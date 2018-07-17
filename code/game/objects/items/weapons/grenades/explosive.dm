/obj/item/projectile/bullet/pellet/fragment
	damage = 18
	range_step = 2

	base_spread = FALSE //causes it to be treated as a shrapnel explosion instead of cone
	spread_step = 12

	silenced = TRUE //embedding messages are still produced so it's kind of weird when enabled.
	no_attack_log = TRUE
	muzzle_type = null

	embed = TRUE

/obj/item/projectile/bullet/pellet/fragment/strong
	damage = 24

/obj/item/weapon/grenade/explosive
	name = "fragmentation grenade"
	desc = "A fragmentation grenade, optimized for harming personnel without causing massive structural damage."
	icon_state = "frggrenade"
	item_state = "grenade"
	loadable = TRUE

	var/fragment_type = /obj/item/projectile/bullet/pellet/fragment
	var/num_fragments = 50  //total number of fragments produced by the grenade
	var/fragment_damage = 15
	var/damage_step = 2      //projectiles lose a fragment each time they travel this distance. Can be a non-integer.
	var/explosion_size = 2   //size of the center explosion
	var/big_bomb = FALSE

	//The radius of the circle used to launch projectiles. Lower values mean less projectiles are used but if set too low gaps may appear in the spread pattern
	var/spread_range = 7

/obj/item/weapon/grenade/explosive/prime()
	if (active)
		set waitfor = FALSE
		..()

		var/turf/T = get_turf(src)
		if (!T) return

		if (explosion_size)
			spawn (2)
				on_explosion(T)

		if (!ismob(loc))

			var/list/target_turfs = getcircle(T, spread_range)
			var/fragments_per_projectile = round(num_fragments/target_turfs.len)

			for (var/turf/TT in target_turfs)
				var/obj/item/projectile/bullet/pellet/fragment/P = new fragment_type(T)
				P.damage = fragment_damage
				P.pellets = fragments_per_projectile
				P.range_step = damage_step
				P.shot_from = name
				P.launch_fragment(TT)

				// any mob on the source turf, lying or not, absorbs 100% of shrapnel now
				for (var/mob/living/L in T)
					P.attack_mob(L, 0, 0)

		spawn (5)
			qdel(src)

/obj/item/weapon/grenade/explosive/proc/on_explosion(var/turf/T)
	if (explosion_size)
		if (!big_bomb)
			explosion(T, 1, 1, 2, round(explosion_size/2), FALSE)
		else
			explosion(T, 3, 3, 4, round(explosion_size), FALSE)

/obj/item/weapon/grenade/explosive/frag
	name = "fragmentation grenade"
	desc = "A military fragmentation grenade, designed to explode in a deadly shower of fragments."
	icon_state = "frag"

	fragment_type = /obj/item/projectile/bullet/pellet/fragment/strong
	num_fragments = 200  //total number of fragments produced by the grenade

/obj/item/weapon/grenade/explosive/frag/on_explosion(var/turf/O)
	if (explosion_size)
		explosion(O, 1, round(explosion_size/2), explosion_size, round(explosion_size/2), FALSE)
