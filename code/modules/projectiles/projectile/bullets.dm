/obj/item/projectile/bullet
	name = "bullet"
	icon_state = "bullet"
	damage = 60
	damage_type = BRUTE
	nodamage = FALSE
	check_armor = "gun"
	embed = FALSE
	sharp = TRUE
	hitsound_wall = "ric_sound"
	var/mob_passthrough_check = FALSE
	var/move_tiles = -1
	var/moved_tiles = FALSE

	muzzle_type = /obj/effect/projectile/bullet/muzzle

/obj/item/projectile/bullet/get_structure_damage()
	if (damage_type == BRUTE || damage_type == BURN)
		return damage/25 // bullets are no longer good at destroying walls, use c4 - Kachnov
	return FALSE

/obj/item/projectile/bullet/on_hit(var/atom/target, var/blocked = FALSE)
	if (..(target, blocked))
		var/mob/living/L = target
		shake_camera(L, 3, 2)

/obj/item/projectile/bullet/attack_mob(var/mob/living/target_mob)
	if (penetrating > 1 && damage > 20 && prob(damage))
		mob_passthrough_check = TRUE
	else
		mob_passthrough_check = FALSE
	return ..()

/obj/item/projectile/bullet/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if (mob_passthrough_check)
		return FALSE
	return ..()

/obj/item/projectile/bullet/check_penetrate(var/atom/A)
	if (!A || !A.density) return TRUE //if whatever it was got destroyed when we hit it, then I guess we can just keep going

	else if (ismob(A))
		if (!mob_passthrough_check)
			return FALSE
		if (iscarbon(A))
			damage *= 0.7 //squishy mobs absorb KE
		return TRUE

	var/chance = 0
	if (istype(A, /turf/wall))
		var/turf/wall/W = A

		// 21% chance for rifles to penetrate a brick wall, 62% for a wood wall
		chance = round((damage/(W.material ? W.material.integrity : 175)) * 150)
		// 1/3rd of that for MGs, buffed since their accuracy was fixed
		if (istype(firedfrom, /obj/item/weapon/gun/projectile/automatic/stationary))
			chance /= 2

	else if (istype(A, /obj/structure))
		chance = round(damage/2) + 10

	if (prob(chance))
		return TRUE

	return FALSE

//For projectiles that actually represent clouds of projectiles
/obj/item/projectile/bullet/pellet
	name = "shrapnel" //'shrapnel' sounds more dangerous (i.e. cooler) than 'pellet'
	damage = 20
	icon_state = "bullet" //TODO: would be nice to have it's own icon state
	var/pellets = 4			//number of pellets
	var/range_step = 2		//projectile will lose a fragment each time it travels this distance. Can be a non-integer.
	var/base_spread = 90	//lower means the pellets spread more across body parts. If zero then this is considered a shrapnel explosion instead of a shrapnel cone
	var/spread_step = 10	//higher means the pellets spread more across body parts with distance
	move_tiles = 7 // 7 tiles

/obj/item/projectile/bullet/pellet/Bumped()
	. = ..()
	bumped = FALSE //can hit all mobs in a tile. pellets is decremented inside attack_mob so this should be fine.

/obj/item/projectile/bullet/pellet/proc/get_pellets(var/distance)
	var/pellet_loss = round((distance - 1)/range_step) //pellets lost due to distance
	return max(pellets - pellet_loss, 1)

/obj/item/projectile/bullet/pellet/attack_mob(var/mob/living/target_mob, var/distance, var/miss_modifier)
	if (pellets < 0) return TRUE

	var/total_pellets = get_pellets(distance)
	var/spread = max(base_spread - (spread_step*distance), FALSE)

	//shrapnel explosions miss prone mobs with a chance that increases with distance
	var/prone_chance = FALSE
	if (!base_spread)
		prone_chance = max(spread_step*(distance - 2), FALSE)

	var/hits = FALSE
	for (var/i in 1 to total_pellets)
		if (target_mob.lying && target_mob != original && prob(prone_chance))
			continue

		//pellet hits spread out across different zones, but 'aim at' the targeted zone with higher probability
		//whether the pellet actually hits the def_zone or a different zone should still be determined by the parent using get_zone_with_miss_chance().
		var/old_zone = def_zone
		def_zone = ran_zone(def_zone, spread)
		if (..()) hits++
		def_zone = old_zone //restore the original zone the projectile was aimed at

	pellets -= hits //each hit reduces the number of pellets left
	if (hits >= total_pellets || pellets <= 0)
		return TRUE
	return FALSE

/obj/item/projectile/bullet/pellet/get_structure_damage()
	var/distance = get_dist(loc, starting)
	return ..() * get_pellets(distance)

/obj/item/projectile/bullet/pellet/Move()
	. = ..()

	++moved_tiles
	if (moved_tiles >= move_tiles)
		return

	//If this is a shrapnel explosion, allow mobs that are prone to get hit, too
	if (. && !base_spread && isturf(loc))
		for (var/mob/living/M in loc)
			if (M.lying || !M.CanPass(src, loc)) //Bump if lying or if we would normally Bump.
				if (Bump(M)) //Bump will make sure we don't hit a mob multiple times
					return

/* short-casing projectiles, like the kind used in pistols or SMGs */

/obj/item/projectile/bullet/pistol
	damage = 20

/obj/item/projectile/bullet/pistol/medium
	damage = 25

/obj/item/projectile/bullet/pistol/strong //revolvers and matebas
	damage = 60

/obj/item/projectile/bullet/pistol/rubber //"rubber" bullets
	name = "rubber bullet"
	check_armor = "melee"
	damage = 5
	agony = 25
	embed = FALSE
	sharp = FALSE

//Should do about 80 damage at 1 tile distance (adjacent), and 50 damage at 3 tiles distance.
//Overall less damage than slugs in exchange for more damage at very close range and more embedding
/obj/item/projectile/bullet/pellet/shotgun
	name = "shrapnel"
	damage = 13
	pellets = 6
	range_step = TRUE
	spread_step = 10

/* "Rifle" rounds */

/obj/item/projectile/bullet/rifle
	armor_penetration = 20
	penetrating = 1


/obj/item/projectile/bullet/gyro/on_hit(var/atom/target, var/blocked = FALSE)
	if (isturf(target))
		explosion(target, -1, FALSE, 2)
	..()

/obj/item/projectile/bullet/blank
	invisibility = 101
	damage = TRUE
	embed = FALSE