@tool
class_name LayerOrderEditorInspectorPlugin
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is LayerOrderOverrideRule


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "mask" and type == TYPE_INT:
		add_property_editor(name, EditorPropertyLayerOverride.new(), false, "Layer Order")
		return true

	if name == "order" and type == TYPE_VECTOR4I:
		return true

	return false
