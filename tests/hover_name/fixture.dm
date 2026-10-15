#define FALSE 0
#define TRUE 1
#define HIDEFACE 1
#define QDELETED(D) (!D || D.gc_destroyed)
#define REF(D) "\ref[D]"
#define HUD_PLANE 20
#define QDEL_HINT_LETMELIVE 1
/world
	maxx = 15
	maxy = 15
	maxz = 1
	view = 5
/world/OpenPort(port)
	if (isnull(port))
		return ..()
	return FALSE
/datum
	var/name
	var/gc_destroyed = FALSE
	var/datum/weakref/weak_reference
/datum/proc/Destroy()
	return
/datum/proc/MouseExited(atom/object, location, control, params)
	return
/datum/proc/MouseEntered(atom/object, location, control, params)
	return
/datum/proc/MouseMove(atom/object, location, control, params)
	return
/datum/proc/MouseDrag(src_object, over_object, src_location, over_location, src_control, over_control, params)
	return
/atom
	var/should_save = TRUE
/obj
	var/flags_inv = 0
/obj/screen
	plane = HUD_PLANE
	var/mob/living/parentmob
	var/process_flag = FALSE
/obj/screen/proc/process()
	return
/mob
	var/datum/hover_client/hover_client
	var/list/HUDneed = list()
/mob/living
/mob/living/human
	var/real_name
	var/obj/wear_mask
	var/obj/head
	var/werewolf = FALSE
	var/datum/body_build
	var/title
	var/religious_title
/proc/ishuman(atom/A)
	return istype(A, /mob/living/human)
/datum/hover_client
	var/mob/mob
	var/list/screen = list()
	var/view = 5
	var/atom/eye
	var/mouse_x
	var/mouse_y
	var/last_mouse_params
/datum/hover_client/proc/UpdateMouseScreenLoc(params)
	last_mouse_params = params
/proc/check(condition, message)
	if (!condition)
		world.log << "FAIL [message]"
		del(world)
/world/New()
	OpenPort(null)
	check(!port, "fixture port closed")
	var/mob/living/human/viewer = new(locate(8,8,1))
	var/datum/hover_client/C = new
	C.mob = viewer
	C.eye = viewer
	viewer.hover_client = C
	var/obj/screen/hover_name/L = new
	L.parentmob = viewer
	viewer.HUDneed["hover name"] = L
	C.screen += L
	check(!L.mouse_opacity && !L.icon && L.maptext_width == 384 && L.maptext_height == 32, "text-only HUD defaults")
	check(!L.should_save, "widget save excluded")
	check(L.persistence_runtime_var("hover_target") && L.persistence_runtime_var("parentmob") && L.persistence_runtime_var("maptext"), "widget runtime exclusions")
	check(L.persistence_runtime_var("persistence_export_frame"), "parent exclusion")
	var/obj/A = new(locate(9,8,1))
	A.name = "<b>scope & mount</b>"
	var/obj/B = new(locate(10,8,1))
	B.name = "rifle"
	C.MouseEntered(A, null, "map", "")
	check(C.mouse_x == 9 && C.mouse_y == 8, "existing coordinates")
	check(findtext(L.maptext, "&lt;b&gt;scope &amp; mount&lt;/b&gt;"), "escaped public name")
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle"), "target transition")
	C.MouseExited(A, null, "map", "")
	check(findtext(L.maptext, "rifle"), "late exit")
	C.MouseExited(B, null, "map", "")
	check(!L.maptext && !L.hover_target, "exit clears")
	C.MouseMove(A, null, "map", "screen-loc=2:1,3:1")
	check(L.maptext && C.last_mouse_params == "screen-loc=2:1,3:1", "move dispatch")
	C.MouseMove(null, null, "map", "")
	check(!L.maptext, "empty pointer clears")
	C.MouseDrag(A, B, null, null, "map", "map", "drag")
	check(findtext(L.maptext, "rifle") && C.last_mouse_params == "drag", "drag dispatch")
	var/mob/living/human/masked = new(locate(9,9,1))
	masked.real_name = "Secret Identity"
	masked.name = "Secret Identity"
	masked.wear_mask = new
	masked.wear_mask.flags_inv = HIDEFACE
	C.MouseEntered(masked, null, "map", "")
	check(findtext(L.maptext, "Unknown") && !findtext(L.maptext, "Secret"), "masked identity")
	masked.wear_mask = null
	L.process()
	check(findtext(L.maptext, "Secret Identity"), "stationary visible-name refresh")
	C.MouseEntered(B, null, "map", "")
	B.invisibility = 99
	L.process()
	check(!L.maptext && !L.hover_target, "hidden target")
	B.invisibility = 0
	C.MouseEntered(B, null, "map", "")
	B.loc = A
	L.process()
	check(!L.maptext && !L.hover_target, "contained target")
	C.screen += B
	C.MouseEntered(B, null, "map", "")
	check(!L.maptext, "screen membership without slot hidden")
	B.screen_loc = "1,1"
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle"), "inventory item")
	C.screen -= B
	L.process()
	check(!L.maptext, "inventory slot removed")
	C.MouseEntered(A, null, "map", "")
	del(A)
	L.process()
	check(!L.maptext && !L.hover_target, "native deletion")
	B.loc = locate(9,8,1)
	C.MouseEntered(B, null, "map", "")
	B.loc = null
	L.process()
	check(!L.maptext && !L.hover_target, "legacy qdel null location")
	B.loc = locate(9,8,1)
	C.MouseEntered(B, null, "map", "")
	B.loc = locate(1,1,1)
	L.process()
	check(!L.maptext, "out of view")
	B.loc = locate(9,8,1)
	C.MouseEntered(B, null, "map", "")
	C.clear_hover_name()
	check(!L.maptext && !L.hover_target, "logout cleanup")
	C.MouseEntered(B, null, "map", "")
	L.Destroy()
	check(!L.maptext && !L.hover_target && !L.parentmob, "UI destruction clears")
	var/obj/screen/hover_name/fresh = new
	fresh.parentmob = viewer
	viewer.HUDneed["hover name"] = fresh
	check(!fresh.maptext && !fresh.hover_target, "rebuild starts empty")
	C.MouseEntered(null, null, "map", "")
	check(!C.mouse_x && !C.mouse_y, "null enter safe")
	world.log << "PASS hover name"
	del(world)
