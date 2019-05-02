/obj/item/projectile/arrow
	name = "arrow"
	icon_state = "arrow"
	damage = 40
	damage_type = BRUTE
	nodamage = FALSE
	check_armor = "arrow"
	embed = FALSE
	sharp = TRUE
	hitsound_wall = "ric_sound" //CHANGE
	var/mob_passthrough_check = FALSE
	var/move_tiles = -1
	var/moved_tiles = FALSE

/obj/item/projectile/arrow/get_structure_damage()
	if (damage_type == BRUTE)
		return 0
	if (damage_type == BURN)
		return damage/25
	return FALSE

/obj/item/projectile/arrow/on_hit(var/atom/target, var/blocked = FALSE)
	if (..(target, blocked))
		var/mob/living/L = target
		shake_camera(L, 3, 2)

/obj/item/projectile/arrow/attack_mob(var/mob/living/target_mob)
	mob_passthrough_check = FALSE
	return ..()

/obj/item/projectile/arrow/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if (mob_passthrough_check)
		return FALSE
	return ..()

/obj/item/projectile/arrow/check_penetrate(var/atom/A)
	if (!A || !A.density) return TRUE //if whatever it was got destroyed when we hit it, then I guess we can just keep going

	else if (ismob(A))
		if (!mob_passthrough_check)
			return FALSE
		if (iscarbon(A))
			damage *= 0.7 //squishy mobs absorb KE
		return TRUE

	var/chance = 0
	if (istype(A, /turf/wall))
		// wont penetrate walls
		chance = 0

	else if (istype(A, /obj/structure))
		chance = round(damage/2) + 20

	if (prob(chance))
		return TRUE

	return FALSE
