// Crossroads Mall: an original shopping-centre raid at a highway interchange.
// It reuses the EFT Factory firefight mode (USEC, BEAR and Scavs with timed
// extraction zones) and doubles as a loot-table and mechanics test map.
// The map is never part of any vote rotation; select it by name like Factory.

/obj/map_metadata/eft_factory/crossroads_mall
	ID = MAP_CROSSROADS_MALL
	title = "Crossroads Mall"
	battle_name = "Raid on Crossroads Mall"
	mission_start_message = "<font size=4>Contractors and scavengers converge on the abandoned Crossroads Mall and its interchange. Loot the stores, hold the keyed rooms and reach an extraction point. You have <b>2 minutes</b> to prepare.</font>"
	description = "A looted shopping centre at a highway interchange: parking lots, anchor stores, a supermarket, keyed back rooms and four extraction points. The fenced north range is a loot-table test area."

/area/caribbean/crossroads_mall
	name = "Crossroads Mall"
	dynamic_lighting = FALSE
	luminosity = TRUE

/area/caribbean/crossroads_mall/range
	name = "Crossroads loot test range"

/area/caribbean/extract/crossroads
	name = "Crossroads extraction"

/area/caribbean/extract/crossroads/westbound
	name = "Westbound shoulder extraction"

/area/caribbean/extract/crossroads/northbound
	name = "Northbound ramp extraction"

/area/caribbean/extract/crossroads/delivery
	name = "Delivery gate extraction"

/area/caribbean/extract/crossroads/culvert
	name = "Storm culvert extraction"

/area/caribbean/extract/crossroads/range
	name = "Range extraction test"

///////////////////////////////Signs//////////////////////////////////////////////

/obj/structure/sign/crossroads
	name = "mall sign"
	desc = "A weathered sign. Its name tells you where you are."
	icon_state = "customsign"

/obj/structure/sign/crossroads/store
	icon_state = "customsign2"

/obj/structure/sign/crossroads/extract
	name = "extraction point"
	desc = "Stand inside the marked zone for ten seconds to extract."
	icon_state = "exit"

/obj/structure/sign/crossroads/pharmacy
	icon_state = "greencross"

/obj/structure/sign/crossroads/hardware
	icon_state = "repair"

/obj/structure/sign/crossroads/food
	icon_state = "sale"

/obj/structure/sign/crossroads/secure
	icon_state = "securearea"

/obj/structure/sign/crossroads/warning
	icon_state = "minefield"

/obj/structure/sign/crossroads/range
	name = "loot test range"
	desc = "Each pad rolls one loot table. Admins reroll every pad with the Special tab verbs."
	icon_state = "securearea"

///////////////////////////////Keys//////////////////////////////////////////////

// Each keyed room has its own keyslot so a key opens exactly one lock.
/datum/keyslot/crossroads/security
	code = 73101
/datum/keyslot/crossroads/management
	code = 73102
/datum/keyslot/crossroads/cage
	code = 73103
/datum/keyslot/crossroads/range
	code = 73104
/datum/keyslot/crossroads/test
	code = 73105

/obj/item/weapon/key/modern/crossroads
	name = "mall key"
/obj/item/weapon/key/modern/crossroads/security
	name = "Security office key"
	code = 73101
/obj/item/weapon/key/modern/crossroads/management
	name = "Management suite key"
	code = 73102
/obj/item/weapon/key/modern/crossroads/cage
	name = "Ironbark stock cage key"
	code = 73103
/obj/item/weapon/key/modern/crossroads/range
	name = "Loot range gate key"
	code = 73104
/obj/item/weapon/key/modern/crossroads/test
	name = "Range test door key"
	code = 73105

///////////////////////////////Doors//////////////////////////////////////////////

/obj/structure/simple_door/key_door/crossroads
	name = "locked door"
	material = "iron"
	keyslot_type = /datum/keyslot/crossroads/security
/obj/structure/simple_door/key_door/crossroads/security
	unique_door_name = "Security office"
	keyslot_type = /datum/keyslot/crossroads/security
/obj/structure/simple_door/key_door/crossroads/management
	unique_door_name = "Management suite"
	keyslot_type = /datum/keyslot/crossroads/management
/obj/structure/simple_door/key_door/crossroads/cage
	unique_door_name = "Ironbark stock cage"
	keyslot_type = /datum/keyslot/crossroads/cage
/obj/structure/simple_door/key_door/crossroads/range
	unique_door_name = "Loot range gate"
	breachable = FALSE
	keyslot_type = /datum/keyslot/crossroads/range
/obj/structure/simple_door/key_door/crossroads/test
	unique_door_name = "Range test"
	keyslot_type = /datum/keyslot/crossroads/test

// Range doors are not meant to be kicked or shot open; the range is not loot.
/obj/structure/simple_door/key_door/crossroads/range/door_takes_kick_damage()
	return FALSE
/obj/structure/simple_door/key_door/crossroads/range/update_damage(amt)
	return

///////////////////////////////Loot pads//////////////////////////////////////////////

var/list/crossroads_loot_pads = list()

// One pad rolls one loot table on its own tile. It keeps what it spawned so an
// admin reroll replaces the previous roll instead of piling items up.
/obj/effect/crossroads_loot_pad
	name = "loot pad"
	desc = "Rolls one loot table onto this tile."
	icon = 'icons/misc/mark.dmi'
	icon_state = "dice"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.9
	var/table = ""
	var/tmp/list/spawned = list()
	var/tmp/rolls = 0

/obj/effect/crossroads_loot_pad/New()
	..()
	crossroads_loot_pads += src
	spawn(2)
		reroll()

/obj/effect/crossroads_loot_pad/Destroy()
	crossroads_loot_pads -= src
	spawned = null
	return ..()

/obj/effect/crossroads_loot_pad/proc/table_path()
	return istext(table) ? text2path(table) : table

/obj/effect/crossroads_loot_pad/proc/reroll()
	var/path = table_path()
	if (!ispath(path) || !isturf(loc)) return FALSE
	for (var/atom/movable/A in spawned)
		if (!QDELETED(A)) qdel(A)
	spawned = list()
	var/list/before = list()
	for (var/atom/movable/A in loc)
		before[A] = TRUE
	new path(loc)
	for (var/atom/movable/A in loc)
		if (A != src && !before[A] && !QDELETED(A))
			spawned += A
	rolls++
	return TRUE

/obj/effect/crossroads_loot_pad/proc/contents_summary()
	var/list/names = list()
	for (var/atom/movable/A in spawned)
		if (!QDELETED(A)) names += A.name
	return names.len ? jointext(names, ", ") : "nothing"

/obj/effect/crossroads_loot_pad/examine(mob/user, distance = -1)
	..()
	to_chat(user, "Table: [table]. Rolls so far: [rolls]. Last roll: [contents_summary()].")

/client/proc/crossroads_reroll_loot_pads()
	set name = "Reroll Loot Pads"
	set category = "Special"
	if (!check_rights(R_ADMIN))
		return
	var/count = 0
	for (var/obj/effect/crossroads_loot_pad/P in crossroads_loot_pads)
		if (P.reroll()) count++
	to_chat(src, SPAN_NOTICE("Rerolled [count] loot pads."))
	log_admin("[key_name(src)] rerolled [count] loot pads.")

/client/proc/crossroads_loot_report()
	set name = "Loot Pad Report"
	set category = "Special"
	if (!check_rights(R_ADMIN))
		return
	if (!crossroads_loot_pads.len)
		to_chat(src, SPAN_WARNING("This map has no loot pads."))
		return
	var/list/lines = list("<b>Loot pads ([crossroads_loot_pads.len])</b>")
	for (var/obj/effect/crossroads_loot_pad/P in crossroads_loot_pads)
		lines += "[P.name] at ([P.x],[P.y],[P.z]): [P.table], [P.rolls] rolls, last: [P.contents_summary()]"
	to_chat(src, jointext(lines, "<br>"))
