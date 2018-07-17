/client/var/pingability = TRUE
/client/proc/toggle_pingability()
	set category = "Admin"
	set name = "Toggle Pingability"
	if (!check_rights(R_HOST))
		return
	pingability = !pingability
	if (pingability)
		src << "<span class = 'good'>You can now be pinged in OOC.</span>"
	else
		src << "<span class = 'notice'>You can no longer be pinged in OOC.</span>"