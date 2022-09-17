/obj/item/projectile/laser
	name = "bolt"
	icon_state = "redbolt"
	damage = 60
	damage_type = BURN
	nodamage = FALSE
	check_armor = "energy"
	embed = FALSE
	sharp = FALSE
	hitsound_wall = "laser_ric_sound"
	damage = DAMAGE_LOW
	penetrating = 8
	armor_penetration = 0
	light_color = "#ff0000"
	light_range = 3
	var/mob_passthrough_check = FALSE
	var/move_tiles = -1
	var/moved_tiles = FALSE

	muzzle_type = /obj/effect/projectile/laser/muzzle

/obj/item/projectile/laser/get_structure_damage()
	if (damage_type == BRUTE || damage_type == BURN)
		return damage/25 // bullets are no longer good at destroying walls, use c4 - Kachnov
	return FALSE

/obj/item/projectile/laser/on_hit(var/atom/target, var/blocked = FALSE)
	if (..(target, blocked))
		var/mob/living/L = target
		shake_camera(L, 3, 2)

/obj/item/projectile/laser/attack_mob(var/mob/living/target_mob)
	if (penetrating > 1 && damage > 20 && prob(damage))
		mob_passthrough_check = TRUE
	else
		mob_passthrough_check = FALSE
	return ..()

/obj/item/projectile/laser/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if (mob_passthrough_check)
		return FALSE
	return ..()

/obj/item/projectile/laser/check_penetrate(var/atom/A)
	if (!A || !A.density) return TRUE //if whatever it was got destroyed when we hit it, then I guess we can just keep going

	else if (ismob(A))
		if (!mob_passthrough_check)
			return FALSE
		if (ishuman(A))
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

////////////////////////////LASERS///////////////////////////////////
/obj/item/projectile/laser/b
	icon_state = "bluebolt"
	muzzle_type = /obj/effect/projectile/laser/muzzle/b
	light_color = "#3b719f"

/obj/item/projectile/laser/g
	icon_state = "greenbolt"
	muzzle_type = /obj/effect/projectile/laser/muzzle/g
	light_color = "#00bf00"
/obj/item/projectile/laser/pistol
	damage = 25
	penetrating = 6
	armor_penetration = 0

/obj/item/projectile/laser/pistol/b
	icon_state = "bluebolt"
	muzzle_type = /obj/effect/projectile/laser/muzzle/b
	light_color = "#3b719f"
/obj/item/projectile/laser/pistol/g
	icon_state = "greenbolt"
	muzzle_type = /obj/effect/projectile/laser/muzzle/g
	light_color = "#00bf00"

/obj/item/projectile/laser/repeating
	damage = 120
	icon_state = "redbolt"
	muzzle_type = /obj/effect/projectile/laser/muzzle