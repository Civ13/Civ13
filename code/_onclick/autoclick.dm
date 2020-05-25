/client/var/selected_target[2]

/client/MouseDown(object, location, control, params)
	if (object == mob)
		return ..(object, location, control, params)
	var/delay = mob.CanMobAutoclick(object, location, params)
	if (delay)
		selected_target[1] = object
		selected_target[2] = params
		while (selected_target[1] && mob && !mob.lying && mob.stat == CONSCIOUS)
			var/foundMG = FALSE
			for (var/obj/item/weapon/gun/projectile/automatic/stationary/MG in get_turf(src))
				var/can_fire = TRUE
				var/atom/A = object
				switch (MG.dir)
					if (EAST)
						if (A.x > MG.x)
							can_fire = TRUE
						else
							can_fire = FALSE
					if (WEST)
						if (A.x < MG.x)
							can_fire = TRUE
						else
							can_fire = FALSE
					if (NORTH)
						if (A.y > MG.y)
							can_fire = TRUE
						else
							can_fire = FALSE
					if (SOUTH)
						if (A.y < MG.y)
							can_fire = TRUE
						else
							can_fire = FALSE
				if (!can_fire)
					continue
				if (MG.last_user == src)
					Click(selected_target[1], location, control, selected_target[2])

				foundMG = TRUE
			if (!foundMG)
				var/obj/item/weapon/gun/G = mob.get_active_hand()
				if (G && istype(G))
					G.next_fire_time = 0 // no 'you can't fire' spam
					Click(selected_target[1], location, control, selected_target[2])
			sleep(0.01)
	else
		return ..(object, location, control, params)

/client/MouseUp(object, location, control, params)
	selected_target[1] = null

/client/MouseDrag(src_object,atom/over_object,src_location,over_location,src_control,over_control,params)
	if (selected_target[1] && over_object && over_object.IsAutoclickable())
		selected_target[1] = over_object
		selected_target[2] = params

/mob/proc/CanMobAutoclick(object, location, params)
	return

/mob/living/human/CanMobAutoclick(atom/object, location, params)
	if (object)
		if (!object.IsAutoclickable())
			return
	var/obj/item/H = get_active_hand()
	if (H)
		return H.CanItemAutoclick(object, location, params)
	else if (!H)
		for (var/obj/item/weapon/gun/projectile/automatic/stationary/MG in get_turf(src))
			if (MG.last_user == src)
				return TRUE

/obj/item/proc/CanItemAutoclick(object, location, params)
	if (istype(src, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/CG = src
		if (CG.full_auto)
			var/datum/firemode/F = CG.firemodes[CG.sel_mode]
			return F.burst_delay
		else
			return FALSE
	else
		return FALSE

/atom/proc/IsAutoclickable()
	return TRUE

/obj/screen/IsAutoclickable()
	return FALSE

/obj/screen/click_catcher/IsAutoclickable()
	return TRUE