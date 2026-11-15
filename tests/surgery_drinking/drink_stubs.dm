// Minimal stand-ins for the types and helpers do_surgery() touches.
#define SURGERY_FAILURE -1
#define I_HELP "help"
#define I_HARM "harm"

var/list/surgery_steps = list()
var/list/chat_log = list()

/proc/to_chat(target, message)
	chat_log += "[message]"

/proc/do_after(mob/user, delay, atom/target)
	return TRUE

/proc/note_field_work(mob/user, kind)
	return

/proc/surgery_node_time(mob/user)
	return 1

/proc/ishuman(thing)
	return istype(thing, /mob/living/human)

/datum/op_stage
	var/list/in_progress = list()

/mob
	var/targeted_organ = "chest"
	var/a_intent = I_HELP
	var/religious_clergy = null

/mob/proc/Adjacent(atom/thing)
	return TRUE

/mob/living/human
	var/datum/op_stage/op_stage

/mob/living/human/New()
	..()
	op_stage = new

/mob/living/human/proc/adaptStat(statname, amount)
	return

/mob/living/human/proc/update_surgery()
	return

/obj/item
	var/open = FALSE

/obj/item/proc/is_open_container()
	return open

/obj/item/weapon/reagent_containers/glass/bucket
/obj/item/weapon/surgery/scalpel

/datum/surgery_step
	var/tool_type = /obj/item/weapon/surgery/scalpel
	var/quality = 100
	var/applies = FALSE
	var/min_duration = 1
	var/max_duration = 1
	var/begun = 0
	var/finished = 0

/datum/surgery_step/proc/tool_quality(obj/item/tool, mob/living/human/user)
	return istype(tool, tool_type) ? quality : 0

/datum/surgery_step/proc/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	return applies

/datum/surgery_step/proc/is_valid_target(mob/living/human/target)
	return TRUE

/datum/surgery_step/proc/begin_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	begun++

/datum/surgery_step/proc/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	finished++

/datum/surgery_step/proc/fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	return
