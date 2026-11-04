// Game stand-ins for map_area_export.dm. Shared by the exporting world and by
// the world that compiles the exported map, so both know the same types.

#define R_DEBUG 0x20

/proc/check_rights(rights_required)
	return TRUE

/proc/to_chat(target, text)
	return

/proc/log_admin(text)
	return

/proc/key_name(whom)
	return "[whom]"

/datum/admins
	var/rights = 0

/client/var/datum/admins/holder = null

/proc/get_turf(atom/A)
	while(A && !isturf(A)) A = A.loc
	return A

/client/proc/add_admin_verbs()
	return

/client/proc/remove_admin_verbs()
	return

/atom/movable/lighting_overlay

/area/hall
/area/garden

/turf/floor/wood
/turf/floor/grass
	icon_state = "grass1"
/turf/wall/stone
	density = TRUE

/obj/structure/chair
/obj/structure/table
/obj/structure/sign
	desc = "A sign."
/obj/item/box
/obj/item/apple
/obj/item/stack
	var/amount = 1
/obj/item/stack/material/wood

/mob/dummy

// One tile as both worlds report it: what the export must reproduce.
/proc/map_export_test_describe(turf/T)
	var/list/out = list()
	for(var/obj/O in T)
		var/list/row = list("[O.type]", O.dir, O.pixel_x, O.pixel_y, O.icon_state, O.name, O.contents.len)
		if(istype(O, /obj/item/stack))
			var/obj/item/stack/S = O
			row += S.amount
		out += list(row)
	out += list(list("[T.type]", T.dir, T.icon_state))
	out += "[T.loc.type]"
	return out
