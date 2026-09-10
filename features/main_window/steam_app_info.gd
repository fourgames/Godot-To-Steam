class_name SteamAppInfo
extends RefCounted
## Reads the depot list out of SteamCMD's `app_info_print <appid>` output.
##
## SteamCMD prints the app's KeyValues (Valve's VDF text format) to stdout,
## mixed with login and progress lines. [method parse_depots] finds the last
## KeyValues block for the App ID, parses it and returns the content depots.
## Knows nothing about the UI.

## Godot export platform names (from export_presets.cfg) for each Steam oslist
## value. Matching is a case-insensitive substring test on the platform name.
const OS_TO_PLATFORM := {
	"windows": "windows",
	"macos": "mac",
	"linux": "linux",
}
## Desktop platforms an oslist-less depot may be assigned to.
const DESKTOP_PLATFORMS := ["windows", "mac", "linux"]


## Returns [{ depot_id, name, oslist }] for every content depot of [param app_id]
## in [param text], sorted by depot ID. oslist is lower-case and "" when Steam
## lists no OS (which it treats as "all platforms"). Shared depots pulled from
## another app and DLC depots are skipped, as are the non-depot keys Steam
## stores in the same block (branches, baselanguages, ...).
static func parse_depots(text: String, app_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var block := _last_block_for(text, app_id)
	if block.is_empty():
		return result
	var app: Dictionary = _parse_keyvalues(block).get(app_id, {})
	var depots: Dictionary = app.get("depots", {})
	for key in depots.keys():
		var id := str(key)
		if not id.is_valid_int():
			continue
		var depot = depots[key]
		if depot is not Dictionary:
			continue
		if depot.has("depotfromapp") or depot.has("sharedinstall") or depot.has("dlcappid"):
			continue
		var config: Dictionary = depot.get("config", {})
		result.append({
			"depot_id": id,
			"name": str(depot.get("name", "")),
			"oslist": str(config.get("oslist", "")).to_lower().strip_edges(),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["depot_id"]) < int(b["depot_id"])
	)
	return result


## Every depot ID a build of [param app_id] may upload to, as listed in
## [param text], sorted. Unlike [method parse_depots] this keeps DLC depots
## (SteamPipe uploads them through the base app's build script); only depots
## shared from another app are left out. Empty when the block is missing or a
## stub without depots.
static func uploadable_depot_ids(text: String, app_id: String) -> PackedStringArray:
	var ids: Array[int] = []
	var block := _last_block_for(text, app_id)
	if block.is_empty():
		return PackedStringArray()
	var app: Dictionary = _parse_keyvalues(block).get(app_id, {})
	var depots: Dictionary = app.get("depots", {})
	for key in depots.keys():
		var id := str(key)
		if not id.is_valid_int():
			continue
		var depot = depots[key]
		if depot is not Dictionary or depot.has("depotfromapp"):
			continue
		ids.append(int(id))
	ids.sort()
	var out := PackedStringArray()
	for id in ids:
		out.append(str(id))
	return out


## True when a depot restricted to [param oslist] (comma separated, may be "")
## can be served by an export preset for [param godot_platform].
static func platform_matches(oslist: String, godot_platform: String) -> bool:
	var platform := godot_platform.to_lower()
	if oslist.strip_edges().is_empty():
		for desktop in DESKTOP_PLATFORMS:
			if desktop in platform:
				return true
		return false
	for os in oslist.split(",", false):
		var needle: String = OS_TO_PLATFORM.get(os.strip_edges().to_lower(), "")
		if not needle.is_empty() and needle in platform:
			return true
	return false


## Human label for an oslist, used in log lines.
static func oslist_label(oslist: String) -> String:
	if oslist.strip_edges().is_empty():
		return "any OS"
	var parts := PackedStringArray()
	for os in oslist.split(",", false):
		match os.strip_edges().to_lower():
			"windows": parts.append("Windows")
			"macos": parts.append("macOS")
			"linux": parts.append("Linux")
			_: parts.append(os.strip_edges())
	return ", ".join(parts)


## Text from the last line that is exactly "<app_id>" to the end of [param text].
## SteamCMD may print the block twice (a stub before the info arrives, the full
## block after), so the last one wins. Anything after the block's closing
## brace is ignored by the parser.
static func _last_block_for(text: String, app_id: String) -> String:
	var marker := '"%s"' % app_id
	var lines := text.split("\n")
	var start := -1
	for i in lines.size():
		if lines[i].strip_edges() == marker:
			start = i
	if start < 0:
		return ""
	return "\n".join(lines.slice(start))


# ---------------------------------------------------------------------------
# Minimal KeyValues (VDF text) parser
# ---------------------------------------------------------------------------

## Parses [param text] into nested Dictionaries. Values are Strings; children
## are Dictionaries. Stops after the first top-level block.
static func _parse_keyvalues(text: String) -> Dictionary:
	var tokens := _tokenize(text)
	var pos := [0]
	var root := {}
	if tokens.size() >= 2 and tokens[1] == "{":
		root[_unquote(tokens[0])] = _parse_block(tokens, pos, 2)
	return root


static func _parse_block(tokens: PackedStringArray, pos: Array, start: int) -> Dictionary:
	var out := {}
	var i := start
	while i < tokens.size():
		var tok := tokens[i]
		if tok == "}":
			pos[0] = i + 1
			return out
		if tok == "{":
			i += 1
			continue
		var key := _unquote(tok)
		if i + 1 >= tokens.size():
			break
		var next := tokens[i + 1]
		if next == "{":
			out[key] = _parse_block(tokens, pos, i + 2)
			i = pos[0]
		elif next == "}":
			out[key] = ""
			i += 1
		else:
			out[key] = _unquote(next)
			i += 2
	pos[0] = i
	return out


## Splits KeyValues text into quoted strings, bare words and braces. Quoted
## tokens keep their quotes so [method _unquote] can tell them apart. `//`
## comments are dropped.
static func _tokenize(text: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			i += 1
		elif c == "{" or c == "}":
			tokens.append(c)
			i += 1
		elif c == "/" and i + 1 < n and text[i + 1] == "/":
			while i < n and text[i] != "\n":
				i += 1
		elif c == '"':
			var j := i + 1
			var buf := ""
			while j < n and text[j] != '"':
				if text[j] == "\\" and j + 1 < n:
					j += 1
				buf += text[j]
				j += 1
			tokens.append('"' + buf + '"')
			i = j + 1
		else:
			var j := i
			while j < n and text[j] not in [" ", "\t", "\n", "\r", "{", "}"]:
				j += 1
			tokens.append(text.substr(i, j - i))
			i = j
	return tokens


static func _unquote(token: String) -> String:
	if token.length() >= 2 and token.begins_with('"') and token.ends_with('"'):
		return token.substr(1, token.length() - 2)
	return token
