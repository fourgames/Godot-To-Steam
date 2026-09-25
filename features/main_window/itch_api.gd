extends Node
## itch.io's server-side API for the signed-in account: who the API key
## belongs to (name and avatar) and which games it can upload to.
##
## The key goes in an Authorization header, never in a URL, so it cannot end
## up in a log line or a proxy's access log. Avatars are cached on disk
## (user://itch_assets/profiles/<user id>.img).
##
## Knows nothing about the UI: call [method fetch_profile] / [method fetch_games]
## and listen for the signals. Every answer carries the serial of the request
## it belongs to, so the caller can drop answers for a key it no longer uses.

## [param user] is { id, username, display_name, url }; [param texture] is
## null when the account has no (decodable) avatar.
signal profile_ready(serial: int, user: Dictionary, texture: Texture2D)
## [param unauthorized] is true when itch.io rejected the key itself.
signal profile_failed(serial: int, reason: String, unauthorized: bool)
## [param games] is an Array of { title, target, url, published }.
signal games_ready(serial: int, games: Array)
signal games_failed(serial: int, reason: String)

const PROFILE_URL := "https://api.itch.io/profile"
const GAMES_URL := "https://api.itch.io/profile/games"
const CACHE_DIR := "user://itch_assets/profiles"

var _profile_http: HTTPRequest
var _games_http: HTTPRequest
var _serial := 0
var _profile_serial := -1
var _games_serial := -1
var _user := {}
var _stage := ""  # "profile" | "avatar"


func _ready() -> void:
	_profile_http = _make_http(_on_profile_completed)
	_games_http = _make_http(_on_games_completed)


func _make_http(handler: Callable) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	http.request_completed.connect(handler)
	add_child(http)
	return http


static func _headers(key: String) -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer %s" % key.strip_edges(), "Accept: application/json"])


static func cache_path(user_id: String) -> String:
	return CACHE_DIR.path_join(user_id + ".img")


## Looks up the account [param key] belongs to. Returns the request's serial.
func fetch_profile(key: String) -> int:
	_serial += 1
	var serial := _serial
	if _profile_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_profile_http.cancel_request()
	_profile_serial = serial
	_user = {}
	_stage = "profile"
	if _profile_http.request(PROFILE_URL, _headers(key)) != OK:
		_profile_serial = -1
		profile_failed.emit.call_deferred(serial, "request failed", false)
	return serial


## Lists the games of the account [param key] belongs to. Returns the serial.
func fetch_games(key: String) -> int:
	_serial += 1
	var serial := _serial
	if _games_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_games_http.cancel_request()
	_games_serial = serial
	if _games_http.request(GAMES_URL, _headers(key)) != OK:
		_games_serial = -1
		games_failed.emit.call_deferred(serial, "request failed")
	return serial


func _on_profile_completed(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	var serial := _profile_serial
	if serial < 0:
		return
	if _stage == "avatar":
		# The avatar is a bonus: without it the chip shows the first letter.
		_profile_serial = -1
		var img: Image = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			img = _decode(body)
		if img != null:
			DirAccess.make_dir_recursive_absolute(CACHE_DIR)
			var f := FileAccess.open(cache_path(str(_user["id"])), FileAccess.WRITE)
			if f != null:
				f.store_buffer(body)
				f.close()
		profile_ready.emit(serial, _user, ImageTexture.create_from_image(img) if img != null else null)
		return
	var answer := _parse(result, code, body)
	if answer.has("error"):
		_profile_serial = -1
		profile_failed.emit(serial, answer["error"], answer.get("unauthorized", false))
		return
	var user: Variant = answer["data"].get("user")
	if not user is Dictionary:
		_profile_serial = -1
		profile_failed.emit(serial, "itch.io sent no account details", false)
		return
	_user = {
		"id": str(user.get("id", "")),
		"username": str(user.get("username", "")),
		"display_name": str(user.get("display_name", "")) if user.get("display_name") != null else "",
		"url": str(user.get("url", "")),
	}
	var cover: Variant = user.get("cover_url")
	if FileAccess.file_exists(cache_path(_user["id"])):
		var cached := _decode(FileAccess.get_file_as_bytes(cache_path(_user["id"])))
		if cached != null:
			_profile_serial = -1
			profile_ready.emit(serial, _user, ImageTexture.create_from_image(cached))
			# Refresh the cached picture quietly for the next start.
			if cover is String and not cover.is_empty():
				_refresh_avatar(cover)
			return
	if not cover is String or cover.is_empty():
		_profile_serial = -1
		profile_ready.emit(serial, _user, null)
		return
	_stage = "avatar"
	if _profile_http.request(cover) != OK:
		_profile_serial = -1
		profile_ready.emit(serial, _user, null)


## Downloads [param url] into the avatar cache without emitting anything.
func _refresh_avatar(url: String) -> void:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	var user_id := str(_user["id"])
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and _decode(body) != null:
			DirAccess.make_dir_recursive_absolute(CACHE_DIR)
			var f := FileAccess.open(cache_path(user_id), FileAccess.WRITE)
			if f != null:
				f.store_buffer(body)
				f.close()
		http.queue_free()
	)
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()


func _on_games_completed(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	var serial := _games_serial
	_games_serial = -1
	if serial < 0:
		return
	var answer := _parse(result, code, body)
	if answer.has("error"):
		games_failed.emit(serial, answer["error"])
		return
	var games: Array = []
	var raw: Variant = answer["data"].get("games")
	if raw is Array:
		for g: Variant in raw:
			if not g is Dictionary:
				continue
			var url := str(g.get("url", ""))
			var target := ButlerTool.target_from_url(url)
			if target.is_empty():
				continue
			games.append({
				"title": str(g.get("title", target)),
				"target": target,
				"url": url,
				"published": g.get("published", false) == true,
			})
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["title"]).naturalnocasecmp_to(b["title"]) < 0)
	games_ready.emit(serial, games)


## { "data": Dictionary } for a good JSON answer, or { "error": String,
## "unauthorized": bool } with a plain-words reason.
static func _parse(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"error": KnownIssues.http_result_text(result)}
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	var errors: Variant = data.get("errors") if data is Dictionary else null
	if code in [401, 403] or (errors is Array and "invalid key" in errors):
		return {"error": "itch.io did not accept the API key", "unauthorized": true}
	if code != 200:
		return {"error": "itch.io answered HTTP %d" % code}
	if not data is Dictionary:
		return {"error": "itch.io sent an answer that could not be read"}
	if errors is Array and not errors.is_empty():
		return {"error": "itch.io said: %s" % ", ".join(PackedStringArray(errors))}
	return {"data": data}


## JPEG / PNG / WebP avatars (a GIF avatar is skipped: Godot cannot load it).
static func _decode(bytes: PackedByteArray) -> Image:
	return preload("res://features/main_window/steam_profile.gd").decode_image(bytes)
