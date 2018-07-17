//** Shield Helpers
//These are shared by various items that have shield-like behaviour

//bad_arc is the ABSOLUTE arc of directions from which we cannot block. If you want to fix it to e.g. the user's facing you will need to rotate the dirs yourself.
/proc/check_shield_arc(mob/user, var/bad_arc, atom/damage_source = null, mob/attacker = null)
	//check attack direction
	var/attack_dir = FALSE //direction from the user to the source of the attack
	if (istype(damage_source, /obj/item/projectile))
		var/obj/item/projectile/P = damage_source
		attack_dir = get_dir(get_turf(user), P.starting)
	else if (attacker)
		attack_dir = get_dir(get_turf(user), get_turf(attacker))
	else if (damage_source)
		attack_dir = get_dir(get_turf(user), get_turf(damage_source))

	if (!(attack_dir && (attack_dir & bad_arc)))
		return TRUE
	return FALSE

/proc/default_parry_check(mob/user, mob/attacker, atom/damage_source)
	//parry only melee attacks
	if (istype(damage_source, /obj/item/projectile) || (attacker && get_dist(user, attacker) > 1) || user.incapacitated())
		return FALSE

	//block as long as they are not directly behind us
	var/bad_arc = reverse_direction(user.dir) //arc of directions from which we cannot block
	if (!check_shield_arc(user, bad_arc, damage_source, attacker))
		return FALSE

	return TRUE

/obj/item/weapon/shield
	name = "shield"
	var/base_block_chance = 50

/obj/item/weapon/shield/handle_shield(mob/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	if (user.incapacitated())
		return FALSE

	//block as long as they are not directly behind us
	var/bad_arc = reverse_direction(user.dir) //arc of directions from which we cannot block
	if (check_shield_arc(user, bad_arc, damage_source, attacker))
		if (prob(get_block_chance(user, damage, damage_source, attacker)))
			user.visible_message("<span class='danger'>\The [user] blocks [attack_text] with \the [src]!</span>")
			return TRUE
	return FALSE

/obj/item/weapon/shield/proc/get_block_chance(mob/user, var/damage, atom/damage_source = null, mob/attacker = null)
	return base_block_chance
