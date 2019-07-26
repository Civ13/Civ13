/obj/item/weapon/prosthesis
	name = "prosthesis"
	desc = "Used to replace missing limbs."
	icon = 'icons/mob/human_races/masks/prosthesis.dmi'
	icon_state = "pegleg"
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "crowbar"
	w_class = 3.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")
	var/limb_type = "none"

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

/obj/item/weapon/prosthesis/attack(mob/living/carbon/human/C as mob, mob/living/carbon/human/user as mob)
	if (user.a_intent == I_HELP)
		if (user.getStatCoeff("medical") < 1.5)
			user << "Your medical skill is too low for such a complicated procedure!"
			return
		var/mod = 1
		if (user.religious_clergy == "Shamans")
			mod = 2
		switch (limb_type)
			if ("leg")
				var/obj/item/organ/external/GR = C.get_organ("groin")
				if (GR.is_stump())
					user << "The whole lower body is missing! You have nowhere to attach \the [src] to!"
					return
				var/obj/item/organ/external/LL = C.get_organ("l_leg")
				var/obj/item/organ/external/RL = C.get_organ("r_leg")
				if (LL.is_stump() && LL.prosthesis == FALSE)
					visible_message("[user] starts to attatch \the [src] to [C]'s left leg stump...","You start attaching \the [src] to [C]'s left leg stump...")
					if (do_after(user, 150*user.getStatCoeff("medical"), C))
						visible_message("[user] finishes attaching \the [src] to [C]'s left leg stump.","You finish attaching \the [src] to [C]'s left leg stump.")
						LL.prosthesis = TRUE
						LL.prosthesis_type = icon_state
						C.update_mutations(1)
						user.adaptStat("medical", 4*mod)
						qdel(src)
					return
				else if (RL.is_stump() && RL.prosthesis == FALSE)
					visible_message("[user] starts to attatch \the [src] to [C]'s right leg stump...","You start attaching \the [src] to [C]'s right leg stump...")
					if (do_after(user, 150*user.getStatCoeff("medical"), C))
						visible_message("[user] finishes attaching \the [src] to [C]'s right leg stump.","You finish attaching \the [src] to [C]'s right leg stump.")
						RL.prosthesis = TRUE
						RL.prosthesis_type = icon_state
						C.update_mutations(1)
						user.adaptStat("medical", 4*mod)
						qdel(src)
					return
			if ("foot")
				var/obj/item/organ/external/LL = C.get_organ("l_leg")
				var/obj/item/organ/external/RL = C.get_organ("r_leg")
				if (RL.is_stump() && RL.prosthesis == FALSE)
					if (LL.is_stump() && LL.prosthesis == FALSE)
						user << "Both legs are missing! There is nowhere to attach the [src]!"
						return

				var/obj/item/organ/external/LF = C.get_organ("l_foot")
				var/obj/item/organ/external/RF = C.get_organ("r_foot")
				if (LF && LF.is_stump() && LF.prosthesis == FALSE && !LL.is_stump())
					visible_message("[user] starts to attatch \the [src] to [C]'s left foot stump...","You start attaching \the [src] to [C]'s left foot stump...")
					if (do_after(user, 130*user.getStatCoeff("medical"), C))
						visible_message("[user] finishes attaching \the [src] to [C]'s left foot stump.","You finish attaching \the [src] to [C]'s left foot stump.")
						LF.prosthesis = TRUE
						LF.prosthesis_type = icon_state
						C.update_mutations(1)
						user.adaptStat("medical", 3*mod)
						qdel(src)
					return
				else if (RF.is_stump() && RF.prosthesis == FALSE && !RL.is_stump())
					visible_message("[user] starts to attatch \the [src] to [C]'s right foot stump...","You start attaching \the [src] to [C]'s right foot stump...")
					if (do_after(user, 130*user.getStatCoeff("medical"), C))
						visible_message("[user] finishes attaching \the [src] to [C]'s right foot stump.","You finish attaching \the [src] to [C]'s right foot stump.")
						RF.prosthesis = TRUE
						RF.prosthesis_type = icon_state
						C.update_mutations(1)
						user.adaptStat("medical", 3*mod)
						qdel(src)
					return
	else
		..()