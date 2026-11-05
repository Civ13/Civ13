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
// The saver omits a field still at its compiled default, so a load keeps
// whatever the constructor left there. A scalar that a restore constructor
// sets to a different value each time (random looks, offsets, counters)
// therefore changes on every load of an object that held its default.
// Allowlisted types already restore omitted fields to their defaults.
/proc/load_construction_drift_fields(datum/D)
	. = list()
	if(QDELETED(D) || D.persistence_uses_field_allowlist())
		return
	for(var/key in D.vars)
		switch(key)
			if("type", "parent_type", "vars", "loc", "locs", "pixloc", "contents", "x", "y", "z", "vis_locs", "client", "key", "ckey", "verbs", "group", "name", "tag", "override", "animate_movement")
				continue
		if(D.persistence_runtime_var(key))
			continue
		var/value = D.vars[key]
		var/default_value = initial(D.vars[key])
		if(value != default_value && persistence_default_scalar(value) && persistence_default_scalar(default_value))
			. += key
// Each type's builds start from seeds derived from its path, so the reviewed
// drift list does not shift when another constructor's random calls change.
/proc/load_construction_seed(T)
	var/text = "[T]"
	. = 7
	for(var/i = 1, i <= length(text), i++)
		. = (. * 31 + text2ascii(text, i)) % 1000003
/proc/load_construction_restore(T, turf/loc)
	persistence_saved_atom_construction++
	try
		. = new T(loc)
	catch(var/exception/inner)
		persistence_saved_atom_construction--
		throw inner
	persistence_saved_atom_construction--
	// A load with no saved fields applies the same omitted-field rules.
	if(.)
		var/datum/built = .
		built.persistence_reset_omitted_fields(list())
// Builds the type a second time and reports drifted fields whose values differ.
// The second copy stays: deleting it races the constructor's spawn callbacks.
/proc/load_construction_record_drift(datum/D, T, turf/loc)
	var/list/fields = load_construction_drift_fields(D)
	if(!fields.len)
		return
	rand_seed(load_construction_seed(T) + 1)
	var/datum/again = load_construction_restore(T, loc)
	if(QDELETED(again))
		return
	for(var/key in fields)
		if(again.vars[key] != D.vars[key])
			text2file("DRIFT\t[T]\t[key]", "construction_drift.txt")
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
				rand_seed(load_construction_seed(T))
				D = load_construction_restore(T, loc)
			else
				D = new T()
			if(!D)
				fails++
				text2file("NULL\t[T]\n", "construction_failures.txt")
			else if(ispath(T, /atom))
				load_construction_record_drift(D, T, loc)
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
