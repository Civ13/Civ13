//TO DO TODO: global obj/item pickup_sound, drop_sound, pickup_volume, drop_volume
//TO DO TODO: unify all food/drinks act as /glass, all /glass act as food/drinks
//TO DO TODO: fix code\game\objects\items.dm , code\modules\lighting\lighting_atom.dm
//TO DO TODO: /obj/effect/flooding need to be fixed
//TO DO TODO: Painstaking checking and possibly redrawing icons of small versions of items. Checking for compliance with item_state and icons in them.
//TO DO TODO: Think about transfer accuracy. For example, there is no such thing as the exact amount that can be poured out of a bucket!
//TO DO TODO: CHECK:   /obj/item/weapon/reagent_containers/glass/small_pot/german_kit_lid it may have bugs
//TO DO TODO: Re-Check all /obj/item/weapon/reagent_containers/glass/ items, that not in this file
//TO DO TODO: Think about concept: all /glass objects are storage, with watertight vessel sides.
//             All storages are vessels with non-waterproof sides and will lose liquids differs with liquid viscosity and pore size of the vessel.
//             I.e. /glass items have pore_size = 0 on sides and pore_size=100(?) on top of it (for vaporing).
//             Lids have own pore_size. For example beakers lid must (may) have pore_size=0
//TO DO TODO: Why not all pots from 'icons/obj/claystuff.dmi' are /glass objects??? Need reworking to usual concept!
//TO DO TODO: Satisfaction of drinking from a glass
//TO DO TODO: resolve theese objects attackby procedures (they must return TRUE for interrupt attack chain):
var/list/not_resolved_in_attackby_objects = list(/obj/structure/chemical_dispenser, /obj/structure/lab_distillery,
		/obj/structure/table, /obj/structure/closet, /obj/structure/sink, /obj/structure/engine,
		/obj/item/weapon/storage, /mob/living/simple_animal/cattle/cow,
		/mob/living/simple_animal/goat/female, /mob/living/simple_animal/sheep/female,
		/mob/living/simple_animal/pig_gilt, /obj/structure/oil_spring,
		/obj/structure/refinery, /obj/structure/distillery, /obj/structure/oilwell,
		/obj/structure/heatsource, /obj/item/flashlight/lantern, /obj/item/stack/ammopart,
		/obj/structure/vehicle, /obj/structure/fuelpump, /obj/item/stack/ore, /obj/structure/pot
		)

////////////////////////////////////////////////////////////////////////////////
/// (Mixing)Glass.
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/glass
	var/base_name // for labeling by pen items
	icon = 'icons/obj/chemical.dmi'
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10,15,25,30,60)
	volume = 60
	w_class = ITEM_SIZE_SMALL
	var/label_text = ""
	dropsound = 'sound/effects/drop_glass.ogg'

/obj/item/weapon/reagent_containers/glass/New()
	..()
	base_name = name
	flags |= OPENCONTAINER
	flags &= ~CONDUCT

/obj/item/weapon/reagent_containers/glass/examine(var/mob/user)
	if (!..(user, 2))
		return
	if (reagents && reagents.reagent_list.len)
		user << "<span class='notice'>It contains [reagents.total_volume] units of liquid.</span>"
	else
		user << "<span class='notice'>It is empty.</span>"
	if (!is_open_container())
		user << "<span class='notice'>Airtight lid seals it completely.</span>"

/obj/item/weapon/reagent_containers/glass/self_feed_message(var/mob/user)
	user << "<span class='notice'>You swallow a gulp from \the [src].</span>"

/obj/item/weapon/reagent_containers/glass/feed_sound(var/mob/user)
	playsound(user.loc, 'sound/items/drink.ogg', rand(10, 50), TRUE)

/obj/item/weapon/reagent_containers/glass/attack_self()
	..()
	if (is_open_container())
		playsound(src,'sound/effects/Lid_Removal_Bottle_mono.ogg',50,1)
		usr << "<span class = 'notice'>You put the lid on \the [src].</span>"
		flags &= ~OPENCONTAINER
	else
		usr << "<span class = 'notice'>You take the lid off \the [src].</span>"
		flags |= OPENCONTAINER
	update_icon()

/obj/item/weapon/reagent_containers/glass/attack_turf(turf/attacked, mob/user, icon_x, icon_y)
	if (is_open_container())
		if (reagents.total_volume)
			if (user.a_intent == I_HARM)
				user.visible_message("<span class='danger'>[user] splashes the contents of [src] onto [attacked]!</span>", \
									"<span class='notice'>You splash the contents of [src] onto [attacked].</span>")
				proper_spill(attacked, reagents.total_volume)
				return TRUE
			else if (istype(attacked, /turf/floor/dirt))
				if (locate(/obj/structure/farming/plant) in attacked)
					user.visible_message("<span class='notice'>[user] pours the contents of [src] onto [attacked]!</span>", \
										"<span class='notice'>You pour the contents of [src] onto [attacked].</span>")
					proper_spill(attacked, amount_per_transfer_from_this)
				return TRUE
	return FALSE

/obj/item/weapon/reagent_containers/glass/attack(mob/living/M, mob/living/user, target_zone)
	if (!is_open_container())
		return ..(M, user, target_zone)
	if (user.a_intent == I_HARM)
		standard_splash_mob(user, M)
	else
		standard_feed_mob(user, M)
	return TRUE //open container attack will resolved anyway

/obj/item/weapon/reagent_containers/glass/attack_obj(obj/attacked, mob/user, icon_x, icon_y)
	for (var/type in not_resolved_in_attackby_objects) //Old code artefact. TO DO TODO: resolve theese objects attackby procedures (they must return TRUE for interrupt attack chain)
		if (istype(attacked, type))
			return FALSE
	if (istype(attacked, /obj/structure/pot))
		return FALSE //all in attackby in pot.dm //TO DO TODO: Rework pot code into a large stationary glass with the ability to cook.
	if (!is_open_container())
		return FALSE
	if (standard_pour_into(user, attacked)) //trying to put into other reagent_container
		return TRUE
	if (standard_dispenser_refill(user, attacked)) //trying to refill this container from dispenser
		return TRUE
	return FALSE //not resolved

/obj/item/weapon/reagent_containers/glass/attackby(obj/item/weapon/W as obj, mob/user as mob) //TO DO TODO: fix this mess to something normal
	if (istype(W, /obj/item/weapon/pen))
		update_name_label(user)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/grapes)) //liquid transfer?
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
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona)) //liquid transfer? solid???
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
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/olives))  //liquid transfer? solid???
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
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/juniper))  //liquid transfer?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You smash the juniper berries, producing juniper juice."
		reagents.add_reagent("juniper_juice", 6)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/animalfat))  //liquid transfer?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You smash the animal fat inside the container, creating lard."
		reagents.add_reagent("lard", 10)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/potato))  //liquid transfer?
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
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/agave))  //liquid transfer?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You rip up the agave leaves, producing agave nectar."
		reagents.add_reagent("agave", 10)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/sapote))  //liquid transfer?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You smash the sapote fruit, producing sapote juice."
		reagents.add_reagent("sapotejuice", 4)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/apple))  //liquid transfer?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You smash the apple, producing apple juice."
		reagents.add_reagent("applejuice", 10)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/sapodilla))  //liquid transfer?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You smash the sapodilla, producing sapodilla juice."
		reagents.add_reagent("sapodillajuice", 10)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod))  //item transfer? what?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You throw the fish into the barrel."
		reagents.add_reagent("fish", 5)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish))  //item transfer? what is it?
		if (!is_open_container())
			user << "<span class='notice'>\The [src] is closed.</span>"
			return
		if (!reagents.get_free_space())
			user << "<span class='notice'>[src] is full.</span>"
			return
		user << "You throw the fish into the barrel."
		reagents.add_reagent("fish", 5)
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/rice)) //item transfer? what is it?
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
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/coffee)) //item transfer? what is it?
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
	else if (istype(W, /obj/item/stack/material/cotton)) //item transfer? what is it?
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
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/corn)) //item transfer? what is it?
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
	else if(istype(W, /obj/item/stack/material/rope)) //Lard candle making
		if (reagents.get_reagent_amount("lard") >= 5)
			var/obj/item/stack/material/rope/R = W
			visible_message("[user] starts to dip the [R.name] into the [src.name], shaping a candle.")
			if(do_after(user, 40, user))
				reagents.remove_reagent("lard", 5)
				new/obj/item/weapon/flame/candle/lard(user.loc)
				if(R.amount == 1)
					qdel(R)
				else
					R.amount -= 1
				return

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
		else if (istype(I, /obj/item/stack/ore/charcoal))
			reagents.add_reagent("carbon",3)
			if (I.amount>1)
				I.amount -= 1
			else
				qdel(I)
			return
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/poo))
			var/obj/item/weapon/reagent_containers/food/snacks/poo/P = I
			P.reagents.trans_to(src, 10, 1, FALSE)
			qdel(I)
			return
	else
		user << "The [src] is full!"
	..()

/obj/item/weapon/reagent_containers/glass/proc/update_name_label(mob/user)
	var/tmp_label = sanitizeSafe(input(user, "Enter a label for [base_name]", "Label", label_text), MAX_NAME_LEN)
	if (length(tmp_label) > 15)
		user << "<span class='notice'>The label can be at most 15 characters long.</span>"
	else
		user << "<span class='notice'>You set the label to \"[tmp_label]\".</span>"
		label_text = tmp_label
		playsound(src,'sound/effects/pen.ogg',40,1)
		if (label_text == "")
			name = base_name
		else
			name = "[base_name] ([label_text])"

/obj/item/weapon/reagent_containers/glass/proc/pierced_reagent_lost(var/lost_amount=10)
	//TO DO TODO: glass after piercing must lose max_volume??? and start lose liquids...
	visible_message("<span class = 'warning'>\The [src] gets pierced!</span>")
	if (reagents)
		if (reagents.total_volume > 0)
			var/part = lost_amount / reagents.total_volume
			for (var/datum/reagent/current in reagents.reagent_list)
				var/amount_to_transfer = current.volume * part
				reagents.remove_reagent(current.id, amount_to_transfer, TRUE)
		if (lost_amount>9)
			new/obj/effect/decal/cleanable/blood/oil(src.loc) //TO DO TODO: After implemented differents types of oil do differents types there

/obj/item/weapon/reagent_containers/glass/bullet_act(var/obj/item/projectile/proj, def_zone)
	var/can_explode = FALSE
	if (!reagents)
		return ..(proj, def_zone)
	if (reagents.has_reagent("gasoline",10) || reagents.has_reagent("diesel",30) || reagents.has_reagent("biodiesel",30) || reagents.has_reagent("ethanol",10) || reagents.has_reagent("petroleum",40) || reagents.has_reagent("gunpowder",30))
		can_explode = TRUE
	if (!can_explode)
		if (prob(30))
			pierced_reagent_lost(15)
			return TRUE
		else
			return FALSE
	if (istype(proj, /obj/item/projectile/shell))
		var/obj/item/projectile/shell/S = proj
		if (S.atype == "HE")
			if (prob(90))
				visible_message("<span class = 'warning'>\The [src] explodes!</span>")
				explosion(loc, 2, 3, 2, 0)
				qdel(src)
			else
				pierced_reagent_lost(15)
		else
			if (prob(20))
				visible_message("<span class = 'warning'>\The [src] explodes!</span>")
				explosion(loc, 1, 1, 2, 0)
				qdel(src)
			else if (prob(75))
				pierced_reagent_lost(25)
	else
		if (prob(16))
			visible_message("<span class = 'warning'>\The [src] explodes!</span>")
			explosion(loc, 1, 2, 2, 0)
			qdel(src)
		else if (prob(30))
			pierced_reagent_lost(15)
	return TRUE

/obj/item/weapon/reagent_containers/glass/beaker
	name = "beaker"
	desc = "A beaker."
	icon = 'icons/obj/chemical.dmi'
	unacidable = TRUE
	icon_state = "beaker"
	item_state = "beaker"

/obj/item/weapon/reagent_containers/glass/beaker/New()
	..()
	desc += " Can hold up to [volume] units."

/obj/item/weapon/reagent_containers/glass/beaker/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/glass/beaker/pickup(mob/user)
	..()
	playsound(src,'sound/effects/glassknock.ogg',50,1)

/obj/item/weapon/reagent_containers/glass/beaker/dropped(mob/user)
	..()
	playsound(src,'sound/effects/Glasshit.ogg',50,1)

/obj/item/weapon/reagent_containers/glass/beaker/update_icon()
	overlays.Cut()
	if (reagents.total_volume)
		var/image/filling = image('icons/obj/reagentfillings.dmi', src, "[icon_state]100")
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 9)		filling.icon_state = "[icon_state]-10"
			if (10 to 24) 	filling.icon_state = "[icon_state]10"
			if (25 to 49)	filling.icon_state = "[icon_state]25"
			if (50 to 74)	filling.icon_state = "[icon_state]50"
			if (75 to 79)	filling.icon_state = "[icon_state]75"
			if (80 to 90)	filling.icon_state = "[icon_state]80"
			else			filling.icon_state = "[icon_state]100"
		filling.color = reagents.get_color()
		overlays += filling
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid

/obj/item/weapon/reagent_containers/glass/beaker/large
	name = "large beaker"
	desc = "A large beaker."
	icon_state = "beakerlarge" //TODO: draw different item state?
	volume = 120
	possible_transfer_amounts = list(5,10,15,25,30,60,120)

/obj/item/weapon/reagent_containers/glass/beaker/vial
	name = "vial"
	desc = "A small glass vial."
	icon_state = "vial" //TODO: draw different item state?
	volume = 30
	possible_transfer_amounts = list(5,10,15,25)

/obj/item/weapon/reagent_containers/glass/bucket
	desc = "It's a bucket."
	name = "bucket"
	icon = 'icons/obj/janitor.dmi'
	icon_state = "bucket"
	item_state = "bucket" //TODO: need be checked!!!!!!!!!!!
	w_class = ITEM_SIZE_NORMAL
	amount_per_transfer_from_this = 20
	possible_transfer_amounts = list(10,20,30,60,120)
	volume = 120
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
	..(D, user)

/obj/item/weapon/reagent_containers/glass/bucket/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/glass/bucket/update_icon()
	overlays.Cut()
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid
	else
		var/image/filling = image('icons/obj/reagentfillings.dmi', src, "[icon_state]100")
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 69)	filling.icon_state = "[icon_state]-70"
			if (69 to 77)	filling.icon_state = "[icon_state]75"
			if (77 to 90)	filling.icon_state = "[icon_state]85"
			else			filling.icon_state = "[icon_state]100"
		filling.color = reagents.get_color()
		overlays += filling

/obj/item/weapon/reagent_containers/glass/small_pot
	desc = "A small tin pot."
	name = "small tin pot"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "small_pot"
	item_state = "bucket" //TODO: need be checked
	w_class = ITEM_SIZE_NORMAL
	possible_transfer_amounts = list(10,20)
	volume = 80
	var/on_stove = FALSE
	New()
		..()
		flags |= CONDUCT

/obj/item/weapon/reagent_containers/glass/small_pot/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/glass/small_pot/update_icon()
	overlays.Cut()
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid
	else
		var/image/filling = image('icons/obj/reagentfillings.dmi', src, "[icon_state]100")
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 54)	filling.icon_state = "[icon_state]-55"
			if (54 to 64)	filling.icon_state = "[icon_state]60"
			if (64 to 74)	filling.icon_state = "[icon_state]70"
			if (74 to 83)	filling.icon_state = "[icon_state]80"
			if (83 to 92)	filling.icon_state = "[icon_state]90"
			else			filling.icon_state = "[icon_state]100"
		filling.color = reagents.get_color()
		overlays += filling

/obj/item/weapon/reagent_containers/glass/small_pot/hangou
	desc = "A japanese pot used by the military all the way back to the meiji era."
	name = "han-gou"
	icon_state = "han_gou_open"
	item_state = "bucket" //TODO: need be checked
	possible_transfer_amounts = list(10,20,30,80)

/obj/item/weapon/reagent_containers/glass/small_pot/hangou/update_icon()
	if (!is_open_container())
		overlays.Cut()
		icon_state = "lid_han_gou"
	else
		icon_state = "han_gou_open"
		..()

/obj/item/weapon/reagent_containers/glass/small_pot/copper_small
	desc = "A small copper pot."
	name = "small copper pot"
	icon_state = "copperpot1"
	item_state = "bucket" //TODO: need be checked
	volume = 90

/obj/item/weapon/reagent_containers/glass/small_pot/copper_large
	desc = "A large copper pot."
	name = "large copper pot"
	icon_state = "copperpot2"
	item_state = "bucket" //TODO: need be checked
	w_class = ITEM_SIZE_LARGE
	volume = 160

/obj/item/weapon/reagent_containers/glass/small_pot/clay
	desc = "A primitive clay pot, used for boiling water and cooking."
	name = "clay cooking pot"
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "cookingpot"
	item_state = "bucket" //TODO: need be checked
	volume = 40
	New()
		..()
		flags &= ~CONDUCT

/* //No entryes of it now. Is it need?
/obj/item/weapon/reagent_containers/glass/fermenterbarrel
	desc = "A fermenter barrel, use it to make alcoholic drinks like ale, beer and cider."
	name = "fermenter barrel"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "wood_barrel1" //no sprite! re-check if reimplement back!!!
	item_state = "bucket"
	w_class = ITEM_SIZE_LARGE
	amount_per_transfer_from_this = 20
	possible_transfer_amounts = list(10,20,30,60,120)
	volume = 150
	density = TRUE
*/

/obj/item/weapon/reagent_containers/glass/barrel
	name = "wood barrel"
	desc = "A wood barrel. You can put liquids inside."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood"
	//item_state = ???? TO DO TODO or check
	w_class = ITEM_SIZE_LARGE
	volume = 250
	throw_speed = 1
	throw_range = 1
	density = TRUE
	nothrow = TRUE

/obj/item/weapon/reagent_containers/glass/barrel/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/glass/barrel/update_icon()
	overlays.Cut()
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid
	else
		var/image/filling = image(icon, src, "[icon_state]100")
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 88.1)	filling.icon_state = "[icon_state]0"
			if (88.1 to 91.5)	filling.icon_state = "[icon_state]90"
			if (91.5 to 94.9)	filling.icon_state = "[icon_state]93"
			if (94.9 to 98.3)	filling.icon_state = "[icon_state]97"
			else			filling.icon_state = "[icon_state]100"
		filling.color = reagents.get_color()
		overlays += filling

/obj/item/weapon/reagent_containers/glass/barrel/water
	name = "wood barrel (drinking water)"
	label_text = "drinking water"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("water",250)

/obj/item/weapon/reagent_containers/glass/barrel/beer
	name = "wood barrel (beer)"
	label_text = "beer"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("beer",250)

/obj/item/weapon/reagent_containers/glass/barrel/ale
	name = "wood barrel (ale)"
	label_text = "ale"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("ale",250)

/obj/item/weapon/reagent_containers/glass/barrel/rum
	name = "wood barrel (rum)"
	label_text = "rum"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("rum",250)

/obj/item/weapon/reagent_containers/glass/barrel/whiskey
	name = "wood barrel (whiskey)"
	label_text = "whiskey"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("whiskey",250)

/obj/item/weapon/reagent_containers/glass/barrel/tequila
	name = "wood barrel (tequila)"
	label_text = "tequila"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("tequila",250)

/obj/item/weapon/reagent_containers/glass/barrel/gin
	name = "wood barrel (gin)"
	label_text = "gin"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("gin",250)

/obj/item/weapon/reagent_containers/glass/barrel/vodka
	name = "wood barrel (vodka)"
	label_text = "vodka"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("vodka",250)

/obj/item/weapon/reagent_containers/glass/barrel/cognac
	name = "wood barrel (cognac)"
	label_text = "cognac"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("cognac",250)

/obj/item/weapon/reagent_containers/glass/barrel/wine
	name = "wood barrel (wine)"
	label_text = "wine"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("wine",250)

/obj/item/weapon/reagent_containers/glass/barrel/tea
	name = "wood barrel (tea)"
	label_text = "tea"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("tea",250)

/obj/item/weapon/reagent_containers/glass/barrel/oil
	name = "wood barrel (petroleum)"
	label_text = "petroleum"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("petroleum",250)

/obj/item/weapon/reagent_containers/glass/barrel/olive_oil
	name = "wood barrel (olive oil)"
	label_text = "olive oil"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("olive_oil",250)

/obj/item/weapon/reagent_containers/glass/barrel/fat_oil
	name = "wood barrel (fat oil)"
	label_text = "fat oil"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("fat_oil",250)

/obj/item/weapon/reagent_containers/glass/barrel/ethanol
	name = "wood barrel (ethanol)"
	label_text = "ethanol"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "wood barrel"
		reagents.add_reagent("pethanol",250)

/obj/item/weapon/reagent_containers/glass/barrel/modern
	name = "steel barrel"
	desc = "A steel barrel. You can put liquids inside."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "barrel"
	//item_state = ???? TO DO TODO or check
	volume = 350
	density = TRUE
	New()
		..()
		flags |= CONDUCT

/obj/item/weapon/reagent_containers/glass/barrel/modern/update_icon()
	overlays.Cut()
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid
	else
		var/image/filling = image(icon, src, "[icon_state]85")
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 85)	filling.icon_state = "[icon_state]-85"
			else			filling.icon_state = "[icon_state]85"
		filling.color = reagents.get_color()
		overlays += filling

/obj/item/weapon/reagent_containers/glass/barrel/modern/water
	name = "steel barrel (drinking water)"
	label_text = "drinking water"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("water",350)

//////////yellow barrel/////////////////////////
/obj/item/weapon/reagent_containers/glass/barrel/modern/yellow
	name = "yellow steel barrel"
	desc = "A yellow steel barrel. You can put liquids inside."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "barreln"
	//item_state = ???? TO DO TODO or check
	volume = 350
	density = TRUE

//////////Galactic Battles//////////////////////

/obj/item/weapon/reagent_containers/glass/barrel/modern/bmilk
	name = "steel barrel (blue milk)"
	label_text = "blue milk"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("bmilk",350)

////////////////////////////////////////////////////////////////////////

/obj/item/weapon/reagent_containers/glass/barrel/modern/oil
	name = "steel barrel (petroleum)"
	label_text = "petroleum"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("petroleum",350)

/obj/item/weapon/reagent_containers/glass/barrel/modern/gasoline
	name = "steel barrel (gasoline)"
	label_text = "gasoline"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("gasoline",350)

/obj/item/weapon/reagent_containers/glass/barrel/modern/diesel
	name = "steel barrel (diesel)"
	label_text = "diesel"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("diesel",250)

/obj/item/weapon/reagent_containers/glass/barrel/modern/diesel/low
	name = "steel barrel (diesel)"
	label_text = "diesel"
	New()
		..()
		base_name = "steel barrel"
		reagents.add_reagent("diesel",30)

/obj/item/weapon/reagent_containers/glass/barrel/modern/biodiesel
	name = "steel barrel (biodiesel)"
	label_text = "biodiesel"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("biodiesel",350)

/obj/item/weapon/reagent_containers/glass/barrel/modern/sterilizine
	name = "steel barrel (sterilizine)"
	label_text = "sterilizine"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("sterilizine", volume * 0.66)
		reagents.add_reagent("cleaner", volume * 0.34)

/obj/item/weapon/reagent_containers/glass/barrel/modern/ethanol
	name = "steel barrel (ethanol)"
	label_text = "ethanol"
	New()
		..()
		flags &= ~OPENCONTAINER
		base_name = "steel barrel"
		reagents.add_reagent("pethanol",350)

/obj/item/weapon/reagent_containers/glass/barrel/jerrycan
	name = "jerrycan"
	desc = "A steel jerrycan. Good for transporting fuel."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "jerrycan"
	amount_per_transfer_from_this = 30
	volume = 150
	density = FALSE
	New()
		..()
		flags &= ~OPENCONTAINER
		flags |= CONDUCT

/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/update_icon()
	overlays.Cut()
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid

/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline/
	name = "jerrycan (gasoline)"
	label_text = "gasoline"
	New()
		..()
		base_name = "jerrycan"
		reagents.add_reagent("gasoline",150)

/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/diesel
	name = "jerrycan (diesel)"
	label_text = "diesel"
	New()
		..()
		base_name = "jerrycan"
		reagents.add_reagent("diesel",150)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank
	name = "large fueltank"
	desc = "A metalic fueltank. Used to connect to a engine and supply it with fuel."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "fueltank_large"
	volume = 250
	density = TRUE

	New()
		..()
		flags |= OPENCONTAINER
		flags |= CONDUCT

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/update_icon()
	overlays.Cut()
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_fueltank")
		overlays += lid
	else
		var/image/filling = image(icon, src, "full_fueltank")
		var/percent = round((reagents.total_volume / volume) * 100)
		switch(percent)
			if (0 to 5)		filling.icon_state = "empty_fueltank"
			else			filling.icon_state = "full_fueltank"
		filling.color = reagents.get_color()
		overlays += filling

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

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike/full
	New()
		..()
		reagents.add_reagent("gasoline",50)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike75
	name = "75u motorcycle fueltank"
	icon_state = "fueltank_bike"
	volume = 75

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank
	name = "huge fueltank"
	icon_state = "fueltank_large_tank"
	volume = 450

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/highcap
	name = "High capacity fueltank"
	icon_state = "fueltank_large_tank"
	volume = 550

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/highcap/fueled
	New()
		..()
		reagents.add_reagent("diesel",550)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/highcap/fueledgasoline
	New()
		..()
		reagents.add_reagent("gasoline",550)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled
	New()
		..()
		reagents.add_reagent("diesel",450)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline
	New()
		..()
		reagents.add_reagent("gasoline",450)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledethanol
	New()
		..()
		reagents.add_reagent("pethanol",450)


/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank
	name = "medium fueltank"
	icon_state = "fueltank_small_tank"
	volume = 180

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline
	New()
		..()
		reagents.add_reagent("gasoline",180)

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueleddiesel
	New()
		..()
		reagents.add_reagent("diesel",180)

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder
	//TO DO TODO: REWORK IT'S BUGGY THING LATER!!!
	name = "gunpowder barrel"
	desc = "A barrel of gunpowder. Don't light it on fire."
	icon_state = "barrel_wood_gunpowder"
	New()
		..()
		reagents.add_reagent("gunpowder",200)

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		if (prob(30))
			visible_message("<span class = 'warning'>\The [src] is hit by \the [proj] and explodes!</span>")
			explode()
			return TRUE
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

/obj/item/weapon/reagent_containers/glass/extraction_kit
	//TO DO TO DO: Unify to one procedure all using of extraction kit
	//             Add restart process (by atack_self if not empty)
	name = "extraction kit"
	desc = "A professional kit for extracting elements from raw ores."
	icon_state = "extraction_kit"
	amount_per_transfer_from_this = 5
	volume = 5
	possible_transfer_amounts = list(5)
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_WEAK
	New()
		..()
		flags |= CONDUCT

/obj/item/weapon/reagent_containers/glass/extraction_kit/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/glass/extraction_kit/update_icon()
	overlays.Cut()
	if (reagents.total_volume)
		var/image/filling = image(icon, src, "[icon_state]_full")
		filling.color = reagents.get_color()
		overlays += filling
	if (!is_open_container())
		var/image/lid = image(icon, src, "lid_[initial(icon_state)]")
		overlays += lid

/obj/item/weapon/analyser
	name = "analyser"
	desc = "An electronic analyser, to check the ingredients of a chemical mixture."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "spectrometer"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT|SLOT_ID|SLOT_POCKET
	flammable = TRUE
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_WEAK
	New()
		..()
		flags |= CONDUCT

/obj/item/weapon/analyser/afterattack(obj/M, mob/user)
	if (istype(M, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = M
		user << "<font color='yellow'><big><b>Reagents detected:</b></big></font>"
		for(var/i=1 to RG.reagents.reagent_list.len)
			user << "<font color='yellow'><i><b>[RG.reagents.reagent_list[i].name]: </b>[RG.reagents.reagent_list[i].volume] units</i></font>"
