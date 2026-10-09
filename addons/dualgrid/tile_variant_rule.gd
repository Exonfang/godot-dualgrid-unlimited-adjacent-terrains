class_name TileVariantRule
extends Resource
## Defines full tile variants and edge variants for a single source id in a [DualGridTileSet].
##
## Full tile variants are only used in place of the full tile (atlas coords 2,1), when all four world tiles around a display tile are the same terrain. Each variant must be a tile in the same source as the terrain it varies, which keeps every terrain's variants inside its own tileset.
## [br]
## Edge variants are alternate 4x4 sets of edge tiles placed further along the X axis of the same tileset image, identified by their atlas offset.
## [br]
## The chance of each tile being picked comes from its [member TileData.probability], including the original tile itself, so set the probability on each tile in the TileSet editor to control how often variants appear.


## The source id in the parent [DualGridTileSet] that these variants belong to
@export_range(0, 256, 1, "or_greater") var source_id: int
## The atlas coords of the full tile variants within the [member source_id] tileset image. Coords without a tile in the source are ignored.
@export var full_tile_variant_atlas_coords: Array[Vector2i]
## The atlas X offsets of alternate 4x4 sets of the main terrain edge tiles (the set at offset 0) in the [member source_id] tileset image. Each edge tile is picked between the main tile and the matching tile at each of these offsets. Tiles missing from the source are ignored.
@export_range(8, 256, 1, "or_greater") var edge_variant_offsets: Array[int]
## The atlas X offsets of alternate 4x4 sets of the generic mix edge tiles (the set at offset 4) in the [member source_id] tileset image. Each generic mix tile is picked between the generic mix tile and the matching tile at each of these offsets. Tiles missing from the source are ignored.
@export_range(8, 256, 1, "or_greater") var generic_mix_edge_variant_offsets: Array[int]
