// ============================================================
// Research Tree - node datum + global registry
// ------------------------------------------------------------
// A node is one "invention" in the tree. Nodes are faction-agnostic
// (shared definitions); per-faction progress lives on the map
// metadata (see research_faction.dm).
//
// Phase 0 ships a tiny stub tree so benches have something real to
// research. Phase 2 replaces build_research_tree() with the ~60-120
// nodes clustered from the crafting catalogue.
// ============================================================

// id => /datum/research_node
var/global/list/research_nodes = list()

// result-path string (recipe field i[3]) => required node id.
// Populated in build_research_tree(). A recipe present here is gated on
// its node being DONE for the faction instead of the legacy research
// thresholds; recipes NOT present here keep using thresholds unchanged.
var/global/list/recipe_node_requirements = list()

/proc/get_recipe_node_req(result_path_string)
	return recipe_node_requirements[result_path_string]

// Reverse index: node id => list of unique recipe display names it unlocks.
// Built lazily (not at boot) and cached, since craftlist_lists is only
// populated partway through world/New() -- by the time any player actually
// opens a bench UI, boot has long finished, so there's no ordering hazard.
// "global" is representative enough for a UI hint list even though a few
// faction-specific catalogues rename or add entries.
var/global/list/recipe_names_by_node = null

/proc/get_node_recipe_names(node_id)
	if (!recipe_names_by_node)
		recipe_names_by_node = list()
		for (var/list/i in craftlist_lists["global"])
			if (!istype(i) || i.len < 3)
				continue
			var/node_req = get_recipe_node_req(i[3])
			if (!node_req)
				continue
			var/list/names = recipe_names_by_node[node_req]
			if (!names)
				names = list()
				recipe_names_by_node[node_req] = names
			if (!(i[2] in names))
				names += i[2]
	var/list/result = recipe_names_by_node[node_id]
	return result ? result : list()

// Reverse index: node id => list of result TYPE PATHS it unlocks. Used to decide
// whether a fed item is a valid "sample" for the node being researched (studying
// an existing example of what the tech produces -- reverse-engineering). Built
// straight from recipe_node_requirements (result path => node), text2path'd once
// and cached.
var/global/list/recipe_paths_by_node = null

/proc/get_node_recipe_paths(node_id)
	if (!recipe_paths_by_node)
		recipe_paths_by_node = list()
		for (var/path_string in recipe_node_requirements)
			var/nid = recipe_node_requirements[path_string]
			var/ptype = text2path(path_string)
			if (!ptype)
				continue
			var/list/paths = recipe_paths_by_node[nid]
			if (!paths)
				paths = list()
				recipe_paths_by_node[nid] = paths
			paths += ptype
	var/list/result = recipe_paths_by_node[node_id]
	return result ? result : list()

// Grid column layout for the tree UI: one BLOCK of columns per era, in era
// order, with each era-changing capstone (PROTOTYPE mode) given its own
// single dedicated column sitting between the block it graduates FROM and
// the block it starts. So: [era0 nodes...][capstone->era1][era1 nodes...]
// [capstone->era2][era2 nodes...] and so on. Within an era's own block, a
// node normally sits at the block's first column, UNLESS it depends on
// ANOTHER regular (non-capstone) node of the SAME era -- e.g. Rifling (era4)
// depends on Steelmaking (era4) -- in which case it shifts one column further
// into the block per level of that same-era chain ("plus extras if
// dependent"). Prereqs from earlier eras (or the block's own capstone, which
// always sits immediately before it) never need to shift anything within the
// block: they're already satisfied by an earlier column purely from block
// ordering. Every capstone in the current tree has all of its own prereqs in
// strictly earlier eras, so it can always take a single column safely.
var/global/list/node_grid_col_cache = null

/proc/get_node_grid_col(node_id)
	if (!node_grid_col_cache)
		build_tree_grid_columns()
	var/col = node_grid_col_cache[node_id]
	return col ? col : 1

/proc/build_tree_grid_columns()
	node_grid_col_cache = list()
	// Each standalone tree (Main, Agriculture, ...) is laid out in its own grid
	// and so gets its own column numbering, reset to 1 per tree. Discover the
	// trees in registration order (Main first).
	var/list/trees = list()
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (!(N.tree in trees))
			trees += N.tree
	for (var/tree_name in trees)
		var/col_cursor = 1
		var/list/tree_node_ids = list()   // this tree's nodes, for the normalize pass
		for (var/era = 0, era <= 8, era++)
			// This tree's regular (non-capstone) nodes for this era.
			var/list/regular_ids = list()
			for (var/node_id in research_nodes)
				var/datum/research_node/N = research_nodes[node_id]
				if (N.tree == tree_name && N.era_tier == era && N.mode != RESEARCH_MODE_PROTOTYPE)
					regular_ids += node_id
			var/list/local_depth = list()
			var/block_width = 0
			for (var/node_id in regular_ids)
				block_width = max(block_width, get_local_era_depth(node_id, regular_ids, local_depth))
			for (var/node_id in regular_ids)
				node_grid_col_cache[node_id] = col_cursor + local_depth[node_id] - 1
				tree_node_ids += node_id
			col_cursor += max(block_width, 1)
			// The capstone that graduates era -> era+1 (if any) gets the next
			// column, immediately after this era's block.
			for (var/node_id in research_nodes)
				var/datum/research_node/N = research_nodes[node_id]
				if (N.tree == tree_name && N.mode == RESEARCH_MODE_PROTOTYPE && N.era_tier == era + 1)
					node_grid_col_cache[node_id] = col_cursor
					col_cursor++
					tree_node_ids += node_id
		// Normalize: a tree whose earliest node isn't era 0 (e.g. Agriculture
		// starts at era 2) would otherwise render with empty leading columns.
		// Shift the whole tree left so its leftmost node sits at column 1.
		if (tree_node_ids.len)
			var/min_col = 0
			for (var/node_id in tree_node_ids)
				if (!min_col || node_grid_col_cache[node_id] < min_col)
					min_col = node_grid_col_cache[node_id]
			if (min_col > 1)
				for (var/node_id in tree_node_ids)
					node_grid_col_cache[node_id] -= (min_col - 1)

// Depth within a single era's block: 1 for a node with no SAME-ERA regular
// prereq, otherwise 1 + the deepest such prereq's local depth. Prereqs
// outside regular_ids (earlier eras, or this era's own capstone) don't count
// -- they're already positioned before the block regardless.
/proc/get_local_era_depth(node_id, list/regular_ids, list/memo)
	if (memo[node_id])
		return memo[node_id]
	var/datum/research_node/N = get_research_node(node_id)
	var/depth = 1
	for (var/req in N.prereqs)
		if (req in regular_ids)
			depth = max(depth, get_local_era_depth(req, regular_ids, memo) + 1)
	memo[node_id] = depth
	return depth

/datum/research_node
	var/id = null                    // unique string key, e.g. "basic_tools"
	var/name = "research node"       // display name
	var/category = "General"         // grouping (mirrors crafting subtitles)
	var/desc = ""                    // flavour / what it unlocks
	var/list/prereqs = list()        // list of node ids that must be DONE first
	var/cost_ticks = 100             // analysis ticks needed to complete
	var/min_bench_tier = 0           // lowest bench tier that can research this
	// Era this node belongs to (ordinal_age). Nodes at era_tier <= the map's
	// current ordinal_age are BASELINE: auto-granted to every faction and to
	// factionless players (you never re-research past eras). Only frontier
	// nodes (era_tier > current era) actually need bench/book/prototype work.
	var/era_tier = 0
	var/mode = RESEARCH_MODE_ANALYSIS
	// Which standalone tree/tab this node lives in for the bench UI. "Main" is
	// the default; specialized trees (e.g. "Agriculture") render as their own
	// switchable tab. Columns are laid out independently per tree.
	var/tree = "Main"
	var/list/unlocks = list()        // recipe ids / feature flags (wired in Phase 1)
	// Alternate-completion payloads (used in later phases):
	var/prototype_type = null        // PROTOTYPE mode: item type to build & consume
	var/book_subject = null          // BOOK mode: matching research-book subject
	var/tmp/prototype_name_cache = null // lazily-resolved display name of prototype_type

/datum/research_node/New(_id, _name, _category, _cost_ticks = 100, _min_bench_tier = 0, _mode = RESEARCH_MODE_ANALYSIS, list/_prereqs = null, _era_tier = 0, _prototype_type = null, _tree = "Main")
	..()
	id = _id
	name = _name
	category = _category
	cost_ticks = _cost_ticks
	min_bench_tier = _min_bench_tier
	mode = _mode
	era_tier = _era_tier
	prototype_type = _prototype_type
	tree = _tree
	if (_prereqs)
		prereqs = _prereqs

// Human-readable name of the item this PROTOTYPE node needs, so the UI can tell
// the researcher what to build instead of leaving them guessing. Resolved once
// by briefly instantiating the type in nullspace, then cached (only the handful
// of prototype nodes ever hit this, once each).
/datum/research_node/proc/prototype_display_name()
	if (!prototype_type)
		return null
	if (isnull(prototype_name_cache))
		var/atom/A = new prototype_type()
		prototype_name_cache = A ? "[A.name]" : "[prototype_type]"
		if (A)
			qdel(A)
	return prototype_name_cache

// Registers a node, warning on duplicate ids so tree authoring mistakes surface.
/proc/register_research_node(datum/research_node/N)
	if (!istype(N) || !N.id)
		return
	if (research_nodes[N.id])
		log_debug("research_tree: duplicate node id '[N.id]' ignored")
		return
	research_nodes[N.id] = N

/proc/get_research_node(node_id)
	return research_nodes[node_id]

// Called once at world setup. Phase 0 = stub content only.
/proc/build_research_tree()
	research_nodes = list()

	// Args: id, name, category(layer), cost_ticks, min_bench_tier, mode, prereqs, era_tier
	// Three intersecting layers (Industrial/Military/Health) plus the Tailoring
	// and Agriculture specialist trees, laddered across the 9 eras. Capstones
	// (PROTOTYPE mode) advance the age. Cross-branch prereqs make it a tree.
	// Rebalanced 2026-07: recipe unlocks re-clustered from the actual crafting
	// catalogue so every node earns its place (see recipe_node_requirements).
	// --- Industrial: Toolmaking ---
	register_research_node(new /datum/research_node("basic_tools", "Basic Toolmaking", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("iron_tools", "Iron Tools", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("basic_tools"), 2))
	register_research_node(new /datum/research_node("machined_tools", "Machined Tools", "Industrial", 200, 3, RESEARCH_MODE_ANALYSIS, list("iron_tools","steelmaking"), 4))
	register_research_node(new /datum/research_node("power_tools", "Power Tools", "Industrial", 270, 5, RESEARCH_MODE_ANALYSIS, list("machined_tools","electricity"), 6))
	// --- Industrial: Metallurgy ---
	// Prototype: a cast axehead mold (gated on stone_arms, era-0 baseline --
	// always available, so it can never be circular with bronze_working itself).
	register_research_node(new /datum/research_node("bronze_working", "Bronze Working", "Industrial", 142, 0, RESEARCH_MODE_PROTOTYPE, null, 1, /obj/item/weapon/clay/mold/axehead))
	// Prototype: a bronze ingot mold (gated on bronze_working, its own direct prereq).
	register_research_node(new /datum/research_node("iron_smithing", "Iron Smithing", "Industrial", 195, 1, RESEARCH_MODE_PROTOTYPE, list("bronze_working"), 2, /obj/item/weapon/clay/mold))
	register_research_node(new /datum/research_node("steelmaking", "Steelmaking", "Industrial", 200, 3, RESEARCH_MODE_ANALYSIS, list("iron_smithing"), 4))
	register_research_node(new /datum/research_node("alloys", "Alloys", "Industrial", 270, 5, RESEARCH_MODE_ANALYSIS, list("steelmaking"), 6))
	// --- Industrial: Construction (one node per building era) ---
	register_research_node(new /datum/research_node("primitive_construction", "Primitive Construction", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("stone_masonry", "Stone Masonry", "Industrial", 95, 0, RESEARCH_MODE_ANALYSIS, list("primitive_construction"), 1))
	register_research_node(new /datum/research_node("brickmaking", "Brickmaking", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("stone_masonry"), 2))
	register_research_node(new /datum/research_node("imperial_architecture", "Imperial Architecture", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, list("brickmaking"), 3))
	register_research_node(new /datum/research_node("reinforced_concrete", "Reinforced Concrete", "Industrial", 200, 3, RESEARCH_MODE_ANALYSIS, list("imperial_architecture","steelmaking"), 4))
	register_research_node(new /datum/research_node("modern_construction", "Modern Construction", "Industrial", 270, 5, RESEARCH_MODE_ANALYSIS, list("reinforced_concrete"), 6))
	// --- Industrial: Culture & Faith ---
	register_research_node(new /datum/research_node("ritual_worship", "Ritual & Worship", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	// Era 0: faction banners and the flag maker must be craftable the day a
	// faction is founded (they were ungated before the rebalance).
	register_research_node(new /datum/research_node("regalia", "Regalia & Heraldry", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, list("weaving"), 0))
	register_research_node(new /datum/research_node("monuments", "Monuments & Statuary", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("stone_masonry","ritual_worship"), 2))
	register_research_node(new /datum/research_node("fine_arts", "Fine Arts & Leisure", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, list("monuments"), 3))
	// --- Industrial: Production & Trade ---
	register_research_node(new /datum/research_node("pottery_storage", "Pottery & Cookware", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("cooperage", "Cooperage & Containers", "Industrial", 95, 0, RESEARCH_MODE_ANALYSIS, list("basic_tools"), 1))
	register_research_node(new /datum/research_node("resource_processing", "Resource Processing", "Industrial", 95, 0, RESEARCH_MODE_ANALYSIS, list("basic_tools"), 1))
	register_research_node(new /datum/research_node("early_economy", "Trade & Coinage", "Industrial", 95, 0, RESEARCH_MODE_ANALYSIS, null, 1))
	register_research_node(new /datum/research_node("workshops", "Workshops", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("pottery_storage"), 2))
	register_research_node(new /datum/research_node("glassworking", "Glassworking", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("pottery_storage"), 2))
	register_research_node(new /datum/research_node("papermaking", "Papermaking", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, null, 2))
	register_research_node(new /datum/research_node("printing_currency", "Printing Press", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, list("papermaking"), 3))
	register_research_node(new /datum/research_node("optics_instruments", "Optics & Instruments", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, list("glassworking"), 3))
	register_research_node(new /datum/research_node("factories", "Factories", "Industrial", 200, 3, RESEARCH_MODE_ANALYSIS, list("printing_currency","steam_power"), 4))
	register_research_node(new /datum/research_node("assembly_line", "Assembly Line", "Industrial", 235, 4, RESEARCH_MODE_ANALYSIS, list("factories"), 5))
	register_research_node(new /datum/research_node("automation", "Automation", "Industrial", 305, 6, RESEARCH_MODE_ANALYSIS, list("assembly_line","electricity"), 7))
	// Prototype: an early electronic device (gated on assembly_line, era5, well
	// before this node's era8 -- assembly_line is baseline-granted by then).
	register_research_node(new /datum/research_node("digital_computing", "Digital Computing", "Industrial", 510, 7, RESEARCH_MODE_PROTOTYPE, list("automation","electricity"), 8, /obj/item/camera/coldwar))
	// --- Industrial: Textiles gateway (the clothing lines live in the
	// standalone Tailoring tree, registered at the bottom of this proc) ---
	register_research_node(new /datum/research_node("weaving", "Weaving", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	// --- Industrial: Furniture ---
	register_research_node(new /datum/research_node("basic_furniture", "Basic Furniture", "Industrial", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("fine_furniture", "Fine Furniture", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("basic_furniture"), 2))
	register_research_node(new /datum/research_node("manufactured_furniture", "Manufactured Furniture", "Industrial", 200, 3, RESEARCH_MODE_ANALYSIS, list("fine_furniture"), 4))
	// --- Industrial: Power ---
	// Era 3: its unlocks (large/powered saw mills) carried ~era-4 legacy
	// thresholds, so era 2 would have leaked them via the baseline grant.
	register_research_node(new /datum/research_node("watermills", "Watermills", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, null, 3))
	// Prototype: a machined component (gated on basic_tools, era0 baseline --
	// placeholder until a dedicated "engine prototype" item exists).
	register_research_node(new /datum/research_node("steam_power", "Steam Power", "Industrial", 300, 3, RESEARCH_MODE_PROTOTYPE, list("watermills"), 4, /obj/item/weapon/material/handle))
	// Prototype: a spool of cable (gated on paved_infrastructure, era3, well
	// before this node's era5).
	register_research_node(new /datum/research_node("hydraulic_fracturing", "Hydraulic Fracturing", "Industrial", 400, 7, RESEARCH_MODE_ANALYSIS, list("electricity", "modern_construction"), 8))
	register_research_node(new /datum/research_node("electricity", "Electricity", "Industrial", 352, 4, RESEARCH_MODE_PROTOTYPE, list("steam_power"), 5, /obj/item/stack/cable_coil))
	register_research_node(new /datum/research_node("combustion", "Combustion Engine", "Industrial", 235, 4, RESEARCH_MODE_ANALYSIS, list("steam_power","steelmaking"), 5))
	// Prototype: a geiger counter (gated on factories, era4, well before this
	// node's era7).
	register_research_node(new /datum/research_node("nuclear_power", "Nuclear Power", "Industrial", 458, 6, RESEARCH_MODE_PROTOTYPE, list("combustion"), 7, /obj/item/weapon/geiger_counter))
	// --- Industrial: Vehicles ---
	register_research_node(new /datum/research_node("carts", "Carts", "Industrial", 95, 0, RESEARCH_MODE_ANALYSIS, null, 1))
	register_research_node(new /datum/research_node("wagons_ships", "Wagons & Ships", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, list("carts"), 3))
	register_research_node(new /datum/research_node("rail_steam", "Rail & Steam", "Industrial", 200, 3, RESEARCH_MODE_ANALYSIS, list("wagons_ships","steam_power"), 4))
	register_research_node(new /datum/research_node("automobiles", "Automobiles", "Industrial", 235, 4, RESEARCH_MODE_ANALYSIS, list("rail_steam","combustion"), 5))
	register_research_node(new /datum/research_node("aviation_rocketry", "Aviation & Rocketry", "Industrial", 305, 6, RESEARCH_MODE_ANALYSIS, list("automobiles","combustion","alloys"), 7))
	// --- Industrial: Infrastructure ---
	register_research_node(new /datum/research_node("paved_infrastructure", "Paved Infrastructure", "Industrial", 165, 2, RESEARCH_MODE_ANALYSIS, list("stone_masonry"), 3))
	register_research_node(new /datum/research_node("utilities", "Utilities", "Industrial", 235, 4, RESEARCH_MODE_ANALYSIS, list("paved_infrastructure","electricity"), 5))
	// --- Industrial: Agriculture ---
	// Basic Agriculture is the Bronze Age gateway for farming: it unlocks the
	// basic farming tools AND opens the specialized Agriculture tree below.
	register_research_node(new /datum/research_node("basic_agriculture", "Basic Agriculture", "Industrial", 95, 0, RESEARCH_MODE_ANALYSIS, null, 1))
	// The specialized Agriculture nodes live in their OWN standalone tree/tab
	// ("Agriculture"), reachable once Basic Agriculture (in the Main tree) is done.
	// Irrigation gates the "dig an irrigation channel" shovel action -- see
	// /obj/item/weapon/material/shovel/attack_self() in code/modules/1713/tools.dm.
	register_research_node(new /datum/research_node("irrigation", "Irrigation", "Agriculture", 165, 1, RESEARCH_MODE_ANALYSIS, list("basic_agriculture"), 2, null, "Agriculture"))
	register_research_node(new /datum/research_node("advanced_agriculture", "Advanced Agriculture", "Agriculture", 235, 3, RESEARCH_MODE_ANALYSIS, list("irrigation"), 4, null, "Agriculture"))
	// --- Military: Melee ---
	register_research_node(new /datum/research_node("stone_arms", "Stone Arms", "Military", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("bronze_weapons", "Bronze Arms & Armor", "Military", 95, 0, RESEARCH_MODE_ANALYSIS, list("stone_arms"), 1))
	register_research_node(new /datum/research_node("steel_blades", "Steel Blades", "Military", 130, 1, RESEARCH_MODE_ANALYSIS, list("bronze_weapons","iron_smithing"), 2))
	// --- Military: Archery ---
	register_research_node(new /datum/research_node("archery", "Archery", "Military", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("crossbows", "Crossbows", "Military", 130, 1, RESEARCH_MODE_ANALYSIS, list("archery"), 2))
	// --- Military: Order & Defense ---
	// Law & Order era 1: organized justice (jails, cuffs, batons). The truly
	// primitive pieces (noose, rope cuffs) live in stone_arms era0 instead.
	register_research_node(new /datum/research_node("law_order", "Law & Order", "Military", 95, 0, RESEARCH_MODE_ANALYSIS, null, 1))
	// Field Defenses era 0: wood palisades/barricades were free at a stone-age
	// start before the rebalance and must stay so; sandbags and dressed-stone
	// walls moved up to trench_warfare/fortifications respectively.
	register_research_node(new /datum/research_node("field_defenses", "Field Defenses", "Military", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	// Fortifications moved to the Main tree's Military layer in the rebalance:
	// crenelated walls, castle gates and barbwire are siegecraft, not tailoring.
	register_research_node(new /datum/research_node("fortifications", "Fortifications", "Military", 165, 2, RESEARCH_MODE_ANALYSIS, list("field_defenses","stone_masonry"), 3))
	// --- Military: Firearms ---
	// Prototype: a pouch of black powder (gated on iron_smithing, its own
	// direct prereq).
	register_research_node(new /datum/research_node("gunpowder", "Gunpowder", "Military", 248, 2, RESEARCH_MODE_PROTOTYPE, list("iron_smithing"), 3, /obj/item/weapon/reagent_containers/food/drinks/gunpowder))
	// Gunsmithing: the craft of building and maintaining firearms. Also gates the
	// "dig a trench" shovel action -- see /turf/floor/dirt/attackby() and
	// /turf/floor/beach/sand/attackby() in code/modules/1713/trench.dm.
	register_research_node(new /datum/research_node("gunsmithing", "Gunsmithing", "Military", 200, 2, RESEARCH_MODE_ANALYSIS, list("gunpowder"), 3))
	register_research_node(new /datum/research_node("rifling", "Rifling", "Military", 200, 3, RESEARCH_MODE_ANALYSIS, list("gunpowder","steelmaking"), 4))
	// The three nodes below also gate the gunsmithing bench's part catalogue
	// (see gunsmith.dm): cartridge_ammo opens the bench's basic receivers,
	// selfloading_firearms the self-loading ones, automatic_weapons full-auto.
	register_research_node(new /datum/research_node("cartridge_ammo", "Cartridge Firearms", "Military", 235, 4, RESEARCH_MODE_ANALYSIS, list("rifling"), 5))
	register_research_node(new /datum/research_node("selfloading_firearms", "Self-Loading Firearms", "Military", 270, 5, RESEARCH_MODE_ANALYSIS, list("cartridge_ammo"), 6))
	register_research_node(new /datum/research_node("automatic_weapons", "Automatic Weapons", "Military", 305, 6, RESEARCH_MODE_ANALYSIS, list("selfloading_firearms"), 7))
	// --- Military: Artillery ---
	register_research_node(new /datum/research_node("siege_engines", "Siege Engines", "Military", 130, 1, RESEARCH_MODE_ANALYSIS, null, 2))
	register_research_node(new /datum/research_node("cannon", "Cannon", "Military", 165, 2, RESEARCH_MODE_ANALYSIS, list("siege_engines","imperial_architecture"), 3))
	register_research_node(new /datum/research_node("field_artillery", "Field Artillery", "Military", 200, 3, RESEARCH_MODE_ANALYSIS, list("cannon","steelmaking"), 4))
	// Prototype: a tank shell casing (gated on field_artillery, its own direct prereq).
	register_research_node(new /datum/research_node("mechanized_war", "Mechanized Warfare", "Military", 405, 5, RESEARCH_MODE_PROTOTYPE, list("field_artillery","combustion","steelmaking"), 6, /obj/item/stack/ammopart/casing/tank))
	register_research_node(new /datum/research_node("missiles", "Missiles", "Military", 305, 6, RESEARCH_MODE_ANALYSIS, list("mechanized_war","aviation_rocketry"), 7))
	// --- Military: Armor gateway (advanced armour lives in the Tailoring tree) ---
	register_research_node(new /datum/research_node("padded_armor", "Primitive Armor", "Military", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	// --- Health: Medicine ---
	register_research_node(new /datum/research_node("herbalism", "Herbalism", "Health", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))
	register_research_node(new /datum/research_node("apothecary", "Apothecary", "Health", 130, 1, RESEARCH_MODE_ANALYSIS, list("herbalism"), 2))
	register_research_node(new /datum/research_node("pharmacology", "Pharmacology", "Health", 235, 4, RESEARCH_MODE_ANALYSIS, list("apothecary","printing_currency"), 5))
	register_research_node(new /datum/research_node("modern_medicine", "Modern Medicine", "Health", 305, 6, RESEARCH_MODE_ANALYSIS, list("pharmacology"), 7))
	// --- Health: Surgery ---
	register_research_node(new /datum/research_node("field_surgery", "Field Surgery", "Health", 95, 0, RESEARCH_MODE_ANALYSIS, list("bronze_working"), 1))
	register_research_node(new /datum/research_node("surgical_theory", "Surgical Theory", "Health", 165, 2, RESEARCH_MODE_ANALYSIS, list("field_surgery","printing_currency"), 3))
	register_research_node(new /datum/research_node("anesthetic_surgery", "Anesthetic Surgery", "Health", 235, 4, RESEARCH_MODE_ANALYSIS, list("surgical_theory"), 5))
	// --- Health: Sanitation ---
	register_research_node(new /datum/research_node("hygiene", "Hygiene", "Health", 95, 0, RESEARCH_MODE_ANALYSIS, null, 1))
	register_research_node(new /datum/research_node("sanitation", "Sanitation", "Health", 165, 2, RESEARCH_MODE_ANALYSIS, list("hygiene"), 3))
	register_research_node(new /datum/research_node("germ_theory", "Germ Theory", "Health", 235, 4, RESEARCH_MODE_ANALYSIS, list("sanitation"), 5))
	register_research_node(new /datum/research_node("public_health", "Public Health", "Health", 305, 6, RESEARCH_MODE_ANALYSIS, list("germ_theory"), 7))
	// --- Tailoring tree: Textiles (clothing by era, reachable via Weaving) ---
	register_research_node(new /datum/research_node("classical_dress", "Classical Dress", "Textiles", 95, 0, RESEARCH_MODE_ANALYSIS, list("weaving"), 1, null, "Tailoring"))
	register_research_node(new /datum/research_node("furriery", "Furriery", "Textiles", 95, 0, RESEARCH_MODE_ANALYSIS, list("weaving"), 1, null, "Tailoring"))
	register_research_node(new /datum/research_node("tailoring", "Tailoring", "Textiles", 130, 1, RESEARCH_MODE_ANALYSIS, list("classical_dress"), 2, null, "Tailoring"))
	register_research_node(new /datum/research_node("fine_garments", "Fine Garments", "Textiles", 165, 2, RESEARCH_MODE_ANALYSIS, list("tailoring"), 3, null, "Tailoring"))
	register_research_node(new /datum/research_node("haberdashery", "Haberdashery", "Textiles", 165, 2, RESEARCH_MODE_ANALYSIS, list("tailoring"), 3, null, "Tailoring"))
	register_research_node(new /datum/research_node("textile_mills", "Textile Mills", "Textiles", 200, 3, RESEARCH_MODE_ANALYSIS, list("fine_garments","steam_power"), 4, null, "Tailoring"))
	register_research_node(new /datum/research_node("ready_made", "Ready-Made Clothing", "Textiles", 235, 4, RESEARCH_MODE_ANALYSIS, list("textile_mills"), 5, null, "Tailoring"))
	register_research_node(new /datum/research_node("synthetics", "Synthetic Fabrics", "Textiles", 305, 6, RESEARCH_MODE_ANALYSIS, list("ready_made"), 7, null, "Tailoring"))
	// --- Tailoring tree: Armour ---
	register_research_node(new /datum/research_node("mail_plate", "Mail & Plate", "Armour", 130, 1, RESEARCH_MODE_ANALYSIS, list("padded_armor"), 2, null, "Tailoring"))
	register_research_node(new /datum/research_node("trench_warfare", "Trench Warfare", "Armour", 235, 4, RESEARCH_MODE_ANALYSIS, list("mail_plate"), 5, null, "Tailoring"))
	register_research_node(new /datum/research_node("modern_armor", "Modern Armor", "Armour", 305, 6, RESEARCH_MODE_ANALYSIS, list("trench_warfare","alloys"), 7, null, "Tailoring"))

	// Era-changing capstones (the PROTOTYPE-mode nodes) advance the whole world's
	// era on completion (see complete_node), so they should be a serious
	// undertaking to reach by passive study -- their tick cost is 5x a normal
	// node's. Building the matching prototype item still completes them instantly.
	for (var/node_id in research_nodes)
		var/datum/research_node/PN = research_nodes[node_id]
		if (PN.mode == RESEARCH_MODE_PROTOTYPE)
			PN.cost_ticks *= 5

	// Phase 2: full catalogue mapping. Generated from config/crafting/
	// material_recipes_*.txt (1325 unique result paths across all 9 faction
	// files) via keyword+era classification, spot-checked and corrected for
	// misclassifications. Unmapped paths (not listed here) keep the legacy
	// threshold gate unchanged (see generate_recipes_civs in civ_recipes.dm).
	recipe_node_requirements = list(
		"/obj/structure/exercise" = "basic_tools",
		"/obj/structure/exercise/course" = "primitive_construction",
		"/obj/structure/exercise/modern" = "factories",
		"/obj/structure/exercise/modern/course" = "factories",
		// --- anesthetic_surgery (2) ---
		"/obj/item/clothing/mask/sterile" = "anesthetic_surgery",
		"/obj/item/clothing/suit/storage/jacket/surgeon" = "anesthetic_surgery",
		// --- apothecary (9) ---
		"/obj/item/stack/medical/advanced/bruise_pack" = "apothecary",
		"/obj/item/stack/medical/advanced/ointment" = "apothecary",
		"/obj/item/weapon/reagent_containers/dropper" = "apothecary",
		"/obj/item/weapon/reagent_containers/glass/beaker" = "apothecary",
		"/obj/item/weapon/reagent_containers/glass/beaker/large" = "apothecary",
		"/obj/item/weapon/reagent_containers/glass/beaker/vial" = "apothecary",
		"/obj/item/weapon/reagent_containers/glass/extraction_kit" = "apothecary",
		"/obj/item/weapon/reagent_containers/pill/cocaine" = "apothecary",
		"/obj/structure/lab_distillery" = "apothecary",
		"/obj/structure/reaction_bench" = "apothecary",
		"/obj/item/weapon/laboratory_burner" = "apothecary",
		// --- archery (7) ---
		"/obj/item/ammo_casing/arrow" = "archery",
		"/obj/item/ammo_casing/stone" = "archery",
		"/obj/item/weapon/gun/projectile/bow" = "archery",
		"/obj/item/weapon/gun/projectile/bow/shortbow" = "archery",
		"/obj/item/weapon/gun/projectile/bow/sling" = "archery",
		"/obj/item/weapon/gun/projectile/dartgun/blowgun" = "archery",
		"/obj/item/weapon/storage/backpack/quiver" = "archery",
		// --- assembly_line (18) ---
		"/obj/item/camera/coldwar" = "assembly_line",
		"/obj/item/conveyor_construct" = "assembly_line",
		"/obj/item/conveyor_switch_construct" = "assembly_line",
		"/obj/item/weapon/flame/lighter/random" = "assembly_line",
		"/obj/item/weapon/flame/lighter/zippo" = "assembly_line",
		"/obj/item/weapon/radio/walkietalkie" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom/fastfoodcup" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/plastic/cola" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/plastic/condiment" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/plastic/gallonjug" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/plastic/sodacan" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/plastic/tallcan" = "assembly_line",
		"/obj/item/weapon/reagent_containers/food/drinks/shaker" = "assembly_line",
		"/obj/item/weapon/storage/foodbox/chippack" = "assembly_line",
		"/obj/item/weapon/storage/ww2/slunch" = "assembly_line",
		"/obj/structure/TV/television" = "assembly_line",
		"/obj/structure/radio/receiver/loudspeaker" = "assembly_line",
		"/obj/structure/radio/transmitter_receiver" = "assembly_line",
		// --- automation (2) ---
		"/obj/item/camera" = "automation",
		"/obj/structure/vending/sales/vending" = "automation",
		// --- automobiles (13) ---
		"/obj/structure/car_workshop" = "automobiles",
		"/obj/item/vehicleparts/frame/bike" = "automobiles",
		"/obj/item/vehicleparts/frame/boat/rhib" = "automobiles",
		"/obj/structure/bed/chair/carseat/left" = "automobiles",
		"/obj/structure/bed/chair/carseat/right" = "automobiles",
		"/obj/structure/bed/chair/drivers" = "automobiles",
		"/obj/structure/bed/chair/drivers/car" = "automobiles",
		"/obj/structure/closet/crate/cart/steel" = "automobiles",
		"/obj/structure/shopping_cart" = "automobiles",
		"/obj/structure/vehicleparts/axis/car" = "automobiles",
		"/obj/structure/vehicleparts/axis/heavy" = "automobiles",
		"/obj/structure/vehicleparts/frame" = "automobiles",
		"/obj/structure/vehicleparts/frame/wood" = "automobiles",
		"/obj/structure/vehicleparts/movement" = "automobiles",
		// --- basic_agriculture (10) ---
		"/obj/item/stack/material/wool" = "basic_agriculture",
		"/obj/item/weapon/berriesgatherer" = "basic_agriculture",
		"/obj/item/weapon/leash" = "basic_agriculture",
		"/obj/item/weapon/material/pitchfork" = "basic_agriculture",
		"/obj/item/weapon/material/trowel" = "basic_agriculture",
		"/obj/item/weapon/plough" = "basic_agriculture",
		"/obj/item/weapon/plough/iron" = "basic_agriculture",
		"/obj/item/weapon/shears" = "basic_agriculture",
		"/obj/item/weapon/storage/produce_basket" = "basic_agriculture",
		"/obj/item/weapon/storage/seed_collector" = "basic_agriculture",
		// --- basic_furniture (17) ---
		"/obj/item/weapon/bedsheet" = "basic_furniture",
		"/obj/item/weapon/bedsheet/blue" = "basic_furniture",
		"/obj/item/weapon/bedsheet/brown" = "basic_furniture",
		"/obj/item/weapon/bedsheet/red" = "basic_furniture",
		"/obj/structure/bed/chair/comfy/brown" = "basic_furniture",
		"/obj/structure/bed/chair/wood" = "basic_furniture",
		"/obj/structure/bed/wood" = "basic_furniture",
		"/obj/structure/brazier" = "basic_furniture",
		"/obj/structure/brazier/obsidian" = "basic_furniture",
		"/obj/structure/brazier/sandstone" = "basic_furniture",
		"/obj/structure/brazier/stone" = "basic_furniture",
		"/obj/structure/closet/coffin" = "basic_furniture",
		"/obj/structure/closet/coffin/generic" = "basic_furniture",
		"/obj/structure/oven/fireplace" = "basic_furniture",
		"/obj/structure/table" = "basic_furniture",
		"/obj/structure/table/rack" = "basic_furniture",
		"/obj/structure/table/wood" = "basic_furniture",
		// --- basic_tools (20) ---
		"/obj/item/stack/material/rope" = "basic_tools",
		"/obj/item/weapon/book/research" = "basic_tools",
		"/obj/item/weapon/cane" = "basic_tools",
		"/obj/item/weapon/chisel" = "basic_tools",
		"/obj/item/weapon/chisel/metal" = "basic_tools",
		"/obj/item/weapon/clay/mold/shovel" = "basic_tools",
		"/obj/item/weapon/fishing" = "basic_tools",
		"/obj/item/weapon/fishing/net" = "basic_tools",
		"/obj/item/weapon/hammer" = "basic_tools",
		"/obj/item/weapon/material/handle" = "basic_tools",
		"/obj/item/weapon/material/hatchet/tribal" = "basic_tools",
		"/obj/item/weapon/material/hatchet/tribal/bone" = "basic_tools",
		"/obj/item/weapon/material/kitchen/rollingpin" = "basic_tools",
		"/obj/item/weapon/material/shovel/bone" = "basic_tools",
		"/obj/item/weapon/mop" = "basic_tools",
		"/obj/item/weapon/researchkit" = "basic_tools",
		"/obj/item/weapon/swatter" = "basic_tools",
		"/obj/item/weapon/swatter/modern" = "basic_tools",
		"/obj/item/weapon/wrench" = "basic_tools",
		"/obj/structure/fishing_cage" = "basic_tools",
		// --- brickmaking (10) ---
		"/obj/covers/stone_wall/brick" = "brickmaking",
		"/obj/covers/stone_wall/brick/archway" = "brickmaking",
		"/obj/covers/stonebrickfloor" = "brickmaking",
		"/obj/item/stack/material/stonebrick" = "brickmaking",
		"/obj/item/weapon/clay/advclaybricks" = "brickmaking",
		"/obj/item/weapon/clay/advclaybricks/cement" = "brickmaking",
		"/obj/item/weapon/clay/roofing/black" = "brickmaking",
		"/obj/item/weapon/clay/roofing/blue" = "brickmaking",
		"/obj/item/weapon/stucco/generic" = "brickmaking",
		"/obj/item/weapon/stucco/roman" = "brickmaking",
		// --- bronze_weapons (10) ---
		"/obj/item/ammo_casing/bolt" = "bronze_weapons",
		"/obj/item/clothing/accessory/armband/punk" = "bronze_weapons",
		"/obj/item/clothing/head/helmet/montefortino" = "bronze_weapons",
		"/obj/item/clothing/head/helmet/napoleonic/dragoon" = "bronze_weapons",
		"/obj/item/clothing/head/helmet/phrigian" = "bronze_weapons",
		"/obj/item/clothing/suit/armor/medieval/bronze_chestplate" = "bronze_weapons",
		"/obj/item/stack/ammopart/stoneball" = "bronze_weapons",
		"/obj/item/weapon/material/thrown/kunai_normal" = "bronze_weapons",
		"/obj/item/weapon/material/thrown/star" = "bronze_weapons",
		"/obj/item/weapon/melee/classic_baton/whip" = "bronze_weapons",
		// --- bronze_working (5) ---
		"/obj/item/weapon/clay/mold" = "bronze_working",
		"/obj/item/weapon/storage/ore_collector" = "bronze_working",
		"/obj/structure/furnace/kiln" = "bronze_working",
		"/obj/structure/furnace/kiln/sandstone" = "bronze_working",
		"/obj/structure/furnace/kiln/stone" = "bronze_working",
		// --- cannon (2) ---
		"/obj/item/cannon_ball" = "cannon",
		"/obj/structure/cannon" = "cannon",
		// --- cartridge_ammo (4) ---
		"/obj/item/ammo_magazine/emptybelt" = "cartridge_ammo",
		"/obj/item/ammo_magazine/emptymagazine" = "cartridge_ammo",
		"/obj/item/ammo_magazine/emptymagazine/rifle" = "cartridge_ammo",
		"/obj/item/stack/ammopart/casing/grenade" = "cartridge_ammo",
		// --- carts (5) ---
		"/obj/structure/closet/crate/cart/copper" = "carts",
		"/obj/structure/closet/crate/cart/stone" = "carts",
		"/obj/structure/closet/crate/cart/wooden" = "carts",
		"/obj/structure/vehicle/carriage" = "carts",
		"/obj/structure/vehicle/raft" = "carts",
		// --- classical_dress (37) ---
		"/obj/item/clothing/head/ainu_bandana" = "classical_dress",
		"/obj/item/clothing/head/egyptian_headdress_black" = "classical_dress",
		"/obj/item/clothing/head/egyptian_headdress_blue" = "classical_dress",
		"/obj/item/clothing/head/egyptian_headdress_red" = "classical_dress",
		"/obj/item/clothing/head/fiendish" = "classical_dress",
		"/obj/item/clothing/head/mayan_headdress" = "classical_dress",
		"/obj/item/clothing/head/nemes" = "classical_dress",
		"/obj/item/clothing/head/pakol" = "classical_dress",
		"/obj/item/clothing/head/pharoah" = "classical_dress",
		"/obj/item/clothing/head/rice_hat" = "classical_dress",
		"/obj/item/clothing/head/semitic_cap" = "classical_dress",
		"/obj/item/clothing/head/steppe_shaman" = "classical_dress",
		"/obj/item/clothing/shoes/aztec_sandals" = "classical_dress",
		"/obj/item/clothing/shoes/geta" = "classical_dress",
		"/obj/item/clothing/shoes/roman" = "classical_dress",
		"/obj/item/clothing/shoes/steppe_shoes" = "classical_dress",
		"/obj/item/clothing/suit/storage/jacket/steppe_shaman" = "classical_dress",
		"/obj/item/clothing/under/ainu" = "classical_dress",
		"/obj/item/clothing/under/ainu2" = "classical_dress",
		"/obj/item/clothing/under/celtic_long_braccae" = "classical_dress",
		"/obj/item/clothing/under/celtic_short_braccae" = "classical_dress",
		"/obj/item/clothing/under/custom/celtic" = "classical_dress",
		"/obj/item/clothing/under/custom/shendyt" = "classical_dress",
		"/obj/item/clothing/under/custom/stola" = "classical_dress",
		"/obj/item/clothing/under/custom/toga" = "classical_dress",
		"/obj/item/clothing/under/halfhuipil" = "classical_dress",
		"/obj/item/clothing/under/hanfu" = "classical_dress",
		"/obj/item/clothing/under/hanfu/green" = "classical_dress",
		"/obj/item/clothing/under/hanfu/light" = "classical_dress",
		"/obj/item/clothing/under/huipil" = "classical_dress",
		"/obj/item/clothing/under/kimono" = "classical_dress",
		"/obj/item/clothing/under/mayan_loincloth" = "classical_dress",
		"/obj/item/clothing/under/medieval/steppe_tunic" = "classical_dress",
		"/obj/item/clothing/under/pharaoh" = "classical_dress",
		"/obj/item/clothing/under/pharaoh2" = "classical_dress",
		"/obj/item/clothing/under/sari/blue" = "classical_dress",
		"/obj/item/clothing/under/sari/red" = "classical_dress",
		// --- combustion (15) ---
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank" = "combustion",
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike" = "combustion",
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike25" = "combustion",
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike75" = "combustion",
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank/small" = "combustion",
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank" = "combustion",
		"/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank" = "combustion",
		"/obj/structure/fuelpump/n" = "combustion",
		"/obj/structure/fuelpump/s" = "combustion",
		"/obj/structure/fuelpump/small" = "combustion",
		"/obj/structure/fuelpump/star" = "combustion",
		"/obj/structure/oil_deposits" = "combustion",
		"/obj/structure/oilwell" = "combustion",
		"/obj/structure/refinery" = "combustion",
		"/obj/structure/refinery/biofuel" = "combustion",
		// --- cooperage (14) ---
		"/obj/item/weapon/reagent_containers/glass/barrel" = "cooperage",
		"/obj/item/weapon/storage/backpack" = "cooperage",
		"/obj/item/weapon/storage/backpack/rucksack" = "cooperage",
		"/obj/item/weapon/storage/belt/leather" = "cooperage",
		"/obj/item/weapon/storage/foodbox" = "cooperage",
		"/obj/item/weapon/storage/ww2/shaving_kit" = "cooperage",
		"/obj/structure/closet/crate/chest" = "cooperage",
		"/obj/structure/closet/crate/empty" = "cooperage",
		"/obj/structure/closet/crate/empty/large" = "cooperage",
		"/obj/structure/closet/crate/large" = "cooperage",
		"/obj/structure/closet/crate/ww2" = "cooperage",
		"/obj/structure/cutting_board" = "cooperage",
		"/obj/structure/meat_grinder" = "cooperage",
		"/obj/structure/reagent_dispensers/largebarrel" = "cooperage",
		// --- crossbows (3) ---
		"/obj/item/weapon/gun/projectile/bow/compoundbow" = "crossbows",
		"/obj/item/weapon/gun/projectile/bow/crossbow" = "crossbows",
		"/obj/item/weapon/gun/projectile/bow/longbow" = "crossbows",
		// --- digital_computing (3) ---
		"/obj/item/weapon/analyser" = "digital_computing",
		"/obj/item/weapon/telephone/mobile" = "digital_computing",
		"/obj/structure/cell_tower" = "digital_computing",
		"/obj/structure/civ_generator/solar" = "digital_computing",
		"/obj/structure/civ_generator/nuclear" = "nuclear_power",
		"/obj/structure/reactor_fuel_processor" = "nuclear_power",
		// --- early_economy (10) ---
		"/obj/item/clothing/accessory/storage/coinpouch" = "early_economy",
		"/obj/item/stack/money/coppercoin" = "early_economy",
		"/obj/item/stack/money/goldcoin" = "early_economy",
		"/obj/item/stack/money/silvercoin" = "early_economy",
		"/obj/item/weapon/storage/bag/cash" = "early_economy",
		"/obj/structure/closet/crate/cash_register" = "early_economy",
		"/obj/structure/stockmarket" = "early_economy",
		"/obj/structure/supplier" = "early_economy",
		"/obj/structure/vending/sales/market_stall" = "early_economy",
		"/obj/structure/voting" = "early_economy",
		// --- electricity (11) ---
		"/obj/item/stack/cable_coil/blue" = "electricity",
		"/obj/item/stack/cable_coil/cyan" = "electricity",
		"/obj/item/stack/cable_coil/green" = "electricity",
		"/obj/item/stack/cable_coil/orange" = "electricity",
		"/obj/item/stack/cable_coil/pink" = "electricity",
		"/obj/item/stack/cable_coil/red" = "electricity",
		// Plain cable supplies the Electricity prototype before that node unlocks.
		"/obj/item/stack/cable_coil/white" = "paved_infrastructure",
		"/obj/item/stack/cable_coil/yellow" = "electricity",
		"/obj/item/stack/material/electronics" = "electricity",
		"/obj/structure/telegraph" = "electricity",
		"/obj/structure/teleprinter" = "electricity",
		// --- factories (16) ---
		"/obj/item/camera/earlymodern" = "factories",
		// nuclear_power's prototype item: must be researchable BEFORE that
		// node, or the tree deadlocks (can't craft the geiger counter the
		// node itself demands).
		"/obj/item/weapon/geiger_counter" = "factories",
		"/obj/item/weapon/can" = "factories",
		"/obj/item/weapon/can/large" = "factories",
		"/obj/item/weapon/can/small" = "factories",
		"/obj/item/weapon/reagent_containers/food/drinks/britmug" = "factories",
		"/obj/item/weapon/reagent_containers/food/drinks/sillycup" = "factories",
		"/obj/item/weapon/reagent_containers/glass/barrel/jerrycan" = "factories",
		"/obj/item/weapon/reagent_containers/glass/barrel/modern" = "factories",
		"/obj/item/weapon/reagent_containers/glass/small_pot/hangou" = "factories",
		"/obj/item/weapon/storage/ww2" = "factories",
		"/obj/structure/closet" = "factories",
		"/obj/structure/closet/crate" = "factories",
		"/obj/structure/closet/crate/bin" = "factories",
		"/obj/structure/radio" = "factories",
        "/obj/structure/telecom" = "factories",
        "/obj/structure/telecom/station" = "factories",
        "/obj/structure/telecom/antenna" = "factories",
        "/obj/structure/telecom/tv" = "assembly_line",
        "/obj/structure/telecom/station/tv" = "assembly_line",
        "/obj/structure/telecom/terminal" = "assembly_line",
        "/obj/item/weapon/telephone/landline" = "utilities",
		"/obj/structure/radio/transmitter" = "factories",
		// --- field_artillery (5) ---
		"/obj/item/stack/ammopart/casing/artillery" = "field_artillery",
		"/obj/item/stack/ammopart/casing/tank" = "field_artillery",
		"/obj/item/weapon/siegeladder/metal" = "field_artillery",
		"/obj/structure/barricade/antitank" = "field_artillery",
		"/obj/structure/cannon/modern" = "field_artillery",
		// --- field_defenses (14) ---
		"/obj/item/weapon/beartrap" = "field_defenses",
		"/obj/item/weapon/dummy_armor" = "field_defenses",
		"/obj/item/weapon/material/shovel/trench" = "field_defenses",
		"/obj/item/weapon/punji_sticks" = "field_defenses",
		"/obj/structure/barricade" = "field_defenses",
		"/obj/structure/barricade/horizontal" = "field_defenses",
		"/obj/structure/barricade/jap" = "field_defenses",
		"/obj/structure/barricade/vertical" = "field_defenses",
		"/obj/structure/barricade/wood_pole" = "field_defenses",
		"/obj/structure/grille/logfence" = "field_defenses",
		"/obj/structure/practice_dummy" = "field_defenses",
		"/obj/structure/practice_dummy/target" = "field_defenses",
		"/obj/structure/window/barrier/rock" = "field_defenses",
		"/obj/structure/window/barrier/sandstone" = "field_defenses",
		// --- field_surgery (14) ---
		"/obj/item/weapon/reagent_containers/syringe" = "field_surgery",
		"/obj/item/weapon/storage/firstaid/surgery_empty" = "field_surgery",
		"/obj/item/weapon/surgery/bone_saw" = "field_surgery",
		"/obj/item/weapon/surgery/bone_saw/bronze" = "field_surgery",
		"/obj/item/weapon/surgery/bonesetter" = "field_surgery",
		"/obj/item/weapon/surgery/bonesetter/bronze" = "field_surgery",
		"/obj/item/weapon/surgery/cautery" = "field_surgery",
		"/obj/item/weapon/surgery/cautery/bronze" = "field_surgery",
		"/obj/item/weapon/surgery/hemostat" = "field_surgery",
		"/obj/item/weapon/surgery/hemostat/bronze" = "field_surgery",
		"/obj/item/weapon/surgery/retractor" = "field_surgery",
		"/obj/item/weapon/surgery/retractor/bronze" = "field_surgery",
		"/obj/item/weapon/surgery/scalpel" = "field_surgery",
		"/obj/item/weapon/surgery/scalpel/bronze" = "field_surgery",
		// --- fine_arts (39) ---
		"/obj/item/clothing/mask/smokable/cigarette" = "fine_arts",
		"/obj/item/clothing/mask/smokable/cigarette/cigar" = "fine_arts",
		"/obj/item/clothing/mask/smokable/cigarette/cigar/havana" = "fine_arts",
		"/obj/item/clothing/mask/smokable/cigarette/joint" = "fine_arts",
		"/obj/item/clothing/mask/smokable/pipe" = "fine_arts",
		"/obj/item/trombone" = "fine_arts",
		"/obj/item/violin" = "fine_arts",
		"/obj/item/weapon/deck/cards" = "fine_arts",
		"/obj/item/weapon/dice" = "fine_arts",
		"/obj/item/weapon/dice/d00" = "fine_arts",
		"/obj/item/weapon/dice/d10" = "fine_arts",
		"/obj/item/weapon/dice/d12" = "fine_arts",
		"/obj/item/weapon/dice/d2" = "fine_arts",
		"/obj/item/weapon/dice/d20" = "fine_arts",
		"/obj/item/weapon/dice/d4" = "fine_arts",
		"/obj/item/weapon/dice/d8" = "fine_arts",
		"/obj/item/weapon/matchbox" = "fine_arts",
		"/obj/item/weapon/material/ashtray" = "fine_arts",
		"/obj/item/weapon/material/ashtray/bronze" = "fine_arts",
		"/obj/item/weapon/material/ashtray/glass" = "fine_arts",
		"/obj/item/weapon/material/ashtray/marble" = "fine_arts",
		"/obj/item/weapon/material/ashtray/stone" = "fine_arts",
		"/obj/item/weapon/storage/fancy/cigar" = "fine_arts",
		"/obj/item/weapon/storage/fancy/cigarettes" = "fine_arts",
		"/obj/structure/piano" = "fine_arts",
		"/obj/structure/sign/painting1" = "fine_arts",
		"/obj/structure/sign/painting10" = "fine_arts",
		"/obj/structure/sign/painting11" = "fine_arts",
		"/obj/structure/sign/painting12" = "fine_arts",
		"/obj/structure/sign/painting13" = "fine_arts",
		"/obj/structure/sign/painting2" = "fine_arts",
		"/obj/structure/sign/painting3" = "fine_arts",
		"/obj/structure/sign/painting4" = "fine_arts",
		"/obj/structure/sign/painting5" = "fine_arts",
		"/obj/structure/sign/painting6" = "fine_arts",
		"/obj/structure/sign/painting7" = "fine_arts",
		"/obj/structure/sign/painting8" = "fine_arts",
		"/obj/structure/sign/painting9" = "fine_arts",
		"/obj/structure/table/wood/poker" = "fine_arts",
		// --- fine_furniture (27) ---
		"/obj/covers/carpet/blackcarpet" = "fine_furniture",
		"/obj/covers/carpet/bluecarpet" = "fine_furniture",
		"/obj/covers/carpet/greencarpet" = "fine_furniture",
		"/obj/covers/carpet/orangecarpet" = "fine_furniture",
		"/obj/covers/carpet/pinkcarpet" = "fine_furniture",
		"/obj/covers/carpet/purplecarpet" = "fine_furniture",
		"/obj/covers/carpet/redcarpet" = "fine_furniture",
		"/obj/covers/carpet/tealcarpet" = "fine_furniture",
		"/obj/covers/carpet/whitecarpet" = "fine_furniture",
		"/obj/structure/TV/grandfather" = "fine_furniture",
		"/obj/structure/bed/chair/wood/red" = "fine_furniture",
		"/obj/structure/bed/chair/wood/wings" = "fine_furniture",
		"/obj/structure/bed/psych" = "fine_furniture",
		"/obj/structure/bed/sofa" = "fine_furniture",
		"/obj/structure/bed/sofa/left" = "fine_furniture",
		"/obj/structure/bed/sofa/right" = "fine_furniture",
		"/obj/structure/bookcase" = "fine_furniture",
		"/obj/structure/closet/cabinet" = "fine_furniture",
		"/obj/structure/closet/cabinet/ceiling" = "fine_furniture",
		"/obj/structure/filingcabinet/chestdrawer" = "fine_furniture",
		"/obj/structure/oven" = "fine_furniture",
		"/obj/structure/oven/woodstove" = "fine_furniture",
		"/obj/structure/sign/clock" = "fine_furniture",
		"/obj/structure/table/fancy" = "fine_furniture",
		"/obj/structure/table/modern/table" = "fine_furniture",
		"/obj/structure/table/rack/coatrack" = "fine_furniture",
		"/obj/structure/table/rack/shelf" = "fine_furniture",
		// --- fine_garments (55) ---
		"/obj/item/clothing/accessory/storage/coinpouch/gator_wallet" = "fine_garments",
		"/obj/item/clothing/accessory/storage/coinpouch/lizard_wallet" = "fine_garments",
		"/obj/item/clothing/gloves/oven" = "fine_garments",
		"/obj/item/clothing/shoes/blackboots" = "fine_garments",
		"/obj/item/clothing/shoes/gator_ankleboots" = "fine_garments",
		"/obj/item/clothing/shoes/leatherboots" = "fine_garments",
		"/obj/item/clothing/shoes/lizard_ankleboots" = "fine_garments",
		"/obj/item/clothing/shoes/riding1" = "fine_garments",
		"/obj/item/clothing/shoes/riding1/gator_cowboy" = "fine_garments",
		"/obj/item/clothing/shoes/riding1/lizard_cowboy" = "fine_garments",
		"/obj/item/clothing/shoes/riding2" = "fine_garments",
		"/obj/item/clothing/shoes/soldiershoes" = "fine_garments",
		"/obj/item/clothing/suit/storage/coat/fur/white" = "fine_garments",
		"/obj/item/clothing/suit/storage/coat/japcoat2/brown" = "fine_garments",
		"/obj/item/clothing/suit/storage/coat/ruscoat/grey" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/blackvest" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/bluevest" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/leatherovercoat1" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/leatherovercoat2" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/olivevest" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/piratejacket1" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/piratejacket3" = "fine_garments",
		"/obj/item/clothing/suit/storage/jacket/piratejacket4" = "fine_garments",
		"/obj/item/clothing/under/blackdress" = "fine_garments",
		"/obj/item/clothing/under/blackdress/short" = "fine_garments",
		"/obj/item/clothing/under/christian_priest" = "fine_garments",
		"/obj/item/clothing/under/civ2" = "fine_garments",
		"/obj/item/clothing/under/civ3" = "fine_garments",
		"/obj/item/clothing/under/civ4" = "fine_garments",
		"/obj/item/clothing/under/civ5" = "fine_garments",
		"/obj/item/clothing/under/civ6" = "fine_garments",
		"/obj/item/clothing/under/civf1" = "fine_garments",
		"/obj/item/clothing/under/civf2" = "fine_garments",
		"/obj/item/clothing/under/civf3" = "fine_garments",
		"/obj/item/clothing/under/civfg" = "fine_garments",
		"/obj/item/clothing/under/civfr" = "fine_garments",
		"/obj/item/clothing/under/count_outfit" = "fine_garments",
		"/obj/item/clothing/under/crinoline_dress" = "fine_garments",
		"/obj/item/clothing/under/custom/tunic" = "fine_garments",
		"/obj/item/clothing/under/customdress" = "fine_garments",
		"/obj/item/clothing/under/customdress2" = "fine_garments",
		"/obj/item/clothing/under/custompontifical" = "fine_garments",
		"/obj/item/clothing/under/custompyjamas" = "fine_garments",
		"/obj/item/clothing/under/customuniform/colonial" = "fine_garments",
		"/obj/item/clothing/under/industrial1" = "fine_garments",
		"/obj/item/clothing/under/industrial2" = "fine_garments",
		"/obj/item/clothing/under/industrial3" = "fine_garments",
		"/obj/item/clothing/under/lederhosen" = "fine_garments",
		"/obj/item/clothing/under/medieval/kilt" = "fine_garments",
		"/obj/item/clothing/under/merchant_suit" = "fine_garments",
		"/obj/item/clothing/under/nun" = "fine_garments",
		"/obj/item/clothing/under/pilgrim" = "fine_garments",
		"/obj/item/weapon/storage/belt/gator_belt" = "fine_garments",
		"/obj/item/weapon/storage/belt/lizard_belt" = "fine_garments",
		"/obj/item/weapon/storage/briefcase" = "fine_garments",
		// --- fortifications (18) ---
		"/obj/item/stack/material/barbwire" = "fortifications",
		"/obj/structure/barbwire" = "fortifications",
		"/obj/structure/barricade/jap_h" = "fortifications",
		"/obj/structure/barricade/jap_h_l" = "fortifications",
		"/obj/structure/barricade/jap_h_r" = "fortifications",
		"/obj/structure/barricade/jap_v" = "fortifications",
		"/obj/structure/barricade/jap_v_b" = "fortifications",
		"/obj/structure/barricade/jap_v_t" = "fortifications",
		"/obj/structure/barricade/sandstone_h/crenelated" = "fortifications",
		"/obj/structure/barricade/sandstone_v/crenelated" = "fortifications",
		"/obj/structure/barricade/stone_h" = "fortifications",
		"/obj/structure/barricade/stone_h/crenelated" = "fortifications",
		"/obj/structure/barricade/stone_v" = "fortifications",
		"/obj/structure/barricade/stone_v/crenelated" = "fortifications",
		"/obj/structure/gate" = "fortifications",
		"/obj/structure/gate/sandstone" = "fortifications",
		"/obj/structure/gatecontrol" = "fortifications",
		"/obj/structure/gatecontrol/sandstone" = "fortifications",
		// --- furriery (10) ---
		"/obj/item/clothing/head/furcap" = "furriery",
		"/obj/item/clothing/head/furhat" = "furriery",
		"/obj/item/clothing/head/furhat/bison" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fancy_fur_coat" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fur" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fur/black" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fur/brown" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fur/grey" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fur/orc" = "furriery",
		"/obj/item/clothing/suit/storage/coat/fur/pink" = "furriery",
		// --- germ_theory (5) ---
		"/obj/item/weapon/reagent_containers/food/drinks/plastic/carton" = "germ_theory",
		"/obj/structure/canner" = "germ_theory",
		"/obj/structure/converter/acid_bath" = "germ_theory",
		"/obj/structure/shower/bathtub/big/steel" = "germ_theory",
		"/obj/structure/shower/bathtub/steel" = "germ_theory",
		// --- glassworking (8) ---
		"/obj/item/weapon/reagent_containers/food/drinks/bottle/large" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/bottle/small" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/beer" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/fancybeer" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/beermug" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/tea/empty" = "glassworking",
		"/obj/item/weapon/reagent_containers/food/drinks/teapot" = "glassworking",
		// --- gunpowder (11) ---
		"/obj/item/ammo_magazine/emptypouch" = "gunpowder",
		"/obj/item/stack/ammopart/blunderbuss" = "gunpowder",
		"/obj/item/stack/ammopart/bullet" = "gunpowder",
		"/obj/item/stack/ammopart/musketball" = "gunpowder",
		"/obj/item/stack/ammopart/musketball_pistol" = "gunpowder",
		"/obj/item/weapon/grenade/dynamite" = "gunpowder",
		"/obj/item/weapon/gun/projectile/ancient/arquebus" = "gunpowder",
		"/obj/item/weapon/gun/projectile/ancient/firelance" = "gunpowder",
		"/obj/item/weapon/gun/projectile/ancient/handcannon" = "gunpowder",
		"/obj/item/weapon/gun/projectile/ancient/matchlock" = "gunpowder",
		"/obj/item/weapon/gun/projectile/ancient/tanegashima" = "gunpowder",
		// --- gunsmithing (13) ---
		"/obj/item/weapon/gun_mount" = "gunsmithing",
		"/obj/item/blackpowder_part/stock/pistol" = "gunsmithing",
		"/obj/item/blackpowder_part/stock/musket" = "gunsmithing",
		"/obj/item/clothing/accessory/holster/hip" = "gunsmithing",
		"/obj/item/clothing/accessory/holster/hip/double" = "gunsmithing",
		"/obj/item/clothing/accessory/storage/webbing" = "gunsmithing",
		"/obj/item/weapon/attachment/bayonet" = "gunsmithing",
		"/obj/item/weapon/gun_cleaning_kit" = "gunsmithing",
		"/obj/structure/gunbench" = "gunsmithing",
		"/obj/structure/repair/gun" = "gunsmithing",
		"/obj/structure/shellrack" = "gunsmithing",
		"/obj/structure/vending/craftable/rifles" = "gunsmithing",
		"/obj/structure/vending/craftable/rifles/wood" = "gunsmithing",
		// --- haberdashery (42) ---
		"/obj/item/clothing/accessory/custom/apron" = "haberdashery",
		"/obj/item/clothing/accessory/custom/bowtie" = "haberdashery",
		"/obj/item/clothing/accessory/custom/priest_band" = "haberdashery",
		"/obj/item/clothing/accessory/custom/scarf" = "haberdashery",
		"/obj/item/clothing/accessory/custom/tie" = "haberdashery",
		"/obj/item/clothing/accessory/storage/coinpouch/wallet" = "haberdashery",
		"/obj/item/clothing/accessory/suspenders" = "haberdashery",
		"/obj/item/clothing/accessory/suspenders/dark" = "haberdashery",
		"/obj/item/clothing/head/bandit" = "haberdashery",
		"/obj/item/clothing/head/bicorne_british_soldier" = "haberdashery",
		"/obj/item/clothing/head/blue_sailorberet" = "haberdashery",
		"/obj/item/clothing/head/bowler_hat" = "haberdashery",
		"/obj/item/clothing/head/capotain" = "haberdashery",
		"/obj/item/clothing/head/capotain/pilgrim" = "haberdashery",
		"/obj/item/clothing/head/count_hat" = "haberdashery",
		"/obj/item/clothing/head/cowboyhat" = "haberdashery",
		"/obj/item/clothing/head/cowboyhat2" = "haberdashery",
		"/obj/item/clothing/head/custom/custombandana" = "haberdashery",
		"/obj/item/clothing/head/custom/customberet" = "haberdashery",
		"/obj/item/clothing/head/custom_feathered_hat" = "haberdashery",
		"/obj/item/clothing/head/feathered_hat" = "haberdashery",
		"/obj/item/clothing/head/helmet/constable" = "haberdashery",
		"/obj/item/clothing/head/helmet/leather_infantry" = "haberdashery",
		"/obj/item/clothing/head/helmet/leather_infantry/blue" = "haberdashery",
		"/obj/item/clothing/head/helmet/leather_infantry/brown" = "haberdashery",
		"/obj/item/clothing/head/helmet/leather_infantry/red" = "haberdashery",
		"/obj/item/clothing/head/helmet/napoleonic/bearskin" = "haberdashery",
		"/obj/item/clothing/head/helmet/napoleonic/bearskin/brown" = "haberdashery",
		"/obj/item/clothing/head/helmet/napoleonic/bearskin/white" = "haberdashery",
		"/obj/item/clothing/head/kerchief" = "haberdashery",
		"/obj/item/clothing/head/nun_hood" = "haberdashery",
		"/obj/item/clothing/head/nurse" = "haberdashery",
		"/obj/item/clothing/head/piratebandana1" = "haberdashery",
		"/obj/item/clothing/head/red_sailorberet" = "haberdashery",
		"/obj/item/clothing/head/roundcap" = "haberdashery",
		"/obj/item/clothing/head/sombrero" = "haberdashery",
		"/obj/item/clothing/head/tarred_hat" = "haberdashery",
		"/obj/item/clothing/head/tricorne_black" = "haberdashery",
		"/obj/item/clothing/head/vaquerohat" = "haberdashery",
		"/obj/item/clothing/head/ww2/sov_ushanka/nomads" = "haberdashery",
		"/obj/item/clothing/mask/shemagh/greykerchief" = "haberdashery",
		"/obj/item/clothing/mask/shemagh/redkerchief" = "haberdashery",
		// --- herbalism (9) ---
		"/obj/item/stack/medical/bruise_pack/bint" = "herbalism",
		"/obj/item/stack/medical/bruise_pack/bint/leather" = "herbalism",
		"/obj/item/stack/medical/splint" = "herbalism",
		"/obj/item/weapon/bedsheet/medical" = "herbalism",
		"/obj/item/weapon/prosthesis/pegleg" = "herbalism",
		"/obj/item/weapon/prosthesis/woodfoot" = "herbalism",
		"/obj/item/weapon/reagent_containers/food/snacks/leaf_salad" = "herbalism",
		"/obj/item/weapon/reagent_containers/pill/opium" = "herbalism",
		"/obj/structure/drying_rack" = "herbalism",
		// --- hygiene (11) ---
		"/obj/item/weapon/material/kitchen/utensil/knife/razorblade" = "hygiene",
		"/obj/structure/shower/bathtub/bronze" = "hygiene",
		"/obj/structure/shower/bathtub/copper" = "hygiene",
		"/obj/structure/shower/bathtub/stone" = "hygiene",
		"/obj/structure/shower/bathtub/wooden" = "hygiene",
		"/obj/structure/sink/well" = "hygiene",
		"/obj/structure/sink/well/marble" = "hygiene",
		"/obj/structure/sink/well/sandstone" = "hygiene",
		"/obj/structure/toilet/outhouse" = "hygiene",
		"/obj/structure/toilet/outhouse/female" = "hygiene",
		"/obj/structure/toilet/outhouse/male" = "hygiene",
		// --- imperial_architecture (44) ---
		"/obj/covers/decorative_marbletile" = "imperial_architecture",
		"/obj/covers/decorative_marbletile/black" = "imperial_architecture",
		"/obj/covers/decorative_marbletile/pink" = "imperial_architecture",
		"/obj/covers/marble_checkerboard" = "imperial_architecture",
		"/obj/covers/marble_checkerboard/pink" = "imperial_architecture",
		"/obj/covers/marble_checkerboard/pink/reverse" = "imperial_architecture",
		"/obj/covers/marble_checkerboard/reverse" = "imperial_architecture",
		"/obj/covers/marble_grid" = "imperial_architecture",
		"/obj/covers/marble_wall" = "imperial_architecture",
		"/obj/covers/marble_wall/classic" = "imperial_architecture",
		"/obj/covers/marble_wall/grecian" = "imperial_architecture",
		"/obj/covers/marble_wall/grecian/archway" = "imperial_architecture",
		"/obj/covers/marble_wall/grecian/archway/modern" = "imperial_architecture",
		"/obj/covers/marblefloor" = "imperial_architecture",
		"/obj/covers/marbletile" = "imperial_architecture",
		"/obj/covers/marbletile/black" = "imperial_architecture",
		"/obj/covers/marbletile/pink" = "imperial_architecture",
		"/obj/covers/ornatemarblefloor" = "imperial_architecture",
		"/obj/covers/ornatemarblefloor/black" = "imperial_architecture",
		"/obj/covers/raw_marblefloor" = "imperial_architecture",
		"/obj/covers/raw_marblefloor/black" = "imperial_architecture",
		"/obj/covers/raw_marblefloor/pink" = "imperial_architecture",
		"/obj/item/weapon/roofbuilder/glass" = "imperial_architecture",
		"/obj/structure/mine_support/stone/aztec/marble" = "imperial_architecture",
		"/obj/structure/mine_support/stone/aztec/obsidian" = "imperial_architecture",
		"/obj/structure/mine_support/stone/ionic" = "imperial_architecture",
		"/obj/structure/mine_support/stone/ionic/obsidian" = "imperial_architecture",
		"/obj/structure/mine_support/stone/ionic/rock" = "imperial_architecture",
		"/obj/structure/mine_support/stone/ionic/sandstone" = "imperial_architecture",
		"/obj/structure/mine_support/stone/marble" = "imperial_architecture",
		"/obj/structure/mine_support/stone/obsidian" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/obsidian" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/rock" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/sandstone" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/thick" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/thick/obsidian" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/thick/rock" = "imperial_architecture",
		"/obj/structure/mine_support/stone/solomonic/thick/sandstone" = "imperial_architecture",
		"/obj/structure/sign/custom/golden" = "imperial_architecture",
		"/obj/structure/sign/custom/metallic" = "imperial_architecture",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/marble" = "imperial_architecture",
		"/obj/structure/window_frame/marble" = "imperial_architecture",
		"/obj/structure/window_frame/marblefull" = "imperial_architecture",
		// --- iron_smithing (5) ---
		"/obj/item/weapon/reagent_containers/food/drinks/gunpowder" = "iron_smithing",
		"/obj/structure/anvil" = "iron_smithing",
		"/obj/structure/furnace" = "iron_smithing",
		"/obj/structure/furnace/blast_furnace" = "iron_smithing",
		"/obj/structure/heatsource" = "iron_smithing",
		// --- iron_tools (4) ---
		"/obj/item/flashlight/lantern" = "iron_tools",
		"/obj/item/weapon/hammer/modern" = "iron_tools",
		"/obj/item/weapon/material/fancycane" = "iron_tools",
		"/obj/item/weapon/wirecutters" = "iron_tools",
		// --- law_order (15) ---
		"/obj/covers/jail/steeljail" = "law_order",
		"/obj/covers/jail/woodjail" = "law_order",
		"/obj/item/garrote" = "law_order",
		"/obj/item/weapon/handcuffs" = "law_order",
		"/obj/item/weapon/material/kitchen/utensil/knife/shank" = "law_order",
		"/obj/item/weapon/material/kitchen/utensil/knife/shank/glass" = "law_order",
		"/obj/item/weapon/material/kitchen/utensil/knife/shank/iron" = "law_order",
		"/obj/item/weapon/melee/classic_baton" = "law_order",
		"/obj/item/weapon/whistle" = "law_order",
		"/obj/structure/cross" = "law_order",
		"/obj/structure/cross/tau" = "law_order",
		"/obj/structure/gallows" = "law_order",
		"/obj/structure/pillory" = "law_order",
		"/obj/structure/simple_door/key_door/custom/jail/steeljail" = "law_order",
		"/obj/structure/simple_door/key_door/custom/jail/woodjail" = "law_order",
		// --- machined_tools (4) ---
		"/obj/item/weapon/enginemaker" = "machined_tools",
		"/obj/item/weapon/fishing/modern" = "machined_tools",
		"/obj/item/weapon/reagent_containers/glass/fire_extinguisher/empty" = "machined_tools",
		"/obj/item/weapon/weldingtool" = "machined_tools",
		// --- mail_plate (7) ---
		"/obj/item/clothing/head/helmet/jingasa" = "mail_plate",
		"/obj/item/clothing/head/helmet/kasa" = "mail_plate",
		"/obj/item/clothing/head/helmet/medieval/emirate" = "mail_plate",
		"/obj/item/clothing/head/helmet/medieval/nomads/arab" = "mail_plate",
		"/obj/item/clothing/head/helmet/medieval/nomads/arab2" = "mail_plate",
		"/obj/item/clothing/head/helmet/medieval/nomads/arab3" = "mail_plate",
		"/obj/item/clothing/head/helmet/medieval/nomads/arab4" = "mail_plate",
		// --- manufactured_furniture (7) ---
		"/obj/item/weapon/radio" = "manufactured_furniture",
		"/obj/structure/bed/chair/office/dark" = "manufactured_furniture",
		"/obj/structure/bed/chair/office/light" = "manufactured_furniture",
		"/obj/structure/bed/chair/steel" = "manufactured_furniture",
		"/obj/structure/oven/grill" = "manufactured_furniture",
		"/obj/structure/table/modern/retable" = "manufactured_furniture",
		"/obj/structure/wallclock" = "manufactured_furniture",
		// --- mechanized_war (5) ---
		"/obj/structure/bed/chair/commander" = "mechanized_war",
		"/obj/structure/bed/chair/gunner" = "mechanized_war",
		"/obj/structure/bed/chair/loader" = "mechanized_war",
		"/obj/structure/cannon/modern/tank" = "mechanized_war",
		"/obj/structure/vehicleparts/movement/tracks" = "mechanized_war",
		// --- missiles (2) ---
		"/obj/item/stack/ammopart/casing/booster" = "missiles",
		"/obj/item/stack/ammopart/warhead" = "missiles",
		// --- modern_armor (7) ---
		"/obj/item/clothing/accessory/armor/nomads/civiliankevlar" = "modern_armor",
		"/obj/item/clothing/head/nbc" = "modern_armor",
		"/obj/item/clothing/head/nbc/olive" = "modern_armor",
		"/obj/item/clothing/mask/gas/modern" = "modern_armor",
		"/obj/item/clothing/mask/gas/modern2" = "modern_armor",
		"/obj/item/clothing/suit/nbc" = "modern_armor",
		"/obj/item/clothing/suit/nbc/olive" = "modern_armor",
		// --- modern_construction (10) ---
		"/obj/covers/sidewalk" = "modern_construction",
		"/obj/item/clothing/head/helmet/modern/hardhat" = "modern_construction",
		"/obj/item/clothing/head/helmet/modern/hardhat/orange" = "modern_construction",
		"/obj/item/clothing/head/helmet/modern/hardhat/yellow" = "modern_construction",
		"/obj/item/weapon/trafficcone" = "modern_construction",
		"/obj/structure/sign/traffic/crossing" = "modern_construction",
		"/obj/structure/sign/traffic/noentry" = "modern_construction",
		"/obj/structure/sign/traffic/stop" = "modern_construction",
		"/obj/structure/sign/traffic/yeld" = "modern_construction",
		"/obj/structure/window/barrier/jersey" = "modern_construction",
		// --- modern_medicine (1) ---
		"/obj/item/weapon/reagent_containers/blood/empty" = "modern_medicine",
		// --- monuments (17) ---
		"/obj/item/weapon/material/bust" = "monuments",
		"/obj/item/weapon/material/hippocratic" = "monuments",
		"/obj/item/weapon/material/marx" = "monuments",
		"/obj/structure/religious/angel" = "monuments",
		"/obj/structure/religious/gargoyle" = "monuments",
		"/obj/structure/religious/monument/crucero" = "monuments",
		"/obj/structure/religious/monument/cultist/cthulu" = "monuments",
		"/obj/structure/religious/monument/cultist/moloch" = "monuments",
		"/obj/structure/religious/monument/cultist/outsider" = "monuments",
		"/obj/structure/religious/monument/cultist/sauron" = "monuments",
		"/obj/structure/religious/monument/karl_marx" = "monuments",
		"/obj/structure/religious/monument/monk/quangshi" = "monuments",
		"/obj/structure/religious/monument/obelisk" = "monuments",
		"/obj/structure/religious/monument/pillar_monument" = "monuments",
		"/obj/structure/religious/monument/priesthood/saint" = "monuments",
		"/obj/structure/religious/monument/venus" = "monuments",
		"/obj/structure/religious/statue" = "monuments",
		// --- nuclear_power (1) ---
		// geiger counter deliberately NOT here: it's this node's prototype
		// item, so it must be craftable earlier (it's under factories, era4).
		"/obj/structure/sign/radiation" = "nuclear_power",
		// --- optics_instruments (15) ---
		"/obj/item/camera/early" = "optics_instruments",
		"/obj/item/camera_film" = "optics_instruments",
		"/obj/item/clothing/glasses/gglasses" = "optics_instruments",
		"/obj/item/clothing/glasses/monocle" = "optics_instruments",
		"/obj/item/clothing/glasses/redlense" = "optics_instruments",
		"/obj/item/clothing/glasses/regular" = "optics_instruments",
		"/obj/item/clothing/glasses/sunglasses" = "optics_instruments",
		"/obj/item/clothing/glasses/sunglasses/large" = "optics_instruments",
		"/obj/item/clothing/gloves/watch/goldwatch" = "optics_instruments",
		"/obj/item/clothing/gloves/watch/specialwatch" = "optics_instruments",
		"/obj/item/clothing/gloves/watch/watch" = "optics_instruments",
		"/obj/item/weapon/attachment/scope/adjustable/binoculars" = "optics_instruments",
		"/obj/item/weapon/compass" = "optics_instruments",
		"/obj/item/weapon/globe" = "optics_instruments",
		"/obj/item/weapon/watch/pocket" = "optics_instruments",
		// --- padded_armor (31) ---
		"/obj/item/clothing/head/helmet/aged_eisenbruck" = "padded_armor",
		"/obj/item/clothing/head/helmet/bone" = "padded_armor",
		"/obj/item/clothing/head/helmet/brown_eisenbruck" = "padded_armor",
		"/obj/item/clothing/head/helmet/chitin" = "padded_armor",
		"/obj/item/clothing/head/helmet/grey_eisenbruck" = "padded_armor",
		"/obj/item/clothing/head/helmet/hatchigane" = "padded_armor",
		"/obj/item/clothing/head/helmet/khepresh" = "padded_armor",
		"/obj/item/clothing/head/helmet/leather" = "padded_armor",
		"/obj/item/clothing/head/helmet/leather_skullcap" = "padded_armor",
		"/obj/item/clothing/head/helmet/samurai/guard" = "padded_armor",
		"/obj/item/clothing/head/helmet/samurai/guard/black" = "padded_armor",
		"/obj/item/clothing/head/helmet/samurai/guard/blue" = "padded_armor",
		"/obj/item/clothing/head/helmet/samurai/guard/red" = "padded_armor",
		"/obj/item/clothing/suit/armor/ancient/aztec_harness" = "padded_armor",
		"/obj/item/clothing/suit/armor/ancient/gator_scale_armor" = "padded_armor",
		"/obj/item/clothing/suit/armor/ancient/linen" = "padded_armor",
		"/obj/item/clothing/suit/armor/chitin" = "padded_armor",
		"/obj/item/clothing/suit/armor/medieval/leather" = "padded_armor",
		"/obj/item/clothing/suit/armor/medieval/steppe_leather" = "padded_armor",
		"/obj/item/clothing/suit/armor/samurai" = "padded_armor",
		"/obj/item/clothing/suit/armor/samurai/black" = "padded_armor",
		"/obj/item/clothing/suit/armor/samurai/blue" = "padded_armor",
		"/obj/item/clothing/suit/armor/samurai/red" = "padded_armor",
		"/obj/item/clothing/suit/hairbonearmor" = "padded_armor",
		"/obj/item/clothing/suit/storage/jacket/bonearmor" = "padded_armor",
		"/obj/item/weapon/shield" = "padded_armor",
		"/obj/item/weapon/shield/chimalli" = "padded_armor",
		"/obj/item/weapon/shield/chitin" = "padded_armor",
		"/obj/item/weapon/shield/chitin/large" = "padded_armor",
		"/obj/item/weapon/shield/nguni_shield" = "padded_armor",
		"/obj/structure/repair/workbench" = "padded_armor",
		// --- papermaking (13) ---
		"/obj/item/weapon/book" = "papermaking",
		"/obj/item/weapon/book/holybook" = "papermaking",
		"/obj/item/weapon/book/language_book" = "papermaking",
		"/obj/item/weapon/clipboard" = "papermaking",
		"/obj/item/weapon/folder" = "papermaking",
		"/obj/item/weapon/folder/red" = "papermaking",
		"/obj/item/weapon/folder/yellow" = "papermaking",
		"/obj/item/weapon/paper" = "papermaking",
		"/obj/item/weapon/pen" = "papermaking",
		"/obj/item/weapon/stamp/mail" = "papermaking",
		"/obj/item/weapon/storage/envelope" = "papermaking",
		"/obj/structure/filingcabinet" = "papermaking",
		"/obj/structure/filingcabinet/filingcabinet" = "papermaking",
		// --- paved_infrastructure (4) ---
		"/obj/covers/road" = "paved_infrastructure",
		"/obj/covers/roads/cobble" = "paved_infrastructure",
		"/obj/covers/roads/modern" = "paved_infrastructure",
		"/obj/covers/roads/roman" = "paved_infrastructure",
		// --- pharmacology (4) ---
		"/obj/structure/centrifuge" = "pharmacology",
		"/obj/structure/chem_master" = "pharmacology",
		"/obj/structure/chemical_dispenser" = "pharmacology",
		"/obj/structure/chemical_dispenser/full/laboratory" = "pharmacology",
		"/obj/structure/closet/fridge" = "pharmacology",
		// --- pottery_storage (32) ---
		"/obj/item/kitchen/wood_bowl" = "pottery_storage",
		"/obj/item/stack/material/stone" = "pottery_storage",
		"/obj/item/weapon/clay/bigclaypot" = "pottery_storage",
		"/obj/item/weapon/clay/claybowl" = "pottery_storage",
		"/obj/item/weapon/clay/claybricks" = "pottery_storage",
		"/obj/item/weapon/clay/claycup" = "pottery_storage",
		"/obj/item/weapon/clay/clayjug" = "pottery_storage",
		"/obj/item/weapon/clay/claypitcher" = "pottery_storage",
		"/obj/item/weapon/clay/claypot" = "pottery_storage",
		"/obj/item/weapon/clay/cookingpot" = "pottery_storage",
		"/obj/item/weapon/clay/largeclaypitcher" = "pottery_storage",
		"/obj/item/weapon/clay/mold/clayjug" = "pottery_storage",
		"/obj/item/weapon/clay/mold/claypot" = "pottery_storage",
		"/obj/item/weapon/clay/roofing" = "pottery_storage",
		"/obj/item/weapon/clay/roofing/kerawa" = "pottery_storage",
		"/obj/item/weapon/clay/smallclaypot" = "pottery_storage",
		"/obj/item/weapon/clay/vase" = "pottery_storage",
		"/obj/item/weapon/clay/verysmallclaypot" = "pottery_storage",
		"/obj/item/weapon/clay/winecup" = "pottery_storage",
		"/obj/item/weapon/key" = "pottery_storage",
		"/obj/item/weapon/material/kitchen/utensil/chopsticks" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/glass/bucket" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/glass/small_pot" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/glass/small_pot/copper_large" = "pottery_storage",
		"/obj/item/weapon/reagent_containers/glass/small_pot/copper_small" = "pottery_storage",
		"/obj/item/weapon/starterjar" = "pottery_storage",
		"/obj/structure/plant_pot/clay/light" = "pottery_storage",
		"/obj/structure/plant_pot/medium_planter/clay/yellow" = "pottery_storage",
		"/obj/structure/pot" = "pottery_storage",
		// --- power tools and resource extraction ---
		"/obj/item/weapon/material/pickaxe/jackhammer" = "power_tools",
		"/obj/structure/drill" = "electricity",
		"/obj/structure/drill/fracking" = "hydraulic_fracturing",
		"/obj/structure/drill/sifter" = "electricity",
		"/obj/structure/drill/sifter/panner" = "electricity",
		"/obj/item/weapon/resource_sieve" = "basic_tools",
		// --- primitive_construction (42) ---
		"/obj/covers/fancywood" = "primitive_construction",
		"/obj/covers/straw_wall" = "primitive_construction",
		"/obj/covers/tatami" = "primitive_construction",
		"/obj/covers/tatami_dark" = "primitive_construction",
		"/obj/covers/tatami_dark_vertical" = "primitive_construction",
		"/obj/covers/tatami_vertical" = "primitive_construction",
		"/obj/covers/thatch" = "primitive_construction",
		"/obj/covers/thatch2" = "primitive_construction",
		"/obj/covers/wood" = "primitive_construction",
		"/obj/covers/wood/stairs" = "primitive_construction",
		"/obj/covers/wood_wall/adjustable" = "primitive_construction",
		"/obj/covers/wood_wall/aztec" = "primitive_construction",
		"/obj/covers/wood_wall/log" = "primitive_construction",
		"/obj/covers/wood_wall/log/corner" = "primitive_construction",
		"/obj/covers/wood_wall/nordic" = "primitive_construction",
		"/obj/item/flashlight/tiki_torch" = "primitive_construction",
		"/obj/item/flashlight/torch" = "primitive_construction",
		"/obj/item/weapon/covers" = "primitive_construction",
		"/obj/item/weapon/roofbuilder" = "primitive_construction",
		"/obj/item/weapon/roofbuilder/leaves" = "primitive_construction",
		"/obj/item/weapon/roofbuilder/palm" = "primitive_construction",
		"/obj/structure/grille/fence" = "primitive_construction",
		"/obj/structure/grille/fence/picket" = "primitive_construction",
		"/obj/structure/mine_support" = "primitive_construction",
		"/obj/structure/roof_support" = "primitive_construction",
		"/obj/structure/roof_support/bamboo" = "primitive_construction",
		"/obj/structure/roof_support/nordic" = "primitive_construction",
		"/obj/structure/sign/custom" = "primitive_construction",
		"/obj/structure/sign/custom/plaque" = "primitive_construction",
		"/obj/structure/sign/signpost" = "primitive_construction",
		"/obj/structure/simple_door/fence" = "primitive_construction",
		"/obj/structure/simple_door/fence/picket" = "primitive_construction",
		"/obj/structure/simple_door/key_door/anyone/aztec" = "primitive_construction",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/bamboo" = "primitive_construction",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/wood" = "primitive_construction",
		"/obj/structure/simple_door/key_door/anyone/nordic" = "primitive_construction",
		"/obj/structure/simple_door/key_door/anyone/rustic" = "primitive_construction",
		"/obj/structure/simple_door/key_door/anyone/wood" = "primitive_construction",
		"/obj/structure/torch_stand" = "primitive_construction",
		"/obj/structure/wallframe" = "primitive_construction",
		"/obj/structure/wallframe/bamboo" = "primitive_construction",
		"/obj/structure/window_frame" = "primitive_construction",
		// --- printing_currency (22) ---
		"/obj/item/clothing/accessory/storage/passport" = "printing_currency",
		"/obj/item/weapon/paper/official" = "printing_currency",
		"/obj/item/weapon/poster/faction/lead" = "printing_currency",
		"/obj/item/weapon/poster/faction/mil1" = "printing_currency",
		"/obj/item/weapon/poster/faction/mil2" = "printing_currency",
		"/obj/item/weapon/poster/faction/work" = "printing_currency",
		"/obj/item/weapon/poster/religious" = "printing_currency",
		"/obj/item/weapon/stamp/approved" = "printing_currency",
		"/obj/item/weapon/stamp/captain" = "printing_currency",
		"/obj/item/weapon/stamp/ce" = "printing_currency",
		"/obj/item/weapon/stamp/clown" = "printing_currency",
		"/obj/item/weapon/stamp/denied" = "printing_currency",
		"/obj/item/weapon/stamp/hop" = "printing_currency",
		"/obj/item/weapon/stamp/hos" = "printing_currency",
		"/obj/item/weapon/stamp/internalaffairs" = "printing_currency",
		"/obj/item/weapon/storage/photo_album" = "printing_currency",
		"/obj/item/weapon/visa" = "printing_currency",
		"/obj/structure/closet/crate/wall_mailbox" = "printing_currency",
		"/obj/structure/closet/crate/wall_mailbox/wood_mailbox" = "printing_currency",
		"/obj/structure/money_printer" = "printing_currency",
		"/obj/structure/noticeboard" = "printing_currency",
		"/obj/structure/printingpress" = "printing_currency",
		// --- public_health (3) ---
		"/obj/item/weapon/paper_bin/empty" = "public_health",
		"/obj/item/weapon/storage/bag/trash" = "public_health",
		"/obj/structure/closet/crate/dumpster" = "public_health",
		// --- rail_steam (8) ---
		"/obj/structure/rails/regular" = "rail_steam",
		"/obj/structure/rails/regular/horizontal" = "rail_steam",
		"/obj/structure/rails/rotate" = "rail_steam",
		"/obj/structure/rails/split/switcher" = "rail_steam",
		"/obj/structure/rails/split/switcher/right" = "rail_steam",
		"/obj/structure/rails/turn" = "rail_steam",
		"/obj/structure/train_lever" = "rail_steam",
		"/obj/structure/vehicleparts/movement/reversed" = "rail_steam",
		// --- ready_made (29) ---
		"/obj/item/clothing/head/custom/custom_beanie" = "ready_made",
		"/obj/item/clothing/head/custom/pimp_hat" = "ready_made",
		"/obj/item/clothing/head/flatcap1" = "ready_made",
		"/obj/item/clothing/head/flatcap2" = "ready_made",
		"/obj/item/clothing/head/flatcap3" = "ready_made",
		"/obj/item/clothing/shoes/punk" = "ready_made",
		"/obj/item/clothing/shoes/sneakers/courier" = "ready_made",
		"/obj/item/clothing/suit/hawaiian" = "ready_made",
		"/obj/item/clothing/suit/hawaiian/green" = "ready_made",
		"/obj/item/clothing/suit/hawaiian/orange" = "ready_made",
		"/obj/item/clothing/suit/hawaiian/purple" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/biker" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/biker/gator_jacket" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/biker/lizard_jacket" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/bomberjacketblack" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/german/civ" = "ready_made",
		"/obj/item/clothing/suit/storage/coat/ww2/moderncoat" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/black_suit" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/burgundy_suit" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/charcoal_suit" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/checkered_suit" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/navy_suit" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/punk" = "ready_made",
		"/obj/item/clothing/suit/storage/jacket/really_black_suit" = "ready_made",
		"/obj/item/clothing/under/customuniform" = "ready_made",
		"/obj/item/clothing/under/customuniform/baggy" = "ready_made",
		"/obj/item/clothing/under/customuniform/short" = "ready_made",
		"/obj/item/clothing/under/punk" = "ready_made",
		// --- regalia (21) ---
		"/obj/item/clothing/accessory/custom/armband" = "regalia",
		"/obj/item/clothing/accessory/custom/cape" = "regalia",
		"/obj/item/clothing/accessory/custom/sash" = "regalia",
		"/obj/item/clothing/accessory/custom/tabard" = "regalia",
		"/obj/item/clothing/accessory/medal/bronze" = "regalia",
		"/obj/item/clothing/accessory/medal/gold" = "regalia",
		"/obj/item/clothing/accessory/medal/silver" = "regalia",
		"/obj/item/clothing/head/deshret" = "regalia",
		"/obj/item/clothing/head/hedjet" = "regalia",
		"/obj/item/clothing/head/helmet/gold_crown" = "regalia",
		"/obj/item/clothing/head/helmet/silver_crown" = "regalia",
		"/obj/item/clothing/head/laurelcrown" = "regalia",
		"/obj/item/clothing/head/laurelcrown/gold" = "regalia",
		"/obj/item/clothing/head/leaves/crown" = "regalia",
		"/obj/item/clothing/head/pschent" = "regalia",
		"/obj/item/clothing/suit/storage/jacket/regal" = "regalia",
		"/obj/item/flagmaker" = "regalia",
		"/obj/item/weapon/goldsceptre" = "regalia",
		"/obj/structure/banner/faction/banner_a" = "regalia",
		"/obj/structure/banner/faction/banner_b" = "regalia",
		"/obj/structure/flag/pole" = "regalia",
		// --- reinforced_concrete (11) ---
		"/obj/covers/concretefloor" = "reinforced_concrete",
		"/obj/covers/steelplating" = "reinforced_concrete",
		"/obj/covers/steelplating/white" = "reinforced_concrete",
		"/obj/covers/stone_wall/roman/modern" = "reinforced_concrete",
		"/obj/item/weapon/roofbuilder/concrete" = "reinforced_concrete",
		"/obj/structure/gate/blast" = "reinforced_concrete",
		"/obj/structure/gatecontrol/blastcontrol" = "reinforced_concrete",
		"/obj/structure/grille/chainlinkfence" = "reinforced_concrete",
		"/obj/structure/grille/metalsheetfence" = "reinforced_concrete",
		"/obj/structure/mine_support/stone/concrete" = "reinforced_concrete",
		"/obj/structure/window_frame/metal" = "reinforced_concrete",
		// --- resource_processing (9) ---
		"/obj/structure/compost" = "resource_processing",
		"/obj/structure/converter/retting_trough" = "resource_processing",
		"/obj/structure/flax_comb" = "resource_processing",
		"/obj/structure/reagent_dispensers/dew_collector" = "basic_agriculture",
		"/obj/structure/converter/tanning" = "resource_processing",
		"/obj/structure/dehydrator" = "resource_processing",
		"/obj/structure/distillery" = "resource_processing",
		"/obj/structure/mill" = "resource_processing",
		"/obj/structure/repair/grindstone" = "resource_processing",
		"/obj/structure/salting_container" = "resource_processing",
		"/obj/structure/sawmill" = "resource_processing",
		// --- rifling (6) ---
		"/obj/item/ammo_magazine/emptyclip" = "rifling",
		"/obj/item/ammo_magazine/emptymagazine/pistol" = "rifling",
		"/obj/item/ammo_magazine/emptymagazine/pistol/a45" = "rifling",
		"/obj/item/ammo_magazine/emptyspeedloader" = "rifling",
		"/obj/item/stack/ammopart/casing/pistol" = "rifling",
		"/obj/item/stack/ammopart/casing/rifle" = "rifling",
		// --- ritual_worship (30) ---
		"/obj/item/stack/material/bone" = "ritual_worship",
		"/obj/item/weapon/gongmallet" = "ritual_worship",
		"/obj/item/weapon/handbell" = "ritual_worship",
		"/obj/item/weapon/horn" = "ritual_worship",
		"/obj/structure/altar/iron" = "ritual_worship",
		"/obj/structure/altar/marble" = "ritual_worship",
		"/obj/structure/altar/obsidian" = "ritual_worship",
		"/obj/structure/altar/sandstone" = "ritual_worship",
		"/obj/structure/altar/stone" = "ritual_worship",
		"/obj/structure/altar/wood" = "ritual_worship",
		"/obj/structure/banner/religious" = "ritual_worship",
		"/obj/structure/bell_stand" = "ritual_worship",
		"/obj/structure/closet/coffin/sarcophagus" = "ritual_worship",
		"/obj/structure/closet/coffin/sarcophagus/gold" = "ritual_worship",
		"/obj/structure/gong" = "ritual_worship",
		"/obj/structure/religious/aztec_statue" = "ritual_worship",
		"/obj/structure/religious/gravestone" = "ritual_worship",
		"/obj/structure/religious/impaledskull" = "ritual_worship",
		"/obj/structure/religious/moai" = "ritual_worship",
		"/obj/structure/religious/moai/long" = "ritual_worship",
		"/obj/structure/religious/monument/megalith" = "ritual_worship",
		"/obj/structure/religious/monument/shaman/ape" = "ritual_worship",
		"/obj/structure/religious/olmec_head" = "ritual_worship",
		"/obj/structure/religious/tiki_statue" = "ritual_worship",
		"/obj/structure/religious/tiki_statue/small" = "ritual_worship",
		"/obj/structure/religious/totem" = "ritual_worship",
		"/obj/structure/religious/totem/sandstone" = "ritual_worship",
		"/obj/structure/religious/totem_pole" = "ritual_worship",
		"/obj/structure/religious/woodcross1" = "ritual_worship",
		"/obj/structure/religious/woodcross2" = "ritual_worship",
		// --- sanitation (9) ---
		"/obj/structure/mirror" = "sanitation",
		"/obj/structure/shower" = "sanitation",
		"/obj/structure/shower/bathtub/big/bronze" = "sanitation",
		"/obj/structure/shower/bathtub/big/copper" = "sanitation",
		"/obj/structure/shower/bathtub/big/stone" = "sanitation",
		"/obj/structure/shower/bathtub/big/wooden" = "sanitation",
		"/obj/structure/sink" = "sanitation",
		"/obj/structure/sink/kitchen" = "sanitation",
		"/obj/structure/toilet" = "sanitation",
		// --- siege_engines (3) ---
		"/obj/item/catapult_ball" = "siege_engines",
		"/obj/item/weapon/siegeladder" = "siege_engines",
		"/obj/structure/catapult" = "siege_engines",
		// --- steam_power (1) ---
		"/obj/structure/engine/external/steam" = "steam_power",
		// --- steel_blades (5) ---
		"/obj/item/clothing/accessory/storage/sheath" = "steel_blades",
		"/obj/item/clothing/accessory/storage/sheath/daisho" = "steel_blades",
		"/obj/item/clothing/accessory/storage/sheath/katana" = "steel_blades",
		"/obj/item/clothing/accessory/storage/sheath/longer" = "steel_blades",
		"/obj/item/clothing/accessory/storage/sheath/longsword" = "steel_blades",
		// --- steelmaking (2) ---
		"/obj/structure/anvil/steel" = "steelmaking",
		"/obj/structure/machinery/factory/coinsmelter" = "steelmaking",
		// --- stone_arms (28) ---
		"/obj/item/ammo_casing/chemdart/bone" = "stone_arms",
		"/obj/item/stack/arrowhead/sandstone" = "stone_arms",
		"/obj/item/stack/arrowhead/stone" = "stone_arms",
		"/obj/item/stack/arrowhead/vial" = "stone_arms",
		"/obj/item/weapon/clay/mold/arrowhead" = "stone_arms",
		"/obj/item/weapon/clay/mold/axehead" = "stone_arms",
		"/obj/item/weapon/clay/mold/knife" = "stone_arms",
		"/obj/item/weapon/clay/mold/pickaxe" = "stone_arms",
		"/obj/item/weapon/clay/mold/spearhead" = "stone_arms",
		"/obj/item/weapon/clay/mold/sword" = "stone_arms",
		"/obj/item/weapon/handcuffs/rope" = "stone_arms",
		"/obj/item/weapon/macuahuitl" = "stone_arms",
		"/obj/item/weapon/material/hatchet/bone_battleaxe" = "stone_arms",
		"/obj/item/weapon/material/kitchen/utensil/knife/bone" = "stone_arms",
		"/obj/item/weapon/material/kitchen/utensil/knife/wood" = "stone_arms",
		"/obj/item/weapon/material/pickaxe/bone" = "stone_arms",
		"/obj/item/weapon/material/pickaxe/stone" = "stone_arms",
		"/obj/item/weapon/material/pilum" = "stone_arms",
		"/obj/item/weapon/material/quarterstaff" = "stone_arms",
		"/obj/item/weapon/material/spear" = "stone_arms",
		"/obj/item/weapon/material/spear/dory" = "stone_arms",
		"/obj/item/weapon/material/spear/sarissa" = "stone_arms",
		"/obj/item/weapon/material/sword/training" = "stone_arms",
		"/obj/item/weapon/material/sword/training/bamboo" = "stone_arms",
		"/obj/item/weapon/material/thrown/tomahawk" = "stone_arms",
		"/obj/item/weapon/melee/classic_baton/club" = "stone_arms",
		"/obj/structure/anvil/stone" = "stone_arms",
		"/obj/structure/noose" = "stone_arms",
		// --- stone_masonry (44) ---
		"/obj/covers/cobblestone" = "stone_masonry",
		"/obj/covers/cobblestone/stairs" = "stone_masonry",
		"/obj/covers/roads/sandstone" = "stone_masonry",
		"/obj/covers/sandstone" = "stone_masonry",
		"/obj/covers/sandstone/brick" = "stone_masonry",
		"/obj/covers/sandstone/slab" = "stone_masonry",
		"/obj/covers/sandstone/slab/red" = "stone_masonry",
		"/obj/covers/sandstone/stairs" = "stone_masonry",
		"/obj/covers/sandstone/tile" = "stone_masonry",
		"/obj/covers/sandstone/tile/decorative" = "stone_masonry",
		"/obj/covers/sandstone/tile/decorative/red" = "stone_masonry",
		"/obj/covers/sandstone_smooth_wall/plain" = "stone_masonry",
		"/obj/covers/sandstone_wall/classic" = "stone_masonry",
		"/obj/covers/sandstone_wall/classic/archway" = "stone_masonry",
		"/obj/covers/sandstone_wall/classic/archway/red" = "stone_masonry",
		"/obj/covers/sandstone_wall/classic/red" = "stone_masonry",
		"/obj/covers/sandstone_wall/egyptian" = "stone_masonry",
		"/obj/covers/sandstone_wall/egyptian/archway" = "stone_masonry",
		"/obj/covers/slatefloor" = "stone_masonry",
		"/obj/covers/stone/slab/decorative" = "stone_masonry",
		"/obj/covers/stone_wall" = "stone_masonry",
		"/obj/covers/stone_wall/classic" = "stone_masonry",
		"/obj/covers/stone_wall/classic/archway" = "stone_masonry",
		"/obj/covers/stone_wall/fortress" = "stone_masonry",
		"/obj/covers/stone_wall/fortress/archway" = "stone_masonry",
		"/obj/covers/stone_wall/fortress/sandstone" = "stone_masonry",
		"/obj/covers/stone_wall/mayan" = "stone_masonry",
		"/obj/covers/stone_wall/roman" = "stone_masonry",
		"/obj/item/weapon/roofbuilder/mayan" = "stone_masonry",
		"/obj/item/weapon/roofbuilder/sandstone" = "stone_masonry",
		"/obj/structure/mine_support/stone" = "stone_masonry",
		"/obj/structure/mine_support/stone/aztec" = "stone_masonry",
		"/obj/structure/mine_support/stone/aztec/sandstone" = "stone_masonry",
		"/obj/structure/mine_support/stone/egyptian" = "stone_masonry",
		"/obj/structure/mine_support/stone/sandstone" = "stone_masonry",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/sandstone" = "stone_masonry",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/stone" = "stone_masonry",
		"/obj/structure/simple_door/key_door/anyone/roman" = "stone_masonry",
		"/obj/structure/window_frame/redsandstone" = "stone_masonry",
		"/obj/structure/window_frame/redsandstonefull" = "stone_masonry",
		"/obj/structure/window_frame/sandstone" = "stone_masonry",
		"/obj/structure/window_frame/sandstonefull" = "stone_masonry",
		"/obj/structure/window_frame/stone" = "stone_masonry",
		"/obj/structure/window_frame/stonefull" = "stone_masonry",
		// --- surgical_theory (4) ---
		"/obj/item/weapon/doctor_handbook" = "surgical_theory",
		"/obj/item/weapon/surgery/surgicaldrill" = "surgical_theory",
		"/obj/structure/bed/chair/wheelchair" = "surgical_theory",
		"/obj/structure/iv_drip" = "surgical_theory",
		// --- synthetics (22) ---
		"/obj/item/clothing/glasses/univisorcyan" = "synthetics",
		"/obj/item/clothing/glasses/univisorflashy" = "synthetics",
		"/obj/item/clothing/glasses/univisorgreen" = "synthetics",
		"/obj/item/clothing/glasses/univisorred" = "synthetics",
		"/obj/item/clothing/glasses/univisorwhite" = "synthetics",
		"/obj/item/clothing/glasses/univisoryellow" = "synthetics",
		"/obj/item/clothing/mask/bat" = "synthetics",
		"/obj/item/clothing/mask/bear" = "synthetics",
		"/obj/item/clothing/mask/bee" = "synthetics",
		"/obj/item/clothing/mask/cow" = "synthetics",
		"/obj/item/clothing/mask/frog" = "synthetics",
		"/obj/item/clothing/mask/gorilla" = "synthetics",
		"/obj/item/clothing/mask/jackal" = "synthetics",
		"/obj/item/clothing/mask/joy" = "synthetics",
		"/obj/item/clothing/mask/owl" = "synthetics",
		"/obj/item/clothing/mask/pig" = "synthetics",
		"/obj/item/clothing/mask/rat" = "synthetics",
		"/obj/item/clothing/mask/raven" = "synthetics",
		"/obj/item/clothing/suit/gorillasuit" = "synthetics",
		"/obj/item/clothing/suit/storage/coat/oldyjacket" = "synthetics",
		"/obj/item/weapon/storage/bag/plasticbag" = "synthetics",
		"/obj/structure/bakelizer" = "synthetics",
		// --- tailoring (57) ---
		"/obj/item/clothing/accessory/ruffle/neck" = "tailoring",
		"/obj/item/clothing/head/artisan" = "tailoring",
		"/obj/item/clothing/head/cavalier" = "tailoring",
		"/obj/item/clothing/head/custom/customnoblehat" = "tailoring",
		"/obj/item/clothing/head/custom/hijab" = "tailoring",
		"/obj/item/clothing/head/custom/kippa" = "tailoring",
		"/obj/item/clothing/head/custom/taqiyah" = "tailoring",
		"/obj/item/clothing/head/custom_hennin" = "tailoring",
		"/obj/item/clothing/head/custom_keffiyeh" = "tailoring",
		"/obj/item/clothing/head/gat" = "tailoring",
		"/obj/item/clothing/head/hooded_cape" = "tailoring",
		"/obj/item/clothing/head/phrigian_hat" = "tailoring",
		"/obj/item/clothing/head/phrigian_hat/blue" = "tailoring",
		"/obj/item/clothing/head/phrigian_hat/doge" = "tailoring",
		"/obj/item/clothing/head/phrigian_hat/red" = "tailoring",
		"/obj/item/clothing/head/plaguedoctor" = "tailoring",
		"/obj/item/clothing/head/turban" = "tailoring",
		"/obj/item/clothing/head/turban/imam" = "tailoring",
		"/obj/item/clothing/head/turban/sultan" = "tailoring",
		"/obj/item/clothing/mask/plaguedoctor" = "tailoring",
		"/obj/item/clothing/mask/shemagh" = "tailoring",
		"/obj/item/clothing/mask/wooden/african" = "tailoring",
		"/obj/item/clothing/shoes/medieval" = "tailoring",
		"/obj/item/clothing/shoes/medieval/arab" = "tailoring",
		"/obj/item/clothing/shoes/medieval/emirate" = "tailoring",
		"/obj/item/clothing/suit/storage/coat/monk_robes" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/custom/haori_jacket" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/custom/poncho" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/customcolonial" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/customcolonialcoat" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/piratejacket2" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/piratejacket5" = "tailoring",
		"/obj/item/clothing/suit/storage/jacket/plaguedoctor" = "tailoring",
		"/obj/item/clothing/under/artisan" = "tailoring",
		"/obj/item/clothing/under/artisan/dark" = "tailoring",
		"/obj/item/clothing/under/artisan/light" = "tailoring",
		"/obj/item/clothing/under/civ1" = "tailoring",
		"/obj/item/clothing/under/conquistador" = "tailoring",
		"/obj/item/clothing/under/custom/arabictunic" = "tailoring",
		"/obj/item/clothing/under/customren" = "tailoring",
		"/obj/item/clothing/under/customuniform/colonial/short" = "tailoring",
		"/obj/item/clothing/under/haori" = "tailoring",
		"/obj/item/clothing/under/haori/blue" = "tailoring",
		"/obj/item/clothing/under/haori/red" = "tailoring",
		"/obj/item/clothing/under/landschneckt" = "tailoring",
		"/obj/item/clothing/under/landschneckt/blue" = "tailoring",
		"/obj/item/clothing/under/landschneckt/red" = "tailoring",
		"/obj/item/clothing/under/medieval/arab1" = "tailoring",
		"/obj/item/clothing/under/medieval/arab2" = "tailoring",
		"/obj/item/clothing/under/medieval/beggar_clothing" = "tailoring",
		"/obj/item/clothing/under/medieval/emirate" = "tailoring",
		"/obj/item/clothing/under/pirate1" = "tailoring",
		"/obj/item/clothing/under/pirate2" = "tailoring",
		"/obj/item/clothing/under/pirate3" = "tailoring",
		"/obj/item/clothing/under/renaissance" = "tailoring",
		"/obj/item/clothing/under/renaissance/doge" = "tailoring",
		"/obj/item/clothing/under/renaissance_pontifical" = "tailoring",
		// --- textile_mills (67) ---
		"/obj/item/clothing/glasses/pilot" = "textile_mills",
		"/obj/item/clothing/gloves/motorist" = "textile_mills",
		"/obj/item/clothing/head/custom/fieldcap" = "textile_mills",
		"/obj/item/clothing/head/custom_off_cap" = "textile_mills",
		"/obj/item/clothing/head/ten_gallon" = "textile_mills",
		"/obj/item/clothing/head/top_hat" = "textile_mills",
		"/obj/item/clothing/head/traffic_police" = "textile_mills",
		"/obj/item/clothing/mask/balaclava" = "textile_mills",
		"/obj/item/clothing/shoes/gator_laceup" = "textile_mills",
		"/obj/item/clothing/shoes/laceup" = "textile_mills",
		"/obj/item/clothing/shoes/laceup/brown" = "textile_mills",
		"/obj/item/clothing/shoes/leather" = "textile_mills",
		"/obj/item/clothing/shoes/lizard_laceup" = "textile_mills",
		"/obj/item/clothing/shoes/workboots" = "textile_mills",
		"/obj/item/clothing/suit/pimpcoat" = "textile_mills",
		"/obj/item/clothing/suit/storage/closechest_apron_f" = "textile_mills",
		"/obj/item/clothing/suit/storage/coat/victorian_peacoat" = "textile_mills",
		"/obj/item/clothing/suit/storage/coat/ww2/servicejacket" = "textile_mills",
		"/obj/item/clothing/suit/storage/jacket/motorist" = "textile_mills",
		"/obj/item/clothing/suit/storage/jacket/texan" = "textile_mills",
		"/obj/item/clothing/suit/storage/jacket/vict_tailcoat" = "textile_mills",
		"/obj/item/clothing/suit/storage/openchest_apron_f" = "textile_mills",
		"/obj/item/clothing/under/cheongsam" = "textile_mills",
		"/obj/item/clothing/under/constable" = "textile_mills",
		"/obj/item/clothing/under/customuniform_modern" = "textile_mills",
		"/obj/item/clothing/under/customvicuniform" = "textile_mills",
		"/obj/item/clothing/under/debutante/blue" = "textile_mills",
		"/obj/item/clothing/under/debutante/orange" = "textile_mills",
		"/obj/item/clothing/under/debutante/purple" = "textile_mills",
		"/obj/item/clothing/under/debutante/red" = "textile_mills",
		"/obj/item/clothing/under/debutante/yellow" = "textile_mills",
		"/obj/item/clothing/under/farmer_outfit" = "textile_mills",
		"/obj/item/clothing/under/gatorpants" = "textile_mills",
		"/obj/item/clothing/under/industrial4" = "textile_mills",
		"/obj/item/clothing/under/industrial5" = "textile_mills",
		"/obj/item/clothing/under/lizardpants" = "textile_mills",
		"/obj/item/clothing/under/mechanic_outfit" = "textile_mills",
		"/obj/item/clothing/under/modern1" = "textile_mills",
		"/obj/item/clothing/under/modern2" = "textile_mills",
		"/obj/item/clothing/under/modern3" = "textile_mills",
		"/obj/item/clothing/under/modern4" = "textile_mills",
		"/obj/item/clothing/under/motorist" = "textile_mills",
		"/obj/item/clothing/under/nightingale" = "textile_mills",
		"/obj/item/clothing/under/saloondress" = "textile_mills",
		"/obj/item/clothing/under/sundress" = "textile_mills",
		"/obj/item/clothing/under/sundress/blue" = "textile_mills",
		"/obj/item/clothing/under/sundress/orange" = "textile_mills",
		"/obj/item/clothing/under/sundress/purple" = "textile_mills",
		"/obj/item/clothing/under/sundress/red" = "textile_mills",
		"/obj/item/clothing/under/texan" = "textile_mills",
		"/obj/item/clothing/under/tradwife" = "textile_mills",
		"/obj/item/clothing/under/tradwife/orange" = "textile_mills",
		"/obj/item/clothing/under/tradwife/purple" = "textile_mills",
		"/obj/item/clothing/under/tradwife/red" = "textile_mills",
		"/obj/item/clothing/under/tradwife/yellow" = "textile_mills",
		"/obj/item/clothing/under/traffic_police" = "textile_mills",
		"/obj/item/clothing/under/victorian_dress" = "textile_mills",
		"/obj/item/clothing/under/victorian_prim" = "textile_mills",
		"/obj/item/clothing/under/victorian_vest" = "textile_mills",
		"/obj/item/clothing/under/victorian_vest/redshirt" = "textile_mills",
		"/obj/item/clothing/under/victorian_vest/redvest" = "textile_mills",
		"/obj/item/clothing/under/waistcoat" = "textile_mills",
		"/obj/item/clothing/under/wedding" = "textile_mills",
		"/obj/item/weapon/storage/backpack/duffel" = "textile_mills",
		"/obj/item/weapon/storage/backpack/satchel" = "textile_mills",
		"/obj/item/weapon/storage/backpack/satchel/gator_satchel" = "textile_mills",
		"/obj/item/weapon/storage/backpack/satchel/lizard_satchel" = "textile_mills",
		// --- trench_warfare (7) ---
		"/obj/item/clothing/accessory/storage/webbing/green_webbing" = "trench_warfare",
		"/obj/item/clothing/accessory/storage/webbing/khaki_webbing" = "trench_warfare",
		"/obj/item/clothing/accessory/storage/webbing/light" = "trench_warfare",
		"/obj/item/clothing/mask/gas/british" = "trench_warfare",
		"/obj/item/clothing/mask/gas/german" = "trench_warfare",
		"/obj/item/clothing/suit/b3" = "trench_warfare",
		"/obj/item/weapon/barrier/sandbag/empty" = "trench_warfare",
		// --- utilities (7) ---
		"/obj/item/lightbulb" = "utilities",
		"/obj/item/lightbulb/tube" = "utilities",
		"/obj/item/weapon/telephone" = "utilities",
		"/obj/structure/lamp/lamp_big" = "utilities",
		"/obj/structure/lamp/lamp_small" = "utilities",
		"/obj/structure/lamp/lamppost_small" = "utilities",
		"/obj/structure/phoneline" = "utilities",
		// --- wagons_ships (24) ---
		"/obj/item/sail" = "wagons_ships",
		"/obj/item/sail/wool" = "wagons_ships",
		"/obj/item/vehicleparts/frame/boat" = "wagons_ships",
		"/obj/item/weapon/covers/ship" = "wagons_ships",
		"/obj/structure/barricade/ship/aport0" = "wagons_ships",
		"/obj/structure/barricade/ship/aport0/north" = "wagons_ships",
		"/obj/structure/barricade/ship/blue/b9" = "wagons_ships",
		"/obj/structure/barricade/ship/wall2" = "wagons_ships",
		"/obj/structure/barricade/ship/wall2/doorway" = "wagons_ships",
		"/obj/structure/barricade/ship/wood/a2" = "wagons_ships",
		"/obj/structure/barricade/ship/wood/a6" = "wagons_ships",
		"/obj/structure/barricade/ship/wood/a7" = "wagons_ships",
		"/obj/structure/closet/crate/cart/bronze" = "wagons_ships",
		"/obj/structure/simple_door/key_door/anyone/wood/ship" = "wagons_ships",
		"/obj/structure/vehicleparts/axis/ship" = "wagons_ships",
		"/obj/structure/vehicleparts/axis/ship/heavy" = "wagons_ships",
		"/obj/structure/vehicleparts/frame/ship" = "wagons_ships",
		"/obj/structure/vehicleparts/frame/ship/steel" = "wagons_ships",
		"/obj/structure/vehicleparts/movement/sail" = "wagons_ships",
		"/obj/structure/vehicleparts/shipwheel" = "wagons_ships",
		"/obj/structure/window/barrier/ship/blue/bport0/south" = "wagons_ships",
		"/obj/structure/window/barrier/ship/blue/bport3/south" = "wagons_ships",
		"/obj/structure/window/barrier/ship/wood/port0/north" = "wagons_ships",
		"/obj/structure/window/barrier/ship/wood/port2/north" = "wagons_ships",
		// --- watermills (2) ---
		"/obj/structure/sawmill/large" = "watermills",
		"/obj/structure/sawmill/powered" = "watermills",
		// --- weaving (83) ---
		"/obj/item/clothing/accessory/armband/armbangle" = "weaving",
		"/obj/item/clothing/accessory/armband/armbangle/bronze" = "weaving",
		"/obj/item/clothing/accessory/armband/armbangle/copper" = "weaving",
		"/obj/item/clothing/accessory/armband/armbangle/gold" = "weaving",
		"/obj/item/clothing/accessory/armband/armbangle/silver" = "weaving",
		"/obj/item/clothing/accessory/armband/indian2" = "weaving",
		"/obj/item/clothing/accessory/armband/indian2/pygmy" = "weaving",
		"/obj/item/clothing/accessory/armband/talisman" = "weaving",
		"/obj/item/clothing/accessory/wearable_sign" = "weaving",
		"/obj/item/clothing/glasses/eyepatch" = "weaving",
		"/obj/item/clothing/glasses/sunglasses/blindfold" = "weaving",
		"/obj/item/clothing/gloves/thick/leather" = "weaving",
		"/obj/item/clothing/gloves/thick/leather/black" = "weaving",
		"/obj/item/clothing/gloves/thick/leather/brown" = "weaving",
		"/obj/item/clothing/gloves/thick/leather/grey" = "weaving",
		"/obj/item/clothing/gloves/thick/leather/orc" = "weaving",
		"/obj/item/clothing/gloves/thick/leather/pink" = "weaving",
		"/obj/item/clothing/gloves/thick/leather/white" = "weaving",
		"/obj/item/clothing/head/bearpelt/black" = "weaving",
		"/obj/item/clothing/head/bearpelt/brown" = "weaving",
		"/obj/item/clothing/head/bearpelt/white" = "weaving",
		"/obj/item/clothing/head/bisonpelt" = "weaving",
		"/obj/item/clothing/head/chief_hat" = "weaving",
		"/obj/item/clothing/head/custom/customhood" = "weaving",
		"/obj/item/clothing/head/foxpelt" = "weaving",
		"/obj/item/clothing/head/foxpelt/white" = "weaving",
		"/obj/item/clothing/head/gatorpelt" = "weaving",
		"/obj/item/clothing/head/goatpelt" = "weaving",
		"/obj/item/clothing/head/leaves" = "weaving",
		"/obj/item/clothing/head/lionpelt" = "weaving",
		"/obj/item/clothing/head/lizardpelt" = "weaving",
		"/obj/item/clothing/head/pantherpelt" = "weaving",
		"/obj/item/clothing/head/sheeppelt" = "weaving",
		"/obj/item/clothing/head/strawhat" = "weaving",
		"/obj/item/clothing/head/wolfpelt" = "weaving",
		"/obj/item/clothing/head/wolfpelt/white" = "weaving",
		"/obj/item/clothing/head/zulu_umghele" = "weaving",
		"/obj/item/clothing/mask/chitinmask" = "weaving",
		"/obj/item/clothing/mask/skullmask" = "weaving",
		"/obj/item/clothing/mask/wooden" = "weaving",
		"/obj/item/clothing/mask/wooden/expressive" = "weaving",
		"/obj/item/clothing/shoes/fur" = "weaving",
		"/obj/item/clothing/shoes/fur/black" = "weaving",
		"/obj/item/clothing/shoes/fur/brown" = "weaving",
		"/obj/item/clothing/shoes/fur/grey" = "weaving",
		"/obj/item/clothing/shoes/fur/orc" = "weaving",
		"/obj/item/clothing/shoes/fur/pink" = "weaving",
		"/obj/item/clothing/shoes/fur/white" = "weaving",
		"/obj/item/clothing/shoes/sandal" = "weaving",
		"/obj/item/clothing/suit/prehistoricfurcoat" = "weaving",
		"/obj/item/clothing/suit/prehistoricfurcoat/black" = "weaving",
		"/obj/item/clothing/suit/prehistoricfurcoat/brown" = "weaving",
		"/obj/item/clothing/suit/prehistoricfurcoat/grey" = "weaving",
		"/obj/item/clothing/suit/prehistoricfurcoat/white" = "weaving",
		"/obj/item/clothing/suit/zulu_mbata" = "weaving",
		"/obj/item/clothing/under/aztec_loincloth" = "weaving",
		"/obj/item/clothing/under/custom/roman" = "weaving",
		"/obj/item/clothing/under/custom/spartan" = "weaving",
		"/obj/item/clothing/under/customtribalrobe" = "weaving",
		"/obj/item/clothing/under/indian1" = "weaving",
		"/obj/item/clothing/under/indian2" = "weaving",
		"/obj/item/clothing/under/indian3" = "weaving",
		"/obj/item/clothing/under/indianchief" = "weaving",
		"/obj/item/clothing/under/indianchief/pygmy" = "weaving",
		"/obj/item/clothing/under/indianhuge" = "weaving",
		"/obj/item/clothing/under/indianshaman" = "weaving",
		"/obj/item/clothing/under/indianshaman/pygmy" = "weaving",
		"/obj/item/clothing/under/leaves_skirt" = "weaving",
		"/obj/item/clothing/under/leaves_skirt/au_naturel" = "weaving",
		"/obj/item/clothing/under/leaves_skirt/au_naturel/eve" = "weaving",
		"/obj/item/clothing/under/leaves_skirt/long" = "weaving",
		"/obj/item/clothing/under/loincotton" = "weaving",
		"/obj/item/clothing/under/loinleather" = "weaving",
		"/obj/item/clothing/under/pygmyhuge" = "weaving",
		"/obj/item/clothing/under/pygmyshaman" = "weaving",
		"/obj/item/clothing/under/zulu_slene" = "weaving",
		"/obj/item/weapon/bedroll" = "weaving",
		"/obj/item/weapon/reagent_containers/glass/rag" = "weaving",
		"/obj/item/weapon/tent" = "weaving",
		"/obj/structure/curtain" = "weaving",
		"/obj/structure/curtain/leather" = "weaving",
		"/obj/structure/loom" = "weaving",
		"/obj/structure/religious/tribalmask" = "weaving",
		// --- workshops (24) ---
		"/obj/item/flashlight/lantern/bronze" = "workshops",
		"/obj/item/flashlight/lantern/copper" = "workshops",
		"/obj/item/weapon/storage/belt/keychain" = "workshops",
		"/obj/item/weapon/storage/toolbox" = "workshops",
		"/obj/item/weapon/storage/toolbox/blue" = "workshops",
		"/obj/item/weapon/storage/toolbox/yellow" = "workshops",
		"/obj/structure/closet/crate/footlocker" = "workshops",
		"/obj/structure/closet/crate/lead" = "workshops",
		"/obj/structure/grille/fence/steel_picket" = "workshops",
		"/obj/structure/grille/ironfence" = "workshops",
		"/obj/structure/research_forge" = "workshops",
		"/obj/structure/simple_door/key_door/anyone" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/bronze" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/copper" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/gold" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/iron" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/lead" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/silver" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/steel" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/doubledoor/tin" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/singledoor/housedoor" = "workshops",
		"/obj/structure/simple_door/key_door/anyone/singledoor/privacy" = "workshops",
		"/obj/structure/simple_door/key_door/custom" = "workshops",
		"/obj/structure/simple_door/key_door/faction_door" = "workshops",
	)

	validate_research_tree()
	log_startup_progress("	Built research tree: [research_nodes.len] nodes, [recipe_node_requirements.len] gated recipes.")

// Sanity pass: every prereq id must resolve to a real node. Catches typos in
// the tree definition at startup instead of silently locking nodes forever.
/proc/validate_research_tree()
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		for (var/req in N.prereqs)
			if (!research_nodes[req])
				log_debug("research_tree: node '[node_id]' has unknown prereq '[req]'")
