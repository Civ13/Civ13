/obj/structure/TV
	name = "television"
	desc = "A television for watching broadcasted programmes. Its switched off."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "TV"
	anchored = TRUE
	var/destroyed = FALSE
	var/active = FALSE
	density = TRUE
	flammable = FALSE
	var/health = 100
	var/maxhealth = 100
	not_movable = TRUE
	not_disassemblable = TRUE
	var/mob/living/human/stored_unit = null

	var/protection_chance = 85 //odds of something hitting the TV

/obj/structure/TV/active //no television channels... yet.
	icon_state = "TV_wn"
	desc = "A television for watching broadcasted programmes. Its switched on."
	active = TRUE

/obj/structure/TV/active/examine(var/mob/living/L)
	L << "There is nothing on television at the moment except static. Typical."
	return

/* Clocks*/

/obj/structure/TV/grandfather
	name = "grandfather clock"
	desc = "A tall wooden grandfather clock. The clock hands & pendulum move frequently as time slips by."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "grandfather_clock_a"
	anchored = TRUE
	destroyed = FALSE
	active = TRUE
	density = TRUE
	flammable = TRUE
	health = 100
	maxhealth = 100
	not_movable = FALSE
	not_disassemblable = FALSE
	protection_chance = 85

/obj/structure/TV/grandfather/inactive
	icon_state = "grandfather_clock"
	desc = "A tall wooden grandfather clock. The clock hands & pendulum have frozen in place, inert."
	active = FALSE

/obj/structure/TV/grandfather/inactive/examine(var/mob/living/L) //it would be fun to have nukes set clocks inactive or halt at a time.
	L << "This clock's stopped running, you can't tell what time it is currently."
	return

/obj/structure/TV/grandfather/examine(var/mob/living/L)
	L << "<big>It is now [clock_time()].</big>"
	return

/obj/structure/TV/television //in prep for actually interesting and watchable tv's
	name = "television"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "TV"
	anchored = TRUE
	destroyed = FALSE
	active = FALSE
	density = TRUE
	flammable = FALSE
	health = 100
	maxhealth = 100
	not_movable = TRUE
	not_disassemblable = TRUE

	protection_chance = 85

/obj/structure/TV/television/active
	icon_state = "TV_wn"
	desc = "A television for watching broadcasted programmes. Its switched on."
	active = TRUE

/obj/structure/TV/television/active/examine(var/mob/living/L)
	L << "There is nothing on television at the moment except static. Typical."
	return

/* TV Technical*/

/obj/structure/TV/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/item/projectile))
		return prob(100-protection_chance)
	else
		return FALSE

/obj/structure/TV/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage/3
	visible_message("<span class='warning'>\The [src] is hit by the [proj.name]!</span>")
	try_destroy()

/obj/structure/TV/fire_act(temperature)
	if (prob(35 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is damaged by the fire and breaks apart!.</span>")
		qdel(src)

/obj/structure/TV/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * TRUE
		if ("brute")
			health -= W.force * 0.20
	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/TV/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/item/projectile))
		return prob(100-protection_chance)
	else
		return FALSE

/obj/structure/TV/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage/3
	visible_message("<span class='warning'>\The [src] is hit by the [proj.name]!</span>")
	try_destroy()

/obj/structure/TV/proc/try_destroy()
	if (health <= 0)
		if (stored_unit)
			release_stored()
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		qdel(src)
		return

/obj/structure/TV/attack_hand(mob/user as mob)
	if (stored_unit)
		if (user == stored_unit)
			release_stored()
	else
		..()
/obj/structure/TV/proc/release_stored()
	if (stored_unit)
		if (stored_unit.client)
			stored_unit.client.eye = stored_unit.client.mob
			stored_unit.client.perspective = MOB_PERSPECTIVE
			stored_unit.forceMove(get_turf(src))
			stored_unit = null
			return

/* Television Technical (reserved)*/

/obj/structure/TV/television/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(O,/obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin smashing apart \the [src].</span>"
		if (do_after(user,30,src))
			user << "<span class='notice'>You roughly smash apart \the [src].</span>"
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/electronics(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,20,src))
			user << "<span class='notice'>You carefully dismantle \the [src].</span>" //scavenging, the new proceeds auto-stack.
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/electronics(loc)
			new /obj/item/stack/material/electronics(loc)
			new /obj/item/stack/material/electronics(loc)
			qdel(src)


/* Clocks Technical (reserved)*/

/obj/structure/TV/grandfather/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(O,/obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin smashing apart \the [src].</span>"
		if (do_after(user,30,src))
			user << "<span class='notice'>You roughly smash apart \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			qdel(src)
	else if (istype(O,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,20,src))
			user << "<span class='notice'>You carefully dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/glass(loc)
			new /obj/item/stack/material/glass(loc)
			qdel(src)

/obj/structure/coolingfan
	name = "cooling fan"
	desc = "A rotating cooling fan. It's switched off."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "fan"
	anchored = TRUE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/on = FALSE

/obj/structure/coolingfan/attack_hand(mob/user as mob)
	if (on == FALSE)
		usr << "You turn the cooling fan on."
		icon_state = "fan_working"
		on = TRUE
	else
		usr << "You turn the cooling fan off."
		icon_state = "fan"
		on = FALSE

