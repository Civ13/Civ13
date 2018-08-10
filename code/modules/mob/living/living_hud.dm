/mob/proc/create_HUD()
	return

/mob/living/proc/destroy_HUD()
	var/mob/living/H = src
	client.screen.Cut()
	H.HUDprocess.Cut()
	for (var/i=1,i<=H.HUDneed.len,i++)
		var/p = H.HUDneed[i]
		qdel(H.HUDneed[p])
	for (var/HUDelement in H.HUDinventory)
		qdel(HUDelement)
	for (var/HUDelement in H.HUDfrippery)
		qdel(HUDelement)
	for (var/i=1,i<=H.HUDtech.len,i++)
		var/p = H.HUDtech[i]
		qdel(H.HUDtech[p])
	H.HUDtech.Cut()
	H.HUDneed.Cut()
	H.HUDinventory.Cut()
	H.HUDfrippery.Cut()

/mob/living/proc/show_HUD()
	if (client)
		client.screen.Cut()
		for (var/i=1,i<=HUDneed.len,i++)
			var/p = HUDneed[i]
			client.screen += HUDneed[p]
		for (var/obj/screen/HUDinv in HUDinventory)
			client.screen += HUDinv
		for (var/obj/screen/frippery/HUDfri in HUDfrippery)
			client.screen += HUDfri
		for (var/i=1,i<=HUDtech.len,i++)
			var/p = HUDtech[i]
			client.screen += HUDtech[p]
		if(src.hud_used)
			for(var/thing in hud_used.plane_masters)
				var/obj/screen/plane_master/PM = hud_used.plane_masters[thing]
				PM.backdrop(src)
				src.client.screen += PM
//For HUD checking needs

/mob/living/proc/recolor_HUD(var/_color, var/_alpha)
	for (var/i=1,i<=HUDneed.len,i++)
		var/p = HUDneed[i]
		var/obj/screen/HUDelm = HUDneed[p]
		HUDelm.color = _color
		HUDelm.alpha = _alpha
	for (var/obj/screen/HUDinv in HUDinventory)
		HUDinv.color = _color
		HUDinv.alpha = _alpha
	return

/mob/living/proc/check_HUD()//Main HUD check process
	return

/mob/living/proc/check_HUDdatum()//correct a datum?
	return
/mob/living/proc/check_HUDinventory()//correct a HUDinventory?
	return
/mob/living/proc/check_HUDneed()
	return
/mob/living/proc/check_HUDfrippery()
	return
/mob/living/proc/check_HUDprocess()
	return
/mob/living/proc/check_HUDtech()
	return
/mob/living/proc/check_HUD_style()
	return


/mob/living/proc/create_HUDinventory()//correct a HUDinventory?
	return
/mob/living/proc/create_HUDneed()
	return
/mob/living/proc/create_HUDfrippery()
	return
///mob/living/proc/create_HUDprocess()
//	return
/mob/living/proc/create_HUDtech()
	return

