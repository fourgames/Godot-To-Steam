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

## Valve's official SteamCMD archives; static, unauthenticated downloads.
const STEAMCMD_DOCS_URL := "https://developer.valvesoftware.com/wiki/SteamCMD"
const STEAMCMD_URLS := {
	"Windows": "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip",
	"macOS": "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz",
	"Linux": "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz",
}

## Godot editor visibility icons (public/icons/editor, MIT) for the show/hide toggles.
const EYE_VISIBLE := preload("res://public/icons/editor/visibility_visible.svg")
const EYE_HIDDEN := preload("res://public/icons/editor/visibility_hidden.svg")

## Smallest window in logical points. Below CONSOLE_MIN_WIDTH the console hides
## itself and comes back once there is room again; the sidebar keeps a short
## games list and scrolls the account fields when the window is very short.
const MIN_WINDOW_SIZE := Vector2i(500, 340)
const CONSOLE_MIN_WIDTH := 920.0
const GAMES_LIST_MIN_HEIGHT := 88.0

## Whether the user wants the console open (independent of whether it fits).
var _console_wanted := true

# Console / status colours (bbcode + Color). Kept in sync with public/theme.tres.
const COLOR_INFO := "#c9c5bc"
const COLOR_CMD := "#8ab4f8"
const COLOR_OK := "#7ec98f"
const COLOR_WARN := "#e3b341"
const COLOR_ERR := "#ef7f75"
const COLOR_STAMP := "#5e5a53"
const COLOR_TEXT := "#ebe7df"
const COLOR_TEXT_2 := "#a8a49b"
const COLOR_MUTED := "#6e6a62"

## Each project is a Dictionary:
## {
##   name: String, path: String, godot_binary: String,
##   app_id: String, branch: String, description: String,
##   depots: Array[Dictionary]  -> { preset: String, depot_id: String, output: String }
## }
var _projects: Array[Dictionary] = []
var _selected_index: int = -1
## Project names already sent to the Steam store for an App ID lookup, so
## switching between projects does not repeat the same search.
var _app_id_lookups_done: Dictionary = {}
var _project_button_group := ButtonGroup.new()
# Thin accent line shown between sidebar rows while a project is being dragged.
var _drop_line: Panel
var _is_busy := false
var _preset_names: PackedStringArray
## Platform of each entry in _preset_names, as written in export_presets.cfg.
var _preset_platforms: PackedStringArray
## True once _check_godot_version found a binary matching the project. While
## false the banner shows a Godot problem, which outranks depot warnings.
var _godot_ok := false

## Theme variations that draw a red border around a field that failed validation.
const ERROR_FIELD := &"ErrorField"
const ERROR_OPTION := &"ErrorOption"
## depot index -> { "preset": true, "depot_id": true, "output": true } for the
## depot fields marked red at the last submit. Rows are rebuilt from data, so
## the marks live here rather than on the controls.
var _depot_errors: Dictionary = {}

# Reader threads for the currently running child process.
var _reader_threads: Array[Thread] = []
## While true, stdout lines from run_process are also collected in _capture
## so a caller can parse them (see run_process_capture).
var _capturing := false
var _capture: PackedStringArray

# SteamCMD downloader state.
var _steamcmd_http: HTTPRequest
var _steamcmd_archive := ""
var _steamcmd_downloading := false


func _ready() -> void:
	_apply_display_scale()
	get_viewport().size_changed.connect(_on_window_resized)
	_on_window_resized()
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%AddGameButton.pressed.connect(_on_new_game_pressed)
	%EmptyNewGameButton.pressed.connect(_on_new_game_pressed)
	%ConsoleToggle.toggled.connect(_set_console_visible)
	%HideConsoleButton.pressed.connect(_set_console_visible.bind(false))
	%SteamAccountHeader.pressed.connect(_toggle_steam_fields)
	%DismissBannerButton.pressed.connect(func() -> void: %StatusBanner.visible = false)
	%BrowseButton.pressed.connect(_on_browse_pressed)
	%RemoveProjectButton.pressed.connect(_on_remove_project_pressed)
	%ProjectDialog.dir_selected.connect(_on_project_dir_selected)
	%BuildPublishButton.pressed.connect(_on_build_publish_pressed)
	%ClearConsoleButton.pressed.connect(%Console.clear)
	%SteamLoginButton.pressed.connect(_on_steam_login_pressed)
	%AddDepotButton.pressed.connect(_on_add_depot_pressed)
	%FetchDepotsButton.pressed.connect(_on_fetch_depots_pressed)
	%CheckGodotButton.pressed.connect(_on_check_godot_pressed)
	%BrowseGodotButton.pressed.connect(func() -> void: %GodotDialog.popup_centered())
	%GodotDialog.file_selected.connect(_on_godot_binary_selected)
	%GodotDialog.dir_selected.connect(_on_godot_binary_selected)
	%DetectSteamCmdButton.pressed.connect(_on_detect_steamcmd_pressed)
	%BrowseSteamCmdButton.pressed.connect(func() -> void: %SteamCmdDialog.popup_centered())
	%SteamCmdDialog.file_selected.connect(_on_steamcmd_selected)
	%DownloadSteamCmdButton.pressed.connect(_on_download_steamcmd_pressed)
	%SteamCmdWebsiteButton.pressed.connect(func() -> void: OS.shell_open(STEAMCMD_DOCS_URL))
	%TotpTimer.timeout.connect(_update_totp_status)
	%SteamAssets.header_ready.connect(_on_header_ready)
	%SteamAssets.header_failed.connect(_on_header_failed)
	%SteamAssets.app_id_found.connect(_on_app_id_found)
	%RefreshHeaderButton.pressed.connect(_refresh_steam_header.bind(true))
	%HeaderDebounce.timeout.connect(_refresh_steam_header.bind(false))
	%SteamCard.resized.connect(_on_steam_card_resized)
	%HeaderImage.resized.connect(_update_header_shader_size)

	# Per-project fields write straight back into the selected project.
	%GodotBinary.text_changed.connect(func(t: String) -> void:
		_commit_field("godot_binary", t)
		_set_field_error(%GodotBinary, false)
	)
	%AppId.text_changed.connect(func(t: String) -> void:
		_commit_field("app_id", t)
		_set_field_error(%AppId, false)
		%HeaderDebounce.start()
	)
	%Branch.text_changed.connect(func(t: String) -> void: _commit_field("branch", t))
	%BuildDescription.text_changed.connect(func(t: String) -> void: _commit_field("description", t))
	%BuildDescription.text_submitted.connect(func(_t: String) -> void: _on_build_publish_pressed())

	# Global settings.
	%SteamCmdBinary.text_changed.connect(func(_t: String) -> void:
		_save_settings()
		_check_steamcmd()
		_set_field_error(%SteamCmdBinary, false)
	)
	%SteamUsername.text_changed.connect(func(_t: String) -> void:
		_save_settings()
		_update_steam_header()
		_set_field_error(%SteamUsername, false)
	)
	%SteamPassword.text_changed.connect(func(_t: String) -> void: _save_settings())
	%SteamSharedSecret.text_changed.connect(func(_t: String) -> void:
		_save_settings()
		_update_steam_header()
	)
	%RememberPassword.toggled.connect(func(_on: bool) -> void: _save_settings())
	%RememberSharedSecret.toggled.connect(func(_on: bool) -> void: _save_settings())
	_bind_secret_toggle(%TogglePasswordVisible, %SteamPassword, "password")
	_bind_secret_toggle(%ToggleSecretVisible, %SteamSharedSecret, "shared secret")

	_steamcmd_http = HTTPRequest.new()
	_steamcmd_http.timeout = 0
	_steamcmd_http.use_threads = true
	_steamcmd_http.request_completed.connect(_on_steamcmd_download_completed)
	add_child(_steamcmd_http)

	_load_settings()
	_check_steamcmd()
	_drop_line = Panel.new()
	_drop_line.theme_type_variation = &"Dot"
	_drop_line.self_modulate = Color(COLOR_OK)
	_drop_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_line.top_level = true
	_drop_line.visible = false
	add_child(_drop_line)

	_load_projects()
	_rebuild_sidebar()
	_show_project(-1)
	_update_totp_status()
	_update_steam_header()
	# First run: open the account panel so the user sees what to fill in.
	%SteamFieldsScroll.visible = %SteamUsername.text.strip_edges().is_empty()
	_update_steam_chevron()
	_fit_sidebar.call_deferred()
	log_line("Godot to Steam ready.", COLOR_OK)


## Render the UI at the OS scale factor so it is the same physical size on a
## Retina/HiDPI screen as on a 1x screen (Godot draws in device pixels when
## stretch mode is disabled). Runs with an unscaled window when embedded in
## the editor, whose panel owns the window size.
func _apply_display_scale() -> void:
	var ui_scale := DisplayServer.screen_get_scale()
	match OS.get_name():
		"Windows":
			ui_scale = DisplayServer.screen_get_dpi() / 96.0
		"Linux":
			ui_scale = maxf(ui_scale, DisplayServer.screen_get_dpi() / 96.0)
	ui_scale = clampf(snappedf(ui_scale, 0.25), 1.0, 3.0)

	var window := get_window()
	window.min_size = Vector2i(Vector2(MIN_WINDOW_SIZE) * ui_scale)
	if is_equal_approx(ui_scale, 1.0):
		return
	window.content_scale_factor = ui_scale

	# Embedded game view: the "screen" is the editor panel – never resize it.
	if DisplayServer.screen_get_size() == DisplayServer.window_get_size():
		return
	var target := Vector2i(Vector2(1440, 900) * ui_scale)
	if window.size.x < target.x or window.size.y < target.y:
		window.size = target
		window.move_to_center()


func _on_window_resized() -> void:
	_apply_console_visibility()
	_fit_sidebar.call_deferred()


## The console only shows when the user wants it and the window is wide enough.
func _apply_console_visibility() -> void:
	var fits := get_viewport().get_visible_rect().size.x >= CONSOLE_MIN_WIDTH
	%ConsolePanel.visible = _console_wanted and fits
	%ConsoleToggle.disabled = not fits
	%ConsoleToggle.set_pressed_no_signal(%ConsolePanel.visible)
	%ConsoleToggle.tooltip_text = "Window is too narrow for the console" if not fits else "Show or hide the console"


## Keeps the account panel pinned to the bottom of the sidebar: its fields get
## as much height as they need, but never more than what is left after the nav,
## the games header, a 120px games list and the account header.
func _fit_sidebar() -> void:
	var scroll: ScrollContainer = %SteamFieldsScroll
	if not scroll.visible:
		return
	var fields_h: float = %SteamFields.get_combined_minimum_size().y
	var fixed: float = %NavMargin.size.y + %GamesHeader.size.y + GAMES_LIST_MIN_HEIGHT \
		+ %SteamAccountHeader.size.y + 8.0 + 18.0  # AuthLayout separation + footer margins
	var available := get_viewport().get_visible_rect().size.y - fixed
	scroll.custom_minimum_size.y = clampf(available, minf(48.0, fields_h), fields_h)


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
		ProjectIcons.invalidate(_projects[_selected_index]["path"])
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

	_app_id_lookups_done.erase(_projects[_selected_index]["name"])
	_save_projects()
	_rebuild_sidebar()
	_show_project(_selected_index)


## Fills in the App ID from the Steam store when the project name matches a
## published app exactly and the user has not typed an ID yet. Each name is
## looked up once per run.
func _suggest_app_id(p: Dictionary) -> void:
	var project_name: String = p["name"]
	if not str(p.get("app_id", "")).strip_edges().is_empty() or _app_id_lookups_done.has(project_name):
		return
	_app_id_lookups_done[project_name] = true
	log_line("Looking up '%s' on the Steam store for an App ID…" % project_name, COLOR_INFO)
	%SteamAssets.find_app_id(project_name)


func _on_app_id_found(project_name: String, app_id: String) -> void:
	if app_id.is_empty():
		log_line("No Steam app is named exactly '%s'; enter the App ID by hand." % project_name, COLOR_INFO)
		return
	for i in _projects.size():
		var p := _projects[i]
		if p["name"] != project_name:
			continue
		if not str(p.get("app_id", "")).strip_edges().is_empty():
			continue
		if p.get("app_id", "") == app_id:
			continue
		p["app_id"] = app_id
		log_line("Steam lists '%s' as App %s, filled it in." % [project_name, app_id], COLOR_OK)
		if i == _selected_index:
			%AppId.text = app_id  # Setting text does not emit text_changed.
			_set_field_error(%AppId, false)
			_refresh_steam_header(false)
	_save_projects()


func _rebuild_sidebar() -> void:
	for child in %ProjectList.get_children():
		if child != %NoGamesLabel:
			child.queue_free()
	%NoGamesLabel.visible = _projects.is_empty()

	for i in _projects.size():
		%ProjectList.add_child(_make_project_row(i, _projects[i]))
	_refresh_sidebar_selection()


## A sidebar row: status dot · project icon · project name · required Godot version.
## The Button itself has no text; the children ignore the mouse so hover and
## click land on the button, which keeps the ButtonGroup selection working.
func _make_project_row(index: int, p: Dictionary) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"SidebarItem"
	btn.toggle_mode = true
	btn.button_group = _project_button_group
	btn.tooltip_text = p["path"]
	btn.custom_minimum_size.y = 34
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.button_pressed = (index == _selected_index)
	btn.pressed.connect(_show_project.bind(index))
	btn.set_drag_forwarding(
		_get_row_drag_data.bind(index, btn),
		_can_drop_on_row.bind(btn),
		_drop_on_row.bind(btn))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	btn.add_child(row)

	var dot := Panel.new()
	dot.theme_type_variation = &"Dot"
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var binary: String = p.get("godot_binary", "")
	dot.self_modulate = Color(COLOR_OK) if not binary.is_empty() and FileAccess.file_exists(binary) else Color(COLOR_MUTED)
	dot.tooltip_text = "Godot binary configured" if dot.self_modulate == Color(COLOR_OK) else "No Godot binary yet"
	row.add_child(dot)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = ProjectIcons.load_texture(p["path"])
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = p["name"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 13)
	row.add_child(name_label)
	btn.set_meta("name_label", name_label)

	var version := Label.new()
	version.theme_type_variation = &"Caption"
	version.text = _read_required_godot_version(p["path"])
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(version)
	return btn


# --- Drag-to-reorder -------------------------------------------------------

## Drag payload for a sidebar row plus a translucent ghost of the row that
## follows the cursor.
func _get_row_drag_data(_at: Vector2, index: int, btn: Button) -> Variant:
	if index < 0 or index >= _projects.size():
		return null
	var ghost := _make_project_row(index, _projects[index])
	ghost.button_group = null  # Must not steal the real selection.
	ghost.toggle_mode = false
	ghost.button_pressed = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = btn.size
	ghost.size = btn.size
	ghost.modulate.a = 0.7
	btn.set_drag_preview(ghost)
	return {"type": "project_row", "index": index}


## Called continuously while a drag hovers a row: also moves the drop line.
func _can_drop_on_row(at: Vector2, data: Variant, btn: Button) -> bool:
	if not (data is Dictionary and data.get("type") == "project_row"):
		return false
	var below := at.y > btn.size.y * 0.5
	_drop_line.size = Vector2(btn.size.x, 2)
	_drop_line.global_position = Vector2(
		btn.global_position.x,
		btn.global_position.y + (btn.size.y if below else 0.0) - 1.0)
	_drop_line.visible = true
	return true


func _drop_on_row(at: Vector2, data: Variant, btn: Button) -> void:
	_drop_line.visible = false
	# Position of the target among the sidebar rows (NoGamesLabel is not a Button).
	var to := 0
	for child in %ProjectList.get_children():
		if child == btn:
			break
		if child is Button and not child.is_queued_for_deletion():
			to += 1
	if at.y > btn.size.y * 0.5:
		to += 1
	_move_project(int(data["index"]), to)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_line != null:
		_drop_line.visible = false


## Moves project [param from] to insertion slot [param to] (0.._projects.size()),
## keeping the currently selected project selected.
func _move_project(from: int, to: int) -> void:
	if to > from:
		to -= 1
	if from == to or from < 0 or from >= _projects.size():
		return
	to = clampi(to, 0, _projects.size() - 1)
	var p := _projects[from]
	_projects.remove_at(from)
	_projects.insert(to, p)
	if _selected_index == from:
		_selected_index = to
	elif from < _selected_index and to >= _selected_index:
		_selected_index -= 1
	elif from > _selected_index and to <= _selected_index:
		_selected_index += 1
	_save_projects()
	_rebuild_sidebar()


## Selected row gets the bright text colour, the rest stay secondary.
func _refresh_sidebar_selection() -> void:
	for child in %ProjectList.get_children():
		if child is Button and child.has_meta("name_label"):
			var label: Label = child.get_meta("name_label")
			label.add_theme_color_override("font_color", Color(COLOR_TEXT) if child.button_pressed else Color(COLOR_TEXT_2))


## Switch the main view to project [param index]; -1 shows the empty state.
func _show_project(index: int) -> void:
	_selected_index = index
	var has_project := index >= 0 and index < _projects.size()
	%EmptyState.visible = not has_project
	%ProjectSettings.visible = has_project
	%ComposerBox.visible = has_project
	%StatusBanner.visible = false
	_clear_project_errors()
	_refresh_sidebar_selection()
	if not has_project:
		%HeaderDebounce.stop()
		return

	var p := _projects[index]
	%ProjectTitle.text = p["name"]
	%TitleMark.texture = ProjectIcons.load_texture(p["path"])
	%ProjectPath.text = p["path"]
	%GodotBinary.text = p.get("godot_binary", "")
	%AppId.text = p.get("app_id", "")
	%Branch.text = p.get("branch", "")
	%BuildDescription.text = p.get("description", "")

	_read_presets(p["path"])
	if not _has_presets():
		log_line("'%s' has no export presets. Open it in Godot → Project → Export… and add one, then reselect the project." % p["name"], COLOR_WARN)
	_rebuild_depot_rows()
	_check_godot_version()
	_refresh_steam_header(false)

	log_line("Selected project: %s" % p["name"], COLOR_INFO)
	_suggest_app_id(p)


## Banner above the build bar for things the user should fix before publishing.
func _show_status(text: String, color: String) -> void:
	%BannerLabel.text = text
	%BannerDot.self_modulate = Color(color)
	%StatusBanner.visible = true


func _commit_field(key: String, value: String) -> void:
	if _selected_index < 0:
		return
	_projects[_selected_index][key] = value
	_save_projects()


# ---------------------------------------------------------------------------
# Form validation
# ---------------------------------------------------------------------------

## Draws (or removes) the red border on a field that failed validation.
func _set_field_error(control: Control, error: bool) -> void:
	if control is OptionButton:
		control.theme_type_variation = ERROR_OPTION if error else &""
	else:
		control.theme_type_variation = ERROR_FIELD if error else &""


## Forgets every red mark on the per-project fields (switching project).
func _clear_project_errors() -> void:
	_depot_errors.clear()
	_set_field_error(%GodotBinary, false)
	_set_field_error(%AppId, false)


func _mark_depot_error(index: int, key: String) -> void:
	if not _depot_errors.has(index):
		_depot_errors[index] = {}
	_depot_errors[index][key] = true


func _clear_depot_error(index: int, key: String) -> void:
	if _depot_errors.has(index):
		_depot_errors[index].erase(key)


## Checks the Steam account fields both Test login and Build & Publish need,
## marks the failing ones red and opens the account panel so they are visible.
func _validate_login_fields() -> bool:
	var ok := true
	if %SteamUsername.text.strip_edges().is_empty():
		log_line("Enter a Steam username.", COLOR_ERR)
		_set_field_error(%SteamUsername, true)
		ok = false
	if _resolve_steamcmd(%SteamCmdBinary.text).is_empty():
		if %ProjectSettings.visible:
			log_line("SteamCMD not found – use Detect, Browse or Download SteamCMD in the game's SteamCMD card.", COLOR_ERR)
		else:
			log_line("SteamCMD not found – select or add a game, then set it in the SteamCMD card.", COLOR_ERR)
		_set_field_error(%SteamCmdBinary, true)
		ok = false
	if not ok and not %SteamFieldsScroll.visible:
		%SteamFieldsScroll.visible = true
		_update_steam_chevron()
	return ok


## Checks everything Build & Publish needs, marks every failing field red and
## logs one line per problem. Duplicate depot IDs are marked but only warn.
func _validate_publish_form() -> bool:
	var p := _projects[_selected_index]
	var depots: Array = p["depots"]
	var godot: String = p.get("godot_binary", "")
	var ok := true
	_depot_errors.clear()

	if p["app_id"].strip_edges().is_empty():
		log_line("Steam App ID is required.", COLOR_ERR)
		_set_field_error(%AppId, true)
		ok = false
	if godot.is_empty():
		log_line("Pick a Godot binary (or click Detect).", COLOR_ERR)
		_set_field_error(%GodotBinary, true)
		ok = false
	elif not FileAccess.file_exists(godot):
		log_line("Godot binary not found: %s" % godot, COLOR_ERR)
		_set_field_error(%GodotBinary, true)
		ok = false
	if depots.is_empty():
		log_line("Add at least one depot row.", COLOR_ERR)
		ok = false
	if not _has_presets():
		log_line("No export presets found in %s. Add one in Godot → Project → Export… first." % p["path"].path_join("export_presets.cfg"), COLOR_ERR)
		ok = false

	var row_incomplete := false
	for i in depots.size():
		var d: Dictionary = depots[i]
		for key in ["preset", "depot_id", "output"]:
			if str(d[key]).strip_edges().is_empty():
				_mark_depot_error(i, key)
				row_incomplete = true
	if row_incomplete:
		log_line("Every depot row needs a preset, a depot ID and an export file name.", COLOR_ERR)
		ok = false

	var dupes := _duplicate_depot_ids()
	if not dupes.is_empty():
		log_line(_duplicate_depot_message(dupes), COLOR_WARN)
		for i in depots.size():
			if dupes.has(depots[i]["depot_id"].strip_edges()):
				_mark_depot_error(i, "depot_id")

	if not _validate_login_fields():
		ok = false
	_rebuild_depot_rows()
	return ok


# ---------------------------------------------------------------------------
# Steam library capsule
# ---------------------------------------------------------------------------

## Library capsules are 600x900 (2x: 1200x1800). The frame sits left of the
## Steam card, matches the card's height and keeps the capsule aspect ratio
## so image and placeholder share one size.
const CAPSULE_ASPECT := 600.0 / 900.0


func _on_steam_card_resized() -> void:
	var height: float = %SteamCard.size.y
	var wanted := Vector2(roundf(height * CAPSULE_ASPECT), height)
	if not %HeaderFrame.custom_minimum_size.is_equal_approx(wanted):
		%HeaderFrame.custom_minimum_size = wanted


func _update_header_shader_size() -> void:
	var mat := %HeaderImage.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("size", %HeaderImage.size)


func _current_app_id() -> String:
	if _selected_index < 0 or _selected_index >= _projects.size():
		return ""
	return str(_projects[_selected_index].get("app_id", "")).strip_edges()


## Shows the selected project's Steam library capsule beside the Steam card. Cached
## images are reused unless [param force] is set (the Refresh button).
func _refresh_steam_header(force: bool) -> void:
	%HeaderDebounce.stop()
	var app_id := _current_app_id()
	if app_id.is_empty():
		%SteamHeader.visible = false
		return
	if not app_id.is_valid_int() or int(app_id) <= 0:
		%SteamHeader.visible = false
		log_line("App ID '%s' is not a number, so no Steam capsule can be fetched." % app_id, COLOR_WARN)
		return

	%SteamHeader.visible = true
	_on_steam_card_resized()
	# Keep the previous image while a different app loads only if it is the same app.
	if %HeaderImage.get_meta("app_id", "") != app_id:
		%HeaderImage.texture = null
		%HeaderImage.visible = false
		%PlaceholderLabel.text = "Fetching Steam capsule for App %s…" % app_id
		%HeaderPlaceholder.visible = true
	%HeaderCaption.text = "Fetching…"
	%RefreshHeaderButton.disabled = true
	if force:
		log_line("Refreshing Steam capsule for App %s" % app_id, COLOR_INFO)
	%SteamAssets.fetch_header(app_id, force)


func _on_header_ready(app_id: String, texture: Texture2D) -> void:
	if app_id != _current_app_id():
		return  # Late answer for a project that is no longer selected.
	%HeaderImage.texture = texture
	%HeaderImage.set_meta("app_id", app_id)
	%HeaderImage.visible = true
	%HeaderPlaceholder.visible = false
	%HeaderCaption.text = "App %s · 600x900" % app_id
	%RefreshHeaderButton.disabled = false
	log_line("Steam capsule ready for App %s" % app_id, COLOR_INFO)


func _on_header_failed(app_id: String, reason: String) -> void:
	if app_id != _current_app_id():
		return
	# A failed refresh keeps the image we already have.
	if %HeaderImage.texture == null:
		%HeaderImage.visible = false
		%PlaceholderLabel.text = "Couldn't find a Steam library capsule for App %s.\n%s" % [app_id, reason]
		%HeaderPlaceholder.visible = true
	%HeaderCaption.text = "Not found (%s)" % reason
	%RefreshHeaderButton.disabled = false
	log_line("Steam capsule for App %s unavailable: %s" % [app_id, reason], COLOR_WARN)


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
		_godot_ok = false
		%GodotVersionLabel.text = "Project requires %s  ·  no binary set" % required
		%GodotVersionDot.self_modulate = Color(COLOR_ERR)
		_show_status("Pick a Godot %s binary (or click Detect) before building." % required, COLOR_ERR)
		return

	var reported := _binary_version(binary)
	var matches := reported.begins_with(required + ".")
	%GodotVersionLabel.text = "Project requires %s  ·  binary reports %s" % [required, reported]
	%GodotVersionDot.self_modulate = Color(COLOR_OK if matches else COLOR_WARN)
	_godot_ok = matches
	if matches:
		_show_preset_status()
	else:
		_show_status("Version mismatch: the project wants Godot %s but the binary is %s." % [required, reported], COLOR_WARN)
		log_line("Godot version mismatch for %s: project wants %s, binary is %s" % [p["name"], required, reported], COLOR_WARN)
	_rebuild_sidebar()


## Banner fallback when Godot itself is fine: warn about missing export presets,
## then about depot IDs shared by several rows.
func _show_preset_status() -> void:
	if not _has_presets():
		_show_status("No export presets found. Open the project in Godot → Project → Export… and add a preset, then reselect the project.", COLOR_WARN)
		return
	var dupes := _duplicate_depot_ids()
	if dupes.is_empty():
		%StatusBanner.visible = false
	else:
		_show_status(_duplicate_depot_message(dupes), COLOR_WARN)


## Re-evaluates the banner after a depot edit without re-probing the Godot
## binary. Does nothing while a Godot problem is showing, since that outranks it.
func _refresh_depot_status() -> void:
	if _godot_ok:
		_show_preset_status()


## Depot IDs used by more than one row of the selected project, ignoring blanks.
func _duplicate_depot_ids() -> PackedStringArray:
	var dupes := PackedStringArray()
	if _selected_index < 0:
		return dupes
	var seen := {}
	for d in _projects[_selected_index]["depots"]:
		var id: String = d["depot_id"].strip_edges()
		if id.is_empty():
			continue
		if seen.has(id) and not dupes.has(id):
			dupes.append(id)
		seen[id] = true
	return dupes


func _duplicate_depot_message(dupes: PackedStringArray) -> String:
	var which := "Depot %s is" % dupes[0] if dupes.size() == 1 else "Depots %s are" % ", ".join(dupes)
	return "%s used by several rows. Steam filters downloads per depot, so every player would get all of those builds. Use one depot per export preset." % which


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

## Fills _preset_names and _preset_platforms from the project's export_presets.cfg.
func _read_presets(project_path: String) -> void:
	_preset_names = PackedStringArray()
	_preset_platforms = PackedStringArray()
	var cfg := ConfigFile.new()
	if cfg.load(project_path.path_join("export_presets.cfg")) != OK:
		return
	var i := 0
	while cfg.has_section("preset.%d" % i):
		var section := "preset.%d" % i
		_preset_names.append(cfg.get_value(section, "name", "preset %d" % i))
		_preset_platforms.append(str(cfg.get_value(section, "platform", "")))
		i += 1


## True when the selected project has at least one preset in export_presets.cfg.
func _has_presets() -> bool:
	return not _preset_names.is_empty()


func _on_add_depot_pressed() -> void:
	if _selected_index < 0:
		return
	_depot_errors.clear()
	var depots: Array = _projects[_selected_index]["depots"]
	var idx := mini(depots.size(), _preset_names.size() - 1)
	var preset := _preset_names[idx] if _preset_names.size() > 0 else ""
	depots.append({"preset": preset, "depot_id": "", "output": _default_output_name(idx)})
	_save_projects()
	_rebuild_depot_rows()
	_refresh_depot_status()


## Asks SteamCMD for the App ID's depot list and appends a row for every depot
## not already in the table, picking a matching export preset by platform.
func _on_fetch_depots_pressed() -> void:
	if _is_busy or _selected_index < 0:
		return
	var app_id: String = %AppId.text.strip_edges()
	if app_id.is_empty() or not app_id.is_valid_int():
		_set_field_error(%AppId, true)
		log_line("Enter a numeric Steam App ID before fetching depots.", COLOR_ERR)
		return
	if not _validate_login_fields():
		return
	var steamcmd := _resolve_steamcmd(%SteamCmdBinary.text)
	_set_busy(true)
	log_line("Fetching depots for App ID %s…" % app_id, COLOR_INFO)
	var args := _steam_login_args()
	# app_info_print is asked twice on purpose: on a fresh SteamCMD cache the
	# first print is often a stub without depots, the second one is complete.
	# The parser uses the last block it finds.
	args.append_array(["+app_info_update", "1", "+app_info_print", app_id, "+app_info_print", app_id, "+quit"])
	var res := await run_process_capture(steamcmd, args)
	if res["code"] != 0:
		log_line("SteamCMD failed (exit code %d); depots not fetched." % res["code"], COLOR_ERR)
		_set_busy(false)
		return
	var found := SteamAppInfo.parse_depots(res["output"], app_id)
	if found.is_empty():
		log_line("No depots found for App ID %s. Check that the account has access to the app and that its depots are published on the Steamworks partner site." % app_id, COLOR_WARN)
		_set_busy(false)
		return
	_merge_fetched_depots(found)
	_set_busy(false)


## Appends the depots from [param found] that are not already in the table.
func _merge_fetched_depots(found: Array[Dictionary]) -> void:
	var depots: Array = _projects[_selected_index]["depots"]
	var existing_ids := {}
	var used_presets := {}
	for d in depots:
		existing_ids[str(d.get("depot_id", "")).strip_edges()] = true
		used_presets[str(d.get("preset", ""))] = true
	var added := PackedStringArray()
	var skipped := 0
	for depot in found:
		if existing_ids.has(depot["depot_id"]):
			skipped += 1
			continue
		var preset_index := _pick_preset_for_oslist(depot["oslist"], used_presets)
		var preset := _preset_names[preset_index] if preset_index >= 0 else ""
		if not preset.is_empty():
			used_presets[preset] = true
		var output := _default_output_name(preset_index) if preset_index >= 0 else "game.zip"
		depots.append({"preset": preset, "depot_id": depot["depot_id"], "output": output})
		added.append("%s (%s)" % [depot["depot_id"], SteamAppInfo.oslist_label(depot["oslist"])])
	if not added.is_empty():
		_depot_errors.clear()
		_save_projects()
		_rebuild_depot_rows()
		_refresh_depot_status()
		log_line("Added %d depot(s): %s" % [added.size(), ", ".join(added)], COLOR_OK)
	if skipped > 0:
		log_line("Skipped %d depot(s) already in the table." % skipped, COLOR_INFO)
	if added.is_empty() and skipped == 0:
		log_line("Nothing to add.", COLOR_INFO)


## Index into _preset_names of the first preset whose platform can serve a
## depot with [param oslist] and that is not in [param used_presets], or -1.
## Presets already assigned to another depot are only reused when nothing
## else matches.
func _pick_preset_for_oslist(oslist: String, used_presets: Dictionary) -> int:
	var fallback := -1
	for i in _preset_platforms.size():
		if not SteamAppInfo.platform_matches(oslist, _preset_platforms[i]):
			continue
		if not used_presets.has(_preset_names[i]):
			return i
		if fallback < 0:
			fallback = i
	return fallback


func _rebuild_depot_rows() -> void:
	for child in %DepotRows.get_children():
		child.queue_free()
	if _selected_index < 0:
		return
	var depots: Array = _projects[_selected_index]["depots"]
	%DepotsEmpty.visible = depots.is_empty()
	%DepotColumns.visible = not depots.is_empty()
	for i in depots.size():
		%DepotRows.add_child(_make_depot_row(i, depots[i]))


## Column widths shared by the header row in the scene and the rows built here.
## Every column expands, so a narrow window shrinks the row instead of pushing
## the content column (and the Steam header above it) wider than the viewport.
const PRESET_STRETCH := 1.6
const DEPOT_ID_MIN_WIDTH := 64.0
const DEPOT_ID_STRETCH := 1.0
const OUTPUT_MIN_WIDTH := 88.0
const OUTPUT_STRETCH := 1.3
## Platform logos are 32px; shrink them to text height in the preset dropdown.
const PRESET_ICON_SIZE := 16


func _make_depot_row(index: int, depot: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var preset := OptionButton.new()
	preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset.size_flags_stretch_ratio = PRESET_STRETCH
	preset.clip_text = true
	preset.add_theme_constant_override("icon_max_width", PRESET_ICON_SIZE)
	preset.get_popup().add_theme_constant_override("icon_max_width", PRESET_ICON_SIZE)
	for i in _preset_names.size():
		var icon := PlatformIcons.for_platform(_preset_platforms[i])
		if icon != null:
			preset.add_icon_item(icon, _preset_names[i])
		else:
			preset.add_item(_preset_names[i])
	if not _has_presets():
		preset.add_item("No export presets")
		preset.set_item_disabled(0, true)
		preset.tooltip_text = "Open the project in Godot → Project → Export… and add a preset, then reselect the project."
	var sel := _preset_names.find(depot["preset"])
	if sel >= 0:
		preset.select(sel)
	var errors: Dictionary = _depot_errors.get(index, {})
	_set_field_error(preset, errors.has("preset"))
	preset.item_selected.connect(func(idx: int) -> void:
		_clear_depot_error(index, "preset")
		var d: Dictionary = _projects[_selected_index]["depots"][index]
		d["preset"] = _preset_names[idx]
		d["output"] = _default_output_name(idx)
		_save_projects()
		_rebuild_depot_rows()
	)
	row.add_child(preset)

	var depot_id := LineEdit.new()
	depot_id.custom_minimum_size.x = DEPOT_ID_MIN_WIDTH
	depot_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depot_id.size_flags_stretch_ratio = DEPOT_ID_STRETCH
	depot_id.placeholder_text = "2807131"
	depot_id.text = depot["depot_id"]
	_set_field_error(depot_id, errors.has("depot_id"))
	depot_id.text_changed.connect(func(t: String) -> void:
		_clear_depot_error(index, "depot_id")
		_set_field_error(depot_id, false)
		_projects[_selected_index]["depots"][index]["depot_id"] = t
		_save_projects()
		_refresh_depot_status()
	)
	row.add_child(depot_id)

	var output := LineEdit.new()
	output.custom_minimum_size.x = OUTPUT_MIN_WIDTH
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output.size_flags_stretch_ratio = OUTPUT_STRETCH
	output.placeholder_text = "game.zip"
	output.tooltip_text = "Export file name. Godot names the .app / .exe / .pck after this, so keep it stable and match Steam's launch options."
	output.text = depot["output"]
	_set_field_error(output, errors.has("output"))
	output.text_changed.connect(func(t: String) -> void:
		_clear_depot_error(index, "output")
		_set_field_error(output, false)
		_projects[_selected_index]["depots"][index]["output"] = t
		_save_projects()
	)
	row.add_child(output)

	var remove := Button.new()
	remove.text = "✕"
	remove.theme_type_variation = &"IconButton"
	remove.tooltip_text = "Remove depot"
	remove.custom_minimum_size.x = 28
	remove.pressed.connect(func() -> void:
		_depot_errors.clear()
		_projects[_selected_index]["depots"].remove_at(index)
		_save_projects()
		_rebuild_depot_rows()
		_refresh_depot_status()
	)
	row.add_child(remove)
	return row


## Default export file name for the preset at [param preset_index], based on
## its platform: "game.zip" for macOS and Web, "game.exe" for Windows,
## "game.x86_64" otherwise. Falls back to the preset name for old entries.
func _default_output_name(preset_index: int) -> String:
	var lower := ""
	if preset_index >= 0 and preset_index < _preset_platforms.size():
		lower = _preset_platforms[preset_index].to_lower()
	if lower.is_empty() and preset_index >= 0 and preset_index < _preset_names.size():
		lower = _preset_names[preset_index].to_lower()
	if "mac" in lower or "web" in lower:
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
	if not _validate_publish_form():
		return
	var p := _projects[_selected_index]
	var depots: Array = p["depots"]
	var godot: String = p.get("godot_binary", "")
	var steamcmd := _resolve_steamcmd(%SteamCmdBinary.text)

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

## Wires a toggle button so it flips masking on a LineEdit. Never persisted:
## both fields start masked on every launch.
func _bind_secret_toggle(button: Button, field: LineEdit, what: String) -> void:
	button.toggled.connect(func(on: bool) -> void:
		field.secret = not on
		button.icon = EYE_HIDDEN if on else EYE_VISIBLE
		button.tooltip_text = ("Hide " if on else "Show ") + what
	)


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
	if not _validate_login_fields():
		return
	var steamcmd := _resolve_steamcmd(%SteamCmdBinary.text)
	_set_busy(true)
	var args := _steam_login_args()
	args.append("+quit")
	var code := await run_process(steamcmd, args)
	if code == 0:
		log_line("Steam login OK – session cached by SteamCMD.", COLOR_OK)
		%SteamGuardCode.text = ""
		if not %RememberPassword.button_pressed:
			%SteamPassword.text = ""
	else:
		log_line("Steam login failed (exit code %d)." % code, COLOR_ERR)
	_set_busy(false)


# ---------------------------------------------------------------------------
# SteamCMD – resolve / detect / browse / download
# ---------------------------------------------------------------------------

func _steamcmd_install_dir() -> String:
	return OS.get_user_data_dir().path_join("steamcmd")


func _path_dirs() -> PackedStringArray:
	var sep := ";" if OS.get_name() == "Windows" else ":"
	var out := PackedStringArray()
	for d in OS.get_environment("PATH").split(sep, false):
		if not out.has(d):
			out.append(d)
	return out


## Turns what the user typed into a runnable path. A bare command name
## ("steamcmd") is looked up on PATH; anything with a directory part must
## exist as a file. Scripts (steamcmd.sh, the Homebrew wrapper) are the real
## entry points, so they are deliberately accepted here.
func _resolve_steamcmd(text: String) -> String:
	text = text.strip_edges()
	if text.is_empty():
		return ""
	if FileAccess.file_exists(text):
		return text
	if "/" in text or "\\" in text:
		return ""
	var names: PackedStringArray = [text]
	if OS.get_name() == "Windows":
		names.append_array([text + ".exe", text + ".bat", text + ".cmd"])
	for d in _path_dirs():
		for n in names:
			var full := d.path_join(n)
			if FileAccess.file_exists(full):
				return full
	return ""


## Well-known SteamCMD locations: PATH, package-manager dirs, the folders
## Valve's docs suggest, and finally this app's own download folder.
func _steamcmd_candidates() -> PackedStringArray:
	var home := OS.get_environment("HOME")
	var dirs := _path_dirs()
	dirs.append_array([
		"/usr/local/bin",
		"/opt/homebrew/bin",
		"/usr/games",
		home.path_join(".steam/steamcmd"),
		home.path_join("steamcmd"),
		home.path_join("Steam"),
		"C:/steamcmd",
	])
	var program_data := OS.get_environment("ProgramData")
	if not program_data.is_empty():
		dirs.append(program_data.path_join("chocolatey/bin"))
	dirs.append(_steamcmd_install_dir())

	var out := PackedStringArray()
	for d in dirs:
		if d.is_empty():
			continue
		for n in ["steamcmd", "steamcmd.sh", "steamcmd.exe"]:
			var full := d.path_join(n)
			if FileAccess.file_exists(full) and not out.has(full):
				out.append(full)
	return out


## Refreshes the SteamCMD status dot/label. Returns the resolved path or "".
func _check_steamcmd() -> String:
	var text: String = %SteamCmdBinary.text.strip_edges()
	var resolved := _resolve_steamcmd(text)
	if text.is_empty():
		%SteamCmdStatusLabel.text = "Not set  ·  Detect, Browse or Download"
		%SteamCmdDot.self_modulate = Color(COLOR_MUTED)
	elif resolved.is_empty():
		%SteamCmdStatusLabel.text = "Not found: %s" % text
		%SteamCmdDot.self_modulate = Color(COLOR_ERR)
	else:
		%SteamCmdStatusLabel.text = "Found  ·  %s" % resolved
		%SteamCmdDot.self_modulate = Color(COLOR_OK)
	%SteamCmdStatusLabel.tooltip_text = resolved
	return resolved


func _set_steamcmd_path(path: String) -> void:
	%SteamCmdBinary.text = path  # text_changed does not fire on set, commit manually
	_save_settings()
	_check_steamcmd()


## Detect button: confirms the current entry, or searches for one when it is
## empty or invalid.
func _on_detect_steamcmd_pressed() -> void:
	var current := _check_steamcmd()
	if not current.is_empty():
		log_line("SteamCMD OK at %s" % current, COLOR_OK)
		return
	var found := _steamcmd_candidates()
	if found.is_empty():
		log_line("No SteamCMD found on PATH or in common folders. Use Browse… or Download SteamCMD.", COLOR_WARN)
		return
	log_line("Detected SteamCMD at %s" % found[0], COLOR_OK)
	_set_steamcmd_path(found[0])


func _on_steamcmd_selected(path: String) -> void:
	_set_steamcmd_path(path)
	log_line("SteamCMD set to %s" % path, COLOR_INFO)


## Fetches Valve's archive into user://steamcmd, unpacks it, runs it once so
## it can update itself, then points the field at the result.
func _on_download_steamcmd_pressed() -> void:
	if _is_busy:
		return
	var host := OS.get_name()
	if not STEAMCMD_URLS.has(host):
		log_line("No SteamCMD download is available for %s. See %s" % [host, STEAMCMD_DOCS_URL], COLOR_ERR)
		return
	var url: String = STEAMCMD_URLS[host]
	var dir := _steamcmd_install_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	_steamcmd_archive = dir.path_join(url.get_file())

	_set_busy(true)
	log_line("── Downloading SteamCMD from %s" % url, COLOR_OK)
	_steamcmd_http.download_file = _steamcmd_archive
	var err := _steamcmd_http.request(url)
	if err != OK:
		log_line("Could not start the download (error %d)." % err, COLOR_ERR)
		_set_busy(false)
		return

	_steamcmd_downloading = true
	while _steamcmd_downloading:
		var got := _steamcmd_http.get_downloaded_bytes()
		var total := _steamcmd_http.get_body_size()
		if total > 0:
			%SteamCmdStatusLabel.text = "Downloading…  %d%%" % int(100.0 * got / total)
		else:
			%SteamCmdStatusLabel.text = "Downloading…  %d KB" % (got >> 10)
		await get_tree().process_frame


func _on_steamcmd_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_steamcmd_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var why := ("HTTP %d" % code) if result == HTTPRequest.RESULT_SUCCESS else ("result %d" % result)
		log_line("SteamCMD download failed (%s)." % why, COLOR_ERR)
		DirAccess.remove_absolute(_steamcmd_archive)
		_check_steamcmd()
		_set_busy(false)
		return
	log_line("Downloaded %s" % _steamcmd_archive.get_file(), COLOR_INFO)

	%SteamCmdStatusLabel.text = "Unpacking…"
	var dir := _steamcmd_install_dir()
	var is_windows := OS.get_name() == "Windows"
	var ok: bool
	if is_windows:
		ok = await _unzip_in_place(_steamcmd_archive, dir)
	else:
		# System tar keeps the executable bits on steamcmd.sh and the binary.
		ok = await run_process("/usr/bin/tar", ["-xzf", _steamcmd_archive, "-C", dir]) == 0
		DirAccess.remove_absolute(_steamcmd_archive)
	var exe := dir.path_join("steamcmd.exe" if is_windows else "steamcmd.sh")
	if not ok or not FileAccess.file_exists(exe):
		log_line("Could not unpack SteamCMD into %s." % dir, COLOR_ERR)
		_check_steamcmd()
		_set_busy(false)
		return

	# The archive is only a bootstrapper: the first run downloads the real
	# client. Doing it now also proves the thing launches on this machine.
	log_line("── Running SteamCMD once so it can update itself", COLOR_OK)
	%SteamCmdStatusLabel.text = "Updating SteamCMD…"
	var boot := await run_process(exe, ["+quit"])
	if boot != 0:
		log_line("SteamCMD's first run exited with code %d – check the output above." % boot, COLOR_WARN)
		if OS.get_name() == "macOS" and OS.has_feature("arm64"):
			log_line("SteamCMD is an Intel binary. On Apple Silicon install Rosetta first: softwareupdate --install-rosetta", COLOR_WARN)
	else:
		log_line("SteamCMD is ready.", COLOR_OK)
	_set_steamcmd_path(exe)
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
		if _capturing and not is_stderr:
			_capture_line.call_deferred(line)


func _capture_line(line: String) -> void:
	_capture.append(line)


## Like [method run_process], but also returns everything the process wrote to
## stdout: { "code": int, "output": String }.
func run_process_capture(exe: String, args: PackedStringArray) -> Dictionary:
	_capture = PackedStringArray()
	_capturing = true
	var code := await run_process(exe, args)
	# Reader threads have joined, but their deferred appends land next frame.
	await get_tree().process_frame
	_capturing = false
	return {"code": code, "output": "\n".join(_capture)}


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
# Layout toggles (console, Steam account panel)
# ---------------------------------------------------------------------------

func _set_console_visible(visible_now: bool) -> void:
	_console_wanted = visible_now
	_apply_console_visibility()


func _toggle_steam_fields() -> void:
	%SteamFieldsScroll.visible = not %SteamFieldsScroll.visible
	_update_steam_chevron()
	_fit_sidebar.call_deferred()


func _update_steam_chevron() -> void:
	%SteamChevron.text = "▾" if %SteamFieldsScroll.visible else "▴"


## Header row of the account panel: avatar initial, username and a one-line status.
func _update_steam_header() -> void:
	var user: String = %SteamUsername.text.strip_edges()
	var secret: String = %SteamSharedSecret.text.strip_edges()
	%AvatarLetter.text = user.substr(0, 1).to_upper() if not user.is_empty() else "S"
	%SteamAccountName.text = user if not user.is_empty() else "Steam account"
	if user.is_empty():
		%SteamAccountSub.text = "Not signed in"
	elif secret.is_empty():
		%SteamAccountSub.text = "Cached SteamCMD session"
	elif steam_totp(secret).is_empty():
		%SteamAccountSub.text = "Shared secret is not valid"
	else:
		%SteamAccountSub.text = "Steam Guard automatic"


# ---------------------------------------------------------------------------
# Console
# ---------------------------------------------------------------------------

## Append a line to the debug console and keep it scrolled to the bottom.
func log_line(text: String, color: String = COLOR_INFO) -> void:
	var safe := text.replace("[", "[lb]")
	var stamp := Time.get_time_string_from_system()
	%Console.append_text("[color=%s]%s[/color]  [color=%s]%s[/color]\n" % [COLOR_STAMP, stamp, color, safe])
	_scroll_console_to_bottom()


func _scroll_console_to_bottom() -> void:
	await get_tree().process_frame
	var scroll: ScrollContainer = %ConsoleScroll
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(bar.max_value)


func _set_busy(busy: bool) -> void:
	_is_busy = busy
	%BuildPublishButton.disabled = busy
	%BuildDescription.editable = not busy
	%BuildPublishButton.text = "Working…" if busy else "Build & Publish"
	%SteamLoginButton.disabled = busy
	%NewGameButton.disabled = busy
	%AddGameButton.disabled = busy
	%EmptyNewGameButton.disabled = busy
	%RemoveProjectButton.disabled = busy
	%BrowseButton.disabled = busy
	%AddDepotButton.disabled = busy
	%FetchDepotsButton.disabled = busy
	%DetectSteamCmdButton.disabled = busy
	%BrowseSteamCmdButton.disabled = busy
	%DownloadSteamCmdButton.disabled = busy


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


## The password and shared secret are only persisted when their "Remember"
## toggles are on; otherwise they live in memory until the app quits. Both are
## plain text in user://settings.cfg – keep that file private.
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tools", "steamcmd_binary", %SteamCmdBinary.text)
	cfg.set_value("steam", "username", %SteamUsername.text)
	cfg.set_value("steam", "remember_shared_secret", %RememberSharedSecret.button_pressed)
	cfg.set_value("steam", "shared_secret", %SteamSharedSecret.text if %RememberSharedSecret.button_pressed else "")
	cfg.set_value("steam", "remember_password", %RememberPassword.button_pressed)
	cfg.set_value("steam", "password", %SteamPassword.text if %RememberPassword.button_pressed else "")
	cfg.save(SETTINGS_FILE)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	%SteamCmdBinary.text = cfg.get_value("tools", "steamcmd_binary", "")
	%SteamUsername.text = cfg.get_value("steam", "username", "")
	var stored_secret: String = cfg.get_value("steam", "shared_secret", "")
	# Older settings files have no remember flag: keep the secret if one was stored.
	%RememberSharedSecret.button_pressed = cfg.get_value("steam", "remember_shared_secret", not stored_secret.is_empty())
	%SteamSharedSecret.text = stored_secret
	%RememberPassword.button_pressed = cfg.get_value("steam", "remember_password", false)
	%SteamPassword.text = cfg.get_value("steam", "password", "")
	if not %SteamUsername.text.is_empty():
		%SteamStatusLabel.text = "Using cached SteamCMD session for %s" % %SteamUsername.text
