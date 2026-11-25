// Called by the isolated animal-harvest world. The test actor has no
// connected client and does not run normal mob startup.
/mob/living/sinew_conversion_tester/New()
	return

/proc/harvest_sinew_conversion_regression(turf/site)
	var/mob/living/sinew_conversion_tester/user = new(site)
	var/obj/item/stack/sinew/input = new(user, 3)
	user.hand = 0
	user.r_hand = input
	var/obj/item/stack/material/rope/hand_bundle = new(user, 4, FALSE)
	user.l_hand = hand_bundle
	var/obj/item/stack/material/rope/ground_bundle = new(site, 1, FALSE)

	input.attack_self(user)
	harvest_assert(input.amount == 2 && hand_bundle.amount == 5 && ground_bundle.amount == 1 && harvest_count(site, /obj/item/stack/material/rope) == 1, "Sinew did not prefer compatible rope in the other hand")

	hand_bundle.amount = hand_bundle.max_amount
	input.attack_self(user)
	harvest_assert(input.amount == 1 && hand_bundle.amount == hand_bundle.max_amount && ground_bundle.amount == 2 && harvest_count(site, /obj/item/stack/material/rope) == 1, "Full hand bundle did not fall back to ground rope")
	harvest_assert(ground_bundle.icon_state == "rope[pile_suffix(2, list(2, 8, 20))]" && ground_bundle.gender == PLURAL, "Stack appearance did not refresh after adding sinew rope")

	ground_bundle.amount = ground_bundle.max_amount
	var/obj/item/stack/material/rope/anchored_bundle = new(site, 1, FALSE)
	anchored_bundle.anchored = TRUE
	var/obj/item/stack/material/rope/incompatible_bundle = new(site, 2, FALSE)
	incompatible_bundle.color = "#FF0000"
	var/obj/item/stack/material/rope/remote_bundle = new(get_step(site, EAST), 1, FALSE)
	input.attack_self(user)
	var/obj/item/stack/material/rope/new_cord
	for (var/obj/item/stack/material/rope/bundle in site)
		if (!QDELETED(bundle) && bundle.name == "sinew binding cord")
			new_cord = bundle
	harvest_assert(QDELETED(input) && ground_bundle.amount == ground_bundle.max_amount && hand_bundle.amount == hand_bundle.max_amount, "Last sinew portion was not consumed exactly once or overfilled a stack")
	harvest_assert(anchored_bundle.amount == 1 && incompatible_bundle.amount == 2 && remote_bundle.amount == 1, "Conversion merged into an anchored, incompatible, or out-of-scope bundle")
	harvest_assert(new_cord?.amount == 1 && harvest_count(site, /obj/item/stack/material/rope) == 4, "No-room fallback did not leave exactly one cord on the ground")
	qdel(remote_bundle)
	harvest_clear(site)
	qdel(user)
