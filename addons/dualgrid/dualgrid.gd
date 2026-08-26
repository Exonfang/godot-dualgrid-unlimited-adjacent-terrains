@tool
@icon("res://addons/dualgrid/dualgrid.svg")
class_name DualGrid
extends TileMapLayer
## A custom DualGrid implementation which allows any terrain tile to sit directly next to any other terrain tile without requiring bespoke mixes for each combination, while requiring fewer tiles than Godot's default TileMapLayer terrain implementation. Bespoke mixes can be optionally added for any combination of two terrains.
## 
## The DualGrid is considered the "world layer" and contains the logical tiles used to build the "display layers". 
## [br]
## The world layer is completely hidden at runtime and the "display layers" combine to create the illusion of the tiles placed in the "world layer" created in this DualGrid. 
## [br]
## Instead of visually drawing borders at the edges of tiles, borders are drawn through the center of each tile which allows only four peering neighbors to significantly reduce the required tiles to create functioning terrains (15 terrain tiles, and 15 generic mix tiles per terrain). 
## [br]
## By using four display layers instead of just one, any tile can sit directly next to any other tile without requiring bespoke mixes for each combination. 
## [br]
## If desired, bespoke mixes can easily be added for any combination of two terrains, which overwrite the generic mixes when the entire world neighborhood is occupied.
## [br]
## Changes to the DualGrid's properties, including but not limited to material and modulation (see [member INHERITED_PROPERTIES]) are passed down to the internal TileMapLayers for the display layers.
## [br]
## To set tiles in the world grid at runtime, do not use [method TileMapLayer.set_cell], use [method set_world_tile] instead
##
## @tutorial(GitHub Repo, with usage outlines): https://github.com/Exonfang/godot-dualgrid-unlimited-adjacent-terrains


@export_tool_button("Toggle Display Layer Preview", "GuiVisibilityVisible") var display_preview_toggle: Callable = func() -> void:
	if _editor_display_layer_visible:
		hide_display_layers()
		_editor_display_layer_visible = false
	else:
		show_display_layers()
		_editor_display_layer_visible = true

@export_tool_button("Refresh Display Layer Preview", "Anchor") var display_preview_refresh: Callable = func() -> void:
	if _editor_display_layer_visible:
		_sync_inherited_properties()
		update_all_tiles()

## Enables collision on the internal display TileMapLayers.
@export var display_collision_enabled: bool = true:
	set(value):
		display_collision_enabled = value
		if is_instance_valid(_mix_layer_1):
			_set_display_layer_property(&"collision_enabled", value)

## Enables navigation on the internal display TileMapLayers.
@export var display_navigation_enabled: bool = false:
	set(value):
		display_navigation_enabled = value
		if is_instance_valid(_mix_layer_1):
			_set_display_layer_property(&"navigation_enabled", value)

@export_group("Display Layer Ordering")
## When the display layer preview is enabled in the editor, enables changes to the layer ordering to update the preview. Enabling this for large tile maps could be quite laggy.
@export var live_ordering_update_preview: bool = true
## Reverse the default layering order, dependant on your tile set art style. 
@export var reverse_default_layering_order: bool = false:
	set(value):
		reverse_default_layering_order = value
		if _editor_display_layer_visible and live_ordering_update_preview:
			update_all_tiles()

## A collection of [LayerOrderOverrideRules] to accomadate cases where the default ordering produces unwanted layering results.
@export var layering_order_rules: Array[LayerOrderOverrideRule]:
	set(value):
		for rule: LayerOrderOverrideRule in layering_order_rules:
			if not is_instance_valid(rule): continue
			if rule.changed.is_connected(_on_layer_order_exception_rule_changed):
				rule.changed.disconnect(_on_layer_order_exception_rule_changed)

		layering_order_rules = value
		for rule: LayerOrderOverrideRule in layering_order_rules:
			if not is_instance_valid(rule): continue
			rule.changed.connect(_on_layer_order_exception_rule_changed)

@export_storage var _mix_layer_1: TileMapLayer
@export_storage var _mix_layer_2: TileMapLayer
@export_storage var _mix_layer_3: TileMapLayer
@export_storage var _mix_layer_4: TileMapLayer
var _mix_layers: Array[TileMapLayer]:
	get():
		if _mix_layers.is_empty():
			if not is_instance_valid(_mix_layer_1): _setup_layers()
			else: _mix_layers = [_mix_layer_1, _mix_layer_2, _mix_layer_3, _mix_layer_4]
		return _mix_layers

## List of properties which should be inherited by the inner display TileMapLayers
const INHERITED_PROPERTIES: Array[StringName] = [
	# TileMapLayer
	&"tile_set",
	&"enabled",
	&"occlusion_enabled",
	&"y_sort_origin",
	&"x_draw_order_reversed",
	&"rendering_quadrant_size",
	&"physics_quadrant_size",
	&"use_kinematic_bodies",
	&"collision_visibility_mode",
	&"navigation_visibility_mode",

	# CanvasItem
	&"show_behind_parent",
	&"top_level",
	&"clip_children",
	&"light_mask",
	&"visibility_layer",
	&"material",
	&"use_parent_material",
	&"z_index",
	&"z_as_relative",
	&"y_sort_enabled",
	&"texture_filter",
	&"texture_repeat",

	# Node / Object
	&"process_mode",
	&"process_priority",
	&"process_physics_priority",
	&"process_thread_group",
	&"physics_interpolation_mode",
]

## When world or display layers need to reference each other, they use the NEIGHBORS offsets, which correspond to the contributing four tiles from the other "world" or "display" layer. They are ordered in top left, top right, bottom left, bottom right.
const _NEIGHBORS: Array[Vector2i] = [Vector2i(), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]
## Terrain peering dictionary. Referenced to determine which tile in the 4x4 TileSet resource is to be used to achieve the illusion of the terrains. The Array of bools is comprised of the occupied status of the four [member NEIGHBORS] (top left, top right, bottom left, bototm right).
const _TERRAIN: Dictionary[Array, Vector2i] = {
	# top row
	[false, false, true, false]: Vector2i(0,0),
	[false, true, false, true]: Vector2i(1,0),
	[true, false, true, true]: Vector2i(2,0),
	[false, false, true, true]: Vector2i(3,0),
	# top middle row
	[true, false, false, true]: Vector2i(0,1),
	[false, true, true, true]: Vector2i(1,1),
	[true, true, true, true]: Vector2i(2,1),
	[true, true, true, false]: Vector2i(3,1),
	# bottom middle row
	[false, true, false, false]: Vector2i(0,2),
	[true, true, false, false]: Vector2i(1,2),
	[true, true, false, true]: Vector2i(2,2),
	[true, false, true, false]: Vector2i(3,2),
	# bottom row
	[false, false, false, false]: Vector2i(-1,-1),
	[false, false, false, true]: Vector2i(1,3),
	[false, true, true, false]: Vector2i(2,3),
	[true, false, false, false]: Vector2i(3,3)
}
## Added to x values of TERRAIN reference to fetch the MIXED variant of the dual grid tile.
const _MIXED_OFFSET: int = 4
## Empty source id
const _NULL_SOURCE_ID: int = -1
## The atlas coords used when placing arbitrary world tiles using [method set_world_tile]
const DEFAULT_WORLD_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 3)

var _editor_display_layer_visible: bool = false
## A type-cast reference to the [member tile_set] as a DualGridTileSet if it is one
var _dual_tile_set: DualGridTileSet:
	get:
		if not tile_set is DualGridTileSet:
			return null
		return tile_set as DualGridTileSet


func _ready() -> void:
	_setup_layers()

	if not Engine.is_editor_hint():
		show_display_layers()
	else:
		hide_display_layers()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not tile_set is DualGridTileSet:
		warnings.append("DualGridTileMap only supports bespoke mixing with a DualGridTileSet as its TileSet.")

	return warnings


## Handle connection to tile_set.changed signal to update the internal display layer tilemap position offsets. Propagate changes to inhertited properties down to the internal TileMapLayers
func _set(property: StringName, value: Variant) -> bool:
	if property == &"tile_set":
		var new_tile_set: TileSet = value as TileSet
		if tile_set != new_tile_set:
			if is_instance_valid(tile_set) and tile_set.changed.is_connected(_update_display_layer_position_offset):
				tile_set.changed.disconnect(_update_display_layer_position_offset)
			new_tile_set.changed.connect(_update_display_layer_position_offset)
			tile_set = new_tile_set
			_set_display_layer_property(property, new_tile_set)
			update_configuration_warnings()
			return true
	
	if INHERITED_PROPERTIES.has(property):
		_set_display_layer_property(property, value)

	return false


## Override virtual function to update the display layer tiles when world tiles are changed 
func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	if forced_cleanup: return
	if not Engine.is_editor_hint(): return
	
	for world_coords: Vector2i in coords:
		_set_display_tiles_for_world_tile(world_coords)


## Sets a property on all internal TileMapLayers
func _set_display_layer_property(property: StringName, value: Variant) -> void:
	for layer: TileMapLayer in _mix_layers:
		layer.set(property, value)


func _setup_layers() -> void:
	if not _mix_layer_1: _mix_layer_1 = TileMapLayer.new()
	if not _mix_layer_2: _mix_layer_2 = TileMapLayer.new()
	if not _mix_layer_3: _mix_layer_3 = TileMapLayer.new()
	if not _mix_layer_4: _mix_layer_4 = TileMapLayer.new()

	_mix_layers = [_mix_layer_1, _mix_layer_2, _mix_layer_3, _mix_layer_4]

	for layer: TileMapLayer in _mix_layers:
		add_child(layer)
		layer.owner = self

	_sync_inherited_properties()
	_set_display_layer_property(&"collision_enabled", display_collision_enabled)
	_set_display_layer_property(&"navigation_enabled", display_navigation_enabled)

	if is_instance_valid(tile_set):
		_update_display_layer_position_offset()


## Position the display tileset layers to be offset by half the tileset size so that the display aligns visually with the properties of the world layer.
func _update_display_layer_position_offset() -> void:
	var position_offset: Vector2i = -1 * tile_set.tile_size / 2
	for layer: TileMapLayer in _mix_layers:
		layer.position = position_offset


func _sync_inherited_properties() -> void:
	for property: StringName in INHERITED_PROPERTIES:
		_set_display_layer_property(property, get(property))


## Updates the display layer tiles for the world tile
func _set_display_tiles_for_world_tile(world_coords: Vector2i) -> void:
	for neighbor: int in range(_NEIGHBORS.size()):
		var display_coords: Vector2i = world_coords + _NEIGHBORS[neighbor]
		_calculate_display_tiles(display_coords)


## Determines what display tile to use at a given display coordinate based on the 4 neighboring tiles in the world grid
func _calculate_display_tiles(display_coords: Vector2i) -> void:
	var neighbouring_source_ids: Array[int] = []
	for neighbor: Vector2i in _NEIGHBORS:
		var world_coords: Vector2i = display_coords - neighbor
		neighbouring_source_ids.append(get_cell_source_id(world_coords))

	# build an array of the unqiue source ids nearby so we can determine which display layers to update.
	var sources_excluding_empty: Array[int] = neighbouring_source_ids.filter(
		func(source_id: int) -> bool:   
			return source_id != _NULL_SOURCE_ID
	)
	var unique_source_ids: Array[int] = []
	for source_id: int in sources_excluding_empty:
		if not unique_source_ids.has(source_id):
			unique_source_ids.append(source_id)

	_remove_display_tiles(display_coords)

	# With only one unique source id nearby the display only requires a single layer
	if unique_source_ids.size() == 1:
		_mix_layer_1.set_cell(display_coords, unique_source_ids[0], _calculate_display_tile(display_coords))
		return

	# Check for bespoke mix between the two unique source ids nearby
	if unique_source_ids.size() == 2 and not neighbouring_source_ids.has(_NULL_SOURCE_ID) and _dual_tile_set:
		var mix_data: Array = _dual_tile_set.get_bespoke_mix(unique_source_ids[0], unique_source_ids[1])
		if not mix_data.is_empty():
			var primary_id: int = mix_data[0]
			var offset: int = mix_data[1]
			var bespoke_tile_atlas_coords: Vector2i = _calculate_bespoke_display_tile(display_coords, primary_id, offset)
			_mix_layer_1.set_cell(display_coords, primary_id, bespoke_tile_atlas_coords)
			return

	# Default generic mixing layer order
	var paint_layers: Array[TileMapLayer] = [_mix_layer_4, _mix_layer_3, _mix_layer_2, _mix_layer_1]
	if reverse_default_layering_order:
		paint_layers.reverse()

	# Check for layer ordering exceptions
	var active_rule: LayerOrderOverrideRule 
	if not layering_order_rules.is_empty():
		active_rule = _get_layer_order_exception(neighbouring_source_ids) 
		if active_rule:
			paint_layers.clear()
			for i: int in range(4):
				paint_layers.append(_mix_layers[active_rule.order[i]])

	# Can now paint layers according to the calculated layer ordering
	for i: int in range(neighbouring_source_ids.size()):
		var source_id: int = neighbouring_source_ids[i]

		if source_id == _NULL_SOURCE_ID:
			paint_layers[i].set_cell(display_coords, _NULL_SOURCE_ID)
			continue

		paint_layers[i].set_cell(
			display_coords, 
			source_id, 
			_calculate_display_tile_for_source_id(display_coords, source_id, i)
		)


## Checks if this configuration of a tile neighbourhood matches any of the layer order overrides. Returns null if no exception is found
func _get_layer_order_exception(neighbourhood_ids: Array[int]) -> LayerOrderOverrideRule:
	for rule: LayerOrderOverrideRule in layering_order_rules:
		if not is_instance_valid(rule): continue
		var target: int
		var has_target: bool = false
		var rule_matches: bool = true

		for i: int in range(4):
			if (rule.mask & (1 << i)) != 0:
				if not has_target:
					target = neighbourhood_ids[i]
					has_target = true
				elif neighbourhood_ids[i] != target:
					rule_matches = false
					break

		if rule_matches:
			return rule

	return null


## Function for updating the editor display layer preview if a layer order override rule changes.
func _on_layer_order_exception_rule_changed() -> void:
	if _editor_display_layer_visible and live_ordering_update_preview:
		update_all_tiles()


## Remove display tiles from all mix layers at the given display coordinates
func _remove_display_tiles(display_coords: Vector2i) -> void:
	_mix_layer_1.set_cell(display_coords, _NULL_SOURCE_ID)
	_mix_layer_2.set_cell(display_coords, _NULL_SOURCE_ID)
	_mix_layer_3.set_cell(display_coords, _NULL_SOURCE_ID)
	_mix_layer_4.set_cell(display_coords, _NULL_SOURCE_ID)


## Calculate which display tiles to use at a world coordinate when it is know that all 4 neighbours are from the same source id.
func _calculate_display_tile(world_coords: Vector2i) -> Vector2i:
	var top_left: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[3])
	var top_right: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[2])
	var bottom_left: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[1])
	var bottom_right: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[0])
	return _TERRAIN[[top_left, top_right, bottom_left, bottom_right]]


## Calculate which bespoke display tile to use at a world coordinate 
func _calculate_bespoke_display_tile(world_coords: Vector2i, source_id: int, offset: int) -> Vector2i:
	var top_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[3], source_id)
	var top_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[2], source_id)
	var bottom_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[1], source_id)
	var bottom_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[0], source_id)
	return _TERRAIN[[top_left, top_right, bottom_left, bottom_right]] + Vector2i(offset, 0)


## Calculate which display tile to use at world coordinate when there are more than one unique source id in the neighborhood.
func _calculate_display_tile_for_source_id(world_coords: Vector2i, source_id: int, tile_count: int) -> Vector2i:
	var top_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[3], source_id)
	var top_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[2], source_id)
	var bottom_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[1], source_id)
	var bottom_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBORS[0], source_id)
	var tile_key: Array = [top_left, top_right, bottom_left, bottom_right]

	# Check for all tiles occupied, so we know when to use the mixed version of the terrain.
	var top_left_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[3])
	var top_right_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[2])
	var bottom_left_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[1])
	var bottom_right_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBORS[0])
	var occupied_key: Array = [top_left_occupied, top_right_occupied, bottom_left_occupied, bottom_right_occupied]

	if occupied_key == [true, true, true, true]:
		if tile_key == [true, false, false, true]:
			if tile_count == 3:
				return Vector2i(3,3) + Vector2i(_MIXED_OFFSET, 0)
			elif tile_count == 0:
				return Vector2i(1,3) + Vector2i(_MIXED_OFFSET, 0)
			else:
				return _TERRAIN[tile_key] + Vector2i(_MIXED_OFFSET, 0)
		if tile_key == [false, true, true, false]:
			if tile_count == 2:
				return Vector2i(0,2) + Vector2i(_MIXED_OFFSET, 0)
			elif tile_count == 1:
				return Vector2i(0,0) + Vector2i(_MIXED_OFFSET, 0)
			else:
				return _TERRAIN[tile_key] + Vector2i(_MIXED_OFFSET, 0)
		else:
			return _TERRAIN[tile_key] + Vector2i(_MIXED_OFFSET, 0)
	else:
		if tile_key == [true, false, false, true]:
			if tile_count == 3:
				return Vector2i(3,3)
			elif tile_count == 0:
				return Vector2i(1,3)
			else:
				return _TERRAIN[tile_key]
		if tile_key == [false, true, true, false]:
			if tile_count == 2:
				return Vector2i(0,2)
			elif tile_count == 1:
				return Vector2i(0,0)
			else:
				return _TERRAIN[tile_key]
		else:
			return _TERRAIN[tile_key]


func _is_world_tile_occupied(world_coords: Vector2i) -> bool:
	return get_cell_source_id(world_coords) != _NULL_SOURCE_ID


func _is_world_tile_occupied_by_source(world_coords: Vector2i, souce_id: int) -> bool:
	if souce_id == _NULL_SOURCE_ID:
		return false
	return get_cell_source_id(world_coords) == souce_id


## Makes the display layers visible and hides the world grid.
func show_display_layers() -> void:
	self_modulate.a = 0.0
	for layer: TileMapLayer in _mix_layers:
		layer.show()


## Makes the display layers invisible and reveals the world grid.
func hide_display_layers() -> void:
	self_modulate.a = 1.0
	for layer: TileMapLayer in _mix_layers:
		layer.hide()


## Sets a tile on the world grid based on the source_id and updates the display tiles for that world tile
func set_world_tile(world_coords: Vector2i, source_id: int) -> void:
	set_cell(world_coords, source_id, DEFAULT_WORLD_TILE_ATLAS_COORDS)
	_set_display_tiles_for_world_tile(world_coords)


## Forcibly updates the display layers for all world grid tiles. Use sparingly, will cause a lag spike
func update_all_tiles() -> void:
	for layer: TileMapLayer in _mix_layers:
		layer.clear()
	for world_coords: Vector2i in get_used_cells():
		_set_display_tiles_for_world_tile(world_coords)
