// Offline adapters: no game startup, players, network, SQL, or production files.
var/TimeOfGame = 0
var/obj/map_metadata/map
var/list/errors = list()
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
/mob/living/human
	var/tmp/rejuvenate_calls = 0
/mob/living/human/proc/rejuvenate()
	rejuvenate_calls++
	stat = CONSCIOUS
/datum/controller/gameticker
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
// Ordinary-map fixture only. Surface admission is tested by extraction probes;
// accidental activation here must fail instead of supplying synthetic success.
/obj/map_metadata/extraction_survival
	var/datum/extraction_surface_service/surface_service
/datum/extraction_surface_service
	var/world_inventory_complete = FALSE
	proc/begin_world_inventory(levels)
		throw EXCEPTION("Surface service outside ordinary world-save fixture")
	proc/feed_loaded_level(level, list/objects)
		throw EXCEPTION("Surface service outside ordinary world-save fixture")
	proc/discovery_fail()
		throw EXCEPTION("Surface service outside ordinary world-save fixture")
	proc/finish_world_inventory()
		throw EXCEPTION("Surface service outside ordinary world-save fixture")
/turf/proc/ChangeTurf(path, tell_universe, force_lighting_update)
	return new path(src)
