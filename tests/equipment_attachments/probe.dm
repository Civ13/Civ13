// Native probe: clothing attachments (routing of a held item, the HUD strip
// helpers) and the belt staying on without clothes.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/equipment_attachments/probe.dm
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/client/New()
	del(src)
	return

/obj/map_metadata/ea_probe/New()
	return

// Skip the human constructor; these checks only use worn slots and hands.
/mob/living/human/ea_probe/New()
	return
/mob/living/human/ea_probe/update_inv_l_hand()
	return
/mob/living/human/ea_probe/update_inv_r_hand()
	return
/mob/living/human/ea_probe/update_inv_w_uniform()
	return
/mob/living/human/ea_probe/update_inv_wear_suit()
	return

var/ea_failures = 0
var/ea_runtime_error = FALSE
/proc/ea_check(condition, label)
	if (!condition)
		ea_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	ea_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map = new /obj/map_metadata/ea_probe
		map.civilizations = TRUE
		ea_checks()
	catch(var/exception/e)
		ea_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ea_failures, "runtime_error" = ea_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/mob/living/human/ea_probe/update_inv_belt()
	return
/mob/living/human/ea_probe/update_inv_wear_id()
	return
/mob/living/human/ea_probe/update_inv_pockets()
	return
/mob/living/human/ea_probe/update_action_buttons()
	return
/mob/living/human/ea_probe/update_icons()
	return

/proc/ea_checks()
	var/turf/T = locate(2, 2, 1)
	var/mob/living/human/ea_probe/H = new
	H.loc = T

	// Strip layout: one row above the storage window, moved with it.
	var/list/locs = attachment_strip_locs(3, 5, 2)
	ea_check(locs.len == 3 && locs[1] == "5:16,3:16" && locs[3] == "7:16,3:16", "three tiles sit in a row above the storage window")
	locs = attachment_strip_locs(2, 5, 2, 2, 4)
	ea_check(locs[1] == "7:16,7:16" && locs[2] == "8:16,7:16", "the strip moves with a dragged storage window")
	ea_check(attachment_strip_locs(0, 5, 2).len == 0, "no attachments, no tiles")

	// Two pouches on one outfit: a held item goes into the first only.
	var/obj/item/clothing/under/shirt = new(H)
	H.w_uniform = shirt
	var/obj/item/clothing/accessory/storage/belt_pouch/first = new(T)
	var/obj/item/clothing/accessory/storage/belt_pouch/cloth/second = new(T)
	for (var/obj/item/clothing/accessory/A in list(first, second))
		ea_check(shirt.can_attach_accessory(A), "[A] can be attached")
		shirt.accessories += A
		A.on_attached(shirt, H)
	ea_check(attachment_strip_valid(first, shirt, H) && attachment_strip_valid(second, shirt, H), "both pouches are valid strip targets")
	var/obj/item/weapon/flint/stone = new(H)
	H.l_hand = stone
	H.hand = TRUE
	shirt.attackby(stone, H)
	ea_check(stone.loc == first.hold, "the held item went into the first pouch")
	ea_check(!second.hold.contents.len, "the second pouch was not offered an item that was already stowed")

	// A tile's target stops being valid once the pouch or the clothes leave.
	shirt.accessories -= second
	second.has_suit = null
	second.loc = T
	ea_check(!attachment_strip_valid(second, shirt, H), "a removed pouch is no longer a strip target")
	ea_check(attachment_strip_valid(first, shirt, H), "the remaining pouch still is")

	// An empty hand on a necklace tile takes the necklace off into the hand;
	// on a pouch tile it opens the pouch and leaves it attached.
	var/obj/item/clothing/accessory/necklace/cord = new(T)
	shirt.accessories += cord
	cord.on_attached(shirt, H)
	ea_check(cord.strip_click_removes && !first.strip_click_removes, "necklaces come off from the strip; pouches open")
	H.l_hand = null
	attachment_strip_use(H, cord, shirt)
	ea_check(!(cord in shirt.accessories) && !cord.has_suit && H.get_active_hand() == cord, "an empty-hand click takes the necklace into the hand")
	H.l_hand = null
	cord.loc = T
	attachment_strip_use(H, first, shirt)
	ea_check((first in shirt.accessories) && first.has_suit == shirt, "an empty-hand click leaves the pouch attached")

	// Examining a strip attachment reads it without taking it off.
	attachment_strip_examine(H, first)
	ea_check((first in shirt.accessories) && first.has_suit == shirt, "examining a pouch from the strip leaves it attached")

	// Dragging a pouch tile to a chosen hand takes it into that hand, even when
	// the other hand is the active one; a full hand refuses it.
	var/obj/item/clothing/accessory/storage/belt_pouch/spare = new(T)
	shirt.accessories += spare
	spare.on_attached(shirt, H)
	H.l_hand = null
	H.r_hand = null
	H.hand = TRUE
	ea_check(attachment_strip_take_off(H, spare, shirt, slot_r_hand), "a pouch dragged to the right hand comes off")
	ea_check(H.r_hand == spare && !H.l_hand && !(spare in shirt.accessories) && !spare.has_suit, "it lands in the right hand, not the active left one")
	ea_check(H.hand == TRUE, "the active hand is unchanged")
	H.r_hand = null
	spare.loc = T
	shirt.accessories += spare
	spare.on_attached(shirt, H)
	var/obj/item/weapon/flint/held = new(H)
	H.r_hand = held
	ea_check(!attachment_strip_take_off(H, spare, shirt, slot_r_hand) && (spare in shirt.accessories) && spare.has_suit == shirt, "a full hand refuses it and the pouch stays on")
	H.r_hand = null
	held.loc = T

	// Dragging a tile to the floor sets the attachment down there, but only on
	// the wearer's tile or one next to it.
	var/turf/far = locate(6, 2, 1)
	ea_check(!attachment_strip_set_down(H, spare, shirt, far) && (spare in shirt.accessories), "a far tile is refused")
	var/turf/next = locate(3, 2, 1)
	ea_check(attachment_strip_set_down(H, spare, shirt, next), "a pouch dragged to the next tile comes off")
	ea_check(spare.loc == next && !H.l_hand && !H.r_hand && !(spare in shirt.accessories), "it lies on that tile, not in a hand")

	// The belt stays on when the clothes come off.
	var/obj/item/clothing/pouch_belt/belt = new(H)
	H.belt = belt
	ea_check(H.u_equip(shirt), "the clothes come off")
	ea_check(!H.w_uniform && H.belt == belt, "the belt stays on without clothes")
	shirt.loc = T
	ea_check(!attachment_strip_valid(first, shirt, H), "attachments on dropped clothes are not strip targets")

	// Belt points: two pouches, one sheath or holster, one tool loop.
	var/obj/item/clothing/pouch_belt/rig = new(T)
	var/obj/item/clothing/accessory/storage/sheath/sheath = new(T)
	var/obj/item/clothing/accessory/storage/sheath/knife/knife_sheath = new(T)
	var/obj/item/clothing/accessory/holster/holster = new(T)
	var/obj/item/clothing/accessory/storage/webbing/webbing = new(T)
	var/obj/item/clothing/accessory/storage/tool_loop/tool_loop = new(T)
	var/obj/item/clothing/accessory/storage/tool_loop/spare_loop = new(T)
	ea_check(rig.can_attach_accessory(sheath) && rig.can_attach_accessory(holster) && rig.can_attach_accessory(tool_loop), "a belt takes a sheath, a holster or a tool loop")
	ea_check(!rig.can_attach_accessory(webbing), "a belt does not take webbing")
	rig.accessories += sheath
	sheath.on_attached(rig, H)
	ea_check(!rig.can_attach_accessory(knife_sheath) && !rig.can_attach_accessory(holster), "one sheath or holster per belt")
	ea_check(rig.can_attach_accessory(tool_loop) && rig.can_attach_accessory(second), "a sheath leaves the loop and pouch points free")
	rig.accessories += tool_loop
	tool_loop.on_attached(rig, H)
	ea_check(!rig.can_attach_accessory(spare_loop), "one tool loop per belt")
	ea_check(/obj/item/clothing/accessory/storage/sheath/verb/sheathe_verb in rig.verbs, "a belt with a sheath offers the draw and sheathe verb")

	// The tool loop holds one thing made for the belt.
	var/obj/item/weapon/hammer/hammer = new(T)
	var/obj/item/weapon/hammer/hammer_two = new(T)
	var/obj/item/stack/material/wood/planks = new(T)
	ea_check(hammer.slot_flags & SLOT_BELT, "a hammer is belt gear")
	ea_check(tool_loop.hold.can_be_inserted(hammer, TRUE), "a hammer hangs in the tool loop")
	ea_check(!tool_loop.hold.can_be_inserted(planks, TRUE), "planks do not hang in the tool loop")
	ea_check(!tool_loop.hold.can_be_inserted(second, TRUE), "a pouch does not hang in the tool loop")
	hammer.loc = tool_loop.hold
	ea_check(!tool_loop.hold.can_be_inserted(hammer_two, TRUE), "the tool loop holds one thing")

	// The shoulder belt: two pouches, or one sword and a pouch.
	var/obj/item/clothing/accessory/storage/baldric/baldric = new(T)
	var/obj/item/weapon/material/sword/sword = new(T)
	var/obj/item/weapon/material/sword/sword_two = new(T)
	var/obj/item/clothing/accessory/storage/belt_pouch/third = new(T)
	ea_check(baldric.hold.can_be_inserted(sword, TRUE), "a sword hangs from the shoulder belt")
	sword.loc = baldric.hold
	ea_check(!baldric.hold.can_be_inserted(sword_two, TRUE), "only one sword hangs from the shoulder belt")
	ea_check(baldric.hold.can_be_inserted(second, TRUE), "a pouch still fits beside the sword")
	second.loc = baldric.hold
	ea_check(!baldric.hold.can_be_inserted(third, TRUE), "the shoulder belt has two places")
	ea_check(!baldric.hold.can_be_inserted(hammer_two, TRUE), "the shoulder belt does not carry tools")
