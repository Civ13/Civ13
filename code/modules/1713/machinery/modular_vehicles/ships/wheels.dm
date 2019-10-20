/obj/item/vehicleparts/wheel/ship
	icon_state = "rudder"
	name = "boat rudder and sail control"
	desc = "Used to steer a boat and control the sails."
	var/spamtimer = 0
	var/obj/structure/vehicleparts/axis/axis_control = null
	secondary_action = TRUE

/obj/item/vehicleparts/wheel/ship/attack_self(mob/living/carbon/human/H)
	if (!axis_control)
		var/found = FALSE
		for (var/obj/structure/vehicleparts/frame/ship/S in H.loc)
			if (S.axis && S.axis.masts)
				found = TRUE
				axis_control = S.axis
		if (!found || !axis_control || !(axis_control.loc in range(5,H)))
			axis_control = null
			return
	for (var/obj/structure/vehicleparts/movement/sails/M in axis_control.masts)
		if (world.time > spamtimer)
			if (!M.sails_on)
				H << "You hoist the sails."
				M.sails_on = TRUE
				spamtimer = world.time + 20
				return
			else
				H << "You retract the sails."
				M.sails_on = FALSE
				return

/obj/item/vehicleparts/wheel/ship/secondary_attack_self(mob/living/carbon/human/user)
	if (!axis_control)
		var/found = FALSE
		for (var/obj/structure/vehicleparts/frame/ship/S in user.loc)
			if (S.axis && S.axis.masts)
				found = TRUE
				axis_control = S.axis
		if (!found || !axis_control || !(axis_control.loc in range(5,user)))
			axis_control = null
			return

	if (world.time > spamtimer)
		if (axis_control)
			if (axis_control.anchor)
				axis_control.anchor = FALSE
				user << "You lift the anchor."
				axis_control.moving = TRUE
				axis_control.add_transporting()
				axis_control.startmovementloop()
				return
			else
				axis_control.anchor = TRUE
				axis_control.moving = FALSE
				axis_control.stopmovementloop()
				user << "You drop the anchor."
				return