// chat for all staff - Kachnov
/client/proc/cmd_staff_say(msg as text)
	set category = "Special"
	set name = "Asay"
	set hidden = TRUE
	if (!check_rights(R_MENTOR|R_MOD))
		return

	msg = sanitize(msg)
	if (!msg)
		return

	log_admin("ASAY: [key_name(src)] : [msg]")

	if (check_rights(R_MENTOR|R_MOD,0))
		for (var/client/C in admins)
			if (R_MENTOR & C.holder.rights || R_MOD & C.holder.rights)
				C << "<span class='admin_channel'>" + create_text_tag("admin", "ADMIN:", C) + " <span class='name'>[key_name(usr, TRUE)]</span>([admin_jump_link(mob, src)]): <span class='message'>[msg]</span></span>"

/*
/client/proc/cmd_admin_say(msg as text)
	set category = "Special"
	set name = "Asay" //Gave this shit a shorter name so you only have to time out "asay" rather than "admin say" to use it --NeoFite
	set hidden = TRUE
	if (!check_rights(R_MOD))	return // this was R_ADMIN, but mods and devs should have ASAY too - Kachnov

	msg = sanitize(msg)
	if (!msg)	return

	log_admin("ADMIN: [key_name(src)] : [msg]")

	if (check_rights(R_MOD,0))
		for (var/client/C in admins)
			if (R_MOD & C.holder.rights)
				C << "<span class='admin_channel'>" + create_text_tag("admin", "ADMIN:", C) + " <span class='name'>[key_name(usr, TRUE)]</span>([admin_jump_link(mob, src)]): <span class='message'>[msg]</span></span>"

/client/proc/cmd_mod_say(msg as text)
	set category = "Special"
	set name = "Msay"
	set hidden = TRUE

	if (!check_rights(R_ADMIN|R_MOD|R_MENTOR))	return

	msg = sanitize(msg)
	log_admin("MOD: [key_name(src)] : [msg]")

	if (!msg)
		return

	var/sender_name = key_name(usr, TRUE)
	if (check_rights(R_ADMIN, FALSE))
		sender_name = "<span class='admin'>[sender_name]</span>"
	for (var/client/C in admins)
		C << "<span class='mod_channel'>" + create_text_tag("mod", "MOD:", C) + " <span class='name'>[sender_name]</span>([admin_jump_link(mob, C.holder)]): <span class='message'>[msg]</span></span>"
*/

