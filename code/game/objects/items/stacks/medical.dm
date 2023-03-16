/obj/item/stack/medical
	name = "medical pack"
	singular_name = "medical pack"
	icon = 'icons/obj/items.dmi'
	amount = 30
	max_amount = 30
	w_class = ITEM_SIZE_SMALL
	throw_speed = 4
	throw_range = 20
	var/heal_brute = 0
	var/heal_burn = 0
	value = 0
/obj/item/stack/medical/attack(mob/living/human/C as mob, mob/user as mob)
	if (!istype(C) )
		if (!istype(C, /mob/living/simple_animal))
			user << "<span class='warning'>\The [src] cannot be applied to [C]!</span>"
		return TRUE

	if (!istype(user, /mob/living/human))
		user << "<span class='warning'>You don't have the dexterity to do this!</span>"
		return TRUE

	if (istype(C, /mob/living/human))
		var/mob/living/human/H = C

		H.UpdateDamageIcon()

		H.updatehealth()

	else if (istype(C, /mob/living/human))
		C.heal_organ_damage((heal_brute/2), (heal_burn/2))
		user.visible_message( \
			"<span class='notice'>[C] has been applied with [src] by [user].</span>", \
			"<span class='notice'>You apply \the [src] to [C].</span>" \
		)
		use(1)

		C.updatehealth()

/obj/item/stack/medical/bruise_pack
	name = "roll of gauze"
	singular_name = "gauze length"
	desc = "Some sterile gauze to wrap around bloody stumps."
	icon_state = "brutepack"
	flammable = TRUE

/obj/item/stack/medical/bruise_pack/attack(mob/living/M as mob, mob/user as mob)
	if (..())
		return TRUE

	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)

		if (affecting && affecting.open == FALSE)
			if (affecting.is_bandaged())
				user << "<span class='warning'>The wounds on [M]'s [affecting.name] have already been bandaged.</span>"
				return TRUE
			else
				user.visible_message("<span class='notice'>\The [user] starts treating [M]'s [affecting.name].</span>", \
									 "<span class='notice'>You start treating [M]'s [affecting.name].</span>" )
				var/used = FALSE
				for (var/datum/wound/W in affecting.wounds)
					if (W.internal)
						continue
					if (W.bandaged)
						continue
					if (used == amount)
						break
					if (!do_mob(user, M, W.damage/5))
						user << "<span class='notice'>You must stand still to bandage wounds.</span>"
						break

					if (W.current_stage <= W.max_bleeding_stage)
						user.visible_message("<span class='notice'>\The [user] bandages \a [W.desc] on [M]'s [affecting.name].</span>", \
													  "<span class='notice'>You bandage \a [W.desc] on [M]'s [affecting.name].</span>" )
						//H.add_side_effect("Itch")
					else if (W.damage_type == BRUISE)
						user.visible_message("<span class='notice'>\The [user] places a bruise patch over \a [W.desc] on [M]'s [affecting.name].</span>", \
													  "<span class='notice'>You place a bruise patch over \a [W.desc] on [M]'s [affecting.name].</span>" )
					else
						user.visible_message("<span class='notice'>\The [user] places a bandaid over \a [W.desc] on [M]'s [affecting.name].</span>", \
													  "<span class='notice'>You place a bandaid over \a [W.desc] on [M]'s [affecting.name].</span>" )
					W.bandage()
					used++
				affecting.update_damages()
				if (used == amount)
					if (affecting.is_bandaged())
						user << "<span class='warning'>\The [src] is used up.</span>"
					else
						user << "<span class='warning'>\The [src] is used up, but there are more wounds to treat on \the [affecting.name].</span>"
				use(used)
				H.update_bandaging(0)
		else
			if (can_operate(H))		//Checks if mob is lying down on table for surgery
				if (do_surgery(H,user,src))
					return
			else
				if (affecting)
					user << "<span class='notice'>The [affecting.name] is cut open, you'll need more than a bandage!</span>"

/obj/item/stack/medical/advanced/bruise_pack
	name = "trauma kit"
	singular_name = "trauma kit"
	desc = "An advanced trauma kit for severe injuries."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "trauma_kit"
	item_state = "trauma_kit"
	heal_brute = 0
	flammable = TRUE

/obj/item/stack/medical/advanced/bruise_pack/attack(mob/living/human/M as mob, mob/user as mob)
	if (..())
		return TRUE

	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)

		if (affecting && (affecting.open == FALSE || (affecting.open && !affecting.is_disinfected())))
			if (affecting.is_bandaged() && affecting.is_disinfected())
				user << "<span class='warning'>The wounds on [M]'s [affecting.name] have already been treated.</span>"
				return TRUE
			else
				user.visible_message("<span class='notice'>\The [user] starts treating [M]'s [affecting.name].</span>", \
									 "<span class='notice'>You start treating [M]'s [affecting.name].</span>" )
				var/used = 0
				for (var/datum/wound/W in affecting.wounds)
					if (W.internal)
						continue
					if (W.bandaged && W.disinfected)
						continue
					if (used == amount)
						break
					if (!do_mob(user, M, W.damage/5))
						user << "<span class='notice'>You must stand still to bandage wounds.</span>"
						break
					if (W.current_stage <= W.max_bleeding_stage)
						user.visible_message("<span class='notice'>\The [user] cleans \a [W.desc] on [M]'s [affecting.name] and covers it with a bandage.</span>", \
											 "<span class='notice'>You clean and cover \a [W.desc] on [M]'s [affecting.name].</span>" )
					else if (W.damage_type == BRUISE)
						user.visible_message("<span class='notice'>\The [user] places a medical patch over \a [W.desc] on [M]'s [affecting.name].</span>", \
													  "<span class='notice'>You place a medical patch over \a [W.desc] on [M]'s [affecting.name].</span>" )
					else
						user.visible_message("<span class='notice'>\The [user] smears some ointment over \a [W.desc] on [M]'s [affecting.name].</span>", \
													  "<span class='notice'>You smear some ointment over \a [W.desc] on [M]'s [affecting.name].</span>" )
					W.bandage()
					W.disinfect()
					W.heal_damage(heal_brute)
					used++
				affecting.update_damages()
				if (used == amount)
					if (affecting.is_bandaged())
						user << "<span class='warning'>\The [src] is used up.</span>"
					else
						user << "<span class='warning'>\The [src] is used up, but there are more wounds to treat on \the [affecting.name].</span>"
				use(used)
		else
			if (can_operate(H))		//Checks if mob is lying down on table for surgery
				if (do_surgery(H,user,src))
					return
			else
				if (affecting)
					user << "<span class='notice'>The [affecting.name] is cut open, you'll need more than a bandage!</span>"

		var/mob/living/human/H_user = user
		if (istype(H_user) && H_user.getStatCoeff("medical") >= GET_MIN_STAT_COEFF(STAT_VERY_HIGH))
			if (affecting && affecting.open == FALSE)
				if (affecting.is_bandaged() && affecting.is_disinfected())
					affecting.wounds.Cut()
					H_user.bad_external_organs -= affecting

/obj/item/stack/medical/advanced/herbs
	name = "healing herbs"
	singular_name = "healing herb"
	desc = "A bunch of healing herbs collected from bushes. Helps clean the wounds."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "healing_herbs"
	item_state = null
	amount = 10
	heal_brute = 0
/obj/item/stack/medical/advanced/herbs/small
	amount = 1

/obj/item/stack/medical/advanced/herbs/attack(mob/living/human/M as mob, mob/user as mob)
	if (..())
		return TRUE

	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)

		if (affecting)
			if (affecting.is_salved() && affecting.is_disinfected())
				user << "<span class='warning'>The wounds on [M]'s [affecting.name] have already been treated.</span>"
				return TRUE

			if (!affecting.is_disinfected() || !affecting.is_salved())
				user.visible_message("<span class='notice'>\The [user] starts treating [M]'s [affecting.name].</span>", \
									 "<span class='notice'>You start treating [M]'s [affecting.name].</span>" )
				var/used = 0
				for (var/datum/wound/W in affecting.wounds)
					if (W.internal)
						continue
					if (W.salved && W.disinfected)
						continue
					if (used == amount)
						break
					if (!do_mob(user, M, W.damage/5))
						user << "<span class='notice'>You must stand still to bandage wounds.</span>"
						break

					user.visible_message("<span class='notice'>\The [user] rub some healing herbs over \a [W.desc] on [M]'s [affecting.name].</span>", \
													  "<span class='notice'>You rub some healing herbs over \a [W.desc] on [M]'s [affecting.name].</span>" )
					W.disinfect()
					W.salve()
					W.heal_damage(heal_brute)
					used++
				affecting.update_damages()
				if (used == amount)
					if (affecting.is_bandaged())
						user << "<span class='warning'>\The [src] is used up.</span>"
					else
						user << "<span class='warning'>\The [src] is used up, but there are more wounds to treat on \the [affecting.name].</span>"
				use(used)
		else
			if (can_operate(H))		//Checks if mob is lying down on table for surgery
				if (do_surgery(H,user,src))
					return
			else
				if (affecting)
					user << "<span class='notice'>The [affecting.name] is cut open, you'll need more than some healing herbs!</span>"

		var/mob/living/human/H_user = user
		if (istype(H_user) && H_user.getStatCoeff("medical") >= GET_MIN_STAT_COEFF(STAT_VERY_HIGH))
			if (affecting)
				if (affecting.is_salved() && affecting.is_disinfected())
					affecting.wounds.Cut()
					H_user.bad_external_organs -= affecting
	return

/obj/item/stack/medical/advanced/sulfa
	name = "sulfanilamide powder packs"
	singular_name = "powder pack"
	desc = "A pack of powdered sulfanilamide, a sulfamide anti-septic."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "sulfa"
	item_state = "trauma_kit"
	amount = 20
	heal_brute = 0
	flammable = TRUE
/obj/item/stack/medical/advanced/sulfa/small
	amount = 5

/obj/item/stack/medical/advanced/sulfa/attack(mob/living/human/M as mob, mob/user as mob)
	if (..())
		return TRUE

	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)

		if (affecting.is_disinfected())
			user << "<span class='warning'>The wounds on [M]'s [affecting.name] have already been disinfected.</span>"
			return TRUE
		else
			user.visible_message("<span class='notice'>\The [user] starts disinfecting [M]'s [affecting.name].</span>", \
								 "<span class='notice'>You start disinfecting [M]'s [affecting.name].</span>" )
			var/used = 0
			for (var/datum/wound/W in affecting.wounds)
				if (W.internal)
					continue
				if (W.bandaged && W.disinfected)
					continue
				if (used == amount)
					break
				if (!do_mob(user, M, W.damage/5))
					user << "<span class='notice'>You must stand still to treat wounds.</span>"
					break
				user.visible_message("<span class='notice'>\The [user] spread some sulfanilamide over \a [W.desc] on [M]'s [affecting.name].</span>", \
												  "<span class='notice'>You spread some sulfanilamide over \a [W.desc] on [M]'s [affecting.name].</span>" )
				W.disinfect()
				W.heal_damage(heal_brute)
				used++
			affecting.update_damages()
			if (used == amount)
				if (affecting.is_bandaged())
					user << "<span class='warning'>\The [src] is used up.</span>"
				else
					user << "<span class='warning'>\The [src] is used up, but there are more wounds to treat on \the [affecting.name].</span>"
			use(used)

/obj/item/stack/medical/advanced/ointment
	name = "burn kit"
	singular_name = "burn kit"
	desc = "An advanced treatment kit for severe burns."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "burn_kit"
	item_state = "burn_kit"
	heal_burn = FALSE
	amount = 10


/obj/item/stack/medical/advanced/ointment/attack(mob/living/human/M as mob, mob/user as mob)
	if (..())
		return TRUE

	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)

		if (affecting && affecting.open == FALSE)
			if (affecting.is_salved())
				user << "<span class='warning'>The wounds on [M]'s [affecting.name] have already been salved.</span>"
				return TRUE
			else
				user.visible_message("<span class='notice'>\The [user] starts salving wounds on [M]'s [affecting.name].</span>", \
									 "<span class='notice'>You start salving the wounds on [M]'s [affecting.name].</span>" )
				if (!do_mob(user, M, 10))
					user << "<span class='notice'>You must stand still to salve wounds.</span>"
					return TRUE
				user.visible_message( 	"<span class='notice'>[user] covers wounds on [M]'s [affecting.name] with a healing ointment.</span>", \
										"<span class='notice'>You cover wounds on [M]'s [affecting.name] with a healing ointment.</span>" )
				affecting.heal_damage(0,heal_burn)
				use(1)
				affecting.salve()
		else
			if (can_operate(H))		//Checks if mob is lying down on table for surgery
				if (do_surgery(H,user,src))
					return
			else
				user << "<span class='notice'>The [affecting.name] is cut open, you'll need more than a bandage!</span>"

/obj/item/stack/medical/splint
	name = "medical splints"
	singular_name = "medical splint"
	icon_state = "splint"
	amount = 5
	max_amount = 5
	flags = CONDUCT

/obj/item/stack/medical/splint/attack(mob/living/human/M as mob, mob/user as mob)
	if (..())
		return TRUE
	if (istype(M, /mob/living/human) && user.targeted_organ != "random")
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)
		var/limb = "chest"
		if (affecting)
			limb = affecting.name
			if (!(affecting.limb_name in list("chest", "head", "groin", "l_arm","r_arm","l_leg","r_leg", "l_hand", "r_hand", "l_foot", "r_foot")))
				user << "<span class='danger'>You can't apply a splint there!</span>"
				return
			else if (affecting.status & ORGAN_SPLINTED)
				user << "<span class='danger'>[M]'s [limb] is already splinted!</span>"
				return
			else if (affecting.status == 0)
				user << "<span class='danger'>[M]'s [limb] does not need splinting.</span>"
				return
		if (M != user)
			user.visible_message("<span class='danger'>[user] starts to apply \the [src] to [M]'s [limb].</span>", "<span class='danger'>You start to apply \the [src] to [M]'s [limb].</span>", "<span class='danger'>You hear something being wrapped.</span>")
		else
			if ((!user.hand && affecting.limb_name == "r_arm") || (user.hand && affecting.limb_name == "l_arm"))
				user << "<span class='danger'>You can't apply a splint to the arm you're using!</span>"
				return
			user.visible_message("<span class='danger'>[user] starts to apply \the [src] to their [limb].</span>", "<span class='danger'>You start to apply \the [src] to your [limb].</span>", "<span class='danger'>You hear something being wrapped.</span>")
		if (do_mob(user, M, 50))
			if (M != user)
				user.visible_message("<span class='danger'>[user] finishes applying \the [src] to [M]'s [limb].</span>", "<span class='danger'>You finish applying \the [src] to [M]'s [limb].</span>", "<span class='danger'>You hear something being wrapped.</span>")
			else
				if (prob(40 * H.getStatCoeff("medical")))
					user.visible_message("<span class='danger'>[user] successfully applies \the [src] to their [limb].</span>", "<span class='danger'>You successfully apply \the [src] to your [limb].</span>", "<span class='danger'>You hear something being wrapped.</span>")
				else
					user.visible_message("<span class='danger'>[user] fumbles \the [src].</span>", "<span class='danger'>You fumble \the [src].</span>", "<span class='danger'>You hear something being wrapped.</span>")
					return
			affecting.status |= ORGAN_SPLINTED
			use(1)
		return

/obj/item/stack/medical/bruise_pack/bint
	name = "cloth bandages"
	singular_name = "cloth bandage"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bint"
	heal_brute = 10 // for healing dogs and other animals
	amount = 10

/obj/item/stack/medical/bruise_pack/bint/small
	amount = 1

/obj/item/stack/medical/bruise_pack/bint/medic
	amount = 40

/obj/item/stack/medical/bruise_pack/bint/leather
	name = "leather bandages"
	singular_name = "leather bandage"
	desc = "A crude bandage, made of thin animal leather."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "leatherbandage"
	heal_brute = 6 // for healing dogs and other animals
	amount = 6

/obj/item/stack/medical/bruise_pack/gauze
	name = "roll of gauze"
	singular_name = "gauze length"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "gauze"
	heal_brute = 10 // for healing dogs and other animals
	amount = 10

/obj/item/revival_kit
	name = "revival kit"
	desc = "A full sized hospital and multiple years of rehabilitation in only couple of seconds, a true gift from the gods! Better not be greedy..."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "revival"
/obj/item/revival_kit/attack(var/mob/living/human/M as mob, var/mob/user as mob)
	user.visible_message("<span class='notice'>[user] starts trying to revive [M].</span>", "<span class='notice'>You determinately start trying to perfom the work of gods on [M].</span>")
	if (do_after(user, 120, src))
		M.revive()
		if (!M.ckey && M.lastKnownCkey)
			M.ckey = M.lastKnownCkey
		user.visible_message("<font size=4>[user] delivers a message from the GODS by reviving from [M] the dead!</font>", "<font size=4>You did something only a GOD could achieve by reviving [M]!</font>")
		playsound(get_turf(M), 'sound/hallelujah!.ogg', 200, FALSE)
		if (M.ckey == user.ckey)
			user << "You were greedy and now you don't feel so good..."
			spawn(30)
				M.gib()
		qdel(src)
	else
		user.visible_message("<span class='notice'>[user] stops trying to revive [M].</span>", "<span class='notice'>You stop trying to revive [M].</span>")
