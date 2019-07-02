/obj/item/organ/brain
	name = "brain"
	health = 200 //They need to live awhile longer than other organs. Is this even used by organ code anymore?
	desc = "A piece of juicy meat found in a person's head."
	organ_tag = "brain"
	parent_organ = "head"
	vital = TRUE
	icon_state = "brain"
	force = 1.0
	w_class = 2.0
	throwforce = 1.0
	throw_speed = 3
	throw_range = 5
	relative_size = 60
	attack_verb = list("attacked", "slapped", "whacked")
	var/mob/living/carbon/brain/brainmob = null

/obj/item/organ/brain/New()
	..()
	health = config.default_brain_health

/obj/item/organ/brain/Destroy()
	..()

/obj/item/organ/brain/examine(mob/user) // -- TLE
	..(user)
	user << "This one seems particularly lifeless. Perhaps it will regain some of its luster later.."

/obj/item/organ/brain/removed(var/mob/living/user)

	name = "[owner.real_name]'s brain"

	..()

/obj/item/organ/brain/replaced(var/mob/living/target)

	if (target.key)
		target.ghostize()
	..()