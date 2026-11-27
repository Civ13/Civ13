// Native probe for bee farming 4b and 5: the bee veil and beekeeper suit
// (bee_gear.dm, bee_sting_chance in wild_bees.dm), sealing wax
// (sealing_wax.dm) and mead fermenting in a closed barrel (mead.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/bee_products/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/bee_products_probe/New()
	map = src
/mob/living/human/bee_products_probe
	var/obj/item/probe_hand = null
/mob/living/human/bee_products_probe/New()
	icon_update = FALSE
	return
/mob/living/human/bee_products_probe/get_active_hand()
	return probe_hand
/mob/living/human/bee_products_probe/restrained()
	return FALSE
/mob/living/human/bee_products_probe/drop_from_inventory(obj/item/W, atom/target = null)
	if (l_hand == W)
		l_hand = null
	if (r_hand == W)
		r_hand = null
	W.loc = target ? target : loc
	return TRUE

var/bp_failures = 0
var/bp_runtime_error = FALSE
/proc/bp_check(condition, label)
	if (!condition)
		bp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bp_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/bee_products_probe
		populate_material_list()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		bee_product_checks()
	catch(var/exception/e)
		bp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bp_failures, "runtime_error" = bp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
	return

/proc/bee_product_checks()
	var/turf/T = locate(10, 10, 1)
	var/mob/living/human/bee_products_probe/H = new(T)
	H.stat = CONSCIOUS
	H.real_name = "Ada Reeve"

	// Veil and suit.
	bp_check(bee_sting_chance(H) == 70, "a bare body is stung often")
	H.head = new /obj/item/clothing/head/bee_veil(H)
	bp_check(bee_sting_chance(H) == 40, "a bee veil cuts stings more than a hat")
	H.wear_suit = new /obj/item/clothing/suit/beekeeper_suit(H)
	bp_check(bee_sting_chance(H) == 10, "veil and suit together cut stings sharply")
	H.gloves = new /obj/item/clothing/gloves(H)
	bp_check(bee_sting_chance(H) == 2, "with gloves too, stings are rare but possible")
	var/obj/item/clothing/head/hat = new /obj/item/clothing/head(H)
	H.head = hat
	bp_check(bee_sting_chance(H) == 15, "an ordinary hat protects less than a veil")
	H.head = null
	H.wear_suit = null
	H.gloves = null

	// Sealing wax sticks.
	var/obj/item/sealing_wax/W = new(H, "blue")
	bp_check(W.wax_colour == "blue" && W.uses == 10 && W.color == sealing_wax_rgb("blue") && findtext(W.name, "blue"), "a stick of blue sealing wax")
	var/obj/item/sealing_wax/red = new(T)
	bp_check(red.wax_colour == "red", "sealing wax is red by default")

	// Envelopes need wax and take its colour.
	var/obj/item/weapon/storage/envelope/E = new(T)
	E.opened = FALSE
	var/obj/item/weapon/stamp/mail/seal = new(H)
	H.l_hand = seal
	H.probe_hand = seal
	E.attackby(seal, H)
	bp_check(!E.sealed, "an envelope cannot be sealed without wax")
	H.r_hand = W
	E.attackby(seal, H)
	bp_check(E.sealed && E.wax_colour == "blue" && W.uses == 9, "sealing an envelope uses wax of the stick's colour")
	E.attackby(seal, H)
	bp_check(W.uses == 9, "a sealed envelope takes no more wax")

	// Paper: wax seals need wax, ink stamps do not.
	var/obj/item/weapon/paper/P = new(T)
	H.r_hand = null
	P.attackby(seal, H)
	bp_check(!length(P.stamped), "a wax seal cannot be pressed without wax")
	H.r_hand = W
	P.attackby(seal, H)
	bp_check(length(P.stamped) == 1 && W.uses == 8, "pressing a wax seal onto paper uses wax")
	var/obj/item/weapon/stamp/approved/ink = new(H)
	H.l_hand = ink
	H.probe_hand = ink
	H.r_hand = null
	P.attackby(ink, H)
	bp_check(length(P.stamped) == 2, "an ink stamp needs no wax")
	bp_check(seal.is_wax_seal() && !ink.is_wax_seal(), "envelope seals are wax seals, ink stamps are not")
	var/obj/item/weapon/stamp/faction_seal/matrix = new(H)
	bp_check(matrix.is_wax_seal(), "a faction seal matrix is a wax seal")

	// The last seal uses up the stick.
	W.uses = 1
	H.l_hand = seal
	H.probe_hand = seal
	H.r_hand = W
	var/obj/item/weapon/paper/P2 = new(T)
	P2.attackby(seal, H)
	bp_check(length(P2.stamped) == 1 && QDELETED(W) && !H.r_hand, "the last seal uses up the stick")

	// Sealing wax needs pitch.
	var/obj/item/weapon/beeswax/cake = new(T)
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(T)
	B.reagents.add_reagent("pitch", 2)
	cake.attackby(B, H)
	bp_check(!QDELETED(cake) && B.reagents.get_reagent_amount("pitch") == 2, "too little pitch makes no sealing wax")

	// Mead: honey and water make must, not mead.
	var/obj/item/weapon/reagent_containers/glass/bucket/pail = new(T)
	pail.reagents.add_reagent("honey", 10)
	pail.reagents.add_reagent("water", 10)
	pail.reagents.process_reactions() // the chemistry process does this in game
	bp_check(pail.reagents.get_reagent_amount("honey_must") == 20 && !pail.reagents.get_reagent_amount("mead"), "honey and water stir into mead must, not mead")
	var/obj/item/weapon/reagent_containers/glass/bucket/sweet = new(T)
	sweet.reagents.add_reagent("enzyme", 5)
	sweet.reagents.add_reagent("sugar", 10)
	sweet.reagents.add_reagent("water", 10)
	sweet.reagents.process_reactions()
	bp_check(!sweet.reagents.get_reagent_amount("mead"), "sugar water no longer turns straight into mead")

	var/obj/item/weapon/reagent_containers/glass/barrel/cask = new(locate(12, 10, 1))
	cask.reagents.add_reagent("honey_must", 40)
	bp_check(cask.is_open_container() && cask.mead_work() == 0, "an open barrel does not ferment")
	cask.flags &= ~OPENCONTAINER
	bp_check(cask.mead_work() == 3 && cask.reagents.get_reagent_amount("mead") == 3, "a closed barrel ferments slowly on wild yeast")
	bp_check(cask.mead_timer, "fermenting schedules the next spell")
	cask.mead_cancel()
	cask.reagents.add_reagent("enzyme", 1)
	bp_check(cask.mead_work() == 10 && cask.reagents.get_reagent_amount("honey_must") == 27, "yeast speeds the fermenting")
	cask.mead_cancel()
	for (var/i = 1, i <= 5, i++)
		cask.mead_work()
		cask.mead_cancel()
	bp_check(!cask.reagents.get_reagent_amount("honey_must") && cask.reagents.get_reagent_amount("mead") == 40, "all the must becomes mead")
	cask.mead_schedule()
	bp_check(!cask.mead_timer, "with no must left nothing is scheduled")

	// Reopening invalidates the pending closed spell, including a batch
	// swapped while open. Reclosing must schedule a fresh full spell.
	cask.attack_self(H) // Open the spent barrel.
	cask.reagents.add_reagent("honey_must", 10)
	cask.attack_self(H) // Close the lid.
	var/stale_timer = cask.mead_timer
	bp_check(stale_timer && timeleft(stale_timer) > 0, "closing a barrel starts a spell")
	cask.attack_self(H) // Open it before that spell completes.
	bp_check(!cask.mead_timer && isnull(timeleft(stale_timer)), "opening a barrel removes its pending spell")
	cask.reagents.remove_reagent("honey_must", 10)
	cask.reagents.add_reagent("honey_must", 5)
	cask.attack_self(H) // Reclose with a new batch.
	bp_check(cask.mead_timer && cask.mead_timer != stale_timer && timeleft(cask.mead_timer) > 1100, "reclosing starts a fresh two-minute spell")
	bp_check(cask.reagents.get_reagent_amount("honey_must") == 5 && cask.reagents.get_reagent_amount("mead") == 40, "lid toggling neither processes fresh must early nor discards fermented mead")
	cask.mead_cancel()
