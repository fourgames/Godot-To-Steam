class_name KnownIssues
extends RefCounted
## Known failure signatures in SteamCMD and Godot output, each paired with the
## fix a user can apply without help.
##
## [method match_line] is fed every line a child process prints; the caller
## collects the matches and shows their hints once the process failed. Knows
## nothing about the UI.
##
## Only substrings that really appear in the tools' output belong here: a
## wrong hint sends the user in the wrong direction, which is worse than the
## generic fallback.

const STEAMCMD := "steamcmd"
const GODOT := "godot"

## { id, tool, all: substrings (lowercase) that must all appear, hint,
## minor (optional): true for side notes that never lead the explanation }.
const ISSUES: Array[Dictionary] = [
	# --- SteamCMD ------------------------------------------------------------
	{
		"id": "invalid_password",
		"tool": STEAMCMD,
		"all": ["invalid password"],
		"hint": "Steam rejected the password. Retype it on the SteamCMD page (use the eye button to check it) and press Sign in. Use your Steam account name, not your email address. Several wrong tries in a row lock sign-ins for a while.",
	},
	{
		"id": "rate_limit",
		"tool": STEAMCMD,
		"all": ["rate limit exceeded"],
		"hint": "Steam blocked sign-ins from this computer after too many attempts. Wait 30–60 minutes without trying, then sign in once with the correct password. Every new attempt restarts the wait.",
	},
	{
		"id": "no_connection",
		"tool": STEAMCMD,
		"all": ["(no connection)"],
		"hint": "SteamCMD could not reach Steam. Check your internet connection, and turn off any VPN, proxy or firewall that blocks it, then try again.",
	},
	{
		"id": "timeout",
		"tool": STEAMCMD,
		"all": ["(timeout)"],
		"hint": "Steam did not answer in time. Check your connection (VPN, proxy, firewall) and try again in a few minutes.",
	},
	{
		"id": "service_unavailable",
		"tool": STEAMCMD,
		"all": ["service unavailable"],
		"hint": "Steam's servers are unavailable right now (maintenance is usually Tuesdays). Try again later; https://steamstat.us shows the current status.",
	},
	{
		# run_app_build's own refusal; before access_denied so it wins the match.
		"id": "build_access_denied",
		"tool": STEAMCMD,
		"all": ["failed to initialize build", "access denied"],
		"hint": "Steam refused to start a build for this App ID. Check that every depot ID belongs to this app (Steamworks → SteamPipe → Depots, or press Fetch in the depot table) and that new depots are published. Then check that the account has 'Edit App Metadata' and 'Publish App Changes To Steam' for the app (Steamworks → Users & Permissions → Manage Users).",
	},
	{
		"id": "access_denied",
		"tool": STEAMCMD,
		"all": ["access denied"],
		"hint": "This Steam account may not publish builds for this App ID. In Steamworks → Users & Permissions → Manage Users, give it 'Edit App Metadata' and 'Publish App Changes To Steam' for the app, and check the App ID.",
	},
	{
		"id": "commit_failed",
		"tool": STEAMCMD,
		"all": ["failed to commit build"],
		"hint": "Steam refused the build. Check that every depot ID belongs to this App ID (Steamworks → SteamPipe → Depots), that the depot configuration is published, and that the account has 'Publish App Changes To Steam' permission.",
	},
	{
		"id": "branch_failed",
		"tool": STEAMCMD,
		"all": ["failed", "branch"],
		"hint": "The build could not be set live on that branch. Check the spelling. The branch has to exist first: create it in Steamworks → SteamPipe → Builds (Manage branches). If it exists but has never had a build live, set this build live on it by hand there once.",
	},
	{
		"id": "disk_write",
		"tool": STEAMCMD,
		"all": ["disk write failure"],
		"hint": "SteamCMD could not write to disk. Free up disk space and check that this app's data folder is writable.",
	},
	{
		"id": "bad_cpu_type",
		"tool": "any",
		"all": ["bad cpu type"],
		"hint": "SteamCMD is an Intel program. On Apple Silicon install Rosetta: run 'softwareupdate --install-rosetta' in Terminal, then try again.",
	},
	{
		"id": "linux32_missing",
		"tool": "any",
		"all": ["linux32/steamcmd", "no such file"],
		"hint": "SteamCMD is a 32-bit program and the 32-bit runtime is missing. Debian/Ubuntu: 'sudo apt install lib32gcc-s1'; Fedora: 'sudo dnf install glibc.i686 libstdc++.i686'; Arch: enable multilib and install lib32-gcc-libs.",
	},
	{
		# Godot's own message when exec() of a child fails (it lands in the child's stderr).
		"id": "exec_failed",
		"tool": "any",
		"all": ["could not create child process"],
		"hint": "The program could not be started. Pick the program itself rather than a shortcut or launcher, and make sure it is executable (Terminal: chmod +x \"<path>\"). On macOS, a program downloaded in a browser may be blocked until you open it once from Finder (right-click → Open).",
	},
	# --- Godot export --------------------------------------------------------
	{
		"id": "export_templates",
		"tool": GODOT,
		"all": ["no export template found"],
		"hint": "The export templates for this Godot version are not installed. Open the same Godot version, go to Editor → Manage Export Templates → Download and Install, then build again.",
	},
	{
		"id": "export_template_file",
		"tool": GODOT,
		"all": ["template file not found"],
		"hint": "An export template file is missing. Reinstall the templates in Godot (Editor → Manage Export Templates), or clear the custom template path in the preset.",
	},
	{
		"id": "preset_config_errors",
		"tool": GODOT,
		"all": ["due to configuration errors"],
		"hint": "Godot listed what is wrong with the export preset right below that line. Open the project in Godot → Project → Export…, select the preset and fix the red messages there.",
	},
	{
		"id": "invalid_preset",
		"tool": GODOT,
		"all": ["invalid export preset name"],
		"hint": "The export preset in the depot row no longer exists (renamed or deleted in Godot). Reselect the app so the preset list reloads, then pick the preset again in the depot row.",
	},
	{
		"id": "project_not_loaded",
		"tool": GODOT,
		"all": ["couldn't load project"],
		"hint": "Godot could not open the project folder. If it was moved, click the app name at the top to point at its new location.",
	},
	{
		"id": "invalid_project_path",
		"tool": GODOT,
		"all": ["invalid project path"],
		"hint": "Godot could not open the project folder. If it was moved, click the app name at the top to point at its new location.",
	},
	{
		"id": "failed_loading_resource",
		"tool": GODOT,
		"all": ["failed loading resource"],
		"hint": "Some project files could not be loaded. Open the project once in the Godot editor so it imports its assets, and check that every file is present (for example Git LFS files were pulled).",
	},
	{
		"id": "rcedit",
		"tool": GODOT,
		"minor": true,  # A warning Godot prints even on success; never the headline.
		"all": ["rcedit"],
		"hint": "Godot could not set the Windows icon and file info (rcedit). The build still works; to fix it, set the rcedit path in Godot → Editor Settings → Export → Windows, or turn off 'Modify Resources' in the Windows preset.",
	},
	{
		"id": "dotnet_hostfxr",
		"tool": GODOT,
		"all": ["hostfxr"],
		"hint": "This is a C# project and the .NET runtime was not found. Install the .NET SDK (https://dotnet.microsoft.com/download) and use the .NET build of Godot.",
	},
	{
		"id": "dotnet_missing",
		"tool": GODOT,
		"all": ["dotnet", "not found"],
		"hint": "This is a C# project and the .NET SDK was not found. Install it (https://dotnet.microsoft.com/download) and use the .NET build of Godot.",
	},
]


## First issue whose substrings all occur in [param line], for output of
## [param tool] ([constant STEAMCMD] or [constant GODOT]); {} when none does.
static func match_line(line: String, tool: String) -> Dictionary:
	var lower := line.to_lower()
	for issue in ISSUES:
		var issue_tool: String = issue["tool"]
		if issue_tool != "any" and issue_tool != tool:
			continue
		var all_found := true
		for needle: String in issue["all"]:
			if not lower.contains(needle):
				all_found = false
				break
		if all_found:
			return issue
	return {}


## The issue with [param id], or {}.
static func get_issue(id: String) -> Dictionary:
	for issue in ISSUES:
		if issue["id"] == id:
			return issue
	return {}


## Plain-words reason for an [enum HTTPRequest.Result] other than success,
## including what the user can check.
static func http_result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "success"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "server name could not be resolved – no internet connection, or DNS is blocked"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "could not connect – check your internet connection, VPN, proxy or firewall"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "secure connection failed – check that the computer's date and time are correct, and that no proxy or antivirus intercepts HTTPS"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "the server did not respond"
		HTTPRequest.RESULT_TIMEOUT:
			return "timed out – the connection is too slow or blocked"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "the download could not be saved – free up disk space and check that the app's data folder is writable"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "the answer was larger than expected"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "too many redirects"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH, HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "the download arrived damaged – try again"
	return "request failed (result %d)" % result
