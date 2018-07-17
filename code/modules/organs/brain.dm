/obj/item/organ/brain
	name = "brain"
	health = 400 //They need to live awhile longer than other organs. Is this even used by organ code anymore?
	desc = "A piece of juicy meat found in a person's head."
	organ_tag = "brain"
	parent_organ = "head"
	vital = TRUE
	icon_state = "brain2"
	force = 1.0
	w_class = 2.0
	throwforce = 1.0
	throw_speed = 3
	throw_range = 5
//	origin_tech = list(TECH_BIO = 3)
	attack_verb = list("attacked", "slapped", "whacked")
	var/mob/living/carbon/brain/brainmob = null

/obj/item/organ/brain/New()
	..()
	health = config.default_brain_health
	spawn(5)
		if (brainmob && brainmob.client)
			brainmob.client.screen.len = null //clear the hud

/obj/item/organ/brain/Destroy()
	if (brainmob)
		qdel(brainmob)
		brainmob = null
	..()

/obj/item/organ/brain/proc/transfer_identity(var/mob/living/carbon/H)
	name = "\the [H]'s [initial(name)]"
	brainmob = new(src)
	brainmob.name = H.real_name
	brainmob.real_name = H.real_name
	brainmob.dna = H.dna.Clone()
//	brainmob.timeofhostdeath = H.timeofdeath
	if (H.mind)
		H.mind.transfer_to(brainmob)

	brainmob << "<span class='notice'>You feel slightly disoriented. That's normal when you're just a [initial(name)].</span>"
	callHook("debrain", list(brainmob))

	if (brainmob.client)
		brainmob.ghostize() // gibbed people now automatically ghost - Kachnov

/obj/item/organ/brain/examine(mob/user) // -- TLE
	..(user)
	if (brainmob && brainmob.client)//if thar be a brain inside... the brain.
		user << "You can feel the small spark of life still left in this one."
	else
		user << "This one seems particularly lifeless. Perhaps it will regain some of its luster later.."

/obj/item/organ/brain/removed(var/mob/living/user)

	name = "[owner.real_name]'s brain"

	var/obj/item/organ/brain/B = src
	if (istype(B) && istype(owner))
		B.transfer_identity(owner)

	..()

/obj/item/organ/brain/replaced(var/mob/living/target)

	if (target.key)
		target.ghostize()

	if (brainmob)
		if (brainmob.mind)
			brainmob.mind.transfer_to(target)
		else
			target.key = brainmob.key
	..()