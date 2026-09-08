# Godot to Steam

Desktop app that exports a Godot project and uploads the build to Steam with SteamCMD.

## Fetching depots from Steam

Press **Fetch depots** in the Depots header to fill the table from the App ID. The app runs SteamCMD with your login and `app_info_print`, then adds a row for every content depot that is not already listed, picking an export preset whose platform matches the depot's OS. Only depots that are published in the app's configuration on the Steamworks partner site show up, so create the depots and publish the config there first.

## Steam Guard

Normal flow: leave the shared secret empty, type the Steam Guard code from your email or phone into the Steam Guard code field, and press **Test login & cache session** once. SteamCMD caches the session, so later uploads usually do not ask for a code again.

The shared secret field is optional and for advanced use only. If you already have a Steam Guard `shared_secret` for a dedicated build account with publish access, you can paste it in and the app will generate codes itself. Do not set up an authenticator on your main account for this. The secret is only written to `user://settings.cfg` (plain text) when **Remember shared secret** is on.
