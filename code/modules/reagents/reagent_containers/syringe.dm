////////////////////////////////////////////////////////////////////////////////
/// Syringes.
////////////////////////////////////////////////////////////////////////////////
#define SYRINGE_DRAW FALSE
#define SYRINGE_INJECT TRUE
#define SYRINGE_BROKEN 2

/obj/item/weapon/reagent_containers/syringe
	name = "syringe"
	desc = "A syringe."
	icon = 'icons/obj/syringe.dmi'
	item_state = "syringe_0"
	icon_state = "0"
	matter = list("glass" = 150)
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = null
	volume = 15
	w_class = TRUE
	slot_flags = SLOT_EARS
	sharp = TRUE
	var/mode = SYRINGE_DRAW
	var/image/filling //holds a reference to the current filling overlay
	var/visible_name = "a syringe"
	var/time = 30
	var/used = FALSE
	var/single_use = FALSE

	on_reagent_change()
		update_icon()

	pickup(mob/user)
		..()
		update_icon()

	dropped(mob/user)
		..()
		update_icon()

	attack_self(mob/user as mob)

		switch(mode)
			if (SYRINGE_DRAW)
				mode = SYRINGE_INJECT
			if (SYRINGE_INJECT)
				mode = SYRINGE_DRAW
			if (SYRINGE_BROKEN)
				return

		update_icon()

	attack_hand()
		..()
		update_icon()

	attackby(obj/item/I as obj, mob/user as mob)
		return

	afterattack(obj/target, mob/user, proximity)
		if (!proximity || !target.reagents)
			return

		if (single_use && used)
			user << "<span class='warning'>This [src] is used already!</span>"
			return

		if (mode == SYRINGE_BROKEN)
			user << "<span class='warning'>This syringe is broken!</span>"
			return

	/*	if (user.a_intent == I_HURT && ismob(target))
			if ((CLUMSY in user.mutations) && prob(50))
				target = user
			syringestab(target, user)
			return*/


		switch(mode)
			if (SYRINGE_DRAW)

				if (!reagents.get_free_space())
					user << "<span class='warning'>The syringe is full.</span>"
					mode = SYRINGE_INJECT
					return

				if (ismob(target))//Blood!
					if (reagents.has_reagent("blood"))
						user << "<span class='notice'>There is already a blood sample in this syringe.</span>"
						return
					if (istype(target, /mob/living/carbon))
						var/amount = reagents.get_free_space()
						var/mob/living/carbon/T = target
						if (!T.dna)
							user << "<span class='warning'>You are unable to locate any blood. (To be specific, your target seems to be missing their DNA datum).</span>"
							return
						var/datum/reagent/B
						if (istype(T, /mob/living/carbon/human))
							var/mob/living/carbon/human/H = T
							if (H.species && H.species.flags & NO_BLOOD)
								H.reagents.trans_to_obj(src, amount)
							else
								B = T.take_blood(src, amount)
						else
							B = T.take_blood(src,amount)

						if (B)
							reagents.reagent_list += B
							reagents.update_total()
							on_reagent_change()
							reagents.handle_reactions()
						user << "<span class='notice'>You take a blood sample from [target].</span>"
						for (var/mob/O in viewers(4, user))
							O.show_message("<span class='notice'>[user] takes a blood sample from [target].</span>", TRUE)

				else //if not mob
					if (!target.reagents.total_volume)
						user << "<span class='notice'>[target] is empty.</span>"
						return

					if (!target.is_open_container() && !istype(target, /obj/structure/reagent_dispensers))
						user << "<span class='notice'>You cannot directly remove reagents from this object.</span>"
						return

					var/trans = target.reagents.trans_to_obj(src, amount_per_transfer_from_this)
					user << "<span class='notice'>You fill the syringe with [trans] units of the solution.</span>"
					update_icon()

				if (!reagents.get_free_space())
					mode = SYRINGE_INJECT
					update_icon()

			if (SYRINGE_INJECT)
				if (!reagents.total_volume)
					user << "<span class='notice'>The syringe is empty.</span>"
					mode = SYRINGE_DRAW
					return
/*				if (istype(target, /obj/item/weapon/implantcase/chem))
					return*/

				if (!target.is_open_container() && !ismob(target) && !istype(target, /obj/item/weapon/reagent_containers/food) && !istype(target, /obj/item/clothing/mask/smokable/cigarette))
					user << "<span class='notice'>You cannot directly fill this object.</span>"
					return
				if (!target.reagents.get_free_space())
					user << "<span class='notice'>[target] is full.</span>"
					return

				var/mob/living/carbon/human/H = target
				if (istype(H))
					var/tgt = user.targeted_organ
					if (user.targeted_organ == "random")
						tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
					var/obj/item/organ/external/affected = H.get_organ(tgt)
					if (!affected)
						user << "<span class='danger'>\The [H] is missing that limb!</span>"
						return

				if (ismob(target) && target != user)

					var/injtime = time //Injecting through a hardsuit takes longer due to needing to find a port.

					if (istype(H))
						if (H.wear_suit)
							if (!H.can_inject(user, TRUE))
								return

					else if (isliving(target))

						var/mob/living/M = target
						if (!M.can_inject(user, TRUE))
							return

					if (injtime == time)
						user.visible_message("<span class='warning'>[user] is trying to inject [target] with [visible_name]!</span>")
					else
						user.visible_message("<span class='warning'>[user] begins hunting for an injection port on [target]'s suit!</span>")

					user.setClickCooldown(DEFAULT_QUICK_COOLDOWN)
					user.do_attack_animation(target)

					if (!do_mob(user, target, injtime))
						return

					user.visible_message("<span class='warning'>[user] injects [target] with the syringe!</span>")

				var/trans
				if (ismob(target))
					if (reagents.has_reagent("adrenaline", 20) && ishuman(target))
						H.AdjustParalysis(-3)
						H.AdjustStunned(-8)
						H.AdjustWeakened(-10)
						H.emote("scream")
					var/contained = reagentlist()
					trans = reagents.trans_to_mob(target, amount_per_transfer_from_this, CHEM_BLOOD)
					admin_inject_log(user, target, src, contained, trans)
				else
					trans = reagents.trans_to(target, amount_per_transfer_from_this)
				user << "<span class='notice'>You inject [trans] units of the solution. The syringe now contains [reagents.total_volume] units.</span>"
				if (single_use)
					used = TRUE
				if (reagents.total_volume <= 0 && mode == SYRINGE_INJECT)
					mode = SYRINGE_DRAW
					update_icon()

		return

	update_icon()
		overlays.Cut()

		if (mode == SYRINGE_BROKEN)
			icon_state = "broken"
			return

		var/rounded_vol = round(reagents.total_volume, round(reagents.maximum_volume / 3))
		if (ismob(loc))
			var/injoverlay
			switch(mode)
				if (SYRINGE_DRAW)
					injoverlay = "draw"
				if (SYRINGE_INJECT)
					injoverlay = "inject"
			overlays += injoverlay
		icon_state = "[rounded_vol]"
		item_state = "syringe_[rounded_vol]"

		if (reagents.total_volume)
			filling = image('icons/obj/reagentfillings.dmi', src, "syringe10")

			filling.icon_state = "syringe[rounded_vol]"

			filling.color = reagents.get_color()
			overlays += filling

	proc/syringestab(mob/living/carbon/target as mob, mob/living/carbon/user as mob)

		if (istype(target, /mob/living/carbon/human))

			var/mob/living/carbon/human/H = target
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			var/target_zone = ran_zone(check_zone(tgt, target))
			var/obj/item/organ/external/affecting = H.get_organ(target_zone)

			if (!affecting || affecting.is_stump())
				user << "<span class='danger'>They are missing that limb!</span>"
				return

			var/hit_area = affecting.name

			if ((user != target) && H.check_shields(7, src, user, "\the [src]"))
				return

			if (target != user && H.getarmor(target_zone, "melee") > 5 && prob(50))
				for (var/mob/O in viewers(7, user))
					O.show_message(text("<span class = 'red'><b>[user] tries to stab [target] in \the [hit_area] with [name], but the attack is deflected by armor!</b></span>"), TRUE)
				user.remove_from_mob(src)
				qdel(src)

				user.attack_log += "\[[time_stamp()]\]<font color='red'> Attacked [target.name] ([target.ckey]) with \the [src] (INTENT: HARM).</font>"
				target.attack_log += "\[[time_stamp()]\]<font color='orange'> Attacked by [user.name] ([user.ckey]) with [name] (INTENT: HARM).</font>"
				msg_admin_attack("[key_name_admin(user)] attacked [key_name_admin(target)] with [name] (INTENT: HARM) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

				return

			user.visible_message("<span class='danger'>[user] stabs [target] in \the [hit_area] with [name]!</span>")

			if (affecting.take_damage(3))
				H.UpdateDamageIcon()

		else
			user.visible_message("<span class='danger'>[user] stabs [target] with [name]!</span>")
			target.take_organ_damage(3)// 7 is the same as crowbar punch



		var/syringestab_amount_transferred = rand(0, (reagents.total_volume - 5)) //nerfed by popular demand
		var/contained_reagents = reagents.get_reagents()
		var/trans = reagents.trans_to_mob(target, syringestab_amount_transferred, CHEM_BLOOD)
		if (isnull(trans)) trans = FALSE
		admin_inject_log(user, target, src, contained_reagents, trans, violent=1)
		break_syringe(target, user)

	proc/break_syringe(mob/living/carbon/target, mob/living/carbon/user)
		desc += " It is broken."
		mode = SYRINGE_BROKEN
		if (target)
			add_blood(target)
		if (user)
			add_fingerprint(user)
		update_icon()

////////////////////////////////////////////////////////////////////////////////
/// Syringes. END
////////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/reagent_containers/syringe/antitoxin
	name = "Syringe (anti-toxin)"
	desc = "Contains anti-toxins."
	New()
		..()
		reagents.add_reagent("anti_toxin", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/weapon/reagent_containers/syringe/penicillin
	name = "Syringe (penicillin)"
	desc = "Contains antiviral agents."
	New()
		..()
		reagents.add_reagent("penicillin", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/weapon/reagent_containers/syringe/ld50_syringe/choral
	New()
		..()
		reagents.add_reagent("chloralhydrate", 60)
		mode = SYRINGE_INJECT
		update_icon()

// morphine syringes
/obj/item/weapon/reagent_containers/syringe/morphine
	name = "Morphine injector"
	desc = "Injector containing 5 units of morphine. Administer two of these to make someone sleep."
	icon_state = "single_use0"
	w_class = 1
	volume = 5
	amount_per_transfer_from_this = 5
	single_use = TRUE
/obj/item/weapon/reagent_containers/syringe/morphine/New()
	..()
	reagents.add_reagent("morphine", 5)
	mode = SYRINGE_INJECT

/obj/item/weapon/reagent_containers/syringe/morphine/update_icon()
	if (reagents.total_volume > 0)
		icon_state = "single_use0"
	else
		icon_state = "single_use0_empty"
		used = TRUE

/obj/item/weapon/reagent_containers/syringe/sulfanomides
	name = "sulfanomide injector"
	desc = "Injector containing a single dose of IV sulfanomides. Used to prevent and treat systemic microbial infections."
	icon_state = "single_use2"
	w_class = 1
	volume = 9
	amount_per_transfer_from_this = 9
	single_use = TRUE
/obj/item/weapon/reagent_containers/syringe/sulfanomides/New()
	..()
	reagents.add_reagent("penicillin", 9)
	mode = SYRINGE_INJECT

/obj/item/weapon/reagent_containers/syringe/sulfanomides/update_icon()
	if (reagents.total_volume > 0)
		icon_state = "single_use2"
	else
		icon_state = "single_use2_empty"
		used = TRUE

/obj/item/weapon/reagent_containers/syringe/adrenaline
	name = "adrenaline injector"
	desc = "Injector containing a single dose of adrenalin. Good to stabilize patients and help moderate shock."
	icon_state = "single_use3"
	w_class = 1
	volume = 30
	amount_per_transfer_from_this = 30
	single_use = TRUE
/obj/item/weapon/reagent_containers/syringe/adrenaline/New()
	..()
	reagents.add_reagent("adrenaline", 30)
	mode = SYRINGE_INJECT

/obj/item/weapon/reagent_containers/syringe/adrenaline/update_icon()
	if (reagents.total_volume > 0)
		icon_state = "single_use3"
	else
		icon_state = "single_use3_empty"
		used = TRUE