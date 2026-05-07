/client/var/pingability = TRUE
/client/proc/toggle_pingability()
	set category = "Admin"
	set name = "Toggle Pingability"
	if (!check_rights(R_HOST))
		return
	pingability = !pingability
	if (pingability)
		to_chat(src, "<span class = 'good'>You can now be pinged in OOC.</span>")
	else
		to_chat(src, "<span class = 'notice'>You can no longer be pinged in OOC.</span>")