/obj/structure/iv_drip
	name = "\improper IV drip"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "hooked0"
	anchored = FALSE
	density = TRUE
	var/mob/living/carbon/human/attached = null
	var/mode = TRUE // TRUE is injecting, FALSE is taking blood.
	var/obj/item/weapon/reagent_containers/beaker = null

/obj/structure/iv_drip/New()
	..()
	processing_objects += src

/obj/structure/iv_drip/Del()
	processing_objects -= src
	..()

/obj/structure/iv_drip/update_icon()
	if (attached)
		icon_state = "hooked"
	else
		icon_state = "hooked0"

	overlays = null

	if (beaker)
		var/datum/reagents/reagents = beaker.reagents
		if (reagents.total_volume)
			var/image/filling = image('icons/obj/surgery.dmi', src, "reagent")

			var/percent = round((reagents.total_volume / beaker.volume) * 100)
			switch(percent)
				if (0 to 9)		filling.icon_state = "reagent0"
				if (10 to 24) 	filling.icon_state = "reagent10"
				if (25 to 49)	filling.icon_state = "reagent25"
				if (50 to 74)	filling.icon_state = "reagent50"
				if (75 to 79)	filling.icon_state = "reagent75"
				if (80 to 90)	filling.icon_state = "reagent80"
				if (91 to INFINITY)	filling.icon_state = "reagent100"

			filling.icon += reagents.get_color()
			overlays += filling

/obj/structure/iv_drip/MouseDrop(over_object, src_location, over_location)
	..()

	if (attached)
		visible_message("[attached] is detached from \the [src]")
		attached = null
		update_icon()
		return

	if (in_range(src, usr) && ishuman(over_object) && get_dist(over_object, src) <= 1)
		visible_message("[usr] attaches \the [src] to \the [over_object].")
		attached = over_object
		update_icon()


/obj/structure/iv_drip/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		if (!isnull(beaker))
			user << "There is already a reagent container loaded!"
			return

		user.drop_item()
		W.loc = src
		beaker = W
		user << "You attach \the [W] to \the [src]."
		update_icon()
		return
	else
		return ..()

/obj/structure/iv_drip/process()

	if (attached)

		if (!(get_dist(src, attached) <= 1 && isturf(attached.loc)))
		/*	visible_message("The needle is ripped out of [attached], doesn't that hurt?")
			attached:apply_damage(3, BRUTE, pick("r_arm", "l_arm"))*/ // this is dumb - Kachnov
			attached = null
			update_icon()
			return

	if (attached && beaker)
		// Give blood
		if (mode)
			if (beaker.volume > 0)
				var/transfer_amount = REM
				if (istype(beaker, /obj/item/weapon/reagent_containers/blood))
					// speed up transfer on blood packs
					transfer_amount = 4
				beaker.reagents.trans_to_mob(attached, transfer_amount, CHEM_BLOOD)
				update_icon()

		// Take blood
		else
			var/amount = beaker.reagents.maximum_volume - beaker.reagents.total_volume
			amount = min(amount, 4)
			// If the beaker is full, ping
			if (amount == FALSE)
				if (prob(5)) visible_message("\The [src] pings.")
				return

			var/mob/living/carbon/human/T = attached

			if (!istype(T)) return
			if (!T.dna)
				return

			if (T.species.flags & NO_BLOOD)
				return

			// If the human is losing too much blood, beep.
			if (((T.vessel.get_reagent_amount("blood")/T.species.blood_volume)*100) < BLOOD_VOLUME_SAFE)
				visible_message("\The [src] beeps loudly.")

			var/datum/reagent/B = T.take_blood(beaker,amount)

			if (B)
				beaker.reagents.reagent_list |= B
				beaker.reagents.update_total()
				beaker.on_reagent_change()
				beaker.reagents.handle_reactions()
				update_icon()

/obj/structure/iv_drip/attack_hand(mob/user as mob)
	if (beaker)
		beaker.loc = get_turf(src)
		beaker = null
		update_icon()
	else
		return ..()


/obj/structure/iv_drip/verb/toggle_mode()
	set category = null
	set name = "Toggle Mode"
	set src in view(1)

	if (!istype(usr, /mob/living))
		usr << "<span class='warning'>You can't do that.</span>"
		return

	if (usr.stat)
		return

	mode = !mode
	usr << "The IV drip is now [mode ? "injecting" : "taking blood"]."

/obj/structure/iv_drip/examine(mob/user)
	..(user)
	if (!(user in view(2)) && user!=loc) return

	user << "The IV drip is [mode ? "injecting" : "taking blood"]."

	if (beaker)
		if (beaker.reagents && beaker.reagents.reagent_list.len)
			usr << "<span class='notice'>Attached is \a [beaker] with [beaker.reagents.total_volume] units of liquid.</span>"
		else
			usr << "<span class='notice'>Attached is an empty [beaker].</span>"
	else
		usr << "<span class='notice'>No chemicals are attached.</span>"

	usr << "<span class='notice'>[attached ? attached : "No one"] is attached.</span>"

/obj/structure/iv_drip/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (height && istype(mover) && mover.checkpass(PASSTABLE)) //allow bullets, beams, thrown objects, mice, drones, and the like through.
		return TRUE
	return ..()


///////////////////////////////////////////

/obj/item/weapon/storage/box/bloodpacks
	name = "blood packs bags"
	desc = "This box contains blood packs."
	icon_state = "box"
	New()
		..()
		new /obj/item/weapon/reagent_containers/blood/empty(src)
		new /obj/item/weapon/reagent_containers/blood/empty(src)
		new /obj/item/weapon/reagent_containers/blood/empty(src)
		new /obj/item/weapon/reagent_containers/blood/empty(src)
		new /obj/item/weapon/reagent_containers/blood/empty(src)
		new /obj/item/weapon/reagent_containers/blood/empty(src)
		new /obj/item/weapon/reagent_containers/blood/empty(src)

/obj/item/weapon/reagent_containers/blood
	name = "blood pack"
	desc = "Contains blood used for transfusion."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bp_empty"
	volume = 200

	var/blood_type = null

	New()
		..()
		if (blood_type != null)
			name = "BloodPack [blood_type]"
			reagents.add_reagent("blood", 200, list("donor"=null,"viruses"=null,"blood_DNA"=null,"blood_type"=blood_type,"resistances"=null,"trace_chem"=null))
			update_icon()

	on_reagent_change()
		update_icon()

	update_icon()
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 9)			icon_state = "bp_empty"
			if (10 to 50) 		icon_state = "bp_half"
			if (51 to INFINITY)	icon_state = "bp_full"

/obj/item/weapon/reagent_containers/blood/APlus
	blood_type = "A+"

/obj/item/weapon/reagent_containers/blood/AMinus
	blood_type = "A-"

/obj/item/weapon/reagent_containers/blood/BPlus
	blood_type = "B+"

/obj/item/weapon/reagent_containers/blood/BMinus
	blood_type = "B-"

/obj/item/weapon/reagent_containers/blood/OPlus
	blood_type = "O+"

/obj/item/weapon/reagent_containers/blood/OMinus
	blood_type = "O-"

/obj/item/weapon/reagent_containers/blood/empty
	name = "empty blood pack"
	desc = "Seems pretty useless... Maybe if there were a way to fill it?"
	icon_state = "bp_empty"