/obj/structure/TV
	name = "television"
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
	var/mob/living/carbon/human/stored_unit = null

	var/protection_chance = 85 //odds of something hitting the TV

/obj/structure/TV/active //no television channels... yet.
	icon_state = "TV_wn"
	active = TRUE

/obj/structure/TV/active/examine(var/mob/living/L)
	L << "There is nothing on television at the moment except static. Typical."
	return

/* Clocks*/

/obj/structure/TV/grandfather
	name = "grandfather clock"
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
	protection_chance = 85 //odds of something hitting the TV

/obj/structure/TV/grandfather/inactive
	icon_state = "grandfather_clock"
	active = FALSE

/obj/structure/TV/grandfather/inactive/examine(var/mob/living/L) //it would be fun to have nukes set clocks inactive or halt at a time.
	L << "This clock's stopped running, you can't tell what hour it is currently."
	return

/obj/structure/TV/grandfather/examine(var/mob/living/L)
	L << "<big>It is now [clock_time()].</big>"
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

/obj/structure/TV/attackby(obj/O as obj, mob/living/carbon/human/user as mob)
	if (istype(O,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(O,/obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			qdel(src)

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

/* Grandfather Technical*/