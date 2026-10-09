@tool
class_name DualGridTileSet
extends TileSet
## A TileSet with extended functionality to support bespoke tile mixing and tile variants in a [DualGrid]

## The atlas coords of the full terrain tile, which is the only tile that can be replaced by a full tile variant.
const FULL_TILE_ATLAS_COORDS: Vector2i = Vector2i(2, 1)

## List of bespoke mixes configured for this TileSet.
@export var bespoke_mixes: Array[BespokeMixRule]
## List of full tile variants and edge variants configured for this TileSet. Each rule only adds variants to its own source id.
@export var tile_variants: Array[TileVariantRule]:
	set(value):
		tile_variants = value
		_variant_cache_built = false
@export_storage var _mix_cache: Dictionary[Vector2i, int]
## Lookup of [primary source id, secondary source id] to the edge variant atlas offsets of that mix
@export_storage var _mix_variant_cache: Dictionary[Vector2i, Array]
## Lookup of source id to [Array[Vector2i] atlas coords, PackedFloat32Array cumulative probabilities] for the full tile and its variants
var _variant_cache: Dictionary[int, Array] = {}
## Lookup of source id to [Array[int] edge variant offsets, Array[int] generic mix edge variant offsets]
var _edge_variant_cache: Dictionary[int, Array] = {}
var _variant_cache_built: bool = false


## Rebuilds the internal lookup dictionary from the bespoke_mixes array.
func rebuild_cache() -> void:
	_mix_cache.clear()
	_mix_variant_cache.clear()
	for mix: BespokeMixRule in bespoke_mixes:
		if mix and mix.primary_source_id >= 0 and mix.secondary_source_id >= 0:
			var key: Vector2i = Vector2i(mix.primary_source_id, mix.secondary_source_id)
			_mix_cache[key] = mix.atlas_offset
			_mix_variant_cache[key] = mix.bespoke_mix_variant_offsets.duplicate()


## Checks if a bespoke mix exists between two source IDs. Returns Array [primary_source_id: int, atlas_offset: int, variant_atlas_offsets: Array[int]] or an empty Array if no mix exists
func get_bespoke_mix(source_a: int, source_b: int) -> Array:
	# Rebuild the cache every time in the editor, @export_storage ensures that it is updated for fast access during runtime calls
	if Engine.is_editor_hint():
		rebuild_cache()

	var key_a: Vector2i = Vector2i(source_a, source_b)
	if _mix_cache.has(key_a):
		return [source_a, _mix_cache[key_a], _mix_variant_cache.get(key_a, [])]

	var key_b: Vector2i = Vector2i(source_b, source_a)
	if _mix_cache.has(key_b):
		return [source_b, _mix_cache[key_b], _mix_variant_cache.get(key_b, [])]

	return []


## Rebuilds the internal variant lookups from the tile_variants array and the tile probabilities. Call this if tile_variants or tile probabilities are changed at runtime.
func rebuild_variant_cache() -> void:
	_variant_cache.clear()
	_edge_variant_cache.clear()
	_variant_cache_built = true

	# Collect the variants for each source, merging any rules that share a source id
	var coords_by_source: Dictionary[int, Array] = {}
	for rule: TileVariantRule in tile_variants:
		if not rule or not has_source(rule.source_id): continue
		var source: TileSetAtlasSource = get_source(rule.source_id) as TileSetAtlasSource
		if not source: continue

		if not rule.edge_variant_offsets.is_empty() or not rule.generic_mix_edge_variant_offsets.is_empty():
			if not _edge_variant_cache.has(rule.source_id):
				_edge_variant_cache[rule.source_id] = [[], []]
			var edge_offsets: Array = _edge_variant_cache[rule.source_id]
			for offset: int in rule.edge_variant_offsets:
				if not edge_offsets[0].has(offset): edge_offsets[0].append(offset)
			for offset: int in rule.generic_mix_edge_variant_offsets:
				if not edge_offsets[1].has(offset): edge_offsets[1].append(offset)

		if not source.has_tile(FULL_TILE_ATLAS_COORDS): continue

		if not coords_by_source.has(rule.source_id):
			coords_by_source[rule.source_id] = [FULL_TILE_ATLAS_COORDS]
		var source_coords: Array = coords_by_source[rule.source_id]
		for atlas_coords: Vector2i in rule.full_tile_variant_atlas_coords:
			if source.has_tile(atlas_coords) and not source_coords.has(atlas_coords):
				source_coords.append(atlas_coords)

	for source_id: int in coords_by_source:
		var source: TileSetAtlasSource = get_source(source_id) as TileSetAtlasSource
		var source_coords: Array[Vector2i] = []
		source_coords.assign(coords_by_source[source_id])
		if source_coords.size() < 2: continue

		var cumulative_probabilities: PackedFloat32Array = []
		var total_probability: float = 0.0
		for atlas_coords: Vector2i in source_coords:
			total_probability += maxf(source.get_tile_data(atlas_coords, 0).probability, 0.0)
			cumulative_probabilities.append(total_probability)
		if total_probability <= 0.0: continue

		_variant_cache[source_id] = [source_coords, cumulative_probabilities]


## Returns the atlas coords to display in place of the full tile for a source id, picked between the full tile and its variants by tile probability. [param roll] is a value in the range [0, 1). Returns [constant FULL_TILE_ATLAS_COORDS] if the source has no variants.
func get_full_tile_variant(source_id: int, roll: float) -> Vector2i:
	# Rebuild the cache every time in the editor so changes to rules and tile probabilities are previewed
	if Engine.is_editor_hint() or not _variant_cache_built:
		rebuild_variant_cache()

	if not _variant_cache.has(source_id):
		return FULL_TILE_ATLAS_COORDS

	var source_coords: Array[Vector2i] = _variant_cache[source_id][0]
	var cumulative_probabilities: PackedFloat32Array = _variant_cache[source_id][1]
	var target: float = roll * cumulative_probabilities[-1]
	for i: int in range(cumulative_probabilities.size()):
		if target < cumulative_probabilities[i]:
			return source_coords[i]

	return source_coords[-1]


## Returns the edge variant atlas offsets configured for a source id, for the generic mix tiles if [param generic_mix] is true, otherwise for the main terrain tiles. Returns an empty Array if there are none.
func get_edge_variant_offsets(source_id: int, generic_mix: bool) -> Array:
	# Rebuild the cache every time in the editor so changes to rules are previewed
	if Engine.is_editor_hint() or not _variant_cache_built:
		rebuild_variant_cache()

	if not _edge_variant_cache.has(source_id):
		return []
	return _edge_variant_cache[source_id][1 if generic_mix else 0]


## Returns the atlas coords to display for an edge tile, picked by tile probability between [param atlas_coords] and the matching tile in each of the alternate 4x4 sets at [param variant_offsets]. [param base_offset] is the atlas X offset of the 4x4 set [param atlas_coords] is in. [param roll] is a value in the range [0, 1). The full tile is never replaced, and variant tiles missing from the source are ignored.
func get_edge_variant(source_id: int, atlas_coords: Vector2i, base_offset: int, variant_offsets: Array, roll: float) -> Vector2i:
	if variant_offsets.is_empty():
		return atlas_coords

	var local_coords: Vector2i = atlas_coords - Vector2i(base_offset, 0)
	if local_coords == FULL_TILE_ATLAS_COORDS or not has_source(source_id):
		return atlas_coords
	var source: TileSetAtlasSource = get_source(source_id) as TileSetAtlasSource
	if not source or not source.has_tile(atlas_coords):
		return atlas_coords

	var candidates: Array[Vector2i] = [atlas_coords]
	var cumulative_probabilities: PackedFloat32Array = [maxf(source.get_tile_data(atlas_coords, 0).probability, 0.0)]
	for variant_offset: int in variant_offsets:
		var variant_coords: Vector2i = local_coords + Vector2i(variant_offset, 0)
		if variant_offset == base_offset or candidates.has(variant_coords) or not source.has_tile(variant_coords): continue
		candidates.append(variant_coords)
		cumulative_probabilities.append(cumulative_probabilities[-1] + maxf(source.get_tile_data(variant_coords, 0).probability, 0.0))

	if candidates.size() < 2 or cumulative_probabilities[-1] <= 0.0:
		return atlas_coords

	var target: float = roll * cumulative_probabilities[-1]
	for i: int in range(cumulative_probabilities.size()):
		if target < cumulative_probabilities[i]:
			return candidates[i]

	return candidates[-1]
