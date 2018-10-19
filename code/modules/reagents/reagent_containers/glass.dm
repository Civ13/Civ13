
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
		/obj/item/weapon/storage/secure/safe,
		/mob/living/simple_animal/cow,
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

/obj/item/weapon/reagent_containers/glass/fermenterbarrel
	desc = "A fermenter barrel, use it to make alcoholic drinks like ale, beer and cider."
	name = "fermenter barrel"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "wood_barrel1"
	item_state = "bucket"
	matter = list(DEFAULT_WALL_MATERIAL = 200)
	w_class = 4.0
	amount_per_transfer_from_this = 20
	possible_transfer_amounts = list(10,20,30,60,120)
	volume = 150
	density = TRUE
	flags = OPENCONTAINER

/obj/item/weapon/reagent_containers/glass/barrel
	w_class = 4.0
	throw_speed = 1
	throw_range = 1
	nothrow = TRUE

/obj/item/weapon/reagent_containers/glass/barrel/empty
	name = "wood barrel"
	desc = "A wood barrel. You can put liquids inside."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE


/obj/item/weapon/reagent_containers/glass/barrel/water
	name = "water barrel"
	desc = "A wood barrel, filled with drinking water."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE
	New()
		..()
		reagents.add_reagent("water",250)


/obj/item/weapon/reagent_containers/glass/barrel/beer
	name = "beer barrel"
	desc = "A barrel of beer. Keep it secured!"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	density = TRUE
	volume = 250
	New()
		..()
		reagents.add_reagent("beer",200)

/obj/item/weapon/reagent_containers/glass/barrel/rum
	name = "rum barrel"
	desc = "A barrel of rum. You better keep it locked and away from the crew!"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE
	New()
		..()
		reagents.add_reagent("rum",200)

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder
	name = "gunpowder barrel"
	desc = "A barrel of gunpowder. Don't light it on fire."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_gunpowder"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE
	New()
		..()
		reagents.add_reagent("gunpowder",200)

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		if (prob(30))
			visible_message("<span class = 'warning'>\The [src] is hit by \the [proj] and explodes!</span>")
			return explode()
	return FALSE

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder/ex_act()
	explode()

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder/proc/explode()
	if (reagents.total_volume > 500)
		explosion(loc,1,2,4,2)
	else if (reagents.total_volume > 100)
		explosion(loc,0,1,3,1)
	else if (reagents.total_volume > 50)
		explosion(loc,-1,1,2,1)
	if (src) qdel(src)

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder/fire_act(temperature)
	if (temperature > T0C+500)
		explode()
	return ..()


/obj/item/weapon/reagent_containers/glass/barrel/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/stack/ore/sulphur))
		reagents.add_reagent("sulfur",3)
		if (I.amount>1)
			I.amount -= 1
		else
			qdel(I)
		return
		return
	else if (istype(I, /obj/item/stack/ore/saltpeter))
		reagents.add_reagent("potassium",3)
		if (I.amount>1)
			I.amount -= 1
		else
			qdel(I)
		return
	else if (istype(I, /obj/item/stack/ore/coal))
		reagents.add_reagent("carbon",3)
		if (I.amount>1)
			I.amount -= 1
		else
			qdel(I)
		return
		return
	..()