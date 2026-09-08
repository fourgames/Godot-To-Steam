extends Node
## Fetches a game's Steam library capsule (600x900 portrait, 2x when available)
## for an App ID and caches it in memory and on disk
## (user://steam_assets/<app_id>/library_600x900.jpg).
##
## Knows nothing about the UI: call [method fetch_header] and listen for
## [signal header_ready] / [signal header_failed]. Both carry the App ID that
## was requested so the caller can drop late answers after a project switch.

signal header_ready(app_id: String, texture: Texture2D)
signal header_failed(app_id: String, reason: String)
## Emitted by [method find_app_id] with the App ID whose store name exactly
## matches [param name] (case-insensitive), or "" when there is no such app.
signal app_id_found(name: String, app_id: String)

const API_URL := "https://store.steampowered.com/api/appdetails?appids=%s&filters=basic"
const SEARCH_URL := "https://store.steampowered.com/api/storesearch/?term=%s&l=english&cc=US"
## Library capsule file names, as listed on the Steam store asset page.
const CAPSULE_2X_FILE := "library_600x900_2x.jpg"
const CAPSULE_FILE := "library_600x900.jpg"
## Current store asset host; the appdetails API does not list the library
## capsule, but it is served from this fixed path for every app that has one.
const STORE_2X_URL := "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/%s/" + CAPSULE_2X_FILE
const STORE_URL := "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/%s/" + CAPSULE_FILE
## Legacy CDN paths, tried last. Steam does not always keep these in sync
## with the current store artwork.
const CDN_2X_URL := "https://cdn.cloudflare.steamstatic.com/steam/apps/%s/" + CAPSULE_2X_FILE
const CDN_URL := "https://cdn.cloudflare.steamstatic.com/steam/apps/%s/" + CAPSULE_FILE
const CACHE_DIR := "user://steam_assets"

var _http: HTTPRequest
var _pending_app_id := ""
var _stage := ""  # "api" | "image"
var _queue: PackedStringArray = []  # Image URLs still to try, best first.
var _last_reason := ""
var _texture_cache: Dictionary = {}

var _search_http: HTTPRequest
var _search_name := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

	_search_http = HTTPRequest.new()
	_search_http.timeout = 15.0
	_search_http.request_completed.connect(_on_search_completed)
	add_child(_search_http)


var is_fetching: bool:
	get:
		return not _pending_app_id.is_empty()


func cache_path(app_id: String) -> String:
	return CACHE_DIR.path_join(app_id).path_join(CAPSULE_FILE)


func has_cached(app_id: String) -> bool:
	return _texture_cache.has(app_id) or FileAccess.file_exists(cache_path(app_id))


## Delivers the header for [param app_id] through the signals. Cached copies
## are used unless [param force] is set; the signal is always emitted
## asynchronously so callers can rely on one code path.
func fetch_header(app_id: String, force := false) -> void:
	if not force:
		if _texture_cache.has(app_id):
			header_ready.emit.call_deferred(app_id, _texture_cache[app_id])
			return
		if FileAccess.file_exists(cache_path(app_id)):
			var img := _decode(FileAccess.get_file_as_bytes(cache_path(app_id)))
			if img != null:
				var tex := ImageTexture.create_from_image(img)
				_texture_cache[app_id] = tex
				header_ready.emit.call_deferred(app_id, tex)
				return
			# Corrupt cache file: fall through and download again.

	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	_pending_app_id = app_id
	_last_reason = ""
	_stage = "api"
	if _http.request(API_URL % app_id) != OK:
		_try_urls(_legacy_urls(app_id))


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200
	_last_reason = ("HTTP %d" % code) if result == HTTPRequest.RESULT_SUCCESS else "no response"
	match _stage:
		"api":
			# The API only lists header.jpg (under a hashed path the capsule is
			# not served from), so it just confirms the app exists; the capsule
			# itself comes from the fixed per-app asset paths.
			if ok and _app_exists(body):
				_try_urls(_store_urls(_pending_app_id) + _legacy_urls(_pending_app_id))
			else:
				_try_urls(_legacy_urls(_pending_app_id))
		"image":
			if ok:
				var img := _decode(body)
				if img != null:
					_finish_image(img, body)
					return
				_last_reason = "could not decode image"
			_next_url()


## 2x first; the 2x copy is not present for every app.
func _store_urls(app_id: String) -> PackedStringArray:
	return PackedStringArray([STORE_2X_URL % app_id, STORE_URL % app_id])


func _legacy_urls(app_id: String) -> PackedStringArray:
	return PackedStringArray([CDN_2X_URL % app_id, CDN_URL % app_id])


func _try_urls(urls: PackedStringArray) -> void:
	_queue = urls
	_stage = "image"
	_next_url()


func _next_url() -> void:
	if _queue.is_empty():
		_fail(_last_reason if not _last_reason.is_empty() else "no image found")
		return
	var url := _queue[0]
	_queue.remove_at(0)
	if _http.request(url) != OK:
		_last_reason = "request failed"
		_next_url()


## True when the appdetails JSON reports the pending app as a real store
## entry; false for {"<id>": {"success": false}} or a malformed payload.
func _app_exists(body: PackedByteArray) -> bool:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return false
	var entry = parsed.get(_pending_app_id)
	return entry is Dictionary and bool(entry.get("success", false)) and entry.get("data") is Dictionary


func _finish_image(img: Image, bytes: PackedByteArray) -> void:
	var app_id := _pending_app_id
	_pending_app_id = ""
	_stage = ""
	_queue.clear()

	var dir := CACHE_DIR.path_join(app_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(cache_path(app_id), FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
	else:
		push_warning("Steam capsule for %s could not be written to %s" % [app_id, cache_path(app_id)])

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[app_id] = tex
	header_ready.emit(app_id, tex)


func _fail(reason: String) -> void:
	var app_id := _pending_app_id
	_pending_app_id = ""
	_stage = ""
	_queue.clear()
	header_failed.emit(app_id, reason)


## Decodes JPEG / PNG / WebP by magic bytes; null for anything else (e.g. an
## HTML error page served with status 200).
func _decode(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = img.load_png_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	return img


# ---------------------------------------------------------------------------
# App ID lookup by store name
# ---------------------------------------------------------------------------

## Asks the Steam store search for [param name] and answers through
## [signal app_id_found]. Only an exact name match counts, so a project called
## "Platformer" never picks up some other studio's "Platformer 2". A new call
## cancels a search that is still running.
func find_app_id(name: String) -> void:
	var term := name.strip_edges()
	if term.is_empty():
		app_id_found.emit.call_deferred(name, "")
		return
	if _search_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_search_http.cancel_request()
	_search_name = term
	if _search_http.request(SEARCH_URL % term.uri_encode()) != OK:
		_search_name = ""
		app_id_found.emit.call_deferred(term, "")


func _on_search_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var name := _search_name
	_search_name = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		app_id_found.emit(name, "")
		return
	app_id_found.emit(name, _exact_match_id(name, body))


## Pulls the id of the "app" item whose name equals [param name] (ignoring
## case, surrounding whitespace and trademark marks such as ™ or ®) out of
## the storesearch JSON; "" otherwise.
func _exact_match_id(name: String, body: PackedByteArray) -> String:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return ""
	var items = parsed.get("items", [])
	if not items is Array:
		return ""
	var wanted := _normalize_name(name)
	for item in items:
		if not item is Dictionary or item.get("type", "") != "app":
			continue
		var item_name = item.get("name", "")
		if item_name is String and _normalize_name(item_name) == wanted:
			var id = item.get("id")
			if id is float or id is int:
				return str(int(id))
	return ""


## Store names often carry ™, ® or © that nobody types into project.godot.
static func _normalize_name(name: String) -> String:
	var out := name.to_lower()
	for mark in ["™", "®", "©"]:
		out = out.replace(mark, "")
	return out.strip_edges()
