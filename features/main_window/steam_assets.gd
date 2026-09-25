extends Node
## Fetches an app's Steam library capsule (600x900 portrait, 2x when available)
## for an App ID and caches it in memory and on disk
## (user://steam_assets/<app_id>/library_600x900.jpg, plus a stamp.txt naming
## the Steam asset it came from).
##
## Knows nothing about the UI: call [method fetch_header] and listen for
## [signal header_ready] / [signal header_failed]. Both carry the App ID that
## was requested so the caller can drop late answers after a project switch.
## A cached capsule is delivered at once and then checked against Steam in the
## background, so [signal header_ready] can fire a second time with new art.

signal header_ready(app_id: String, texture: Texture2D)
signal header_failed(app_id: String, reason: String)
## Emitted by [method find_app_id] with the App ID whose store name exactly
## matches [param name] (case-insensitive), or "" when there is no such app.
signal app_id_found(name: String, app_id: String)

## Store browse API: the only public endpoint that names the current library
## capsule. Updated art lives under a hashed path (and may be renamed to
## library_capsule.jpg), so the fixed paths below can keep serving old art.
const ITEMS_URL := "https://api.steampowered.com/IStoreBrowseService/GetItems/v1/?input_json=%s"
const ASSET_BASE_URL := "https://shared.akamai.steamstatic.com/store_item_assets/"
const SEARCH_URL := "https://store.steampowered.com/api/storesearch/?term=%s&l=english&cc=US"
## Library capsule file names, as listed on the Steam store asset page.
const CAPSULE_2X_FILE := "library_600x900_2x.jpg"
const CAPSULE_FILE := "library_600x900.jpg"
## Fixed per-app paths, tried only when the store API gives no answer. Steam
## does not keep these in sync with the current store artwork.
const STORE_2X_URL := "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/%s/" + CAPSULE_2X_FILE
const STORE_URL := "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/%s/" + CAPSULE_FILE
const CDN_2X_URL := "https://cdn.cloudflare.steamstatic.com/steam/apps/%s/" + CAPSULE_2X_FILE
const CDN_URL := "https://cdn.cloudflare.steamstatic.com/steam/apps/%s/" + CAPSULE_FILE
const CACHE_DIR := "user://steam_assets"
const STAMP_FILE := "stamp.txt"

var _http: HTTPRequest
var _pending_app_id := ""
var _stage := ""  # "api" | "image"
var _queue: PackedStringArray = []  # Image URLs still to try, best first.
var _queue_stamps: PackedStringArray = []  # Asset stamp per queued URL ("" for fixed paths).
var _stamp := ""  # Stamp of the URL being downloaded.
var _last_reason := ""
## Background check of a cached capsule: failures are silent and only art
## Steam names as current may replace the cache.
var _quiet := false
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


func cache_path(app_id: String) -> String:
	return CACHE_DIR.path_join(app_id).path_join(CAPSULE_FILE)


func stamp_path(app_id: String) -> String:
	return CACHE_DIR.path_join(app_id).path_join(STAMP_FILE)


## Delivers the header for [param app_id] through the signals. Cached copies
## are used unless [param force] is set, then checked against Steam in the
## background; the signal is always emitted asynchronously so callers can rely
## on one code path.
func fetch_header(app_id: String, force := false) -> void:
	var quiet := false
	if not force:
		if _texture_cache.has(app_id):
			header_ready.emit.call_deferred(app_id, _texture_cache[app_id])
			quiet = true
		elif FileAccess.file_exists(cache_path(app_id)):
			var img := _decode(FileAccess.get_file_as_bytes(cache_path(app_id)))
			if img != null:
				var tex := ImageTexture.create_from_image(img)
				_texture_cache[app_id] = tex
				header_ready.emit.call_deferred(app_id, tex)
				quiet = true
			# Corrupt cache file: fall through and download again.

	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	_pending_app_id = app_id
	_quiet = quiet
	_last_reason = ""
	_stage = "api"
	var input := JSON.stringify({
		"ids": [{"appid": int(app_id)}],
		"context": {"language": "english", "country_code": "US"},
		"data_request": {"include_assets": true},
	})
	if _http.request(ITEMS_URL % input.uri_encode()) != OK:
		_last_reason = "request failed"
		_on_assets_resolved({})


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200
	_last_reason = ("HTTP %d" % code) if result == HTTPRequest.RESULT_SUCCESS else KnownIssues.http_result_text(result)
	match _stage:
		"api":
			_on_assets_resolved(_capsule_assets(body) if ok else {})
		"image":
			if ok:
				var img := _decode(body)
				if img != null:
					_finish_image(img, body)
					return
				_last_reason = "could not decode image"
			_next_url()


## [param assets] maps stamp -> URL for the current capsule, 2x first; empty
## when the store API had no answer.
func _on_assets_resolved(assets: Dictionary) -> void:
	var urls := PackedStringArray(assets.values())
	var stamps := PackedStringArray(assets.keys())
	if _quiet:
		# Background check: keep the cached image unless Steam names newer art.
		# The fixed paths are never used here, they are what served stale art.
		if urls.is_empty() or _read_stamp(_pending_app_id) in stamps:
			_pending_app_id = ""
			_stage = ""
			return
		_try_urls(urls, stamps)
		return
	var fallback := _store_urls(_pending_app_id) + _legacy_urls(_pending_app_id)
	var blanks := PackedStringArray()
	blanks.resize(fallback.size())
	_try_urls(urls + fallback, stamps + blanks)


## Reads the library capsule out of a GetItems answer as {stamp: url}, 2x
## first. The stamp is the asset's path relative to the app folder (e.g.
## "<hash>/library_capsule_2x.jpg"), which changes whenever the art does.
func _capsule_assets(body: PackedByteArray) -> Dictionary:
	var out := {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("response") is Dictionary:
		return out
	var items = parsed["response"].get("store_items")
	if not items is Array or items.is_empty() or not items[0] is Dictionary:
		return out
	var item: Dictionary = items[0]
	var assets = item.get("assets")
	if int(item.get("success", 0)) != 1 or not assets is Dictionary:
		return out
	var url_format = assets.get("asset_url_format", "")
	if not url_format is String or not "${FILENAME}" in url_format:
		return out
	for key in ["library_capsule_2x", "library_capsule"]:
		var file = assets.get(key, "")
		if file is String and not file.is_empty():
			out[file] = ASSET_BASE_URL + url_format.replace("${FILENAME}", file)
	return out


## 2x first; the 2x copy is not present for every app.
func _store_urls(app_id: String) -> PackedStringArray:
	return PackedStringArray([STORE_2X_URL % app_id, STORE_URL % app_id])


func _legacy_urls(app_id: String) -> PackedStringArray:
	return PackedStringArray([CDN_2X_URL % app_id, CDN_URL % app_id])


func _try_urls(urls: PackedStringArray, stamps: PackedStringArray) -> void:
	_queue = urls
	_queue_stamps = stamps
	_stage = "image"
	_next_url()


func _next_url() -> void:
	if _queue.is_empty():
		_fail(_last_reason if not _last_reason.is_empty() else "no image found")
		return
	var url := _queue[0]
	_stamp = _queue_stamps[0]
	_queue.remove_at(0)
	_queue_stamps.remove_at(0)
	if _http.request(url) != OK:
		_last_reason = "request failed"
		_next_url()


func _read_stamp(app_id: String) -> String:
	if not FileAccess.file_exists(stamp_path(app_id)):
		return ""
	return FileAccess.get_file_as_string(stamp_path(app_id)).strip_edges()


func _finish_image(img: Image, bytes: PackedByteArray) -> void:
	var app_id := _pending_app_id
	_pending_app_id = ""
	_stage = ""
	_queue.clear()
	_queue_stamps.clear()

	var dir := CACHE_DIR.path_join(app_id)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(cache_path(app_id), FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
		var s := FileAccess.open(stamp_path(app_id), FileAccess.WRITE)
		if s != null:
			s.store_string(_stamp)
			s.close()
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
	_queue_stamps.clear()
	if _quiet:
		return  # The cached image is still showing; nothing to report.
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
