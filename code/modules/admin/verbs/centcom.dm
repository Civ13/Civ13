/client/proc/CentCom(ckey)
	if (!check_rights(R_ADMIN | R_MOD))	return

	if (!ckey || !istext(ckey))	return

	message_admins("[key_name_admin(src)] has checked [ckey]'s bans on the CentCom DB.", key_name_admin(src))
	var/centcom = "<!DOCTYPE html><HTML><HEAD><TITLE>CentCom Database</TITLE><META http-equiv=\"X-UA-Compatible\" content=\"IE=edge\"></HEAD> \
		<BODY><iframe src=\"https://centcom.melonmesa.com/viewer/view/[ckey]%3E\" style=\"position: absolute; height: 97%; width: 97%; border: none\"></iframe></BODY></HTML>"
	src << browse(centcom, "window=wiki;size=820x650")
