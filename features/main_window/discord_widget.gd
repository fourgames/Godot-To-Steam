extends Node
## Fetches the public Discord "Server Widget" JSON for a guild and the
## avatars of the members it lists. Knows nothing about the UI: call
## [method fetch] and listen for [signal widget_ready] / [signal widget_failed];
## call [method fetch_avatar] and listen for [signal avatar_ready].
##
## The endpoint needs no API key; the guild only has to have the widget
## enabled (Server Settings → Widget). Member ids in the response are
## anonymised per request, so avatars are cached by URL, not by member id.

signal widget_ready(data: Dictionary)
signal widget_failed(reason: String)
signal avatar_ready(url: String, texture: Texture2D)

const WIDGET_URL := "https://discord.com/api/guilds/%s/widget.json"
const MAX_AVATAR_QUEUE := 40

var _http: HTTPRequest
var _avatar_http: HTTPRequest
var _avatar_queue: PackedStringArray = []
var _avatar_pending := ""
## avatar_url -> Texture2D
var _avatar_cache: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_widget_completed)
	add_child(_http)
	_avatar_http = HTTPRequest.new()
	_avatar_http.timeout = 15.0
	_avatar_http.request_completed.connect(_on_avatar_completed)
	add_child(_avatar_http)


## Requests the widget JSON for [param guild_id]. Any request still in flight
## is dropped so only the latest answer is delivered.
func fetch(guild_id: String) -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	if _http.request(WIDGET_URL % guild_id) != OK:
		widget_failed.emit.call_deferred("request failed")


func _on_widget_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		widget_failed.emit(KnownIssues.http_result_text(result))
		return
	if code == 403:
		widget_failed.emit("HTTP 403 – enable Server Widget in Discord's server settings")
		return
	if code != 200:
		widget_failed.emit("HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		widget_failed.emit("unexpected response")
		return
	widget_ready.emit(data)


## Delivers the picture at [param url] through [signal avatar_ready], from the
## in-memory cache when possible, otherwise downloaded one at a time.
func fetch_avatar(url: String) -> void:
	if url.is_empty():
		return
	if _avatar_cache.has(url):
		avatar_ready.emit.call_deferred(url, _avatar_cache[url])
		return
	if url == _avatar_pending or _avatar_queue.has(url) or _avatar_queue.size() >= MAX_AVATAR_QUEUE:
		return
	_avatar_queue.append(url)
	_next_avatar()


## Forgets queued downloads that have not started yet (a new member list).
func clear_avatar_queue() -> void:
	_avatar_queue.clear()


func _next_avatar() -> void:
	if not _avatar_pending.is_empty() or _avatar_queue.is_empty():
		return
	_avatar_pending = _avatar_queue[0]
	_avatar_queue.remove_at(0)
	if _avatar_http.request(_avatar_pending) != OK:
		_avatar_pending = ""
		_next_avatar()


func _on_avatar_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var url := _avatar_pending
	_avatar_pending = ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var img := decode_image(body)
		if img != null:
			var tex := ImageTexture.create_from_image(img)
			_avatar_cache[url] = tex
			avatar_ready.emit(url, tex)
	_next_avatar()


static func decode_image(bytes: PackedByteArray) -> Image:
	return preload("res://features/main_window/steam_profile.gd").decode_image(bytes)
