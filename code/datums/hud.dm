/datum/hud
	var/name
	var/list/HUDneed
//	var/list/HUDprocess = list()
	var/list/slot_data
	var/icon/icon = null
	var/list/HUDfrippery
	var/list/HUDoverlays
	var/list/ConteinerData
	// TRUE: every "loc" names its own screen edge (WEST/CENTER/EAST, SOUTH/NORTH) and
	// is used as written. FALSE: locs are tiles on the 15x15 design grid and
	// hud_layout.dm works out which edge each one follows.
	var/anchored_layout = FALSE

/datum/hud/human
	name = "NewStyle"
	icon = 'icons/mob/screen/1713Style.dmi'
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 3,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
		"screen_cover" = 	list("type" = /obj/screen/cover, "loc" = "-2,1", "icon" = 'icons/mob/screenlimit.dmi',"icon_state" = "cover"),
		"damageoverlay" = 	list("type" = /obj/screen/damageoverlay, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  			list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"pain" = 			list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"drugeffect" = 		list("type" = /obj/screen/drugoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = 			list("type" = /obj/screen/nvgoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = 		list("type" = /obj/screen/thermaloverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = 			list("type" = /obj/screen/fov, "loc" = "1,1", "icon_state" = "blank"),
		"gasmask" = 		list("type" = /obj/screen/gasmask, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "blank"),
		"aim_cross" =		list("type" = /obj/screen/aiming_cross,	"loc" = "1,1", "icon" = 'icons/mob/screen/aiming_cross.dmi', "icon_state" = "cross3"),
	)
	HUDneed = list(
		// right side
		"body temperature" = 	list("type" = /obj/screen/bodytemp,   "loc" = "16,14"),
		"mood" = 				list("type" = /obj/screen/mood,	   "loc" = "16,13"),
		"health" = 				list("type" = /obj/screen/health,	 "loc" = "16,12", "icon" = 'icons/mob/screen/healthdoll.dmi'),
		"nutrition" = 			list("type" = /obj/screen/nutrition,  "loc" = "16,11"),
		"random damage zone" = 	list("type" = /obj/screen/zone_sel_random,   "loc" = "16,10"),
		"damage zone" = 		list("type" = /obj/screen/zone_sel3,   "loc" = "16,8", "icon" = 'icons/mob/screen/zone_sel.dmi'),
		"fixeye" = 				list("type" = /obj/screen/fixeye,	 "loc" = "16,7"),
		"tactic" = 				list("type" = /obj/screen/tactic,	 "loc" = "16,6"),
		"mode" = 				list("type" = /obj/screen/mode,	   "loc" = "16,5"),
		"secondary attack" = 	list("type" = /obj/screen/kick_jump_bite,	   "loc" = "16,4"),
		"m_intent" = 			list("type" = /obj/screen/mov_intent, "loc" = "16,3"),
		"throw" = 				list("type" = /obj/screen/HUDthrow,   "loc" = "16,2"),
		"pull" = 				list("type" = /obj/screen/pull,	   "loc" = "16,2"),
		"drop" = 				list("type" = /obj/screen/drop,	   "loc" = "16,2"),
		"resist" = 				list("type" = /obj/screen/resist,	 "loc" = "16,2"),

		"intent" = 				list("type" = /obj/screen/intent,	 "loc" = "16,1"),
		// left side

		"toggle gun mode" = 	list("type" = /obj/screen/gun/mode,	   "loc" = "-2,6"),
		"allow movement" = 		list("type" = /obj/screen/gun/move,	   "loc" = "-2,7"),
		"allow item use" = 		list("type" = /obj/screen/gun/item,	   "loc" = "-1,7"),
		)

	slot_data = list (
		"i_clothing" =  list("loc" = "-1,4", 	"name" = "Clothing",		"state" = "center",  	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =  list("loc" = "-1,3", 	"name" = "Suit",			"state" = "equip",   	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		list("loc" = "0,4",  	"name" = "Mask",			"state" = "mask",		"hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =		list("loc" = "-2,4", 	"name" = "Gloves",			"state" = "gloves",  	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = "-2,5", 	"name" = "Left Ear",		"state" = "ears0",   	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = "0,5",  	"name" = "Right Ear",		"state" = "ears1",   	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		list("loc" = "-1,6", 	"name" = "Hat",				"state" = "hair",		"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =		list("loc" = "-2,3", 	"name" = "Shoes",			"state" = "shoes",		"hideflag" = TOGGLE_INVENTORY_FLAG),
		"id" =			list("loc" = "0,6",  	"name" = "Pouch",			"state" = "id",			"hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		list("loc" = "-1,5", 	"name" = "Eyes",			"state" = "eyes", 		"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoulder" =	list("loc" = "0,3",  	"name" = "Shoulder",		"state" = "shoulder"),
		"storage1" =	list("loc" = "-2,2", 	"name" = "Left Pocket",		"state" = "pocket_l"),
		"belt" =		list("loc" = "-1,2", 	"name" = "Belt",			"state" = "belt"),
		"storage2" =	list("loc" = "0,2",  	"name" = "Right Pocket",	"state" = "pocket_r"),

		"l_hand" =		list("loc" = "0,1",  	"name" = "Left Hand",		"state" = "hand-l", 	"type" = /obj/screen/inventory/hand),
		"back" =		list("loc" = "-1,1", 	"name" = "Back",			"state" = "back"),
		"r_hand" =		list("loc" = "-2,1", 	"name" = "Right Hand",		"state" = "hand-r", 	"type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()

/datum/hud/human/civstyle
	name = "1713Style"
	icon = 'icons/mob/screen/1713Style.dmi'
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 5,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
		"damageoverlay" = 	list("type" = /obj/screen/damageoverlay, 		"loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  			list("type" = /obj/screen/full_1_tile_overlay, 	"loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"pain" = 			list("type" = /obj/screen/full_1_tile_overlay, 	"loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"drugeffect" = 		list("type" = /obj/screen/drugoverlay, 			"loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = 			list("type" = /obj/screen/nvgoverlay, 			"loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = 		list("type" = /obj/screen/thermaloverlay, 		"loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = 			list("type" = /obj/screen/fov, 					"loc" = "1,1", "icon_state" = "blank"),
		"gasmask" = 		list("type" = /obj/screen/gasmask, 				"loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "blank"),
		"aim_cross" =		list("type" = /obj/screen/aiming_cross,			"loc" = "1,1", "icon" = 'icons/mob/screen/aiming_cross.dmi', "icon_state" = "cross3"),
	)
	HUDneed = list(
		"health" = 				list("type" = /obj/screen/health,	 "loc" = "15,7", "icon" = 'icons/mob/screen/healthdoll.dmi'),
		"nutrition" = 			list("type" = /obj/screen/nutrition,  "loc" = "15,6"),
		"mood" = 				list("type" = /obj/screen/mood,	   "loc" = "15,8"),
		"body temperature" = 	list("type" = /obj/screen/bodytemp,   "loc" = "15,9"),
		"throw" = 				list("type" = /obj/screen/HUDthrow,   "loc" = "14,2"),
		"pull" = 				list("type" = /obj/screen/pull,	   "loc" = "14,2"),
		"drop" = 				list("type" = /obj/screen/drop,	   "loc" = "14,2"),
		"resist" = 				list("type" = /obj/screen/resist,	 "loc" = "14,2"),
		"m_intent" = 			list("type" = /obj/screen/mov_intent, "loc" = "14,1"),
		"secondary attack" = 	list("type" = /obj/screen/kick_jump_bite,	   "loc" = "11,1"),
		"mode" = 				list("type" = /obj/screen/mode,	   "loc" = "10,1"),
		"tactic" = 				list("type" = /obj/screen/tactic,	 "loc" = "9,1"),
		"equip" = 				list("type" = /obj/screen/equip,	  "loc" = "7,2"),
		"intent" =				list("type" = /obj/screen/intent,	 "loc" = "12:16,1"),
		"help" = 				list("type" = /obj/screen/fastintent/help,	 "loc" = "12,1"),
		"disarm" = 				list("type" = /obj/screen/fastintent/disarm,   "loc" = "12,1"),
		"harm" = 				list("type" = /obj/screen/fastintent/harm,	 "loc" = "13,1"),
		"grab" = 				list("type" = /obj/screen/fastintent/grab,	 "loc" = "13,1"),
		"random damage zone" = 	list("type" = /obj/screen/zone_sel_random,   "loc" = "15,3"),
		"damage zone" = 		list("type" = /obj/screen/zone_sel3,   "loc" = "15,1", "icon" = 'icons/mob/screen/zone_sel.dmi'),
		"swap hand" = 			list("type" = /obj/screen/swap,	   "loc" = "7,2"),
		"fixeye" = 				list("type" = /obj/screen/fixeye,	 "loc" = "15,3:13"),
		"toggle gun mode" = 	list("type" = /obj/screen/gun/mode,	   "loc" = "4,2"),
		"allow movement" = 		list("type" = /obj/screen/gun/move,	   "loc" = "5,2"),
		"allow item use" = 		list("type" = /obj/screen/gun/item,	   "loc" = "6,2"),
		"toggle inventory" = 	list("type" = /obj/screen/toggle_inventory,	   "loc" = "1,1"),
		)

	slot_data = list (
		"i_clothing" =  list("loc" = "2,3",  "name" = "Clothing",		"state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =  list("loc" = "2,2",  "name" = "Suit",			"state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		list("loc" = "3,3",  "name" = "Mask",			"state" = "mask",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =	   	list("loc" = "1,3",  "name" = "Gloves",		  "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = "1,4",  "name" = "Left Ear",		"state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = "3,4",  "name" = "Right Ear",	   "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		list("loc" = "2,5",  "name" = "Hat",			 "state" = "hair",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =		list("loc" = "1,2",  "name" = "Shoes",		   "state" = "shoes",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		list("loc" = "2,4",  "name" = "Eyes",			 "state" = "eyes", "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoulder" =	list("loc" = "5,1",  "name" = "Shoulder",		 "state" = "shoulder"),
		"storage1" =	list("loc" = "2,1",  "name" = "Left Pocket",	 "state" = "pocket_l"),
		"storage2" =	list("loc" = "3,1",  "name" = "Right Pocket",	"state" = "pocket_r"),
		"id" =		   	list("loc" = "3,2",  "name" = "Pouch",		   "state" = "id",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"belt" =		list("loc" = "4,1",  "name" = "Belt",			"state" = "belt"),
		"back" =		list("loc" = "6,1",  "name" = "Back",			"state" = "back"),
		"l_hand" =	   	list("loc" = "8,1",  "name" = "Left Hand",	   "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"r_hand" =	   	list("loc" = "7,1",  "name" = "Right Hand",	  "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()



// Everything about your own character in one block at the bottom centre,
// actions in the bottom right corner, clothing in the bottom left.
// Icons are built from 1713Style by tools/hud-skin/build_console_style.py.
/datum/hud/human/consolestyle
	name = "ConsoleStyle"
	icon = 'icons/mob/screen/ConsoleStyle.dmi'
	anchored_layout = TRUE
	// Storage windows open on the row above the console.
	ConteinerData = list(
		"Xspace" = 4,
		"Yspace" = 3,
		"ColCount" = 7,
		"Xslot" = 4,
		"Yslot" = 3
	)

	HUDoverlays = list(
		"damageoverlay" = 	list("type" = /obj/screen/damageoverlay, 		"loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  			list("type" = /obj/screen/full_1_tile_overlay, 	"loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"pain" = 			list("type" = /obj/screen/full_1_tile_overlay, 	"loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"drugeffect" = 		list("type" = /obj/screen/drugoverlay, 			"loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = 			list("type" = /obj/screen/nvgoverlay, 			"loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = 		list("type" = /obj/screen/thermaloverlay, 		"loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = 			list("type" = /obj/screen/fov, 					"loc" = "1,1", "icon_state" = "blank"),
		"gasmask" = 		list("type" = /obj/screen/gasmask, 				"loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "blank"),
		"aim_cross" =		list("type" = /obj/screen/aiming_cross,			"loc" = "1,1", "icon" = 'icons/mob/screen/aiming_cross.dmi', "icon_state" = "cross3"),
	)
	HUDneed = list(
		// Centre console, upper row: how you are.
		"health" = 				list("type" = /obj/screen/health,	 "loc" = "CENTER-3,SOUTH+1:2", "icon" = 'icons/mob/screen/healthdoll_console.dmi'),
		"needs" = 				list("type" = /obj/screen/needs,	 "loc" = "CENTER-2,SOUTH+1:2", "icon" = 'icons/mob/screen/needs.dmi', "icon_state" = "needs"),
		"mood" = 				list("type" = /obj/screen/mood,	   "loc" = "CENTER+2,SOUTH+1:2"),
		"body temperature" = 	list("type" = /obj/screen/bodytemp,   "loc" = "CENTER+3,SOUTH+1:2"),
		// Hand controls, right above the hands.
		"equip" = 				list("type" = /obj/screen/equip,	  "loc" = "CENTER,SOUTH+1:2"),
		"swap hand" = 			list("type" = /obj/screen/swap,	   "loc" = "CENTER,SOUTH+1:2"),
		"drop" = 				list("type" = /obj/screen/drop,	   "loc" = "CENTER,SOUTH+1:17"),
		"throw" = 				list("type" = /obj/screen/HUDthrow,   "loc" = "CENTER:16,SOUTH+1:17"),
		"pull" = 				list("type" = /obj/screen/pull,	   "loc" = "CENTER+1,SOUTH+1:17"),
		"resist" = 				list("type" = /obj/screen/resist,	 "loc" = "CENTER+1:16,SOUTH+1:17"),
		// Action corner.
		"help" = 				list("type" = /obj/screen/fastintent/help,	 "loc" = "EAST-3,SOUTH:2"),
		"disarm" = 				list("type" = /obj/screen/fastintent/disarm,   "loc" = "EAST-3,SOUTH:2"),
		"intent" =				list("type" = /obj/screen/intent,	 "loc" = "EAST-3:16,SOUTH:2"),
		"harm" = 				list("type" = /obj/screen/fastintent/harm,	 "loc" = "EAST-2,SOUTH:2"),
		"grab" = 				list("type" = /obj/screen/fastintent/grab,	 "loc" = "EAST-2,SOUTH:2"),
		"m_intent" = 			list("type" = /obj/screen/mov_intent, "loc" = "EAST-1,SOUTH:2"),
		"damage zone" = 		list("type" = /obj/screen/zone_sel3,   "loc" = "EAST,SOUTH:2", "icon" = 'icons/mob/screen/zone_sel_console.dmi'),
		"tactic" = 				list("type" = /obj/screen/tactic,	 "loc" = "EAST-3,SOUTH+1:2"),
		"mode" = 				list("type" = /obj/screen/mode,	   "loc" = "EAST-2,SOUTH+1:2"),
		"secondary attack" = 	list("type" = /obj/screen/kick_jump_bite,	   "loc" = "EAST-1,SOUTH+1:2"),
		"random damage zone" = 	list("type" = /obj/screen/zone_sel_random,   "loc" = "EAST,SOUTH+2:2"),
		"fixeye" = 				list("type" = /obj/screen/fixeye,	 "loc" = "EAST,SOUTH+2:18"),
		"toggle gun mode" = 	list("type" = /obj/screen/gun/mode,	   "loc" = "EAST-3,SOUTH+2:2"),
		"allow movement" = 		list("type" = /obj/screen/gun/move,	   "loc" = "EAST-2,SOUTH+2:2"),
		"allow item use" = 		list("type" = /obj/screen/gun/item,	   "loc" = "EAST-1,SOUTH+2:2"),
		// Clothing corner.
		"toggle inventory" = 	list("type" = /obj/screen/toggle_inventory,	   "loc" = "WEST:2,SOUTH:2"),
		)

	slot_data = list (
		"shoes" =		list("loc" = "WEST+1:2,SOUTH:2",  "name" = "Shoes",		   "state" = "shoes",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"i_clothing" =  list("loc" = "WEST:2,SOUTH+1:2",  "name" = "Clothing",		"state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =  list("loc" = "WEST+1:2,SOUTH+1:2",  "name" = "Suit",			"state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =	   	list("loc" = "WEST+2:2,SOUTH+1:2",  "name" = "Gloves",		  "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		list("loc" = "WEST:2,SOUTH+2:2",  "name" = "Eyes",			 "state" = "eyes", "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		list("loc" = "WEST+1:2,SOUTH+2:2",  "name" = "Mask",			"state" = "mask",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"id" =		   	list("loc" = "WEST+2:2,SOUTH+2:2",  "name" = "Pouch",		   "state" = "id",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = "WEST:2,SOUTH+3:2",  "name" = "Left Ear",		"state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		list("loc" = "WEST+1:2,SOUTH+3:2",  "name" = "Hat",			 "state" = "hair",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = "WEST+2:2,SOUTH+3:2",  "name" = "Right Ear",	   "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		// Centre console, lower row: what you carry.
		"shoulder" =	list("loc" = "CENTER-3,SOUTH:2",  "name" = "Shoulder",		 "state" = "shoulder"),
		"back" =		list("loc" = "CENTER-2,SOUTH:2",  "name" = "Back",			"state" = "back"),
		"belt" =		list("loc" = "CENTER-1,SOUTH:2",  "name" = "Belt",			"state" = "belt"),
		"r_hand" =	   	list("loc" = "CENTER,SOUTH:2",  "name" = "Right Hand",	  "state" = "hand-r", "type" = /obj/screen/inventory/hand),
		"l_hand" =	   	list("loc" = "CENTER+1,SOUTH:2",  "name" = "Left Hand",	   "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"storage1" =	list("loc" = "CENTER+2,SOUTH:2",  "name" = "Left Pocket",	 "state" = "pocket_l"),
		"storage2" =	list("loc" = "CENTER+3,SOUTH:2",  "name" = "Right Pocket",	"state" = "pocket_r")
		)

	HUDfrippery = list()



/datum/hud/human/litewebstyle
	name = "LiteWebStyle"
	icon = 'icons/mob/screen/litewebStyle.dmi'
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 5,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
		"damageoverlay" = list("type" = /obj/screen/damageoverlay, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"pain" = list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"drugeffect" = list("type" = /obj/screen/drugoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = list("type" = /obj/screen/nvgoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = list("type" = /obj/screen/thermaloverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = list("type" = /obj/screen/fov, "loc" = "1,1", "icon_state" = "blank"),
		"gasmask" = list("type" = /obj/screen/gasmask, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "blank"),
		"aim_cross" =		list("type" = /obj/screen/aiming_cross,	"loc" = "1,1", "icon" = 'icons/mob/screen/aiming_cross.dmi', "icon_state" = "cross3"),
	)
	HUDneed = list(
		"health"	  = list("type" = /obj/screen/health,	 "loc" = "15,6", "icon" = 'icons/mob/screen/healthdoll_lw.dmi'),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = "15,8"),
		"mood"  			 = list("type" = /obj/screen/mood,	   "loc" = "15,7"),
		"body temperature"	= list("type" = /obj/screen/bodytemp,   "loc" = "15,9"),
		"throw"	   = list("type" = /obj/screen/HUDthrow,   "loc" = "13,1"),
		"pull"		= list("type" = /obj/screen/pull,	   "loc" = "13,1"),
		"m_intent"	= list("type" = /obj/screen/mov_intent, "loc" = "14,1"),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,	   "loc" = "11,1"),
		"mode"		= list("type" = /obj/screen/mode,	   "loc" = "10,1"),
		"tactic"	  = list("type" = /obj/screen/tactic,	 "loc" = "9,1"),
		"intent"	  = list("type" = /obj/screen/intent,	 "loc" = "12,1"),
		"random damage zone" = list("type" = /obj/screen/zone_sel_random,   "loc" = "15,3"),
		"damage zone" = list("type" = /obj/screen/zone_sel2,   "loc" = "15,1", "icon" = 'icons/mob/screen/zone_sel_lw.dmi'),
		"fixeye"	 = list("type" = /obj/screen/fixeye,	 "loc" = "15,3:9"),
		"toggle gun mode"   = list("type" = /obj/screen/gun/mode,	   "loc" = "4,2"),
		"allow movement"	= list("type" = /obj/screen/gun/move,	   "loc" = "5,2"),
		"allow item use" 	 = list("type" = /obj/screen/gun/item,	   "loc" = "6,2"),
		"toggle inventory"   = list("type" = /obj/screen/toggle_inventory,	   "loc" = "1,1"),
		)

	slot_data = list (
		"i_clothing" =  list("loc" = "2,3",  "name" = "Clothing",		"state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =  list("loc" = "2,2",  "name" = "Suit",			"state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		list("loc" = "3,3",  "name" = "Mask",			"state" = "mask",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =	   	list("loc" = "1,3",  "name" = "Gloves",		  	"state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = "1,4",  "name" = "Left Ear",		"state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = "3,4",  "name" = "Right Ear",	   	"state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		list("loc" = "2,5",  "name" = "Hat",			"state" = "hair",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =		list("loc" = "1,2",  "name" = "Shoes",		   	"state" = "shoes",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		list("loc" = "2,4",  "name" = "Eyes",			"state" = "eyes", "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoulder" =	list("loc" = "5,1",  "name" = "Shoulder",		"state" = "shoulder"),
		"storage1" =	list("loc" = "2,1",  "name" = "Left Pocket",	"state" = "pocket_l"),
		"storage2" =	list("loc" = "3,1",  "name" = "Right Pocket",	"state" = "pocket_r"),
		"id" =			list("loc" = "3,2",  "name" = "Pouch",		   	"state" = "id",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"belt" =		list("loc" = "4,1",  "name" = "Belt",			"state" = "belt"),
		"back" =		list("loc" = "6,1",  "name" = "Back",			"state" = "back"),
		"l_hand" =		list("loc" = "8,1",  "name" = "Left Hand",	  	"state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"r_hand" =		list("loc" = "7,1",  "name" = "Right Hand",	  	"state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()


/datum/hud/human/fofstyle
	name = "FoFStyle"
	icon = 'icons/mob/screen/FoFStyle.dmi'
	ConteinerData = list(
		"Xspace" = 2,
		"Yspace" = 5,
		"ColCount" = 7,
		"Xslot" = 5,
		"Yslot" = 2
	)

	HUDoverlays = list(
		"damageoverlay" = list("type" = /obj/screen/damageoverlay, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi'),
		"flash" =  list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"pain" = list("type" = /obj/screen/full_1_tile_overlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon" = 'icons/mob/screen/effects.dmi', "icon_state" = "blank"),
		"drugeffect" = list("type" = /obj/screen/drugoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"nvg" = list("type" = /obj/screen/nvgoverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"thermal" = list("type" = /obj/screen/thermaloverlay, "loc" = "WEST,SOUTH to EAST,NORTH", "icon_state" = "blank"),
		"fov" = list("type" = /obj/screen/fov, "loc" = "1,1", "icon_state" = "blank"),
		"gasmask" = list("type" = /obj/screen/gasmask, "loc" = "1,1", "icon" = 'icons/mob/screen1_full.dmi', "icon_state" = "blank"),
		"aim_cross" =		list("type" = /obj/screen/aiming_cross,	"loc" = "1,1", "icon" = 'icons/mob/screen/aiming_cross.dmi', "icon_state" = "cross3"),
	)
	HUDneed = list(
		"health"	  = list("type" = /obj/screen/health,	 "loc" = "15,7", "icon" = 'icons/mob/screen/healthdoll_fof.dmi'),
		"nutrition"   = list("type" = /obj/screen/nutrition,  "loc" = "15,6"),
		"mood"  			 = list("type" = /obj/screen/mood,	   "loc" = "15,8"),
		"body temperature"	= list("type" = /obj/screen/bodytemp,   "loc" = "15,9"),
		"throw"	   = list("type" = /obj/screen/HUDthrow,   "loc" = "12,1"),
		"pull"		= list("type" = /obj/screen/pull,	   "loc" = "12,1"),
		"m_intent"	= list("type" = /obj/screen/mov_intent, "loc" = "14,1"),
		"secondary attack"   = list("type" = /obj/screen/kick_jump_bite,	   "loc" = "11,1"),
		"mode"		= list("type" = /obj/screen/mode,	   "loc" = "10,1"),
		"tactic"	  = list("type" = /obj/screen/tactic,	 "loc" = "9,1"),
		"intent"	  = list("type" = /obj/screen/intent,	 "loc" = "13,1"),
		"random damage zone" = list("type" = /obj/screen/zone_sel_random,   "loc" = "15,3"),
		"damage zone" = list("type" = /obj/screen/zone_sel3,   "loc" = "15,1", "icon" = 'icons/mob/screen/zone_sel_fof.dmi'),
		"fixeye"	 = list("type" = /obj/screen/fixeye,	 "loc" = "15,3"),
		"toggle gun mode"   = list("type" = /obj/screen/gun/mode,	   "loc" = "4,2"),
		"allow movement"	= list("type" = /obj/screen/gun/move,	   "loc" = "5,2"),
		"allow item use" 	 = list("type" = /obj/screen/gun/item,	   "loc" = "6,2"),
		"toggle inventory"   = list("type" = /obj/screen/toggle_inventory,	   "loc" = "1,1"),
		)

	slot_data = list (
		"i_clothing" =   list("loc" = "2,3",  "name" = "Clothing",		"state" = "center",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"o_clothing" =   list("loc" = "2,2",  "name" = "Suit",			"state" = "equip",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"mask" =		 list("loc" = "3,3",  "name" = "Mask",			"state" = "mask",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"gloves" =	   list("loc" = "1,3",  "name" = "Gloves",		  "state" = "gloves",  "hideflag" = TOGGLE_INVENTORY_FLAG),
		"l_ear" =		list("loc" = "1,4",  "name" = "Left Ear",		"state" = "ears0",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"r_ear" =		list("loc" = "3,4",  "name" = "Right Ear",	   "state" = "ears1",   "hideflag" = TOGGLE_INVENTORY_FLAG),
		"head" =		 list("loc" = "2,5",  "name" = "Hat",			 "state" = "hair",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoes" =		list("loc" = "1,2",  "name" = "Shoes",		   "state" = "shoes",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"eyes" =		 list("loc" = "2,4",  "name" = "Eyes",			 "state" = "eyes", "hideflag" = TOGGLE_INVENTORY_FLAG),
		"shoulder" =	 list("loc" = "5,1",  "name" = "Shoulder",		 "state" = "shoulder"),
		"storage1" =	 list("loc" = "2,1",  "name" = "Left Pocket",	 "state" = "pocket_l"),
		"storage2" =	 list("loc" = "3,1",  "name" = "Right Pocket",	"state" = "pocket_r"),
		"id" =		   list("loc" = "3,2",  "name" = "Pouch",		   "state" = "id",	"hideflag" = TOGGLE_INVENTORY_FLAG),
		"belt" =		 list("loc" = "4,1",  "name" = "Belt",			"state" = "belt"),
		"back" =		 list("loc" = "6,1",  "name" = "Back",			"state" = "back"),
		"l_hand" =	   list("loc" = "8,1",  "name" = "Left Hand",	   "state" = "hand-l", "type" = /obj/screen/inventory/hand),
		"r_hand" =	   list("loc" = "7,1",  "name" = "Right Hand",	  "state" = "hand-r", "type" = /obj/screen/inventory/hand)
		)

	HUDfrippery = list()
