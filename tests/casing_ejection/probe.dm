// Casing ejection from guns and cannons on the production types, 6x4x1 world.
/obj/map_metadata/casing_fixture/New()
	return
/obj/map_metadata/casing_fixture/book_research_enabled()
	return FALSE
/proc/casing_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "casing_result.txt")
		del(world)
		sleep(1)
/proc/casing_count(atom/A, live)
	. = 0
	for(var/obj/item/ammo_casing/C in A)
		if((!!C.BB) == live)
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
	return "Casing fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "casing_result.txt")
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
	initialize_chemical_reactions()
	build_research_tree()
	map = new /obj/map_metadata/casing_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/turf/nest = locate(1,1,1)
	var/turf/pit = locate(3,1,1)
	var/turf/field = locate(5,1,1)

	// A machine gun throws its brass onto its tile, up to the per-tile cap.
	var/obj/item/weapon/gun/projectile/automatic/pkm/G = new(nest)
	casing_check(G.handle_casings == EJECT_CASINGS, "the PKM ejects casings")
	if(!G.ammo_magazine)
		G.ammo_magazine = new G.magazine_type(G)
	var/obj/item/ammo_magazine/belt = G.ammo_magazine
	var/rounds = belt.stored_ammo.len
	casing_check(rounds >= CASINGS_PER_TILE + 8, "the belt holds enough rounds ([rounds])")
	for(var/i = 1, i <= CASINGS_PER_TILE + 8, i++)
		var/obj/item/projectile/P = G.consume_next_projectile()
		casing_check(P, "shot [i] has a bullet")
		G.chambered.expend()
		G.process_chambered()
		casing_check(!G.chambered, "shot [i] clears the chamber")
	casing_check(casing_count(nest, FALSE) == CASINGS_PER_TILE, "[CASINGS_PER_TILE] spent casings lie by the gun ([casing_count(nest, FALSE)])")
	casing_check(!casing_count(belt, FALSE) && !casing_count(G, FALSE), "no spent casing stays in the belt or gun ([casing_count(belt, FALSE)], [casing_count(G, FALSE)])")
	casing_check(belt.stored_ammo.len == rounds - (CASINGS_PER_TILE + 8), "the belt lost one round per shot ([belt.stored_ammo.len])")
	for(var/obj/item/ammo_casing/C in nest)
		casing_check(C.spent_brass_class() == "rifle", "ejected brass can be handloaded ([C.spent_brass_class()])")
		casing_check(C.abandonment_index, "ejected brass decays when abandoned")

	// A live round thrown out of a capped tile is never deleted.
	var/obj/item/ammo_casing/live = belt.stored_ammo[1]
	belt.stored_ammo -= live
	G.chambered = live
	G.process_chambered()
	casing_check(live.loc == nest && live.BB, "a live round lands on a full tile")

	// Tank guns leave a cannon casing of their calibre; field guns an artillery casing.
	var/obj/structure/cannon/modern/tank/T = new(pit)
	var/obj/item/cannon_ball/shell/tank/AP75/TS = new(T)
	var/obj/item/stack/ammopart/casing/tank/TC = T.eject_shell_casing(TS)
	casing_check(istype(TC) && TC.loc == pit && TC.caliber == TS.caliber, "a tank shell leaves a [TS.caliber]mm casing")
	casing_check(findtext(TC.name, "[TS.caliber]mm"), "the casing names its calibre ([TC.name])")
	var/obj/structure/cannon/modern/F = new(field)
	casing_check(istype(F.eject_shell_casing(new /obj/item/cannon_ball/shell(F)), /obj/item/stack/ammopart/casing/artillery), "a field shell leaves an artillery casing")
	casing_check(!F.eject_shell_casing(new /obj/item/cannon_ball/mortar_shell(F)), "a mortar bomb leaves no casing")
	casing_check(!F.eject_shell_casing(new /obj/item/cannon_ball(F)), "a cannonball leaves no casing")
	casing_check(!F.eject_shell_casing(new /obj/item/cannon_ball/shell/naval/HE150(F)), "a naval shell leaves no casing")

	text2file("PASS: guns and cased shells leave their brass, capped per tile", "casing_result.txt")
	del(world)
