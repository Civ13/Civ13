/client/proc/see_who_is_in_tank()
	set category = "Ghost"
	set name = "Check Tank Users"

	if (!check_rights(R_MOD))
		return

	if (!locate(/obj/tank) in range(3, src))
		return

	var/obj/tank/tank = locate(/obj/tank) in range(3, src)

	if (!tank)
		return

	if (tank.drive_front_seat)
		var/mob/living/carbon/human/H = tank.drive_front_seat
		src << "<span class = 'warning'>FRONT SEAT:</span> [H.real_name] ([H.stat == DEAD ? "DEAD" : H.stat == UNCONSCIOUS ? "UNCONSCIOUS" : "ALIVE"]) ([H.original_job ? H.original_job.base_type_flag() : ""])[H.is_spy ? " (SPY) " : ""][H.is_jew ? " (JEW) " : ""]"
		src << "<br>"
	else
		src << "<span class = 'warning'>FRONT SEAT: EMPTY</span>"
		src << "<br>"

	if (tank.fire_back_seat)
		var/mob/living/carbon/human/H = tank.fire_back_seat
		src << "<span class = 'warning'>BACK SEAT:</span> [H.real_name] ([H.stat == DEAD ? "DEAD" : H.stat == UNCONSCIOUS ? "UNCONSCIOUS" : "ALIVE"]) ([H.original_job ? H.original_job.base_type_flag() : ""])[H.is_spy ? " (SPY) " : ""][H.is_jew ? " (JEW) " : ""]"
		src << "<br>"
	else
		src << "<span class = 'warning'>BACK SEAT: EMPTY</span>"
		src << "<br>"

/client/proc/eject_from_tank()
	set category = "Ghost"
	set name = "Eject People From Tank"

	if (!check_rights(R_MOD))
		return

	if (!locate(/obj/tank) in range(3, src))
		return

	var/obj/tank/tank = locate(/obj/tank) in range(3, src)
	if (!tank)
		return

	tank.forcibly_eject_everyone()

	log_admin("[key_name(usr)] tried to eject everyone from [tank]")
	message_admins("[key_name_admin(usr)] tried to eject everyone from [tank]", TRUE)