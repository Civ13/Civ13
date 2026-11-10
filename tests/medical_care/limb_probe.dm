#define SURGERY_FAILURE -1
/datum/species
	var/list/has_limbs = list("l_arm" = list(), "r_arm" = list())
/mob/living/human
	var/datum/species/species = new
	var/list/limbs = list()
	proc/get_organ(zone)
		return limbs[zone]
	proc/update_body()
	proc/updatehealth()
	proc/UpdateDamageIcon()
/mob/living/proc/visible_message(message, self_message)
/mob/living/proc/drop_from_inventory(obj/item/E)
/obj/item/organ/external
	var/limb_name
	var/amputation_point = "arm"
	proc/replaced(mob/living/human/H)
		H.limbs[limb_name] = src
/proc/hasorgans(mob/living/human/H)
	return !!H.species
/proc/to_chat(mob/M, message)
/datum/surgery_step
	proc/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		return FALSE
	proc/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
/datum/surgery_step/limb
/datum/surgery_step/limb/attach
