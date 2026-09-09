extends Node
## Resolves a Steam account name to its public profile (persona name and
## avatar) without an API key and caches the avatar on disk
## (user://steam_assets/profiles/<steamid64>.jpg).
##
## SteamCMD records the SteamID64 of every account that logged in through it
## in its config.vdf (Software/Valve/Steam/Accounts/<name>/SteamID). That ID
## is enough for the Steam Community XML endpoint, which serves the avatar and
## persona name for any account, private profiles included.
##
## Knows nothing about the UI: call [method fetch] and listen for
## [signal profile_ready] / [signal profile_failed]. Both carry the account
## name that was requested so the caller can drop late answers.

signal profile_ready(username: String, persona: String, texture: Texture2D)
signal profile_failed(username: String, reason: String)

const PROFILE_URL := "https://steamcommunity.com/profiles/%s/?xml=1"
const CACHE_DIR := "user://steam_assets/profiles"

var _http: HTTPRequest
var _pending_user := ""
var _pending_id := ""
var _persona := ""
var _stage := ""  # "xml" | "image"
## steamid64 -> {"persona": String, "texture": Texture2D}
var _cache: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func cache_path(steam_id: String) -> String:
	return CACHE_DIR.path_join(steam_id + ".jpg")


## Persona name cached next to the avatar so a restart shows it immediately.
func persona_path(steam_id: String) -> String:
	return CACHE_DIR.path_join(steam_id + ".persona")


## Delivers the profile for [param username] through the signals. The SteamID
## is read from SteamCMD's config.vdf (see [method find_steam_id]); the
## cached avatar is used unless [param force] is set. The signal is always
## emitted asynchronously so callers can rely on one code path.
func fetch(username: String, steamcmd_path: String, force := false) -> void:
	username = username.strip_edges()
	var steam_id := find_steam_id(username, steamcmd_path)
	if steam_id.is_empty():
		profile_failed.emit.call_deferred(username, "SteamID not found in SteamCMD config – sign in once first")
		return

	if not force:
		if _cache.has(steam_id):
			var c: Dictionary = _cache[steam_id]
			profile_ready.emit.call_deferred(username, c["persona"], c["texture"])
			return
		if FileAccess.file_exists(cache_path(steam_id)):
			var img := decode_image(FileAccess.get_file_as_bytes(cache_path(steam_id)))
			if img != null:
				var tex := ImageTexture.create_from_image(img)
				var persona := ""
				if FileAccess.file_exists(persona_path(steam_id)):
					persona = FileAccess.get_file_as_string(persona_path(steam_id)).strip_edges()
				_cache[steam_id] = {"persona": persona, "texture": tex}
				profile_ready.emit.call_deferred(username, persona, tex)
				return
			# Corrupt cache file: fall through and download again.

	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	_pending_user = username
	_pending_id = steam_id
	_persona = ""
	_stage = "xml"
	if _http.request(PROFILE_URL % steam_id) != OK:
		_fail("request failed")


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("no response")
		return
	if code != 200:
		_fail("HTTP %d" % code)
		return
	match _stage:
		"xml":
			var xml := body.get_string_from_utf8()
			_persona = _xml_text(xml, "steamID")
			var avatar := _xml_text(xml, "avatarFull")
			if avatar.is_empty():
				avatar = _xml_text(xml, "avatarMedium")
			if avatar.is_empty():
				_fail("profile has no avatar")
				return
			_stage = "image"
			if _http.request(avatar) != OK:
				_fail("request failed")
		"image":
			var img := decode_image(body)
			if img == null:
				_fail("could not decode image")
				return
			_finish(img, body)


## Text of the first <tag>…</tag> in [param xml]; CDATA wrappers are stripped.
static func _xml_text(xml: String, tag: String) -> String:
	var open := xml.find("<%s>" % tag)
	if open < 0:
		return ""
	open += tag.length() + 2
	var close := xml.find("</%s>" % tag, open)
	if close < 0:
		return ""
	var text := xml.substr(open, close - open).strip_edges()
	if text.begins_with("<![CDATA[") and text.ends_with("]]>"):
		text = text.substr(9, text.length() - 12)
	return text.strip_edges()


func _finish(img: Image, bytes: PackedByteArray) -> void:
	var user := _pending_user
	var steam_id := _pending_id
	var persona := _persona
	_pending_user = ""
	_pending_id = ""
	_stage = ""

	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(cache_path(steam_id), FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
	else:
		push_warning("Steam avatar for %s could not be written to %s" % [user, cache_path(steam_id)])
	var pf := FileAccess.open(persona_path(steam_id), FileAccess.WRITE)
	if pf != null:
		pf.store_string(persona)
		pf.close()

	var tex := ImageTexture.create_from_image(img)
	_cache[steam_id] = {"persona": persona, "texture": tex}
	profile_ready.emit(user, persona, tex)


func _fail(reason: String) -> void:
	var user := _pending_user
	_pending_user = ""
	_pending_id = ""
	_stage = ""
	profile_failed.emit(user, reason)


# ---------------------------------------------------------------------------
# SteamID lookup in SteamCMD's config.vdf
# ---------------------------------------------------------------------------

## The SteamID64 SteamCMD stored for [param username], or "" when no config
## file lists it. [param steamcmd_path] is the resolved SteamCMD executable;
## its folder is one of the places the config is looked for.
static func find_steam_id(username: String, steamcmd_path: String) -> String:
	if username.is_empty():
		return ""
	for path in config_candidates(steamcmd_path):
		if not FileAccess.file_exists(path):
			continue
		var id := _parse_account_id(FileAccess.get_file_as_string(path), username)
		if not id.is_empty():
			return id
	return ""


## Every config.vdf location SteamCMD is known to use, most likely first.
static func config_candidates(steamcmd_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	# The app runs SteamCMD with a private HOME (MainWindow.steamcmd_home()) so
	# the Steam client cannot clobber its login; the user's real HOME comes
	# second for logins made before that, or from a terminal.
	var homes := PackedStringArray()
	var private_home := MainWindow.steamcmd_home()
	if not private_home.is_empty():
		homes.append(private_home)
	homes.append(OS.get_environment("HOME"))
	for home in homes:
		match OS.get_name():
			"macOS":
				# SteamCMD on macOS uses the Steam client's config layout.
				out.append(home.path_join("Library/Application Support/Steam/config/config.vdf"))
			"Linux":
				out.append_array([
					home.path_join(".steam/steamcmd/config/config.vdf"),
					home.path_join("Steam/config/config.vdf"),
					home.path_join(".local/share/Steam/config/config.vdf"),
				])
	# Zip / tarball installs (and this app's own download) keep it next to the binary.
	if not steamcmd_path.is_empty():
		out.append(steamcmd_path.get_base_dir().path_join("config/config.vdf"))
	out.append(OS.get_user_data_dir().path_join("steamcmd/config/config.vdf"))
	return out


## Minimal scan of the "Accounts" block:
##   "Accounts" { "<name>" { "SteamID" "7656..." } ... }
## No full VDF parser is needed; keys are one per line and quoted.
static func _parse_account_id(vdf: String, username: String) -> String:
	var lines := vdf.split("\n")
	var in_accounts := false
	var depth := 0
	var in_user := false
	var user_depth := 0
	for raw in lines:
		var line := raw.strip_edges()
		if not in_accounts:
			if line == "\"Accounts\"":
				in_accounts = true
				depth = 0
			continue
		if line == "{":
			depth += 1
			continue
		if line == "}":
			depth -= 1
			if depth <= 0:
				return ""  # Left the Accounts block without a match.
			if in_user and depth < user_depth:
				in_user = false
			continue
		var tokens := _quoted_tokens(line)
		if tokens.is_empty():
			continue
		if in_user and tokens.size() >= 2 and tokens[0] == "SteamID":
			return tokens[1]
		if not in_user and tokens.size() == 1 and depth == 1 and tokens[0].nocasecmp_to(username) == 0:
			in_user = true
			user_depth = depth + 1
	return ""


static func _quoted_tokens(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < line.length():
		if line[i] == "\"":
			var end := line.find("\"", i + 1)
			if end < 0:
				break
			out.append(line.substr(i + 1, end - i - 1))
			i = end + 1
		else:
			i += 1
	return out


## Decodes JPEG / PNG / WebP by magic bytes; null for anything else.
static func decode_image(bytes: PackedByteArray) -> Image:
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
