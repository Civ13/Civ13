// ============================================================
// Research Tree - practice and gathering for early nodes (Val, 2026-11-12)
// ------------------------------------------------------------
// "Players don't want an idle simulator." Field work (field_work.dm) only
// covered era tier 5 and up, so most of a book-research world was spent
// standing at a lit bench while a timer ran. This adds field work for the
// earlier tiers:
// - Practice: making things a node builds on writes a share of that node.
//   Smithing tools you know (Basic Toolmaking) advances Iron Tools, and so on.
//   Every early node with prerequisites gets one practice experiment per
//   prerequisite, generated from the tree, so new nodes are covered too.
// - Deeds: era tiers 0 to 4 have hand-written deeds per subject instead of a
//   counter (subject_deeds below).
// - Gathering: a few first nodes with nothing before them advance by
//   foraging or butchering.
// Credit still happens at a bench, once per book, exactly like late field
// work. Bench study alone still finishes every node.
// ============================================================

// Practice experiments are generated for nodes below this era tier. Late
// nodes keep their hand-picked field work.
#define PRACTICE_BELOW_TIER 5
// How much of a node practice can write in total, split between its
// prerequisites.
#define PRACTICE_TOTAL_SHARE 0.5
#define PRACTICE_MIN_ITEMS 4
#define PRACTICE_MAX_ITEMS 20

var/global/practice_experiments_built = FALSE

// Hand-written deeds (Val, 2026-11-14): instead of "make N things taught by
// P", a subject listed here asks for particular pieces of work that point at
// what it is about. Every deed uses only things its groundwork teaches. A
// subject without an entry keeps its generated practice.
// node id => list of deeds, each list(key, list(result paths), amount, share, what to do).
// A result path also covers its subtypes.
var/global/list/subject_deeds = list(
	"bronze_working" = list(
		list("molds", list("/obj/item/weapon/clay/mold/shovel"), 2, 0.2, "Shape 2 unfired shovel molds from clay"),
		list("hammer", list("/obj/item/weapon/hammer"), 1, 0.15, "Make a hammer"),
		list("chisel", list("/obj/item/weapon/chisel"), 1, 0.15, "Make a chisel")),
	"early_cells" = list(
		list("kiln", list("/obj/structure/furnace/kiln"), 1, 0.3, "Build a clay kiln"),
		list("molds", list("/obj/item/weapon/clay/mold"), 3, 0.2, "Shape 3 unfired clay molds")),
	"stone_masonry" = list(
		list("walls", list("/obj/covers/wood_wall"), 4, 0.2, "Raise 4 wooden walls"),
		list("supports", list("/obj/structure/roof_support"), 2, 0.15, "Set up 2 roof supports"),
		list("frames", list("/obj/structure/wallframe"), 2, 0.15, "Build 2 wall frames")),
	"regalia" = list(
		list("ornaments", list("/obj/item/clothing/accessory/armband"), 2, 0.25, "Make 2 arm ornaments, bangles or talismans"),
		list("mask", list("/obj/item/clothing/mask/wooden"), 1, 0.25, "Carve a wearable wood mask")),
	"cooperage" = list(
		list("handles", list("/obj/item/weapon/material/handle"), 2, 0.2, "Make 2 tool handles"),
		list("dowels", list("/obj/item/stack/wooden_dowels"), 1, 0.15, "Whittle a set of wooden dowels"),
		list("bench", list("/obj/structure/component_workbench"), 1, 0.15, "Build a workbench")),
	"resource_processing" = list(
		list("tanning", list("/obj/structure/converter/tanning"), 1, 0.2, "Build a tanning rack"),
		list("dehydrator", list("/obj/structure/dehydrator"), 1, 0.15, "Build a dehydrator"),
		list("net", list("/obj/item/weapon/fishing/net"), 1, 0.15, "Make a fishing net")),
	"furriery" = list(
		list("pelts", list("/obj/item/clothing/head/bearpelt", "/obj/item/clothing/head/bisonpelt", "/obj/item/clothing/head/foxpelt", "/obj/item/clothing/head/gatorpelt", "/obj/item/clothing/head/goatpelt", "/obj/item/clothing/head/lionpelt", "/obj/item/clothing/head/lizardpelt", "/obj/item/clothing/head/pantherpelt", "/obj/item/clothing/head/sheeppelt", "/obj/item/clothing/head/wolfpelt"), 2, 0.2, "Make 2 pelt headcovers"),
		list("coat", list("/obj/item/clothing/suit/prehistoricfurcoat"), 1, 0.15, "Sew a pelt coat"),
		list("boots", list("/obj/item/clothing/shoes/fur"), 1, 0.15, "Make a pair of fur boots")),
	"bronze_weapons" = list(
		list("molds", list("/obj/item/weapon/clay/mold/sword", "/obj/item/weapon/clay/mold/spearhead", "/obj/item/weapon/clay/mold/axehead"), 2, 0.2, "Shape 2 unfired weapon molds: sword, spearhead or axehead"),
		list("kiln", list("/obj/structure/furnace/kiln"), 1, 0.15, "Build a clay kiln"),
		list("bench", list("/obj/structure/component_workbench/weapon"), 1, 0.15, "Build a weapon workbench")),
	"field_surgery" = list(
		list("bandages", list("/obj/item/stack/medical/bruise_pack/bint"), 3, 0.2, "Make bandages 3 times"),
		list("splints", list("/obj/item/stack/medical/splint"), 2, 0.15, "Make splints twice"),
		list("mortar", list("/obj/item/weapon/reagent_containers/glass/mortar"), 1, 0.15, "Make a mortar and pestle")),
	"classical_dress" = list(
		list("sandals", list("/obj/item/clothing/shoes/sandal"), 2, 0.2, "Make 2 pairs of sandals"),
		list("hat", list("/obj/item/clothing/head/strawhat"), 1, 0.15, "Make a straw hat"),
		list("robe", list("/obj/item/clothing/under/customtribalrobe", "/obj/item/clothing/under/aztec_loincloth", "/obj/item/clothing/under/indian1", "/obj/item/clothing/under/indian2", "/obj/item/clothing/under/indian3"), 1, 0.15, "Sew a tribal robe or loincloth")),
	// Era tier 2 (chat feedback, 2026-11-17).
	"apothecary" = list(
		list("table", list("/obj/structure/table/wood/anatomy"), 1, 0.2, "Build an anatomy table"),
		list("rack", list("/obj/structure/drying_rack"), 1, 0.15, "Build a drying rack"),
		list("splints", list("/obj/item/stack/medical/splint/wooden"), 2, 0.15, "Make wooden splints twice")),
	"brickmaking" = list(
		list("kiln", list("/obj/structure/furnace/lime_kiln"), 1, 0.2, "Build a lime kiln"),
		list("saw", list("/obj/structure/workshop_machine/masons_saw"), 1, 0.15, "Build a mason's saw"),
		list("walls", list("/obj/covers/stone_wall"), 3, 0.15, "Raise 3 rough stone walls")),
	"crossbows" = list(
		list("bench", list("/obj/structure/component_workbench/fletching"), 1, 0.2, "Build a fletcher's bench"),
		list("bow", list("/obj/item/weapon/gun/projectile/bow/shortbow"), 1, 0.15, "Make a shortbow"),
		list("arrows", list("/obj/item/ammo_casing/arrow"), 4, 0.15, "Make arrows or arrow shafts 4 times")),
	"fine_furniture" = list(
		list("desk", list("/obj/structure/writing_desk"), 1, 0.2, "Build a writing desk"),
		list("chairs", list("/obj/structure/bed/chair/wood"), 2, 0.15, "Build 2 wooden chairs"),
		list("chest", list("/obj/structure/storage_container/log_chest"), 1, 0.15, "Build a hewn log chest")),
	"glassworking" = list(
		list("wheel", list("/obj/structure/workshop_machine/potters_wheel"), 1, 0.2, "Build a potter's wheel"),
		list("cups", list("/obj/item/weapon/clay/claycup"), 3, 0.15, "Shape 3 unfired clay cups"),
		list("jugs", list("/obj/item/weapon/clay/clayjug"), 2, 0.15, "Shape 2 unfired clay jugs")),
	"iron_smithing" = list(
		list("bellows", list("/obj/structure/workshop_machine/bellows"), 1, 0.2, "Build a bellows"),
		list("bench", list("/obj/structure/component_workbench/toolsmith"), 1, 0.15, "Build a toolsmith's bench"),
		list("sluice", list("/obj/structure/placer_washer/sluice"), 1, 0.15, "Build a sluice box")),
	"iron_tools" = list(
		list("anvil", list("/obj/structure/anvil"), 1, 0.2, "Build an iron anvil"),
		list("tub", list("/obj/structure/quench_tub"), 1, 0.15, "Build a quench tub"),
		list("heads", list("/obj/item/weapon/material/part/axehead/hatchet"), 2, 0.15, "Forge 2 hatchet heads at the anvil")),
	"irrigation" = list(
		list("shaduf", list("/obj/structure/water_lift/shaduf"), 1, 0.2, "Build a shaduf"),
		list("gauge", list("/obj/structure/river_gauge"), 1, 0.15, "Set up a river gauge"),
		list("hoe", list("/obj/item/weapon/plough/hoe"), 1, 0.15, "Make a hoe")),
	"japanese_swordsmithing" = list(
		list("tatara", list("/obj/structure/tatara"), 1, 0.2, "Build a tatara"),
		list("channel", list("/obj/structure/kanna_channel"), 1, 0.15, "Build a washing channel"),
		list("tanto", list("/obj/item/weapon/material/kitchen/utensil/knife/tanto"), 1, 0.15, "Forge a tanto")),
	"mail_plate" = list(
		list("bench", list("/obj/structure/repair/workbench"), 1, 0.2, "Build an armor repair workbench"),
		list("armor", list("/obj/item/clothing/suit/armor/medieval/leather"), 1, 0.15, "Make a suit of leather armor"),
		list("boots", list("/obj/item/clothing/shoes/weather/hobnail_boots"), 1, 0.15, "Make a pair of hobnailed boots")),
	"monuments" = list(
		list("altar", list("/obj/structure/altar/stone"), 1, 0.2, "Build a stone altar"),
		list("totem", list("/obj/structure/religious/totem"), 1, 0.15, "Carve a stone totem"),
		list("cairn", list("/obj/structure/religious/cairn"), 1, 0.15, "Pile up a cairn")),
	"ore_dressing" = list(
		list("crusher", list("/obj/structure/stone_crusher"), 1, 0.2, "Build a stone crusher"),
		list("grindstone", list("/obj/structure/repair/grindstone"), 1, 0.15, "Build a grindstone"),
		list("mill", list("/obj/structure/mill"), 1, 0.15, "Build a mill")),
	"siege_engines" = list(
		list("shears", list("/obj/structure/workshop_machine/shear_legs"), 1, 0.2, "Raise a set of shear legs"),
		list("supports", list("/obj/structure/mine_support"), 2, 0.15, "Set up 2 mine supports"),
		list("sills", list("/obj/covers/wood_wall/log_build"), 3, 0.15, "Lay 3 log wall sills")),
	"steel_blades" = list(
		list("furnace", list("/obj/structure/furnace/blast_furnace"), 1, 0.2, "Build a blast furnace"),
		list("tub", list("/obj/structure/quench_tub"), 1, 0.15, "Build a quench tub"),
		list("sword", list("/obj/item/weapon/material/sword/gladius", "/obj/item/weapon/material/sword/khopesh"), 1, 0.15, "Make a gladius or a khopesh")),
	"tailoring" = list(
		list("pouches", list("/obj/item/clothing/accessory/storage/belt_pouch/cloth"), 2, 0.2, "Sew 2 cloth drawstring pouches"),
		list("bedroll", list("/obj/item/weapon/bedroll"), 1, 0.15, "Make a bedroll"),
		list("curtain", list("/obj/structure/curtain"), 1, 0.15, "Hang a curtain")),
	"tatara_smelting" = list(
		list("furnace", list("/obj/structure/furnace/blast_furnace"), 1, 0.2, "Build a blast furnace"),
		list("horseshoes", list("/obj/item/horseshoes"), 1, 0.15, "Forge a set of horseshoes"),
		list("wedge", list("/obj/item/door_wedge/iron"), 1, 0.15, "Forge an iron wedge")),
	"workshops" = list(
		list("bench", list("/obj/structure/component_workbench/toolsmith"), 1, 0.2, "Build a toolsmith's bench"),
		list("bellows", list("/obj/structure/workshop_machine/bellows"), 1, 0.15, "Build a bellows"),
		list("springs", list("/obj/item/machine_part/spring"), 2, 0.15, "Make 2 springs")),
	// Era tier 3 (chat feedback, 2026-11-17).
	"amalgamation" = list(
		list("rocker", list("/obj/structure/placer_washer/rocker"), 1, 0.2, "Build a rocker"),
		list("flask", list("/obj/item/weapon/reagent_containers/glass/mercury_flask"), 1, 0.15, "Make a mercury flask"),
		list("burner", list("/obj/item/weapon/laboratory_burner"), 1, 0.15, "Make a laboratory burner")),
	"cannon" = list(
		list("handcannon", list("/obj/item/weapon/gun/projectile/ancient/handcannon"), 1, 0.2, "Make a handcannon"),
		list("lance", list("/obj/item/weapon/gun/projectile/ancient/firelance"), 1, 0.15, "Make a fire lance"),
		list("shot", list("/obj/item/stack/ammopart/musketball"), 3, 0.15, "Cast musketball projectiles 3 times")),
	"fine_arts" = list(
		list("gong", list("/obj/structure/gong"), 1, 0.2, "Build a gong"),
		list("drum", list("/obj/item/stone_age_instrument/frame_drum"), 1, 0.15, "Make a frame drum"),
		list("flute", list("/obj/item/stone_age_instrument/bone_flute"), 1, 0.15, "Carve a bone flute")),
	"fine_garments" = list(
		list("clothing", list("/obj/item/clothing/under/artisan"), 1, 0.2, "Sew a set of artisan clothing"),
		list("shoes", list("/obj/item/clothing/shoes/medieval"), 1, 0.15, "Make a pair of leather shoes"),
		list("robes", list("/obj/item/clothing/suit/storage/coat/monk_robes"), 1, 0.15, "Sew monk robes")),
	"fortifications" = list(
		list("palisade", list("/obj/structure/grille/logfence"), 4, 0.2, "Raise 4 lengths of palisade"),
		list("walls", list("/obj/covers/stone_wall/fortress"), 3, 0.15, "Raise 3 fortress brick walls"),
		list("dummy", list("/obj/structure/practice_dummy"), 1, 0.15, "Set up a practice dummy or target")),
	"gunpowder" = list(
		list("pouches", list("/obj/item/weapon/reagent_containers/food/drinks/gunpowder"), 2, 0.2, "Make 2 gunpowder pouches"),
		list("lock", list("/obj/item/fitted_lock/warded"), 1, 0.15, "Make a warded lock"),
		list("shutters", list("/obj/structure/simple_door/key_door/anyone/window_shutters/iron"), 1, 0.15, "Fit a set of iron shutters")),
	"gunsmithing" = list(
		list("arquebus", list("/obj/item/weapon/gun/projectile/ancient/arquebus"), 1, 0.2, "Make an arquebus"),
		list("handcannon", list("/obj/item/weapon/gun/projectile/ancient/handcannon"), 1, 0.15, "Make a handcannon"),
		list("pouch", list("/obj/item/ammo_magazine/emptypouch"), 1, 0.15, "Make a bullet pouch")),
	"haberdashery" = list(
		list("hats", list("/obj/item/clothing/head/artisan", "/obj/item/clothing/head/cavalier", "/obj/item/clothing/head/phrigian_hat"), 2, 0.2, "Make 2 hats: artisan, cavalier or phrigian"),
		list("ruffle", list("/obj/item/clothing/accessory/ruffle/neck"), 1, 0.15, "Sew a neck ruffle"),
		list("poncho", list("/obj/item/clothing/suit/storage/jacket/custom/poncho"), 1, 0.15, "Sew a poncho")),
	"imperial_architecture" = list(
		list("bench", list("/obj/structure/workshop_machine/brick_bench"), 1, 0.2, "Build a brick mould bench"),
		list("walls", list("/obj/covers/stone_wall/brick"), 3, 0.15, "Raise 3 stone brick walls"),
		list("bricks", list("/obj/item/weapon/clay/advclaybricks"), 2, 0.15, "Shape unfired bricks twice")),
	"optics_instruments" = list(
		list("bench", list("/obj/structure/workshop_machine/glass_bench"), 1, 0.2, "Build a glassblowing bench"),
		list("hourglass", list("/obj/item/hourglass"), 1, 0.15, "Make an hourglass"),
		list("monocle", list("/obj/item/clothing/glasses/monocle"), 1, 0.15, "Make a monocle")),
	"paved_infrastructure" = list(
		list("cobbles", list("/obj/covers/cobblestone"), 4, 0.2, "Lay 4 cobblestone floors"),
		list("road", list("/obj/covers/roads/sandstone"), 2, 0.15, "Lay 2 stretches of sandstone road"),
		list("slate", list("/obj/covers/slatefloor"), 2, 0.15, "Lay 2 slate floors")),
	"printing_currency" = list(
		list("seal", list("/obj/item/weapon/stamp/faction_seal"), 1, 0.2, "Cut a seal matrix"),
		list("book", list("/obj/item/weapon/book"), 1, 0.15, "Bind a book"),
		list("paper", list("/obj/item/weapon/paper"), 5, 0.15, "Make sheets of paper 5 times")),
	"sanitation" = list(
		list("outhouse", list("/obj/structure/toilet/outhouse"), 1, 0.2, "Build an outhouse"),
		list("well", list("/obj/structure/sink/well"), 1, 0.15, "Build a well"),
		list("washstand", list("/obj/structure/washbasin/washstand"), 1, 0.15, "Build a washstand")),
	"surgical_theory" = list(
		list("book", list("/obj/item/weapon/book"), 1, 0.2, "Bind a book"),
		list("scalpel", list("/obj/item/weapon/surgery/scalpel"), 1, 0.15, "Make a scalpel"),
		list("saw", list("/obj/item/weapon/surgery/bone_saw"), 1, 0.15, "Make a bone saw")),
	"wagons_ships" = list(
		list("raft", list("/obj/structure/vehicle/raft"), 1, 0.2, "Build a raft"),
		list("cart", list("/obj/structure/closet/crate/cart"), 1, 0.15, "Build a cart"),
		list("carriage", list("/obj/structure/vehicle/carriage"), 1, 0.15, "Build a carriage")),
	"watermills" = list(
		list("mill", list("/obj/structure/mill"), 1, 0.2, "Build a mill"),
		list("sawmill", list("/obj/structure/sawmill"), 1, 0.15, "Build a primitive saw mill"),
		list("gin", list("/obj/structure/workshop_machine/mover/horse_gin"), 1, 0.15, "Build a horse gin")),
	// Era tier 4 (chat feedback, 2026-11-17).
	"advanced_agriculture" = list(
		list("plough", list("/obj/item/weapon/plough/iron"), 1, 0.2, "Make an iron plough"),
		list("sickle", list("/obj/item/weapon/material/kitchen/utensil/knife/sickle"), 1, 0.15, "Make a sickle"),
		list("basket", list("/obj/item/weapon/storage/produce_basket"), 1, 0.15, "Weave a produce basket")),
	"factories" = list(
		list("engine", list("/obj/structure/engine/external/steam"), 1, 0.2, "Build a steam engine"),
		list("lathe", list("/obj/structure/workshop_machine/lathe/pole"), 1, 0.15, "Build a pole lathe"),
		list("toolbox", list("/obj/item/weapon/storage/toolbox"), 1, 0.15, "Make a toolbox")),
	"field_artillery" = list(
		list("cannon", list("/obj/structure/cannon"), 1, 0.2, "Build a cannon"),
		list("balls", list("/obj/item/cannon_ball"), 3, 0.15, "Cast 3 cannon balls"),
		list("anvil", list("/obj/structure/anvil/steel"), 1, 0.15, "Build a steel anvil")),
	"galvanic_cells" = list(
		list("cells", list("/obj/structure/battery"), 2, 0.3, "Build 2 Baghdad-style jar cells"),
		list("dish", list("/obj/structure/gilding_dish"), 1, 0.2, "Build a gilding dish")),
	"industrial_milling" = list(
		list("press", list("/obj/structure/workshop_machine/amalgam_press"), 1, 0.2, "Build an amalgam press"),
		list("retort", list("/obj/structure/workshop_machine/mercury_retort"), 1, 0.15, "Build a mercury retort"),
		list("hammer", list("/obj/structure/workshop_machine/trip_hammer/steam"), 1, 0.15, "Build a steam hammer")),
	"machined_tools" = list(
		list("drafting", list("/obj/item/weapon/drafting_set"), 1, 0.2, "Make a drafting set"),
		list("saw", list("/obj/item/weapon/saw"), 1, 0.15, "Make a saw"),
		list("screwdriver", list("/obj/item/weapon/screwdriver"), 1, 0.15, "Make a screwdriver")),
	"manufactured_furniture" = list(
		list("bookcase", list("/obj/structure/bookcase"), 1, 0.2, "Build a bookcase"),
		list("clock", list("/obj/structure/TV/grandfather"), 1, 0.15, "Build a grandfather clock"),
		list("chairs", list("/obj/structure/bed/chair/wood/red"), 2, 0.15, "Build 2 padded chairs")),
	"rail_steam" = list(
		list("engine", list("/obj/structure/engine/external/steam"), 1, 0.2, "Build a steam engine"),
		list("depot", list("/obj/structure/berth/quay/depot"), 1, 0.15, "Build a freight depot"),
		list("crane", list("/obj/structure/workshop_machine/shear_legs/crane/steam"), 1, 0.15, "Build a steam crane")),
	"reinforced_concrete" = list(
		list("bricks", list("/obj/item/weapon/clay/advclaybricks/cement"), 2, 0.2, "Shape unfired cement bricks twice"),
		list("walls", list("/obj/covers/stone_wall/brick"), 3, 0.15, "Raise 3 stone brick walls"),
		list("door", list("/obj/structure/simple_door/key_door/anyone/fire_door"), 1, 0.15, "Build an iron-clad fire door")),
	"rifling" = list(
		list("arquebus", list("/obj/item/weapon/gun/projectile/ancient/arquebus"), 1, 0.2, "Make an arquebus"),
		list("bullets", list("/obj/item/stack/ammopart/bullet"), 3, 0.15, "Make iron bullets 3 times"),
		list("anvil", list("/obj/structure/anvil/steel"), 1, 0.15, "Build a steel anvil")),
	"steam_power" = list(
		list("wheel", list("/obj/structure/workshop_machine/mover/mill_wheel"), 1, 0.2, "Build a mill wheel"),
		list("hammer", list("/obj/structure/workshop_machine/trip_hammer"), 1, 0.15, "Build a trip hammer"),
		list("windmill", list("/obj/structure/workshop_machine/mover/windmill"), 1, 0.15, "Build a windmill")),
	"steelmaking" = list(
		list("furnace", list("/obj/structure/furnace/blast_furnace"), 1, 0.2, "Build a blast furnace"),
		list("anvil", list("/obj/structure/anvil"), 1, 0.15, "Build an iron anvil"),
		list("tub", list("/obj/structure/quench_tub"), 1, 0.15, "Build a quench tub")),
	"textile_mills" = list(
		list("engine", list("/obj/structure/engine/external/steam"), 1, 0.2, "Build a steam engine"),
		list("outfit", list("/obj/item/clothing/under/customren"), 1, 0.15, "Sew a renaissance outfit"),
		list("turbans", list("/obj/item/clothing/head/turban"), 2, 0.15, "Wind 2 turbans")))

// result path => list of deed activities it counts towards. Built with the experiments.
var/global/list/deed_paths = list()

/proc/deed_activity(node_id, key)
	return "deed:[node_id]:[key]"

// Counts a finished piece of work towards every deed it belongs to.
/proc/note_deed_work(mob/user, result_path_string)
	build_practice_experiments()
	. = FALSE
	for (var/path in deed_paths)
		if (result_path_string != path && findtext(result_path_string, "[path]/") != 1)
			continue
		for (var/activity in deed_paths[path])
			if (note_field_work(user, activity))
				. = TRUE

// The activity id that counts things made from node_id's recipes.
/proc/practice_activity(node_id)
	return "craft:[node_id]"

// How many things a practice experiment asks for: more for costlier nodes.
/proc/practice_items_needed(datum/research_node/N)
	return clamp(round(N.cost_ticks / 12), PRACTICE_MIN_ITEMS, PRACTICE_MAX_ITEMS)

// Adds one practice experiment per prerequisite of every early node. Runs once,
// the first time field work is looked up after the tree exists.
/proc/build_practice_experiments()
	if (practice_experiments_built || !research_nodes.len)
		return
	practice_experiments_built = TRUE
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if (!N || N.era_tier >= PRACTICE_BELOW_TIER || N.mode == RESEARCH_MODE_BOOK || !N.prereqs.len)
			continue
		// Hand-written deeds replace the generated practice.
		if (islist(subject_deeds[N.id]))
			for (var/list/D in subject_deeds[N.id])
				var/activity = deed_activity(N.id, D[1])
				field_experiments["deed_[N.id]_[D[1]]"] = list(N.id, activity, D[3], D[4], D[5])
				for (var/path in D[2])
					if (!islist(deed_paths[path]))
						deed_paths[path] = list()
					deed_paths[path] |= activity
			continue
		var/needed = practice_items_needed(N)
		var/share = round(PRACTICE_TOTAL_SHARE / N.prereqs.len, 0.01)
		for (var/req in N.prereqs)
			var/datum/research_node/P = get_research_node(req)
			if (!P)
				continue
			var/id = "practice_[N.id]_[P.id]"
			if (field_experiments[id])
				continue
			field_experiments[id] = list(N.id, practice_activity(P.id), needed, share, "Make [needed] things taught by [P.name]")
	// Caps are worked out again with the new experiments included.
	field_activity_caps = null

// Called when someone finishes making something. The recipe's own research
// node decides which practice it counts towards.
/proc/note_craft_practice(mob/user, result_path_string)
	if (!istext(result_path_string) || !map || !map.book_research_enabled())
		return FALSE
	var/deed = note_deed_work(user, result_path_string)
	var/node_id = get_recipe_node_req(result_path_string)
	if (!istext(node_id) || !get_research_node(node_id))
		return deed
	// Made beside someone who knows the subject: guided work (trade_learning.dm).
	// Otherwise, made early from a part-written chapter: a prototype (subject_prototypes.dm).
	if (!record_guided_work(user, result_path_string))
		record_subject_prototype(user, result_path_string)
	// People close by who could learn the subject watch how it is done.
	note_craft_watched(user, result_path_string)
	return note_field_work(user, practice_activity(node_id)) || deed

#undef PRACTICE_BELOW_TIER
#undef PRACTICE_TOTAL_SHARE
#undef PRACTICE_MIN_ITEMS
#undef PRACTICE_MAX_ITEMS
