// Gun blueprint design code probe (tests/gun_blueprints/run.py). A bench, a
// skilled gunsmith and a stocked bench: blueprints export codes,
// and an imported code is worked through the bench's own design steps, so it
// is refused for parts the gunsmith's people do not know, a caliber the
// receiver cannot take or a bare bench, regardless of coins in hand.

/world
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/gun_code_tester
	civilizations = TRUE
	var/list/probe_nodes = list()

/obj/map_metadata/gun_code_tester/New()
	return

/obj/map_metadata/gun_code_tester/book_research_enabled()
	return FALSE

/obj/map_metadata/gun_code_tester/is_node_done(faction, node_id)
	return (node_id in probe_nodes)

/mob/living/human/gun_code_probe/New()
	return
/mob/living/human/gun_code_probe/update_inv_l_hand(update_icons=1)
	return
/mob/living/human/gun_code_probe/update_inv_r_hand(update_icons=1)
	return

var/global/gun_probe_checks = 0

/proc/gun_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	gun_probe_checks++
	world.log << "GUN PASS: [message]"

/proc/gun_probe_smith(skill = 300)
	var/mob/living/human/gun_code_probe/H = new(locate(2, 2, 1))
	H.stats = list("crafting" = list(skill, skill))
	return H

/proc/gun_probe_bench(steel = 100, wood = 100)
	var/obj/structure/gunbench/B = new(locate(3, 2, 1))
	B.steel_amt = steel
	B.wood_amt = wood
	return B

/proc/gun_probe_blueprints()
	. = 0
	for (var/obj/item/blueprint/gun/G in world)
		.++

/proc/gun_probe_clear()
	for (var/atom/movable/A in world)
		if (!istype(A, /obj/map_metadata))
			qdel(A)

/proc/gun_probe_run()
	var/obj/map_metadata/gun_code_tester/M = map
	M.probe_nodes = list("cartridge_ammo", "selfloading_firearms", "automatic_weapons")

	// A ready-made blueprint exports and reads back.
	var/obj/item/blueprint/gun/arisaka/A = new(locate(1, 1, 1))
	var/code = gun_blueprint_code(A)
	gun_assert(code == "C13GUN/1/Arisaka_Type_99/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Long_Rifle_Barrel/a77x58/arisaka99", "the Arisaka blueprint exports [code]")
	var/list/G = gun_design_from_code(code)
	gun_assert(G && G["stock"] == "Rifle Wooden Stock" && G["receiver"] == "Bolt-Action" && G["caliber"] == "a77x58" && G["look"] == "arisaka99", "its code reads back")
	gun_assert(!gun_design_from_code("C13GUN/1/a/b/c"), "a short code is refused")
	gun_assert(!gun_design_from_code("C13SHIP/1/a/b/c/d/e/f/g"), "another kind is refused")
	qdel(A)

	// A whole design makes a blueprint and the first gun without coins.
	var/design = "C13GUN/1/Probe_Rifle/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Long_Rifle_Barrel/a792x57/kar98k"
	var/mob/living/human/H = gun_probe_smith()
	var/obj/structure/gunbench/B = gun_probe_bench()
	gun_assert(!H.l_hand && !H.r_hand && B.can_design(H), "the skilled smith can design with empty hands")
	var/obj/item/blueprint/gun/made = B.import_design_code(H, design)
	gun_assert(made && made.receiver_type == "Bolt-Action" && made.caliber == "a792x57" && made.custom_name == "Probe Rifle", "a known design imports as a blueprint")
	gun_assert(B.steel_amt == 100 - 17 && B.wood_amt == 100 - 7, "the bench spends what designing by hand spends ([B.steel_amt] steel, [B.wood_amt] wood)")
	gun_assert(!B.current_gun, "the bench is clear afterwards")
	gun_assert(gun_blueprint_code(made) == design, "the imported blueprint exports the same code")
	var/obj/item/weapon/gun/projectile/custom/first = locate() in get_turf(B)
	gun_assert(first && first.name == "Probe Rifle", "the first gun is still delivered")

	// With a look and a small coin stack, which must stay untouched.
	var/obj/item/stack/money/coins = new /obj/item/stack/money(H)
	coins.value = 1
	coins.amount = 10
	H.r_hand = coins
	made = B.import_design_code(H, "C13GUN/1/Looker/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Rifle_Barrel/a792x57/mosin")
	gun_assert(made && made.override_sprite == "mosin", "a look in the code is kept")
	gun_assert(!QDELETED(coins) && H.r_hand == coins && coins.amount == 10, "held coins are untouched")
	gun_probe_clear()

	// Parts beyond the gunsmith's people are refused, and nothing is spent.
	M.probe_nodes = list("cartridge_ammo")
	H = gun_probe_smith()
	B = gun_probe_bench()
	var/count = gun_probe_blueprints()
	gun_assert(!B.import_design_code(H, "C13GUN/1/Rifle/Steel_Stock/Dual_Selective_Fire/External_Magazine/Carbine_Barrel/a556x45/-"), "a stock from a later age is refused")
	gun_assert(!B.current_gun && B.steel_amt == 100 && gun_probe_blueprints() == count, "a refused import leaves the bench as it was")
	gun_assert(!B.import_design_code(H, "C13GUN/1/Rifle/Rifle_Wooden_Stock/Dual_Selective_Fire/Internal_Magazine/Rifle_Barrel/a556x45/-"), "a receiver from a later age is refused")
	gun_assert(!B.import_design_code(H, "C13GUN/1/Rifle/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Rifle_Barrel/a45/-"), "a caliber the receiver cannot take is refused")
	gun_assert(!B.import_design_code(H, "C13GUN/1/Rifle/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Rifle_Barrel/a792x57/ak47"), "a look the receiver does not have is refused")
	gun_assert(!B.import_design_code(H, "C13GUN/1/Rifle/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Rifle_Barrel/a792x57/kar98k"), "a look from a later age is refused")
	gun_assert(!B.current_gun, "every refusal clears the bench")
	gun_probe_clear()

	// The bench's own limits.
	M.probe_nodes = list("cartridge_ammo")
	design = "C13GUN/1/Probe_Rifle/Rifle_Wooden_Stock/Bolt-Action/Internal_Magazine/Long_Rifle_Barrel/a792x57/mosin"
	H = gun_probe_smith()
	B = gun_probe_bench()
	gun_assert(B.import_design_code(H, design), "the same rifle in an older look imports at the cartridge age")
	gun_probe_clear()
	H = gun_probe_smith()
	B = gun_probe_bench(2, 100)
	gun_assert(!B.import_design_code(H, design), "a bench without the steel refuses")
	H = gun_probe_smith(skill = 100)
	B = gun_probe_bench()
	gun_assert(!B.can_design(H), "an unskilled maker cannot design")

/world/New()
	OpenPort("none")
	sleep(1)
	var/result = "FAIL"
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		GLOB.nanomanager = new /datum/nanomanager
		map = new /obj/map_metadata/gun_code_tester
		gun_probe_run()
		result = "PASS: gun blueprint codes"
	catch (var/exception/E)
		world.log << "GUN FAIL: [E] at [E.file]:[E.line]"
	world.log << "GUN CHECKS: [gun_probe_checks]"
	text2file(result, "result.txt")
	del(world)
