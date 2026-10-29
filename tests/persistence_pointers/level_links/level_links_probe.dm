// Tiny native fixture for the #3407 cross-level link codec: the actual
// production exporter, loader and preflight with the world_save stubs. Each
// scenario runs in a fresh process and private save directory.
var/link_case
var/link_checks = 0
var/link_runtime_failed = FALSE
var/turf/link_trigger
var/atom/movable/link_hidden

/world
	name = "Civ13 isolated cross-level link fixture"
	maxx = 3
	maxy = 2
	maxz = 2
	fps = 10
	visibility = 0
	sleep_offline = FALSE
	turf = /turf/level_link
	hub = ""
	hub_password = ""
/world/OpenPort(port)
	return ..("none")
/client/New()
	del(src)
/world/Error(exception/E)
	link_runtime_failed = TRUE
	world.log << "Unexpected runtime error: [E] at [E.file]:[E.line]"

/proc/link_check(condition, message)
	link_checks++
	if(!condition) throw EXCEPTION(message)

/turf/level_link/get_saved_vars()
	return list("name")
/turf/level_link/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	if(src == link_trigger && link_hidden)
		link_hidden.loc = null
		link_hidden = null

/obj/link_target
	var/paid_units = 0
/obj/link_target/get_saved_vars()
	return list("name", "paid_units")
/obj/link_target/unsaved
	should_save = FALSE
/obj/link_box/get_saved_vars()
	return list("name")

// Only "link" is declared; "other" keeps the ordinary per-level guard.
/obj/link_holder
	var/link
	var/other
/obj/link_holder/get_saved_vars()
	return list("name", "link", "other")
/obj/link_holder/persistence_level_link_var(key)
	return key == "link" || ..()

/proc/link_save()
	try
		link_check(map_storage.Save_World(), "save admission unexpectedly failed")
	catch(var/exception/save_error)
		return save_error.name
	return null

/proc/link_assert_released()
	link_check(!persistence_active_operation && !persistence_save_in_progress, "export retained operation admission")
	link_check(!map_storage.saving_level_links.len && !map_storage.saving_level_link_ids.len && !map_storage.saving_reference_pins.len, "export retained cross-level link pins")

/proc/link_rows()
	var/list/state = map_storage.read_round_state()
	return state["level_links"]

/proc/link_reload()
	link_check(map_storage.validate_world_save(), "link generation failed production preflight: [map_storage.last_error]")
	map_storage.ClearMap()
	link_check(map_storage.Load_World(), "link generation failed production loading: [map_storage.last_error]")
	link_check(!map_storage.loading_level_link_fields.len && !map_storage.loading_level_link_targets.len && !map_storage.loading_level_links && !map_storage.validated_level_links, "import retained cross-level link state")

/proc/link_find(type, name)
	var/found
	for(var/atom/movable/A in world)
		if(A.type != type || A.name != name) continue
		link_check(!found, "duplicate restored [name]")
		found = A
	link_check(found, "missing restored [name]")
	return found

/proc/link_new_target(atom/where, name, units)
	var/obj/link_target/T = new(where)
	T.name = name
	T.paid_units = units
	return T

/proc/link_new_holder(atom/where, name, target)
	var/obj/link_holder/H = new(where)
	H.name = name
	H.link = target
	return H

// A later-level target is bound when its own level exports; an earlier-level
// target is bound immediately from the completed level's record.
/proc/link_check_direction(backward)
	var/turf/holder_turf = locate(1,1,backward ? 2 : 1)
	var/turf/target_turf = locate(2,1,backward ? 1 : 2)
	link_new_holder(holder_turf, "holder", link_new_target(target_turf, "target", 731))
	var/reason = link_save()
	link_check(!reason, "cross-level link export rejected: [reason]")
	link_assert_released()
	var/list/rows = link_rows()
	link_check(rows && rows.len == 1, "round state lacks exactly one link row")
	var/list/row = rows[1]
	link_check(row["z"] == target_turf.z && row["ref"] > 0 && row["type"] == "/obj/link_target", "link row lost its target identity")
	var/savefile/F = new("map_saves/[holder_turf.z].sav")
	var/found = 0
	F.cd = "/entries"
	for(var/shard in F.dir.Copy())
		F.cd = "/entries/[shard]"
		for(var/ref in F.dir.Copy())
			var/path = map_storage.entry_path(F, ref)
			if(F["[path]/type"] == /obj/link_target) throw EXCEPTION("target duplicated into the holder's level")
			if(F["[path]/type"] != /obj/link_holder) continue
			var/list/value = F["[path]/link"]
			link_check(islist(value) && value["kind"] == "level_link" && value["id"] == 1, "holder field was not stored as a link")
			found++
	link_check(found == 1, "holder level lacks its link field")
	link_reload()
	var/obj/link_holder/H = link_find(/obj/link_holder, "holder")
	var/obj/link_target/T = link_find(/obj/link_target, "target")
	link_check(H.loc == holder_turf && T.loc == target_turf, "link endpoints restored at the wrong levels")
	link_check(H.link == T && T.paid_units == 731, "cross-level link did not resolve to the restored target")

// Ladder-shaped mutual pair, plus a nested target and a shared target.
/proc/link_check_pair()
	var/obj/link_holder/top = link_new_holder(locate(1,1,1), "top", null)
	var/obj/link_holder/bottom = link_new_holder(locate(1,1,2), "bottom", top)
	top.link = bottom
	var/obj/link_box/box = new(locate(3,2,2))
	box.name = "box"
	var/obj/link_target/T = link_new_target(box, "nested", 5)
	link_new_holder(locate(3,1,1), "first", T)
	link_new_holder(locate(2,2,1), "second", T)
	var/reason = link_save()
	link_check(!reason, "paired link export rejected: [reason]")
	link_assert_released()
	var/list/rows = link_rows()
	link_check(rows && rows.len == 3, "pair and shared target did not use one row per target")
	link_reload()
	top = link_find(/obj/link_holder, "top")
	bottom = link_find(/obj/link_holder, "bottom")
	link_check(top.link == bottom && bottom.link == top, "mutual cross-level pair did not restore")
	T = link_find(/obj/link_target, "nested")
	var/obj/link_holder/first = link_find(/obj/link_holder, "first")
	var/obj/link_holder/second = link_find(/obj/link_holder, "second")
	link_check(istype(T.loc, /obj/link_box) && get_turf(T) == locate(3,2,2), "nested target lost its container")
	link_check(first.link == T && second.link == T, "shared cross-level target did not restore once")

/proc/link_check_same_level()
	var/obj/link_target/T = link_new_target(locate(2,1,1), "local", 3)
	link_new_holder(locate(1,1,1), "holder", T)
	link_check(!link_save(), "same-level link export rejected")
	link_check(!link_rows(), "same-level reference used the cross-level codec")
	link_reload()
	var/obj/link_holder/H = link_find(/obj/link_holder, "holder")
	link_check(H.link == link_find(/obj/link_target, "local"), "same-level reference did not restore")

/proc/link_check_undeclared()
	var/obj/link_holder/H = link_new_holder(locate(1,1,1), "holder", null)
	H.other = link_new_target(locate(1,1,2), "target", 1)
	var/reason = link_save()
	link_check(istext(reason) && findtext(reason, "Cross-level object reference cannot be represented") == 1, reason ? "wrong rejection: [reason]" : "undeclared cross-level field was accepted")
	link_check(findtext(reason, "source_field=other"), "rejection lost the undeclared field context")
	link_check(!fexists("map_saves/save_complete.txt"), "rejected export left a completion marker")
	link_assert_released()

/proc/link_check_unsaved()
	var/obj/link_target/unsaved/T = new(locate(1,1,2))
	link_new_holder(locate(1,1,1), "holder", T)
	link_check(!link_save(), "unsaved target blocked the save")
	link_check(!link_rows(), "unsaved target was given a link row")
	link_reload()
	var/obj/link_holder/H = link_find(/obj/link_holder, "holder")
	link_check(isnull(H.link), "unsaved target did not encode null")

/proc/link_check_unbound()
	var/obj/link_target/T = link_new_target(locate(2,1,2), "target", 9)
	link_new_holder(locate(1,1,1), "holder", T)
	link_trigger = locate(1,1,2)
	link_hidden = T
	var/reason = link_save()
	link_check(istext(reason) && findtext(reason, "Cross-level link target is absent from the saved world") == 1, reason ? "wrong rejection: [reason]" : "unbound link target was accepted")
	link_check(!fexists("map_saves/save_complete.txt"), "rejected export left a completion marker")
	var/list/failure = map_storage.last_save_reference_failure
	link_check(islist(failure) && failure["kind"] == "unbound_level_link", "unbound link was not recorded for admins")
	link_assert_released()

/proc/link_check_tampered()
	link_new_holder(locate(1,1,1), "holder", link_new_target(locate(2,1,2), "target", 4))
	link_check(!link_save(), "link export rejected")
	var/list/state = json_decode(file2text("map_saves/round.json"))
	var/list/rows = state["level_links"]
	var/list/row = rows[1]
	row["type"] = "/obj/link_holder"
	fdel("map_saves/round.json")
	text2file(json_encode(state), "map_saves/round.json")
	link_check(!map_storage.validate_world_save(), "tampered link target type was admitted")
	link_check(findtext(map_storage.last_error, "Cross-level link target differs from its saved level") == 1, "wrong tampered-link rejection: [map_storage.last_error]")
	link_check(!map_storage.validated_level_links, "rejected preflight retained link rows")
	link_check(link_find(/obj/link_holder, "holder"), "rejected preflight changed the world")

/world/New()
	OpenPort("none")
	..()
	sleep(1)
	link_case = world.params["case"]
	var/result = "PASS"
	try
		link_check(!world.port, "fixture opened a network port")
		map = new /obj/map_metadata(locate(3,2,1))
		map_storage = new /map_storage("level-link-fixture")
		switch(link_case)
			if("forward") link_check_direction(FALSE)
			if("backward") link_check_direction(TRUE)
			if("pair") link_check_pair()
			if("same-level") link_check_same_level()
			if("undeclared") link_check_undeclared()
			if("unsaved") link_check_unsaved()
			if("unbound") link_check_unbound()
			if("tampered") link_check_tampered()
			else throw EXCEPTION("Unknown level-link fixture scenario")
	catch(var/exception/probe_error)
		result = "FAIL: [probe_error.name]"
	text2file(json_encode(list("case" = link_case, "done" = TRUE, "result" = result, "checks" = link_checks, "runtime_failed" = link_runtime_failed, "port" = world.port)), "result.json")
	del(world)
	sleep(1)
