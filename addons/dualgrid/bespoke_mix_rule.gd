class_name BespokeMixRule
extends Resource
## Defines a relationship between two source ids in a [DualGridTileSet] with an offset in the atlas for bespoke tile merging.


## The primary source id for this rule in the parent [DualGridTileSet]
@export_range(0, 256, 1, "or_greater") var primary_source_id: int
## The secondary source id for this rule in the parent [DualGridTileSet]
@export_range(0, 256, 1, "or_greater") var secondary_source_id: int
## The atlas offset for this mix, in sequential order within the X axis of the primary source id tileset image.
@export_range(8, 256, 4, "or_greater") var atlas_offset: int = 8
## The atlas offsets of alternate 4x4 sets of this mix's edge tiles, in the primary source id tileset image. Each edge tile of the mix is picked between the tile at [member atlas_offset] and the matching tile at each of these offsets, by tile probability. Tiles missing from the source are ignored.
@export_range(8, 256, 4, "or_greater") var bespoke_mix_variant_offsets: Array[int]
