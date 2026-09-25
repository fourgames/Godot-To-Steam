class_name ButlerTool
extends RefCounted
## Where butler (itch.io's upload tool) comes from and how it is called.
## Knows nothing about the UI; MainWindow runs the commands this builds.
##
## butler is a single self-contained binary. itch.io serves the current build
## for each platform as a zip from broth.itch.zone; the itch desktop app keeps
## its own copy under <config>/itch/broth/butler/versions/<version>/.

const DOCS_URL := "https://itch.io/docs/butler/"
const API_KEYS_URL := "https://itch.io/user/settings/api-keys"
const BROTH_URL := "https://broth.itch.zone/butler/%s/LATEST/archive/default"

## itch.io's valid "user/game" slugs: letters, digits, "-" and "_".
static var _target_re := RegEx.create_from_string("^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$")
## Channel names butler accepts without surprises (it lower-cases them anyway).
static var _channel_re := RegEx.create_from_string("^[a-z0-9][a-z0-9._-]*$")
static var _version_re := RegEx.create_from_string("v?(\\d+\\.\\d+\\.\\d+)")


## broth channel for this computer, or "" when itch.io builds none for it.
## Apple Silicon and Intel Macs share the universal build; Windows on ARM
## runs the x64 build emulated.
static func host_channel() -> String:
	var arch := Engine.get_architecture_name()
	match OS.get_name():
		"macOS":
			return "darwin-universal"
		"Windows":
			return "windows-amd64" if arch in ["x86_64", "arm64"] else ""
		"Linux":
			if arch == "x86_64":
				return "linux-amd64"
			if arch == "arm64":
				return "linux-arm64"
	return ""


static func download_url() -> String:
	var channel := host_channel()
	return "" if channel.is_empty() else BROTH_URL % channel


static func exe_name() -> String:
	return "butler.exe" if OS.get_name() == "Windows" else "butler"


## Where the Download button puts butler.
static func install_dir() -> String:
	return OS.get_user_data_dir().path_join("butler")


## The folders the itch desktop app keeps butler's versions in.
static func itch_app_broth_dirs(home: String) -> PackedStringArray:
	var out := PackedStringArray()
	match OS.get_name():
		"macOS":
			if not home.is_empty():
				out.append(home.path_join("Library/Application Support/itch/broth/butler"))
		"Windows":
			var appdata := OS.get_environment("APPDATA")
			if not appdata.is_empty():
				out.append(appdata.path_join("itch/broth/butler"))
		"Linux":
			var config := OS.get_environment("XDG_CONFIG_HOME")
			if config.is_empty() and not home.is_empty():
				config = home.path_join(".config")
			if not config.is_empty():
				out.append(config.path_join("itch/broth/butler"))
	return out


## The itch app's current butler under [param broth_dir]: the version named
## in .chosen-version, else the newest folder in versions/. "" when none.
static func itch_app_butler(broth_dir: String) -> String:
	var versions := broth_dir.path_join("versions")
	var chosen_file := broth_dir.path_join(".chosen-version")
	if FileAccess.file_exists(chosen_file):
		var chosen := FileAccess.get_file_as_string(chosen_file).strip_edges()
		var exe := versions.path_join(chosen).path_join(exe_name())
		if not chosen.is_empty() and FileAccess.file_exists(exe):
			return exe
	var dir := DirAccess.open(versions)
	if dir == null:
		return ""
	var names := Array(dir.get_directories())
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) > 0)
	for version: String in names:
		var exe := versions.path_join(version).path_join(exe_name())
		if FileAccess.file_exists(exe):
			return exe
	return ""


## Every butler this computer has: PATH, the itch app's copy, this app's own
## download. [param path_dirs] is PATH split into folders.
static func candidates(home: String, path_dirs: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var dirs := path_dirs.duplicate()
	dirs.append_array(["/usr/local/bin", "/opt/homebrew/bin"])
	for d in dirs:
		var full := d.path_join(exe_name())
		if not d.is_empty() and FileAccess.file_exists(full) and not out.has(full):
			out.append(full)
	for broth in itch_app_broth_dirs(home):
		var exe := itch_app_butler(broth)
		if not exe.is_empty() and not out.has(exe):
			out.append(exe)
	var own := install_dir().path_join(exe_name())
	if FileAccess.file_exists(own) and not out.has(own):
		out.append(own)
	return out


## True when [param exe] is the copy the itch desktop app manages (and
## updates itself), so this app must not replace it.
static func is_itch_app_copy(exe: String) -> bool:
	return exe.replace("\\", "/").contains("/itch/broth/butler/")


## True when [param exe] is the copy the Download button put in place.
static func is_own_copy(exe: String) -> bool:
	return exe.simplify_path() == install_dir().path_join(exe_name()).simplify_path()


## "15.31.0" out of "v15.31.0, built on …"; "" when there is no version.
static func parse_version(output: String) -> String:
	var m := _version_re.search(output)
	return "" if m == null else m.get_string(1)


## Arguments for one push of [param dir] to [param target]:[param channel].
## --fix-permissions marks Mac and Linux executables executable, which a
## build unpacked on Windows loses.
static func push_args(dir: String, target: String, channel: String, userversion: String) -> PackedStringArray:
	var args := PackedStringArray(["push", dir, "%s:%s" % [target, channel], "--json", "--fix-permissions"])
	if not userversion.is_empty():
		args.append("--userversion=%s" % userversion)
	return args


static func is_valid_target(target: String) -> bool:
	return _target_re.search(target) != null


static func is_valid_channel(channel: String) -> bool:
	return _channel_re.search(channel) != null


## "user/game" from a game page address such as https://user.itch.io/game,
## or "" when [param url] is not one.
static func target_from_url(url: String) -> String:
	var rest := url.strip_edges().trim_prefix("https://").trim_prefix("http://")
	var slash := rest.find("/")
	if slash < 0:
		return ""
	var host := rest.substr(0, slash).to_lower()
	var game := rest.substr(slash + 1).get_slice("/", 0).get_slice("?", 0)
	if not host.ends_with(".itch.io") or game.is_empty():
		return ""
	var target := "%s/%s" % [host.trim_suffix(".itch.io"), game]
	return target if is_valid_target(target) else ""


## Game page address for [param target] ("user/game").
static func page_url(target: String) -> String:
	var parts := target.split("/")
	if parts.size() != 2:
		return ""
	return "https://%s.itch.io/%s" % [parts[0], parts[1]]


## Channel for a new build row of platform [param kind] ("windows", "macos",
## "linux", "web", "" for a folder) that is not in [param taken]. itch.io tags
## channels whose name contains windows / linux / mac with that platform.
static func default_channel(kind: String, taken: PackedStringArray, folder_name := "") -> String:
	var base: String
	match kind:
		"windows":
			base = "windows"
		"macos":
			base = "mac"
		"linux":
			base = "linux"
		"web":
			base = "html5"
		_:
			base = slug(folder_name)
			if base.is_empty():
				base = "build"
	var channel := base
	var n := 2
	while taken.has(channel):
		channel = "%s-%d" % [base, n]
		n += 1
	return channel


## [param text] reduced to a channel-safe slug ("My Soundtrack" → "my-soundtrack").
static func slug(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif not out.ends_with("-") and not out.is_empty():
			out += "-"
	return out.trim_suffix("-")
