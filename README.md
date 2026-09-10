# Godot To Steam

Desktop app that exports a Godot project and uploads the build to Steam with SteamCMD.

## Getting started

The **SteamCMD** tab in the sidebar holds a two-step checklist shared by every app: point Godot To Steam at a SteamCMD binary (Find, folder or Download button), then enter your Steam account and press **Sign in**. Until both steps are done, the **+** button next to **Apps** opens this checklist instead of adding an app. The verified login is remembered in `user://settings.cfg`; changing the username asks for a new sign-in.

## Depot rows and the Executable column

Each depot row pairs an export preset with a Steam depot ID and an executable name. Type only the base name (it defaults to the project name); the extension is fixed by the preset's platform: `.exe` for Windows, `.x86_64` for Linux and `.app` for macOS. Godot names the executable and its `.pck` after it, and SteamCMD uploads the whole depot folder. Steam itself does not care about the name, but the launch option you set in Steamworks → Installation → General must point at the same file, e.g. `MyGame.exe` or `MyGame.app`. macOS presets are exported as a zip that the app unpacks before upload, so the `.app` bundle is what ships.

## Publishing non-Godot content (soundtracks, etc.)

The **+** button next to **Apps** accepts any folder. If it has no `project.godot` it is added as a content folder: the Godot section disappears, and each depot row pairs a folder with a depot ID instead of an export preset (the first row defaults to the app folder itself; use the folder button to point a row elsewhere). Build & Publish skips the Godot export and uploads every file in each folder straight to its depot with SteamCMD. **Fetch** in the Depots header works the same way. Use this for soundtrack apps, DLC, or builds produced by another engine or tool.

## Fetching depots from Steam

Press **Fetch** in the Depots header to fill the table from the App ID. The app runs SteamCMD with your login and `app_info_print`, then adds a row for every content depot that is not already listed, picking an export preset whose platform matches the depot's OS. Only depots that are published in the app's configuration on the Steamworks partner site show up, so create the depots and publish the config there first.

## Branches and setting builds live

**Set live on branch** is SteamPipe's `SetLive` option: after a successful upload SteamCMD sets the build live on that branch. Valve's docs limit this to beta branches ("the 'default' branch can not be set live automatically"), so type a beta branch name such as `beta`, or leave the field empty to upload without setting anything live. Godot To Steam rejects `default` before it starts the export.

To ship a build on the default branch, upload first, then open Steamworks → Builds (the **Builds** button under the field opens it) and set it live there. For a released app Steam asks you to confirm in the Steam Mobile app, so the account needs a phone number or the mobile app attached, and any change to the account's email or phone number blocks setting builds live for 3 days. Details: https://partner.steamgames.com/doc/sdk/uploading

## Steam Guard

Normal flow: enter your username and password and press **Sign in**. With the Steam mobile app authenticator you can either type the current code into the Steam Guard code field first (it is passed to SteamCMD with `+set_steam_guard_code`, so no phone prompt is sent) or leave it empty and approve the sign-in in the Steam mobile app when SteamCMD reports `Waiting for confirmation`; the app shows **Approve on phone** meanwhile. With email Guard, leave the field empty: once the password is accepted Steam sends the email and SteamCMD usually exits with `Account Logon Denied`. The app then tells you a code is needed and focuses the Steam Guard code field. Type the code and press **Sign in** again. A wrong code is reported the same way, with the field marked red so you can correct it. SteamCMD caches the session after a successful sign-in, so later uploads usually do not ask for a code again; the code field is cleared and should stay empty. On macOS and Linux the app runs SteamCMD with its own `HOME` (`user://steamcmd_home`), because SteamCMD otherwise shares its config folder with the Steam desktop client, which throws the cached session away every time it logs in. If SteamCMD still asks for the password or a code (the session expired, or the account changed), the app drops the "Signed in" state until the next successful sign-in, depot fetch or upload. To re-test the login flow, press **Sign out** next to **Sign in**: it deletes SteamCMD's cached session (`config.vdf` in the app-owned folders) and forgets the verified state, but keeps the password and shared secret fields.

If SteamCMD instead keeps running and prompts for the code on the console, the button turns into **Submit code**: type the code and press Enter or **Submit code** and SteamCMD finishes the login in the same session. Both paths also apply while Build & Publish and a depot fetch run.

The shared secret field is optional and for advanced use only. It is the **Shared secret** field in the Steam account card. If you already have a Steam Guard `shared_secret` for a dedicated build account with publish access, you can paste it in and the app will generate codes itself. Do not set up an authenticator on your main account for this. The secret is only written to `user://settings.cfg` (plain text) when **Remember shared secret** is on.

## Platform notes

The app runs on macOS, Windows and Linux; the export presets build all three. SteamCMD is an Intel 32-bit binary from Valve, so the host needs: on Apple Silicon Macs, Rosetta (`softwareupdate --install-rosetta`); on Linux, the 32-bit runtime (`sudo apt install lib32gcc-s1` on Debian/Ubuntu, `sudo dnf install glibc.i686 libstdc++.i686` on Fedora, `lib32-gcc-libs` from multilib on Arch) and `tar` on `PATH` for the **Download SteamCMD** button; on Windows, nothing extra (`steamcmd.exe` is unpacked with Godot's own zip reader). macOS exports are unpacked with `unzip` when it is on `PATH`; otherwise the app unpacks them itself and marks the bundle's binaries executable. Godot and SteamCMD are looked up on `PATH`, in the usual install folders of each OS and in every Steam library; the **Detect** buttons and the file pickers cover anything else.
