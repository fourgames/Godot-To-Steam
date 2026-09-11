extends RefCounted
## Small insert, remove and fade animations for rows in containers (sidebar
## apps, depot rows, banners).
##
## A row animates inside a clipping holder that takes its slot in the
## container, so the container reflows smoothly around a height that grows
## or shrinks. Each tween belongs to its holder: a list rebuild that frees the
## holder also stops the animation, and the callbacks after it never run.

## Seconds and pixels, matched to the trailer.
const ROW_IN := 0.34
const ROW_SLIDE := 18.0
const DEPOT_IN := 0.3
const BANNER_IN := 0.34
const OUT := 0.26
const STAGGER := 0.06
const FADE_IN := 0.55


## Grows [param c], already placed in its container, from zero height to its
## own (fading in, and sliding in from the left by [param slide] pixels), then
## puts it back in its slot.
static func grow_in(c: Control, seconds := DEPOT_IN, slide := 0.0, delay := 0.0) -> void:
	var parent := c.get_parent() as Control
	if parent == null or not c.is_inside_tree():
		return
	var holder := _holder()
	parent.add_child(holder)
	parent.move_child(holder, c.get_index())
	c.reparent(holder, false)
	c.modulate.a = 0.0
	var tree := holder.get_tree()
	await tree.process_frame  # The holder gets its width from the container.
	if not (is_instance_valid(holder) and is_instance_valid(c)):
		return
	c.position = Vector2.ZERO
	c.size = Vector2(holder.size.x, 0.0)
	await tree.process_frame  # Wrapped labels settle their height for that width.
	await tree.process_frame
	if not (is_instance_valid(holder) and is_instance_valid(c)):
		return
	var h := maxf(c.get_combined_minimum_size().y, c.custom_minimum_size.y)
	c.size = Vector2(holder.size.x, h)
	c.position.x = -slide
	var tw := holder.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "custom_minimum_size:y", h, seconds).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, seconds).set_delay(delay)
	if slide != 0.0:
		tw.tween_property(c, "position:x", 0.0, seconds * 1.2).set_delay(delay)
	tw.finished.connect(func() -> void:
		if not is_instance_valid(c):
			return
		var at := holder.get_index()
		holder.visible = false  # Out of the layout before c takes its place.
		c.reparent(parent, false)
		parent.move_child(c, at)
		holder.queue_free()
	)


## Shrinks [param c] to nothing and frees it; [param done] runs afterwards
## (not when a rebuild freed the row first). [param c] ignores the mouse
## from the start.
static func collapse(c: Control, seconds := OUT, done := Callable()) -> void:
	var parent := c.get_parent() as Control
	if parent == null or not c.is_inside_tree():
		c.queue_free()
		if done.is_valid():
			done.call()
		return
	var box := c.size
	var holder := _holder()
	holder.custom_minimum_size.y = box.y
	parent.add_child(holder)
	parent.move_child(holder, c.get_index())
	c.reparent(holder, false)
	c.position = Vector2.ZERO
	c.size = box
	ignore_mouse(c)
	var tw := holder.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(holder, "custom_minimum_size:y", 0.0, seconds)
	tw.tween_property(c, "modulate:a", 0.0, seconds * 0.8)
	tw.finished.connect(func() -> void:
		holder.queue_free()
		if done.is_valid():
			done.call()
	)


## Fades [param c] in with a slight zoom from its centre.
static func fade_in(c: Control, seconds := FADE_IN) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(0.97, 0.97)
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, seconds)
	tw.tween_property(c, "scale", Vector2.ONE, seconds)


## Makes [param root] and everything in it ignore the mouse: rows that are
## about to be rebuilt still carry callbacks bound to their old index.
static func ignore_mouse(root: Node) -> void:
	if root is Control:
		(root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		ignore_mouse(child)


## The row inside [param child] when it is a holder mid-animation, else
## [param child] itself.
static func row_of(child: Node) -> Node:
	if child.has_meta("motion_holder") and child.get_child_count() > 0:
		return child.get_child(0)
	return child


static func _holder() -> Control:
	var holder := Control.new()
	holder.set_meta("motion_holder", true)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return holder
