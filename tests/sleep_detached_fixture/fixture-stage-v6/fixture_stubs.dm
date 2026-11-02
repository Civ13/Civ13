// Synthetic native-test scaffolding only; no production game behavior.
#define TRUE 1
#define FALSE 0
#define EXCEPTION(message) new /exception(message)
/datum/var/should_save = TRUE
/datum/proc/get_saved_vars()
    return list()
/datum/proc/persistence_runtime_var(key)
    return FALSE
/datum/proc/before_save()
    return
/datum/proc/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
    return before_save()
/atom/var/load_contents = TRUE
/mob/var/stat = FALSE
/mob/living
/mob/living/human
    var/persistence_owner_ckey
/obj/item
/datum/save_export_frame
/map_storage
/proc/isDeleted(datum/D)
    return isnull(D)
/proc/sleep_handoff_round_valid(value)
    return istext(value) && length(value) >= 1 && length(value) <= 128
/proc/sleep_handoff_account_valid(value)
    return istext(value) && length(value) && ckey(value) == value
/proc/sleep_handoff_nonce_valid(value)
    if(!istext(value) || length(value) != 32) return FALSE
    for(var/i = 1, i <= 32, i++)
        if(!findtextEx("0123456789abcdef", copytext(value, i, i+1))) return FALSE
    return TRUE
// Compile-only seams for pinned production loader procedures. They are used
// only in a separate synthetic reader process and are not a game provider.
#define TICK_CHECK sleep_fixture_tick()
/proc/sleep_fixture_tick()
    return
#define ishuman(A) istype(A, /mob/living/human)
#define DEAD 2
var/obj/map_metadata/map
/obj/map_metadata
/obj/screen
/datum/hud
/datum/action
/obj/item/weapon/grab
/datum/light_source
/datum/lighting_corner
/atom/movable/lighting_overlay
/atom/movable/lighting_fullbright
/datum/wound/lost_limb
    proc/validate_restored_state()
        return TRUE
/mob/living/simple_animal
    proc/npc_subtile_prepare_import(savefile/F)
        return
/mob/living/human
    var/persistence_restored = FALSE
    proc/human_subtile_prepare_import(savefile/F)
        return
    proc/rejuvenate()
        return
/turf
    var/weather_snow = 0
    proc/activate_reserved_lighting()
        return
    proc/ChangeTurf(path, preserve, force)
        return
    proc/snowfall_ground_icon()
        return
    proc/sync_fullbright_coverage()
        return
/turf/floor
    proc/irrigation_prepare_load()
        return
/area/var/persistence_zone_id
/datum/sleep_fixture_import
    proc/accept_entry(z, ref, datum/object)
        throw EXCEPTION("Synthetic durable importer unavailable")
/map_storage
    var/list/existing_references = list()
    var/list/saved_turfs = list()
    var/list/validated_roof_entries = list()
    var/list/loading_level_link_targets = list()
    var/list/loading_level_link_fields = list()
    var/list/all_loaded = list()
    var/list/loaded_lists = list()
    var/list/restored_zones = list()
    var/datum/sleep_fixture_import/durable_import
    var/loading_z = 1
    var/so_far = 0
    var/per_pause = 200
    proc/is_loaded_validated_roof(atom/roof)
        return FALSE
    proc/level_link_row(list/value)
        throw EXCEPTION("Synthetic level links unsupported")
    proc/validate_zone_reference(id, type)
        throw EXCEPTION("Synthetic zones unsupported")
    proc/Numeric(text)
        return text2num(text)
/proc/string_explode(text, separator)
    return splittext(text, separator)
/proc/qdel(datum/D)
    del(D)