extends RefCounted
## Reads the progress lines Godot and SteamCMD print, for the console's live
## progress bars. One instance reads one child process: [method feed] gets
## every output line and says what to do with it. Knows nothing about the UI.
##
## Formats, as captured from real runs:
## - Godot 4.4 and later: "[  16% ] savepack | Storing File: res://…", then
##   "[ DONE ] savepack".
## - Godot 4.3 and earlier 4.x: "savepack: begin: Packing steps: 102", then
##   "\tsavepack: step 7: Storing File: res://…" (many lines per step), then
##   "savepack: end".
## - SteamCMD self-update (any SteamCMD run can do one first):
##   "[----] Downloading update (0 of 31,262 KB)...",
##   "[ 38%] Downloading update (11,996 of 31,262 KB)...",
##   "[100%] Download Complete.".
## - butler with --json: one JSON object per line, e.g.
##   {"type":"progress","progress":0.42,"eta":12.5,"bps":1048576,…},
##   {"type":"log","level":"info","message":"…"} and, when it gives up,
##   {"type":"error","message":"<reason>\n<Go stack trace>"}. It then repeats
##   the error on stderr as "bailing out: <reason>" plus the stack trace.
## - SteamCMD run_app_build, per depot: "[2026-09-11 10:17:15]: Building depot
##   2807131...", "Scanning content", "......... 184.3MB (30%)" (the dots
##   arrive a few at a time, so a quiet pipe can split them off as their own
##   line), then "Uploading content...". The upload itself prints no progress,
##   so its bar ends with the scan.
##
## Anything else, including Godot 3's output, is left alone and prints as is.

const GODOT := "godot"
const STEAMCMD := "steamcmd"
const BUTLER := "butler"

## Friendlier bar labels for Godot's progress task names.
const GODOT_TASKS := {
	"savepack": "Packing files",
	"savezip": "Zipping files",
	"export": "Exporting",
	"first_scan_filesystem": "Scanning project",
	"update_scripts_classes": "Registering classes",
	"reimport": "Importing assets",
}
const UPDATE_LABEL := "SteamCMD update"

static var _godot_pct_re := RegEx.create_from_string("^\\[\\s*(\\d{1,3})%\\s*\\]\\s*(\\S+)\\s*\\|")
static var _godot_done_re := RegEx.create_from_string("^\\[\\s*DONE\\s*\\]\\s*(\\S+)\\s*$")
static var _godot_begin_re := RegEx.create_from_string("^(\\w+): begin: .*?steps: (\\d+)\\s*$")
static var _godot_step_re := RegEx.create_from_string("^\\s*(\\w+): step (\\d+):")
static var _godot_end_re := RegEx.create_from_string("^(\\w+): end\\s*$")
static var _update_re := RegEx.create_from_string("^\\[\\s*(\\d{1,3}|-+)%?\\]\\s*(Downloading update|Download Complete)")
static var _depot_re := RegEx.create_from_string("Building depot (\\d+)")
static var _scan_re := RegEx.create_from_string("^\\.*\\s*[\\d.,]+\\s*[KMGT]?B\\s*\\((\\d{1,3})%\\)\\s*$")
static var _dots_re := RegEx.create_from_string("^\\.+\\s*$")

## KnownIssues.GODOT, KnownIssues.STEAMCMD or KnownIssues.BUTLER (the same strings).
var tool := ""
## Bar label for tools whose output does not name what it works on (butler).
var bar_label := ""
## butler: set after "bailing out:", whose stack trace lines are all dropped.
var _bailing := false
## Godot 4.3 task name → its step count, from the "begin" line.
var _steps := {}
## SteamCMD: depot being built, and whether its scan bar is running.
var _depot := ""
var _scanning := false


func _init(p_tool: String, p_label := "") -> void:
	tool = p_tool
	bar_label = p_label


## True when [param p_tool]'s output has progress lines this class reads.
static func reads(p_tool: String) -> bool:
	return p_tool == GODOT or p_tool == STEAMCMD or p_tool == BUTLER


## What to do with one output line (ANSI codes already stripped).
## {} prints it unchanged. Otherwise "label" and "pct" (0–100) move that
## bar and "end" finishes it; the line itself is folded into the bar unless
## "print" is set. {"fold": true} alone just drops the line. {"text": …}
## prints that text instead of the line ("err": true marks it as an error).
func feed(line: String) -> Dictionary:
	if tool == GODOT:
		return _feed_godot(line)
	if tool == STEAMCMD:
		return _feed_steamcmd(line)
	if tool == BUTLER:
		return _feed_butler(line)
	return {}


func _feed_godot(line: String) -> Dictionary:
	var m := _godot_pct_re.search(line)
	if m != null:
		return {"label": _task_label(m.get_string(2)), "pct": float(m.get_string(1))}
	m = _godot_done_re.search(line)
	if m != null:
		return {"label": _task_label(m.get_string(1)), "pct": 100.0, "end": true}
	m = _godot_begin_re.search(line)
	if m != null:
		var steps := int(m.get_string(2))
		if steps > 0:
			_steps[m.get_string(1)] = steps
			return {"label": _task_label(m.get_string(1)), "pct": 0.0}
		return {}
	# Step and end lines only count for a task whose begin line was seen, so
	# a game that prints "something: end" at export time is not eaten.
	m = _godot_step_re.search(line)
	if m != null and _steps.has(m.get_string(1)):
		var task := m.get_string(1)
		return {"label": _task_label(task), "pct": clampf(100.0 * int(m.get_string(2)) / _steps[task], 0.0, 100.0)}
	m = _godot_end_re.search(line)
	if m != null and _steps.has(m.get_string(1)):
		var task := m.get_string(1)
		_steps.erase(task)
		return {"label": _task_label(task), "pct": 100.0, "end": true}
	return {}


func _feed_steamcmd(line: String) -> Dictionary:
	var m := _update_re.search(line)
	if m != null:
		if m.get_string(2) == "Download Complete":
			return {"label": UPDATE_LABEL, "pct": 100.0, "end": true}
		var pct := m.get_string(1)
		return {"label": UPDATE_LABEL, "pct": float(pct) if pct.is_valid_int() else 0.0}
	m = _depot_re.search(line)
	if m != null:
		_depot = m.get_string(1)
		_scanning = false
		return {}
	var label := "Scan %s" % _depot if not _depot.is_empty() else "Scan"
	var trimmed := line.strip_edges()
	if trimmed == "Scanning content":
		_scanning = true
		return {"label": label, "pct": 0.0}
	m = _scan_re.search(trimmed)
	if m != null:
		_scanning = true
		return {"label": label, "pct": float(m.get_string(1))}
	if _scanning and _dots_re.search(trimmed) != null:
		return {"fold": true}
	if _scanning and trimmed.begins_with("Uploading content"):
		_scanning = false
		return {"label": label, "pct": 100.0, "end": true, "print": true}
	return {}


func _feed_butler(line: String) -> Dictionary:
	var trimmed := line.strip_edges()
	if not trimmed.begins_with("{"):
		if trimmed.begins_with("bailing out:"):
			_bailing = true  # The JSON error line already said why.
		return {"fold": true} if _bailing else {}
	var data: Variant = JSON.parse_string(trimmed)
	if not data is Dictionary:
		return {}
	var bar := bar_label if not bar_label.is_empty() else "Uploading"
	match str(data.get("type", "")):
		"progress":
			var progress: Variant = data.get("progress")
			if progress is float or progress is int:
				return {"label": bar, "pct": clampf(float(progress) * 100.0, 0.0, 100.0)}
			return {"fold": true}
		"log":
			if str(data.get("level", "")) == "debug":
				return {"fold": true}
			return {"text": str(data.get("message", "")).strip_edges(), "err": str(data.get("level", "")) == "error"}
		"error":
			# The message carries a Go stack trace after its first line.
			return {"text": str(data.get("message", "")).get_slice("\n", 0).strip_edges(), "err": true}
	return {"fold": true}  # result, prompts and other bookkeeping


static func _task_label(task: String) -> String:
	return GODOT_TASKS.get(task, task)
