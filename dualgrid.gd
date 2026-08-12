@tool
class_name DualGridTileMapLayer
extends TileMapLayer
## DO NOT USE [method TileMapLayer.set_cell], use [method set_world_tile] instead

@export_tool_button("Toggle Display Layer View") var display_view_toggle: Callable = func() -> void:
    if _editor_display_layer_visible:
        hide_display_layers()
        _editor_display_layer_visible = false
    else:
        update_all_tiles()
        show_display_layers()
        _editor_display_layer_visible = true

@export_storage var _mix_layer_1: TileMapLayer
@export_storage var _mix_layer_2: TileMapLayer
@export_storage var _mix_layer_3: TileMapLayer
@export_storage var _mix_layer_4: TileMapLayer

const _NEIGHBOURS: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]
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
const _MIXED_OFFSET: int = 4
const _NULL_SOURCE_ID: int = -1
## The atlas coords used when placing arbitrary world tiles using [method set_world_tile]
const DEFAULT_WORLD_TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 3)

var _editor_display_layer_visible: bool = false
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


func _notification(what: int) -> void:
    if what == NOTIFICATION_EDITOR_PRE_SAVE:
        _cache_display_layers()


func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []

    if not tile_set is DualGridTileSet:
        warnings.append("DualGridTileMap only supports bespoke mixing with a DualGridTileSet as its TileSet.")

    return warnings


## Handle connection to tile_set.changed signal to update the internal display layer tilemap position offsets
func _set(property: StringName, value: Variant) -> bool:
    if not property == &"tile_set":
        return false

    var new_tile_set: TileSet = value as TileSet
    if tile_set == new_tile_set:
        return false
    if tile_set.changed.is_connected(_update_display_layer_position_offset):
        tile_set.changed.disconnect(_update_display_layer_position_offset)
    new_tile_set.changed.connect(_update_display_layer_position_offset)

    return false


func _setup_layers() -> void:
    if not _mix_layer_1: _mix_layer_1 = TileMapLayer.new()
    if not _mix_layer_2: _mix_layer_2 = TileMapLayer.new()
    if not _mix_layer_3: _mix_layer_3 = TileMapLayer.new()
    if not _mix_layer_4: _mix_layer_4 = TileMapLayer.new()

    var mix_layers: Array[TileMapLayer] = [_mix_layer_1, _mix_layer_2, _mix_layer_3, _mix_layer_4]

    for layer: TileMapLayer in mix_layers:
        layer.tile_set = tile_set
        layer.collision_enabled = false
        layer.navigation_enabled = false
        add_child(layer)

    if is_instance_valid(tile_set):
        _update_display_layer_position_offset()


func _update_display_layer_position_offset() -> void:
    var position_offset: Vector2i = -1 * tile_set.tile_size / 2
    _mix_layer_1.position = position_offset
    _mix_layer_2.position = position_offset
    _mix_layer_3.position = position_offset
    _mix_layer_4.position = position_offset
    

## Makes the display layers visible and hides the world grid
func show_display_layers() -> void:
    self_modulate.a = 0.0
    _mix_layer_1.show()
    _mix_layer_2.show()
    _mix_layer_3.show()
    _mix_layer_4.show()


## Makes the display layers invisible and reveals the world grid
func hide_display_layers() -> void:
    self_modulate.a = 1.0
    _mix_layer_1.hide()
    _mix_layer_2.hide()
    _mix_layer_3.hide()
    _mix_layer_4.hide()


## Sets a tile on the world grid based on the source_id and updates the display tiles for that world tile
func set_world_tile(world_coords: Vector2i, source_id: int) -> void:
    set_cell(world_coords, source_id, DEFAULT_WORLD_TILE_ATLAS_COORDS)
    _set_display_tiles_for_world_tile(world_coords)


## Forcibly updates the display layers for all world grid tiles. Use sparingly, will cause a lag spike
func update_all_tiles() -> void:
    for world_coords: Vector2i in get_used_cells():
        _set_display_tiles_for_world_tile(world_coords)


func _set_display_tiles_for_world_tile(world_coords: Vector2i) -> void:
    for neighbour: int in range(_NEIGHBOURS.size()):
        var display_coords: Vector2i = world_coords + _NEIGHBOURS[neighbour]
        _calculate_display_tiles(display_coords)


func _calculate_display_tiles(display_coords: Vector2i) -> void:
    var neighbouring_sources: Array[int] = []
    for neighbour: int in range(_NEIGHBOURS.size()):
        var world_coords: Vector2i = display_coords - _NEIGHBOURS[neighbour]
        neighbouring_sources.append(get_cell_source_id(world_coords))
    
    var sources_excluding_empty: Array[int] = neighbouring_sources.filter(func(source_id: int) -> bool: return source_id != _NULL_SOURCE_ID)
    var unique_sources: Array[int] = []
    for source_id: int in sources_excluding_empty:
        if not unique_sources.has(source_id):
            unique_sources.append(source_id)
    
    _remove_display_tiles(display_coords)
    
    if unique_sources.size() == 1:
        _mix_layer_1.set_cell(display_coords, unique_sources[0], _calculate_display_tile(display_coords))
        return

    if unique_sources.size() == 2 and not neighbouring_sources.has(_NULL_SOURCE_ID) and _dual_tile_set:
        var mix_data: Array = _dual_tile_set.get_bespoke_mix(unique_sources[0], unique_sources[1])
        if not mix_data.is_empty():
            var primary_id: int = mix_data[0]
            var offset: int = mix_data[1]
            _mix_layer_1.set_cell(
                display_coords, 
                primary_id, 
                _calculate_bespoke_display_tile(display_coords, primary_id, offset)
            )
            return

    var paint_layers: Array[TileMapLayer] = [_mix_layer_4, _mix_layer_3, _mix_layer_2, _mix_layer_1]
    for i: int in range(neighbouring_sources.size()):
        var source_id: int = neighbouring_sources[i]

        if source_id == -1:
            paint_layers[i].set_cell(display_coords, _NULL_SOURCE_ID)
            continue

        paint_layers[i].set_cell(
            display_coords, 
            source_id, 
            _calculate_display_tile_for_source_id(display_coords, source_id, i)
        )


func _remove_display_tiles(display_coords: Vector2i) -> void:
    _mix_layer_1.set_cell(display_coords, _NULL_SOURCE_ID)
    _mix_layer_2.set_cell(display_coords, _NULL_SOURCE_ID)
    _mix_layer_3.set_cell(display_coords, _NULL_SOURCE_ID)
    _mix_layer_4.set_cell(display_coords, _NULL_SOURCE_ID)


func _calculate_display_tile(world_coords: Vector2i) -> Vector2i:
    var top_left: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[3])
    var top_right: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[2])
    var bottom_left: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[1])
    var bottom_right: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[0])
    return _TERRAIN[[top_left, top_right, bottom_left, bottom_right]]


func _calculate_bespoke_display_tile(world_coords: Vector2i, source_id: int, offset: int) -> Vector2i:
    var top_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[3], source_id)
    var top_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[2], source_id)
    var bottom_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[1], source_id)
    var bottom_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[0], source_id)
    return _TERRAIN[[top_left, top_right, bottom_left, bottom_right]] + Vector2i(offset, 0)


func _calculate_display_tile_for_source_id(world_coords: Vector2i, source_id: int, tile_count: int) -> Vector2i:
    var top_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[3], source_id)
    var top_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[2], source_id)
    var bottom_left: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[1], source_id)
    var bottom_right: bool = _is_world_tile_occupied_by_source(world_coords - _NEIGHBOURS[0], source_id)
    var tile_key: Array = [top_left, top_right, bottom_left, bottom_right]

    var top_left_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[3])
    var top_right_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[2])
    var bottom_left_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[1])
    var bottom_right_occupied: bool = _is_world_tile_occupied(world_coords - _NEIGHBOURS[0])
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


func _cache_display_layers() -> void:
    _mix_layer_1.clear()
    _mix_layer_2.clear()
    _mix_layer_3.clear()
    _mix_layer_4.clear()

    update_all_tiles()