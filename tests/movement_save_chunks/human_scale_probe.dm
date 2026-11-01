// Synthetic scale fixture only. No live data or connected clients.
/obj/map_metadata/subtile_fixture
	ID = "human-scale-fixture"

/obj/item/weapon/pen/human_scale_ground
	var/scale_number = 0

var/global/human_scale_heartbeat_running = FALSE
var/global/human_scale_heartbeat_last = 0
var/global/human_scale_heartbeat_max_gap = 0
var/global/human_scale_heartbeat_count = 0
var/global/human_scale_serialization_start = 0
var/global/human_scale_serialization_end = 0
var/global/human_scale_human_checks_start = 0
var/global/human_scale_human_checks_end = 0
var/global/list/human_scale_geometry_metrics = null

/proc/human_scale_assert(ok, label)
	if(!ok) throw EXCEPTION(label)

/proc/human_scale_heartbeat()
	while(human_scale_heartbeat_running)
		sleep(1)
		var/now = world.realtime
		var/gap = now - human_scale_heartbeat_last
		if(gap < 0) throw EXCEPTION("scale_heartbeat_clock_reversed")
		human_scale_heartbeat_max_gap = max(human_scale_heartbeat_max_gap, gap)
		human_scale_heartbeat_count++
		human_scale_heartbeat_last = now

/proc/human_scale_owner(i)
	return "syntheticscale[i]"

/proc/human_scale_expected_position(i)
	return list("x" = 2 + 4 * (i - 1), "y" = 2, "z" = 1, "sx" = 4, "sy" = 4)

/proc/human_scale_check_round()
	var/marker = trim(file2text("map_saves/save_complete.txt"))
	var/list/round = map_storage.read_round_state()
	human_scale_assert(length(marker) && islist(round) && round["generation"] == marker, "scale_round_generation")
	human_scale_assert(round["map"] == map.ID && round["game_id"] == "human-scale-round", "scale_round_identity")
	human_scale_assert(round["maxx"] == 700 && round["maxy"] == 500 && round["maxz"] == 1, "scale_round_dimensions")
	return marker

// Validate each saved map reference rather than counting only live world turfs.
// This inspection is separately timed and yields; it is not serialization.
/proc/human_scale_count_saved_turfs()
	var/savefile/F = new("map_saves/1.sav")
	var/count = 0
	for(var/y = 1, y <= 500, y++)
		for(var/x = 1, x <= 700, x++)
			var/ref = F["/map/1/[y]/[x]"]
			if(!isnum(ref) || isnan(ref) || isinf(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("scale_missing_saved_turf")
			count++
			if(!(count % 512)) sleep(world.tick_lag)
	return count

/proc/human_scale_check_bodies()
	var/count = 0
	var/all_humans = 0
	for(var/mob/living/human/body in world)
		all_humans++
	human_scale_assert(all_humans == 32, "scale_world_human_count")
	for(var/i = 1, i <= 32, i++)
		var/list/bodies = persistence_restored_bodies[human_scale_owner(i)]
		human_scale_assert(islist(bodies) && bodies.len == 1, "scale_owner_count")
		var/mob/living/human/H = bodies[1]
		var/list/expected_position = human_scale_expected_position(i)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		expected_position["sx"] = 0
		expected_position["sy"] = 0
#endif
		human_scale_assert(H && H.type == /mob/living/human && human_subtile_same(H.human_subtile_snapshot(), expected_position), "scale_actor_position")
		human_scale_assert(istype(H.back, /obj/item/weapon/storage/backpack) && H.back.loc == H, "scale_actor_bag")
		var/obj/item/weapon/pen/P = locate(/obj/item/weapon/pen) in H.back
		human_scale_assert(P && P.loc == H.back && P.name == "scale nested pen [i]", "scale_nested_pen")
		count++
	return count

/proc/human_scale_check_ground()
	var/list/seen = list()
	var/count = 0
	for(var/obj/item/weapon/pen/human_scale_ground/P in world)
		var/id = P.scale_number
		human_scale_assert(isnum(id) && id >= 1 && id <= 5000 && !seen["[id]"], "scale_ground_identity")
		human_scale_assert(isturf(P.loc) && P.z == 1 && P.y >= 100 && P.y <= 107, "scale_ground_location")
		seen["[id]"] = TRUE
		count++
	human_scale_assert(count == 5000, "scale_ground_count")
	var/expected_id = 0
	for(var/y = 100, y <= 107 && expected_id < 5000, y++)
		for(var/x = 1, x <= 700 && expected_id < 5000, x++)
			var/obj/item/weapon/pen/human_scale_ground/expected_pen = locate(/obj/item/weapon/pen/human_scale_ground) in locate(x, y, 1)
			human_scale_assert(expected_pen && expected_pen.scale_number == ++expected_id, "scale_ground_exact_position")
	return count

/world/New()
	var/native_port = port
	OpenPort("none")
	var/list/observed = list("head" = world.params["tested_commit"], "phase" = world.params["phase"], "variant" = world.params["variant"], "initial_native_port" = native_port, "port" = port, "byond_version" = byond_version, "byond_build" = byond_build)
	text2file(json_encode(observed), "human-scale-entry.json")
	var/error = null
	try
		human_scale_assert(!port && byond_version == 516 && byond_build == 1688, "scale_engine_or_port")
		human_scale_assert(world.maxx == 700 && world.maxy == 500 && world.maxz == 1, "scale_world_dimensions")
		observed["world_turfs"] = world.maxx * world.maxy * world.maxz
		observed["world_turfs_basis"] = "dimension_product_not_a_restored_turf_scan"
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		human_scale_assert(world.params["variant"] == "enabled", "scale_variant_binding")
#else
		human_scale_assert(world.params["variant"] == "disabled", "scale_variant_binding")
#endif
		var/setup_start = world.realtime
		human_subtile_fixture_initialize()
		global.game_id = "human-scale-round"
		human_scale_assert(map && map.ID == "human-scale-fixture", "scale_map_identity")
		human_scale_heartbeat_last = world.realtime
		human_scale_heartbeat_running = TRUE
		spawn(0) human_scale_heartbeat()
		if(world.params["phase"] == "writer")
			for(var/i = 1, i <= 32, i++)
				var/list/position = human_scale_expected_position(i)
				var/mob/living/human/H = new(locate(position["x"], position["y"], 1))
				H.persistence_owner_ckey = human_scale_owner(i)
				H.canmove = TRUE
				H.stat = CONSCIOUS
				human_scale_assert(H.set_human_subtile(TRUE), "scale_human_enable")
				// Test-only partial input; the enabled reader must normalize it.
				H.step_x = position["sx"]
				H.step_y = position["sy"]
				H.human_subtile_offset_owned = TRUE
				human_scale_assert(H.human_subtile_offset_owned && human_subtile_same(H.human_subtile_snapshot(), position), "scale_initial_position")
				var/obj/item/weapon/storage/backpack/B = new(H)
				H.back = B
				var/obj/item/weapon/pen/P = new(B)
				P.name = "scale nested pen [i]"
			var/ground = 0
			for(var/y = 100, y <= 107 && ground < 5000, y++)
				for(var/x = 1, x <= 700 && ground < 5000, x++)
					var/obj/item/weapon/pen/human_scale_ground/ground_pen = new(locate(x, y, 1))
					ground_pen.scale_number = ++ground
			human_scale_assert(ground == 5000, "scale_ground_setup")
			var/setup_humans = 0
			for(var/mob/living/human/setup_body in world)
				setup_humans++
			human_scale_assert(setup_humans == 32, "scale_setup_human_count")
			observed["setup_humans"] = setup_humans
			observed["setup_ground"] = ground
			observed["setup_deciseconds"] = world.realtime - setup_start
			var/save_start = world.realtime
			human_scale_assert(map_storage.Save_World(), "scale_save_failed")
			observed["save_deciseconds"] = world.realtime - save_start
			observed["generation"] = human_scale_check_round()
			var/writer_inspect_start = world.realtime
			observed["saved_turfs"] = human_scale_count_saved_turfs()
			observed["saved_turf_slot_check"] = "positive_integer_refs_not_unique_or_type_verified"
			observed["inspection_deciseconds"] = world.realtime - writer_inspect_start
			human_scale_assert(observed["saved_turfs"] == 350000, "scale_saved_turf_count")
		else if(world.params["phase"] == "reader")
			var/list/expected = json_decode(file2text("human-scale-expected.json"))
			human_scale_assert(islist(expected) && expected["generation"] == human_scale_check_round(), "scale_expected_generation")
			observed["setup_deciseconds"] = world.realtime - setup_start
			var/load_start = world.realtime
			human_scale_assert(map_storage.Load_World(), "scale_load_failed")
			observed["load_deciseconds"] = world.realtime - load_start
			var/reader_inspect_start = world.realtime
			observed["restored_humans"] = human_scale_check_bodies()
			observed["restored_ground"] = human_scale_check_ground()
			observed["inspection_deciseconds"] = world.realtime - reader_inspect_start
			observed["generation"] = expected["generation"]
		else
			throw EXCEPTION("scale_phase_unknown")
		sleep(world.tick_lag)
		observed["heartbeat_count"] = human_scale_heartbeat_count
		observed["heartbeat_max_gap_deciseconds"] = human_scale_heartbeat_max_gap
		observed["heartbeat_scope"] = "post_initialization_setup_save_or_load_and_inspection"
		human_scale_assert(human_scale_heartbeat_count > 0, "scale_heartbeat_missing")
	catch(var/exception/E)
		error = E.name
	human_scale_heartbeat_running = FALSE
	if(human_scale_serialization_start && human_scale_serialization_end >= human_scale_serialization_start)
		observed["serialization_and_flush_deciseconds"] = human_scale_serialization_end - human_scale_serialization_start
	if(human_scale_human_checks_start && human_scale_human_checks_end >= human_scale_human_checks_start)
		observed["human_candidate_checks_deciseconds"] = human_scale_human_checks_end - human_scale_human_checks_start
	observed["geometry_metrics"] = human_scale_geometry_metrics
	observed["error"] = error
	text2file(json_encode(observed), "human-scale-[world.params["phase"]].json")
	if(error) world.log << "FAIL: [error]"
	del(world)
	return
