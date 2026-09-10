class_name SecretStore
extends RefCounted
## Keeps remembered secrets (the Steam password and shared secret) in the
## operating system's credential store instead of a settings file:
##
## - macOS: the login Keychain, through /usr/bin/security.
## - Windows: DPAPI through PowerShell. The encrypted value is kept in
##   user://secrets.cfg and only the same Windows user can decrypt it.
## - Linux: the Secret Service (GNOME Keyring, KWallet) through secret-tool.
##
## A secret never goes on a command line, where any process could read it: it
## is written to the tool's stdin. Values are stored base64-encoded, so any
## text survives the tools unchanged.
##
## Every call blocks until the tool exits (PowerShell can take a second), so
## callers run writes on a thread. Calls must not overlap. Knows nothing about
## the UI.

const SERVICE := "Godot To Steam"
const LINUX_SERVICE := "godot-to-steam"
const WINDOWS_FILE := "user://secrets.cfg"
const SECURITY := "/usr/bin/security"
## A tool that has not exited after this long (say, a keyring stuck waiting
## for an unlock dialog) is killed and the call fails.
const TIMEOUT_MS := 60000

static var _probed := false
static var _backend := ""


## The credential store secrets go to, as words for messages ("the macOS
## Keychain"), or "" when this system has none.
static func backend() -> String:
	if not _probed:
		_probed = true
		_backend = _probe()
	return _backend


static func _probe() -> String:
	match OS.get_name():
		"macOS":
			return "the macOS Keychain" if FileAccess.file_exists(SECURITY) else ""
		"Windows":
			return "Windows (encrypted for your user account)"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			if OS.execute("sh", PackedStringArray(["-c", "command -v secret-tool"])) != 0:
				return ""
			# A lookup of a key that does not exist exits 1 without output; a
			# missing or broken keyring daemon prints an error instead.
			var output := []
			var code := OS.execute("secret-tool", PackedStringArray(["lookup", "service", LINUX_SERVICE, "key", "probe"]), output, true)
			if code == 0 or (code == 1 and "".join(output).strip_edges().is_empty()):
				return "the system keyring"
			return ""
	return ""


## The secret stored under [param name], or "" when none is stored or the
## store cannot be read.
static func read(name: String) -> String:
	var stored := ""
	match OS.get_name():
		"macOS":
			var output := []
			if OS.execute(SECURITY, PackedStringArray(["find-generic-password", "-s", SERVICE, "-a", name, "-w"]), output) == 0:
				stored = "".join(output)
		"Windows":
			var cfg := ConfigFile.new()
			if cfg.load(WINDOWS_FILE) != OK:
				return ""
			var blob := str(cfg.get_value("secrets", name, ""))
			if blob.is_empty():
				return ""
			var res := _run_piped("powershell.exe", _powershell_args(
					"$b = [Console]::In.ReadLine(); $s = ConvertTo-SecureString $b; [Net.NetworkCredential]::new('', $s).Password"),
					blob + "\n", false)
			if res["code"] == 0:
				stored = res["output"]
		_:
			if backend().is_empty():
				return ""
			var output := []
			if OS.execute("secret-tool", PackedStringArray(["lookup", "service", LINUX_SERVICE, "key", name]), output) == 0:
				stored = "".join(output)
	stored = stored.strip_edges()
	return "" if stored.is_empty() else Marshalls.base64_to_utf8(stored)


## Stores [param value] under [param name], replacing what was there. An
## empty value erases the entry. Returns false when it could not be stored.
static func write(name: String, value: String) -> bool:
	if value.is_empty():
		return erase(name)
	if backend().is_empty():
		return false
	var encoded := Marshalls.utf8_to_base64(value)
	match OS.get_name():
		"macOS":
			# Interactive mode reads the command from stdin, so the value never
			# shows up in the process list. Base64 needs no quoting.
			var command := "add-generic-password -U -s \"%s\" -a \"%s\" -w %s\n" % [SERVICE, name, encoded]
			return _run_piped(SECURITY, PackedStringArray(["-i"]), command, true)["code"] == 0
		"Windows":
			var res := _run_piped("powershell.exe", _powershell_args(
					"$v = [Console]::In.ReadLine(); ConvertTo-SecureString $v -AsPlainText -Force | ConvertFrom-SecureString"),
					encoded + "\n", false)
			var blob: String = res["output"].strip_edges()
			if res["code"] != 0 or blob.is_empty():
				return false
			var cfg := ConfigFile.new()
			cfg.load(WINDOWS_FILE)  # Missing on the first write; starts empty.
			cfg.set_value("secrets", name, blob)
			return cfg.save(WINDOWS_FILE) == OK
		_:
			# secret-tool reads the value up to EOF, newline included.
			var args := PackedStringArray(["store", "--label=%s (%s)" % [SERVICE, name], "service", LINUX_SERVICE, "key", name])
			return _run_piped("secret-tool", args, encoded, true)["code"] == 0


## Removes the entry for [param name]. True when it is gone afterwards,
## including when there was none.
static func erase(name: String) -> bool:
	match OS.get_name():
		"macOS":
			if not FileAccess.file_exists(SECURITY):
				return true
			var code := OS.execute(SECURITY, PackedStringArray(["delete-generic-password", "-s", SERVICE, "-a", name]))
			return code == 0 or code == 44  # 44: no such item
		"Windows":
			var cfg := ConfigFile.new()
			if cfg.load(WINDOWS_FILE) != OK or not cfg.has_section_key("secrets", name):
				return true
			cfg.erase_section_key("secrets", name)
			return cfg.save(WINDOWS_FILE) == OK
		_:
			if backend().is_empty():
				return true
			# Exits 1 when nothing matched, which counts as gone too.
			return OS.execute("secret-tool", PackedStringArray(["clear", "service", LINUX_SERVICE, "key", name])) in [0, 1]


static func _powershell_args(script: String) -> PackedStringArray:
	return PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; " + script])


## Runs [param exe] with [param input] on its stdin and waits for it to exit.
## With [param close_stdin] the pipe is closed right after the input so the
## tool sees EOF, and its output is not read. Returns
## {"code": int, "output": String}; code is -1 when the tool could not start
## or hung.
static func _run_piped(exe: String, args: PackedStringArray, input: String, close_stdin: bool) -> Dictionary:
	var info := OS.execute_with_pipe(exe, args, true)
	if info.is_empty():
		return {"code": -1, "output": ""}
	var pid: int = info["pid"]
	var stdio: FileAccess = info["stdio"]
	var stderr: FileAccess = info["stderr"]
	stdio.store_string(input)
	stdio.flush()
	var output := ""
	if not close_stdin:
		# Blocking pipe: get_line waits for the next line and reports EOF once
		# the tool has closed its stdout.
		while true:
			var line := stdio.get_line()
			if stdio.get_error() != OK:
				output += line
				break
			output += line + "\n"
	stdio.close()
	var waited := 0
	while OS.is_process_running(pid):
		if waited >= TIMEOUT_MS:
			OS.kill(pid)
			stderr.close()
			return {"code": -1, "output": ""}
		OS.delay_msec(10)
		waited += 10
	stderr.close()
	return {"code": OS.get_process_exit_code(pid), "output": output}
