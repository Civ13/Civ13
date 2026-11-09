// Ecology-driven wildlife spawning. On by default on every Nomads map.
//
// Wild animals spawn wherever their biome (area climate) and ground suit them,
// anywhere on the map, instead of at fixed map spawn points. Once started the
// owner indexes the map into 8x8 habitat cells, sizes each species' target
// from how much suitable ground the map has, and every cycle tops up species
// below target with small herds. A spawn site must be in a cell players have
// not used recently and out of every player's view range. Map mob spawners
// for species this table covers stay quiet on these maps (see spawner.dm).
// Animals register in their own species lists in New(), so breeding caps and
// deaths keep working unchanged. Nothing here is saved; the heatmap, index
// and census start fresh after a load and count restored animals again.

#define ECOLOGY_CELL_SIZE 8
#define ECOLOGY_CYCLE (60 SECONDS)
#define ECOLOGY_WARMUP (5 MINUTES)
#define ECOLOGY_QUIET_PRESSURE 0.05
#define ECOLOGY_VIEW_MARGIN 15
#define ECOLOGY_ATTEMPTS 24
#define ECOLOGY_INDEX_SAMPLES 6
#define ECOLOGY_INDEX_REFRESH (30 MINUTES)
#define ECOLOGY_SPAWN_BUDGET 30
#define ECOLOGY_HERD_RANGE 3
#define ECOLOGY_MIN_HABITAT 128

// Ground classes a species can stand on.
#define ECO_GRASS 1
#define ECO_DIRT 2
#define ECO_SNOW 4
#define ECO_BEACH 8
#define ECO_SAND 16
#define ECO_WATER 32

var/global/datum/ecology_spawner/ecology_spawner = null
// Set when an admin turns ecology spawning off, so it does not restart itself.
var/global/ecology_admin_disabled = FALSE

/obj/map_metadata
	var/ecology_wildlife = FALSE // Spawn wildlife by habitat instead of fixed map spawners.
	var/ecology_wildlife_cap = 700 // Wild animals across all ecology species.
	var/ecology_density_scale = 2 // Multiplies every species' density; raise for a busier map.

/obj/map_metadata/nomads
	ecology_wildlife = TRUE

// Author policy: code changes take effect on load instead of a saved copy.
/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "ecology_wildlife" || key == "ecology_wildlife_cap" || key == "ecology_density_scale")
		return TRUE
	return ..(key)

// One wild species: what to spawn, which bases count as it, and its habitat.
/datum/ecology_species
	var/name
	var/list/spawn_types = list()
	var/list/covers = list() // census and spawner retirement match these and their subtypes
	var/list/excludes = list() // special subtypes of a covered base that are not this species
	var/target = 0 // the spawner tops up to this many living wild animals
	var/list/biomes = list()
	var/grounds = ECO_GRASS | ECO_DIRT
	var/density = 0 // animals per 1000 tiles of matching habitat
	var/max_target = 0
	var/herd_min = 1
	var/herd_max = 1
	var/habitat_tiles = 0
	var/list/habitat_keys = list()

/datum/ecology_species/New(_name, list/_types, _target, list/_biomes, _grounds = ECO_GRASS | ECO_DIRT, _density = 0, _max = 0, _herd_min = 1, _herd_max = 1, list/_covers = null, list/_excludes = null)
	..()
	name = _name
	spawn_types = _types
	target = _target
	biomes = _biomes
	grounds = _grounds
	density = _density
	max_target = _max ? _max : _target
	herd_min = max(1, _herd_min)
	herd_max = max(herd_min, _herd_max)
	covers = _covers ? _covers : _types.Copy()
	excludes = _excludes ? _excludes : list()

// Living wild animals of this species. Counts the whole world each call; the
// spawner itself uses one shared census per cycle instead.
/datum/ecology_species/proc/population()
	var/total = 0
	for (var/mob/living/simple_animal/A in living_mob_list)
		if (ecology_wild_animal(A) && ecology_match_species(A.type, list(src)) == src)
			total++
	return total

/proc/ecology_wild_animal(mob/living/simple_animal/A)
	if (!istype(A) || QDELETED(A) || A.stat == DEAD || A.client || A.key)
		return FALSE
	if (length(A.friends) || A.rider || A.following_mob)
		return FALSE
	return TRUE

/proc/eco_species(name, list/types, list/biomes, grounds, density, max_target, herd_min = 1, herd_max = 1, list/covers = null, list/excludes = null)
	return new /datum/ecology_species(name, types, 0, biomes, grounds, density, max_target, herd_min, herd_max, covers, excludes)

// Density is animals per 1000 tiles of matching ground; max_target caps a big
// map. Targets stay below each registry's breeding cap so breeding still works.
/proc/ecology_default_species()
	var/G = ECO_GRASS
	var/D = ECO_DIRT
	var/S = ECO_SNOW
	var/B = ECO_BEACH
	var/A = ECO_SAND
	var/W = ECO_WATER
	return list(
		eco_species("deer", list(/mob/living/simple_animal/deer/male, /mob/living/simple_animal/deer/female), list("temperate", "taiga"), G|D|S, 1.2, 70, 2, 3, list(/mob/living/simple_animal/deer)),
		eco_species("elk", list(/mob/living/simple_animal/deer/elk/male, /mob/living/simple_animal/deer/elk/female), list("taiga", "tundra"), G|D|S, 0.5, 25, 2, 2, list(/mob/living/simple_animal/deer/elk)),
		eco_species("reindeer", list(/mob/living/simple_animal/deer/reindeer/male, /mob/living/simple_animal/deer/reindeer/female), list("tundra", "taiga"), D|S, 0.8, 30, 2, 4, list(/mob/living/simple_animal/deer/reindeer)),
		eco_species("dik-dik", list(/mob/living/simple_animal/deer/dikdik/male, /mob/living/simple_animal/deer/dikdik/female), list("savanna", "semiarid"), G|D|A, 0.8, 20, 2, 2, list(/mob/living/simple_animal/deer/dikdik)),
		eco_species("rabbit", list(/mob/living/simple_animal/rabbit), list("temperate", "taiga", "semiarid"), G|D, 0.8, 40, 1, 2),
		eco_species("wild boar", list(/mob/living/simple_animal/boar_boar, /mob/living/simple_animal/boar_gilt), list("temperate", "taiga", "jungle"), G|D|S, 0.4, 30, 2, 2),
		eco_species("sheep", list(/mob/living/simple_animal/sheep, /mob/living/simple_animal/sheep/female), list("temperate", "taiga", "tundra", "semiarid"), G|D|S, 0.7, 50, 2, 4),
		eco_species("goat", list(/mob/living/simple_animal/goat, /mob/living/simple_animal/goat/female), list("semiarid", "desert", "taiga", "temperate"), G|D|S|A, 0.4, 40, 2, 3),
		eco_species("cattle", list(/mob/living/simple_animal/cattle/bull, /mob/living/simple_animal/cattle/cow), list("temperate", "savanna"), G, 0.25, 30, 2, 3, list(/mob/living/simple_animal/cattle)),
		eco_species("pig", list(/mob/living/simple_animal/pig_boar, /mob/living/simple_animal/pig_gilt), list("temperate", "jungle"), G|D, 0.15, 15, 2, 2),
		eco_species("horse", list(/mob/living/simple_animal/horse, /mob/living/simple_animal/horse/beige, /mob/living/simple_animal/horse/black, /mob/living/simple_animal/horse/white), list("temperate", "semiarid", "savanna"), G|D, 0.4, 30, 2, 3, list(/mob/living/simple_animal/horse)),
		eco_species("bison", list(/mob/living/simple_animal/bisonbull, /mob/living/simple_animal/bison), list("temperate", "semiarid"), G, 0.25, 30, 2, 4),
		eco_species("buffalo", list(/mob/living/simple_animal/hostile/buffalo), list("savanna", "jungle"), G|D, 0.4, 15, 2, 3),
		eco_species("camel", list(/mob/living/simple_animal/camel), list("desert"), A|D, 0.8, 25, 1, 2),
		eco_species("turkey", list(/mob/living/simple_animal/turkey_m, /mob/living/simple_animal/turkey_f), list("temperate", "jungle"), G, 0.5, 35, 2, 2),
		eco_species("junglefowl", list(/mob/living/simple_animal/rooster, /mob/living/simple_animal/chicken), list("jungle", "temperate"), G|D, 0.2, 25, 2, 2),
		eco_species("monkey", list(/mob/living/simple_animal/monkey), list("jungle", "savanna"), G|D, 1.0, 30, 2, 3),
		eco_species("parrot", list(/mob/living/simple_animal/parrot), list("jungle"), G|D, 0.6, 20, 1, 2),
		eco_species("gorilla", list(/mob/living/simple_animal/hostile/gorilla), list("jungle"), G, 0.15, 6, 1, 2, null, list(/mob/living/simple_animal/hostile/gorilla/gigantopithecus)),
		eco_species("lizard", list(/mob/living/simple_animal/lizard), list("desert", "semiarid", "savanna"), G|D|A, 0.8, 30),
		eco_species("snake", list(/mob/living/simple_animal/hostile/poison/snake), list("temperate", "semiarid"), G|D, 0.1, 10),
		eco_species("cobra", list(/mob/living/simple_animal/hostile/poison/snake/cobra), list("desert", "semiarid"), A|D, 0.2, 10),
		eco_species("constrictor", list(/mob/living/simple_animal/hostile/poison/snake/constrictor, /mob/living/simple_animal/hostile/poison/snake/constrictor/python), list("jungle"), G|D|W, 0.2, 8, 1, 1, list(/mob/living/simple_animal/hostile/poison/snake/constrictor)),
		eco_species("frog", list(/mob/living/simple_animal/frog), list("temperate", "jungle", "semiarid"), W, 3, 30),
		eco_species("poison frog", list(/mob/living/simple_animal/frog/poisonous), list("jungle"), W, 2, 15),
		eco_species("leech", list(/mob/living/simple_animal/leech), list("jungle", "temperate"), W, 2, 20),
		eco_species("alligator", list(/mob/living/simple_animal/hostile/alligator), list("jungle"), W|D, 0.3, 8),
		eco_species("crab", list(/mob/living/simple_animal/crab/small), list("sea", "temperate", "jungle", "semiarid", "desert", "savanna"), B, 1.5, 30, 1, 2, list(/mob/living/simple_animal/crab/small, /mob/living/simple_animal/crab), list(/mob/living/simple_animal/crab/small/trilobite)),
		eco_species("seagull", list(/mob/living/simple_animal/seagull), list("sea", "temperate", "semiarid"), B, 0.8, 20),
		eco_species("pelican", list(/mob/living/simple_animal/pelican), list("sea"), B, 0.3, 10),
		eco_species("penguin", list(/mob/living/simple_animal/penguin), list("tundra", "taiga"), S, 0.4, 25, 2, 4),
		eco_species("fox", list(/mob/living/simple_animal/hostile/fox), list("temperate", "semiarid"), G|D, 0.25, 20),
		eco_species("arctic fox", list(/mob/living/simple_animal/hostile/fox/arctic), list("tundra", "taiga"), S, 0.3, 15),
		eco_species("wolf", list(/mob/living/simple_animal/hostile/wolf, /mob/living/simple_animal/hostile/wolf/female), list("temperate", "taiga"), G|D|S, 0.2, 24, 2, 3),
		eco_species("white wolf", list(/mob/living/simple_animal/hostile/wolf/white, /mob/living/simple_animal/hostile/wolf/white/female), list("tundra"), S, 0.3, 16, 2, 3),
		eco_species("black bear", list(/mob/living/simple_animal/hostile/bear/boar/black, /mob/living/simple_animal/hostile/bear/sow/black), list("temperate"), G|D, 0.08, 8),
		eco_species("brown bear", list(/mob/living/simple_animal/hostile/bear/boar/brown, /mob/living/simple_animal/hostile/bear/sow/brown), list("taiga", "temperate"), G|D|S, 0.08, 8),
		eco_species("polar bear", list(/mob/living/simple_animal/hostile/bear/boar/polar, /mob/living/simple_animal/hostile/bear/sow/polar), list("tundra"), S, 0.15, 6),
		eco_species("panther", list(/mob/living/simple_animal/hostile/panther), list("jungle"), G|D, 0.1, 6),
		eco_species("jaguar", list(/mob/living/simple_animal/hostile/panther/jaguar), list("jungle", "savanna"), G|D, 0.1, 6),
		eco_species("lion", list(/mob/living/simple_animal/hostile/sabertooth/lion), list("savanna", "semiarid"), G|D|A, 0.2, 8, 1, 3),
	)

// Most specific species whose covered base is an ancestor of the type, or null.
var/global/list/ecology_species_table = null

/proc/ecology_species_list()
	if (ecology_spawner && ecology_spawner.species)
		return ecology_spawner.species
	if (!ecology_species_table)
		ecology_species_table = ecology_default_species()
	return ecology_species_table

/proc/ecology_match_species(path, list/table)
	var/datum/ecology_species/best = null
	var/best_len = 0
	for (var/datum/ecology_species/S in table)
		var/excluded = FALSE
		for (var/special in S.excludes)
			if (ispath(path, special))
				excluded = TRUE
				break
		if (excluded)
			continue
		for (var/base in S.covers)
			if (ispath(path, base) && length("[base]") > best_len)
				best = S
				best_len = length("[base]")
	return best

/proc/ecology_species_for_type(path)
	if (!ispath(path))
		return null
	if (ecology_spawner && ecology_spawner.species)
		return ecology_spawner.species_for_type(path)
	return ecology_match_species(path, ecology_species_list())

// Map spawners stay quiet where ecology spawning runs and this map has
// habitat for their species. Others (caves, special creatures) keep working.
/proc/ecology_replaces_spawner(path)
	if (!map || !map.ecology_wildlife || !ecology_spawner || !ecology_spawner.enabled || ecology_spawner.indexed_at < 0)
		return FALSE
	var/datum/ecology_species/S = ecology_species_for_type(path)
	return S && S.target > 0

/datum/ecology_spawner
	should_save = FALSE
	var/tmp/enabled = FALSE
	var/tmp/datum/ecology_activity_heatmap/heatmap
	var/tmp/list/species
	var/tmp/started_at = 0
	var/tmp/loop_generation = 0
	var/tmp/spawned_total = 0
	var/tmp/last_report = "not started"
	// key "climate|ground" -> list of cell rows; key -> sampled hits
	var/tmp/list/habitat_cells
	var/tmp/list/habitat_hits
	var/tmp/indexed_at = -1
	var/tmp/total_target = 0
	var/tmp/list/last_census
	var/tmp/list/type_cache

/datum/ecology_spawner/New()
	..()
	species = ecology_default_species()

// Cached per spawner: the species table can be replaced (tests, admin edits).
/datum/ecology_spawner/proc/species_for_type(path)
	if (!type_cache || type_cache["table"] != species)
		type_cache = list("table" = species)
	var/key = "[path]"
	if (key in type_cache)
		return type_cache[key]
	var/datum/ecology_species/S = ecology_match_species(path, species)
	type_cache[key] = S
	return S

/datum/ecology_spawner/persistence_runtime_var(key)
	if (key in list("enabled", "heatmap", "species", "started_at", "loop_generation", "spawned_total", "last_report", "habitat_cells", "habitat_hits", "indexed_at", "total_target", "last_census", "type_cache"))
		return TRUE
	return ..()

/datum/ecology_spawner/proc/now_seconds()
	return round(world.time / 10)

/datum/ecology_spawner/proc/start()
	if (enabled)
		return FALSE
	enabled = TRUE
	heatmap = new /datum/ecology_activity_heatmap(4096, ECOLOGY_CYCLE / 10, 1800, 0.25)
	started_at = world.time
	indexed_at = -1
	loop_generation++
	var/generation = loop_generation
	spawn (0)
		while (enabled && generation == loop_generation)
			cycle()
			sleep(ECOLOGY_CYCLE)
	return TRUE

/datum/ecology_spawner/proc/stop()
	if (!enabled)
		return FALSE
	enabled = FALSE
	loop_generation++
	if (heatmap)
		qdel(heatmap)
	heatmap = null
	return TRUE

/proc/ecology_cell_row(turf/T)
	if (!T)
		return null
	return list(T.z, round((T.x - 1) / ECOLOGY_CELL_SIZE) + 1, round((T.y - 1) / ECOLOGY_CELL_SIZE) + 1)

// Active, non-AFK players in the world. Ghosts and lobby players do not count as activity.
/datum/ecology_spawner/proc/activity_rows()
	var/list/rows = list()
	var/list/seen = list()
	for (var/client/C in clients)
		var/mob/living/L = C.mob
		if (!istype(L) || L.stat == DEAD || C.inactivity > 5 MINUTES)
			continue
		var/list/row = ecology_cell_row(get_turf(L))
		if (!row)
			continue
		var/key = "[row[1]]:[row[2]]:[row[3]]"
		if (seen[key])
			continue
		seen[key] = TRUE
		rows += list(row)
	return rows

/datum/ecology_spawner/proc/sample_activity()
	var/list/rows = activity_rows()
	// More distinct occupied cells than one complete sample allows: hold
	// coverage unknown for this epoch rather than truncating it.
	if (rows.len > 256)
		heatmap.reset_epoch(now_seconds())
		started_at = world.time
		return FALSE
	return heatmap.sample(now_seconds(), rows, TRUE, heatmap.epoch)

// No client's eye or body may be close enough to see the spawn happen.
/proc/ecology_visible_to_players(turf/T, margin = ECOLOGY_VIEW_MARGIN)
	for (var/client/C in clients)
		var/turf/eye = get_turf(C.eye)
		var/turf/body = get_turf(C.mob)
		if (eye && eye.z == T.z && get_dist(eye, T) <= margin)
			return TRUE
		if (body && body.z == T.z && get_dist(body, T) <= margin)
			return TRUE
	return FALSE

// Natural ground class of a turf, or 0. Farmland, caves, deep water, ice,
// salt water and off-world regolith are never wildlife ground.
/proc/ecology_ground(turf/T)
	if (!T || T.density)
		return 0
	if (istype(T, /turf/floor/winter))
		return ECO_SNOW
	if (istype(T, /turf/floor/grass))
		return ECO_GRASS
	if (istype(T, /turf/floor/dirt))
		if (istype(T, /turf/floor/dirt/ploughed) || istype(T, /turf/floor/dirt/underground) || istype(T, /turf/floor/dirt/flooded) || istype(T, /turf/floor/dirt/dust/regolith) || istype(T, /turf/floor/dirt/dry_lava))
			return 0
		if (istype(T, /turf/floor/dirt/winter))
			return ECO_SNOW
		return ECO_DIRT
	if (istype(T, /turf/floor/beach/sand))
		if (istype(T, /turf/floor/beach/sand/desert))
			return ECO_SAND
		return ECO_BEACH
	if (istype(T, /turf/floor/beach/water))
		if (istype(T, /turf/floor/beach/water/deep) || istype(T, /turf/floor/beach/water/ice) || istype(T, /turf/floor/beach/water/shallowsaltwater) || istype(T, /turf/floor/beach/water/coastwater) || istype(T, /turf/floor/beach/water/flooded))
			return 0
		return ECO_WATER
	return 0

// Climate of an open outdoor area with air and gravity, or null.
/proc/ecology_outdoor_climate(turf/T)
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE || A.is_void_area || A.no_air || !A.has_gravity)
		return null
	return A.climate

/proc/ecology_habitat_error(turf/T, list/biomes, grounds = ECO_GRASS | ECO_DIRT)
	if (!T || !(ecology_ground(T) & grounds))
		return "ground"
	var/climate = ecology_outdoor_climate(T)
	if (!climate || !(climate in biomes))
		return "habitat"
	if (locate(/obj/roof) in T)
		return "roofed"
	if (T.contents.len > 32)
		return "occupied"
	for (var/atom/movable/AM in T)
		if (AM.density || istype(AM, /mob/living) || istype(AM, /obj/structure) || istype(AM, /obj/covers))
			return "occupied"
	return null

// Samples a few turfs in every 8x8 cell of every level. Areas rarely change,
// so the index is rebuilt only every half hour; each spawn still checks the
// actual turf. Bounded: (maxx/8)*(maxy/8)*maxz*6 samples, yielding as it goes.
/datum/ecology_spawner/proc/build_index()
	habitat_cells = list()
	habitat_hits = list()
	var/cells_x = round((world.maxx - 1) / ECOLOGY_CELL_SIZE) + 1
	var/cells_y = round((world.maxy - 1) / ECOLOGY_CELL_SIZE) + 1
	for (var/z = 1, z <= world.maxz, z++)
		if (z == practice_room_z)
			continue
		for (var/cx = 1, cx <= cells_x, cx++)
			for (var/cy = 1, cy <= cells_y, cy++)
				var/list/keys_here = list()
				for (var/i = 1, i <= ECOLOGY_INDEX_SAMPLES, i++)
					var/x = min(world.maxx, (cx - 1) * ECOLOGY_CELL_SIZE + rand(1, ECOLOGY_CELL_SIZE))
					var/y = min(world.maxy, (cy - 1) * ECOLOGY_CELL_SIZE + rand(1, ECOLOGY_CELL_SIZE))
					var/turf/T = locate(x, y, z)
					var/ground = ecology_ground(T)
					if (!ground)
						continue
					var/climate = ecology_outdoor_climate(T)
					if (!climate)
						continue
					var/key = "[climate]|[ground]"
					habitat_hits[key] = (habitat_hits[key] || 0) + 1
					keys_here[key] = TRUE
				for (var/key in keys_here)
					if (!habitat_cells[key])
						habitat_cells[key] = list()
					var/list/cells = habitat_cells[key]
					cells += list(list(z, cx, cy))
			CHECK_TICK
	indexed_at = world.time
	size_targets()

/datum/ecology_spawner/proc/size_targets()
	var/cap = map ? map.ecology_wildlife_cap : 700
	var/scale_density = map ? map.ecology_density_scale : 2
	var/tile_per_hit = (ECOLOGY_CELL_SIZE * ECOLOGY_CELL_SIZE) / ECOLOGY_INDEX_SAMPLES
	var/total = 0
	for (var/datum/ecology_species/S in species)
		S.habitat_keys = list()
		S.habitat_tiles = 0
		for (var/key in habitat_hits)
			var/list/parts = splittext(key, "|")
			if ((parts[1] in S.biomes) && (text2num(parts[2]) & S.grounds))
				S.habitat_keys += key
				S.habitat_tiles += habitat_hits[key] * tile_per_hit
		if (S.density <= 0)
			continue // a fixed target (tests, admin edits) stays as given
		if (S.habitat_tiles < ECOLOGY_MIN_HABITAT)
			S.target = 0
		else
			S.target = clamp(round(S.habitat_tiles * S.density * scale_density / 1000, 1), 1, S.max_target)
		total += S.target
	if (cap > 0 && total > cap)
		var/scale = cap / total
		total = 0
		for (var/datum/ecology_species/S in species)
			if (S.density > 0 && S.target > 0)
				S.target = max(1, round(S.target * scale, 1))
				total += S.target
	total_target = total

// Living wild animals per species, one pass over the living mobs.
/datum/ecology_spawner/proc/census()
	var/list/counts = list()
	for (var/datum/ecology_species/S in species)
		counts[S] = 0
	for (var/mob/living/simple_animal/A in living_mob_list)
		if (!ecology_wild_animal(A))
			continue
		var/datum/ecology_species/S = species_for_type(A.type)
		if (S && (S in counts))
			counts[S] += 1
	last_census = counts
	return counts

/datum/ecology_spawner/proc/random_habitat_turf(datum/ecology_species/S)
	if (habitat_cells && S.habitat_keys.len)
		var/key = pick(S.habitat_keys)
		var/list/cells = habitat_cells[key]
		if (cells && cells.len)
			var/list/cell = pick(cells)
			var/x = min(world.maxx, (cell[2] - 1) * ECOLOGY_CELL_SIZE + rand(1, ECOLOGY_CELL_SIZE))
			var/y = min(world.maxy, (cell[3] - 1) * ECOLOGY_CELL_SIZE + rand(1, ECOLOGY_CELL_SIZE))
			return locate(x, y, cell[1])
	return locate(rand(1, world.maxx), rand(1, world.maxy), rand(1, world.maxz))

// Returns the turf used, or null. Picks random habitat candidates; never scans the world.
/datum/ecology_spawner/proc/find_site(datum/ecology_species/S)
	var/now = now_seconds()
	for (var/i = 1, i <= ECOLOGY_ATTEMPTS, i++)
		var/turf/T = random_habitat_turf(S)
		if (ecology_habitat_error(T, S.biomes, S.grounds))
			continue
		var/pressure = heatmap.pressure(now, ecology_cell_row(T), heatmap.epoch)
		// Unknown coverage (null) never counts as quiet.
		if (isnull(pressure) || pressure > ECOLOGY_QUIET_PRESSURE)
			continue
		if (ecology_visible_to_players(T))
			continue
		return T
	return null

// Places up to count animals of S around site, alternating sexes. Returns how many.
/datum/ecology_spawner/proc/spawn_herd(datum/ecology_species/S, turf/site, count)
	var/placed = 0
	var/offset = rand(0, S.spawn_types.len - 1)
	var/list/used = list()
	for (var/i = 1, i <= count, i++)
		var/turf/T = site
		if (i > 1)
			T = null
			for (var/try_n = 1, try_n <= 8, try_n++)
				var/turf/C = locate(site.x + rand(-ECOLOGY_HERD_RANGE, ECOLOGY_HERD_RANGE), site.y + rand(-ECOLOGY_HERD_RANGE, ECOLOGY_HERD_RANGE), site.z)
				if (C && !(C in used) && !ecology_habitat_error(C, S.biomes, S.grounds))
					T = C
					break
		if (!T)
			continue
		used += T
		var/path = S.spawn_types[((i + offset - 1) % S.spawn_types.len) + 1]
		new path(T)
		placed++
	return placed

/datum/ecology_spawner/proc/cycle()
	if (!enabled || !heatmap)
		return 0
	var/generation = loop_generation
	if (persistence_active_operation || persistence_save_in_progress)
		last_report = "paused for a world save"
		return 0
	sample_activity()
	if (world.time - started_at < ECOLOGY_WARMUP)
		last_report = "warming up activity history"
		return 0
	if (indexed_at < 0 || world.time - indexed_at > ECOLOGY_INDEX_REFRESH)
		build_index()
		// The build yields; an admin may have stopped or restarted us meanwhile.
		if (!enabled || !heatmap || generation != loop_generation)
			return 0
	var/list/counts = census()
	var/spawned = 0
	var/budget = ECOLOGY_SPAWN_BUDGET
	var/list/notes = list()
	var/list/order = shuffle(species.Copy())
	// Round-robin so one big deficit cannot take the whole budget.
	var/list/no_site = list()
	for (var/pass = 1, pass <= 3 && budget > 0, pass++)
		for (var/datum/ecology_species/S in order)
			if (budget <= 0)
				break
			if (S in no_site)
				continue
			var/deficit = S.target - counts[S]
			if (deficit <= 0)
				continue
			var/turf/T = find_site(S)
			if (!T)
				no_site += S
				continue
			var/herd = min(deficit, budget, rand(S.herd_min, S.herd_max))
			var/placed = spawn_herd(S, T, herd)
			counts[S] += placed
			spawned += placed
			budget -= placed
	var/total = 0
	for (var/datum/ecology_species/S in species)
		total += counts[S]
		if (S.target > 0 || counts[S] > 0)
			notes += "[S.name] [counts[S]]/[S.target][(S in no_site) ? " (no quiet habitat found)" : ""]"
	spawned_total += spawned
	last_report = "[total]/[total_target] wild animals, +[spawned] this cycle: [jointext(notes, ", ")]"
	return spawned

// Far from every player, wild animals live at a slower pace: the mob process
// runs their Life() once every ECOLOGY_REST_EVERY seconds instead of every
// second. Nobody can see them, so a larger population costs much less.
// Animals near a player, held, ridden, led, fighting or player-controlled, and
// human NPCs (raiders, zombies, soldiers) always run every second.
#define ECOLOGY_AWAKE_RANGE 32
#define ECOLOGY_REST_EVERY 4
var/global/list/ecology_observer_turfs = list()
var/global/ecology_rest_phase = 0
// TRUE while nobody is connected (no client, not even in the lobby) and no
// agent character plays: living animals hold still, do not get hungry and do
// not attack until someone joins, and saves have nothing moving to capture.
var/global/ecology_world_unwatched = FALSE

// Once per full pass over the living mobs (a fire can resume a snapshot).
/proc/ecology_advance_rest_phase()
	ecology_rest_phase = (ecology_rest_phase + 1) % ECOLOGY_REST_EVERY

/proc/ecology_refresh_observers()
	var/list/turfs = list()
	for (var/client/C in clients)
		var/turf/T = get_turf(C.mob)
		if (T)
			turfs |= T
		T = get_turf(C.eye)
		if (T)
			turfs |= T
	for (var/mob/M in agent_characters)
		var/turf/T = get_turf(M)
		if (T)
			turfs |= T
	ecology_observer_turfs = turfs
	ecology_world_unwatched = !length(clients) && !length(agent_characters)

// Val (2026-11-09): with no players connected, animals should not move,
// starve or attack. Their whole Life() waits, including NPC humans, so a
// raider cannot attack an empty settlement either. Dead animals keep running,
// so carcasses still rot away.
/proc/ecology_animal_frozen(mob/living/simple_animal/A)
	return ecology_world_unwatched && istype(A) && !A.client && A.stat != DEAD

/proc/ecology_animal_resting(mob/living/simple_animal/A)
	if (!istype(A) || A.client || A.stat == DEAD || istype(A, /mob/living/simple_animal/hostile/human))
		return FALSE
	if (A.pulledby || A.buckled || A.following_mob || A.rider || A.target_mob || A.targeting || A.stance == HOSTILE_STANCE_ATTACK)
		return FALSE
	var/turf/T = A.loc
	if (!isturf(T))
		return FALSE
	for (var/turf/O in ecology_observer_turfs)
		if (abs(O.z - T.z) <= 1 && max(abs(O.x - T.x), abs(O.y - T.y)) <= ECOLOGY_AWAKE_RANGE)
			return FALSE
	// Staggered by position so resting animals do not all wake together.
	return ((ecology_rest_phase + T.x + T.y) % ECOLOGY_REST_EVERY) != 0

#undef ECOLOGY_AWAKE_RANGE
#undef ECOLOGY_REST_EVERY

// Starts ecology spawning once a round is playing on a map that wants it,
// including after a world load. Called by the ticker process every 2 seconds;
// cheap when already running. An admin toggle-off holds it until restart.
/proc/ecology_autostart_check()
	if (ecology_admin_disabled || !map || !map.ecology_wildlife)
		return
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		return
	if (ecology_spawner && ecology_spawner.enabled)
		return
	if (!ecology_spawner)
		ecology_spawner = new
	ecology_spawner.start()
	log_game("Ecology spawning started on [map.title].")

/client/proc/toggle_ecology_spawning()
	set category = "Debug"
	set name = "Toggle Ecology Spawning"
	if (!check_rights(R_DEBUG))
		return
	if (!ecology_spawner)
		ecology_spawner = new
	if (ecology_spawner.enabled)
		ecology_spawner.stop()
		ecology_admin_disabled = TRUE
	else
		ecology_admin_disabled = FALSE
		ecology_spawner.start()
	var/state = ecology_spawner.enabled ? "enabled" : "disabled"
	to_chat(src, SPAN_NOTICE("Ecology spawning [state]. It needs five minutes of activity history before the first spawn."))
	message_admins("[key_name(src)] [state] ecology spawning.", key_name(src))
	log_admin("[key_name(src)] [state] ecology spawning.")

/client/proc/ecology_spawning_status()
	set category = "Debug"
	set name = "Ecology Spawning Status"
	if (!check_rights(R_DEBUG))
		return
	if (!ecology_spawner || !ecology_spawner.enabled)
		to_chat(src, SPAN_NOTICE("Ecology spawning is off."))
		return
	to_chat(src, SPAN_NOTICE("Ecology spawning is on. Spawned so far: [ecology_spawner.spawned_total]. Last cycle: [ecology_spawner.last_report]."))
	if (flora_regrowth && flora_regrowth.enabled)
		to_chat(src, SPAN_NOTICE("Flora regrowth: [flora_regrowth.last_report]."))

#undef ECOLOGY_CELL_SIZE
#undef ECOLOGY_CYCLE
#undef ECOLOGY_WARMUP
#undef ECOLOGY_QUIET_PRESSURE
#undef ECOLOGY_VIEW_MARGIN
#undef ECOLOGY_ATTEMPTS
#undef ECOLOGY_INDEX_SAMPLES
#undef ECOLOGY_INDEX_REFRESH
#undef ECOLOGY_SPAWN_BUDGET
#undef ECOLOGY_HERD_RANGE
#undef ECOLOGY_MIN_HABITAT
