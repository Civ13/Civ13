// toggle hub visibility
/client/proc/toggle_BYOND_hub_visibility()

	set name = "Toggle BYOND hub visibility"
	set category = "Server"

	if (!check_rights(R_HOST))
		return

	var/change = input(world.visibility ? "The server is currently VISIBLE on the hub. Set it to invisible?" : "The server is currently INVISIBLE on the hub. Set it to visible?") in list("Yes", "No")
	if (change == "Yes")
		world.visibility = !world.visibility
		var/M = "[key_name(src)] set the world's hub visibility to [world.visibility]."
		log_admin(M)
		message_admins(M)