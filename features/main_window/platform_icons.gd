class_name PlatformIcons
extends RefCounted
## Maps the `platform=` value of an export preset to the same logo Godot's
## export dialog shows for it. Logos live in public/icons/platforms (MIT,
## from the Godot Engine repository).

const ICONS := {
	"windows": preload("res://public/icons/platforms/windows.svg"),
	"macos": preload("res://public/icons/platforms/macos.svg"),
	"linux": preload("res://public/icons/platforms/linux.svg"),
	"web": preload("res://public/icons/platforms/web.svg"),
	"android": preload("res://public/icons/platforms/android.svg"),
	"ios": preload("res://public/icons/platforms/ios.svg"),
}


## Logo for a platform name such as "Windows Desktop", "macOS", "Linux",
## "Linux/X11", "Web", "Android" or "iOS"; null for unknown platforms.
static func for_platform(platform: String) -> Texture2D:
	var lower := platform.to_lower()
	for key in ICONS:
		if key in lower:
			return ICONS[key]
	return null
