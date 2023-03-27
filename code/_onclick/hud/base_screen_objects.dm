#define MINIMAL_HUD

 /*
	Screen objects
	Todo: improve/re-implement

	Screen objects are only used for the hud and should not appear anywhere "in-game".
	They are used with the client/screen list and the screen_loc var.
	For more information, see the byond documentation on the screen_loc and screen vars.
*/
/image/no_recolor
	appearance_flags = RESET_COLOR


/obj/screen
	name = ""
	icon = 'icons/mob/screen/1713Style.dmi'
	layer = 20.0
	plane = HUD_PLANE

	var/obj/master = null //A reference to the object in the slot. Grabs or items, generally.
	var/mob/living/parentmob
	var/process_flag = FALSE
	var/hideflag = FALSE

/obj/screen/New(_name = "unnamed", _screen_loc = "7,7", mob/living/_parentmob, _icon, _icon_state)
	parentmob = _parentmob
	name = _name
	screen_loc = _screen_loc
	if (parentmob)
		icon = parentmob.client.prefs.UI_file
	if (_icon)
		icon = _icon
	if (_icon_state)
		icon_state = _icon_state

/obj/screen/process()
	return

/obj/screen/Destroy()
	master = null
	return ..()

/obj/screen/Click(location, control, params)
	if (!usr)	return TRUE
	switch(name)

		if ("equip")
			if (ishuman(usr))
				var/mob/living/human/H = usr
				H.quick_equip()

		if ("Reset Machine")
			usr.unset_using_object()
		else
			return FALSE
	return TRUE


//--------------------------------------------------close---------------------------------------------------------

/obj/screen/close
	name = "close"

/obj/screen/close/New()
	return

/obj/screen/close/Click()
	if (master)
		if (istype(master, /obj/item/weapon/storage))
			var/obj/item/weapon/storage/S = master
			S.close(usr)
	return TRUE
//--------------------------------------------------close end---------------------------------------------------------


//--------------------------------------------------GRAB---------------------------------------------------------
/obj/screen/grab
	name = "grab"

/obj/screen/grab/Click()
	var/obj/item/weapon/grab/G = master
	if (G)
		G.s_click(src)
	return TRUE

/obj/screen/grab/attack_hand()
	return

/obj/screen/grab/attackby()
	return
//-----------------------------------------------GRAB END---------------------------------------------------------





//-----------------------------------------------ITEM ACTION---------------------------------------------------------
/obj/screen/item_action
	var/obj/item/owner

/obj/screen/item_action/Destroy()
	..()
	owner = null

/obj/screen/item_action/Click()
	if (!usr || !owner)
		return TRUE
	if (!usr.canClick())
		return

	if (usr.stat || usr.restrained() || usr.stunned || usr.lying)
		return TRUE

	if (!(owner in usr))
		return TRUE

	owner.ui_action_click()
	return TRUE
//-----------------------------------------------ITEM ACTION END---------------------------------------------------------



//--------------------------------------------------ZONE SELECT---------------------------------------------------------
/obj/screen/zone_sel
	name = "damage zone"
	icon_state = "zone_sel"
	var/selecting = null

/obj/screen/zone_sel/New()
	..()
	selecting = parentmob.targeted_organ

/obj/screen/zone_sel/Click(location, control,params)
	var/list/PL = params2list(params)
	var/icon_x = text2num(PL["icon-x"])
	var/icon_y = text2num(PL["icon-y"])
	var/old_selecting = parentmob.targeted_organ //We're only going to update_icon() if there's been a change

	switch(icon_y)
		if (1 to 3) //Feet
			switch(icon_x)
				if (10 to 15)
					parentmob.targeted_organ = "r_foot"
				if (17 to 22)
					parentmob.targeted_organ = "l_foot"
				else
					return TRUE
		if (4 to 9) //Legs
			switch(icon_x)
				if (10 to 15)
					parentmob.targeted_organ = "r_leg"
				if (17 to 22)
					parentmob.targeted_organ = "l_leg"
				else
					return TRUE
		if (10 to 13) //Hands and groin
			switch(icon_x)
				if (8 to 11)
					parentmob.targeted_organ = "r_hand"
				if (12 to 20)
					parentmob.targeted_organ = "groin"
				if (21 to 24)
					parentmob.targeted_organ = "l_hand"
				else
					return TRUE
		if (14 to 22) //Chest and arms to shoulders
			switch(icon_x)
				if (8 to 11)
					parentmob.targeted_organ = "r_arm"
				if (12 to 20)
					parentmob.targeted_organ = "chest"
				if (21 to 24)
					parentmob.targeted_organ = "l_arm"
				else
					return TRUE
		if (23 to 30) //Head, but we need to check for eye or mouth
			if (icon_x in 12 to 20)
				parentmob.targeted_organ = "head"
				switch(icon_y)
					if (23 to 24)
						if (icon_x in 15 to 17)
							parentmob.targeted_organ = "mouth"
					/*if (26) //Eyeline, eyes are on 15 and 17
						if (icon_x in 14 to 18)
							selecting = "eyes"
					if (25 to 27)
						if (icon_x in 15 to 17)
							selecting = "eyes"*/
					if (25 to 27)
						if (icon_x in 14 to 18)
							parentmob.targeted_organ = "eyes"

	if (old_selecting != parentmob.targeted_organ)
		update_icon()

	selecting = parentmob.targeted_organ
	parentmob.HUDneed["random damage zone"].update_icon()
	return TRUE

/obj/screen/zone_sel/New()
	..()
	update_icon()

/obj/screen/zone_sel/update_icon()
	overlays.Cut()
	overlays += image('icons/mob/zone_sel.dmi', "[parentmob.targeted_organ]")
//--------------------------------------------------ZONE SELECT END---------------------------------------------------------
//--------------------------------------------------ZONE SELECT---------------------------------------------------------
/obj/screen/zone_sel2
	name = "damage zone"
	icon_state = "zone_sel"
	var/selecting = null

/obj/screen/zone_sel2/New()
	..()
	selecting = parentmob.targeted_organ

/obj/screen/zone_sel2/Click(location, control,params)
	var/list/PL = params2list(params)
	var/icon_x = text2num(PL["icon-x"])
	var/icon_y = text2num(PL["icon-y"])
	var/old_selecting = parentmob.targeted_organ //We're only going to update_icon() if there's been a change

	switch(icon_y)
		if (1 to 7) //Feet
			switch(icon_x)
				if (1 to 16)
					parentmob.targeted_organ = "r_foot"
				if (17 to 32)
					parentmob.targeted_organ = "l_foot"
				else
					return TRUE
		if (8 to 19) //Legs
			switch(icon_x)
				if (1 to 16)
					parentmob.targeted_organ = "r_leg"
				if (17 to 32)
					parentmob.targeted_organ = "l_leg"
				else
					return TRUE
		if (19 to 23) //Legs and groin
			switch(icon_x)
				if (1 to 12)
					parentmob.targeted_organ = "r_leg"
				if (12 to 22)
					parentmob.targeted_organ = "groin"
				if (22 to 32)
					parentmob.targeted_organ = "l_leg"
				else
					return TRUE
		if (23 to 25) //Hands and groin
			switch(icon_x)
				if (2 to 11)
					parentmob.targeted_organ = "r_hand"
				if (12 to 22)
					parentmob.targeted_organ = "groin"
				if (23 to 31)
					parentmob.targeted_organ = "l_hand"
				else
					return TRUE
		if (26 to 32) //Hands and chest
			switch(icon_x)
				if (2 to 11)
					parentmob.targeted_organ = "r_hand"
				if (12 to 22)
					parentmob.targeted_organ = "chest"
				if (23 to 31)
					parentmob.targeted_organ = "l_hand"
				else
					return TRUE
		if (33 to 45) //Chest and arms to shoulders
			switch(icon_x)
				if (4 to 10)
					parentmob.targeted_organ = "r_arm"
				if (11 to 22)
					parentmob.targeted_organ = "chest"
				if (23 to 29)
					parentmob.targeted_organ = "l_arm"
				else
					return TRUE
		if (46 to 64) //Head, but we need to check for eye or mouth
			if (icon_x in 12 to 22)
				parentmob.targeted_organ = "head"
				switch(icon_y)
					if (49 to 51)
						if (icon_x in 13 to 20)
							parentmob.targeted_organ = "mouth"
					if (53 to 55)
						if (icon_x in 13 to 20)
							parentmob.targeted_organ = "eyes"

	if (old_selecting != parentmob.targeted_organ)
		update_icon()

	selecting = parentmob.targeted_organ
	parentmob.HUDneed["random damage zone"].update_icon()
	return TRUE

/obj/screen/zone_sel2/New()
	..()
	update_icon()

/obj/screen/zone_sel2/update_icon()
	overlays.Cut()
	overlays += image('icons/mob/screen/zone_sel_lw.dmi', "[parentmob.targeted_organ]")
//--------------------------------------------------ZONE SELECT END---------------------------------------------------------
//--------------------------------------------------ZONE SELECT---------------------------------------------------------
/obj/screen/zone_sel3
	name = "damage zone"
	icon_state = "zone_sel"
	var/selecting = null

/obj/screen/zone_sel3/New()
	..()
	selecting = parentmob.targeted_organ

/obj/screen/zone_sel3/Click(location, control,params)
	var/list/PL = params2list(params)
	var/icon_x = text2num(PL["icon-x"])
	var/icon_y = text2num(PL["icon-y"])
	var/old_selecting = parentmob.targeted_organ //We're only going to update_icon() if there's been a change

	switch(icon_y)
		if(5 to 8) //Feet
			switch(icon_x)
				if(6 to 13)
					parentmob.targeted_organ = "r_foot"
				if(20 to 27)
					parentmob.targeted_organ = "l_foot"
				else
					return 1
		if(9 to 25) //Legs
			switch(icon_x)
				if(8 to 15)
					parentmob.targeted_organ = "r_leg"
				if(18 to 25)
					parentmob.targeted_organ = "l_leg"
				else
					return 1
		if(26 to 32) //Hands and groin
			switch(icon_x)
				if(5 to 11)
					parentmob.targeted_organ = "r_hand"
				if(12 to 22)
					parentmob.targeted_organ = "groin"
				if(23 to 29)
					parentmob.targeted_organ = "l_hand"
				else
					return 1
		if(33 to 48) //Chest and arms to shoulders
			switch(icon_x)
				if(4 to 10)
					parentmob.targeted_organ = "r_arm"
				if(11 to 23)
					parentmob.targeted_organ = "chest"
				if(24 to 29)
					parentmob.targeted_organ = "l_arm"
				else
					return 1
		if(49 to 60) //Head, but we need to check for eye or mouth
			if(icon_x in 11 to 22)
				parentmob.targeted_organ = "head"
				switch(icon_y)
					if(48 to 52)
						if(icon_x in 13 to 20)
							parentmob.targeted_organ = "mouth"
					if(53 to 55) //Eyeline, eyes are on 15 and 17
						if(icon_x in 14 to 19)
							parentmob.targeted_organ = "eyes"
	if (old_selecting != parentmob.targeted_organ)
		update_icon()

	selecting = parentmob.targeted_organ
	parentmob.HUDneed["random damage zone"].update_icon()
	return TRUE

/obj/screen/zone_sel3/New()
	..()
	update_icon()

/obj/screen/zone_sel3/update_icon()
	overlays.Cut()
	overlays += image('icons/mob/screen/zone_sel_fof.dmi', "[parentmob.targeted_organ]")
//--------------------------------------------------ZONE SELECT END---------------------------------------------------------
//--------------------------------------------------RANDOM ZONE SELECT---------------------------------------------------------
/obj/screen/zone_sel_random
	name = "random damage zone"
	icon_state = "random"
	var/previous_s = ""

/obj/screen/zone_sel_random/Click(location, control,params)
	if (parentmob.targeted_organ == "random" && previous_s != "")
		parentmob.targeted_organ = previous_s
	else
		previous_s = parentmob.targeted_organ
		parentmob.targeted_organ = "random"
	update_icon()
	return TRUE

/obj/screen/zone_sel_random/New()
	..()
	update_icon()

/obj/screen/zone_sel_random/update_icon()
	if (parentmob.targeted_organ == "random")
		icon_state = "random_on"
	else
		icon_state = "random"
//--------------------------------------------------RANDOM ZONE SELECT END---------------------------------------------------------
/obj/screen/text
	icon = null
	icon_state = null
	mouse_opacity = FALSE
	screen_loc = "CENTER-7,CENTER-7"
	maptext_height = 480
	maptext_width = 480


/obj/screen/storage
	name = "storage"

/obj/screen/storage/New()
	if (usr && usr.client)
		icon = usr.client.prefs.UI_file
	..()

/obj/screen/storage/Click()
	if (!usr.canClick())
		return TRUE
	if (usr.stat || usr.paralysis || usr.stunned || usr.weakened)
		return TRUE
	if (master)
		var/obj/item/I = usr.get_active_hand()
		if (I)
			usr.ClickOn(master)
	return TRUE

//--------------------------------------------------inventory---------------------------------------------------------
/obj/screen/inventory
	var/slot_id //The indentifier for the slot. It has nothing to do with ID cards.
	icon = 'icons/mob/screen/1713Style.dmi'
	layer = 19

/obj/screen/inventory/New(_name = "unnamed", _screen_loc = "7,7", _slot_id = null, _icon = null, _icon_state = null, _parentmob = null)
	name = _name
	screen_loc = _screen_loc
	icon = _icon
	slot_id = _slot_id
	icon_state = _icon_state
	parentmob = _parentmob

/obj/screen/inventory/Click()
	// At this point in client Click() code we have passed the TRUE/10 sec check and little else
	// We don't even know if it's a middle click
	if (!usr.canClick())
		return TRUE
	if (usr.stat || usr.paralysis || usr.stunned || usr.weakened)
		return TRUE
	switch(name)
		if ("hand")
			usr:swap_hand()
		else
			if (usr.attack_ui(slot_id))
				usr.update_inv_l_hand(0)
				usr.update_inv_r_hand(0)
	return TRUE

/obj/screen/inventory/hand
	name = "nonamehand"

/obj/screen/inventory/hand/New()
	..()
	update_icon()

/obj/screen/inventory/hand/Click()
	var/mob/living/human/C = parentmob
	if (slot_id == slot_l_hand)
		C.activate_hand("l")
	else
		C.activate_hand("r")

/obj/screen/inventory/hand/update_icon()
	if (slot_id == (parentmob.hand ? slot_l_hand : slot_r_hand)) //���e aa���e ������� o�aa ���a�a�a�� ��a��
		icon_state = "act_hand[slot_id==slot_l_hand ? "-l" : "-r"]"
	else
		icon_state = "hand[slot_id==slot_l_hand ? "-l" : "-r"]"
//--------------------------------------------------inventory end---------------------------------------------------------

//--------------------------------------------------health---------------------------------------------------------
/obj/screen/health
	name = "health"
	icon = 'icons/mob/screen/healthdoll.dmi'
	icon_state = "healthdoll_BASE_ALIVE"
	screen_loc = "15,7"
	process_flag = TRUE

/obj/screen/health/process()
	var/mob/living/human/H = parentmob
	overlays.Cut()
	if (parentmob.stat != DEAD)

		icon_state = "healthdoll_BASE"
		for(var/X in H.organs)
			var/obj/item/organ/external/BP = X
			var/damage = BP.burn_dam + BP.brute_dam
			var/icon_num = 1
			if(damage > (BP.max_damage*0.15)) // > 15% max dmg - yellow
				icon_num = 2
			if(damage > (BP.max_damage*0.4)) // > 40% max dmg - orange
				icon_num = 3
			if(damage > BP.max_damage*0.7) // > 70% max dmg - red
				icon_num = 4
			if(icon_num)
				add_overlay(image(icon, "[BP.limb_name][icon_num]"))
		var/list/missinglimbs = H.get_missing_limbs()
		for(var/t in missinglimbs) //Missing limbs
			add_overlay(image(icon, "[t]6"))
	else
		icon_state = "healthdoll_BASE_DEAD"
		var/list/missinglimbs = H.get_missing_limbs()
		for(var/t in missinglimbs) //Missing limbs
			add_overlay(image(icon, "[t]6"))

/obj/screen/health/Click()
	if (ishuman(parentmob))
		var/mob/living/human/X = parentmob
		X.exam_self()

//--------------------------------------------------health end---------------------------------------------------------

//--------------------------------------------------nutrition---------------------------------------------------------
/obj/screen/nutrition
	name = "nutrition"

	icon_state = "nutrition1"
	screen_loc = "15,6"
	process_flag = TRUE

/obj/screen/nutrition/process()
	//var/mob/living/human/H = parentmob
	update_icon()

/obj/screen/nutrition/update_icon()
	var/mob/living/human/H = parentmob

	// show our worst status, hunger or thirst

	var/nstatus = Clamp(smart_round(1/(H.nutrition/H.max_nutrition)), 1, 4)
	var/wstatus = Clamp(smart_round(1/(H.water/H.max_water)), 1, 4)
	icon_state = "nutrition[max(nstatus, wstatus)]"

/obj/screen/nutrition/Click()
	if (!parentmob)
		return

	var/mob/living/human/H = parentmob

	var/hungry_coeff = min(H.nutrition/H.max_nutrition, 1.0)
	var/hungry_percentage = "[round(hungry_coeff*100)]%"

	var/thirsty_coeff = min(H.water/H.max_water, 1.0)
	var/thirsty_percentage = "[round(thirsty_coeff*100)]%"

	if (thirsty_coeff <= 0)
		H << "<span class = 'danger'>You're dehydrating.</span>"
	else
		H << "<span class = 'warning'>You're about [thirsty_percentage] hydrated.</span>"

	if (hungry_coeff <= 0)
		H << "<span class = 'danger'>You're starving.</span>"
	else
		H << "<span class = 'warning'>You're about [hungry_percentage] full.</span>"

//--------------------------------------------------nutrition end---------------------------------------------------------

//--------------------------------------------------bodytemp---------------------------------------------------------
/obj/screen/bodytemp
	name = "body temperature"

	icon_state = "temp0"
	screen_loc = "15,9"
	process_flag = TRUE

/obj/screen/bodytemp/process()
	update_icon()

/obj/screen/bodytemp/update_icon()
	//TODO: precalculate all of this stuff when the species datum is created
	var/base_temperature = parentmob:species.body_temperature
	if (base_temperature == null) //some species don't have a set metabolic temperature
		base_temperature = (parentmob:species.heat_level_1 + parentmob:species.cold_level_1)/2

	var/temp_step
	if (parentmob:bodytemperature >= base_temperature)
		temp_step = (parentmob:species.heat_level_1 - base_temperature)/4

		if (parentmob:bodytemperature >= parentmob:species.heat_level_1)
			icon_state = "temp4"
		else if (parentmob:bodytemperature >= base_temperature + temp_step*3)
			icon_state = "temp3"
		else if (parentmob:bodytemperature >= base_temperature + temp_step*2)
			icon_state = "temp2"
		else if (parentmob:bodytemperature >= base_temperature + temp_step*1)
			icon_state = "temp1"
		else
			icon_state = "temp0"

	else if (parentmob:bodytemperature < base_temperature)
		temp_step = (base_temperature - parentmob:species.cold_level_1)/4

		if (parentmob:bodytemperature <= parentmob:species.cold_level_1)
			icon_state = "temp-4"
		else if (parentmob:bodytemperature <= base_temperature - temp_step*3)
			icon_state = "temp-3"
		else if (parentmob:bodytemperature <= base_temperature - temp_step*2)
			icon_state = "temp-2"
		else if (parentmob:bodytemperature <= base_temperature - temp_step*1)
			icon_state = "temp-1"
		else
			icon_state = "temp0"
//--------------------------------------------------bodytemp end---------------------------------------------------------

/obj/screen/pull
	name = "pull"

	icon_state = "pull0"
	screen_loc = "14,2"

/obj/screen/pull/New()
	..()
	update_icon()

/obj/screen/pull/Click()
	usr.stop_pulling()
	update_icon()

/obj/screen/pull/update_icon()
	if (parentmob.pulling)
		icon_state = "pull1"
	else
		icon_state = "pull0"
//-----------------------throw------------------------------
/obj/screen/HUDthrow
	name = "throw"

	icon_state = "act_throw_off"
	screen_loc = "15,2"

/obj/screen/HUDthrow/New()
	/*if (usr)
		//parentmob = usr
		//usr.verbs += /obj/screen/HUDthrow/verb/toggle_throw_mode()
		if (usr.client)
			usr.client.screen += src*/
	..()
	update_icon()

/obj/screen/HUDthrow/Click()
	parentmob.toggle_throw_mode()

/obj/screen/HUDthrow/update_icon()
	if (parentmob.in_throw_mode)
		icon_state = "act_throw_on"
	else
		icon_state = "act_throw_off"
//-----------------------throw END------------------------------

//-----------------------drop------------------------------
/obj/screen/drop
	name = "drop"

	icon_state = "act_drop"
	screen_loc = "15:-16,2"

/obj/screen/drop/Click()
	if (usr.client)
		usr.client.drop_item()
//-----------------------drop END------------------------------

//-----------------------resist------------------------------
/obj/screen/resist
	name = "resist"

	icon_state = "act_resist"
	screen_loc = "14:16,2"

/obj/screen/resist/Click()
	if (isliving(parentmob))
		var/mob/living/L = parentmob
		L.resist()
//-----------------------resist END------------------------------
/obj/screen/fixeye
	name = "fixeye"
	icon_state = "fixeye"
	screen_loc = "19,8"

/obj/screen/fixeye/New()
	..()
	update_icon()

/obj/screen/fixeye/update_icon()
	var/mob/living/human/L = parentmob
	if (!L.facing_dir)
		icon_state = "fixeye"
	else
		icon_state = "fixeye_on"

/obj/screen/fixeye/Click()
	if (isliving(parentmob))
		var/mob/living/human/L = parentmob

		L.set_face_dir()

		if (!L.facing_dir)
			L << "You are now not facing anything."
			icon_state = "fixeye"
		else
			L << "You are now facing [dir2text(L.facing_dir)]."
			icon_state = "fixeye_on"
		update_icon()

/obj/screen/kick_jump_bite
	name = "secondary attack"

	icon_state = "kick"
	screen_loc = "11,2"

/obj/screen/kick_jump_bite/Click()
	if (isliving(parentmob))
		switch (parentmob.middle_click_intent)
			if("kick")
				parentmob.middle_click_intent = "jump"
				icon_state = "jump"
				update_icon()
				return
			if("jump")
				parentmob.middle_click_intent = "bite"
				icon_state = "bite"
				update_icon()
				return
			if("bite")
				parentmob.middle_click_intent = "kick"
				icon_state = "kick"
				update_icon()
				return


obj/screen/tactic
	name = "tactic"

	icon_state = "charge"
	screen_loc = "19,4"

/obj/screen/tactic/New()
	..()
	update_icon()
/obj/screen/tactic/Click()
	if (isliving(parentmob))
		switch (parentmob.tactic)
			if("charge") //10% damage buff
				parentmob.tactic = "aim"
				icon_state = "aim"
				parentmob << "<span class='warning'>You will now focus on aiming.</span>"
				update_icon()
				return
			if("aim") //10% accuracy buff
				parentmob.tactic = "rush"
				icon_state = "rush"
				parentmob << "<span class='warning'>You will now focus on rushing.</span>"
				update_icon()
				return
			if("rush") // 15% cooldown buff
				parentmob.tactic = "defend"
				icon_state = "defend"
				parentmob << "<span class='warning'>You will now focus on defending.</span>"
				update_icon()
				return
			if("defend") //20% dodge/parry buff
				parentmob.tactic = "charge"
				icon_state = "charge"
				parentmob << "<span class='warning'>You will now focus on charging.</span>"
				update_icon()
				return

/obj/screen/tactic/update_icon()
	if (parentmob.tactic == "charge")
		icon_state = "charge"

	else if (parentmob.tactic == "aim")
		icon_state = "aim"

	else if (parentmob.tactic == "rush")
		icon_state = "rush"

	else if (parentmob.tactic == "defend")
		icon_state = "defend"

/obj/screen/mood
	name = "mood"

	icon_state = "mood1"
	screen_loc = "15,8"
	process_flag = TRUE
/obj/screen/mood/Click()
	if (ishuman(parentmob))
		var/mob/living/human/C = parentmob
		C.print_mood()
/obj/screen/mood/process()
	update_icon()

/obj/screen/mood/update_icon()
	if (isliving(parentmob))
		var/mob/living/human/L = parentmob
		var/old_icon = icon_state
		var/old_mood = L.mood
		switch(L.mood)
			if(-5000000 to 19)
				icon_state = "mood5"

			if(20 to 39)
				icon_state = "mood4"

			if(40 to 59)
				icon_state = "mood3"

			if(60 to 79)
				icon_state = "mood2"

			if(80 to INFINITY)
				icon_state = "mood1"
		if(old_icon && old_icon != icon_state)
			if(old_mood > L.mood)
				src << "<span class='warning'>My mood gets worse.</span>"
			else
				src << "<span class='info'>My mood gets better.</span>"
//-----------------------mov_intent------------------------------
/obj/screen/mov_intent
	name = "mov_intent"

	icon_state = "walk"
	screen_loc = "14,1"

/obj/screen/mov_intent/Click()
//	if (ishuman(parentmob))
	var/mob/living/human/C = parentmob
	if (C.legcuffed)
		C << "<span class='notice'>You are legcuffed! You cannot run until you get [C.legcuffed] removed!</span>"
		C.m_intent = "walk"	//Just incase
		update_icon()
		return TRUE

	if (C.m_intent == "run")
		C.m_intent = "proning"
	else if (C.m_intent == "proning")
		if (C.facing_dir)
			C.set_face_dir()
		C.m_intent = "stealth"
	else if (C.m_intent == "stealth")
		C.m_intent = "walk"
	else if (C.m_intent == "walk")
		C.m_intent = "run"
	else
		C.m_intent = "walk"

	if (C.m_intent == "proning")
		C.prone = TRUE
		C.facing_dir = dir
		if (C.dir == NORTH || C.dir == NORTHWEST || C.dir == NORTHEAST || C.dir == WEST)
			C.dir = WEST
		else
			C.dir = EAST
		var/matrix/M = matrix()
		M.Turn(90)
		M.Translate(1,-6)
		update_icon()
		C.transform = M
		return

	else
		C.prone = FALSE
		var/matrix/M = matrix()
		M.Translate(0, 16*(C.size_multiplier-1))
		C.transform = M
		update_icon()
		return

/obj/screen/mov_intent/New()
	..()
	update_icon()

/obj/screen/mov_intent/update_icon()
	var/mob/living/human/C = parentmob
	switch(C.m_intent)
		if ("run")
			icon_state = "running"
		if ("walk")
			icon_state = "walking"
		if ("proning")
			icon_state = "proning"
		if ("stealth")
			icon_state = "stealth"

//-----------------------mov_intent END------------------------------
/obj/screen/equip
	name = "equip"

	icon_state = "act_equip"
	screen_loc = "8,2"

/obj/screen/equip/Click()
	if (ishuman(parentmob))
		var/mob/living/human/H = parentmob
		H.quick_equip()
//-----------------------swap------------------------------
/obj/screen/swap
	name = "swap hand"

	icon_state = "swap-l"

/obj/screen/swap/New()
	..()
	overlays += image(icon = icon, icon_state =  "swap-r", pixel_x = 32)

/obj/screen/swap/Click()
	parentmob.swap_hand()
//-----------------------swap END------------------------------
//-----------------------intent------------------------------
/obj/screen/intent
	name = "intent"

	icon_state = "help"
	screen_loc = "8,2"

/obj/screen/intent/New()
	..()
	update_icon()

/obj/screen/intent/Click()
	parentmob.a_intent_change("right")
//	update_icon()//update in a_intent_change, because macro

/obj/screen/intent/update_icon()
	switch (parentmob.a_intent)
		if (I_HELP)
			icon_state = "help"
		if (I_HARM)
			icon_state = "harm"
		if (I_GRAB)
			icon_state = "grab"
		if (I_DISARM)
			icon_state = "disarm"
//-----------------------intent END------------------------------
//-----------------------mode------------------------------
/obj/screen/mode
	name = "mode"

	icon_state = "dodge"
	screen_loc = "11,1"
//	process_flag = TRUE

/obj/screen/mode/New()
	..()
	update_icon()

/obj/screen/mode/Click()
	if (parentmob.defense_intent == I_DODGE)
		parentmob.defense_intent = I_PARRY
		parentmob << "<span class='warning'>You will now parry.</span>"
		update_icon()
	else
		parentmob.defense_intent = I_DODGE
		parentmob << "<span class='warning'>You will now dodge.</span>"
		update_icon()
/obj/screen/mode/update_icon()
	switch (parentmob.defense_intent)
		if (I_DODGE)
			icon_state = "dodge"
		if (I_PARRY)
			icon_state = "parry"

//-----------------------mode END------------------------------


/obj/screen/fastintent
	name = "fastintent"

//update in a_intent_change, because macro
/*/obj/screen/fastintent/Click()
	if (parentmob.HUDneed.Find("intent"))
		var/obj/screen/intent/I = parentmob.HUDneed["intent"]
		I.update_icon()*/


/obj/screen/fastintent/help
	icon_state = "intent_help"

/obj/screen/fastintent/help/Click()
	parentmob.a_intent_change(I_HELP)
//	..()

/obj/screen/fastintent/harm
	icon_state = "intent_harm"

/obj/screen/fastintent/harm/Click()
	parentmob.a_intent_change(I_HARM)
//	..()

/obj/screen/fastintent/grab
	icon_state = "intent_grab"

/obj/screen/fastintent/grab/Click()
	parentmob.a_intent_change(I_GRAB)
//	..()

/obj/screen/fastintent/disarm
	icon_state = "intent_disarm"

/obj/screen/fastintent/disarm/Click()
	parentmob.a_intent_change(I_DISARM)
//	..()

/obj/screen/nvgoverlay
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "blank"
	name = "nvg"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	mouse_opacity = FALSE
	process_flag = TRUE
	layer = 17 //The black screen overlay sets layer to 18 to display it, this one has to be just on top.

/obj/screen/thermaloverlay
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "blank"
	name = "thermal"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	mouse_opacity = FALSE
	process_flag = TRUE
	layer = 17 //The black screen overlay sets layer to 18 to display it, this one has to be just on top.

/obj/screen/gasmask
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "blank"
	name = "gas mask"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	mouse_opacity = FALSE
	process_flag = TRUE
	layer = 17.1 //The black screen overlay sets layer to 18 to display it, this one has to be just on top.


/obj/screen/nvgoverlay/process()
	update_icon()

/obj/screen/nvgoverlay/update_icon()
	underlays.Cut()
	if (parentmob.nvg)
		underlays += global_hud.nvg

/obj/screen/thermaloverlay/process()
	update_icon()

/obj/screen/thermaloverlay/update_icon()
	underlays.Cut()
	if (parentmob.thermal)
		underlays += global_hud.thermal

/obj/screen/gasmask/process()
	update_icon()

/obj/screen/gasmask/update_icon()
	underlays.Cut()
	if (ishuman(parentmob))
		var/mob/living/human/H = parentmob
		if (H.wear_mask && istype(H.wear_mask, /obj/item/clothing/mask/gas))
			underlays += global_hud.gasmask


/obj/screen/drugoverlay
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "blank"
	name = "drugs"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	mouse_opacity = FALSE
	process_flag = TRUE
	layer = 17 //The black screen overlay sets layer to 18 to display it, this one has to be just on top.
//	var/global/image/blind_icon = image('icons/mob/screen1_full.dmi', "blackimageoverlay")

/obj/screen/drugoverlay/process()
	update_icon()
	return

/obj/screen/drugoverlay/update_icon()
	underlays.Cut()

	var/mob/living/human/H = parentmob

	if (!istype(H))
		if (parentmob.sdisabilities & NEARSIGHTED)
			underlays += global_hud.vimpaired

	if (parentmob.eye_blurry)
		underlays += global_hud.blurry
	if (parentmob.druggy)
		underlays += global_hud.druggy
	return

/obj/screen/full_1_tile_overlay
	icon = 'icons/mob/screen/effects.dmi'
	name = "full_1_tile_overlay"
	icon_state = "blank"
	layer = 21
	mouse_opacity = TRUE
/obj/screen/full_1_tile_overlay/process()
	update_icon()
	return

/obj/screen/damageoverlay
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "oxydamageoverlay0"
	name = "dmg"
	screen_loc = "4,1"
	mouse_opacity = FALSE
	process_flag = TRUE
	layer = 17 //The black screen overlay sets layer to 18 to display it, this one has to be just on top.
	var/global/image/blind_icon = image('icons/mob/screen1_full.dmi', "blackimageoverlay")


/obj/screen/damageoverlay/process()
	update_icon()
	return

/obj/screen/damageoverlay/update_icon()
	overlays.Cut()
	UpdateHealthState()

	underlays.Cut()
	UpdateVisionState()
	return

/obj/screen/damageoverlay/proc/UpdateHealthState()
	var/mob/living/human/H = parentmob

	if (H.stat == UNCONSCIOUS)
		//Critical damage passage overlay
		if (H.health <= 0)
			var/image/I
			switch(H.health)
				if (-20 to -10)
					I = H.overlays_cache[1]
				if (-30 to -20)
					I = H.overlays_cache[2]
				if (-40 to -30)
					I = H.overlays_cache[3]
				if (-50 to -40)
					I = H.overlays_cache[4]
				if (-60 to -50)
					I = H.overlays_cache[5]
				if (-70 to -60)
					I = H.overlays_cache[6]
				if (-80 to -70)
					I = H.overlays_cache[7]
				if (-90 to -80)
					I = H.overlays_cache[8]
				if (-95 to -90)
					I = H.overlays_cache[9]
				if (-INFINITY to -95)
					I = H.overlays_cache[10]
			overlays += I
	else
		//Oxygen damage overlay
		if (H.oxyloss)
			var/image/I
			switch(H.oxyloss)
				if (10 to 20)
					I = H.overlays_cache[11]
				if (20 to 25)
					I = H.overlays_cache[12]
				if (25 to 30)
					I = H.overlays_cache[13]
				if (30 to 35)
					I = H.overlays_cache[14]
				if (35 to 40)
					I = H.overlays_cache[15]
				if (40 to 45)
					I = H.overlays_cache[16]
				if (45 to INFINITY)
					I = H.overlays_cache[17]
			overlays += I

		//Fire and Brute damage overlay (BSSR)
		var/hurtdamage = H.getBruteLoss() + H.getFireLoss() + H.damageoverlaytemp
		H.damageoverlaytemp = FALSE // We do this so we can detect if someone hits us or not.
		if (hurtdamage)
			var/image/I
			switch(hurtdamage)
				if (10 to 25)
					I = H.overlays_cache[18]
				if (25 to 40)
					I = H.overlays_cache[19]
				if (40 to 55)
					I = H.overlays_cache[20]
				if (55 to 70)
					I = H.overlays_cache[21]
				if (70 to 85)
					I = H.overlays_cache[22]
				if (85 to INFINITY)
					I = H.overlays_cache[23]
			overlays += I

/obj/screen/damageoverlay/proc/UpdateVisionState()
	if (parentmob.eye_blind)
		underlays |= list(blind_icon)
//	else
//		underlays.Remove(list(blind_icon))
//	world << underlays.len

/obj/screen/frippery
	name = ""

/obj/screen/frippery/New(_icon_state,_screen_loc = "7,7",_dir, mob/living/_parentmob)
	parentmob = _parentmob
	screen_loc = _screen_loc
	icon_state = _icon_state
	dir = _dir

////////////Screen effects/////////////////////////
/obj/screen/noise
	icon = 'icons/effects/static.dmi'
	icon_state = "1 moderate"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	layer = 17
	alpha = 127

/obj/screen/scanline
	icon = 'icons/effects/static.dmi'
	icon_state = "scanlines"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	alpha = 50
	layer = 17

/obj/screen/fishbed
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "fishbed"
	layer = 17

/obj/screen/cover
	icon = 'icons/mob/screenlimit.dmi'
	icon_state = "cover"
	layer = 18

//-----------------------Gun Mod------------------------------
/obj/screen/gun
	name = "gun"

	master = null
	dir = 2

/obj/screen/gun/Click(location, control, params)
	if (!usr)
		return
	return TRUE

/obj/screen/gun/New()
	..()
	if (!parentmob.aiming)
		parentmob.aiming = new(parentmob)
	update_icon()

/obj/screen/gun/mode
	name = "Toggle Gun Mode"
	icon_state = "gun0"
	screen_loc = "15,2"


/obj/screen/gun/mode/Click(location, control, params)
	if (..())
		var/mob/living/user = parentmob
		if (istype(user))
			if (!user.aiming) user.aiming = new(user)
			user.aiming.toggle_active()
			update_icon()
		return TRUE
	return FALSE

/obj/screen/gun/mode/update_icon()
	icon_state = "gun[parentmob.aiming.active]"

/obj/screen/gun/move
	name = "Allow Movement"
	icon_state = "no_walk0"
	screen_loc = "15,3"

/obj/screen/gun/move/Click(location, control, params)
	if (..())
		var/mob/living/user = parentmob
		if (istype(user))
			if (!user.aiming) user.aiming = new(user)
			user.aiming.toggle_permission(TARGET_CAN_MOVE)
			update_icon()
		return TRUE
	return FALSE

/obj/screen/gun/move/update_icon()
	if (!(parentmob.aiming.target_permissions & TARGET_CAN_MOVE))
		icon_state = "no_walk0"
//			owner.gun_move_icon.name = "Allow Movement"
	else
		icon_state = "no_walk1"
//			owner.gun_move_icon.name = "Disallow Movement"

/obj/screen/gun/item
	name = "Allow Item Use"
	icon_state = "no_items0"
	screen_loc = "14,2"

/obj/screen/gun/item/Click(location, control, params)
	if (..())
		var/mob/living/user = parentmob
		if (istype(user))
			if (!user.aiming) user.aiming = new(user)
			user.aiming.toggle_permission(TARGET_CAN_CLICK)
			update_icon()
		return TRUE
	return FALSE

/obj/screen/gun/item/update_icon()
	if (!(parentmob.aiming.target_permissions & TARGET_CAN_CLICK))
		icon_state = "no_items0"
//			owner.item_use_icon.name = "Allow Item Use"
	else
		icon_state = "no_items1"
//			owner.item_use_icon.name = "Disallow Item Use"

//-----------------------Gun Mod End------------------------------

//-----------------------toggle_inventory------------------------------
/obj/screen/toggle_inventory

	icon_state = "b-open"
	name = "toggle inventory"
	screen_loc = "1,0"

/obj/screen/toggle_inventory/proc/hideobjects()
	for (var/obj/screen/HUDelement in parentmob.HUDinventory)
		if (HUDelement.hideflag & TOGGLE_INVENTORY_FLAG)
			HUDelement.invisibility = 101
			hidden_inventory_update(HUDelement)
	for (var/obj/screen/HUDelement in parentmob.HUDfrippery)
		if (HUDelement.hideflag & TOGGLE_INVENTORY_FLAG)
			HUDelement.invisibility = 101

/obj/screen/toggle_inventory/proc/showobjects()
	for (var/obj/screen/HUDelement in parentmob.HUDinventory)
		HUDelement.invisibility = FALSE
		hidden_inventory_update(HUDelement)
	for (var/obj/screen/HUDelement in parentmob.HUDfrippery)
		HUDelement.invisibility = FALSE

/obj/screen/toggle_inventory/Click()

	if (parentmob.inventory_shown)
		parentmob.inventory_shown = FALSE
		hideobjects()
	else
		parentmob.inventory_shown = TRUE
		showobjects()

	//parentmob.hud_used.hidden_inventory_update()
	return


/obj/screen/fov
	icon = 'icons/mob/hide.dmi'
	icon_state = "combat"
	name = " "
	screen_loc = "4,1"
	mouse_opacity = FALSE
	layer = 18
	process_flag = TRUE

/obj/screen/fov/process()
	update_icon()

/obj/screen/fov/update_icon()
	underlays.Cut()
	if (!config.disable_fov)
		if (istype(parentmob, /mob/living/human))
			var/mob/living/human/H = parentmob
			var/largest = 0
			for (var/obj/item/clothing/CM in H.contents)
				if (CM.restricts_view > largest && (H.wear_mask == CM || H.head == CM))
					largest = CM.restricts_view

			if (largest <= 0)
				global_hud.fov.icon_state = "combat"
			else if (largest == 1)
				global_hud.fov.icon_state = "helmet"
			else if (largest >= 2)
				global_hud.fov.icon_state = "narrow"
			else
				global_hud.fov.icon_state = "combat"

		underlays += global_hud.fov


/obj/screen/toggle_inventory/proc/hidden_inventory_update(obj/screen/inventory/inv_elem)
	var/mob/living/human/H = parentmob
	switch (inv_elem.slot_id)
		if (slot_head)
			if (H.head)	  H.head.screen_loc =	 (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_shoes)
			if (H.shoes)	 H.shoes.screen_loc =	 (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_l_ear)
			if (H.l_ear)	 H.l_ear.screen_loc =	 (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_r_ear)
			if (H.r_ear)	 H.r_ear.screen_loc =	 (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_gloves)
			if (H.gloves)	H.gloves.screen_loc =	(inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_w_uniform)
			if (H.w_uniform) H.w_uniform.screen_loc = (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_wear_suit)
			if (H.wear_suit) H.wear_suit.screen_loc = (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_wear_mask)
			if (H.wear_mask) H.wear_mask.screen_loc = (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
		if (slot_eyes)
			if (H.eyes)	  H.eyes.screen_loc =	  (inv_elem.invisibility == 101) ? null : inv_elem.screen_loc
