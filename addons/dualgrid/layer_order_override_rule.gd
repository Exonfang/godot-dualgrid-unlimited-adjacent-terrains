@tool
class_name LayerOrderOverrideRule
extends Resource
## A description of a layering rule for a [DualGrid] to handle edge cases in art layering based on the tile set art style.


## A mask for which display tiles are in the neighbourhood of this tile, where masked quadrants detect if they are the the same source. Left clicking a quadrant enables the mask for that quadrant, right clicking cycles the layer to display that quadrant on.
@export_flags("TL", "TR", "BL", "BR") var mask: int = 0:
	set(value):
		mask = value
		emit_changed()


## The configuration of display layers to place the various quadrants in
@export var order: Vector4i = Vector4i(0, 1, 2, 3):
	set(value):
		order = value
		emit_changed()
