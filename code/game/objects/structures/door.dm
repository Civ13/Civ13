/obj/structure/simple_door
	name = "door"
	density = TRUE
	anchored = TRUE
	var/custom = FALSE //for customized locks in RP
	var/custom_code = 0 //for customized locks in RP
	var/locked = FALSE //for customized locks in RP

	var/override_material = FALSE
	var/override_opacity = FALSE

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

	//KEYPAD AND LOCKS
	var/locktype = "NONE" //NONE, KEYPAD, DNA, and LOCK.
	var/haslock = FALSE
	var/lockicon = "" //File
	var/lockstate = "" //Icon_state
	var/keycode

	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;keycode;haslock;custom;custom_code;locked"

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
	opacity = TRUE
	update_material(material_name)
	door_list += src
	if (material)
		if (get_material_name() == "wood" || "bamboo")
			flammable = TRUE
	for(var/obj/roof/R in range(1,src))
		R.update_transparency(0)

/obj/structure/simple_door/Destroy()
	door_list -= src
	..()
	spawn(1)
		for(var/obj/roof/R in loc)
			R.collapse_check()
		for(var/obj/roof/R in range(1,src))
			R.update_transparency(0)
/obj/structure/simple_door/proc/update_material(var/material_name)
	if (!material_name)
		material_name = DEFAULT_WALL_MATERIAL
	material = get_material_by_name(material_name)
	if (!material)
		qdel(src)
		return
	hardness = max(1,round(material.integrity/10))
	if (override_material)
		basic_icon = icon_state
	else
		icon_state = material.door_icon_base
		basic_icon = material.door_icon_base
		name = "[material.display_name] door"
		color = material.icon_colour
	if (material.opacity < 0.5)
		opacity = FALSE
	else
		opacity = TRUE

/obj/structure/simple_door/Destroy()
	processing_objects -= src
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
			if (ishuman(M))
				var/mob/living/human/C = M
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
	if(haslock)
		//NO AUDIO, HANDLED IN ATTACKBY
	else if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
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
		for (var/atom/movable/lighting_overlay/L in view(7*3, src))
			L.update_overlay()
		for(var/obj/roof/R in range(1,src))
			R.update_transparency(1)

/obj/structure/simple_door/proc/Close()
	isSwitchingStates = TRUE
	if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
		playsound(loc, 'sound/machines/shoji_door_close.ogg', 100, TRUE)
	else
		playsound(loc, 'sound/machines/door_close.ogg', 100, TRUE)
	flick("[basic_icon]closing",src)
	spawn (10)
		density = TRUE
		if(override_opacity)
			opacity = FALSE
		else
			opacity = TRUE
		state = FALSE
		update_icon()
		isSwitchingStates = FALSE
		for (var/atom/movable/lighting_overlay/L in view(7*3, src))
			L.update_overlay()
		for(var/obj/roof/R in range(1,src))
			R.update_transparency(0)
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
	//KEYPAD AND LOCKSAASDASD
	if (istype(W,/obj/item/weapon/keypad))
		if(haslock)
			user << "This door already has a lock!"
		else
			user << "You attach the " + W.name + " to the door!"
			src.name = name + "("+W.name+")"
			//LATER WE WILL ADD A SWITCH TO CHECK FOR EACH LOCKTYPE APPROPRIATELY
			src.locktype = "KEYPAD"
			src.lockicon = "icons/obj/doors/locks.dmi"
			src.lockstate = "keypad_door_overlay"
			var/input_code = input(user, "Input a code, only the first four characters will be used.","Keypad Code", keycode) as text
			keycode = sanitizeName(input_code, 4, TRUE)
			user << "<span class='notice'> Code set to: " + keycode + "!</span>"
			update_lock_overlay()
			playsound(src, 'sound/machines/click.ogg', 60)
	//If the door has a lock.
	else if (haslock)
		if(locktype == "KEYPAD")
			if(state) //If it is open, close it, lock it, and overlay
				Close()
				locked = 1
				update_lock_overlay()
				playsound(src, 'sound/effects/insert.ogg', 30)
			else //It is closed
				var/input_query = input(user, "Input the Passcode.","Keypad Code", keycode) as text//Get input
				var/answer = sanitizeName(input_query, 4, TRUE)
				if(answer == keycode)//if it matches, unlock, open, and overlay
					locked = 0
					Open()
					update_lock_overlay()
					playsound(src, 'sound/machines/ping.ogg', 60)
				else
					playsound(src, 'sound/machines/geiger/ext1.ogg', 60)//temp error noise


	else if (istype(W,/obj/item/weapon)) //not sure, can't not just weapons get passed to this proc?
		hardness -= W.force/100
		user << "You hit the [name] with your [W.name]!"
		CheckHardness()
	else
		attack_hand(user)
	return TRUE // for key_doors
	..()
//MOAR KEYPAD
/obj/structure/simple_door/proc/update_lock_overlay()
	if(haslock)
		if (state) //if open
			src.overlays = null
		else //if closed
			src.overlays += icon(lockicon,lockstate)

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

/obj/structure/simple_door/key_door/custom/jail/
	var/buildstackamount = 0//How much mats it takes to make it.
	var/buildstack = /obj/item/stack/rods //the item it is made with.
	override_opacity = TRUE
	opacity = FALSE
	breachable = FALSE

/obj/structure/simple_door/key_door/custom/jail/woodjail/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/key))
		if (W.code == custom_code)
			locked = !locked
			if (locked == 1)
				visible_message("<span class = 'notice'>[user] locks the door.</span>")
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
			else if (locked == 0)
				visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
		if (W.code != custom_code)
			user << "This key does not match this lock!"
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		for (var/obj/item/weapon/key/KK in W.contents)
			if (KK.code == custom_code)
				locked = !locked
				if (locked == 1)
					visible_message("<span class = 'notice'>[user] locks the door.</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
				else if (locked == 0)
					visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
		if (W.code != custom_code)
			user << "None of the keys match this lock!"
	else if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You pound the bars uselessly!"//sucker
	else if (istype(W,/obj/item/weapon/wrench) || istype(W,/obj/item/weapon/hammer))//if it is a wrench
		if (state == 0)
			user << "You need to open the door first."
		else
			user << "<span class='notice'>You start disassembling the [src]...</span>"
			playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
			if (do_after(user, 30, target = src))
				for (var/i = TRUE, i <= buildstackamount, i++)
					new buildstack(get_turf(src))
				qdel(src)
				return
	else if (istype(W, /obj/item/weapon/lockpick))
		if (src.locked == 1)
			var/mob/living/human/H = user
			visible_message("<span class = 'danger'>[user] starts picking the [src.name]'s lock with the [W]!</span>")
			if (H.getStatCoeff("dexterity") < 1.7)
				user << "You don't have the skills to use this."
				return
			else
				if (do_after(user, 35*H.getStatCoeff("dexterity"), src))
					if(prob(H.getStatCoeff("dexterity")*35))
						user << "<span class='notice'>You pick the lock.</span>"
						src.locked = 0
						return
					else if (prob(60))
						qdel(W)
						user << "<span class='warning'>Your lockpick broke!</span>"
						return
					else
						user << "<span class='warning'>You failed to pick the lock!</span>"
						return
				return
	else
		attack_hand(user)//keys!
	return TRUE // for key_doors

/obj/structure/simple_door/key_door/custom/jail/steeljail/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/key))
		if (W.code == custom_code)
			locked = !locked
			if (locked == 1)
				visible_message("<span class = 'notice'>[user] locks the door.</span>")
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
			else if (locked == 0)
				visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
		if (W.code != custom_code)
			user << "This key does not match this lock!"
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		for (var/obj/item/weapon/key/KK in W.contents)
			if (KK.code == custom_code)
				locked = !locked
				if (locked == 1)
					visible_message("<span class = 'notice'>[user] locks the door.</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
				else if (locked == 0)
					visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
		if (W.code != custom_code)
			user << "None of the keys match this lock!"
	else if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/weldingtool)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You pound the bars uselessly!"//sucker
	else if (istype(W,/obj/item/weapon/weldingtool))//if it is a welding tool
		if (state == 0)
			user << "You need to open the door first."
		else
			user << "<span class='notice'>You start disassembling the [src]...</span>"
			playsound(loc, 'sound/effects/extinguish.ogg', 50, TRUE)
			if (do_after(user, 30, target = src))
				for (var/i = TRUE, i <= buildstackamount, i++)
					new buildstack(get_turf(src))
				qdel(src)
				return
	else if (istype(W, /obj/item/weapon/lockpick))
		if (src.locked == 1)
			var/mob/living/human/H = user
			visible_message("<span class = 'danger'>[user] starts picking the [src.name]'s lock with the [W]!</span>")
			if (H.getStatCoeff("dexterity") < 1.7)
				user << "You don't have the skills to use this."
				return
			else
				if (do_after(user, 35*H.getStatCoeff("dexterity"), src))
					if(prob(H.getStatCoeff("dexterity")*35))
						user << "<span class='notice'>You pick the lock.</span>"
						src.locked = 0
						return
					else if (prob(60))
						qdel(W)
						user << "<span class='warning'>Your lockpick broke!</span>"
						return
					else
						user << "<span class='warning'>You failed to pick the lock!</span>"
						return
				return
	else
		attack_hand(user)//keys!
	return TRUE // for key_doors

/obj/structure/simple_door/key_door/custom/jail/bullet_act(var/obj/item/projectile/P)
	return PROJECTILE_CONTINUE

/obj/structure/simple_door/iron/New(var/newloc,var/material_name)
	..(newloc, "iron")
	basic_icon = "cell"
	name = "Cell"

/obj/structure/simple_door/fence
	basic_icon = "fence"
	icon_state = "fence"
/obj/structure/simple_door/fence/New(var/newloc,var/material_name)
	..(newloc, "wood")
	basic_icon = "fence"
	icon_state = "fence"
	name = "fence gate"
	override_opacity = TRUE
	opacity = FALSE

/obj/structure/simple_door/fence/picket
	basic_icon = "picketfence"
	icon_state = "picketfence"
/obj/structure/simple_door/fence/picket/New(var/newloc,var/material_name)
	..(newloc, "wood")
	basic_icon = "picketfence"
	icon_state = "picketfence"
	name = "picket fence gate"

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

/obj/structure/simple_door/wood2
	icon = 'icons/obj/doors/material_doors_leonister.dmi'
	basic_icon = "wood2"
	icon_state = "wood2"
/obj/structure/simple_door/wood2/New(var/newloc,var/material_name)
	..(newloc, "wood")
	icon = 'icons/obj/doors/material_doors_leonister.dmi'
	basic_icon = "wood2"
	icon_state = "wood2"
	name = "Windowed"
	opacity = 0
	override_opacity = 1

///obj/structure/simple_door/resin/New(var/newloc,var/material_name)
//	..(newloc, "resin")
//resin is not an extant material, this is a broken door - siro

/obj/structure/simple_door/key_door/custom/jail/woodjail
	basic_icon = "woodcell"
	icon_state = "woodcell"
/obj/structure/simple_door/key_door/custom/jail/woodjail/New(var/newloc,var/material_name)
	..(newloc, "wood")
	basic_icon = "woodcell"
	icon_state = "woodcell"

/obj/structure/simple_door/key_door/custom/jail/woodjail/abashiri
	icon = 'icons/obj/doors/material_doors_leonister.dmi'
	basic_icon = "abashiricell"
	icon_state = "abashiricell"
/obj/structure/simple_door/key_door/custom/jail/woodjail/abashiri/New(var/newloc,var/material_name)
	..(newloc, "wood")
	icon = 'icons/obj/doors/material_doors_leonister.dmi'
	basic_icon = "abashiricell"
	icon_state = "abashiricell"

/obj/structure/simple_door/key_door/custom/jail/steeljail
	basic_icon = "cell"
	icon_state = "cell"
/obj/structure/simple_door/key_door/custom/jail/steeljail/New(var/newloc,var/material_name)
	..(newloc, "steel")
	basic_icon = "cell"
	icon_state = "cell"
