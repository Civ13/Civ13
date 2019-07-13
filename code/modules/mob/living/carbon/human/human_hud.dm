/mob/living/carbon/human/check_HUD()
	var/mob/living/carbon/human/H = src
	if (!H.client)
		return

//	var/datum/hud/human/HUDdatum = global.HUDdatums[H.defaultHUD]
	var/recreate_flag = FALSE

	if (!check_HUDdatum())
		log_debug("[H] trying to check a HUD, but HUDdatums does not have \"[H.client.prefs.UI_style]!\"")
		H << "Some problem has occured, use default HUD type."
		H.defaultHUD = "1713Style"
		++recreate_flag
	else if (H.client.prefs.UI_style != H.defaultHUD)
		H.defaultHUD = H.client.prefs.UI_style
		++recreate_flag

	if (recreate_flag)
		H.destroy_HUD()
		H.create_HUD()

	H.show_HUD()

	if (!recreate_flag && !check_HUD_style())
		H.recolor_HUD(H.client.prefs.UI_style_color, H.client.prefs.UI_style_alpha)

	return recreate_flag

/mob/living/carbon/human/check_HUD_style()
	var/mob/living/carbon/human/H = src


	for (var/obj/screen/inventory/HUDinv in H.HUDinventory)

		if (HUDinv.color != H.client.prefs.UI_style_color || HUDinv.alpha != H.client.prefs.UI_style_alpha)
			return FALSE

	for (var/p in HUDneed)
		var/obj/screen/HUDelm = HUDneed[p]
		if (HUDelm.color != H.client.prefs.UI_style_color || HUDelm.alpha != H.client.prefs.UI_style_alpha)
			return FALSE
	return TRUE

/mob/living/carbon/human/check_HUDdatum()//correct a datum?
	var/mob/living/carbon/human/H = src

	if (H.client.prefs.UI_style && !(H.client.prefs.UI_style == "")) //если у клиента моба прописан стиль\тип ХУДа
		if (global.HUDdatums.Find(H.client.prefs.UI_style))//Если существует такой тип ХУДА
			return TRUE

	return FALSE

/mob/living/carbon/human/update_hud()	//TODO: do away with this if possible
	if (client)
		if (client.prefs && client.prefs.cursor && client.prefs.cursor != client.mouse_pointer_icon)
			client.mouse_pointer_icon = client.prefs.cursor
		check_HUD()
		client.screen |= contents
		//if (hud_used)
			//hud_used.hidden_inventory_update() 	//Updates the screenloc of the items on the 'other' inventory bar







/mob/living/carbon/human/create_HUD()
//	var/mob/living/carbon/human/H = src
//	var/datum/hud/human/HUDdatum = global.HUDdatums[H.defaultHUD]

	create_HUDinventory()
	create_HUDneed()
	create_HUDfrippery()
	create_HUDtech()
	recolor_HUD(client.prefs.UI_style_color, client.prefs.UI_style_alpha)

/mob/living/carbon/human/create_HUDinventory()
	var/mob/living/carbon/human/H = src
	var/datum/hud/human/HUDdatum = global.HUDdatums[H.defaultHUD]

	for (var/gear_slot in species.hud.gear)
		if (!HUDdatum.slot_data.Find(gear_slot))
			log_debug("[usr] tring to make inventory data for [gear_slot], but HUDdatum does not have it!")
			src << "Sorry, but something went wrong while creating the inventory slots, we recomendend that you change the HUD type or contact the admins."
			return
		else
			var/HUDtype
			if (HUDdatum.slot_data[gear_slot]["type"])
				HUDtype = HUDdatum.slot_data[gear_slot]["type"]
			else
				HUDtype = /obj/screen/inventory

			var/obj/screen/inventory/inv_box = new HUDtype(HUDdatum.slot_data[gear_slot]["name"], HUDdatum.slot_data[gear_slot]["loc"], species.hud.gear[gear_slot], HUDdatum.icon, HUDdatum.slot_data[gear_slot]["state"], H)
			if (HUDdatum.slot_data[gear_slot]["dir"])
				inv_box.set_dir(HUDdatum.slot_data[gear_slot]["dir"])
			if (HUDdatum.slot_data[gear_slot]["hideflag"])
				inv_box.hideflag = HUDdatum.slot_data[gear_slot]["hideflag"]
			H.HUDinventory += inv_box
	return

/mob/living/carbon/human/create_HUDneed()
	var/mob/living/carbon/human/H = src
	var/datum/hud/human/HUDdatum = global.HUDdatums[H.defaultHUD]

	for (var/HUDname in species.hud.ProcessHUD) //Добавляем Элементы ХУДа (не инвентарь)
		if (!(HUDdatum.HUDneed.Find(HUDname))) //Ищем такой в датуме
		//	log_debug("[usr] try create a [HUDname], but it no have in HUDdatum [HUDdatum.name]")
		else
			var/HUDtype = HUDdatum.HUDneed[HUDname]["type"]
			var/obj/screen/HUD = new HUDtype(HUDname, HUDdatum.HUDneed[HUDname]["loc"], H, HUDdatum.HUDneed[HUDname]["icon"] ? HUDdatum.HUDneed[HUDname]["icon"] : HUDdatum.icon, HUDdatum.HUDneed[HUDname]["icon_state"] ? HUDdatum.HUDneed[HUDname]["icon_state"] : null)
/*			if (HUDdatum.HUDneed[HUDname]["icon"])//Анализ на овверайд icon
				HUD.icon = HUDdatum.HUDneed[HUDname]["icon"]
			else
				HUD.icon = HUDdatum.icon
			if (HUDdatum.HUDneed[HUDname]["icon_state"])//Анализ на овверайд icon_state
				HUD.icon_state = HUDdatum.HUDneed[HUDname]["icon_state"]*/
			if (HUDdatum.HUDneed[HUDname]["hideflag"])
				HUD.hideflag = HUDdatum.HUDneed[HUDname]["hideflag"]
			H.HUDneed[HUD.name] += HUD//Добавляем в список худов
			if (HUD.process_flag)//Если худ нужно процессить
				H.HUDprocess += HUD//Вливаем в соотвествующий список

	return
/mob/living/carbon/human/create_HUDfrippery()
	var/mob/living/carbon/human/H = src
	var/datum/hud/human/HUDdatum = global.HUDdatums[H.defaultHUD]

	//Добавляем Элементы ХУДа (украшения)
	for (var/list/whistle in HUDdatum.HUDfrippery)
		var/obj/screen/frippery/perdelka = new (whistle["icon_state"],whistle["loc"], whistle["dir"],H)
		perdelka.icon = HUDdatum.icon
		if (whistle["hideflag"])
			perdelka.hideflag = whistle["hideflag"]
		H.HUDfrippery += perdelka
	return

/mob/living/carbon/human/create_HUDtech()
	var/mob/living/carbon/human/H = src
	var/datum/hud/human/HUDdatum = global.HUDdatums[H.defaultHUD]

	for (var/techobject in HUDdatum.HUDoverlays)
		var/HUDtype = HUDdatum.HUDoverlays[techobject]["type"]
		var/obj/screen/HUD = new HUDtype(techobject, HUDdatum.HUDoverlays[techobject]["loc"], H)
		if (HUDdatum.HUDoverlays[techobject]["icon"])
			HUD.icon = HUDdatum.HUDoverlays[techobject]["icon"]
		else
			HUD.icon = HUDdatum.icon
		if (HUDdatum.HUDoverlays[techobject]["icon_state"])
			HUD.icon_state = HUDdatum.HUDoverlays[techobject]["icon_state"]
		H.HUDtech[HUD.name] += HUD
		if (HUD.process_flag)
			H.HUDprocess += HUD
	return

/* Using the HUD procs is simple. Call these procs in the life.dm of the intended mob.
Use the regular_hud_updates() proc before process_faction_hud(mob) so
the HUD updates properly! */

// faction HUDs processing and stuff

/proc/process_faction_hud(var/mob/M, var/mob/Alt)

	if (!can_process_hud(M))
		return
	if (!ishuman(M))
		return

	var/mob/living/carbon/human/viewer = M
	if (!viewer.original_job)
		return

	#ifdef PROCESS_FACTION_HUD_DEBUG
	world << "[viewer] processing faction huds."
	#endif

	var/datum/arranged_hud_process/P = arrange_hud_process(M, Alt, faction_hud_users)
	for (var/mob/living/carbon/human/perp in P.Mob.in_view(P.Turf))

		if (P.Mob.see_invisible < perp.invisibility)
			continue
		if (!perp.original_job)
			continue

		var/shared_job_check = FALSE

		if (viewer == perp)
			shared_job_check = TRUE
		else if (viewer.original_job.base_type_flag() == perp.original_job.base_type_flag())
			shared_job_check = TRUE
		if (istype(src, /mob/living/carbon/human))
			var/mob/living/carbon/human/HM = src
			if (HM.original_job_title != perp.original_job_title && map.civilizations == TRUE)
				shared_job_check = FALSE
			else if (HM.original_job_title == perp.original_job_title && map.civilizations == TRUE && perp.original_job_title != "Nomad")
				shared_job_check = TRUE
			if (((perp.original_job_title == "Nomad" && HM.civilization == perp.civilization)) && !perp.civilization == "none")
				shared_job_check = TRUE
			else
				shared_job_check = FALSE
		if(!map.nomads)
			if (shared_job_check)
				P.Client.images += perp.hud_list[BASE_FACTION]
			else
				P.Client.images += perp.hud_list[FACTION_TO_ENEMIES]
		if (map.nomads == TRUE)
			var/image/holderf = perp.hud_list[BASE_FACTION]
			holderf.icon = 'icons/mob/hud_1713.dmi'
			holderf.plane = HUD_PLANE
			holderf.icon_state = ""
			if (perp.original_job_title == "Nomad" && viewer.original_job_title == "Nomad")
				if (viewer == perp)
					holderf.icon_state = "civp" //player hud
				else if (perp.civilization == "none")
					holderf.icon_state = "" //nomads are yellow
				else if (perp.civilization == viewer.civilization && viewer.civilization != "none" && perp.leader == FALSE)
					holderf.icon_state = "civp" //same faction is green
				else if (perp.civilization == viewer.civilization && viewer.civilization != "none" && perp.leader == TRUE)
					holderf.icon_state = "civpl" //same faction is green
				else
					holderf.icon_state = "" //other factions are red
				perp.hud_list[BASE_FACTION] = holderf
				if (perp.civilization == viewer.civilization && viewer.civilization != "none" && perp.leader == FALSE)
					P.Client.images += perp.hud_list[BASE_FACTION]
				else if (perp.civilization == viewer.civilization && viewer.civilization != "none" && perp.leader == TRUE)
					P.Client.images += perp.hud_list[BASE_FACTION]
				else
					P.Client.images += perp.hud_list[FACTION_TO_ENEMIES]
/datum/arranged_hud_process
	var/client/Client
	var/mob/Mob
	var/turf/Turf

/proc/arrange_hud_process(var/mob/M, var/mob/Alt, var/list/hud_list)
	hud_list |= M
	var/datum/arranged_hud_process/P = new
	P.Client = M.client
	P.Mob = Alt ? Alt : M
	P.Turf = get_turf(P.Mob)
	return P

/proc/can_process_hud(var/mob/M)
	if (!M)
		return FALSE
	if (!M.client)
		return FALSE
	if (M.stat != CONSCIOUS)
		return FALSE
	return TRUE

/mob/proc/in_view(var/turf/T)
	return view(T)

/mob/observer/eye/in_view(var/turf/T)
	var/list/viewed = new
	for (var/mob/living/carbon/human/H in mob_list)
		if (get_dist(H, T) <= 7)
			viewed += H
	return viewed
