// Handloading and spent-brass recovery on the production types, 6x4x1 world.
/obj/map_metadata/handload_fixture/New()
	return
/proc/handload_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "handload_result.txt")
		del(world)
		sleep(1)
/proc/handload_row(path)
	for(var/datum/handload_cartridge/R in handload_cartridges())
		if(R.path == path)
			return R
/proc/handload_count(turf/T, path, live)
	. = 0
	for(var/obj/item/ammo_casing/C in T)
		if(C.type == path && (!!C.BB) == live)
			.++
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Handloading fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "handload_result.txt")
	del(world)
	sleep(1)
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	build_research_tree()
	map = new /obj/map_metadata/handload_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/turf/work = locate(1,1,1)
	var/turf/out = locate(2,1,1)
	var/turf/range = locate(3,1,1)
	var/mob/M = new /mob(work)

	// The table: every row builds a real cartridge of its own caliber.
	var/list/seen = list()
	for(var/datum/handload_cartridge/R in handload_cartridges())
		handload_check(ispath(R.path, /obj/item/ammo_casing) && R.caliber, "row [R.label] has a cartridge and caliber")
		handload_check(!(R.label in seen), "row label [R.label] is unique")
		seen += R.label
		handload_check(get_research_node(R.node), "row [R.label] names a real research node ([R.node])")
		var/obj/item/ammo_casing/C = new R.path(out)
		handload_check(C.BB && C.caliber == R.caliber, "row [R.label] spawns a loaded [R.caliber] round")
		qdel(C)

	// Powder is poured only as far as the casings need, bullets only into charged casings.
	var/obj/item/stack/ammopart/casing/rifle/S = new(work, 10)
	var/obj/item/stack/ammopart/bullet/B = new(work, 20)
	S.handload_attackby(B, M)
	handload_check(S.bulletn == 0 && B.amount == 20, "bullets wait for powder ([S.bulletn], [B.amount] left)")
	var/obj/item/weapon/reagent_containers/glass/beaker/large/P = new(work)
	P.reagents.add_reagent("gunpowder", 6)
	S.handload_attackby(P, M)
	handload_check(S.gunpowder == 6 && !P.reagents.get_reagent_amount("gunpowder"), "a short pour takes all 6 units ([S.gunpowder])")
	S.handload_attackby(B, M)
	handload_check(S.bulletn == 4 && B.amount == 16, "only the four charged casings take bullets ([S.bulletn], [B.amount] left)")
	handload_check(S.handload_ready() == 4, "four sets are ready ([S.handload_ready()])")
	P.reagents.add_reagent("gunpowder", 100)
	S.handload_attackby(P, M)
	handload_check(S.gunpowder == 15 && P.reagents.get_reagent_amount("gunpowder") == 91, "a long pour stops at 15 units ([S.gunpowder], [P.reagents.get_reagent_amount("gunpowder")] left)")

	// Splitting and merging carry whole sets; nothing is lost or made.
	var/obj/item/stack/ammopart/casing/rifle/part = S.split(3)
	handload_check(part && part.amount == 3 && S.amount == 7, "split leaves 3 and 7 casings")
	handload_check(part.handload_ready() == 3 && part.gunpowder == 4.5 && part.bulletn == 3, "split part carries three sets ([part.handload_ready()], [part.gunpowder], [part.bulletn])")
	handload_check(S.handload_ready() == 1 && S.gunpowder == 10.5 && S.bulletn == 1, "original keeps the rest ([S.handload_ready()], [S.gunpowder], [S.bulletn])")
	part.merge(S)
	handload_check(QDELETED(part) && S.amount == 10 && S.gunpowder == 15 && S.bulletn == 4, "merging back restores the stack ([S.amount], [S.gunpowder], [S.bulletn])")

	// Loading pays for exactly the ready sets.
	var/datum/handload_cartridge/AK = handload_row(/obj/item/ammo_casing/a762x39)
	var/datum/handload_cartridge/NINE = handload_row(/obj/item/ammo_casing/a9x19)
	handload_check(AK && NINE, "7.62x39 and 9x19 rows exist")
	handload_check(!S.handload_produce(NINE, "normal", out), "rifle brass cannot load a pistol cartridge")
	handload_check(S.handload_produce(AK, "AP", out) == 4, "four AP rounds are loaded")
	handload_check(handload_count(out, AK.path, TRUE) == 4, "four live 7.62x39 rounds lie on the bench")
	for(var/obj/item/ammo_casing/C in out)
		handload_check(C.btype == "AP" && C.BB.btype == "AP", "loaded round is AP")
	handload_check(S.amount == 6 && S.gunpowder == 9 && S.bulletn == 0 && !S.handload_ready(), "six charged casings remain ([S.amount], [S.gunpowder], [S.bulletn])")
	handload_check(!S.handload_produce(AK, "normal", out), "nothing more loads without bullets")

	// Spent brass: only fired, loose cartridges of the stack's size are gathered.
	for(var/i = 1, i <= 3, i++)
		var/obj/item/ammo_casing/a762x39/fired = new(range)
		qdel(fired.expend())
	var/obj/item/ammo_casing/a9x19/pistol_brass = new(range)
	qdel(pistol_brass.expend())
	var/obj/item/ammo_casing/a762x39/live = new(range)
	var/obj/item/ammo_casing/a50cal/heavy = new(range)
	qdel(heavy.expend())
	handload_check(!live.spent_brass_class(), "a live round is not brass")
	handload_check(!heavy.spent_brass_class(), "heavy machine-gun brass is not reloadable")
	handload_check(pistol_brass.spent_brass_class() == "pistol", "9x19 brass is pistol brass")
	var/obj/item/stack/ammopart/casing/rifle/R2 = new(work, 1)
	handload_check(R2.handload_collect_brass(range, M) == 3 && R2.amount == 4, "three fired 7.62x39 casings are gathered ([R2.amount])")
	handload_check(!QDELETED(live) && !QDELETED(pistol_brass) && !QDELETED(heavy), "live, pistol and heavy casings stay")
	var/obj/item/ammo_magazine/box = new /obj/item/ammo_magazine(work)
	var/obj/item/ammo_casing/a762x39/boxed = new(box)
	qdel(boxed.expend())
	handload_check(!boxed.spent_brass_class(), "a spent round inside a box is left alone")
	text2file("PASS: handloading pays once per round and spent brass comes back", "handload_result.txt")
	del(world)
