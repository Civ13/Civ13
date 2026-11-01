/mob/proc/create_HUD()
	return

/mob/living/proc/destroy_HUD()
	var/mob/living/H = src
	// Other owners keep their renderer, vehicle, spell and transient screens.
	for (var/p in H.HUDneed)
		H.remove_HUD_element(H.HUDneed[p])
	for (var/HUDelement in H.HUDinventory)
		H.remove_HUD_element(HUDelement)
	for (var/HUDelement in H.HUDfrippery)
		H.remove_HUD_element(HUDelement)
	for (var/p in H.HUDtech)
		H.remove_HUD_element(H.HUDtech[p])
	H.HUDtech.Cut()
	H.HUDneed.Cut()
	H.HUDinventory.Cut()
	H.HUDfrippery.Cut()

/mob/living/proc/remove_HUD_element(obj/screen/HUDelement)
	if (!HUDelement)
		return
	if (client)
		client.screen -= HUDelement
	HUDprocess -= HUDelement
	qdel(HUDelement)

/mob/living/proc/show_HUD()
	if (client)
		// Reattach owned members without withdrawing another owner's screens.
		for (var/p in HUDneed)
			client.screen |= HUDneed[p]
		for (var/obj/screen/HUDinv in HUDinventory)
			client.screen |= HUDinv
		for (var/obj/screen/frippery/HUDfri in HUDfrippery)
			client.screen |= HUDfri
		for (var/p in HUDtech)
			client.screen |= HUDtech[p]
		if(src.hud_used)
			for(var/thing in hud_used.plane_masters)
				var/obj/screen/plane_master/PM = hud_used.plane_masters[thing]
				// The constructor and sight updates own backdrop policy. In
				// particular, the root scene leases the raw game plane's filters.
				src.client.screen |= PM
			client.screen |= hud_used.vehicle_hud
			client.screen |= hud_used.wizard_hud
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

