var/list/skyboxes = list()
var/list/global_SID_map = list()

/obj/skybox
  var/ID = ""
  var/sid = 0
  var/turf/below = null
  invisibility = 100
  icon = 'icons/mob/screen1.dmi'
  icon_state = "x1-notastate" // was "x", set to invisible until they're fixed
  name = ""
  anchored = TRUE

/obj/skybox/proc/GetBelow()
	if (below)
		return below
	if (!findtext(ID, "-z2"))
		return null
	var/corresponding_ID = replacetext(ID, "-z2", "-z1")
	for (var/obj/skybox/S in skyboxes)
		if (S.ID == corresponding_ID)
			below = get_turf(S)
			return below

/obj/skybox/New()
	..()
	for (var/obj/skybox/S in loc)
		if (S != src)
			qdel(S)
	skyboxes += src
	if (!global_SID_map[ID])
		global_SID_map[ID] = 0
	++global_SID_map[ID]
	sid = global_SID_map[ID]
/*
/hook/roundstart/proc/activate_skyboxes()
	for (var/obj/skybox/S in skyboxes)
		if (dd_hassuffix(S.ID, "-z2"))
			S.GetBelow()
			if (istype(S.loc, /turf/open))
				var/turf/open/O = S.loc
				O.skybox = S
				OS_controller.open_spaces |= O
*/

/hook/roundstart/proc/activate_skyboxes()
	for (var/obj/skybox/S in skyboxes)
		qdel(S)
	return TRUE