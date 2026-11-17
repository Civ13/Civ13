// Headless probe for the stack count shown on inventory slots (code/modules/storage_window/stack_count.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/stack_count/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 6
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/stackcount_probe/New()
	species = new /datum/species/human
	return
/mob/living/human/stackcount_probe/update_icons()
	return

var/stackcount_failures = 0
var/stackcount_runtime_error = FALSE
/proc/stackcount_check(condition, label)
	if (!condition)
		stackcount_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	stackcount_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		stackcount_text_checks()
		stackcount_badge_checks()
		stackcount_sweep_checks()
	catch(var/exception/e)
		stackcount_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = stackcount_failures, "runtime_error" = stackcount_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/stackcount_text_checks()
	stackcount_check(stack_count_text(2) == "2", "2 reads 2")
	stackcount_check(stack_count_text(50) == "50", "50 reads 50")
	stackcount_check(stack_count_text(9999) == "9999", "9999 keeps four figures")
	stackcount_check(stack_count_text(10000) == "10k", "10000 reads 10k")
	stackcount_check(stack_count_text(12999) == "12k", "12999 reads 12k")
	stackcount_check(stack_count_text(999999) == "999k", "999999 reads 999k")
	stackcount_check(stack_count_text(1000000) == "1m", "a million reads 1m")
	for (var/n in list(2, 50, 500, 2500, 9999, 10000, 999999, 1000000, 5000000000))
		stackcount_check(length(stack_count_text(n)) <= 4, "[n] fits four figures")
	// Every glyph a count can use is in the sheet, in both colours.
	var/list/states = icon_states('icons/mob/screen/stack_count.dmi')
	for (var/prefix in list("n", "f"))
		for (var/glyph in list("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "k", "m"))
			stackcount_check("[prefix][glyph]" in states, "the sheet has [prefix][glyph]")

/proc/stackcount_badge_checks()
	var/turf/here = locate(3, 3, 1)
	var/obj/item/stack/material/stone/A = new(here, 50)
	var/obj/item/stack/material/stone/B = new(locate(4, 3, 1), 12)
	A.update_slot_count()
	stackcount_check(!A.slot_count_badge && !length(A.vis_contents), "a stack on the ground shows no number")

	var/obj/item/weapon/storage/backpack/bag = new(here)
	bag.handle_item_insertion(A, TRUE)
	bag.handle_item_insertion(B, TRUE)
	stackcount_check(A.loc == bag && A.slot_count_badge && (A.slot_count_badge in A.vis_contents), "a stack of 50 in a bag shows a number")
	stackcount_check(A.slot_count_badge == stack_count_badge(50, A.slot_count_full()), "it is the badge for 50")
	stackcount_check(A.slot_count_badge.overlays.len == 2, "50 is two figures")
	stackcount_check(B.slot_count_badge && B.slot_count_badge != A.slot_count_badge, "12 shows a different number")
	stackcount_check(stack_count_badge(12, FALSE) != stack_count_badge(12, TRUE), "a full stack has its own badge")
	stackcount_check(length(A.vis_contents) == 1, "one badge only")
	stackcount_check(!A.slot_count_badge.mouse_opacity, "the number cannot be clicked")

	// The number is never saved with the item.
	var/list/saved = A.get_saved_vars()
	stackcount_check(!("vis_contents" in saved) && !("slot_count_badge" in saved), "the number is left out of saves")

	// Using the stack changes the number at once.
	var/before = A.slot_count_badge
	stackcount_check(A.use(8) && A.amount == 42, "use still works")
	stackcount_check(A.slot_count_badge != before && A.slot_count_badge == stack_count_badge(42, FALSE), "using 8 shows 42")
	stackcount_check(length(A.vis_contents) == 1, "still one badge after the change")

	// Two stacks showing the same count share one badge.
	B.amount = 42
	B.update_slot_count()
	stackcount_check(B.slot_count_badge == A.slot_count_badge, "equal counts share a badge")

	// One thing shows nothing.
	B.amount = 1
	B.update_slot_count()
	stackcount_check(!B.slot_count_badge && !length(B.vis_contents), "a single thing shows no number")

	// A full stack is the amber set.
	if (A.max_amount)
		A.amount = A.max_amount
		A.update_slot_count()
		stackcount_check(A.slot_count_badge == stack_count_badge(A.max_amount, TRUE), "a full stack shows the full colour")

	// Taking it out onto the ground clears it.
	bag.remove_from_storage(A, here)
	stackcount_check(isturf(A.loc) && !A.slot_count_badge && !length(A.vis_contents), "taken out onto the ground, the number goes")

	// Splitting keeps both halves right.
	bag.handle_item_insertion(A, TRUE)
	A.amount = 20
	A.update_slot_count()
	var/obj/item/stack/half = A.split(5)
	stackcount_check(A.amount == 15 && A.slot_count_badge == stack_count_badge(15, FALSE), "the rest of a split stack shows 15")
	stackcount_check(istype(half) && half.amount == 5 && half.slot_count_badge == stack_count_badge(5, FALSE), "the split-off part shows 5")

	// Merging updates both.
	half.merge(A)
	stackcount_check(A.amount == 20 && A.slot_count_badge == stack_count_badge(20, FALSE), "merged back shows 20")

	// A deleted stack lets go of its badge.
	var/atom/movable/stack_count_badge/kept = A.slot_count_badge
	qdel(A)
	stackcount_check(!QDELETED(kept), "deleting a stack keeps the shared badge")

/proc/stackcount_sweep_checks()
	var/turf/here = locate(2, 2, 1)
	var/mob/living/human/stackcount_probe/H = new(here)
	var/obj/item/stack/material/stone/S = new(here, 30)
	S.forceMove(H)
	H.refresh_slot_counts()
	stackcount_check(S.slot_count_badge == stack_count_badge(30, FALSE), "the sweep shows a carried stack's number")
	stackcount_check(H.slot_count_tracked && (S in H.slot_count_tracked), "the sweep remembers it")

	// Code that changes amount directly is caught by the next sweep.
	S.amount -= 7
	H.refresh_slot_counts()
	stackcount_check(S.slot_count_badge == stack_count_badge(23, FALSE), "a direct amount change shows on the next sweep")

	// A stack that left some other way loses its number on the next sweep.
	S.forceMove(here)
	stackcount_check(S.slot_count_badge, "moved without a hook, the number is still there")
	H.refresh_slot_counts()
	stackcount_check(!S.slot_count_badge && !length(S.vis_contents), "the next sweep clears it")
	stackcount_check(!H.slot_count_tracked, "nothing left to remember")

	// The open bag's contents are swept too.
	var/obj/item/weapon/storage/backpack/bag = new(here)
	S.forceMove(bag)
	H.s_active = bag
	H.refresh_slot_counts()
	stackcount_check(S.slot_count_badge == stack_count_badge(23, FALSE), "the open bag's stacks are swept")
	H.s_active = null

	var/list/saved = H.get_saved_vars()
	stackcount_check(!("slot_count_tracked" in saved), "the sweep list is left out of saves")
