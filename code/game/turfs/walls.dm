var/list/global/wall_cache = list()

/turf/wall
	name = "wall"
	desc = "A huge chunk of metal used to seperate rooms."
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "generic"
	opacity = TRUE
	density = TRUE
	heat_capacity = 312500 //a little over 5 cm thick , 312500 for TRUE m by 2.5 m by 0.25 m plasteel wall
	plane = GAME_PLANE
	overlay_priority = 100
	var/damage = FALSE
	var/damage_overlay = FALSE
	var/global/damage_overlays[16]
	var/active
	var/can_open = FALSE
	var/material/material
	var/last_state
	var/construction_stage
	var/hitsound = 'sound/weapons/Genhit.ogg'
	var/list/wall_connections = list("0", "0", "0", "0")
	var/ref_state = "generic"
	var/tank_destroyable = TRUE
	var/ricochet_id = 0

// Extracts ricochet angle's tan if ischance = 1.
// In other case it just makes bullets and lazorz go where they're supposed to.
/turf/wall/proc/bullet_ricochet(var/obj/item/projectile/Proj, var/ischance = 0)
	if(Proj.starting)
		var/turf/curloc = get_turf(src)
		var/ricochet_temp_id = rand(1,1000)
		if(!ischance) Proj.ricochet_id = ricochet_temp_id
		if(!ischance && ((curloc.x == Proj.starting.x) || (curloc.y == Proj.starting.y)))
			var/random_value = pick(-1, 0, 1)
			var/critical_x = Proj.starting.x + random_value
			var/critical_y = Proj.starting.y + random_value
			Proj.redirect(critical_x, critical_y, curloc, src)
			visible_message(SPAN_DANGER("\The [Proj] ricochets from the surface of \the [src]!"))
			playsound(curloc, "ric_sound", 50, TRUE, -2)
			return
		var/check_x0 = 32 * curloc.x
		var/check_y0 = 32 * curloc.y
		var/check_x1 = 32 * Proj.starting.x
		var/check_y1 = 32 * Proj.starting.y
		var/check_x2 = 32 * Proj.original.x
		var/check_y2 = 32 * Proj.original.y
		var/corner_x0 = check_x0
		var/corner_y0 = check_y0
		if(check_y0 - check_y1 > 0)
			corner_y0 = corner_y0 - 16
		else
			corner_y0 = corner_y0 + 16
		if(check_x0 - check_x1 > 0)
			corner_x0 = corner_x0 - 16
		else
			corner_x0 = corner_x0 + 16
		// Checks if original is lower or upper than line connecting proj's starting and wall
		// In specific coordinate system that has wall as (0,0) and 'starting' as (r, 0), where r > 0.
		// So, this checks whether 'original's' y-coordinate is positive or negative in new c.s.
		// In order to understand, in which direction bullet will ricochet.
		// Actually new_y isn't y-coordinate, but it has the same sign.
		var/new_y = (check_y2 - corner_y0) * (check_x1 - corner_x0) - (check_x2 - corner_x0) * (check_y1 - corner_y0)
		// Here comes the thing which differs two situations:
		// First - bullet comes from north-west or south-east, with negative func value. Second - NE or SW.
		var/new_func = (corner_x0 - check_x1) * (corner_y0 - check_y1)
		// Added these wall things because my original code works well with one-tiled walls, but ignores adjacent turfs which in my current opinion was pretty wrong.
		var/wallnorth = 0
		var/wallsouth = 0
		var/walleast = 0
		var/wallwest = 0
		for (var/turf/wall/W in range(2, curloc))
			var/turf/tempwall = get_turf(W)
			if (tempwall.x == curloc.x)
				if (tempwall.y == (curloc.y - 1))
					wallnorth = 1
					if (!ischance) W.ricochet_id = ricochet_temp_id
				else if (tempwall.y == (curloc.y + 1))
					wallsouth = 1
					if (!ischance) W.ricochet_id = ricochet_temp_id
			if (tempwall.y == curloc.y)
				if (tempwall.x == (curloc.x + 1))
					walleast = 1
					if (!ischance) W.ricochet_id = ricochet_temp_id
				else if (tempwall.x == (curloc.x - 1))
					wallwest = 1
					if (!ischance) W.ricochet_id = ricochet_temp_id
		if((wallnorth || wallsouth) && ((Proj.starting.y - curloc.y)*(wallsouth - wallnorth) >= 0))
			if(!ischance)
				Proj.redirect(round(check_x1 / 32), round((2 * check_y0 - check_y1)/32), curloc, src)
				visible_message(SPAN_DANGER("\The [Proj] ricochets from the surface of \the [src]!"))
				playsound(curloc, "ric_sound", 50, TRUE, -2)
				return
			else
				return abs((check_y0 - check_y1) / (check_x0 - check_x1))
		if((walleast || wallwest) && ((Proj.starting.x - curloc.x)*(walleast-wallwest) >= 0))
			if(!ischance)
				Proj.redirect(round((2 * check_x0 - check_x1) / 32), round(check_y1 / 32), curloc, src)
				visible_message(SPAN_DANGER("\The [Proj] ricochets from the surface of \the [src]!"))
				playsound(curloc, "ric_sound", 50, TRUE, -2)
				return
			else
				return abs((check_x0 - check_x1) / (check_y0 - check_y1))
		if((new_y * new_func) > 0)
			if(!ischance)
				Proj.redirect(round((2 * check_x0 - check_x1) / 32), round(check_y1 / 32), curloc, src)
				visible_message(SPAN_DANGER("\The [Proj] ricochets from the surface of \the [src]!"))
				playsound(curloc, "ric_sound", 50, TRUE, -2)
			else
				return abs((check_x0 - check_x1) / (check_y0 - check_y1))
		else
			if(!ischance)
				Proj.redirect(round(check_x1 / 32), round((2 * check_y0 - check_y1)/32), curloc, src)
				visible_message(SPAN_DANGER("\The [Proj] ricochets from the surface of \the [src]!"))
				playsound(curloc, "ric_sound", 50, TRUE, -2)
			else
				return abs((check_y0 - check_y1) / (check_x0 - check_x1))
		return

/turf/wall/void
	icon_state = "void"
	damage = -100000
	tank_destroyable = FALSE

/turf/wall/rockwall
	name = "cave wall"
	icon = 'icons/turf/walls.dmi'
	icon_state = "rock"
	tank_destroyable = FALSE
	layer = TURF_LAYER + 0.02 // above lifts
	desc = "A massive slab of rock in the shape of a wall."

/turf/wall/rockwall/lavaspawner

/turf/wall/rockwall/attackby(obj/item/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	if(istype(W, /obj/item/weapon/chisel))
		var design = "smooth"
		if (!istype(H.l_hand, /obj/item/weapon/hammer) && !istype(H.r_hand, /obj/item/weapon/hammer))
			user << "<span class = 'warning'>You need to have a hammer in one of your hands to use a chisel.</span>"
			return
		else
			var/display = list("Smooth", "Cave", "Underground Cave", "Brick", "Cobbled", "Tiled", "Cancel")
			var/input =  WWinput(user, "What design do you want to carve?", "Carving", "Cancel", display)
			if (input == "Cancel")
				return
			else if  (input == "Smooth")
				user << "<span class='notice'>You will now carve the smooth design!</span>"
				design = "smooth"
			else if  (input == "Cave")
				user << "<span class='notice'>You will now carve the cave design!</span>"
				design = "cave"
			else if  (input == "Underground Cave")
				user << "<span class='notice'>You will now carve the cave design!</span>"
				design = "undercave"
			else if  (input == "Brick")
				user << "<span class='notice'>You will now carve the brick design!</span>"
				design = "brick"
			else if  (input == "Cobbled")
				user << "<span class='notice'>You will now carve the cobbled design!</span>"
				design = "cobbled"
			else if  (input == "Tiled")
				user << "<span class='notice'>You will now carve the tiled design!</span>"
				design = "tiled"
			visible_message("<span class='danger'>[user] starts to chisel a design!</span>", "<span class='danger'>You start chiseling a design.</span>")
			playsound(src,'sound/effects/pickaxe.ogg',60,1)
			if (do_after(user, 60, src))
			//Designs possible are "smooth", "cave", "brick", "cobbled", "tiled"
				if(design == "smooth")
					src.icon_state = "b_stone_wall"
					src.name = "stone wall"
					src.desc = "A cave wall carved smooth."
				else if(design == "cave")
					src.icon_state = "rocky"
					src.name = "underground cave wall"
					src.desc = "A cave wall."
				else if(design == "undercave")
					src.icon_state = "rock"
					src.name = "cave wall"
					src.desc = "A cave wall."
				else if(design == "brick")
					src.icon_state = "b_brick_stone_wall"
					src.name = "stone brick wall"
					src.desc = "A cave wall carved to look like its made of stone bricks."
				else if(design == "cobbled")
					src.icon_state = "b_cobbled_stone_wall"
					src.name = "cobbled stone wall"
					src.desc = "A cave wall carved to look like piled up stones."
				else if(design == "tiled")
					src.icon_state = "b_tiled_stone_wall"
					src.name = "tiled stone wall"
					src.desc = "A cave wall carved to have a tiled stone pattern."
				return
	..()

// Walls always hide the stuff below them.
/turf/wall/levelupdate()
	for (var/obj/O in src)
		O.hide(1)

/turf/wall/New(var/newloc, var/materialtype)
	..(newloc)
	if (!istype(src, /turf/wall/rockwall))
		icon_state = "blank"
		if (!materialtype)
			materialtype = DEFAULT_WALL_MATERIAL
		material = get_material_by_name(materialtype)
		update_material()
		hitsound = material.hitsound
	else
		icon = 'icons/turf/walls.dmi'
		icon_state = "rock"

	for (var/atom/movable/lighting_overlay/L in view(7*3, src))
		L.update_overlay()

/turf/wall/Destroy()
	dismantle_wall(null,null,1)
	for (var/atom/movable/lighting_overlay/L in view(7*3, src))
		L.update_overlay()
	..()

/turf/wall/bullet_act(var/obj/item/projectile/Proj)
	var/proj_damage = Proj.get_structure_damage()

	//cap the amount of damage, so that things like emitters can't destroy walls in one hit.
	var/damage = min(proj_damage, 100)

	take_damage(damage)
	return

/turf/wall/hitby(AM as mob|obj, var/speed=THROWFORCE_SPEED_DIVISOR)
	..()
	if (ismob(AM))
		return

	var/tforce = AM:throwforce * (speed/THROWFORCE_SPEED_DIVISOR)
	if (tforce < 15)
		return

	take_damage(tforce)

//Appearance
/turf/wall/examine(mob/user)
	. = ..(user)

	if (!damage && material)
		user << "<span class='notice'>It looks fully intact.</span>"
	else
		if (material)
			var/dam = damage / material.integrity
			if (dam <= 0.3)
				user << "<span class='warning'>It looks slightly damaged.</span>"
			else if (dam <= 0.6)
				user << "<span class='warning'>It looks moderately damaged.</span>"
			else
				user << "<span class='danger'>It looks heavily damaged.</span>"
//Damage

/turf/wall/proc/take_damage(dam)
	if (dam)
		damage = max(0, damage + dam)
		update_damage()
	return

/turf/wall/proc/update_damage()

	var/cap = material ? material.integrity : 150

	if (damage >= cap)
		dismantle_wall()
	else
		update_icon()

	return

/turf/wall/fire_act(temperature)
	burn(temperature)
/turf/wall/proc/dismantle_wall(var/devastated, var/explode, var/no_product)

	for (var/obj/O in contents) //Eject contents!
		O.loc = src

	material = get_material_by_name("placeholder")
	//update_connections(1)
	update_icon()
	ChangeTurf(get_base_turf_by_area(src))

/turf/wall/ex_act(severity)
	switch(severity)
		if (1.0, 2.0)
			if (!material || material.integrity < 400)
				ChangeTurf(get_base_turf_by_area(src))
			else
				dismantle_wall(1,1)
		if (3.0)
			take_damage(rand(50, 100))

/turf/wall/proc/burn(temperature)
	if (material.combustion_effect(src, temperature, 0.7))
		spawn(2)
			ChangeTurf(get_base_turf_by_area(src))
			for (var/turf/wall/W in range(3,src))
				W.burn((temperature/4))