/proc/check_own_hover(datum/hover_client/C, mob/living/human/viewer, obj/screen/hover_name/L)
	// The configured player's own body must use the same public-name path as
	// another human, without bypassing visibility or remote-camera checks.
	viewer.name = "Own Visible Identity"
	viewer.real_name = "Own Visible Identity"
	C.MouseEntered(viewer, null, "map", "")
	check(findtext(L.maptext, "Own Visible Identity"), "own body enter")
	C.MouseMove(viewer, null, "map", "screen-loc=8:1,8:1")
	check(findtext(L.maptext, "Own Visible Identity"), "own body move")
	C.MouseDrag(null, viewer, null, null, "map", "map", "drag")
	check(findtext(L.maptext, "Own Visible Identity"), "own body drag")
	viewer.wear_mask = new
	viewer.wear_mask.flags_inv = HIDEFACE
	L.process()
	check(findtext(L.maptext, "Unknown") && !findtext(L.maptext, "Own Visible Identity"), "own masked identity")
	viewer.wear_mask = null
	viewer.alpha = 0
	L.process()
	check(!L.maptext && !L.hover_target, "own transparent body")
	viewer.alpha = 255
	viewer.invisibility = 99
	C.MouseEntered(viewer, null, "map", "")
	check(!L.maptext && !L.hover_target, "own invisible body")
	viewer.invisibility = 0
	C.eye = locate(1,1,1)
	C.MouseEntered(viewer, null, "map", "")
	check(!L.maptext && !L.hover_target, "own body outside remote camera")
	C.eye = viewer
	C.MouseEntered(viewer, null, "map", "")
	check(findtext(L.maptext, "Own Visible Identity"), "own camera restored")
	C.MouseExited(viewer, null, "map", "")
	check(!L.maptext && !L.hover_target, "own body exit")
