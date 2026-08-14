@tool
extends EditorPlugin


var plugin: LayerOrderEditorInspectorPlugin


func _enter_tree() -> void:
	plugin = LayerOrderEditorInspectorPlugin.new() 
	add_inspector_plugin(plugin)


func _exit_tree() -> void:
	if plugin:
		remove_inspector_plugin(plugin)
