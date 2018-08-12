
////////////////////////////////////////////////////////////////////////////////
/// (Mixing)Glass.
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/glass
	name = " "
	var/base_name = " "
	desc = " "
	icon = 'icons/obj/chemical.dmi'
	icon_state = "null"
	item_state = "null"
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10,15,25,30,60)
	volume = 60
	w_class = 2
	flags = OPENCONTAINER

	var/label_text = ""

	var/list/can_be_placed_into = list(
		/obj/structure/chemical_dispenser,
		/obj/structure/table,
		/obj/structure/closet,
		/obj/structure/sink,
		/obj/item/weapon/storage,
//		/obj/machinery/atmospherics/unary/cryo_cell,
	//	/obj/machinery/dna_scannernew,
		/obj/item/weapon/storage/secure/safe,
	//	/obj/machinery/disease2/incubator,
	//	/obj/machinery/disposal,
		/mob/living/simple_animal/cow,
	//	/obj/machinery/computer/centrifuge,
//		/obj/machinery/sleeper,
	//	/obj/machinery/smartfridge/,
	//	/obj/machinery/biogenerator,
	//	/obj/machinery/constructable_frame
		)

	dropsound = 'sound/effects/drop_glass.ogg'

	New()
		..()
		base_name = name

	examine(var/mob/user)
		if (!..(user, 2))
			return
		if (reagents && reagents.reagent_list.len)
			user << "<span class='notice'>It contains [reagents.total_volume] units of liquid.</span>"
		else
			user << "<span class='notice'>It is empty.</span>"
		if (!is_open_container())
			user << "<span class='notice'>Airtight lid seals it completely.</span>"

	attack_self()
		..()
		if (is_open_container())
			playsound(src,'sound/effects/Lid_Removal_Bottle_mono.ogg',50,1)
			usr << "<span class = 'notice'>You put the lid on \the [src].</span>"
			flags ^= OPENCONTAINER
		else
			usr << "<span class = 'notice'>You take the lid off \the [src].</span>"
			flags |= OPENCONTAINER
		update_icon()

	afterattack(var/obj/target, var/mob/user, var/flag)

		if (istype(target, /obj/structure/pot))
			return

		if (!is_open_container() || !flag)
			return

		for (var/type in can_be_placed_into)
			if (istype(target, type))
				return

		if (standard_splash_mob(user, target))
			return
		if (standard_dispenser_refill(user, target))
			return
		if (standard_pour_into(user, target))
			return

		if (reagents.total_volume)
			playsound(src,'sound/effects/Splash_Small_01_mono.ogg',50,1)
			user << "<span class='notice'>You splash the solution onto [target].</span>"
			reagents.splash(target, reagents.total_volume)
			return

	attackby(obj/item/weapon/W as obj, mob/user as mob)
		if (istype(W, /obj/item/weapon/pen))
			var/tmp_label = sanitizeSafe(input(user, "Enter a label for [name]", "Label", label_text), MAX_NAME_LEN)
			if (length(tmp_label) > 10)
				user << "<span class='notice'>The label can be at most 10 characters long.</span>"
			else
				user << "<span class='notice'>You set the label to \"[tmp_label]\".</span>"
				label_text = tmp_label
				update_name_label()

	proc/update_name_label()
		playsound(src,'sound/effects/pen.ogg',40,1)
		if (label_text == "")
			name = base_name
		else
			name = "[base_name] ([label_text])"

/obj/item/weapon/reagent_containers/glass/bucket
	desc = "It's a bucket."
	name = "bucket"
	icon = 'icons/obj/janitor.dmi'
	icon_state = "bucket"
	item_state = "bucket"
	matter = list(DEFAULT_WALL_MATERIAL = 200)
	w_class = 3.0
	amount_per_transfer_from_this = 20
	possible_transfer_amounts = list(10,20,30,60,120)
	volume = 120
	flags = OPENCONTAINER

/obj/item/weapon/reagent_containers/glass/bucket/attackby(var/obj/D, mob/user as mob)

	if (istype(D, /obj/item/weapon/mop))
		if (reagents.total_volume < 1)
			user << "<span class='warning'>\The [src] is empty!</span>"
		else
			reagents.trans_to_obj(D, 5)
			user << "<span class='notice'>You wet \the [D] in \the [src].</span>"
			playsound(loc, 'sound/effects/slosh.ogg', 25, TRUE)
		return
	else
		return ..()

/obj/item/weapon/reagent_containers/glass/bucket/update_icon()
	overlays.Cut()
	if (reagents.total_volume >= 1)
		overlays += "water_bucket"
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid

/*
/obj/item/weapon/reagent_containers/glass/blender_jug
	name = "Blender Jug"
	desc = "A blender jug, part of a blender."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "blender_jug_e"
	volume = 100

	on_reagent_change()
		switch(reagents.total_volume)
			if (0)
				icon_state = "blender_jug_e"
			if (1 to 75)
				icon_state = "blender_jug_h"
			if (76 to 100)
				icon_state = "blender_jug_f"

/obj/item/weapon/reagent_containers/glass/canister		//not used apparantly
	desc = "It's a canister. Mainly used for transporting fuel."
	name = "canister"
	icon = 'icons/obj/tank.dmi'
	icon_state = "canister"
	item_state = "canister"
	m_amt = 300
	g_amt = FALSE
	w_class = 4.0

	amount_per_transfer_from_this = 20
	possible_transfer_amounts = list(10,20,30,60)
	volume = 120
*/
