/proc/fix_nanoUI(var/mob/user, var/mob/H)
	if (!istype(H) || !H.client)
		if (user) user << "This can only be done on mobs with clients"
		return

	nanomanager.close_uis(H)
	H.client.cache.Cut()
	var/datum/asset/assets = get_asset_datum(/datum/asset/nanoui)
	assets.send(H)

	if (user) user << "Resource files sent"
	H << "Your NanoUI Resource files have been refreshed"

	if (user) log_admin("[key_name(user)] resent the NanoUI resource files to [key_name(H)] ")
