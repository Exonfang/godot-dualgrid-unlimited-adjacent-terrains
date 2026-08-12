class_name BespokeMixRule
extends Resource

## The primary source id for this rule in the parent [DualGridTileSet]
@export_range(0, 256, 1, "or_greater") var primary_source_id: int
## The secondary source id for this rule in the parent [DualGridTileSet]
@export_range(0, 256, 1, "or_greater") var secondary_source_id: int
## The atlas offset for this mix, in sequential order within the X axis of the primary source id tileset image.
@export_range(8, 256, 4, "or_greater") var atlas_offset: int = 8
