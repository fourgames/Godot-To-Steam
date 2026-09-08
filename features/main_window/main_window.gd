extends Control
## Godot to Steam – main window controller.
##
## Owns the sidebar project list, the per-project settings form (Godot binary,
## App ID, branch, depot table), the Steam auth panel with automatic TOTP, and
## the live debug console. Child processes (Godot export + SteamCMD upload)
## stream their output into the console line by line.

const PROJECTS_FILE := "user://projects.cfg"
const SETTINGS_FILE := "user://settings.cfg"
const STEAM_TOTP_ALPHABET := "23456789BCDFGHJKMNPQRTVWXY"

# Console colours (bbcode).
const COLOR_INFO := "#c8c8c8"
const COLOR_CMD := "#6cb6ff"
const COLOR_OK := "#7ee787"
const COLOR_WARN := "#e3b341"
const COLOR_ERR := "#ff7b72"

## Each project is a Dictionary:
## {
##   name: String, path: String, godot_binary: String,
##   app_id: String, branch: String, description: String,
##   depots: Array[Dictionary]  -> { preset: String, depot_id: String, output: String }
## }
var _projects: Array[Dictionary] = []
var _selected_index: int = -1
var _project_button_group := ButtonGroup.new()
var _is_busy := false
var _preset_names: PackedStringArray = []

# Reader threads for the currently running child process.
var _reader_threads: Array[Thread] = []


func _ready() -> void:
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%BrowseButton.pressed.connect(_on_browse_pressed)
	%RemoveProjectButton.pressed.connect(_on_remove_project_pressed)
	%ProjectDialog.dir_selected.connect(_on_project_dir_selected)
	%BuildPublishButton.pressed.connect(_on_build_publish_pressed)
	%ClearConsoleButton.pressed.connect(%Console.clear)
	%SteamLoginButton.pressed.connect(_on_steam_login_pressed)
	%AddDepotButton.pressed.connect(_on_add_depot_pressed)
	%CheckGodotButton.pressed.connect(_on_check_godot_pressed)
	%BrowseGodotButton.pressed.connect(func() -> void: %GodotDialog.popup_centered())
	%GodotDialog.file_selected.connect(_on_godot_binary_selected)
	%GodotDialog.dir_selected.connect(_on_godot_binary_selected)
	%TotpTimer.timeout.connect(_update_totp_status)

	# Per-project fields write straight back into the selected project.
	%GodotBinary.text_changed.connect(func(t: String) -> void: _commit_field("godot_binary", t))
	%AppId.text_changed.connect(func(t: String) -> void: _commit_field("app_id", t))
	%Branch.text_changed.connect(func(t: String) -> void: _commit_field("branch", t))
	%BuildDescription.text_changed.connect(func(t: String) -> void: _commit_field("description", t))

	# Global settings.
	%SteamCmdBinary.text_changed.connect(func(_t: String) -> void: _save_settings())
	%SteamUsername.text_changed.connect(func(_t: String) -> void: _save_settings())
	%SteamPassword.text_changed.connect(func(_t: String) -> void: _save_settings())
	%SteamSharedSecret.text_changed.connect(func(_t: String) -> void: _save_settings())
	%RememberPassword.toggled.connect(func(_on: bool) -> void: _save_settings())

	_load_settings()
	_load_projects()
	_rebuild_sidebar()
	_show_project(-1)
	_update_totp_status()
	log_line("Godot to Steam ready.", COLOR_OK)


# ---------------------------------------------------------------------------
# Sidebar / project switching
# ---------------------------------------------------------------------------

func _on_new_game_pressed() -> void:
	%ProjectDialog.set_meta("browse", false)
	%ProjectDialog.popup_centered()


func _on_browse_pressed() -> void:
	%ProjectDialog.set_meta("browse", true)
	%ProjectDialog.popup_centered()


func _on_remove_project_pressed() -> void:
	if _selected_index < 0:
		return
	log_line("Removed %s from the list." % _projects[_selected_index]["name"], COLOR_WARN)
	_projects.remove_at(_selected_index)
	_save_projects()
	_rebuild_sidebar()
	_show_project(-1)


func _on_project_dir_selected(dir: String) -> void:
	if not FileAccess.file_exists(dir.path_join("project.godot")):
		log_line("No project.godot found in %s" % dir, COLOR_ERR)
		return

	var is_browse: bool = %ProjectDialog.get_meta("browse", false)
	if is_browse and _selected_index >= 0:
		_projects[_selected_index]["path"] = dir
		_projects[_selected_index]["name"] = _read_project_name(dir)
	else:
		_projects.append({
			"name": _read_project_name(dir),
			"path": dir,
			"godot_binary": _guess_godot_binary(_read_required_godot_version(dir)),
			"app_id": "",
			"branch": "",
			"description": "",
			"depots": [],
		})
		_selected_index = _projects.size() - 1

	_save_projects()
	_rebuild_sidebar()
	_show_project(_selected_index)


func _rebuild_sidebar() -> void:
	for child in %ProjectList.get_children():
		child.queue_free()

	for i in _projects.size():
		var p := _projects[i]
		var btn := Button.new()
		btn.text = "%s   ·   Godot %s" % [p["name"], _read_required_godot_version(p["path"])]
		btn.tooltip_text = p["path"]
		btn.toggle_mode = true
		btn.button_group = _project_button_group
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.clip_text = true
		btn.custom_minimum_size.y = 32
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.button_pressed = (i == _selected_index)
		btn.pressed.connect(_show_project.bind(i))
		%ProjectList.add_child(btn)


## Switch the main view to project [param index]; -1 shows the empty state.
func _show_project(index: int) -> void:
	_selected_index = index
	var has_project := index >= 0 and index < _projects.size()
	%EmptyState.visible = not has_project
	%ProjectSettings.visible = has_project
	if not has_project:
		return

	var p := _projects[index]
	%ProjectTitle.text = p["name"]
	%ProjectPath.text = p["path"]
	%GodotBinary.text = p.get("godot_binary", "")
	%AppId.text = p.get("app_id", "")
	%Branch.text = p.get("branch", "")
	%BuildDescription.text = p.get("description", "")

	_preset_names = _read_presets(p["path"])
	_rebuild_depot_rows()
	_check_godot_version()

	log_line("Selected project: %s" % p["name"], COLOR_INFO)


func _commit_field(key: String, value: String) -> void:
	if _selected_index < 0:
		return
	_projects[_selected_index][key] = value
	_save_projects()


# ---------------------------------------------------------------------------
# Godot version per project
# ---------------------------------------------------------------------------

## Reads "4.7" out of config/features in the project's project.godot.
func _read_required_godot_version(project_path: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(project_path.path_join("project.godot")) != OK:
		return "?"
	var features: PackedStringArray = cfg.get_value("application", "config/features", PackedStringArray())
	var re := RegEx.create_from_string("^\\d+\\.\\d+$")
	for f in features:
		if re.search(f):
			return f
	return "?"


## Asks the configured binary for its version and compares it with the project.
func _check_godot_version() -> void:
	if _selected_index < 0:
		return
	var p := _projects[_selected_index]
	var required := _read_required_godot_version(p["path"])
	var binary: String = p.get("godot_binary", "")

	if binary.is_empty() or not FileAccess.file_exists(binary):
		%GodotVersionLabel.text = "Project requires %s  ·  binary not found" % required
		%GodotVersionLabel.modulate = Color(COLOR_ERR)
		return

	var reported := _binary_version(binary)
	var matches := reported.begins_with(required + ".")
	%GodotVersionLabel.text = "Project requires %s  ·  binary reports %s" % [required, reported]
	%GodotVersionLabel.modulate = Color(COLOR_OK if matches else COLOR_WARN)
	if not matches:
		log_line("Godot version mismatch for %s: project wants %s, binary is %s" % [p["name"], required, reported], COLOR_WARN)


func _on_godot_binary_selected(path: String) -> void:
	var resolved := _resolve_godot_binary(path)
	if resolved.is_empty():
		log_line("No executable found inside %s" % path, COLOR_ERR)
		return
	%GodotBinary.text = resolved  # text_changed does not fire on set, commit manually
	_commit_field("godot_binary", resolved)
	_check_godot_version()


## Check button: verifies the version, or auto-detects when the field is empty.
func _on_check_godot_pressed() -> void:
	if _selected_index < 0:
		return
	var current: String = %GodotBinary.text.strip_edges()
	if current.is_empty() or not FileAccess.file_exists(current):
		var required := _read_required_godot_version(_projects[_selected_index]["path"])
		var found := _guess_godot_binary(required)
		if found.is_empty():
			log_line("No Godot %s install found in /Applications or the Steam library. Use Browse…" % required, COLOR_WARN)
		else:
			log_line("Detected Godot %s at %s" % [required, found], COLOR_OK)
			%GodotBinary.text = found
			_commit_field("godot_binary", found)
	_check_godot_version()


## Turns "Godot.app" (a macOS bundle) into the executable inside it.
## Any other path is returned untouched.
func _resolve_godot_binary(path: String) -> String:
	path = path.trim_suffix("/")
	if path.to_lower().ends_with(".app") and DirAccess.dir_exists_absolute(path):
		var macos_dir := path.path_join("Contents/MacOS")
		var dir := DirAccess.open(macos_dir)
		if dir == null:
			return ""
		var files := dir.get_files()
		if files.has("Godot"):
			return macos_dir.path_join("Godot")
		# Steam drops launcher bundles in ~/Applications whose only content is a
		# run.sh that opens Steam – never treat those as a Godot binary.
		for f in files:
			if not _is_script_file(f):
				return macos_dir.path_join(f)
		return ""
	return path


func _is_script_file(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return ext in ["sh", "command", "bat", "cmd", "ps1"]


## Finds a Godot binary whose --version matches [param required] ("4.7").
## Order: binaries already set on other projects, then well-known install
## locations (/Applications, ~/Applications, Steam library, PATH).
func _guess_godot_binary(required: String) -> String:
	for p in _projects:
		var b: String = p.get("godot_binary", "")
		if not b.is_empty() and _read_required_godot_version(p["path"]) == required:
			return b

	for candidate in _godot_candidates():
		if _binary_version(candidate).begins_with(required + "."):
			return candidate
	return ""


func _godot_candidates() -> PackedStringArray:
	var out := PackedStringArray()
	var home := OS.get_environment("HOME")
	var dirs: PackedStringArray = [
		"/Applications",
		home.path_join("Applications"),
		home.path_join("Library/Application Support/Steam/steamapps/common/Godot Engine"),
		home.path_join("Library/Application Support/Steam/steamapps/common/Godot Engine 4"),
		OS.get_environment("ProgramFiles").path_join("Godot"),
		home.path_join(".steam/steam/steamapps/common/Godot Engine"),
		"/usr/local/bin",
		"/opt/homebrew/bin",
	]
	for d in dirs:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for entry in dir.get_directories():
			if "godot" in entry.to_lower() and entry.to_lower().ends_with(".app"):
				var exe := _resolve_godot_binary(d.path_join(entry))
				if not exe.is_empty() and not out.has(exe):
					out.append(exe)
		for entry in dir.get_files():
			if "godot" in entry.to_lower() and not _is_script_file(entry) and not out.has(d.path_join(entry)):
				out.append(d.path_join(entry))
	if OS.has_feature("editor") and not out.has(OS.get_executable_path()):
		out.append(OS.get_executable_path())  # the editor running this tool
	return out


## Runs "<binary> --version" with a hard timeout so a launcher stub or a
## broken install can never freeze the UI. Returns "" when unsure.
func _binary_version(binary: String, timeout_msec: int = 8000) -> String:
	if binary.is_empty() or _is_script_file(binary) or not FileAccess.file_exists(binary):
		return ""
	var info := OS.execute_with_pipe(binary, ["--version"], false)
	if info.is_empty():
		return ""
	var pid: int = info["pid"]
	var stdio: FileAccess = info["stdio"]
	var started := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - started > timeout_msec:
			OS.kill(pid)
			log_line("Timed out probing %s – not a Godot binary?" % binary, COLOR_WARN)
			return ""
		OS.delay_msec(20)
	var version := stdio.get_line().strip_edges()
	stdio.close()
	info["stderr"].close()
	return version


# ---------------------------------------------------------------------------
# Depot table
# ---------------------------------------------------------------------------

func _read_presets(project_path: String) -> PackedStringArray:
	var names := PackedStringArray()
	var cfg := ConfigFile.new()
	if cfg.load(project_path.path_join("export_presets.cfg")) != OK:
		return names
	var i := 0
	while cfg.has_section("preset.%d" % i):
		names.append(cfg.get_value("preset.%d" % i, "name", "preset %d" % i))
		i += 1
	return names


func _on_add_depot_pressed() -> void:
	if _selected_index < 0:
		return
	var depots: Array = _projects[_selected_index]["depots"]
	var preset := _preset_names[mini(depots.size(), _preset_names.size() - 1)] if _preset_names.size() > 0 else ""
	depots.append({"preset": preset, "depot_id": "", "output": _default_output_name(preset)})
	_save_projects()
	_rebuild_depot_rows()


func _rebuild_depot_rows() -> void:
	for child in %DepotRows.get_children():
		child.queue_free()
	if _selected_index < 0:
		return
	var depots: Array = _projects[_selected_index]["depots"]
	for i in depots.size():
		%DepotRows.add_child(_make_depot_row(i, depots[i]))


func _make_depot_row(index: int, depot: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var preset := OptionButton.new()
	preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset_name in _preset_names:
		preset.add_item(preset_name)
	var sel := _preset_names.find(depot["preset"])
	if sel >= 0:
		preset.select(sel)
	preset.item_selected.connect(func(idx: int) -> void:
		var d: Dictionary = _projects[_selected_index]["depots"][index]
		d["preset"] = _preset_names[idx]
		d["output"] = _default_output_name(d["preset"])
		_save_projects()
		_rebuild_depot_rows()
	)
	row.add_child(preset)

	var depot_id := LineEdit.new()
	depot_id.custom_minimum_size.x = 120
	depot_id.placeholder_text = "2807131"
	depot_id.text = depot["depot_id"]
	depot_id.text_changed.connect(func(t: String) -> void:
		_projects[_selected_index]["depots"][index]["depot_id"] = t
		_save_projects()
	)
	row.add_child(depot_id)

	var output := LineEdit.new()
	output.custom_minimum_size.x = 160
	output.placeholder_text = "game.zip"
	output.tooltip_text = "Export file name. Godot names the .app / .exe / .pck after this, so keep it stable and match Steam's launch options."
	output.text = depot["output"]
	output.text_changed.connect(func(t: String) -> void:
		_projects[_selected_index]["depots"][index]["output"] = t
		_save_projects()
	)
	row.add_child(output)

	var remove := Button.new()
	remove.text = "✕"
	remove.custom_minimum_size.x = 32
	remove.pressed.connect(func() -> void:
		_projects[_selected_index]["depots"].remove_at(index)
		_save_projects()
		_rebuild_depot_rows()
	)
	row.add_child(remove)
	return row


## "game.zip" for macOS, "game.exe" for Windows, "game.x86_64" for Linux.
func _default_output_name(preset: String) -> String:
	var lower := preset.to_lower()
	if "mac" in lower:
		return "game.zip"
	if "windows" in lower:
		return "game.exe"
	return "game.x86_64"


# ---------------------------------------------------------------------------
# Build & Publish pipeline
# ---------------------------------------------------------------------------

func _on_build_publish_pressed() -> void:
	if _is_busy or _selected_index < 0:
		return
	var p := _projects[_selected_index]
	var depots: Array = p["depots"]
	var godot: String = p.get("godot_binary", "")
	var steamcmd: String = %SteamCmdBinary.text

	if p["app_id"].is_empty():
		log_line("Steam App ID is required.", COLOR_ERR)
		return
	if depots.is_empty():
		log_line("Add at least one depot row.", COLOR_ERR)
		return
	for d in depots:
		if d["preset"].is_empty() or d["depot_id"].is_empty() or d["output"].is_empty():
			log_line("Every depot row needs a preset, a depot ID and an export file name.", COLOR_ERR)
			return
	if not FileAccess.file_exists(godot):
		log_line("Godot binary not found: %s" % godot, COLOR_ERR)
		return
	if not FileAccess.file_exists(steamcmd):
		log_line("SteamCMD binary not found: %s" % steamcmd, COLOR_ERR)
		return
	if %SteamUsername.text.strip_edges().is_empty():
		log_line("Enter a Steam username.", COLOR_ERR)
		return

	_set_busy(true)
	log_line("══ Build & Publish: %s (App %s) ══" % [p["name"], p["app_id"]], COLOR_OK)

	var build_dir := OS.get_user_data_dir().path_join("builds").path_join(p["app_id"])
	var content_root := build_dir.path_join("content")
	_remove_dir_recursive(content_root)
	DirAccess.make_dir_recursive_absolute(build_dir.path_join("output"))

	# 1) Export one preset per depot.
	for d in depots:
		var depot_dir := content_root.path_join(d["depot_id"])
		DirAccess.make_dir_recursive_absolute(depot_dir)
		var out_path := depot_dir.path_join(d["output"])
		log_line("── Exporting '%s' → depot %s" % [d["preset"], d["depot_id"]], COLOR_OK)

		var code := await run_process(godot, [
			"--headless",
			"--path", p["path"],
			"--export-release", d["preset"],
			out_path,
		])
		if code != 0 or not FileAccess.file_exists(out_path):
			log_line("Export of '%s' failed." % d["preset"], COLOR_ERR)
			_set_busy(false)
			return

		# macOS exports are zipped .app bundles – unpack so Steam ships the bundle itself.
		if out_path.ends_with(".zip"):
			var ok := await _unzip_in_place(out_path, depot_dir)
			if not ok:
				_set_busy(false)
				return

	# 2) Write the SteamCMD build script.
	var vdf_path := build_dir.path_join("app_build.vdf")
	_write_app_build_vdf(vdf_path, p, build_dir)
	log_line("Wrote %s" % vdf_path, COLOR_INFO)

	# 3) Upload with SteamCMD.
	var steam_args := _steam_login_args()
	steam_args.append_array(["+run_app_build", vdf_path, "+quit"])
	var upload_code := await run_process(steamcmd, steam_args)
	if upload_code != 0:
		log_line("SteamCMD upload failed (exit code %d)." % upload_code, COLOR_ERR)
	elif p["branch"].is_empty():
		log_line("Upload complete. Set the build live in Steamworks → SteamPipe → Builds.", COLOR_OK)
	else:
		log_line("Upload complete and set live on branch '%s'." % p["branch"], COLOR_OK)
	_set_busy(false)


func _unzip_in_place(zip_path: String, dest_dir: String) -> bool:
	var host := OS.get_name()
	if host == "macOS" or host == "Linux":
		# System unzip preserves the executable bits inside the .app bundle.
		var code := await run_process("/usr/bin/unzip", ["-o", "-q", zip_path, "-d", dest_dir])
		if code != 0:
			log_line("unzip failed.", COLOR_ERR)
			return false
	else:
		var reader := ZIPReader.new()
		if reader.open(zip_path) != OK:
			log_line("Could not open %s" % zip_path, COLOR_ERR)
			return false
		for f in reader.get_files():
			var target := dest_dir.path_join(f)
			if f.ends_with("/"):
				DirAccess.make_dir_recursive_absolute(target)
				continue
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			var fa := FileAccess.open(target, FileAccess.WRITE)
			fa.store_buffer(reader.read_file(f))
			fa.close()
		reader.close()
		log_line("Unpacked with ZIPReader – executable bits are NOT preserved on this host.", COLOR_WARN)
	DirAccess.remove_absolute(zip_path)
	log_line("Unpacked %s" % zip_path.get_file(), COLOR_INFO)
	return true


func _write_app_build_vdf(path: String, p: Dictionary, build_dir: String) -> void:
	var lines: PackedStringArray = [
		'"AppBuild"',
		'{',
		'\t"AppID" "%s"' % p["app_id"],
		'\t"Desc" "%s"' % p["description"].replace('"', "'"),
		'\t"BuildOutput" "%s"' % build_dir.path_join("output"),
		'\t"ContentRoot" "%s"' % build_dir.path_join("content"),
	]
	if not p["branch"].is_empty():
		lines.append('\t"SetLive" "%s"' % p["branch"])
	lines.append('\t"Depots"')
	lines.append('\t{')
	for d in p["depots"]:
		lines.append_array([
			'\t\t"%s"' % d["depot_id"],
			'\t\t{',
			'\t\t\t"ContentRoot" "%s"' % build_dir.path_join("content").path_join(d["depot_id"]),
			'\t\t\t"FileMapping"',
			'\t\t\t{',
			'\t\t\t\t"LocalPath" "*"',
			'\t\t\t\t"DepotPath" "."',
			'\t\t\t\t"recursive" "1"',
			'\t\t\t}',
			'\t\t}',
		])
	lines.append('\t}')
	lines.append('}')
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()


func _remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	dir.include_hidden = true
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for d in dir.get_directories():
		_remove_dir_recursive(path.path_join(d))
	DirAccess.remove_absolute(path)


# ---------------------------------------------------------------------------
# Steam auth + TOTP
# ---------------------------------------------------------------------------

## Generates a Steam Guard code from the base64 shared_secret, same algorithm
## as the steam-totp action from the old GitHub workflow.
static func steam_totp(shared_secret_b64: String, unix_time: int = -1) -> String:
	if unix_time < 0:
		unix_time = int(Time.get_unix_time_from_system())
	var key := Marshalls.base64_to_raw(shared_secret_b64.strip_edges())
	if key.is_empty():
		return ""

	var counter := unix_time / 30
	var msg := PackedByteArray()
	msg.resize(8)
	for i in 8:
		msg[7 - i] = (counter >> (8 * i)) & 0xFF

	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA1, key)
	hmac.update(msg)
	var digest := hmac.finish()

	var offset := digest[19] & 0x0F
	var code: int = ((digest[offset] & 0x7F) << 24) \
		| (digest[offset + 1] << 16) \
		| (digest[offset + 2] << 8) \
		| digest[offset + 3]

	var out := ""
	for i in 5:
		out += STEAM_TOTP_ALPHABET[code % STEAM_TOTP_ALPHABET.length()]
		code /= STEAM_TOTP_ALPHABET.length()
	return out


func _current_guard_code() -> String:
	var secret: String = %SteamSharedSecret.text
	if not secret.strip_edges().is_empty():
		return steam_totp(secret)
	return %SteamGuardCode.text.strip_edges()


## SteamCMD login arguments. After one successful login SteamCMD caches its
## session; with a shared secret every later login also gets a fresh code, so
## the flow never needs manual input again.
func _steam_login_args() -> PackedStringArray:
	var args := PackedStringArray()
	var code := _current_guard_code()
	if not code.is_empty():
		args.append_array(["+set_steam_guard_code", code])
	args.append_array(["+login", %SteamUsername.text.strip_edges()])
	var password: String = %SteamPassword.text
	if not password.is_empty():
		args.append(password)
	return args


func _update_totp_status() -> void:
	var secret: String = %SteamSharedSecret.text
	if secret.strip_edges().is_empty():
		return
	var code := steam_totp(secret)
	if code.is_empty():
		%SteamStatusLabel.text = "Shared secret is not valid base64"
		return
	var seconds_left := 30 - int(Time.get_unix_time_from_system()) % 30
	%SteamStatusLabel.text = "TOTP %s  (%ds)" % [code, seconds_left]


func _on_steam_login_pressed() -> void:
	if _is_busy:
		return
	if %SteamUsername.text.strip_edges().is_empty():
		log_line("Enter a Steam username.", COLOR_ERR)
		return
	if not FileAccess.file_exists(%SteamCmdBinary.text):
		log_line("SteamCMD binary path is invalid.", COLOR_ERR)
		return
	_set_busy(true)
	var args := _steam_login_args()
	args.append("+quit")
	var code := await run_process(%SteamCmdBinary.text, args)
	if code == 0:
		log_line("Steam login OK – session cached by SteamCMD.", COLOR_OK)
		%SteamGuardCode.text = ""
		if not %RememberPassword.button_pressed:
			%SteamPassword.text = ""
	else:
		log_line("Steam login failed (exit code %d)." % code, COLOR_ERR)
	_set_busy(false)


# ---------------------------------------------------------------------------
# Process runner – streams stdout/stderr into the console live
# ---------------------------------------------------------------------------

## Runs [param exe] with [param args] and returns its exit code once done.
## Output is streamed to the console as it arrives. Passwords are masked.
func run_process(exe: String, args: PackedStringArray) -> int:
	log_line("$ %s %s" % [exe, " ".join(_redact(args))], COLOR_CMD)

	var info := OS.execute_with_pipe(exe, args, false)
	if info.is_empty():
		log_line("Failed to start process.", COLOR_ERR)
		return -1

	var pid: int = info["pid"]
	var stdio: FileAccess = info["stdio"]
	var stderr: FileAccess = info["stderr"]

	_reader_threads.clear()
	for pipe: FileAccess in [stdio, stderr]:
		var t := Thread.new()
		t.start(_pipe_reader.bind(pipe, pipe == stderr))
		_reader_threads.append(t)

	while OS.is_process_running(pid):
		await get_tree().process_frame

	var exit_code := OS.get_process_exit_code(pid)
	stdio.close()
	stderr.close()
	for t in _reader_threads:
		t.wait_to_finish()
	_reader_threads.clear()

	log_line("Process exited with code %d" % exit_code, COLOR_OK if exit_code == 0 else COLOR_ERR)
	return exit_code


func _pipe_reader(pipe: FileAccess, is_stderr: bool) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line := pipe.get_line()
		if line.is_empty():
			continue
		log_line.call_deferred(line, COLOR_WARN if is_stderr else COLOR_INFO)


## Hides the password and guard code in the echoed command line.
func _redact(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < args.size():
		out.append(args[i])
		if args[i] == "+set_steam_guard_code" or args[i] == "+login":
			if args[i] == "+login" and i + 1 < args.size():
				out.append(args[i + 1])  # username is fine to show
				i += 1
			if i + 1 < args.size() and not args[i + 1].begins_with("+"):
				out.append("•••••")
				i += 1
		i += 1
	return out


# ---------------------------------------------------------------------------
# Console
# ---------------------------------------------------------------------------

## Append a line to the debug console and keep it scrolled to the bottom.
func log_line(text: String, color: String = COLOR_INFO) -> void:
	var safe := text.replace("[", "[lb]")
	var stamp := Time.get_time_string_from_system()
	%Console.append_text("[color=#666]%s[/color] [color=%s]%s[/color]\n" % [stamp, color, safe])
	_scroll_console_to_bottom()


func _scroll_console_to_bottom() -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = %ConsoleScroll
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(bar.max_value)


func _set_busy(busy: bool) -> void:
	_is_busy = busy
	%BuildPublishButton.disabled = busy
	%BuildPublishButton.text = "Working…" if busy else "Build & Publish"
	%SteamLoginButton.disabled = busy
	%NewGameButton.disabled = busy
	%RemoveProjectButton.disabled = busy


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _read_project_name(dir: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(dir.path_join("project.godot")) == OK:
		return cfg.get_value("application", "config/name", dir.get_file())
	return dir.get_file()


func _save_projects() -> void:
	var cfg := ConfigFile.new()
	for i in _projects.size():
		for key in _projects[i]:
			cfg.set_value("project_%d" % i, key, _projects[i][key])
	cfg.save(PROJECTS_FILE)


func _load_projects() -> void:
	_projects.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PROJECTS_FILE) != OK:
		return
	for section in cfg.get_sections():
		var p := {}
		for key in cfg.get_section_keys(section):
			p[key] = cfg.get_value(section, key)
		if not p.has("depots"):
			p["depots"] = []
		_projects.append(p)


## The shared secret is persisted (it is what makes unattended logins work).
## The password is only persisted when "Remember password" is on. Both are
## plain text in user://settings.cfg – keep that file private.
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tools", "steamcmd_binary", %SteamCmdBinary.text)
	cfg.set_value("steam", "username", %SteamUsername.text)
	cfg.set_value("steam", "shared_secret", %SteamSharedSecret.text)
	cfg.set_value("steam", "remember_password", %RememberPassword.button_pressed)
	cfg.set_value("steam", "password", %SteamPassword.text if %RememberPassword.button_pressed else "")
	cfg.save(SETTINGS_FILE)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	%SteamCmdBinary.text = cfg.get_value("tools", "steamcmd_binary", "")
	%SteamUsername.text = cfg.get_value("steam", "username", "")
	%SteamSharedSecret.text = cfg.get_value("steam", "shared_secret", "")
	%RememberPassword.button_pressed = cfg.get_value("steam", "remember_password", false)
	%SteamPassword.text = cfg.get_value("steam", "password", "")
	if not %SteamUsername.text.is_empty():
		%SteamStatusLabel.text = "Using cached SteamCMD session for %s" % %SteamUsername.text
