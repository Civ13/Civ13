// New version of fire that doesn't require ZAS. Mostly copypasta - Kachnov

/turf/var/fire_protection = FALSE //Protects newly extinguished tiles from being overrun again.
/turf/proc/apply_fire_protection()
/turf/apply_fire_protection()
	fire_protection = world.time

//Some legacy definitions so fires can be started.
/atom/proc/temperature_expose(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	return null


turf/proc/hotspot_expose(exposed_temperature, exposed_volume, soh = FALSE)
	return

/turf/hotspot_expose(exposed_temperature, exposed_volume, soh)
	if (fire_protection > world.time-300)
		return FALSE
	if (locate(/obj/fire) in src)
		return TRUE

	if (exposed_temperature < (T0C +  126))
		return FALSE

	var/igniting = FALSE

	//	create_fire(exposed_temperature)
	return igniting

/turf/var/obj/fire/fire = null

/turf/proc/create_fire(fl, temp, spread = TRUE)
	return FALSE

/turf/Entered(atom/movable/am,atom/oldloc)
	..(am,oldloc)
	if (isliving(am))
		var/mob/living/L = am
		if (fire)
			fire.Burn(L, 0.33) // sucks to die by trying to walk out of fire

var/list/fire_pool = list()
/proc/unpool_new_fire(location)
	if (fire_pool.len)
		var/obj/fire/F = pick(fire_pool)
		fire_pool -= F
		F.loc = location
		return F
	return new /obj/fire (location)

/turf/create_fire(fl, temp, spread = TRUE, _time_limit = 10)

	if (fire)
		fire.firelevel = max(fl, fire.firelevel)
		fire.temperature = max(temp, fire.temperature)
		return TRUE

	fire = unpool_new_fire(src)

	if (!fire)
		return null

	if (!spread)
		fire.nospread = TRUE

	fire.time_limit = _time_limit

	fire.temperature = temp

	fire.setup(src, fl)

	processes.callproc.queue(fire, /datum/proc/qdeleted, null, fire.time_limit)

	return fire

var/obj/burning_overlay_obj = null
var/obj/burning_overlay_turf = null

/obj/fire

	anchored = TRUE
	mouse_opacity = FALSE

	blend_mode = BLEND_ADD

	icon = 'icons/effects/fire.dmi'
	icon_state = "1"
	light_color = "#ED9200"
	layer = MOB_LAYER + 0.01 // above train pseudoturfs, stairs, and now MOBs

	var/firelevel = TRUE
	var/default_damage = 5
	var/spread_range = TRUE
	var/spread_prob = 10
	var/spread_fuel_prob = 80
	var/temperature = 500
	var/default_temperature = 500

	var/time_limit = 2

	var/ticks = FALSE

	var/nospread = FALSE

/obj/fire/process()
	. = TRUE

	if (!burning_overlay_obj)
		burning_overlay_obj = new
		var/icon/I = icon(icon, "burning") // 'fire2' stopped animating
//		I.Scale(48,96)
		burning_overlay_obj.icon = I
//		burning_overlay_obj.pixel_y = -32
//		burning_overlay_obj.pixel_x = -8
		burning_overlay_obj.layer = 5 // below smoke
		burning_overlay_obj.color = fire_color(500)

	if (!burning_overlay_turf)
		burning_overlay_turf = new
		var/icon/I = icon(icon, "burning")
		burning_overlay_turf.icon = I
		burning_overlay_turf.layer = 5 // below smoke
		burning_overlay_turf.color = fire_color(500)

	var/turf/my_tile = loc

	if (!istype(my_tile) && my_tile)
		if (my_tile.fire == src)
			my_tile.fire = null
			RemoveFire()
		return TRUE

	if (firelevel > 6)
		icon_state = "3"
		set_light(7, 3)
	else if (firelevel > 2.5)
		icon_state = "2"
		set_light(5, 2)
	else
		icon_state = "1"
		set_light(3, TRUE)

	for (var/mob/m in my_tile)
		Burn(m)

	var/list/fire_act_on = list()
	for (var/turf/T in range(my_tile, 1))
		fire_act_on += T
		fire_act_on += T.contents

	for (var/atom/a in fire_act_on)

		if (ismob(a))
			continue

		a.fire_act(temperature)

		// handle flammable objects

		if (a.density)

			var/a_is_flammable = FALSE
			if (list(/obj/structure/table/wood, /turf/wall/wood, /obj/structure/closet/cabinet, /obj/structure/barricade, /obj/structure/bed/chair/wood, /obj/structure/bookcase, /obj/structure/curtain, /obj/structure/window_frame).Find(a.type))
				a_is_flammable = TRUE
			if (!a_is_flammable)
				if (a.vars.Find("material"))
					if (istype(a:material, /material/wood))
						a_is_flammable = TRUE

			if (a_is_flammable && !a.overlays.Find(burning_overlay_obj) && !a.overlays.Find(burning_overlay_turf))

				if (istype(a, /obj))
					a.overlays |= burning_overlay_obj
					burning_obj_list += a

				else if (istype(a, /turf))
					a.overlays |= burning_overlay_turf
					burning_turf_list += a


	//spread

	if (!nospread)
		for (var/direction in cardinal)
			var/turf/enemy_tile = get_step(my_tile, direction)

			if (istype(enemy_tile))
				if (my_tile.open_directions & direction) //Grab all valid bordering tiles
					if (enemy_tile.fire)
						continue

					//if (!enemy_tile.zone.fire_tiles.len) TODO - optimize
				//	var/datum/gas_mixture/acs = enemy_tile.return_air()
				//	var/obj/effect/decal/cleanable/liquid_fuel/liquid = locate() in enemy_tile
				//	if (!acs || !acs.check_combustability(liquid))
					//	continue

					//If extinguisher mist passed over the turf it's trying to spread to, don't spread and
					//reduce firelevel.

					if (enemy_tile.fire_protection > world.time-30)
						firelevel -= 1.5
						continue

					//Spread the fire.

				/*	if (prob( 50 + 50 * (firelevel/vsc.fire_firelevel_multiplier) ) && my_tile && my_tile.CanPass(null, enemy_tile, FALSE,0) && enemy_tile && enemy_tile.CanPass(null, my_tile, FALSE,0))
						enemy_tile.create_fire(firelevel)*/

		//	else
			//	enemy_tile.adjacent_fire_act(loc, air_contents, air_contents.temperature, air_contents.volume)
	else
		firelevel -= 1.5

	animate(src, color = fire_color(temperature), 5)
	set_light(l_color = color)

	++ticks

	if (ticks > time_limit)
		qdeleted()

/obj/fire/proc/setup(newLoc,fl)

	if (!istype(loc, /turf))
		qdel(src)
		return

	set_dir(pick(cardinal))

	color = fire_color(temperature)
	set_light(3, TRUE, color)

	firelevel = fl

	processing_objects += src

/obj/fire/qdeleted()
	if (fire_pool.Find(src))
		loc = null
		return
	color = initial(color)
	set_light(0)
	processing_objects -= src
	RemoveFire()
	loc = null
	fire_pool |= src

/obj/fire/proc/fire_color(var/env_temperature)
	//var/temperature = max(4000*sqrt(firelevel/vsc.fire_firelevel_multiplier), env_temperature)
	//return heat2color(temperature)
	return heat2color(env_temperature)

/obj/fire/Destroy()
	RemoveFire()
	processing_objects -= src
	..()

/obj/fire/proc/RemoveFire()

	var/turf/T = loc
	if (istype(T))
		set_light(0)
		T.fire = null
		loc = null

/obj/fire/proc/get_damage()
	return (temperature/default_temperature) * default_damage

/obj/fire/proc/Burn(var/mob/living/L, var/power = 1.0)
	if (!istype(L))
		return

	var/damage = get_damage() * power

	if (prob((temperature/default_temperature) * 40))
		L.fire_act()

	if (!istype(L, /mob/living/carbon/human))
		L.apply_damage(damage*3)
	else
		var/mob/living/carbon/human/H = L

		var/head_exposure = TRUE
		var/chest_exposure = TRUE
		var/groin_exposure = TRUE
		var/legs_exposure = TRUE
		var/arms_exposure = TRUE

		//Get heat transfer coefficients for clothing.

		for (var/obj/item/clothing/C in src)
			if (H.l_hand == C || H.r_hand == C)
				continue

			if ( C.max_heat_protection_temperature >= temperature )
				if (C.body_parts_covered & HEAD)
					head_exposure = FALSE
				if (C.body_parts_covered & UPPER_TORSO)
					chest_exposure = FALSE
				if (C.body_parts_covered & LOWER_TORSO)
					groin_exposure = FALSE
				if (C.body_parts_covered & LEGS)
					legs_exposure = FALSE
				if (C.body_parts_covered & ARMS)
					arms_exposure = FALSE

		H.apply_damage(damage*0.5*head_exposure, BURN, "head", FALSE, FALSE, "Fire")
		H.apply_damage(damage*0.4*chest_exposure, BURN, "chest", FALSE, FALSE, "Fire")
		H.apply_damage(damage*0.4*groin_exposure, BURN, "groin", FALSE, FALSE, "Fire")
		H.apply_damage(damage*0.2*legs_exposure, BURN, "l_leg", FALSE, FALSE, "Fire")
		H.apply_damage(damage*0.2*legs_exposure, BURN, "r_leg", FALSE, FALSE, "Fire")
		H.apply_damage(damage*0.15*arms_exposure, BURN, "l_arm", FALSE, FALSE, "Fire")
		H.apply_damage(damage*0.15*arms_exposure, BURN, "r_arm", FALSE, FALSE, "Fire")

/obj/small_fire
	anchored = TRUE
	name = "fire"
	desc = "it's burning!"
	icon = 'icons/effects/fire.dmi'
	icon_state = "fire"
	layer = 3.13
	var/obj/origin

/obj/small_fire/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/CT = W
		for (var/datum/reagent/R in CT.reagents.reagent_list)
			if (istype(R, /datum/reagent/water))
				visible_message("[user] empties \the [CT] into the fire!")
				if (prob(max(R.volume, 100)))
					qdel(src)
					visible_message("The fire is put out!")
				CT.reagents.clear_reagents()

/obj/small_fire/New()
	..()
	fire_check()

/obj/small_fire/proc/fire_check()
	spawn(50)
		if (!(origin in src.loc))
			visible_message("The fire goes out.")
			qdel(src)
		else
			fire_check()
			return