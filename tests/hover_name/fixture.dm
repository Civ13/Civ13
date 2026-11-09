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
/datum/preferences
	var/hud_scale = 1
	var/hover_text_scale = 1
	var/hover_text_enabled = TRUE
/datum/hover_client
	var/mob/mob
	var/datum/preferences/prefs
	var/list/screen = list()
	var/view = 5
	var/atom/eye
	var/mouse_x
	var/mouse_y
	var/mouse_screen_x = 0
	var/mouse_screen_y = 0
	var/mouse_screen_pixel_x = 0
	var/mouse_screen_pixel_y = 0
	var/list/measured = list()
	var/measure_answer
// The client's text measurement is a network round trip; this boundary answers
// at once with a size that follows the styled font size: 4em wide, 1.2em high.
/datum/hover_client/proc/MeasureText(text, style, width)
	measured += text
	if (width)
		return "[width]x13" // the live client answers a given width with the box width
	if (measure_answer)
		return measure_answer
	var/start = findtext(text, "font-size:") + 10
	var/px = text2num(copytext(text, start, findtext(text, "px", start)))
	return "[px * 4]x[round(px * 1.2)]"
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
	check(findtext(L.maptext, ">&lt;b&gt;scope &amp; mount&lt;/b&gt;</span>"), "escaped public name")
	check(findtext(L.maptext, "text-align:center;vertical-align:middle;"), "text centred in the panel both ways")
	check(findtext(L.maptext, "-dm-text-outline:1px #1c110a") && findtext(L.maptext, "color:#f3e9d6") && !findtext(L.maptext, "background-color"), "outlined text without its own background")
	check(length(C.measured) == 1 && C.measured[1] == L.maptext, "the client measures the drawn label")
	// 11px: measured 44x13 plus 5px/2px padding, rounded up to even sizes.
	check(L.maptext_width == 54 && L.maptext_height == 18 && L.hover_text_width == 56 && L.hover_text_height == 20 && !L.maptext_x && !L.maptext_y, "panel fits the measured text")
	check(length(L.underlays) == 2, "border and fill underlays")
	var/image/edge = L.underlays[1]
	var/image/fill = L.underlays[2]
	var/matrix/m = edge.transform
	check(edge.color == "#9a8468" && edge.layer < fill.layer && m.a == 56 / 32 && m.e == 20 / 32 && m.c == -1 + 28 - 16 && m.f == -1 + 10 - 16, "border rectangle one pixel outside the box, behind the fill")
	m = fill.transform
	check(fill.color == "#3b2c1e" && fill.icon_state == "white" && m.a == 54 / 32 && m.e == 18 / 32 && m.c == 27 - 16 && m.f == 9 - 16, "fill rectangle covers exactly the maptext box")
	check((fill.appearance_flags & PIXEL_SCALE), "rectangles keep hard edges")
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle"), "target transition")
	// The label follows Hover Text Size, not HUD Scale: 11px at 100% (and with no preferences).
	check(findtext(L.maptext, "font-size:11px;") && L.maptext_width == 54 && L.maptext_height == 18, "11px label at 100%")
	C.prefs = new
	C.prefs.hud_scale = 2
	L.process()
	check(findtext(L.maptext, "font-size:11px;"), "HUD Scale leaves the label alone")
	C.prefs.hover_text_scale = 2
	L.process()
	check(findtext(L.maptext, "font-size:22px;") && L.maptext_width == 110 && L.maptext_height == 34 && L.hover_font_px == 22, "label doubles at 200%")
	edge = L.underlays[1]
	m = edge.transform
	check(m.a == 112 / 32 && m.e == 36 / 32, "border follows the larger label")
	C.prefs.hover_text_scale = 0.5
	L.process()
	check(findtext(L.maptext, "font-size:6px;") && L.maptext_width == 30 && L.maptext_height == 10, "label shrinks to a readable minimum at 50%")
	C.prefs.hover_text_scale = 1
	L.process()
	var/asked = length(C.measured)
	check(findtext(L.maptext, "font-size:11px;") && L.maptext_width == 54 && L.maptext_height == 18, "label back to 11px")
	check(asked == 4, "a measured label and size is not measured again")
	// Toggle Hover Text: while off the pointer draws nothing; on again it does.
	C.clear_hover_name()
	C.prefs.hover_text_enabled = FALSE
	C.MouseEntered(B, null, "map", "")
	check(!L.maptext && !L.hover_target && !L.hover_text && !length(L.underlays), "hover text off draws no panel")
	C.prefs.hover_text_enabled = TRUE
	C.MouseEntered(B, null, "map", "")
	check(findtext(L.maptext, "rifle") && length(L.underlays) == 2, "hover text back on")
	// A width far beyond the estimate is not the text's width: keep the estimate.
	C.measure_answer = "374x13"
	B.name = "pistol"
	L.process()
	check(L.maptext_width == 52 && L.maptext_height == 18, "an implausible measured width falls back to the estimate")
	C.measure_answer = null
	B.name = "rifle"
	L.process()
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
	check(L.maptext && L.screen_loc == "2:11,1:26" && length(L.underlays) == 2, "panel below and right of the pointer")
	var/panel = L.maptext
	C.MouseMove(A, null, "map", "screen-loc=2:1,3:1")
	check(L.maptext == panel && L.screen_loc == "2:11,1:26" && length(L.underlays) == 2, "unchanged target keeps its panel")
	C.MouseMove(A, null, "map", "screen-loc=10:0,3:0")
	check(L.screen_loc == "10:9,1:25", "panel clamped at the right edge")
	C.MouseMove(null, null, "map", "")
	check(!L.maptext && !length(L.underlays), "empty pointer clears")
	C.MouseDrag(A, B, null, null, "map", "map", "screen-loc=10:0,1:10")
	check(findtext(L.maptext, "rifle") && L.screen_loc == "10:9,1:19", "drag dispatch flips the panel above a low pointer")
	C.MouseDrag(A, B, null, null, "map", "map", "drag")
	check(findtext(L.maptext, "rifle") && L.screen_loc == "10:9,1:19", "drag without a position keeps the last one")
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
