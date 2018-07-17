/obj/structure/simple_door
	name = "door"
	density = TRUE
	anchored = TRUE

	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "metal"

	var/material/material
	var/state = FALSE //closed, TRUE == open
	var/isSwitchingStates = FALSE
	var/hardness = TRUE
	var/oreAmount = 7

	var/override_material_state = null

	var/health = 100
	var/initial_health = 100

/obj/structure/simple_door/fire_act(temperature)
	var/dmg = round((temperature - 365)/20)
	if (temperature >= 380)
		dmg = max(dmg, 5)
	if (dmg > 0)
		health -= dmg
		if (istype(src, /obj/structure/simple_door/key_door))
			src:damage_display()
		if (health <= 0)
			qdel(src)

/obj/structure/simple_door/bullet_act(var/obj/item/projectile/P)
	var/damage = max(P.damage/2, 2)
	health -= damage
	visible_message("<span class = 'danger'>[src] is hit by the [P.name]!</span>")
	if (istype(src, /obj/structure/simple_door/key_door))
		src:damage_display()
	if (health <= 0)
		qdel(src)

/obj/structure/simple_door/proc/TemperatureAct(temperature)
	hardness -= material.combustion_effect(get_turf(src),temperature, 0.3)
	CheckHardness()

/obj/structure/simple_door/New(var/newloc, var/material_name)
	..()
	update_material(material_name)
	door_list += src

/obj/structure/simple_door/Destroy()
	door_list -= src
	..()

/obj/structure/simple_door/proc/update_material(var/material_name)
	if (!material_name)
		material_name = DEFAULT_WALL_MATERIAL
	material = get_material_by_name(material_name)
	if (!material)
		qdel(src)
		return
	hardness = max(1,round(material.integrity/10))
	icon_state = material.door_icon_base
	name = "[material.display_name] door"
	color = material.icon_colour
	if (material.opacity < 0.5)
		opacity = FALSE
	else
		opacity = TRUE
	if (material.products_need_process())
		processing_objects |= src
	update_nearby_tiles(need_rebuild=1)

/obj/structure/simple_door/Destroy()
	processing_objects -= src
	update_nearby_tiles()
	..()

/obj/structure/simple_door/get_material()
	return material

/obj/structure/simple_door/Bumped(atom/user)
	..()
	if (!state)
		return TryToSwitchState(user)
	return

/obj/structure/simple_door/attack_hand(mob/user as mob)
	return TryToSwitchState(user)

/obj/structure/simple_door/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group) return FALSE
	if (istype(mover, /obj/effect/beam))
		return !opacity
	return !density

/obj/structure/simple_door/proc/TryToSwitchState(atom/user)
	if (isSwitchingStates) return FALSE
	if (ismob(user) && canOpen(user))
		var/mob/M = user
		if (!material.can_open_material_door(user))
			return FALSE
		if (world.time - user.last_bumped <= 60)
			return FALSE
		if (M.client)
			if (iscarbon(M))
				var/mob/living/carbon/C = M
				if (!C.handcuffed)
					SwitchState()
			else
				SwitchState()
	return TRUE


/obj/structure/simple_door/proc/SwitchState()
	if (state)
		Close()
	else
		Open()


/obj/structure/simple_door/proc/canOpen(var/mob/user as mob)
	if (!user || !istype(user))
		return FALSE
	else
		return TRUE


/obj/structure/simple_door/proc/Open()
	isSwitchingStates = TRUE
	playsound(loc, material.dooropen_noise, 100, TRUE)
	flick("[material.door_icon_base]opening",src)
	spawn (10)
		density = FALSE
		opacity = FALSE
		state = TRUE
		update_icon()
		isSwitchingStates = FALSE
		update_nearby_tiles()
		for (var/atom/movable/lighting_overlay/L in view(world.view*3, src))
			L.update_overlay(TRUE)

/obj/structure/simple_door/proc/Close()
	isSwitchingStates = TRUE
	playsound(loc, material.dooropen_noise, 100, TRUE)
	flick("[material.door_icon_base]closing",src)
	spawn (10)
		density = TRUE
		opacity = TRUE
		state = FALSE
		update_icon()
		isSwitchingStates = FALSE
		update_nearby_tiles()
		for (var/atom/movable/lighting_overlay/L in view(world.view*3, src))
			L.update_overlay(TRUE)

/obj/structure/simple_door/Destroy()
	for (var/atom/movable/lighting_overlay/L in view(world.view*3, src))
		L.update_overlay(TRUE)
	..()

/obj/structure/simple_door/update_icon()
	if (state)
		icon_state = "[material.door_icon_base]open"
	else
		icon_state = material.door_icon_base

/obj/structure/simple_door/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon)) //not sure, can't not just weapons get passed to this proc?
		hardness -= W.force/100
		user << "You hit the [name] with your [W.name]!"
		CheckHardness()
	else if (istype(W,/obj/item/weapon/weldingtool))
		var/obj/item/weapon/weldingtool/WT = W
		if (material.ignition_point && WT.remove_fuel(0, user))
			TemperatureAct(150)
	else
		attack_hand(user)
	return TRUE // for key_doors

/obj/structure/simple_door/proc/CheckHardness()
	if (hardness <= 0)
		Dismantle(1)

/obj/structure/simple_door/proc/Dismantle(devastated = FALSE)
	material.place_dismantled_product(get_turf(src))
	qdel(src)

/obj/structure/simple_door/ex_act(severity = TRUE)
	switch(severity)
		if (1)
			Dismantle(1)
		if (2)
			if (prob(20))
				Dismantle(1)
			else
				hardness--
				CheckHardness()
		if (3)
			hardness -= 0.1
			CheckHardness()
	return

/obj/structure/simple_door/process()
	if (!material.radioactivity)
		return
	for (var/mob/living/L in range(1,src))
		L.apply_effect(round(material.radioactivity/3),IRRADIATE,0)

/obj/structure/simple_door/iron/New(var/newloc,var/material_name)
	..(newloc, "iron")

/obj/structure/simple_door/silver/New(var/newloc,var/material_name)
	..(newloc, "silver")

/obj/structure/simple_door/gold/New(var/newloc,var/material_name)
	..(newloc, "gold")

/obj/structure/simple_door/uranium/New(var/newloc,var/material_name)
	..(newloc, "uranium")

/obj/structure/simple_door/sandstone/New(var/newloc,var/material_name)
	..(newloc, "sandstone")

/obj/structure/simple_door/plasma/New(var/newloc,var/material_name)
	..(newloc, "plasma")

/obj/structure/simple_door/diamond/New(var/newloc,var/material_name)
	..(newloc, "diamond")

/obj/structure/simple_door/wood/New(var/newloc,var/material_name)
	..(newloc, "wood")

/obj/structure/simple_door/resin/New(var/newloc,var/material_name)
	..(newloc, "resin")