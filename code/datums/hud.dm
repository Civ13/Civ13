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
	name = "1713Style"
	icon = 'icons/mob/screen/1713Style.dmi'
	//Xbags,Ybags for space_orient_objs
	//Others for slot_orient_objs
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 5,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
		"damageoverlay" = list("type" = /obj/screen/damageoverlay, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"pain" = list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"drugeffect" = list("type" = /obj/screen/drugoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = list("type" = /obj/screen/nvgoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = list("type" = /obj/screen/thermaloverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov"		  = list("type" = /obj/screen/fov,		  "loc" = "1,1", "icon_state" = "blank"),
	)
	HUDneed = list(
		"health"      = list("type" = /obj/screen/health,     "loc" = "15,7", "icon" = 'icons/mob/screen/healthdoll.dmi'),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = "15,6"),
		"mood"  			 = list("type" = /obj/screen/mood,       "loc" = "15,8"),
		"body temperature"    = list("type" = /obj/screen/bodytemp,   "loc" = "15,9"),
		"throw"       = list("type" = /obj/screen/HUDthrow,   "loc" = "9,1"),
		"pull"        = list("type" = /obj/screen/pull,       "loc" = "10,1"),
		"drop"        = list("type" = /obj/screen/drop,       "loc" = "9,1"),
		"resist"      = list("type" = /obj/screen/resist,     "loc" = "10,1"),
		"m_intent"    = list("type" = /obj/screen/mov_intent, "loc" = "14,1"),
		"mode"        = list("type" = /obj/screen/mode,       "loc" = "11,1"),
		"equip"       = list("type" = /obj/screen/equip,      "loc" = "7,2"),
		"intent"      = list("type" = /obj/screen/intent,     "loc" = "12:16,1"),
		"help"        = list("type" = /obj/screen/fastintent/help,     "loc" = "12,1"),
		"disarm"      = list("type" = /obj/screen/fastintent/disarm,   "loc" = "12,1"),
		"harm"        = list("type" = /obj/screen/fastintent/harm,     "loc" = "13,1"),
		"grab"        = list("type" = /obj/screen/fastintent/grab,     "loc" = "13,1"),
		"damage zone" = list("type" = /obj/screen/zone_sel,   "loc" = "15,1"),
		"swap hand"   = list("type" = /obj/screen/swap,       "loc" = "7,2"),
		"toggle gun mode"   = list("type" = /obj/screen/gun/mode,       "loc" = "4,1"),
		"allow movement"	= list("type" = /obj/screen/gun/move,       "loc" = "4,2"),
		"allow item use" 	 = list("type" = /obj/screen/gun/item,       "loc" = "5,2"),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,       "loc" = "11,2"),
		"toggle inventory"   = list("type" = /obj/screen/toggle_inventory,       "loc" = "1,1")
		)

	slot_data = list (
		"i_clothing" =   list("loc" = "2,3",  "name" = "Clothing",        "state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =   list("loc" = "2,2",  "name" = "Suit",            "state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =         list("loc" = "3,3",  "name" = "Mask",            "state" = "mask",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =       list("loc" = "1,3",  "name" = "Gloves",          "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =        list("loc" = "1,4",  "name" = "Left Ear",        "state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =        list("loc" = "3,4",  "name" = "Right Ear",       "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =         list("loc" = "2,4",  "name" = "Hat",             "state" = "hair",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =        list("loc" = "1,2",  "name" = "Shoes",           "state" = "shoes",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"storage1" =     list("loc" = "2,1",  "name" = "Left Pocket",     "state" = "pocket_l"),
		"storage2" =     list("loc" = "3,1",  "name" = "Right Pocket",    "state" = "pocket_r"),
		"id" =           list("loc" = "3,2",  "name" = "Pouch",           "state" = "id",    "hideflag" = TOGGLE_INVENTORY_FLAG),
		"belt" =         list("loc" = "5,1",  "name" = "Belt",            "state" = "belt"),
		"back" =         list("loc" = "6,1",  "name" = "Back",            "state" = "back"),
		"l_hand" =       list("loc" = "7,1",  "name" = "Left Hand",       "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"r_hand" =       list("loc" = "8,1",  "name" = "Right Hand",      "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()