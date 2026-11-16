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

	// Fire pouch: a flint inside lights a held candle against the worn pouch.
	var/mob/living/human/wt_probe/F = new
	F.loc = T
	F.may_do_after = TRUE
	var/obj/item/clothing/under/tunic = new(F)
	F.w_uniform = tunic
	var/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/fire = new(T)
	var/obj/item/clothing/accessory/storage/belt_pouch/plain = new(T)
	wt_check(tunic.can_attach_accessory(fire), "a fire pouch hangs from clothes")
	tunic.accessories += fire
	fire.on_attached(tunic, null)
	tunic.accessories += plain
	plain.on_attached(tunic, null)
	var/obj/item/weapon/flint/firestone = new(T)
	var/obj/item/stack/material/wood/stick = new(T)
	wt_check(fire.hold.can_be_inserted(firestone, TRUE), "a flint goes in the fire pouch")
	wt_check(!fire.hold.can_be_inserted(stick, TRUE), "wood does not")
	var/obj/item/weapon/flame/candle/C = new(F)
	F.r_hand = C
	F.hand = FALSE
	wt_check(!fire.light_held(C, F), "an empty fire pouch makes no spark")
	fire.hold.handle_item_insertion(firestone, TRUE)
	var/lit_now = FALSE
	for (var/i in 1 to 20)
		if (C.lit)
			break
		tunic.attackby(C, F)
	lit_now = C.lit
	wt_check(lit_now, "a candle held against clothes with a fire pouch lights from its flint")
	wt_check(C.loc == F && !plain.hold.contents.len, "the candle stays in hand, not in the plain pouch beside it")
	wt_check(!fire.sparking && !isflamesource(fire), "the pouch is no flame once the candle is lit")

	// Fire drill in hand: an ember for a few seconds.
	var/obj/item/weapon/flame/fire_drill/drill = new(F)
	F.r_hand = drill
	drill.attack_self(F)
	wt_check(drill.lit && isflamesource(drill), "a fire drill spun in hand makes an ember")
	drill.snuff()

	// Needle case: sinew in the worn case mends a damaged garment.
	var/obj/item/clothing/accessory/storage/needle_case/case = new(T)
	var/obj/item/weapon/bone_needle/needle = new(T)
	var/obj/item/stack/sinew/sinew = new(T)
	sinew.amount = 3
	wt_check(case.hold.can_be_inserted(needle, TRUE) && case.hold.can_be_inserted(sinew, TRUE), "the case takes a needle and sinew")
	wt_check(!case.hold.can_be_inserted(stick, TRUE), "the case takes nothing else")
	tunic.accessories += case
	case.on_attached(tunic, null)
	case.hold.handle_item_insertion(sinew, TRUE)
	wt_check(F.needle_case_thread() == sinew, "sinew in a worn needle case is found for mending")
	var/obj/item/clothing/under/torn = new(T)
	torn.health = max(1, initial(torn.health) - 5)
	F.r_hand = needle
	needle.loc = F
	F.l_hand = null
	needle.afterattack(torn, F, TRUE)
	wt_check(torn.health > max(1, initial(torn.health) - 5) && sinew.amount == 2, "the needle mends with sinew from the case")
	var/obj/item/clothing/accessory/storage/belt_pouch/leather_box = new(T)
	var/obj/item/stack/material/leather/hide = new(leather_box.hold)
	tunic.accessories -= case
	case.has_suit = null
	wt_check(!F.needle_case_thread(), "without the case, no thread is reached (not even leather in a pouch)")

	// Neck sheath: a small knife only.
	var/obj/item/clothing/accessory/storage/sheath/neck/neck = new(T)
	var/obj/item/weapon/material/kitchen/utensil/knife/flint/small = new(T)
	var/obj/item/weapon/material/kitchen/utensil/knife/butcher/big = new(T)
	wt_check(neck.hold.can_be_inserted(small, TRUE) && !neck.hold.can_be_inserted(big, TRUE), "a neck sheath takes a small knife, not a butcher knife")
	wt_check(tunic.can_attach_accessory(neck), "a neck sheath hangs from clothes")
	hide.loc = T

	// Pendant hone: a chipped blade clicked on clothes with a hone is honed, not pouched.
	var/mob/living/human/wt_probe/G = new
	G.loc = T
	var/obj/item/clothing/under/smock = new(G)
	G.w_uniform = smock
	var/obj/item/clothing/accessory/storage/belt_pouch/side = new(T)
	var/obj/item/clothing/accessory/pendant_hone/hone = new(T)
	smock.accessories += side
	side.on_attached(smock, null)
	smock.accessories += hone
	hone.on_attached(smock, null)
	var/obj/item/weapon/material/kitchen/utensil/knife/iron/blade = new(G)
	blade.unbreakable = FALSE
	blade.maxhealth = 20
	blade.health = 10
	G.r_hand = blade
	G.hand = FALSE
	smock.attackby(blade, G)
	wt_check(blade.loc == G && !side.hold.contents.len, "a chipped knife is honed, not put in the pouch beside the hone")
	wt_check(blade.health == 16 && blade.maxhealth == 16, "honing gives +6 condition and costs 4 most condition")

	// Strike-a-light pouch: a better-odds fire pouch.
	var/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/strike_a_light/sal = new(T)
	wt_check(sal.spark_chance > 70 && istype(sal, /obj/item/clothing/accessory/storage/belt_pouch), "the strike-a-light pouch sparks better and counts as a pouch")

	// Chatelaine: small tools only, and a needle case on it still feeds the needle.
	var/obj/item/clothing/accessory/storage/chatelaine/chat = new(T)
	var/obj/item/weapon/material/kitchen/utensil/knife/flint/chat_knife = new(T)
	var/obj/item/clothing/accessory/storage/needle_case/chat_case = new(T)
	var/obj/item/stack/sinew/chat_sinew = new(chat_case.hold)
	wt_check(chat.hold.can_be_inserted(chat_knife, TRUE) && chat.hold.can_be_inserted(chat_case, TRUE), "a chatelaine takes a small knife and a needle case")
	wt_check(!chat.hold.can_be_inserted(stick, TRUE) && !chat.hold.can_be_inserted(big, TRUE), "a chatelaine refuses wood and a butcher knife")
	smock.accessories += chat
	chat.on_attached(smock, null)
	chat.hold.handle_item_insertion(chat_case, TRUE)
	wt_check(G.needle_case_thread() == chat_sinew, "sinew in a needle case on a chatelaine is found")
	chat.hold.handle_item_insertion(chat_knife, TRUE)
	wt_check(G.reach_worn_tool(/obj/item/weapon/material/kitchen/utensil/knife) == chat_knife, "a knife on a chatelaine is at hand")
