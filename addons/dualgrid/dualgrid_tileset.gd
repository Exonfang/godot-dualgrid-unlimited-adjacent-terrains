@tool
class_name DualGridTileSet
extends TileSet
## A TileSet with extended functionality to support bespoke tile mixing in a [DualGrid]

## List of bespoke mixes configured for this TileSet.
@export var bespoke_mixes: Array[BespokeMixRule]
@export_storage var _mix_cache: Dictionary[Vector2i, int]


## Rebuilds the internal lookup dictionary from the bespoke_mixes array.
func rebuild_cache() -> void:
	_mix_cache.clear()
	for mix: BespokeMixRule in bespoke_mixes:
		if mix and mix.primary_source_id >= 0 and mix.secondary_source_id >= 0:
			_mix_cache[Vector2i(mix.primary_source_id, mix.secondary_source_id)] = mix.atlas_offset


## Checks if a bespoke mix exists between two source IDs. Returns Array [primary_source_id: int, atlas_offset: int] or an empty Array if no mix exists
func get_bespoke_mix(source_a: int, source_b: int) -> Array:
	# Rebuild the cache every time in the editor, @export_storage ensures that it is updated for fast access during runtime calls 
	if Engine.is_editor_hint():
		rebuild_cache()

	var key_a: Vector2i = Vector2i(source_a, source_b)
	if _mix_cache.has(key_a):
		return [source_a, _mix_cache[key_a]]

	var key_b: Vector2i = Vector2i(source_b, source_a)
	if _mix_cache.has(key_b):
		return [source_b, _mix_cache[key_b]]

	return []
