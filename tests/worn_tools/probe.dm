// Native probe: tools built into wearable gear (worn_tools.dm): reaching a
// worn tool, boot and sleeve sheath fittings, the striker using a worn flint.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/worn_tools/probe.dm
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

/obj/map_metadata/wt_probe/New()
	return

// Skip the human constructor; these checks only use worn slots and hands.
/mob/living/human/wt_probe/New()
	return
/mob/living/human/wt_probe/update_inv_l_hand()
	return
/mob/living/human/wt_probe/update_inv_r_hand()
	return
/mob/living/human/wt_probe/update_inv_w_uniform()
	return
/mob/living/human/wt_probe/update_inv_wear_suit()
	return

var/wt_failures = 0
var/wt_runtime_error = FALSE
/proc/wt_check(condition, label)
	if (!condition)
		wt_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	wt_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map = new /obj/map_metadata/wt_probe
		map.civilizations = TRUE
		wt_checks()
	catch(var/exception/e)
		wt_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wt_failures, "runtime_error" = wt_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/mob/living/human/wt_probe/update_inv_belt()
	return
/mob/living/human/wt_probe/update_inv_wear_id()
	return
/mob/living/human/wt_probe/update_inv_pockets()
	return
/mob/living/human/wt_probe/update_action_buttons()
	return

/mob/living/human/wt_probe/update_inv_shoes()
	return

/proc/wt_checks()
	var/turf/T = locate(2, 2, 1)
	var/mob/living/human/wt_probe/H = new
	H.loc = T

	// Reaching: nothing worn, nothing found; the other hand counts.
	wt_check(!H.reach_worn_tool(/obj/item/weapon/flint), "nothing worn, no flint to reach")
	var/obj/item/weapon/flint/held = new(H)
	H.l_hand = held
	H.hand = FALSE // right hand active, left is the other hand
	wt_check(H.reach_worn_tool(/obj/item/weapon/flint) == held, "a flint in the other hand is reached first")
	H.l_hand = null
	held.loc = T

	// A flint in a pouch on the belt is at hand.
	var/obj/item/clothing/pouch_belt/belt = new(H)
	H.belt = belt
	var/obj/item/clothing/accessory/storage/belt_pouch/pouch = new(T)
	belt.accessories += pouch
	pouch.on_attached(belt, H)
	var/obj/item/weapon/flint/worn = new(pouch.hold)
	wt_check(H.reach_worn_tool(/obj/item/weapon/flint) == worn, "a flint in a belt pouch is reached")

	// A flint in a backpack is not.
	worn.loc = T
	var/obj/item/weapon/storage/backpack/pack = new(H)
	H.back = pack
	var/obj/item/weapon/flint/packed = new(pack)
	wt_check(!H.reach_worn_tool(/obj/item/weapon/flint), "a flint in a backpack is not at hand")
	packed.loc = T

	// The striker strikes against the worn flint with the other hand busy.
	worn.loc = pouch.hold
	var/obj/item/weapon/flame/lighter/striker/S = new(H)
	S.spark_chance = 100
	H.r_hand = S
	var/obj/item/stack/material/wood/busy = new(H)
	H.l_hand = busy
	S.attack_self(H)
	wt_check(S.lit || QDELETED(worn), "the striker throws sparks from a worn flint while the other hand is full")
	S.snuff()

	// A boot sheath goes in shoes, not a coat; a sleeve sheath the other way.
	var/obj/item/clothing/shoes/boots = new(T)
	var/obj/item/clothing/suit/coat = new(T)
	var/obj/item/clothing/under/shirt = new(T)
	var/obj/item/clothing/accessory/storage/sheath/fitting/boot_sheath = new(T)
	var/obj/item/clothing/accessory/storage/sheath/fitting/sleeve/sleeve_sheath = new(T)
	wt_check(boots.can_attach_accessory(boot_sheath), "a boot sheath fits in shoes")
	wt_check(!coat.can_attach_accessory(boot_sheath), "a boot sheath does not fit a coat")
	wt_check(coat.can_attach_accessory(sleeve_sheath), "a sleeve sheath fits a coat")
	wt_check(!boots.can_attach_accessory(sleeve_sheath), "a sleeve sheath does not fit shoes")
	wt_check(!shirt.can_attach_accessory(boot_sheath), "fittings do not go on a uniform")
	boots.accessories += boot_sheath
	boot_sheath.on_attached(boots, null)
	var/obj/item/clothing/accessory/storage/sheath/fitting/spare = new(T)
	wt_check(!boots.can_attach_accessory(spare), "one fitting per garment")
	wt_check(!boot_sheath.get_inv_overlay().icon && !boot_sheath.get_mob_overlay().icon, "a fitting draws nothing on the shoe or the wearer")

	// Small knives only (and the awl in a sleeve).
	var/obj/item/weapon/material/kitchen/utensil/knife/flint/flint_knife = new(T)
	var/obj/item/weapon/material/kitchen/utensil/knife/butcher/cleaver = new(T)
	var/obj/item/weapon/material/kitchen/utensil/fork/fork = new(T)
	var/obj/item/weapon/bone_needle/awl = new(T)
	wt_check(boot_sheath.hold.can_be_inserted(flint_knife, TRUE), "a flint knife fits the boot sheath")
	wt_check(!boot_sheath.hold.can_be_inserted(cleaver, TRUE), "a butcher knife does not")
	wt_check(!boot_sheath.hold.can_be_inserted(fork, TRUE), "a fork does not")
	wt_check(!boot_sheath.hold.can_be_inserted(awl, TRUE), "an awl does not fit a boot sheath")
	wt_check(sleeve_sheath.hold.can_be_inserted(awl, TRUE), "an awl fits a sleeve sheath")

	// Worn boots: an empty hand draws the knife; the knife is a reachable tool.
	S.loc = T
	H.r_hand = null
	busy.loc = T
	H.l_hand = null
	H.u_equip(belt)
	belt.loc = T
	boot_sheath.hold.handle_item_insertion(flint_knife, TRUE)
	wt_check(flint_knife.loc == boot_sheath.hold, "the knife sits in the boot sheath")
	boots.loc = H
	H.shoes = boots
	wt_check(H.reach_worn_tool(/obj/item/weapon/material/kitchen/utensil/knife) == flint_knife, "a knife in a worn boot sheath is at hand")
	boots.attack_hand(H)
	wt_check(flint_knife.loc == H && (H.r_hand == flint_knife || H.l_hand == flint_knife), "clicking the worn boot draws the knife into the hand")

	// A shoe saved with a knife in its old hidden place drops it on load.
	var/obj/item/clothing/shoes/old = new(T)
	var/obj/item/weapon/material/kitchen/utensil/knife/stale = new(old)
	old.after_load()
	wt_check(stale.loc == T, "an old hidden boot knife drops beside the shoe on load")
