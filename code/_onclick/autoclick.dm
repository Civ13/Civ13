/client/MouseDown(object, location, control, params)
	if (object == mob)
		return ..(object, location, control, params)
	var/delay = mob.CanMobAutoclick(object, location, params)
	if (delay)
		selected_target[1] = object
		selected_target[2] = params
		while (selected_target[1] && mob && !mob.lying && mob.stat == CONSCIOUS)
			if (mob.using_MG)
				var/can_fire = TRUE
				var/atom/A = object
				switch (mob.using_MG.dir)
					if (EAST)
						if (A.x > mob.using_MG.x)
							can_fire = TRUE
						else
							can_fire = FALSE
					if (WEST)
						if (A.x < mob.using_MG.x)
							can_fire = TRUE
						else
							can_fire = FALSE
					if (NORTH)
						if (A.y > mob.using_MG.y)
							can_fire = TRUE
						else
							can_fire = FALSE
					if (SOUTH)
						if (A.y < mob.using_MG.y)
							can_fire = TRUE
						else
							can_fire = FALSE
				if (can_fire && mob.using_MG.last_user == src)
					mob.using_MG.next_fire_time = 0 // no 'you can't fire' spam
					Click(selected_target[1], location, control, selected_target[2])
			else
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
	if (using_MG)
		if (using_MG.last_user == src)
			return using_MG.CanItemAutoclick(object, location, params)
	else
		var/obj/item/H = get_active_hand()
		if (H)
			return H.CanItemAutoclick(object, location, params)

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