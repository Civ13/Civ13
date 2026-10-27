/client/proc/reset_custom_roundstart_tip()
	set name = "Reset Custom Roundstart Tip"
	set category = "Fun"

	if (!check_rights(R_FUN))	return

	ticker.tip = null

	var/M = "[key_name(src)] reset the roundstart tip to random."
	message_admins(M)
	log_admin(M)
