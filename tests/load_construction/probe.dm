// Constructs every saveable type the way a world load does: atoms with
// new type(loc) under persistence_saved_atom_construction, datums with no
// arguments. A constructor that throws aborts a whole import; one that never
// yields stalls the server. run.py compares failures with known_failures.txt.
/obj/map_metadata/load_construction_fixture/New()
	return
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	fps = 20
	turf = /turf
var/load_construction_current = null
var/load_construction_errors = 0
var/load_construction_start = 0
var/load_construction_stop = 1e9
/world/Topic(T, addr, master, key)
	return "no"
/world/Error(exception/e, datum/e_src)
	load_construction_errors++
	if(load_construction_errors < 20000)
		text2file("ASYNC\t[load_construction_current]\t[e_src ? e_src.type : "-"]\t[e] on [e.file]:[e.line]\n", "construction_async.txt")
/proc/load_construction_skip(T)
	// A bare /atom is not movable: new /atom(loc) replaces the turf itself.
	if(T == /atom) return TRUE
	var/list/prefixes = list(/turf, /area, /client, /image, /mutable_appearance, /icon, /sound, /matrix, /regex, /database, /exception, /savefile, /list, /mob/new_player, /obj/screen, /datum/hud, /datum/action, /obj/item/weapon/grab, /obj/map_metadata, /datum/light_source, /datum/lighting_corner, /atom/movable/lighting_overlay, /atom/movable/lighting_fullbright, /datum/controller, /datum/global_init, /callee, /generator, /particles, /dm_filter, /alist, /vector, /pixloc)
	for(var/p in prefixes)
		if(ispath(T, p)) return TRUE
	return FALSE
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new /decl/observ/destroyed
	GLOB.nanomanager = new /datum/nanomanager
	map = new /obj/map_metadata/load_construction_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	if(fexists("construction_range.txt"))
		var/list/r = splittext(file2text("construction_range.txt"), " ")
		load_construction_start = text2num(r[1])
		load_construction_stop = text2num(r[2])
	spawn(10) sweep()
/proc/sweep()
	var/n = 0
	var/fails = 0
	var/list/types = typesof(/datum)
	for(var/T in types)
		if(load_construction_skip(T)) continue
		var/datum/proto = T
		if(!initial(proto.should_save)) continue
		n++
		if(n < load_construction_start) continue
		if(n >= load_construction_stop) break
		load_construction_current = T
		var/turf/loc = locate((n % 38) + 2, (round(n / 38) % 38) + 2, 1)
		try
			var/datum/D
			if(ispath(T, /atom))
				persistence_saved_atom_construction++
				try
					D = new T(loc)
				catch(var/exception/inner)
					persistence_saved_atom_construction--
					throw inner
				persistence_saved_atom_construction--
			else
				D = new T()
			if(!D)
				fails++
				text2file("NULL\t[T]\n", "construction_failures.txt")
		catch(var/exception/e)
			fails++
			persistence_saved_atom_construction = 0
			text2file("THROW\t[T]\t[e] on [e.file]:[e.line]\n", "construction_failures.txt")
		if(n % 200 == 0)
			world.log << "swept [n] types, [fails] synchronous failures"
			sleep(1)
	load_construction_current = null
	sleep(50)
	text2file("PASS: swept [n] types; [fails] synchronous failures; [load_construction_errors] async runtime errors", "construction_result.txt")
	del(world)
