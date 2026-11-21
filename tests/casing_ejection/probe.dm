// Casing ejection from guns and cannons on the production types, 40x30x1 world.
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
/proc/casing_release()
	if(delayed_garbage)
		delayed_garbage.Cut()
	if(delayed_hard_garbage)
		delayed_hard_garbage.Cut()
// Measurement run (-params measure=heap or measure=loose): 500 tiles of brass,
// 12 casings each, as one mode per process, since RSS never shrinks.
/proc/casing_measure(mode)
	var/obj/item/weapon/gun/projectile/automatic/pkm/G = new(locate(1,1,1))
	var/obj/item/ammo_magazine/belt = new G.magazine_type(null)
	var/casing_type = belt.stored_ammo[1].type
	qdel(belt)
	var/list/tiles = block(locate(1,5,1), locate(40,30,1))
	var/per_tile = 12
	var/count = 500
	sleep(5)
	var/base_objects = casing_objects()
	var/base_rss = casing_rss_kb()
	// Steady state of the brass left behind. Loose mode is the old behaviour,
	// one object per casing. In heap mode one casing per tile
	// lands through the gun and the heap then counts the other eleven, since the
	// rounds themselves existed in the belt either way.
	for(var/n = 1, n <= count, n++)
		var/turf/T = tiles[n]
		G.loc = T
		for(var/k = 1, k <= (mode == "heap" ? 1 : per_tile), k++)
			var/obj/item/ammo_casing/C = new casing_type(mode == "heap" ? null : T)
			qdel(C.expend())
			if(mode == "heap")
				G.drop_casing(C)
		if(mode == "heap")
			var/obj/item/ammo_casing/H = locate(casing_type) in T
			H.heap_add(per_tile - 1)
		casing_release()
	sleep(10)
	var/objects = casing_objects() - base_objects
	var/rss = casing_rss_kb() - base_rss
	text2file("[mode]: casings=[count * per_tile] objects=[objects] rss_kb=[rss] abandonment_entries=[abandoned_items.len]", "casing_measure.txt")
	del(world)
/proc/casing_rss_kb()
	// The fixture has no garbage process, so qdel parks deleted objects in
	// delayed_garbage; production's queue keeps only their refs. Release them.
	casing_release()
	sleep(2)
	fdel("rss.txt")
	shell("grep VmRSS /proc/$PPID/status > rss.txt")
	var/status = file2text("rss.txt")
	var/at = findtext(status, "VmRSS:")
	if(!at)
		return -1
	return text2num(trim(copytext(status, at + 6, findtext(status, "kB", at))))
/proc/casing_objects()
	. = 0
	for(var/obj/item/ammo_casing/C in world)
		if(!QDELETED(C))
			.++
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 30
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
	var/measure = world.params["measure"]
	if(measure)
		casing_measure(measure)
		return
	var/turf/nest = locate(1,1,1)
	var/turf/pit = locate(3,1,1)
	var/turf/field = locate(5,1,1)
	var/mob/M = new /mob(locate(1,2,1))

	// A machine gun's brass collects into one heap on its tile, up to the cap.
	var/obj/item/weapon/gun/projectile/automatic/pkm/G = new(nest)
	casing_check(G.handle_casings == EJECT_CASINGS, "the PKM ejects casings")
	if(!G.ammo_magazine)
		G.ammo_magazine = new G.magazine_type(G)
	var/obj/item/ammo_magazine/belt = G.ammo_magazine
	var/rounds = belt.stored_ammo.len
	var/shots = CASINGS_PER_TILE + 8
	casing_check(rounds >= shots + 2, "the belt holds enough rounds ([rounds])")
	var/casing_type = belt.stored_ammo[1].type
	for(var/i = 1, i <= shots, i++)
		var/obj/item/projectile/P = G.consume_next_projectile()
		casing_check(P, "shot [i] has a bullet")
		G.chambered.expend()
		G.process_chambered()
		casing_check(!G.chambered, "shot [i] clears the chamber")
	casing_check(casing_count(nest, FALSE) == 1, "the brass forms one heap ([casing_count(nest, FALSE)] objects)")
	var/obj/item/ammo_casing/heap = locate(casing_type) in nest
	casing_check(heap && heap.heap_count == CASINGS_PER_TILE, "the heap holds [CASINGS_PER_TILE] casings ([heap ? heap.heap_count : 0])")
	casing_check(heap.overlays.len == ITEM_HEAP_VISIBLE_MAX, "the heap draws [ITEM_HEAP_VISIBLE_MAX] extra casings ([heap.overlays.len])")
	casing_check(!casing_count(belt, FALSE) && !casing_count(G, FALSE), "no spent casing stays in the belt or gun ([casing_count(belt, FALSE)], [casing_count(G, FALSE)])")
	casing_check(belt.stored_ammo.len == rounds - shots, "the belt lost one round per shot ([belt.stored_ammo.len])")
	casing_check(heap.spent_brass_class() == "rifle", "heaped brass can be handloaded ([heap.spent_brass_class()])")
	casing_check(heap.abandonment_index, "the heap decays when abandoned")

	// A live round thrown out onto the heap is kept as its own object.
	var/obj/item/ammo_casing/live = belt.stored_ammo[1]
	belt.stored_ammo -= live
	G.chambered = live
	G.process_chambered()
	casing_check(live.loc == nest && live.BB && heap.heap_count == CASINGS_PER_TILE, "a live round lands beside the heap")

	// Picking the heap up takes one casing and leaves the rest.
	heap.pickup(M)
	heap.loc = M
	var/obj/item/ammo_casing/rest = null
	for(var/obj/item/ammo_casing/C in nest)
		if(!C.BB)
			rest = C
	casing_check(heap.heap_count == 1 && !heap.overlays.len, "one casing is picked up ([heap.heap_count])")
	casing_check(rest && rest != heap && rest.heap_count == CASINGS_PER_TILE - 1 && !rest.BB, "the rest stay as a spent heap ([rest ? rest.heap_count : 0])")
	casing_check(rest.name == heap.name, "the heap keeps the casing's name ([rest.name], [heap.name])")
	casing_check(!G.ammo_casing_fits(rest, M), "a heap cannot be loaded as one round")

	// A casing stack gathers the whole heap, or as much as it has room for.
	var/obj/item/stack/ammopart/casing/rifle/S = new(locate(2,2,1), 1)
	S.max_amount = 11
	casing_check(S.handload_collect_brass(nest, M) == 10 && S.amount == 11, "a nearly full stack takes 10 casings ([S.amount])")
	casing_check(!QDELETED(rest) && rest.heap_count == CASINGS_PER_TILE - 11, "the heap keeps the rest ([rest.heap_count])")
	S.max_amount = 100
	casing_check(S.handload_collect_brass(nest, M) == CASINGS_PER_TILE - 11 && QDELETED(rest), "the rest of the heap is gathered")
	casing_check(!QDELETED(live), "the live round stays")

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

	text2file("PASS: guns and cased shells leave their brass in heaps", "casing_result.txt")
	del(world)
