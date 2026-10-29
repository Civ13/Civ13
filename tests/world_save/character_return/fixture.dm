// Tiny source-prepared fixture. Native execution is not provided by prepare.py.
// Serializer/reclaim/bed policy are production; client IO and physiology are adapters.
var/character_return_profile = TRUE
var/character_return_refuse_handoff = FALSE
var/mob/living/human/character_return/return_body
var/obj/structure/bed/character_return/return_bed
var/turf/return_origin

/turf/floor/character_return
/turf/floor/beach/water
/turf/floor/lava
/obj/map_metadata/character_return/uses_durable_metadata()
	return character_return_profile
/mob/living/human
	var/riding
	var/driver
	var/driver_vehicle
	var/riding_mob
	var/health = 100
	var/nutrition = 400
	var/water = 100
	var/datum/character_return_medical/fixture_medical
/datum/character_return_medical
	var/damage = 0
/obj/structure/bed
	var/buckle_lying = TRUE
/obj/structure/bed/character_return
	anchored = TRUE
	can_buckle = TRUE
/obj/item/character_return_item
	var/serial = 0
/mob/living/human/character_return
	var/tmp/fixture_move_mode
/mob/living/human/character_return/persistence_runtime_var(key)
	return key == "fixture_move_mode" || ..()
/mob/living/human/character_return/forceMove(atom/destination, var/special_event)
	if(fixture_move_mode == "refused") return FALSE
	if(fixture_move_mode == "redirected") return ..(locate(2,2,2), special_event)
	return ..()

// Same external-effect seam as the existing player-admission probe. It is not
// a native client, Login, HUD, key occupancy or interactive reconnect test.
/mob/new_player/var/datum/character_return_client/claim_client
/datum/character_return_client
	var/key = "FixtureAccount"
	var/ckey = "fixtureaccount"
	var/mob/mob
	var/transfers = 0
/datum/character_return_client/proc/quickBan_isbanned(kind)
	return FALSE
/proc/character_return_transfer(datum/character_return_client/C, mob/living/human/H)
	if(character_return_refuse_handoff) return
	C.transfers++
	C.mob = H
/proc/character_return_lobby(datum/character_return_client/C)
	var/mob/new_player/L = new
	L.claim_client = C
	C.mob = L
	return L

/map_storage/cross_level/character_return/capture_durable_world()
	durable_export = new
	return list("root" = durable_export.encode(list(return_body, return_body, return_bed)))
// The cross-level seam has a deliberately synthetic metadata graph, not Nomads
// zone topology. Keep its zone-less schema while enabling the real bed predicate.
// This override is confined to this fixture subtype, never the generic adapter.
/map_storage/cross_level/character_return/begin_zone_export(generation)
	cross_check(!zone_export_state, "synthetic metadata unexpectedly carried zone state")
	return

/proc/character_return_setup()
	map_storage = new /map_storage/cross_level/character_return
	map_storage.last_error = null
	map_storage.reset_player_restoration()
	persistence_player_claims = list()
	persistence_player_restore_ready = TRUE
	return_origin = locate(2,1,2)
	return_body = new(return_origin)
	return_body.name = "synthetic returned body"
	return_body.persistence_owner_ckey = "fixtureaccount"
	return_body.persistence_restored = TRUE
	return_body.stat = UNCONSCIOUS
	return_body.health = 23
	return_body.nutrition = 83
	return_body.water = 29
	return_body.inducedSSD = TRUE
	return_body.sleeping = 66
	return_body.fixture_medical = new
	return_body.fixture_medical.damage = 37
	var/obj/item/character_return_item/I = new(return_body)
	I.serial = 813
	return_bed = new(locate(3,2,2))
	return_bed.persistence_bed_owner_ckey = "fixtureaccount"
	map_storage.register_restored_player(return_body)
	cross_check(persistence_bed_return_enabled(), "dedicated bed policy was not enabled")
	cross_check(return_bed.valid_character_bed(return_body), "fixture bed was not a valid destination")

/proc/character_return_check_state(mob/living/human/character_return/H, obj/item/character_return_item/I, datum/character_return_medical/M)
	cross_check(H.health == 23 && H.nutrition == 83 && H.water == 29 && H.stat == UNCONSCIOUS && !H.rejuvenate_calls, "return changed represented medical or needs state")
	cross_check(I && I.loc == H && I.serial == 813 && H.fixture_medical == M && M.damage == 37, "return changed represented inventory or medical identity")

/proc/character_return_success(datum/character_return_client/C, mob/new_player/L, turf/expected)
	var/mob/living/human/character_return/H = return_body
	var/obj/item/character_return_item/I = locate(/obj/item/character_return_item) in H
	var/datum/character_return_medical/M = H.fixture_medical
	cross_check(map_storage.reclaim_saved_player(L), "eligible body return failed")
	cross_check(C.mob == H && H.loc == expected, "reclaim replaced body or selected wrong destination")
	cross_check(!persistence_player_claims[C.ckey], "successful handoff retained reservation")
	cross_check(H.persistence_restored, "return cleared customization suppression")
	character_return_check_state(H, I, M)

/proc/character_return_case()
	character_return_setup()
	var/datum/character_return_client/C = new
	var/mob/new_player/L = character_return_lobby(C)
	if(cross_case == "disk")
		// Actual version-2 exporter, preflight and importer; not a fresh process.
		del(L)
		C.mob = null
		var/reason = cross_try_save()
		cross_check(!reason, "bed/body export rejected: [reason]")
		var/list/state = map_storage.read_round_state()
		cross_check(state["version"] == 2 && map_storage.validate_world_save(), "bed/body generation preflight failed")
		return_bed.persistence_bed_owner_ckey = null
		return_body.health = 0
		return_body.nutrition = 0
		return_body.water = 0
		map_storage.reset_player_restoration()
		map_storage.ClearMap()
		cross_check(map_storage.Load_World(), "bed/body disk import failed")
		map_storage.restore_durable_world()
		var/map_storage/cross_level/storage = map_storage
		var/list/roots = storage.fixture_restored
		cross_check(roots.len == 3 && roots[1] == roots[2], "disk body alias changed")
		return_body = roots[1]
		return_bed = roots[3]
		cross_check(istype(return_body) && istype(return_bed), "disk body or bed type changed")
		cross_check(return_bed.persistence_bed_owner_ckey == "fixtureaccount", "disk bed ownership lost")
		cross_check(return_body.persistence_owner_ckey == "fixtureaccount", "disk body ownership lost")
		// Recreate only the synthetic lobby retired before export.
		L = character_return_lobby(C)
		cross_check(map_storage.finish_player_restoration(), "disk player readiness failed")
		character_return_success(C, L, get_turf(return_bed))
		return
	if(cross_case == "repeat-return")
		character_return_success(C, L, get_turf(return_bed))
		return_body.forceMove(return_origin)
		L = character_return_lobby(C)
		cross_check(map_storage.reclaim_saved_player(L), "later lobby reclaim failed")
		cross_check(C.mob == return_body && return_body.loc == return_origin, "repeated return moved back to bed")
		cross_check(C.transfers == 2 && !persistence_restored_bodies[C.ckey] && return_body.persistence_restored, "repeat return changed claim or customization lifecycle")
		return
	if(cross_case == "failed-handoff")
		character_return_refuse_handoff = TRUE
		var/rejected = FALSE
		try
			map_storage.reclaim_saved_player(L)
		catch(var/exception/handoff_error)
			rejected = handoff_error.name == "Saved player body did not receive its authenticated client"
		cross_check(rejected && C.mob == L && !L.spawning && !persistence_player_claims[C.ckey] && persistence_restored_bodies[C.ckey], "failed handoff lost retry ownership")
		character_return_refuse_handoff = FALSE
		return_body.forceMove(return_origin)
		character_return_success(C, L, get_turf(return_bed))
		return
	if(cross_case == "occupied-bed" || cross_case == "destroyed-bed")
		if(cross_case == "occupied-bed") return_bed.buckled_mob = new /mob/living(locate(3,2,2))
		else
			del(return_bed)
		character_return_success(C, L, return_origin)
		return
	if(cross_case == "refused-move" || cross_case == "redirected-move")
		return_body.fixture_move_mode = cross_case == "refused-move" ? "refused" : "redirected"
		cross_check(!map_storage.allow_new_character(L), "failed movement fell through to a fresh character")
		cross_check(C.mob == L && !C.transfers && persistence_restored_bodies[C.ckey] && !persistence_player_claims[C.ckey], "failed movement lost lobby or return claim")
		return_body.fixture_move_mode = null
		character_return_success(C, L, get_turf(return_bed))
		return
	if(cross_case == "reserved")
		var/datum/reservation = new
		persistence_player_claims[C.ckey] = reservation
		cross_check(!map_storage.reclaim_saved_player(L), "reserved return was admitted")
		cross_check(persistence_player_claims[C.ckey] == reservation && C.mob == L && !C.transfers, "reserved return stole another owner")
		return
	if(cross_case == "recovery-hold")
		map_storage.last_error = "synthetic incomplete recovery"
		cross_check(!map_storage.allow_new_character(L) && C.mob == L && !C.transfers, "recovery hold admitted replacement")
		return
	if(cross_case == "dead")
		return_body.stat = DEAD
		cross_check(!map_storage.reclaim_saved_player(L) && map_storage.allow_new_character(L), "dead-only ownership changed respawn admission")
		cross_check(return_body.stat == DEAD && !return_body.rejuvenate_calls && C.mob == L, "dead body revived or claimed")
		return
	if(cross_case == "tdm")
		character_return_profile = FALSE // Metadata policy adapter, not a TDM map startup.
		cross_check(!persistence_bed_return_enabled() && map_storage.allow_new_character(L), "disabled profile changed ordinary admission")
		character_return_success(C, L, return_origin)
		return
	throw EXCEPTION("Unknown character return case")

/world/New()
	OpenPort("none")
	..()
	cross_case = world.params["case"]
	var/result = "PASS"
	try
		cross_check(!world.port, "fixture opened a network port")
		OpenPort(0)
		cross_check(!world.port, "fixture allowed network reopen")
		map = new /obj/map_metadata/character_return(locate(3,2,1))
		character_return_case()
	catch(var/exception/probe_error)
		result = "FAIL: [probe_error.name]"
	text2file(json_encode(list("case" = cross_case, "done" = TRUE, "result" = result, "checks" = cross_checks, "runtime_failed" = cross_runtime_failed, "port" = world.port)), "result.json")
	del(world)
