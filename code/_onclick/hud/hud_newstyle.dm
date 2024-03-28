/datum/hud/human
	name = "NewStyle"
	icon = ui_hud_1713
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 3,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
		"screen_cover" = list("type" = /obj/screen/cover, "loc" = ui_screen_cover, "icon" = 'icons/mob/screenlimit.dmi',"icon_state" = "cover"),
		"damageoverlay" = list("type" = /obj/screen/damageoverlay, "loc" = ui_damageoverlay, "icon" = ui_hud_overlay),
		"flash" =  list("type" = /obj/screen/full_1_tile_overlay, "loc" = ui_flash, "icon" = ui_hud_effects, "icon_state" = ui_blank),
		"pain" = list("type" = /obj/screen/full_1_tile_overlay, "loc" = ui_pain, "icon" = ui_hud_effects, "icon_state" = ui_blank),
		"drugeffect" = list("type" = /obj/screen/drugoverlay, "loc" = ui_drugeffect, "icon_state" = ui_blank),
		"nvg" = list("type" = /obj/screen/nvgoverlay, "loc" = ui_nvg, "icon_state" = ui_blank),
		"thermal" = list("type" = /obj/screen/thermaloverlay, "loc" = ui_thermal, "icon_state" = ui_blank),
		"fov" = list("type" = /obj/screen/fov, "loc" = ui_fov, "icon_state" = ui_blank),
		"gasmask" = list("type" = /obj/screen/gasmask, "loc" = ui_gasmask, "icon" = ui_hud_overlay, "icon_state" = ui_blank),

	)
	HUDneed = list(
		// right side
		"body temperature"	= list("type" = /obj/screen/bodytemp,   "loc" = "16,14"),
		"mood"  			 = list("type" = /obj/screen/mood,	   "loc" = "16,13"),
		"health"	  = list("type" = /obj/screen/health,	 "loc" = "16,12", "icon" = ui_hud_health_1713),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = "16,11"),
		"random damage zone" = list("type" = /obj/screen/zone_sel_random,   "loc" = "16,10"),
		"damage zone" = list("type" = /obj/screen/zone_sel3,   "loc" = "16,8", "icon" = ui_hud_zone_sel_1713),
		"fixeye"	 = list("type" = /obj/screen/fixeye,	 "loc" = "16,7"),
		"tactic"	  = list("type" = /obj/screen/tactic,	 "loc" = "16,6"),
		"mode"		= list("type" = /obj/screen/mode,	   "loc" = "16,5"),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,	   "loc" = "16,4"),
		"m_intent"	= list("type" = /obj/screen/mov_intent, "loc" = "16,3"),
		"throw"	   = list("type" = /obj/screen/HUDthrow,   "loc" = "16,2"),
		"pull"		= list("type" = /obj/screen/pull,	   "loc" = "16,2"),
		"drop"		= list("type" = /obj/screen/drop,	   "loc" = "16,2"),
		"resist"	  = list("type" = /obj/screen/resist,	 "loc" = "16,2"),
		"intent"	  = list("type" = /obj/screen/intent,	 "loc" = "16,1"),
		)

	slot_data = list (
		"i_clothing" =   list("loc" = "-1,4",  "name" = "Clothing",		"state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =   list("loc" = "-1,3",  "name" = "Suit",			"state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		 list("loc" = "0,4",  "name" = "Mask",			 "state" = "mask",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =	   list("loc" = "-2,4",  "name" = "Gloves",		  "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = "-2,5",  "name" = "Left Ear",		"state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = "0,5",  "name" = "Right Ear",		"state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		 list("loc" = "-1,6",  "name" = "Hat",			 "state" = "hair",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =		list("loc" = "-2,3",  "name" = "Shoes",		   "state" = "shoes",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"id" =		   list("loc" = "0,6",  "name" = "Pouch",			"state" = "id",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		 list("loc" = "-1,5",  "name" = "Eyes",			 "state" = "eyes", "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoulder" =	 list("loc" = "0,3",  "name" = "Shoulder",		 "state" = "shoulder"),
		"storage1" =	 list("loc" = "-2,2",  "name" = "Left Pocket",	 "state" = "pocket_l"),
		"belt" =		 list("loc" = "-1,2",  "name" = "Belt",			"state" = "belt"),
		"storage2" =	 list("loc" = "0,2",  "name" = "Right Pocket",	 "state" = "pocket_r"),

		"l_hand" =	   list("loc" = "0,1",  "name" = "Left Hand",		"state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"back" =		 list("loc" = "-1,1",  "name" = "Back",			"state" = "back"),
		"r_hand" =	   list("loc" = "-2,1",  "name" = "Right Hand",	  "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()
