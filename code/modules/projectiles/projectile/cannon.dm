/obj/item/projectile/shell
	name = "bullet"
	icon_state = "shell"
	damage = 200
	damage_type = BRUTE
	nodamage = FALSE
	check_armor = "bomb"
	embed = TRUE
	sharp = TRUE
	hitsound_wall = "ric_sound"
	var/mob_passthrough_check = FALSE
	penetrating = 10
	armor_penetration = 80
	heavy_armor_penetration = 25
	var/caliber = 75
	atype = "HE"
	tracer_type = /obj/effect/projectile/tracer/shell
	muzzle_type = /obj/effect/projectile/bullet/muzzle
	impact_type = /obj/effect/projectile/impact/heavy
	var/turf/targloc = null
	var/initiated = FALSE
	var/create_smoke = TRUE

/obj/item/projectile/shell/New()
	..()
	icon_state = "[atype]_shell"

/obj/item/projectile/shell/get_structure_damage()
	if (damage_type == BRUTE || damage_type == BURN)
		return damage/2
	return FALSE

/obj/item/projectile/shell/attack_mob(var/mob/living/target_mob, var/distance)
	. = ..()
	if(.)
		initiate(loc)

/obj/item/projectile/shell/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if (mob_passthrough_check)
		return FALSE
	return ..()

/obj/item/projectile/shell/on_impact(var/atom/A)
	playsound(src, "ric_sound", 50, TRUE, -2)
	if (istype(A, /turf))
		var/turf/T = A
		if (atype == "cannonball")
			if (!istype(T, /turf/floor/beach) && !istype(T, /turf/floor/broken_floor) && !istype(T, /turf/floor/trench))
				T.ChangeTurf(/turf/floor/dirt/burned)
			explosion(T, 1, 1, 1, 2)
		else
			if(!initiated)
				initiate(T)
	spawn(50)
		if (src)
			qdel(src)
	return TRUE

/obj/item/projectile/shell/impact_effect()
	if (ispath(impact_type))
		var/turf/effect_loc = null
		if(permutated.len > 0)
			effect_loc = permutated[permutated.len]
		else
			effect_loc = starting
		for(var/i = 0, i < 10, i++)
			var/obj/effect/projectile/P = new impact_type(effect_loc)
			if (istype(P))
				P.activate(get_angle())

/obj/item/projectile/shell/launch(atom/target, mob/user, obj/structure/cannon/modern/tank/launcher)
	targloc = get_turf(target)
	var/turf/curloc = get_turf(launcher)
	if (!istype(targloc) || !istype(curloc))
		qdel(src)
		return TRUE
	if (user)
		firer = user
		firer_original_dir = firer.dir
	else
		firer = null
		firer_original_dir = dir
	firedfrom = launcher

	if(user.buckled)
		for (var/obj/structure/turret/T in curloc)
			fired_from_turret = TRUE
		for (var/obj/structure/vehicleparts/frame/F in curloc)
			fired_from_axis = F.axis
			layer = 11

	original = target
	loc = curloc
	starting = curloc

	yo = targloc.y - curloc.y
	xo = targloc.x - curloc.x
	shot_from = launcher
	silenced = FALSE

	projectile_list += src

	update_icon()

	return FALSE

/obj/item/projectile/shell/proc/initiate(var/turf/T)
	if(!T)
		return
	var/caliber_modifier = clamp(round(caliber / 50), 0, 4)
	if (!istype(T, /turf/floor/beach) && !istype(T, /turf/floor/broken_floor) && !istype(T, /turf/floor/trench))
		if(caliber >= 37)
			T.ChangeTurf(/turf/floor/dirt/burned)
	if (atype == "HE")
		var/he_range = caliber_modifier
		var/list/fragment_types = list(/obj/item/projectile/bullet/pellet/fragment/short_range = 1)
		if(caliber < 37)
			explosion(T, 0, 0, 1, 2)
		else
			explosion(T, he_range, he_range + 1, he_range + 2, he_range + 3)
			fragmentate(T, 12, 7, fragment_types)
		loc = null
		qdel(src)
	else if (atype == "AP")
		var/ap_range = clamp(round(caliber_modifier / 2), 0, 4)
		var/list/fragment_types = list(/obj/item/projectile/bullet/pellet/fragment/short_range = 1)
		if(caliber >= 37)
			if(caliber >= 50)
				explosion(T, ap_range, ap_range + 1, ap_range + 2, 3)
			fragmentate(T, 8, 7, fragment_types)
		loc = null
		qdel(src)
	else if (atype == "APCR")
		if(!initiated)
			if(caliber >= 40)
				explosion(T, 0, 0, 1, 0)
			loc = null
			qdel(src)
			return

		var/num_fragments = 2 * caliber_modifier

		var/target_x = round(cos(angle) * 8)
		var/target_y = round(sin(angle) * 8)

		var/i
		for (i = 0, i < num_fragments, i++)
			spawn(i * 0.1)
				var/obj/item/projectile/bullet/pellet/fragment/P = new/obj/item/projectile/bullet/pellet/fragment(T)
				P.damage = 15
				P.pellets = num_fragments
				P.range_step = 2
				P.shot_from = name
				P.launch_fragment(locate(x + target_x + rand(-4,4), y + target_y + rand(-4,4), z))
				for (var/mob/living/L in T)
					P.attack_mob(L, 0, 0)
	else if (atype == "HEAT")
		var/num_fragments = 3 * caliber_modifier
		var/heat_range = clamp(round(caliber_modifier / 2), 0, 4)

		if(!initiated)
			explosion(T, heat_range, heat_range + 1, heat_range + 2, 3)
			loc = null
			qdel(src)
			return
		if(permutated.len > 1)
			explosion(permutated[permutated.len-1], heat_range, heat_range + 1, heat_range + 2, 3)
		else
			explosion(starting, heat_range, heat_range + 1, heat_range + 2, 3)

		var/target_x = round(cos(angle) * 6)
		var/target_y = round(sin(angle) * 6)

		var/i
		for (i = 0, i < num_fragments, i++)
			spawn(i * 0.1)
				var/obj/item/projectile/bullet/pellet/fragment/P = new/obj/item/projectile/bullet/pellet/fragment(T)
				P.damage = 15
				P.pellets = num_fragments
				P.range_step = 2
				P.shot_from = name
				P.launch_fragment(locate(x + target_x + rand(-3,3), y + target_y + rand(-3,3), z))
				for (var/mob/living/L in T)
					P.attack_mob(L, 0, 0)
		loc = null
		qdel(src)
	else if (atype == "HEI")
		var/hei_range = clamp(round(caliber_modifier / 2), 0, 4)
		explosion(T, hei_range, hei_range + 1, hei_range + 2, 3)
		ignite_turf(T,8,40)
		loc = null
		qdel(src)

//////////////////////////////////////////
////////////////AUTOCANNON////////////////

/obj/item/projectile/shell/autocannon
	icon = 'icons/obj/projectiles.dmi'
	icon_state = "bullet"
	damage = 50
	create_smoke = FALSE

/obj/item/projectile/shell/autocannon/New()
	..()
	icon_state = "bullet"

/obj/item/projectile/shell/autocannon/a20_aphe
	atype = "AP"
	heavy_armor_penetration = 32
	caliber = 20

/obj/item/projectile/shell/autocannon/a25_he
	atype = "HE"
	heavy_armor_penetration = 7
	caliber = 25

/obj/item/projectile/shell/autocannon/a25_ap
	atype = "AP"
	heavy_armor_penetration = 65
	caliber = 25

/obj/item/projectile/shell/autocannon/a30_he
	atype = "HE"
	heavy_armor_penetration = 8
	caliber = 30

/obj/item/projectile/shell/autocannon/a30_ap
	atype = "AP"
	heavy_armor_penetration = 82
	caliber = 30

/obj/item/projectile/shell/autocannon/a35_fap
	atype = "APCR"
	heavy_armor_penetration = 102
	caliber = 35

/obj/item/projectile/shell/autocannon/a35_hei
	atype = "HEI"
	heavy_armor_penetration = 11
	caliber = 35

//////////////////////////////////////////
////////////////CANNONBALL////////////////

/obj/item/projectile/shell/cannonball
	icon_state = "shell"
	atype = "cannonball"
/obj/item/projectile/shell/cannonball/chainshot
	icon_state = "chainshot"
	atype = "chainshot"
/obj/item/projectile/shell/cannonball/grapeshot
	icon_state = "buckshot"
	atype = "grapeshot"

/obj/item/projectile/shell/cannonball/on_impact(var/atom/A)
	impact_effect(effect_transform)		// generate impact effect
	playsound(src, artillery_in, 50, TRUE, -2)
	if (istype(A, /turf))
		var/turf/T = A
		if (atype == "cannonball")
			if (!istype(T, /turf/floor/beach) && !istype(T, /turf/floor/broken_floor))
				T.ChangeTurf(/turf/floor/dirt/burned)
			explosion(T, 1, 2, 2, 3)
		else
			if (!istype(T, /turf/floor/beach) && !istype(T, /turf/floor/broken_floor))
				T.ChangeTurf(/turf/floor/dirt/burned)
			explosion(T, 0, 0, 1, 3)
	spawn(50)
		if (src)
			qdel(src)
	return TRUE

/obj/item/projectile/shell/cannonball/get_structure_damage()
	if (atype == "chainshot")
		return damage/2
	if (atype == "grapeshot")
		return damage/5
	return FALSE

/obj/item/projectile/shell/cannonball/attack_mob(var/mob/living/target_mob)
	switch(atype)
		if("cannonball")
			if (prob(80))
				mob_passthrough_check = TRUE
			else
				mob_passthrough_check = FALSE
		if("grapeshot")
			mob_passthrough_check = FALSE
			is_shrapnel = TRUE
		if("chainshot")
			mob_passthrough_check = TRUE
			if (ishuman(target_mob))
				var/mob/living/human/H = target_mob
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_leg","l_arm","r_leg","r_arm"))
				affecting.droplimb(0, DROPLIMB_BLUNT)
	return ..()

/obj/item/projectile/shell/can_embed()
	//prevent embedding if the projectile is passing through the mob
	if (mob_passthrough_check)
		return FALSE
	return ..()
