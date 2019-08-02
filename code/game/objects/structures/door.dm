/obj/structure/simple_door
	name = "door"
	density = TRUE
	anchored = TRUE
	var/custom = FALSE //for customized locks in RP
	var/custom_code = 0 //for customized locks in RP
	var/locked = FALSE //for customized locks in RP

	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "metal"

	var/material/material
	var/state = FALSE //closed, TRUE == open
	var/isSwitchingStates = FALSE
	var/hardness = TRUE
	var/oreAmount = 7
	var/basic_icon = "metal"

	var/override_material_state = null

	var/health = 400
	var/initial_health = 400
	not_movable = TRUE
	not_disassemblable = TRUE

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
	if (material)
		if (get_material_name() == "wood")
			flammable = TRUE
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
	basic_icon = material.door_icon_base
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
	return !density

/obj/structure/simple_door/proc/TryToSwitchState(atom/user)
	if (isSwitchingStates) return FALSE
	if (ismob(user) && canOpen(user))
		var/mob/M = user
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
	if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
		playsound(loc, 'sound/machines/shoji_door_open.ogg', 100, TRUE)
	else
		playsound(loc, 'sound/machines/door_open.ogg', 100, TRUE)
	flick("[basic_icon]opening",src)
	spawn (10)
		density = FALSE
		opacity = FALSE
		state = TRUE
		update_icon()
		isSwitchingStates = FALSE
		update_nearby_tiles()
		for (var/atom/movable/lighting_overlay/L in view(7*3, src))
			L.update_overlay()

/obj/structure/simple_door/proc/Close()
	isSwitchingStates = TRUE
	if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
		playsound(loc, 'sound/machines/shoji_door_close.ogg', 100, TRUE)
	else
		playsound(loc, 'sound/machines/door_close.ogg', 100, TRUE)
	flick("[basic_icon]closing",src)
	spawn (10)
		density = TRUE
		opacity = TRUE
		state = FALSE
		update_icon()
		isSwitchingStates = FALSE
		update_nearby_tiles()
		for (var/atom/movable/lighting_overlay/L in view(7*3, src))
			L.update_overlay()

/obj/structure/simple_door/Destroy()
	for (var/atom/movable/lighting_overlay/L in view(7*3, src))
		L.update_overlay()
	..()

/obj/structure/simple_door/update_icon()
	if (state)
		icon_state = "[basic_icon]open"
	else
		icon_state = basic_icon

/obj/structure/simple_door/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon)) //not sure, can't not just weapons get passed to this proc?
		hardness -= W.force/100
		user << "You hit the [name] with your [W.name]!"
		CheckHardness()
	else
		attack_hand(user)
	return TRUE // for key_doors

/obj/structure/simple_door/proc/CheckHardness()
	if (hardness <= 0)
		Dismantle(1)

/obj/structure/simple_door/proc/Dismantle(devastated = FALSE)
	if (istype(material))
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
	basic_icon = "cell"
	name = "Cell"
/obj/structure/simple_door/fence/New(var/newloc,var/material_name)
	..(newloc, "wood")
	basic_icon = "fence"
	icon_state = "fence"
	name = "Fence Door"
/obj/structure/simple_door/cell/New(var/newloc,var/material_name)
	..(newloc, "iron")
/obj/structure/simple_door/stone/New(var/newloc,var/material_name)
	..(newloc, "stone")

/obj/structure/simple_door/silver/New(var/newloc,var/material_name)
	..(newloc, "silver")

/obj/structure/simple_door/gold/New(var/newloc,var/material_name)
	..(newloc, "gold")

/obj/structure/simple_door/sandstone/New(var/newloc,var/material_name)
	..(newloc, "sandstone")

/obj/structure/simple_door/wood/New(var/newloc,var/material_name)
	..(newloc, "wood")

/obj/structure/simple_door/wood2/New(var/newloc,var/material_name)
	..(newloc, "wood")
	basic_icon = "wood2"
	name = "Windowed"
/obj/structure/simple_door/resin/New(var/newloc,var/material_name)
	..(newloc, "resin")
