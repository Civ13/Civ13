// Only the observation proc is production code. These adapters supply its type
// schema and inert unrelated enrichment/auth/queue helpers. None implements
// view(), invisibility, opacity, location, range or the nearby change list.
#define TRUE 1
#define FALSE 0

/atom/movable
	var/anchored = FALSE
/mob
	var/stat = 0
/mob/living
/mob/living/human
	var/driver = FALSE
	var/obj/structure/vehicle/driver_vehicle
	var/obj/item/wear_suit
/obj/item
/obj/item/stack
	var/amount = 1
/obj/item/stack/material
/obj/item/clothing/suit/lifejacket
/obj/structure/branch
	var/leaves = FALSE
	var/branched = FALSE
/obj/structure/wild
	var/max_branches = 0
	var/branches = 0
/obj/structure/wild/rock
/obj/structure/wild/tree
/obj/structure/wild/palm
/obj/structure/wild/jungle
/obj/structure/converter/tanning
/obj/structure/vehicle
/obj/structure/oven
	var/on = FALSE
	var/fuel = 0
/obj/structure/sink
	var/dirty = FALSE
/obj/structure/sink/puddle
/obj/roof/proc/is_supported()
	return TRUE
/turf/floor/beach/water
	var/sickness = 0
	var/salty = FALSE
/turf/floor/trench/flooded
/turf/floor/dirt/underground/proc/mine_supported()
	return TRUE
/turf/floor/dirt/underground/empty
/area
	var/location = AREA_INSIDE

/datum/agent_identity
	var/name = "visibility-fixture"
/datum/agent_character
	var/mob/living/body
	var/awaiting_driver = TRUE
	var/list/seen
	var/seen_rev = 0
	var/queue_guard
	var/queue_guard_at = 0
	var/queue_guard_agent
	var/list/messages = list()
	var/message_serial = 0
	var/list/prompts = list()
	var/prompt_serial = 0
	var/list/sounds = list()
	var/sound_serial = 0
/datum/agent_character/proc/queue_state(since)
	return list()
/datum/agent_control
	var/datum/agent_character/fixture_character
/datum/agent_control/proc/character_arg(datum/agent_identity/A, list/req)
	return fixture_character
/datum/agent_control/proc/audit_read(datum/agent_identity/A, action, detail)
	return
/datum/agent_control/proc/character_state(datum/agent_character/C)
	return list("ref" = agent_ref(C.body), "x" = C.body.x, "y" = C.body.y, "z" = C.body.z)

/proc/agent_ref(datum/D)
	return "\ref[D]"
/proc/get_turf(atom/A)
	while (A && !isturf(A))
		A = A.loc
	return A
/proc/get_area(atom/A)
	while (A && !isarea(A))
		A = A.loc
	return A
/proc/ishuman(atom/A)
	return istype(A, /mob/living/human)
/proc/dir2text(direction)
	return "[direction]"
/proc/agent_wound_rows(mob/living/human/H)
	return list()
/proc/agent_vehicle_row(obj/structure/vehicle/V, mob/living/M)
	return list()
/proc/agent_verb_names(atom/A, limit)
	return list()
/proc/agent_deep_water(turf/T)
	return FALSE
