/obj/item/weapon/prosthesis
	name = "prosthesis"
	desc = "Used to replace missing limbs."
	icon = 'icons/mob/human_races/masks/prosthesis.dmi'
	icon_state = "pegleg"
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "crowbar"
	w_class = ITEM_SIZE_NORMAL

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")
	var/limb_type = "none"
	flags = FALSE

/obj/item/weapon/prosthesis/pegleg
	name = "wooden pegleg"
	desc = "A simple wood pegleg, used to replace a missing leg."
	icon_state = "pegleg"
	limb_type = "leg"
	flammable = TRUE

/obj/item/weapon/prosthesis/woodfoot
	name = "wooden foot"
	desc = "A simple wood shoe, used to replace a missing foot."
	icon_state = "woodfoot"
	limb_type = "foot"
	flammable = TRUE

/obj/item/weapon/prosthesis/attack(mob/living/human/C as mob, mob/living/human/user as mob)
	if (user.a_intent != I_HELP)
		return ..()

	if (user.getStatCoeff("medical") < 1.5)
		to_chat(user, "Your medical skill is too low for a such complicated procedure!")
		return
	
	var/mod = 1
	if (user.religious_clergy == "Shamans")
		mod = 2
	switch (limb_type)
		if ("leg")
			var/obj/item/organ/external/GR = C.get_organ("groin")
			if (GR.is_stump())
				to_chat(user, "The whole lower body is missing! You have nowhere to attach \the [src] to!")
				return
			var/obj/item/organ/external/LL = C.get_organ("l_leg")
			var/obj/item/organ/external/RL = C.get_organ("r_leg")
			if ((LL && LL.is_stump() && LL.prosthesis == FALSE || !LL))
				visible_message("[user] starts to attach \the [src] to [C]'s left leg stump...","You start attaching \the [src] to [C]'s left leg stump...")
				if (do_after(user, 150*user.getStatCoeff("medical"), C))
					finish_attachment(C, user, LL, "left leg", 4*mod)
				return
			else if ((RL && RL.is_stump() && RL.prosthesis == FALSE || !RL))
				visible_message("[user] starts to attach \the [src] to [C]'s right leg stump...","You start attaching \the [src] to [C]'s right leg stump...")
				if (do_after(user, 150*user.getStatCoeff("medical"), C))
					finish_attachment(C, user, RL, "right leg", 4*mod)
				return
		if ("foot")
			var/obj/item/organ/external/LL = C.get_organ("l_leg")
			var/obj/item/organ/external/RL = C.get_organ("r_leg")
			if ((RL && RL.is_stump() && RL.prosthesis == FALSE) || !RL)
				if ((LL && LL.is_stump() && LL.prosthesis == FALSE) || !LL)
					to_chat(user, "Both legs are missing! There is nowhere to attach the [src]!")
					return

			var/obj/item/organ/external/LF = C.get_organ("l_foot")
			var/obj/item/organ/external/RF = C.get_organ("r_foot")
			if (LF && LF.is_stump() && LF.prosthesis == FALSE && !LL.is_stump())
				visible_message("[user] starts to attach \the [src] to [C]'s left foot stump...","You start attaching \the [src] to [C]'s left foot stump...")
				if (do_after(user, 130*user.getStatCoeff("medical"), C))
					finish_attachment(C, user, LF, "left foot", 3*mod)
				return
			else if (RF && RF.is_stump() && RF.prosthesis == FALSE && !RL.is_stump())
				visible_message("[user] starts to attach \the [src] to [C]'s right foot stump...","You start attaching \the [src] to [C]'s right foot stump...")
				if (do_after(user, 130*user.getStatCoeff("medical"), C))
					finish_attachment(C, user, RF, "right foot", 3*mod)
				return

/obj/item/weapon/prosthesis/proc/finish_attachment(mob/living/human/patient, mob/living/human/user, obj/item/organ/external/limb, limb_description, medical_experience)
	if (!limb)
		return
	visible_message("[user] finishes attaching \the [src] to [patient]'s [limb_description] stump.","You finish attaching \the [src] to [patient]'s [limb_description] stump.")
	limb.prosthesis = TRUE
	limb.prosthesis_type = icon_state
	patient.update_mutations(1)
	user.adaptStat("medical", medical_experience)
	qdel(src)
