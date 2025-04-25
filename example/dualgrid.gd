class_name DualGrid extends TileMapLayer
## A custom DualGrid implementation which combines this node with four TileMapLayer nodes to allow any terrain tile to sit directly next to any other terrain tile without requiring bespoke mixes for each combination, while requiring fewer tiles than Godot's default TileMapLayer terrain implementation. Bespoke mixes can be optionally added for any combination of two terrains.
## 
## The DualGrid is considered the "world layer" and contains the logical tiles used to build the "display layers". The world layer is completely hidden at runtime and the "display layers" combine to create the illusion of the tiles placed in the "world layer" created in this DualGrid. Instead of visually drawing borders at the edges of tiles, borders are drawn through the center of each tile which allows only four peering neighbors to significantly reduce the required tiles to create functioning terrains (1 "alias" tile, 15 terrain tiles, and 15 generic mix tiles per terrain). By using four display layers instead of just one, any tile can sit directly next to any other tile without requiring bespoke mixes for each combination. If desired, bespoke mixes can easily be added for any combination of two terrains, which overwrite the generic mixes when the entire world neighborhood is occupied.
## 
## @tutorial(GitHub Repo, with usage outlines): https://github.com/Exonfang/dualgrid


@export var mix_layer_1: TileMapLayer ## The first display layer used to create the illusion of the tiles on the DualGrid.
@export var mix_layer_2: TileMapLayer ## The second display layer used to create the illusion of the tiles on the DualGrid.
@export var mix_layer_3: TileMapLayer ## The third display layer used to create the illusion of the tiles on the DualGrid.
@export var mix_layer_4: TileMapLayer ## The fourth display layer used to create the illusion of the tiles on the DualGrid.
const NEIGHBORS: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)] ## When world or display layers need to reference each other, they use the NEIGHBORS offsets, which correspond to the contributing four tiles from the other "world" or "display" layer. They are ordered in top left, top right, bottom left, bottom right.

## Terrain peering dictionary. Referenced to determine which tile in the 4x4 TileSet resource is to be used to achieve the illusion of the terrains. The Array of bools is comprised of the occupied status of the four [member NEIGHBORS] (top left, top right, bottom left, bototm right).
const TERRAIN: Dictionary[Array,Vector2i] = {
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
	[false, false, false, false]: Vector2i(-1,-1), ## empty cell (0,3 is used for the alias instead of being blank)
	[false, false, false, true]: Vector2i(1,3),
	[false, true, true, false]: Vector2i(2,3),
	[true, false, false, false]: Vector2i(3,3)
}
const MIXED_OFFSET: int = 4 ## Added to x values of TERRAIN reference to fetch the MIXED variant of the dual grid tile.
enum TileType { NONE, BLUE, GREEN, ORANGE, PURPLE, RED } ## Maps each unique terrain type.
## Stores relationship of TileTypes to their Terrain's Source ID
var tiletype_to_source_id: Dictionary[TileType, int] = {
	TileType.NONE: -1,
	TileType.BLUE: 0,
	TileType.GREEN: 1,
	TileType.ORANGE: 2,
	TileType.PURPLE: 3,
	TileType.RED: 4
}
var source_id_to_tiletype: Dictionary[int, TileType] ## Stores relationship of source IDs to TileTypes. This is built at _ready from tiletype_to_source_id.
## Example bespoke mix_map. This could be nested within tiletype_to_bespoke_mix if preferred.
var purple_mix_map: Dictionary[TileType, int] = {
	TileType.ORANGE: 8
}
## Maps bespoke mixes for any tilesets that have them. The int value is the X offset to that bespoke mix's terrain. The first bespoke mix will always be 8, and sequential bespoke mixes will be multiples of 4.
var tiletype_to_bespoke_mix: Dictionary[TileType, Dictionary] = {
	TileType.PURPLE: purple_mix_map
}


## Builds source_id_to_tiletype from tiletype_to_source_id and creates display tiles for all occupied positions in the DualGrid.
func _ready() -> void:
	# builds source_id_to_tiletype from tiletype_to_source_id dict
	for key: TileType in tiletype_to_source_id.keys():
		source_id_to_tiletype[tiletype_to_source_id[key]] = key
	# set initial display tiles for the "display layers"
	if not Engine.is_editor_hint():
		for _position: Vector2i in get_used_cells():
			set_display_tiles(_position)
		hide()


## Call to update all display tiles in the DualGrid. This is not intended to be called when a single cell is updated.
func update_all_tiles() -> void:
	for _coord: Vector2i in get_used_cells():
		set_display_tiles(_coord)


## Called to update the four display tiles for a given [member at_coords] "world layer" position.
func set_display_tiles(_at_coords: Vector2i) -> void:
	# loop through the display neighborhood
	for neighbor: int in range(NEIGHBORS.size()):
		var display_coords: Vector2i = _at_coords + NEIGHBORS[neighbor]
		calculate_display_tiles(display_coords)


## Creates display tiles at the "display layer" position [member _display_coords] across the four "display layers" based on the neighborhood of the "world layer".
func calculate_display_tiles(_display_coords: Vector2i) -> void:
	# loop through the world neighborhood, building an array of tiletypes (top left, top right, bottom left, bottom right)
	var world_neighborhood: Array[TileType]
	for neighbor: int in range(NEIGHBORS.size()):
		var world_coords: Vector2i = _display_coords - NEIGHBORS[neighbor]
		world_neighborhood.append(get_world_tile(world_coords))
	
	# In the demo project, we want the lower two neighborhood tiles to be ordered above the top two neighborhood tiles. We do this by iterating through the display layers from the last layer to the front, but in this edge case (X, Y, X, X) we need to inverse that to achieve the same visual style. You may need to account for different edge cases given your project's ordering needs.
	## EDGE CASE check - X, Y, X, X -- we need to change the layer order so the Y is above X
	var y_sort_fix: bool
	if (world_neighborhood[0] != TileType.NONE) and (world_neighborhood[0] != world_neighborhood[1]) and (world_neighborhood[0] == world_neighborhood[3]) and (world_neighborhood[0] == world_neighborhood[2]):
		y_sort_fix = true
	else:
		y_sort_fix = false
	
	## This creates a readable neighborhood string to aid in debugging or extending. Uncomment to utilize.
	#var pretty_world_neighborhood: String = ""
	#var count: int = 0
	#for tile: TileType in world_neighborhood:
		#if count != 0:
			#pretty_world_neighborhood += ", "
		#count += 1
		#pretty_world_neighborhood += str(TileType.keys()[tile])
	#print("world_neighborhood (at ", _display_coords, "): ", pretty_world_neighborhood)
	
	# build a unique tiles array so we can determine which display layers to update.
	var tiles_excluding_empty: Array[TileType] = world_neighborhood.filter(is_tile_filled)
	var unique_tiles: Array[TileType]
	for tile: TileType in tiles_excluding_empty:
		if !unique_tiles.has(tile):
			unique_tiles.append(tile)
	
	remove_display_tiles(_display_coords) # clear any tiles in the display position we're about to update.
	if unique_tiles.size() == 1:
		# display positions with only one terrain require only a single layer, so we can use a simplified function to save cpu.
		mix_layer_1.set_cell(_display_coords, tiletype_to_source_id[unique_tiles[0]], calculate_display_tile(_display_coords))
	else:
		# In the demo project, we want the botttom two tiles to appear in front of the top two tiles; because we're looping through the world neighborhood in top left, top right, bottom left, bottom right, by inversing the layers we paint here, we make sure that the bottom row of tiles always sits on top of the top row. Your project might want to inverse this depending on your terrain art.
		var _tile_count: int = 0
		for tile: TileType in unique_tiles:
			var paint_layer: TileMapLayer
			var paint_layer_map: Dictionary[int, TileMapLayer]
			if y_sort_fix == false:
				# default behavior
				paint_layer_map = {
					0: mix_layer_4,
					1: mix_layer_3,
					2: mix_layer_2,
					3: mix_layer_1
				}
			else:
				# Our Edge case (checking [X, Y, X, X]) takes action here
				paint_layer_map = {
					0: mix_layer_1,
					1: mix_layer_2,
					2: mix_layer_3,
					3: mix_layer_4
				}
			paint_layer = paint_layer_map[_tile_count]
			paint_layer.set_cell(_display_coords, tiletype_to_source_id[tile], calculate_display_tile_for_tiletype(_display_coords, tile, unique_tiles))
			_tile_count += 1


## Removes all display tiles for a given "display layer" position [member _at_coords]
func remove_display_tiles(_at_coords: Vector2i) -> void:
	mix_layer_1.set_cell(_at_coords, -1)
	mix_layer_2.set_cell(_at_coords, -1)
	mix_layer_3.set_cell(_at_coords, -1)
	mix_layer_4.set_cell(_at_coords, -1)


## Filtering function which returns true when the provided [member tile] is not TileType.NONE.
func is_tile_filled(tile: TileType) -> bool:
	if tile == TileType.NONE:
		return false
	else:
		return true


## Calculate which display tile to use at [member _at_coords]. This is a simplified version of [method calculate_display_tile_for_tiletype] used when there is only a single unique tiletype in the neighborhood.
func calculate_display_tile(_at_coords: Vector2i) -> Vector2i:
	var top_left: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[3])
	var top_right: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[2])
	var bottom_left: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[1])
	var bottom_right: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[0])
	var tile_key: Array = [top_left, top_right, bottom_left, bottom_right]
	# print("Generated tile key for ", _at_coords, ": ", tile_key)
	return TERRAIN[tile_key]


## Calculate which display tile to use at [member _at_coords] when there are more than one unique TileTypes in the neighborhood.
func calculate_display_tile_for_tiletype(_at_coords: Vector2i, _tiletype: TileType, _unique_tiles: Array[TileType]) -> Vector2i:
	var alias_id: int = tiletype_to_source_id[_tiletype]
	var top_left: bool = get_world_tile_occupied_with_alias(_at_coords - NEIGHBORS[3], alias_id)
	var top_right: bool = get_world_tile_occupied_with_alias(_at_coords - NEIGHBORS[2], alias_id)
	var bottom_left: bool = get_world_tile_occupied_with_alias(_at_coords - NEIGHBORS[1], alias_id)
	var bottom_right: bool = get_world_tile_occupied_with_alias(_at_coords - NEIGHBORS[0], alias_id)
	var tile_key: Array = [top_left, top_right, bottom_left, bottom_right]
	# print("Generated tile_key for ", _at_coords, ": ", tile_key)
	
	# check for all tiles occupied, so we know when to use the mixed version of the terrain
	var top_left_occupied: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[3])
	var top_right_occupied: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[2])
	var bottom_left_occupied: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[1])
	var bottom_right_occupied: bool = get_world_tile_occupied(_at_coords - NEIGHBORS[0])
	var occupied_key: Array = [top_left_occupied, top_right_occupied, bottom_left_occupied, bottom_right_occupied]
	# print("Generated occupied_key for ", _at_coords, ": ", occupied_key)
	if occupied_key == [true, true, true, true]:
		# check for bespoke mixes (which only exist for unique combinations of 2 tiles)
		if _unique_tiles.size() == 2:
			var count: int = 0
			# for every tile in unique tiles, check if there's a bespoke mix
			for tile: TileType in _unique_tiles:
				# look through bespoke mix dict and see if that type exists
				if tiletype_to_bespoke_mix.has(tile):
					var mix_map: Dictionary[TileType, int]
					mix_map = tiletype_to_bespoke_mix[tile]
					var opposite_tile: TileType
					if count == 0:
						opposite_tile = _unique_tiles[1]
					else:
						opposite_tile = _unique_tiles[0]
					# if the mix_map has the opposite tile, create the bespoke mix using its bespoke_offset.
					if mix_map.has(opposite_tile):
						var bespoke_offset: int
						bespoke_offset = mix_map[opposite_tile]
						return TERRAIN[tile_key] + Vector2i(bespoke_offset, 0)
				count += 1
		# if there isn't a bespoke terrain, use the generic mix offset
		return TERRAIN[tile_key] + Vector2i(MIXED_OFFSET, 0)
	else:
		return TERRAIN[tile_key]


## Returns true if world tile is occupied at [member _at_coords].
func get_world_tile_occupied(_at_coords: Vector2i) -> bool:
	if get_cell_source_id(_at_coords) != -1:
		return true
	else:
		return false


## Returns true if world tile [member _at_coords] is occupied with a cell of [member _alias_id]. Helper function for [method calculate_display_tile_for_tiletype].
func get_world_tile_occupied_with_alias(_at_coords: Vector2i, _alias_id: int) -> bool:
	if get_cell_source_id(_at_coords) == _alias_id:
		return true
	else:
		return false


## Gets the world tile (in TileType) for the given world position [member _at_coords]. Helper function for [method calculate_display_tiles]
func get_world_tile(_at_coords: Vector2i) -> TileType:
	var source_id: int = get_cell_source_id(_at_coords)
	return source_id_to_tiletype[source_id]
