/obj/item/projectile/bullet/pellet/fragment
	damage = 18
	range_step = 2 //controls damage falloff with distance. projectiles lose a "pellet" each time they travel this distance. Can be a non-integer.

	base_spread = FALSE //causes it to be treated as a shrapnel explosion instead of cone
	spread_step = 12

	silenced = TRUE
	no_attack_log = TRUE
	muzzle_type = null

	embed = TRUE
	sharp = TRUE

/obj/item/projectile/bullet/pellet/fragment/strong
	damage = 30

/obj/item/weapon/grenade/frag
	name = "fragmentation grenade"
	desc = "A military fragmentation grenade, designed to explode in a deadly shower of fragments, while avoiding massive structural damage."
	icon_state = "frggrenade"

	sharp = FALSE
	edge = FALSE
	throw_speed = 2
	throw_range = 30

	var/list/fragment_types = list(/obj/item/projectile/bullet/pellet/fragment = 1)
	var/num_fragments = 72  //total number of fragments produced by the grenade
	var/explosion_size = 2   //size of the center explosion

	//The radius of the circle used to launch projectiles. Lower values mean less projectiles are used but if set too low gaps may appear in the spread pattern
	var/spread_range = 7 //leave as is, for some reason setting this higher makes the spread pattern have gaps close to the epicenter

/obj/item/weapon/grenade/frag/activate()
	spawn(det_time)
		var/turf/O = get_turf(src)
		if(!O) return

		if(explosion_size)
			on_explosion(O)

		src.fragmentate(O, num_fragments, spread_range, fragment_types)

		spawn(5)
			qdel(src)


/obj/proc/fragmentate(var/turf/T, var/fragment_number = 30, var/spreading_range = 5, var/list/fragtypes=list(/obj/item/projectile/bullet/pellet/fragment/))
	set waitfor = 0
	..()
	
	if(!T) return

	var/list/target_turfs = getcircle(T, spreading_range)
	var/fragments_per_projectile = round(fragment_number/target_turfs.len)

	for(var/turf/TT in target_turfs)
		sleep(0)
		var/fragment_type = pickweight(fragtypes)
		var/obj/item/projectile/bullet/pellet/fragment/P = new fragment_type(T)
		P.pellets = fragments_per_projectile
		P.shot_from = src.name

		P.launch_fragment(TT)
		P.firer_loc = get_turf(src)

		//Make sure to hit any mobs in the source turf
		for(var/mob/living/M in T)
			P.attack_mob(M, 0, 0)



/obj/item/weapon/grenade/frag/proc/on_explosion(var/turf/O)
	if(explosion_size)
		explosion(O, -1, -1, explosion_size, round(explosion_size/2), 0)

/obj/item/weapon/grenade/frag/shell
	name = "fragmentation grenade"
	desc = "A light fragmentation grenade, designed to be fired from a launcher. It can still be activated and thrown by hand if necessary."
	icon_state = "fragshell"

	num_fragments = 50 //less powerful than a regular frag grenade

/obj/item/weapon/grenade/frag/high_yield
	name = "fragmentation bomb"
	desc = "Larger and heavier than a standard fragmentation grenade, this device is extremely dangerous. It cannot be thrown as far because of its weight."
	icon_state = "frag"

	w_class = ITEM_SIZE_NORMAL
	throw_speed = 3
	throw_range = 5 //heavy, can't be thrown as far

	fragment_types = list(/obj/item/projectile/bullet/pellet/fragment=1,/obj/item/projectile/bullet/pellet/fragment/strong=4)
	num_fragments = 200  //total number of fragments produced by the grenade
	explosion_size = 3

/obj/item/weapon/grenade/frag/high_yield/on_explosion(var/turf/O)
	if(explosion_size)
		explosion(O, 0, 2, explosion_size, 2) //has a chance to blow a hole in the floor


/obj/item/weapon/grenade/frag/ugl/shell40mm
	name = "40x46mm 'M381 HE' grenade shell"
	desc = "Cannot be thrown as the usual grenade, by the way."
	icon_state = "M406"
	num_fragments = 50
	fragment_types = list(/obj/item/projectile/bullet/pellet/fragment)
	explosion_size = 2
	throw_range = 30

/obj/item/weapon/grenade/frag/ugl/shell40mm/attack_self(mob/user)
	return

/obj/item/weapon/grenade/frag/ugl/vog25
	name = "40x103mm 'VOG-25' grenade shell"
	desc = "Cannot be thrown as the usual grenade, by the way."
	icon_state = "40x103mmshell"
	num_fragments = 50
	fragment_types = list(/obj/item/projectile/bullet/pellet/fragment)
	explosion_size = 2
	throw_range = 30
