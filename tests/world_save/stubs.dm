// Offline adapters: no game startup, players, network, SQL, or production files.
// Minimal serializer fixtures do not exercise wounds. Keep the loader's type
// contract declared, but fail closed if one is introduced into these probes.
// The --wounds full-source fixture tests actual constructor/state restoration.
/datum/wound/lost_limb
/datum/wound/lost_limb/proc/validate_restored_state()
	throw EXCEPTION("Lost-limb restoration requires the production wound fixture")

#ifndef BUILDING_MAX_Z
#define BUILDING_MAX_Z 32
#define BUILDING_EXTRA_LEVELS 8
#define BUILDING_MAX_LEVEL_CELLS 2000000
var/building_allocating_z = 0
/proc/building_base_maxz()
	return world.maxz
/proc/building_allocate_level(target_z, bootstrap = FALSE)
	return FALSE // Ordinary legacy fixtures never expand a level.
#endif
var/TimeOfGame = 0
// Ordinary serializer probes do not execute reboot effects. Transaction tests
// compile the complete production state machine with their own adapters.
var/datum/persistence_restart_transaction/persistence_restart = new
/datum/persistence_restart_transaction
	var/startup_hold = FALSE
	var/busy = FALSE
	var/expected_generation
/datum/persistence_restart_transaction/proc/exists()
	return FALSE
var/obj/map_metadata/map
// ClearMap preserves the production view singleton; focused probes have none.
var/mob/dview_mob
var/list/errors = list()
var/list/clients = list()
var/game_id = "fixture-round"
var/round_start_time = 0
var/round_elapsed_offset = 0
var/roundstart_time = 0
var/next_duration_update = 0
var/next_duration_update_days = 0
var/last_roundduration2text = 0
var/last_roundduration2text_days = 0
var/datum/controller/gameticker/ticker
// Ordinary serializer fixtures exclude occupations. Round-state mode opts out
// and supplies extracted production job-limit logic instead.
#ifndef WORLD_SAVE_JOB_ADAPTER
var/datum/world_save_fixture_jobs/job_master = new
/datum/world_save_fixture_jobs/proc/initialize_position_limits()
	return
#endif
var/datum/fixture_processes/processes = new
/datum/fixture_processes
	var/datum/fixture_ticker_process/ticker = new
/datum/fixture_ticker_process
	var/playtime_elapsed = 0
// Production applies restored daylight in the lighting module; fixtures have no overlays.
/proc/apply_restored_lighting()
	return FALSE
#ifndef WORLD_SAVE_MUSIC_ADAPTER
/proc/TOD_loop()
	return
/proc/stop_lobby_music()
	return
#endif
/proc/trim(value)
	var/list/lines = splittext(value, "\n")
	return lines[1]
/client/proc/quickBan_isbanned(kind)
	return FALSE
// The raw-key form used by client/New, including web guests.
/proc/IsGuestKey(key)
	if(findtext(key, "Guest-", TRUE, 7) != TRUE) return FALSE
	var/start = copytext(key, 7, 8) == "W" ? 8 : 7
	for(var/i = start, i <= length(key), i++)
		var/character = text2ascii(key, i)
		if(character < 48 || character > 57) return FALSE
	return TRUE
/proc/get_turf(atom/A)
	while(A && !isturf(A))
		A = A.loc
	return A
var/delete_failure_path = null
var/list/mutate_on_tick = null
/proc/fixture_tick_check()
	if(mutate_on_tick)
		mutate_on_tick.Cut()
		mutate_on_tick = null
	return world.tick_usage > 80 ? stoplag() : 0
/proc/delete_file_adapter(path)
	if("[path]" == delete_failure_path)
		return 0
	return fdel(path)
/proc/to_chat(target, message)
	world.log << message
/proc/message_admins(message)
	errors += message
	world.log << message
/proc/qdel(datum/D)
	del(D)
/proc/ishuman(D)
	return istype(D, /mob/living/human)
/atom/movable/lighting_overlay
/atom/proc/update_light()
	// Focused serializer adapter; the lighting regression uses production lighting.
	return
/turf/proc/recalc_atom_opacity()
	return
/turf/var/tmp/lighting_reserved = FALSE
/turf/proc/activate_reserved_lighting()
	// Only ordinary turfs are supported by this serializer-only adapter.
	// Reserved lighting tests compile the real module without these stubs.
	if (lighting_reserved)
		CRASH("Reserved lighting requires the production lighting fixture")
	return
/atom/movable
	var/load_datums = FALSE
/obj
	var/datum/reagents/reagents
/datum/reagents
	var/my_atom
/obj/structure/wild
/obj/item
/obj/covers
/mob
	var/stat = FALSE // Production mob_defines.dm default; states from predefines.dm.
	var/datum/hud/hud_used
	var/list/HUDneed = list()
	var/list/HUDinventory = list()
	var/list/HUDfrippery = list()
	var/list/HUDprocess = list()
	var/list/HUDtech = list()
	var/obj/screen/hands
	var/obj/screen/pullin
	var/obj/screen/purged
	var/obj/screen/i_select
	var/obj/screen/m_select
	var/obj/screen/zone_sel
/obj/screen
/datum/hud
/mob/new_player
	var/spawning = FALSE
/mob/new_player/proc/close_spawn_windows()
	return
/mob/living/human
	var/tmp/rejuvenate_calls = 0
/mob/living/human/proc/human_subtile_prepare_import(savefile/F)
	// This minimal fixture has no physical sub-tile movement implementation.
	if ("human_subtile_position" in F.dir)
		throw EXCEPTION("Sub-tile restoration requires the full-source human fixture")
	return
/mob/living/human/proc/rejuvenate()
	rejuvenate_calls++
	stat = CONSCIOUS
/datum/controller/gameticker
	var/current_state = GAME_STATE_PREGAME
	var/finished = FALSE
	var/list/minds = list()
/datum/controller/gameticker/proc/collect_minds()
	return
/obj/map_metadata
	var/ID = "TEST"
	var/age = "test epoch"
	var/ordinal_age = 2
	var/default_research = 42
	var/autoresearch = 1
	var/autoresearch_mult = 2
	var/chad_mode = 0
	var/chad_mode_plus = 0
	var/gamemode = "test"
	var/persistence = FALSE
	var/research_active = FALSE
	var/resourceresearch = FALSE
	var/perschadplus = FALSE
	var/age1_done
	var/age2_done
	var/age3_done
	var/age4_done
	var/age5_done
	var/age6_done
	var/age7_done
	var/age8_done
/turf/proc/ChangeTurf(path, tell_universe, force_lighting_update)
	return new path(src)

// This legacy serializer fixture has no supported world metadata profile.
// Actual round-v2 integration is tested by run-durable-world.py instead.
/map_storage
	var/datum/durable_save_graph/durable_export
	var/datum/durable_save_graph/durable_import
	var/loading_z = 0
/datum/durable_save_graph/proc/bind_entry(datum/A, z, ref)
	return
/datum/durable_save_graph/proc/accept_entry(z, ref, datum/A)
	return
/datum/durable_save_graph/proc/finish_export()
	return null
/map_storage/proc/capture_durable_world()
	return null
/map_storage/proc/validate_durable_world(list/state, generation)
	throw EXCEPTION("Unsupported fixture metadata profile")
#ifndef WORLD_SAVE_REAL_DURABLE_IDLE
// Serializer-only fixtures omit metadata transitions, like suspension below.
// The operation probe opts out and includes the production predicate instead.
/map_storage/proc/require_durable_world_idle()
	return
#endif
/map_storage/proc/suspend_durable_world()
	return
/map_storage/proc/restore_durable_world()
	return
/map_storage/proc/release_durable_world()
	durable_export = null
	durable_import = null
	loading_z = 0

// Disabled renderer coverage is runtime-only; minimal serializer fixtures have none.
/atom/movable/lighting_fullbright
/turf/proc/sync_fullbright_coverage()
	return

// These serializer-only worlds cannot import topology. Full-source prepared
// zone fixtures compile the production implementation instead.
/area/var/tmp/persistence_zone_id
/map_storage
	var/list/validated_zone_state
	var/list/validated_zones = list()
	var/list/restored_zones = list()
/map_storage/proc/clear_saved_zones()
	validated_zone_state = null
/map_storage/proc/saved_zone_id(x, y, z)
	return null
/map_storage/proc/capture_zone_topology(yielding = TRUE)
	return null
/map_storage/proc/prepare_saved_zones(list/state, generation)
	if(islist(state) && state["schema"] == 2) throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/prepare_zone_roof(savefile/F, x, y, z, child, type)
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/restore_zone_topology()
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/restore_zone_spawns()
	return

/obj/map_metadata/proc/uses_durable_metadata()
	return FALSE
/datum/persistence_world_operation/var/datum/persistence_zone_restore/zone_restore
/datum/persistence_zone_restore
	var/clearing_old_world = FALSE
/map_storage
	var/list/zone_export_state
	var/zone_export_generation
	var/list/zone_candidate_validation
/map_storage/proc/clear_zone_export()
	return
/map_storage/proc/begin_zone_export(generation)
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/finalize_zone_export(list/state)
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/capture_zone_turf(savefile/F, datum/save_export_frame/frame)
	return
/map_storage/proc/encode_zone_reference(area/A)
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/validate_zone_reference(id, type)
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/begin_zone_restore(datum/persistence_world_operation/operation)
	throw EXCEPTION("Topology needs the full-source fixture")
/map_storage/proc/validate_captured_world_save(list/candidate)
	throw EXCEPTION("Topology needs the full-source fixture")

/proc/invalidate_persistence_area_snapshots()
	return
