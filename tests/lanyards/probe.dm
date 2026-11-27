// Run in the isolated Linux game fixture, not on a server.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/tether_probe
	var/wrist_attempts = 0
	var/drop_during_hand_update = FALSE

/mob/living/human/tether_probe/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	organs_by_name = list("l_hand" = new /obj/item/organ/external/tether_probe_hand, "r_hand" = new /obj/item/organ/external/tether_probe_hand)

/mob/living/human/tether_probe/update_icons()
	return

/mob/living/human/tether_probe/put_in_active_hand(obj/item/I)
	wrist_attempts++
	if (drop_during_hand_update)
		// Model the hand-update path that reports success after a drop.
		I.dropped(src)
		return TRUE
	return ..()

/obj/item/organ/external/tether_probe_hand/New()
	return

/obj/item/organ/external/tether_probe_hand/is_usable()
	return TRUE

/obj/item/weapon/hammer/tether_probe
	var/callbacks = 0

/obj/item/weapon/hammer/tether_probe/tether_catch(mob/living/human/H)
	callbacks++
	return ..()

var/tether_probe_failures = 0
var/tether_probe_runtime_error = FALSE

/proc/tether_probe_check(condition, label)
	if (!condition)
		tether_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	tether_probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		if (!GLOB.nanomanager)
			GLOB.nanomanager = new
		tether_probe_wrist()
		tether_probe_lanyard()
	catch(var/exception/e)
		tether_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = tether_probe_failures, "runtime_error" = tether_probe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/tether_probe_drain_timers()
	var/finish = world.time + 10
	while (world.time < finish)
		sleep(world.tick_lag)
		SStimer.state = SS_RUNNING
		SStimer.fire()

/proc/tether_probe_wrist()
	var/turf/T = locate(4, 4, 1)
	var/mob/living/human/tether_probe/H = new(T)
	var/obj/item/weapon/hammer/tether_probe/I = new(T)
	I.wrist_loop = "wrist thong"
	I.wrist_looped = TRUE
	H.handcuffed = new /obj/item/weapon/handcuffs(H)
	I.dropped(H)
	tether_probe_drain_timers()
	tether_probe_check(I.callbacks == 1 && !H.wrist_attempts && I.loc == T && !I.wrist_looped, "handcuffs settle a wrist-looped drop without trying to regrip")
	H.handcuffed = null
	H.drop_during_hand_update = TRUE
	H.wrist_attempts = 0
	I.callbacks = 0
	I.wrist_looped = TRUE
	I.dropped(H)
	tether_probe_drain_timers()
	tether_probe_check(I.callbacks == 1 && H.wrist_attempts == 1 && I.loc == T && !I.wrist_looped, "false hand success causes one catch attempt, then no requeue")
	H.drop_during_hand_update = FALSE
	I.wrist_looped = TRUE
	I.dropped(H)
	tether_probe_drain_timers()
	tether_probe_check(I.loc == H && H.item_is_in_hands(I) && I.wrist_looped, "an unrestricted wearer catches and retains the wrist loop")

/proc/tether_probe_lanyard()
	var/turf/T = locate(8, 8, 1)
	var/mob/living/human/tether_probe/owner = new(T)
	var/mob/living/human/tether_probe/other = new(T)
	var/obj/item/clothing/accessory/storage/lanyard/L = new(owner)
	var/obj/item/weapon/whistle/I = new(T)
	L.hold.handle_item_insertion(I, TRUE)
	tether_probe_check(I.lanyard_tied, "storage entry ties the whistle")
	L.attack_self(owner)
	tether_probe_check(I.loc == T && !I.lanyard_tied, "activating a loose cord spills and unties the whistle")
	other.put_in_active_hand(I)
	tether_probe_check(I.loc == other && other.item_is_in_hands(I) && !I.lanyard_tied, "ordinary pickup of a spilled whistle keeps it untied")
	other.remove_from_mob(I)

	var/obj/item/clothing/under/C = new(owner)
	owner.w_uniform = C
	C.accessories = list(L)
	L.on_attached(C, owner)
	var/datum/storage_window/W = new(owner)
	L.hold.handle_item_insertion(I, TRUE)
	tether_probe_check(W.perform_move(I, STORAGE_WINDOW_KIND_HANDS, owner, slot_r_hand) && owner.r_hand == I && I.lanyard_tied, "exact-slot Storage Window draw from the owner's equipped cord preserves the tie")
	owner.remove_from_mob(I)
	tether_probe_drain_timers()
	tether_probe_check(I.loc == L.hold && I.lanyard_tied, "a truly tied drop returns to its worn cord")
	tether_probe_check(W.perform_move(I, STORAGE_WINDOW_KIND_FLOOR, null) && I.loc == T && !I.lanyard_tied, "the Storage Window floor path detaches and unties")
	L.hold.handle_item_insertion(I, TRUE)
	tether_probe_check(W.perform_move(I, STORAGE_WINDOW_KIND_HANDS, owner) && owner.item_is_in_hands(I) && I.lanyard_tied, "automatic Storage Window hand draw preserves the owner's tie")
	owner.remove_from_mob(I)
	tether_probe_drain_timers()
	owner.s_active = L.hold
	I.equiptimer = 0
	I.inventory_drag_to_hand(slot_r_hand, owner)
	tether_probe_check(owner.r_hand == I && I.loc == owner && I.lanyard_tied, "classic drag from the owner's cord preserves the tie")
	owner.remove_from_mob(I)
	tether_probe_drain_timers()
	I.attack_hand(owner)
	tether_probe_check(owner.item_is_in_hands(I) && I.loc == owner && I.lanyard_tied, "clicking an item from the owner's cord preserves the tie")
	owner.remove_from_mob(I)
	tether_probe_drain_timers()
	owner.stat = DEAD
	var/datum/storage_window/other_window = new(other)
	tether_probe_check(other_window.perform_move(I, STORAGE_WINDOW_KIND_HANDS, other, slot_r_hand) && other.r_hand == I && !I.lanyard_tied, "a draw from someone else's equipped cord unties the whistle")
