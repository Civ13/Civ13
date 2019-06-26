/datum/hud
	var/name
	var/list/HUDneed//для "активных" элементов (прим. здоровье)
//	var/list/HUDprocess = list()
	var/list/slot_data//для инвентаря
	var/icon/icon = null
	var/list/HUDfrippery
	var/list/HUDoverlays
//	var/Xbags
//	var/Ybags
	var/list/ConteinerData

/datum/hud/human
	name = "NewStyle"
	icon = 'icons/mob/screen/1713Style.dmi'
	//Xbags,Ybags for space_orient_objs
	//Others for slot_orient_objs
	ConteinerData = list(
		"Xspace" = 5,
		"Yspace" = 1,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 1
	)

	HUDoverlays = list(
		"screen_cover" = list("type" = /obj/screen/cover, "loc" = "1,1", "icon" = 'icons/mob/screenlimit.dmi',"icon_state" = "cover"),
		"damageoverlay" = list("type" = /obj/screen/damageoverlay, "loc" = "4,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"pain" = list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"drugeffect" = list("type" = /obj/screen/drugoverlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = list("type" = /obj/screen/nvgoverlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = list("type" = /obj/screen/thermaloverlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = list("type" = /obj/screen/fov, "loc" = "4,1", "icon_state" = "blank"),

//		"fishbed" = list("type" = /obj/screen/fishbed, "loc" = "4,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "fishbed"),
//		"noise" = list("type" = /obj/screen/noise, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/effects/static.dmi', "icon_state" = "1 light"),
	)
	HUDneed = list(
		// right side
		"body temperature"    = list("type" = /obj/screen/bodytemp,   "loc" = "19,14"),
		"mood"  			 = list("type" = /obj/screen/mood,       "loc" = "19,13"),
		"health"      = list("type" = /obj/screen/health,     "loc" = "19,12", "icon" = 'icons/mob/screen/healthdoll.dmi'),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = "19,11"),
		"damage zone" = list("type" = /obj/screen/zone_sel,   "loc" = "19,9"),
		"fixeye"     = list("type" = /obj/screen/fixeye,     "loc" = "19,8"),
		"tactic"      = list("type" = /obj/screen/tactic,     "loc" = "19,7"),
		"mode"        = list("type" = /obj/screen/mode,       "loc" = "19,6"),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,       "loc" = "19,5"),
		"m_intent"    = list("type" = /obj/screen/mov_intent, "loc" = "19,3"),
		"throw"       = list("type" = /obj/screen/HUDthrow,   "loc" = "19,2"),
		"pull"        = list("type" = /obj/screen/pull,       "loc" = "19,2"),
		"drop"        = list("type" = /obj/screen/drop,       "loc" = "19,2"),
		"resist"      = list("type" = /obj/screen/resist,     "loc" = "19,2"),
/*		"help"        = list("type" = /obj/screen/fastintent/help,     "loc" = "19,2"),
		"disarm"      = list("type" = /obj/screen/fastintent/disarm,   "loc" = "19,2"),
		"harm"        = list("type" = /obj/screen/fastintent/harm,     "loc" = "19,2"),
		"grab"        = list("type" = /obj/screen/fastintent/grab,     "loc" = "19,2"),*/
		"intent"      = list("type" = /obj/screen/intent,     "loc" = "19,1"),
		// left side
//		"equip"       = list("type" = /obj/screen/equip,      "loc" = "7,2"),
//		"swap hand"   = list("type" = /obj/screen/swap,       "loc" = "7,2"),
		"toggle gun mode"   = list("type" = /obj/screen/gun/mode,       "loc" = "1,6"),
		"allow movement"	= list("type" = /obj/screen/gun/move,       "loc" = "2,6"),
		"allow item use" 	 = list("type" = /obj/screen/gun/item,       "loc" = "3,6"),
//		"toggle inventory"   = list("type" = /obj/screen/toggle_inventory,       "loc" = "1,1")
		)

	slot_data = list (
		"i_clothing" =   list("loc" = "2,4",  "name" = "Clothing",        "state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =   list("loc" = "2,3",  "name" = "Suit",            "state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =         list("loc" = "3,4",  "name" = "Mask",            "state" = "mask",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =       list("loc" = "1,4",  "name" = "Gloves",          "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =        list("loc" = "1,5",  "name" = "Left Ear",        "state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =        list("loc" = "3,5",  "name" = "Right Ear",       "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =         list("loc" = "2,5",  "name" = "Hat",             "state" = "hair",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =        list("loc" = "1,3",  "name" = "Shoes",           "state" = "shoes",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"id" =           list("loc" = "3,3",  "name" = "Pouch",           "state" = "id",    "hideflag" = TOGGLE_INVENTORY_FLAG),

		"storage1" =     list("loc" = "1,2",  "name" = "Left Pocket",     "state" = "pocket_l"),
		"belt" =         list("loc" = "2,2",  "name" = "Belt",            "state" = "belt"),
		"storage2" =     list("loc" = "3,2",  "name" = "Right Pocket",    "state" = "pocket_r"),

		"l_hand" =       list("loc" = "1,1",  "name" = "Left Hand",       "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"back" =         list("loc" = "2,1",  "name" = "Back",            "state" = "back"),
		"r_hand" =       list("loc" = "3,1",  "name" = "Right Hand",      "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()

/datum/hud/human/civstyle
	name = "1713Style"
	icon = 'icons/mob/screen/1713Style.dmi'
	//Xbags,Ybags for space_orient_objs
	//Others for slot_orient_objs
	ConteinerData = list(
		"Xspace" = 5,
		"Yspace" = 1,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 1
	)

	HUDoverlays = list(
		"screen_cover" = list("type" = /obj/screen/cover, "loc" = "1,1", "icon" = 'icons/mob/screenlimit.dmi',"icon_state" = "cover"),
		"damageoverlay" = list("type" = /obj/screen/damageoverlay, "loc" = "4,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"pain" = list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"drugeffect" = list("type" = /obj/screen/drugoverlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = list("type" = /obj/screen/nvgoverlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = list("type" = /obj/screen/thermaloverlay, "loc" = "WEST+3,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = list("type" = /obj/screen/fov, "loc" = "4,1", "icon_state" = "blank"),

//		"fishbed" = list("type" = /obj/screen/fishbed, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "fishbed"),
//		"noise" = list("type" = /obj/screen/noise, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/effects/static.dmi', "icon_state" = "1 moderate"),
	)
	HUDneed = list(
		"health"      = list("type" = /obj/screen/health,     "loc" = "18,7", "icon" = 'icons/mob/screen/healthdoll.dmi'),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = "18,6"),
		"mood"  			 = list("type" = /obj/screen/mood,       "loc" = "18,8"),
		"body temperature"    = list("type" = /obj/screen/bodytemp,   "loc" = "18,9"),
		"throw"       = list("type" = /obj/screen/HUDthrow,   "loc" = "17,2"),
		"pull"        = list("type" = /obj/screen/pull,       "loc" = "17,2"),
		"drop"        = list("type" = /obj/screen/drop,       "loc" = "17,2"),
		"resist"      = list("type" = /obj/screen/resist,     "loc" = "17,2"),
		"m_intent"    = list("type" = /obj/screen/mov_intent, "loc" = "17,1"),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,       "loc" = "14,1"),
		"mode"        = list("type" = /obj/screen/mode,       "loc" = "13,1"),
		"tactic"      = list("type" = /obj/screen/tactic,     "loc" = "12,1"),
		"equip"       = list("type" = /obj/screen/equip,      "loc" = "10,2"),
		"intent"      = list("type" = /obj/screen/intent,     "loc" = "15:16,1"),
		"help"        = list("type" = /obj/screen/fastintent/help,     "loc" = "15,1"),
		"disarm"      = list("type" = /obj/screen/fastintent/disarm,   "loc" = "15,1"),
		"harm"        = list("type" = /obj/screen/fastintent/harm,     "loc" = "16,1"),
		"grab"        = list("type" = /obj/screen/fastintent/grab,     "loc" = "16,1"),
		"damage zone" = list("type" = /obj/screen/zone_sel,   "loc" = "18,1"),
		"swap hand"   = list("type" = /obj/screen/swap,       "loc" = "10,2"),
		"fixeye"     = list("type" = /obj/screen/fixeye,     "loc" = "18,2"),
		"toggle gun mode"   = list("type" = /obj/screen/gun/mode,       "loc" = "7,1"),
		"allow movement"	= list("type" = /obj/screen/gun/move,       "loc" = "7,2"),
		"allow item use" 	 = list("type" = /obj/screen/gun/item,       "loc" = "8,2"),
		"toggle inventory"   = list("type" = /obj/screen/toggle_inventory,       "loc" = "4,1"),
		)

	slot_data = list (
		"i_clothing" =   list("loc" = "5,3",  "name" = "Clothing",        "state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =   list("loc" = "5,2",  "name" = "Suit",            "state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =         list("loc" = "6,3",  "name" = "Mask",            "state" = "mask",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =       list("loc" = "4,3",  "name" = "Gloves",          "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =        list("loc" = "4,4",  "name" = "Left Ear",        "state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =        list("loc" = "6,4",  "name" = "Right Ear",       "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =         list("loc" = "5,4",  "name" = "Hat",             "state" = "hair",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =        list("loc" = "4,2",  "name" = "Shoes",           "state" = "shoes",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"storage1" =     list("loc" = "5,1",  "name" = "Left Pocket",     "state" = "pocket_l"),
		"storage2" =     list("loc" = "6,1",  "name" = "Right Pocket",    "state" = "pocket_r"),
		"id" =           list("loc" = "6,2",  "name" = "Pouch",           "state" = "id",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"belt" =         list("loc" = "8,1",  "name" = "Belt",            "state" = "belt"),
		"back" =         list("loc" = "9,1",  "name" = "Back",            "state" = "back"),
		"l_hand" =       list("loc" = "10,1",  "name" = "Left Hand",       "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"r_hand" =       list("loc" = "11,1",  "name" = "Right Hand",      "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()