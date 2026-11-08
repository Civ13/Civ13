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
	turf = /turf
/world/Error(exception/e)
	world.log << "runtime error: [e] [e.file]:[e.line]"
	del(world)
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/datum
	var/name
	var/gc_destroyed = FALSE
	var/gcDestroyed = FALSE
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
/obj/item
/obj/item/weapon/storage
	var/list/is_seeing = list()
/obj/screen/inventory
	var/slot_id
/obj/screen
	plane = HUD_PLANE
	var/mob/living/parentmob
	var/process_flag = FALSE
/obj/screen/proc/process()
	return
/mob
	var/datum/hover_client/hover_client
	var/obj/item/weapon/storage/s_active
	var/list/HUDneed = list()
	var/list/HUDinventory = list()
	var/list/test_slots = list()
/mob/proc/get_equipped_item(slot)
	return test_slots[slot]
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
	var/mouse_screen_x = 0
	var/mouse_screen_y = 0
	var/mouse_screen_pixel_x = 0
	var/mouse_screen_pixel_y = 0
// The native fixture does not execute the full LOS subsystem or tree presenter.
/proc/los_read_allowed(mob/user, atom/target, operation)
	return !!user && !!target && operation == "hover"
/proc/los_tree_canopy_readable(atom/A)
	return FALSE
/proc/check(condition, message)
	if (!condition)
		throw message
/world/New()
	OpenPort("none")
	try
		run_hover_probe()
	catch (var/failure)
		world.log << "FAIL [failure]"
	del(world)
/proc/run_hover_probe()
	check(!world.port && !world.OpenPort(12345), "fixture port closed")
	var/mob/living/human/viewer = new(locate(8,8,1))
	var/datum/hover_client/C = new
	C.mob = viewer
	C.eye = viewer
	viewer.hover_client = C
	var/obj/screen/hover_name/L = new
	L.parentmob = viewer
	viewer.HUDneed["hover name"] = L
	C.screen += L
	check(!L.mouse_opacity && !L.icon && L.maptext_width == 384 && L.maptext_height == 32 && L.layer == 30, "text-only HUD defaults above the HUD controls")
	check(!L.maptext && !L.hover_text && !length(L.underlays), "starts without text or backdrop")
	check(!L.should_save, "widget save excluded")
	check(L.persistence_runtime_var("hover_target") && L.persistence_runtime_var("hover_text") && L.persistence_runtime_var("parentmob") && L.persistence_runtime_var("maptext"), "widget runtime exclusions")
	check(L.persistence_runtime_var("persistence_export_frame"), "parent exclusion")
	var/obj/A = new(locate(9,8,1))
	A.name = "<b>scope & mount</b>"
	var/obj/item/B = new(locate(10,8,1))
	B.name = "rifle"
	C.MouseEntered(A, null, "map", "")
	check(C.mouse_x == 9 && C.mouse_y == 8, "existing coordinates")
	check(findtext(L.maptext, "&nbsp;&lt;b&gt;scope &amp; mount&lt;/b&gt;&nbsp;"), "escaped public name with panel padding")
	check(findtext(L.maptext, "vertical-align:top;text-align:left"), "explicit top-left text alignment")
	check(findtext(L.maptext, "-dm-text-outline:1px #1c110a") && findtext(L.maptext, "color:#f3e9d6;background-color:#3b2c1e"), "outlined text on the panel fill")
	check(length(L.underlays) == 4, "four border underlays")
	var/image/edge = L.underlays[1]
	check(findtext(edge.maptext, "&nbsp;&lt;b&gt;scope &amp; mount&lt;/b&gt;&nbsp;") && findtext(edge.maptext, "color:#9a8468;background-color:#9a8468") && !findtext(edge.maptext, "outline"), "border underlays repeat the text in the border colour")
	check(edge.maptext_width == 384 && edge.maptext_height == 32 && edge.maptext_x == -1 && !edge.maptext_y, "border underlay shifted one pixel")
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle"), "target transition")
	C.MouseExited(A, null, "map", "")
	check(findtext(L.maptext, "rifle"), "late exit")
	C.MouseExited(B, null, "map", "")
	check(!L.maptext && !L.hover_target && !L.hover_text && !length(L.underlays), "exit clears")
	B.name = ""
	C.MouseEntered(B, null, "map", "")
	check(!L.maptext && !L.hover_target && !length(L.underlays), "empty name has no backdrop")
	B.name = "rifle"
	// The fixture view is 5 (11 tiles, 352px). Pointer at 2:1,3:1 is pixel (33, 65).
	C.MouseMove(A, null, "map", "screen-loc=2:1,3:1")
	check(C.mouse_screen_x == 2 && C.mouse_screen_pixel_x == 1 && C.mouse_screen_y == 3 && C.mouse_screen_pixel_y == 1, "move parses the pointer position")
	check(L.maptext && L.screen_loc == "2:11,1:13" && length(L.underlays) == 4, "panel below and right of the pointer")
	var/panel = L.maptext
	C.MouseMove(A, null, "map", "screen-loc=2:1,3:1")
	check(L.maptext == panel && L.screen_loc == "2:11,1:13" && length(L.underlays) == 4, "unchanged target keeps its panel")
	C.MouseMove(A, null, "map", "screen-loc=10:0,3:0")
	check(L.screen_loc == "3:24,1:12", "panel clamped at the right edge")
	C.MouseMove(null, null, "map", "")
	check(!L.maptext && !length(L.underlays), "empty pointer clears")
	C.MouseDrag(A, B, null, null, "map", "map", "screen-loc=10:0,1:10")
	check(findtext(L.maptext, "rifle") && L.screen_loc == "10:10,1:2", "drag dispatch flips the panel above a low pointer")
	C.MouseDrag(A, B, null, null, "map", "map", "drag")
	check(findtext(L.maptext, "rifle") && L.screen_loc == "10:10,1:2", "drag without a position keeps the last one")
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
	B.loc = viewer
	var/obj/screen/inventory/slot = new
	slot.parentmob = viewer
	slot.slot_id = "probe"
	slot.screen_loc = B.screen_loc
	viewer.HUDinventory += slot
	viewer.test_slots[slot.slot_id] = B
	C.screen += slot
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle"), "inventory item")
	C.screen -= B
	L.process()
	check(!L.maptext, "inventory slot removed")
	B.loc = locate(10,8,1)
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
	// Real storage helper/widget, with a fake network-client and LOS boundary.
	var/obj/item/weapon/storage/storage = new(viewer)
	B.loc = storage
	B.screen_loc = "5,5"
	viewer.s_active = storage
	storage.is_seeing += viewer
	C.screen += B
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle"), "open storage item hover")
	storage.is_seeing -= viewer
	L.process()
	check(!L.maptext, "closed storage view clears hover")
	storage.is_seeing += viewer
	C.MouseEntered(B, null, "map", "")
	var/obj/item/weapon/storage/other_storage = new(viewer)
	other_storage.is_seeing += viewer
	B.loc = other_storage
	viewer.s_active = other_storage
	L.process()
	check(!L.maptext, "storage replacement clears hover")
	C.screen -= B
	viewer.s_active = null
	check_own_hover(C, viewer, L)
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
