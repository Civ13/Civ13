
//basically, the dispensers are now wood barrels and wood crates.
/obj/structure/reagent_dispensers
	name = "Barrel"
	desc = "..."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood"
	density = TRUE
	anchored = FALSE

	var/amount_per_transfer_from_this = 10
	var/possible_transfer_amounts = list(10,25,50,100)

	attackby(obj/item/weapon/W as obj, mob/user as mob)
		return

	New()
		var/datum/reagents/R = new/datum/reagents(1000)
		reagents = R
		R.my_atom = src
		if (!possible_transfer_amounts)
			verbs -= /obj/structure/reagent_dispensers/verb/set_APTFT
		..()

	examine(mob/user)
		if (!..(user, 2))
			return
		user << "<span class = 'notice'>It contains:</span>"
		if (reagents && reagents.reagent_list.len)
			for (var/datum/reagent/R in reagents.reagent_list)
				user << "<span class = 'notice'>[R.volume] units of [R.name]</span>"
		else
			user << "<span class = 'notice'>Nothing.</span>"

	verb/set_APTFT() //set amount_per_transfer_from_this
		set name = "Set transfer amount"
		set category = null
		set src in view(1)
		var/N = input("Amount per transfer from this:","[src]") as null|anything in possible_transfer_amounts
		if (N)
			amount_per_transfer_from_this = N

	ex_act(severity)
		switch(severity)
			if (1.0)
				qdel(src)
				return
			if (2.0)
				if (prob(50))
					new /obj/effect/effect/water(loc)
					qdel(src)
					return
			if (3.0)
				if (prob(5))
					new /obj/effect/effect/water(loc)
					qdel(src)
					return
			else
		return







//Dispensers

/obj/structure/reagent_dispensers/barrel/water
	name = "water barrel"
	desc = "A wood barrel, filled with drinking water."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("water",250)


/obj/structure/reagent_dispensers/fueltank
	name = "fueltank"
	desc = "A fueltank. It is used to store high amounts of fuel."
	icon = 'icons/obj/objects.dmi'
	icon_state = "weldtank"
	amount_per_transfer_from_this = 10
	var/modded = FALSE
	var/obj/item/assembly_holder/rig = null
	New()
		..()
		reagents.add_reagent("fuel",500)

/obj/structure/reagent_dispensers/fueltank/examine(mob/user)
	if (!..(user, 2))
		return
	if (modded)
		user << "<span class = 'red'>The fuel faucet is wrenched open, leaking the fuel!</span>"
	if (rig)
		user << "<span class='notice'>There is some kind of device rigged to the tank.</span>"

/obj/structure/reagent_dispensers/fueltank/attack_hand()
	if (rig)
		usr.visible_message("<span class='notice'>\The [usr] begins to detach [rig] from \the [src].</span>", "<span class='notice'>You begin to detach [rig] from \the [src].</span>")
		if (do_after(usr, 20, src))
			usr.visible_message("<span class='notice'>\The [usr] detaches \the [rig] from \the [src].</span>", "<span class='notice'>You detach [rig] from \the [src]</span>")
			rig.loc = get_turf(usr)
			rig = null
			overlays = new/list()

/obj/structure/reagent_dispensers/fueltank/attackby(obj/item/weapon/W as obj, mob/user as mob)
	add_fingerprint(user)
	if (istype(W,/obj/item/weapon/wrench))
		user.visible_message("[user] wrenches [src]'s faucet [modded ? "closed" : "open"].", \
			"You wrench [src]'s faucet [modded ? "closed" : "open"]")
		modded = modded ? FALSE : TRUE
		if (modded)
			message_admins("[key_name_admin(user)] opened fueltank at [loc.loc.name] ([loc.x],[loc.y],[loc.z]), leaking fuel. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[loc.x];Y=[loc.y];Z=[loc.z]'>JMP</a>)")
			log_game("[key_name(user)] opened fueltank at [loc.loc.name] ([loc.x],[loc.y],[loc.z]), leaking fuel.")
			leak_fuel(amount_per_transfer_from_this)
	if (istype(W,/obj/item/assembly_holder))
		if (rig)
			user << "<span class='warning'>There is another device in the way.</span>"
			return ..()
		user.visible_message("\The [user] begins rigging [W] to \the [src].", "You begin rigging [W] to \the [src]")
		if (do_after(user, 20, src))
			user.visible_message("<span class='notice'>The [user] rigs [W] to \the [src].", "<span class = 'notice'> You rig [W] to \the [src].</span>")

			var/obj/item/assembly_holder/H = W
			if (istype(H.a_left,/obj/item/assembly/igniter) || istype(H.a_right,/obj/item/assembly/igniter))
				message_admins("[key_name_admin(user)] rigged fueltank at [loc.loc.name] ([loc.x],[loc.y],[loc.z]) for explosion. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[loc.x];Y=[loc.y];Z=[loc.z]'>JMP</a>)")
				log_game("[key_name(user)] rigged fueltank at [loc.loc.name] ([loc.x],[loc.y],[loc.z]) for explosion.")

			rig = W
			user.drop_item()
			W.loc = src

			var/icon/test = getFlatIcon(W)
			test.Shift(NORTH,1)
			test.Shift(EAST,6)
			overlays += test

	return ..()


/obj/structure/reagent_dispensers/fueltank/bullet_act(var/obj/item/projectile/Proj)
	if (Proj.get_structure_damage())
		if (Proj.firer)
			message_admins("[key_name_admin(Proj.firer)] shot fueltank at [loc.loc.name] ([loc.x],[loc.y],[loc.z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[loc.x];Y=[loc.y];Z=[loc.z]'>JMP</a>).")
			log_game("[key_name(Proj.firer)] shot fueltank at [loc.loc.name] ([loc.x],[loc.y],[loc.z]).")

		//if (!istype(Proj ,/obj/item/projectile/beam/practice) )
		explode()

/obj/structure/reagent_dispensers/fueltank/ex_act()
	explode()

/obj/structure/reagent_dispensers/fueltank/proc/explode()
	if (reagents.total_volume > 500)
		explosion(loc,1,2,4,2)
	else if (reagents.total_volume > 100)
		explosion(loc,0,1,3,1)
	else if (reagents.total_volume > 50)
		explosion(loc,-1,1,2,1)
	if (src) qdel(src)

/obj/structure/reagent_dispensers/fueltank/fire_act(temperature)
	if (modded)
		explode()
	else if (temperature > T0C+500)
		explode()
	return ..()

/obj/structure/reagent_dispensers/fueltank/Move()
	if (..() && modded)
		leak_fuel(amount_per_transfer_from_this/10.0)

/obj/structure/reagent_dispensers/fueltank/proc/leak_fuel(amount)
	if (reagents.total_volume == FALSE)
		return

	amount = min(amount, reagents.total_volume)
	reagents.remove_reagent("fuel",amount)
	new /obj/effect/decal/cleanable/liquid_fuel(loc, amount,1)

/obj/structure/reagent_dispensers/barrel/beer
	name = "beer barrel"
	desc = "A barrel of beer. Keep it secured!"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("beer",200)

/obj/structure/reagent_dispensers/barrel/rum
	name = "rum barrel"
	desc = "A barrel of rum. You better keep it locked and away from the crew!"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("rum",200)

/obj/structure/reagent_dispensers/barrel/gunpowder
	name = "gunpowder barrel"
	desc = "A barrel of gunpowder. Don't light it on fire."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_gunpowder"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("gunpowder",200)

/obj/structure/reagent_dispensers/barrel/gunpowder/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		if (prob(30))
			visible_message("<span class = 'warning'>\The [src] is hit by \the [proj] and explodes!</span>")
			return explode()
	return FALSE

/obj/structure/reagent_dispensers/barrel/gunpowder/ex_act()
	explode()

/obj/structure/reagent_dispensers/barrel/gunpowder/proc/explode()
	if (reagents.total_volume > 500)
		explosion(loc,1,2,4,2)
	else if (reagents.total_volume > 100)
		explosion(loc,0,1,3,1)
	else if (reagents.total_volume > 50)
		explosion(loc,-1,1,2,1)
	if (src) qdel(src)

/obj/structure/reagent_dispensers/barrel/gunpowder/fire_act(temperature)
	if (temperature > T0C+500)
		explode()
	return ..()
