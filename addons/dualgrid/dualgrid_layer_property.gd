@tool
extends EditorProperty
class_name EditorPropertyLayerOverride


var grid: GridContainer
var buttons: Array[Button] = []
var updating: bool = false


func _init() -> void:
	grid = GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size = Vector2(128, 128)
	add_child(grid)
	set_bottom_editor(grid)

	for i: int in range(4):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(48, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL

		button.gui_input.connect(_on_button_gui_input.bind(i))
		grid.add_child(button)
		buttons.append(button)


func _update_property() -> void:
	updating = true
	var object: Object = get_edited_object()
	if not object or not object is LayerOrderOverrideRule:
		updating = false
		return

	var order_rule: LayerOrderOverrideRule = object as LayerOrderOverrideRule

	for i: int in range(4):
		var is_enabled: bool = (order_rule.mask & (1 << i)) != 0
		var order_val: int = order_rule.order[i]

		buttons[i].text = "%s\n[ %d ]" % [_get_quadrant_label(i), order_val + 1]
		buttons[i].button_pressed = is_enabled

		if is_enabled:
			buttons[i].modulate = Color(0.4, 1.0, 0.4)
		else:
			buttons[i].modulate = Color(0.7, 0.7, 0.7)

	updating = false


func _on_button_gui_input(event: InputEvent, quad_idx: int) -> void:
	if updating:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_quadrant_mask(quad_idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle_quadrant_order(quad_idx)


func _toggle_quadrant_mask(quad_idx: int) -> void:
	var object: Object = get_edited_object()
	if not object or not object is LayerOrderOverrideRule:
		return

	var order_rule: LayerOrderOverrideRule = object as LayerOrderOverrideRule

	# toggle the bit in mask for this quadrant
	var new_mask: int = order_rule.mask ^ (1 << quad_idx)

	emit_changed("mask", new_mask)
	_update_property()


func _cycle_quadrant_order(quad_idx: int) -> void:
	var object: Object = get_edited_object()
	if not object or not object is LayerOrderOverrideRule:
		return

	var order_rule: LayerOrderOverrideRule = object as LayerOrderOverrideRule

	var current_order: Vector4i = order_rule.order
	current_order[quad_idx] = ((current_order[quad_idx] + 1) % 4)

	emit_changed("order", current_order)
	_update_property()


func _get_quadrant_label(idx: int) -> String:
	match idx:
		0: return "Top Left"
		1: return "Top Right"
		2: return "Bottom Left"
		3: return "Bottom Right"
		_: return ""
