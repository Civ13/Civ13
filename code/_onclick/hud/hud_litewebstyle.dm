/datum/hud/human/litewebstyle
	name = "LiteWebStyle"
	icon = ui_hud_liteweb
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 5,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
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
		"health"	  = list("type" = /obj/screen/health,	 "loc" = ui_nutrition, "icon" = ui_hud_health_liteweb),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = ui_mood),
		"mood"  			 = list("type" = /obj/screen/mood,	   "loc" = ui_health),
		"body temperature"	= list("type" = /obj/screen/bodytemp,   "loc" = ui_body_temperature),
		"throw"	   = list("type" = /obj/screen/HUDthrow,   "loc" = ui_throw),
		"pull"		= list("type" = /obj/screen/pull,	   "loc" = ui_pull),
		"m_intent"	= list("type" = /obj/screen/mov_intent, "loc" = ui_m_intent),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,	   "loc" = ui_secondary_attack),
		"mode"		= list("type" = /obj/screen/mode,	   "loc" = ui_mode),
		"tactic"	  = list("type" = /obj/screen/tactic,	 "loc" = ui_tactic),
		"intent"	  = list("type" = /obj/screen/intent,	 "loc" = ui_disarm),
		"random damage zone" = list("type" = /obj/screen/zone_sel_random,   "loc" = ui_random_damage_zone),
		"damage zone" = list("type" = /obj/screen/zone_sel2,   "loc" = ui_damage_zone, "icon" = ui_hud_zone_sel_liteweb),
		"fixeye"	 = list("type" = /obj/screen/fixeye,	 "loc" = ui_fixeye),
		"toggle inventory"   = list("type" = /obj/screen/toggle_inventory,	   "loc" =ui_toggle_inventory),
		)

	slot_data = list (
		"i_clothing" =   list("loc" = ui_i_clothing,  "name" = "Clothing",		"state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =   list("loc" = ui_o_clothing,  "name" = "Suit",			"state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		 list("loc" = ui_mask,  "name" = "Mask",			"state" = "mask",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =	   list("loc" = ui_gloves,  "name" = "Gloves",		  "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = ui_l_ear,  "name" = "Left Ear",		"state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = ui_r_ear,  "name" = "Right Ear",	   "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		 list("loc" = ui_head,  "name" = "Hat",			 "state" = "hair",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =		list("loc" = ui_shoes,  "name" = "Shoes",		   "state" = "shoes",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		 list("loc" = ui_eyes,  "name" = "Eyes",			 "state" = "eyes", "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoulder" =	 list("loc" = ui_shoulder,  "name" = "Shoulder",		 "state" = "shoulder"),
		"storage1" =	 list("loc" = ui_storage1,  "name" = "Left Pocket",	 "state" = "pocket_l"),
		"storage2" =	 list("loc" = ui_storage2,  "name" = "Right Pocket",	"state" = "pocket_r"),
		"id" =		   list("loc" = ui_id,  "name" = "Pouch",		   "state" = "id",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"belt" =		 list("loc" = ui_belt,  "name" = "Belt",			"state" = "belt"),
		"back" =		 list("loc" = ui_back,  "name" = "Back",			"state" = "back"),
		"l_hand" =	   list("loc" = ui_l_hand,  "name" = "Left Hand",	   "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"r_hand" =	   list("loc" = ui_r_hand,  "name" = "Right Hand",	  "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()
