// Native probe for dirt from work and dirty hands (hygiene_work.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/hygiene_work/hygiene_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/hygiene_probe/New()
	return
var/hw_failures = 0
var/hw_runtime_error = FALSE
/proc/hw_check(condition, label)
	if (!condition)
		hw_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hw_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/hygiene_probe
		hw_checks()
	catch(var/exception/e)
		hw_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hw_failures, "runtime_error" = hw_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/mob/living/human/hw_tester/New()
	return

/mob/living/human/hw_tester/adaptStat(statname, multiplier = 1, variety_key = null)
	if (statname == "farming")
		soil(1)

/mob/living/human/hw_tester/update_icons()
	return
/mob/living/human/hw_tester/update_inv_gloves(update_icons = TRUE)
	return
/mob/living/human/hw_tester/update_inv_shoes(update_icons = TRUE)
	return

/proc/hw_checks()
	var/mob/living/human/hw_tester/H = new(locate(2, 2, 1))
	H.hygiene = 200
	H.soil(3, DIRTY_HANDS_GRIME)
	hw_check(H.hygiene == 197 && H.dirty_hands == DIRTY_HANDS_GRIME, "butchering dirties body and hands ([H.hygiene], [H.dirty_hands])")
	H.soil(5, DIRTY_HANDS_WASTE)
	hw_check(H.dirty_hands == DIRTY_HANDS_WASTE, "waste makes the hands worse")
	H.soil(1, DIRTY_HANDS_GRIME)
	hw_check(H.dirty_hands == DIRTY_HANDS_WASTE, "grime never lessens waste on the hands")
	H.wash_hands()
	hw_check(!H.dirty_hands, "washing clears the hands")
	H.adaptStat("farming", 1)
	hw_check(H.hygiene == 190 && !H.dirty_hands, "farm work dirties the body, not the hands ([H.hygiene])")
	H.gloves = new /obj/item/clothing/gloves(H)
	H.soil(0, DIRTY_HANDS_WASTE)
	hw_check(!H.dirty_hands, "gloves keep the hands clean")
	H.gloves = null
	hw_check(HYGIENE_FACTOR == 0.015, "idle dirt is slower (0.015 a second)")

	// Freshly bathed: once on reaching 200 from below, not again soon.
	H.hygiene = 150
	var/mood_before = H.mood
	H.raise_hygiene(200)
	hw_check(H.hygiene == 200 && H.mood == mood_before + 3, "a wash to 200 gives freshly bathed ([H.mood - mood_before])")
	H.hygiene = 150
	mood_before = H.mood
	H.raise_hygiene(200)
	hw_check(H.mood == mood_before, "freshly bathed waits twenty minutes")

	// Tubs hold their own water on Persistence maps.
	map.persistence = TRUE
	var/obj/structure/shower/bathtub/wooden/tub = new(locate(6, 3, 1))
	tub.attack_hand(H)
	hw_check(!tub.on, "a dry tub will not run")
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(locate(6, 2, 1))
	B.reagents.add_reagent("water", 150)
	hw_check(tub.attackby(B, H) && tub.water_store == 100, "a bucket fills the tub to its tank")
	tub.attack_hand(H)
	hw_check(tub.on && tub.water_store == 0, "running the tub takes a tubful")
	var/obj/structure/shower/bathtub/steel/steel_tub = new(locate(1, 3, 1))
	hw_check(steel_tub.water_per_use == 80, "a steel tub takes less water")
	map.persistence = FALSE
	var/obj/structure/shower/bathtub/wooden/round_tub = new(locate(1, 1, 1))
	round_tub.attack_hand(H)
	hw_check(round_tub.on, "tubs run free on round maps")

	// Washing one part (body_washing.dm).
	var/obj/item/organ/external/hand/hand = new
	var/obj/item/organ/external/leg/leg = new
	var/obj/item/organ/external/chest/chest = new
	H.organs_by_name = list("l_hand" = hand, "l_leg" = leg, "chest" = chest)
	H.dirty_hands = DIRTY_HANDS_WASTE
	H.bloody_hands = 2
	hw_check(H.wash_body_part("l_hand") && !H.dirty_hands && !H.bloody_hands, "washing a hand clears dirty and bloody hands")
	H.hygiene = 100
	hw_check(H.wash_body_part("l_leg") && H.hygiene == 110, "washing a bare leg raises cleanliness by 10 ([H.hygiene])")
	H.hygiene = 170
	H.wash_body_part("l_leg")
	hw_check(H.hygiene == 175, "part washing stops at a sponge bath's 175 ([H.hygiene])")
	var/obj/item/clothing/under/U = new(H)
	U.body_parts_covered = LEGS
	U.blood_DNA = list("x" = "O+")
	H.w_uniform = U
	H.hygiene = 100
	H.wash_body_part("l_leg")
	hw_check(!U.blood_DNA && H.hygiene == 100, "washing a clothed leg cleans the clothes, not the skin")
	H.w_uniform = null
	hw_check(!H.wash_body_part("r_foot"), "a missing part cannot be washed")
	hw_check(container_washes_zone("l_leg") && container_washes_zone("chest") && !container_washes_zone("mouth"), "only the mouth drinks from a container")
	hw_check(source_washes_zone("chest") && !source_washes_zone("r_hand"), "sinks keep the hand wash for hands")

	// Wounds: water halves germs, soap disinfects.
	var/datum/wound/cut/small/W = new(10)
	W.germ_level = 80
	leg.wounds = list(W)
	leg.germ_level = 60
	H.wash_body_part("l_leg")
	hw_check(W.germ_level == 40 && leg.germ_level == 30 && !W.disinfected, "water halves the germs in a wound ([W.germ_level], [leg.germ_level])")
	H.wash_body_part("l_leg", TRUE)
	hw_check(W.disinfected && !W.germ_level && !leg.germ_level, "soap disinfects the wound")
	leg.germ_level = INFECTION_LEVEL_ONE + 50
	H.wash_body_part("l_leg")
	hw_check(leg.germ_level == INFECTION_LEVEL_ONE + 50, "washing does not cure an infection set in")
	H.hygiene = 230
	H.wash_body_part("l_leg", TRUE)
	hw_check(H.hygiene == 250, "soap washing reaches 250 ([H.hygiene])")

	// Drinking takes the mouth.
	var/obj/item/weapon/reagent_containers/glass/bucket/cup = new(locate(3, 2, 1))
	cup.reagents.add_reagent("water", 20)
	H.targeted_organ = "chest"
	H.water = 0
	cup.standard_feed_mob(H, H)
	hw_check(cup.reagents.get_reagent_amount("water") == 20, "a container will not drink at the chest")

	// A mug of water washes any part but the mouth, on help intent.
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/mug/mug = new(locate(3, 2, 1))
	mug.reagents.add_reagent("water", 20)
	H.a_intent = I_HELP
	H.targeted_organ = "chest"
	hw_check(mug.washes_on_click(H, H), "a mug of water washes the chest on help intent")
	H.targeted_organ = "mouth"
	hw_check(!mug.washes_on_click(H, H), "a mug at the mouth drinks")
	H.targeted_organ = "chest"
	H.a_intent = I_HARM
	hw_check(!mug.washes_on_click(H, H), "a mug off help intent does not wash")
	H.a_intent = I_HELP

	// Self-examine shows which parts need washing.
	H.w_uniform = null
	H.gloves = null
	H.washed_parts = null
	H.hygiene = 150
	hw_check(H.part_dirt_status(leg) == "dirty" && H.part_dirt_status(chest) == "dirty", "below clean, unwashed parts show dirty")
	H.wash_body_part("l_leg")
	hw_check(H.part_dirt_status(leg) == "" && H.part_dirt_status(chest) == "dirty", "a washed leg shows clean while the chest stays dirty")
	H.hygiene -= 30
	hw_check(H.part_dirt_status(leg) == "dirty", "a washed part gets dirty again as cleanliness falls")
	H.hygiene = 50
	hw_check(H.part_dirt_status(chest) == "filthy", "very dirty parts show filthy")
	H.hygiene = HYGIENE_LEVEL_NORMAL
	hw_check(H.part_dirt_status(chest) == "", "clean people show no dirt")
	H.hygiene = 150
	H.dirty_hands = DIRTY_HANDS_WASTE
	hw_check(H.part_dirt_status(hand) == "dirty", "dirty hands show on the hand")
	H.dirty_hands = 0

	// Every hand wash (open water, sinks, taps) leaves bare hands clean on
	// self-examine, even while the rest of the body is below clean.
	H.washed_parts = null
	H.hygiene = 150
	H.dirty_hands = DIRTY_HANDS_WASTE
	H.clean_blood()
	hw_check(!H.dirty_hands && H.part_dirt_status(hand) == "" && H.part_dirt_status(chest) == "dirty", "a hand wash shows the hand clean on self-examine")
	// A whole-body wash that stops short of clean still cleans every bare part.
	H.washed_parts = null
	H.organs = list(hand, leg, chest)
	H.mark_bare_parts_washed()
	hw_check(H.part_dirt_status(leg) == "" && H.part_dirt_status(chest) == "" && H.part_dirt_status(hand) == "", "a bath below clean shows bare parts clean")

	// Washing moves on to the next bare part that needs it, head to feet.
	H.washed_parts = null
	H.hygiene = 150
	hw_check(H.next_dirty_zone() == "chest", "washing starts with the first dirty part ([H.next_dirty_zone()])")
	hw_check(H.next_dirty_zone(list("chest")) == "l_hand", "then moves to the next ([H.next_dirty_zone(list("chest"))])")
	H.wash_body_part("l_hand")
	hw_check(H.next_dirty_zone(list("chest")) == "l_leg", "washed parts are skipped ([H.next_dirty_zone(list("chest"))])")
	H.hygiene = HYGIENE_LEVEL_NORMAL
	hw_check(isnull(H.next_dirty_zone()), "a clean body leaves nothing to wash")
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/mug/mug2 = new(locate(3, 2, 1))
	mug2.reagents.add_reagent("water", 12)
	hw_check(mug2.wash_spend(H) && mug2.reagents.get_reagent_amount("water") == 7, "a mug pays 5 water a part")
	hw_check(!mug2.wash_spend(H), "a mug stops when it cannot pay for another part")

	// The hygiene feeling follows the parts self-examine marks.
	H.w_uniform = null
	H.gloves = null
	H.dirty_hands = 0
	H.washed_parts = null
	H.hygiene = 150
	hw_check(H.hygiene_feeling() == "You feel a bit dirty.", "unwashed parts feel a bit dirty ([H.hygiene_feeling()])")
	H.wash_body_part("l_hand")
	H.wash_body_part("l_leg")
	H.wash_body_part("chest")
	hw_check(H.hygiene < HYGIENE_LEVEL_NORMAL && findtext(H.hygiene_feeling(), "fairly clean"), "washing every part with water no longer feels a bit dirty ([H.hygiene], [H.hygiene_feeling()])")
	H.washed_parts = null
	var/obj/item/clothing/under/shirt = new(H)
	shirt.body_parts_covered = UPPER_TORSO
	H.w_uniform = shirt
	H.wash_body_part("l_hand")
	H.wash_body_part("l_leg")
	hw_check(findtext(H.hygiene_feeling(), "under your clothes"), "only covered skin left unwashed says to undress ([H.hygiene_feeling()])")
	H.w_uniform = null
	hw_check(H.hygiene_feeling() == "You feel a bit dirty.", "undressed, the unwashed chest feels a bit dirty again")
