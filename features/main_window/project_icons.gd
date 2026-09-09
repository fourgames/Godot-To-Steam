class_name ProjectIcons
extends RefCounted
## Resolves and loads the icon of a *foreign* Godot project (one that is not
## this app) from its project.godot, so every app in the sidebar shows its
## own icon. Textures are cached per project path because the sidebar is
## rebuilt often.

const FALLBACK_ICON := preload("res://public/icon.svg")
const MAX_SIZE := 128
const IMAGE_EXTENSIONS := ["svg", "png", "jpg", "jpeg", "webp", "bmp", "tga"]

static var _cache: Dictionary = {}


## Texture for the project at [param project_path]; the generic icon when the
## project has no usable icon. Never returns null.
static func load_texture(project_path: String) -> Texture2D:
	if _cache.has(project_path):
		return _cache[project_path]
	var tex: Texture2D = _load_uncached(project_path)
	if tex == null:
		tex = FALLBACK_ICON
	_cache[project_path] = tex
	return tex


## Forget the cached texture, e.g. after the entry was pointed at another folder.
static func invalidate(project_path: String) -> void:
	_cache.erase(project_path)


## Absolute path of the project's icon file, or "" if it cannot be found.
static func resolve_icon_path(project_path: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(project_path.path_join("project.godot")) != OK:
		return ""
	var icon: String = str(cfg.get_value("application", "config/icon", "res://icon.svg"))
	if icon.begins_with("uid://"):
		icon = _resolve_uid(project_path, icon)
	if not icon.begins_with("res://"):
		return ""
	var abs_path := project_path.path_join(icon.trim_prefix("res://"))
	if not FileAccess.file_exists(abs_path):
		return ""
	if not abs_path.get_extension().to_lower() in IMAGE_EXTENSIONS:
		return ""
	return abs_path


## Looks a uid:// reference up in the project's .godot/uid_cache.bin
## (u32 count, then repeated { u64 uid, u32 length, utf8 path }).
static func _resolve_uid(project_path: String, uid_text: String) -> String:
	var want := ResourceUID.text_to_id(uid_text)
	if want == ResourceUID.INVALID_ID:
		return ""
	var f := FileAccess.open(project_path.path_join(".godot/uid_cache.bin"), FileAccess.READ)
	if f == null:
		return ""
	var count := f.get_32()
	for i in count:
		if f.get_position() >= f.get_length():
			break
		var id := f.get_64()
		var length := f.get_32()
		var path := f.get_buffer(length).get_string_from_utf8()
		if id == want:
			return path
	return ""


static func _load_uncached(project_path: String) -> Texture2D:
	var path := resolve_icon_path(project_path)
	if path.is_empty():
		return null
	var img := Image.new()
	var err: Error
	if path.get_extension().to_lower() == "svg":
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		err = img.load_svg_from_buffer(bytes, 1.0)
	else:
		err = img.load(path)
	if err != OK or img.is_empty():
		return null

	var longest := maxi(img.get_width(), img.get_height())
	if longest > MAX_SIZE:
		var scale := float(MAX_SIZE) / longest
		img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
