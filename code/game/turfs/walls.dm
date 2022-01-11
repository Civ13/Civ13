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