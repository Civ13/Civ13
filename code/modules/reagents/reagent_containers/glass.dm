
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
		/obj/structure/lab_distillery,
		/obj/structure/table,
		/obj/structure/closet,
		/obj/structure/sink,
		/obj/structure/engine,
		/obj/item/weapon/storage,
		/mob/living/simple_animal/cow,
		/mob/living/simple_animal/goat/female,
		/mob/living/simple_animal/sheep/female,
		/obj/structure/oil_spring,
		/obj/structure/refinery,
		/obj/structure/oilwell,
		/obj/structure/heatsource,
		/obj/item/flashlight/lantern,
		/obj/item/stack/ammopart,
		/obj/structure/vehicle,
		/obj/structure/fuelpump,
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

		if (istype(target, /obj/item/weapon/sandbag))
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
		if (istype(target, /turf/floor/beach/water))
			return
		if (reagents && reagents.total_volume && !istype(src, /obj/item/weapon/reagent_containers/glass/small_pot))
			playsound(src,'sound/effects/Splash_Small_01_mono.ogg',50,1)
			user << "<span class='notice'>You splash the solution onto [target].</span>"
			if (reagents.has_reagent("petroleum", 5))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			else if (reagents.has_reagent("gasoline", 5))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			else if (reagents.has_reagent("diesel", 10))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			else if (reagents.has_reagent("biodiesel", 10))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			else if (reagents.has_reagent("olive_oil", 15))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
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
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/grapes))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You smash the grapes, producing grapejuice."
			reagents.add_reagent("grapejuice", 5)
			qdel(W)
			return

		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You grind the chinchona plant, producing quinine."
			reagents.add_reagent("quinine", 10)
			qdel(W)
			return

		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/olives))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You smash the olives, producing olive oil."
			reagents.add_reagent("olive_oil", 6)
			qdel(W)
			return

		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/potato))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You smash the potatoes, producing potato juice."
			reagents.add_reagent("potato", 5)
			qdel(W)
			return

		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/rice))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You smash the rice, producing a rice paste."
			reagents.add_reagent("rice", 5)
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/coffee))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You grind the coffee, producing a coffee drink."
			reagents.add_reagent("coffee", 15)
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/cotton))
			var/obj/item/stack/material/cotton/CT = W

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You put the cotton inside \the [src]."
			reagents.add_reagent("cotton", CT.amount)
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/corn))

			if (!is_open_container())
				user << "<span class='notice'>\The [src] is closed.</span>"
				return
			if (!reagents.get_free_space())
				user << "<span class='notice'>[src] is full.</span>"
				return

			user << "You grind the corn, producing corn oil."
			reagents.add_reagent("cornoil", 5)
			qdel(W)
			return
	proc/update_name_label()
		playsound(src,'sound/effects/pen.ogg',40,1)
		if (label_text == "")
			name = base_name
		else
			name = "[base_name] ([label_text])"

/obj/item/weapon/reagent_containers/glass/beaker
	name = "beaker"
	desc = "A beaker."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "beaker"
	item_state = "beaker"
	matter = list("glass" = 500)

	New()
		..()
		desc += " Can hold up to [volume] units."

	on_reagent_change()
		update_icon()

	pickup(mob/user)
		..()
		playsound(src,'sound/effects/glassknock.ogg',50,1)
		update_icon()

	dropped(mob/user)
		..()
		playsound(src,'sound/effects/Glasshit.ogg',50,1)
		update_icon()

	attack_hand()
		..()
		update_icon()

	update_icon()
		overlays.Cut()

		if (reagents.total_volume)
			var/image/filling = image('icons/obj/reagentfillings.dmi', src, "[icon_state]10")

			var/percent = round((reagents.total_volume / volume) * 100)
			switch(percent)
				if (0 to 9)		filling.icon_state = "[icon_state]-10"
				if (10 to 24) 	filling.icon_state = "[icon_state]10"
				if (25 to 49)	filling.icon_state = "[icon_state]25"
				if (50 to 74)	filling.icon_state = "[icon_state]50"
				if (75 to 79)	filling.icon_state = "[icon_state]75"
				if (80 to 90)	filling.icon_state = "[icon_state]80"
				if (91 to INFINITY)	filling.icon_state = "[icon_state]100"

			filling.color = reagents.get_color()
			overlays += filling

		if (!is_open_container())
			var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
			overlays += lid

/obj/item/weapon/reagent_containers/glass/beaker/large
	name = "large beaker"
	desc = "A large beaker."
	icon_state = "beakerlarge"
	matter = list("glass" = 5000)
	volume = 120
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10,15,25,30,60,120)
	flags = OPENCONTAINER

/obj/item/weapon/reagent_containers/glass/beaker/vial
	name = "vial"
	desc = "A small glass vial."
	icon_state = "vial"
	matter = list("glass" = 250)
	volume = 30
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10,15,25)
	flags = OPENCONTAINER

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
	flammable = TRUE
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

/obj/item/weapon/reagent_containers/glass/small_pot
	desc = "A small tin pot."
	name = "small tin pot"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "small_pot"
	item_state = "bucket"
	matter = list(DEFAULT_WALL_MATERIAL = 200)
	w_class = 3.0
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(10,20)
	volume = 80
	var/on_stove = FALSE
	flags = OPENCONTAINER

/obj/item/weapon/reagent_containers/glass/small_pot/copper_small
	desc = "A small copper pot."
	name = "small copper pot"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "copperpot1"
	item_state = "bucket"
	matter = list(DEFAULT_WALL_MATERIAL = 300)
	w_class = 3.0
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(10,20)
	volume = 90
	on_stove = FALSE
	flags = OPENCONTAINER

/obj/item/weapon/reagent_containers/glass/small_pot/copper_large
	desc = "A large copper pot."
	name = "large copper pot"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "copperpot2"
	item_state = "bucket"
	matter = list(DEFAULT_WALL_MATERIAL = 300)
	w_class = 4.0
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(10,20)
	volume = 160
	on_stove = FALSE
	flags = OPENCONTAINER

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
	name = "wood barrel"
	desc = "A wood barrel. You can put liquids inside."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	w_class = 4.0
	throw_speed = 1
	throw_range = 1
	nothrow = TRUE

/obj/item/weapon/reagent_containers/glass/barrel/modern
	name = "steel barrel"
	desc = "A steel barrel. You can put liquids inside."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "barrel"
	amount_per_transfer_from_this = 10
	volume = 350
	density = TRUE

/obj/item/weapon/reagent_containers/glass/barrel/fueltank
	name = "large fueltank"
	desc = "A metalic fueltank. Used to connect to a engine and supply it with fuel."
	icon = 'icons/obj/vehicleparts.dmi'
	icon_state = "fueltank_large"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/small
	name = "small fueltank"
	icon_state = "fueltank_small"
	volume = 120

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike25
	name = "25u motorcycle fueltank"
	icon_state = "fueltank_bike"
	volume = 25

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike
	name = "50u motorcycle fueltank"
	icon_state = "fueltank_bike"
	volume = 50

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike75
	name = "75u motorcycle fueltank"
	icon_state = "fueltank_bike"
	volume = 75
/obj/item/weapon/reagent_containers/glass/barrel/modern/water
	name = "water barrel"
	desc = "A steel barrel, filled with drinking water."
	New()
		..()
		reagents.add_reagent("water",350)

/obj/item/weapon/reagent_containers/glass/barrel/modern/oil
	name = "steel barrel"
	desc = "A steel barrel, filled with crude oil."
	New()
		..()
		reagents.add_reagent("petroleum",350)

/obj/item/weapon/reagent_containers/glass/barrel/modern/gasoline
	name = "steel barrel"
	desc = "A steel barrel, filled with gasoline."
	New()
		..()
		reagents.add_reagent("gasoline",350)

/obj/item/weapon/reagent_containers/glass/barrel/modern/diesel
	name = "diesel barrel"
	desc = "A steel barrel, filled with diesel."
	New()
		..()
		reagents.add_reagent("diesel",250)

/obj/item/weapon/reagent_containers/glass/barrel/modern/biodiesel
	name = "biodiesel barrel"
	desc = "A steel barrel, filled with biodiesel."
	New()
		..()
		reagents.add_reagent("biodiesel",350)

/obj/item/weapon/reagent_containers/glass/barrel/ethanol
	name = "ethanol barrel"
	desc = "A steel barrel, filled with ethanol."
	New()
		..()
		reagents.add_reagent("ethanol",350)

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

/obj/item/weapon/reagent_containers/glass/barrel/wine
	name = "wine barrel"
	desc = "A barrel of wine."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE
	New()
		..()
		reagents.add_reagent("wine",200)

/obj/item/weapon/reagent_containers/glass/barrel/tea
	name = "tea barrel"
	desc = "A barrel of tea."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE
	New()
		..()
		reagents.add_reagent("tea",200)

/obj/item/weapon/reagent_containers/glass/barrel/oil
	name = "oil barrel"
	desc = "A barrel filled with petroleum."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	volume = 250
	density = TRUE
	New()
		..()
		reagents.add_reagent("petroleum",200)

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
	if (reagents.total_volume+3 < volume)
		if (istype(I, /obj/item/stack/ore/sulphur))
			reagents.add_reagent("sulfur",3)
			if (I.amount>1)
				I.amount -= 1
			else
				qdel(I)
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
	else
		user << "The [src] is full!"
	..()