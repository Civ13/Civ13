
/obj/structure/sign/crest
	name = "house crest"
	desc = "The crest of one of the houses."
	icon = 'icons/misc/crests.dmi'
	icon_state = ""

/obj/structure/sign/crest/small
	name = "house crest"
	desc = "The crest of one of the houses."
	icon = 'icons/misc/crests_small.dmi'
	icon_state = ""

/obj/structure/sign/crest/llanboarwart
	name = "Llanboarwart crest"
	desc = "The crest of L.A.M.E., Llanboarwart Academy of Magical Education."
	icon_state = "llanboarwart"

/obj/structure/sign/crest/small/llanboarwart
	name = "Llanboarwart crest"
	desc = "The crest of L.A.M.E., Llanboarwart Academy of Magical Education."
	icon_state = "llanboarwart"

/obj/structure/sign/crest/mintysnek
	name = "Mintysnek crest"
	desc = "The crest of the Mintysnek house. A minty green lizard and a leek."
	icon_state = "mintysnek"

/obj/structure/sign/crest/small/mintysnek
	name = "Mintysnek crest"
	desc = "The crest of the Mintysnek house. A minty green lizard and a leek."
	icon_state = "mintysnek"

/obj/structure/sign/crest/rubywyrm
	name = "Rubywyrm crest"
	desc = "The crest of the Rubywyrm house. A welsh dragon coiled around a ruby."
	icon_state = "rubywyrm"

/obj/structure/sign/crest/small/rubywyrm
	name = "Rubywyrm crest"
	desc = "The crest of the Rubywyrm house. A welsh dragon coiled around a ruby."
	icon_state = "rubywyrm"

/obj/structure/sign/crest/slatepie
	name = "Slatepie crest"
	desc = "The crest of the Slatepie house. A magpie sitting on top of welsh slate."
	icon_state = "slatepie"

/obj/structure/sign/crest/small/slatepie
	name = "Slatepie crest"
	desc = "The crest of the Slatepie house. A magpie sitting on top of welsh slate."
	icon_state = "slatepie"

/obj/structure/sign/crest/mustardweasel
	name = "Mustardweasel crest"
	desc = "The crest of the Mustardweasel house. A ferret with a daffodil over its ear."
	icon_state = "mustardweasel"

/obj/structure/sign/crest/small/mustardweasel
	name = "Mustardweasel crest"
	desc = "The crest of the Mustardweasel house. A ferret with a daffodil over its ear."
	icon_state = "mustardweasel"

/obj/structure/sign/house_points
	name = "L.A.M.E. House Points Board"
	desc = "A board displaying up-to-date house points for the four houses."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "house_points"

/obj/structure/sign/house_points/examine(mob/user, distance)
	if (map.ID == MAP_WIZARD_BOY)
		var/obj/map_metadata/wizard_boy/WB = map
		var/leading_house = "None"
		var/max_score = 0
		var/leading_house_color = "#FFFFFF" // Default white for "None"
		for(var/house in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")) // Iterate to find the leading house
			var/score = WB.house_points[house]
			if (score > max_score)
				max_score = score
				leading_house = house
				switch(house) // Determine color for the leading house
					if("Rubywyrm")
						leading_house_color = "#CF0000"
					if("Mintysnek")
						leading_house_color = "#00CF00"
					if("Slatepie")
						leading_house_color = "#0000CF"
					if("Mustardweasel")
						leading_house_color = "#FFD700"

		to_chat(user, "<font size=4 class='wizard'>Current Leading House: <span style='color:[leading_house_color]'><b>[leading_house]</b></span></font>")

		for(var/house in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")) // Iterate to display all house scores
			var/score = WB.house_points[house]
			if (house == "Rubywyrm")
				to_chat(user, "<font size=4 class='wizard' style='color:#CF0000'>Rubywyrm: [score]</font>")
			else if (house == "Mintysnek")
				to_chat(user, "<font size=4 class='wizard' style='color:#00CF00'>Mintysnek: [score]</font>")
			else if (house == "Slatepie")
				to_chat(user, "<font size=4 class='wizard' style='color:#0000CF'>Slatepie: [score]</font>")
			else if (house == "Mustardweasel")
				to_chat(user, "<font size=4 class='wizard' style='color:#FFD700'>Mustardweasel: [score]</font>")

	return TRUE


/obj/structure/vending/sales/wizards
	name = "Arcane Supplies vending machine"
	desc = "An overpriced vending machine that sells various magical items. It accepts coins, but it seems to have a strange fondness for chocolate."
	icon_state = "arcane"
	owner = "Arcane Supplies Co."
	products = list(
		/obj/item/weapon/reagent_containers/food/drinks/bottle/small/not_butter_beer = 15,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/small/green_goop = 15,
		/obj/item/weapon/reagent_containers/food/snacks/chocotoad = 15,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/drinks/bottle/small/not_butter_beer = 20,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/small/green_goop = 20,
		/obj/item/weapon/reagent_containers/food/snacks/chocotoad = 20,
	)

/obj/structure/vending/sales/wands
	name = "Wand-O-Mat"
	desc = "An overpriced vending machine that sells pre-made magical wands. Only qualified students may purchase."
	icon_state = "wands"
	owner = "Arcane Supplies Co."
	products = list(
		/obj/item/weapon/material/magic/wand/crafted/standard = 10,
		/obj/item/weapon/material/magic/wand/crafted/sniper = 5,
		/obj/item/weapon/material/magic/wand/crafted/mugger = 5,
		/obj/item/weapon/material/magic/wand/crafted/ghost = 5,
		/obj/item/weapon/material/magic/wand/crafted/gambler = 5,
		/obj/item/weapon/material/magic/wand/crafted/swamp_thing = 5,
		/obj/item/weapon/material/magic/wand/crafted/chaos_stick = 5,
		/obj/item/weapon/material/magic/wand/crafted/cowards_out = 5
	)
	prices = list(
		/obj/item/weapon/material/magic/wand/crafted/standard = 50,
		/obj/item/weapon/material/magic/wand/crafted/sniper = 150,
		/obj/item/weapon/material/magic/wand/crafted/mugger = 100,
		/obj/item/weapon/material/magic/wand/crafted/ghost = 100,
		/obj/item/weapon/material/magic/wand/crafted/gambler = 75,
		/obj/item/weapon/material/magic/wand/crafted/swamp_thing = 200,
		/obj/item/weapon/material/magic/wand/crafted/chaos_stick = 120,
		/obj/item/weapon/material/magic/wand/crafted/cowards_out = 100
	)

	attack_hand(mob/user)
		if (istype(map, /obj/map_metadata/wizard_boy) && ishuman(user))
			var/obj/map_metadata/wizard_boy/WB = map
			if (user.client && WB.check_level(user.client.ckey) == "0")
				to_chat(user, SPAN_WARNING("The machine buzzes. You do not have the required qualification to purchase a wand!"))
				return
		return ..()

/obj/structure/magic/wand_registration
	name = "wand registration service"
	desc = "A terminal used to register your personal wand combination with the school's records."
	icon = 'icons/obj/computers.dmi'
	icon_state = "lab_on"
	density = TRUE
	anchored = TRUE

	attack_hand(mob/user)
		if (!ishuman(user))
			return
		var/mob/living/human/H = user
		if (istype(map, /obj/map_metadata/wizard_boy))
			var/obj/map_metadata/wizard_boy/WB = map
			if (H.client && WB.check_level(H.client.ckey) == "0")
				to_chat(H, SPAN_WARNING("The terminal displays: 'ERROR: Qualification Level I.D.I.O.T. detected. Please contact a professor.'"))
				return
			
			var/obj/item/weapon/material/magic/wand/crafted/W = null
			if (istype(H.get_active_hand(), /obj/item/weapon/material/magic/wand/crafted))
				W = H.get_active_hand()
			else if (istype(H.get_inactive_hand(), /obj/item/weapon/material/magic/wand/crafted))
				W = H.get_inactive_hand()

			if (!W)
				to_chat(H, SPAN_WARNING("You must be holding a crafted wand to register it!"))
				return
			
			var/choice = alert(H, "Do you want to save this [W.name] and replace your stored one?", "Wand Registration", "Yes", "No")
			if (choice == "Yes")
				if (get_dist(H, src) > 1 || (H.get_active_hand() != W && H.get_inactive_hand() != W))
					return
				WB.save_wand_mob(H)
				to_chat(H, SPAN_NOTICE("Wand registration successful. Your [W.name] has been recorded."))
				playsound(src.loc, 'sound/machines/computer/beep.ogg', 50, FALSE)
		else
			to_chat(H, SPAN_WARNING("The service is currently unavailable."))

/obj/structure/sign/signpost/llanboarwart/New()
	..()
	desc = "<b>NORTH:</b>Main Hall. <b>EAST:</b> Mop Ball Field & Gardens. <b>SOUTH:</b> Main Entrance (to Cwm-Tlawd Valley)."
	spawn(1)
//		overlays += icon(icon, "signpost_west")
		overlays += icon(icon, "signpost_north")
		overlays += icon(icon, "signpost_east")
		overlays += icon(icon, "signpost_south")

/obj/structure/sign/signpost/llanboarwart/outside/New()
	..()
	desc = "<b>NORTH:</b>Llanboarwart Academy of Magical Education. <b>EAST:</b> Dark Forest. <b>WEST:</b> Cwm-Tlawd Village."
	spawn(1)
		overlays += icon(icon, "signpost_west")
		overlays += icon(icon, "signpost_north")
		overlays += icon(icon, "signpost_east")
//		overlays += icon(icon, "signpost_south")

/obj/structure/gem_lever
	name = "G.E.M. Trial Lever"
	desc = "Pull this lever to start the dueling club defense trial. You must be qualification level 2 (C.O.A.L.) to take the test."
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_wood_none"
	anchored = TRUE
	density = TRUE
	var/cooldown = 0

/obj/structure/gem_lever/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (!H.client)
		return
	if (world.time < cooldown)
		to_chat(H, SPAN_WARNING("The trial is resetting. Please wait a moment."))
		return

	if (!map || !istype(map, /obj/map_metadata/wizard_boy))
		to_chat(H, SPAN_WARNING("The trial is only available at Llanboarwart Academy."))
		return

	var/obj/map_metadata/wizard_boy/WB = map
	var/level = WB.check_level(H.client.ckey)
	if (level != "2")
		if (level == "0" || level == "1")
			to_chat(H, SPAN_WARNING("You must be qualification level 2 (C.O.A.L.) to start this trial!"))
		else
			to_chat(H, SPAN_WARNING("You have already completed this qualification level!"))
		return

	// Resolve the designated dueling square landmark
	var/turf/gem_turf = null
	if (latejoin_turfs && latejoin_turfs["GEM_location"])
		var/turfs_entry = latejoin_turfs["GEM_location"]
		if (islist(turfs_entry) && length(turfs_entry) > 0)
			gem_turf = turfs_entry[1]
		else if (istype(turfs_entry, /turf))
			gem_turf = turfs_entry

	if (!gem_turf)
		to_chat(H, SPAN_WARNING("The dueling circle landmark is missing. Please contact an administrator."))
		return

	// Player must be standing on the GEM_location turf to start
	if (get_turf(H) != gem_turf)
		to_chat(H, SPAN_WARNING("You must stand in the designated dueling circle before pulling the lever!"))
		return

	// Check for an existing active dummy
	var/obj/effect/spawner/mobspawner/training_dummy/spawner = null
	for(var/obj/effect/spawner/mobspawner/training_dummy/S in world)
		if(S.z == src.z && get_dist(src, S) <= 8)
			spawner = S
			break

	if (!spawner)
		to_chat(H, SPAN_WARNING("Cannot find the training dummy spawner nearby!"))
		return

	var/mob/living/simple_animal/hostile/wizard/training_dummy/existing_dummy in range(7, src)
	if (existing_dummy)
		to_chat(H, SPAN_WARNING("A trial is already in progress!"))
		return

	cooldown = world.time + 100 // 10s cooldown

	// Activate spawner to produce the dummy
	spawner.activated = TRUE
	spawner.spawnTarget()
	spawner.activated = FALSE

	var/mob/living/simple_animal/hostile/wizard/training_dummy/TD in range(7, spawner)
	if (!TD)
		to_chat(H, SPAN_WARNING("Failed to spawn the training dummy. Please try again."))
		return

	TD.active_student = H
	TD.phase = 1
	TD.blocks_done = 0
	TD.dir = get_dir(TD, H)
	H.dir = get_dir(H, TD)

	to_chat(H, SPAN_NOTICE("<b>Trial started!</b> Deflect 3 spells with <b>Blockum!</b>, then disarm the dummy with <b>Dropus!</b>. Do NOT leave the circle!"))

	// Monitor student position — abort if they leave the dueling square
	spawn(0)
		while (TD && !isnull(TD.loc) && TD.active_student == H)
			sleep(5) // check every 0.5 seconds
			if (!TD || isnull(TD.loc))
				break // trial already finished naturally
			if (TD.active_student != H)
				break // trial ended another way
			if (get_turf(H) != gem_turf || H.stat)
				TD.abort_trial()
				break

/obj/structure/chemical_dispenser/potions
	amount = 5
	is_medical = FALSE
	New()
		..()
		var/list/elements = list("hydrogen", "helium", "lithium", "nitrogen", "oxygen", "fluorine", "sodium", "magnesium", "aluminum", "silicon", "phosphorus", "chlorine", "potassium", "calcium", "arsenic", "iodine", "tungsten", "radium", "thorium", "bromine", "ammonia", "adrenaline", "blood", "chloralhydrate", "coffee", "condensedcapsaicin", "ethanol", "goldschlager", "milk", "mindbreaker", "paracetamol", "protein", "sugar", "water", "wine")
		for (var/i in elements)
			dispensable_reagents += list(list(i,100))

/obj/structure/bookcase/filled_magic
	icon_state = "book-3"

/obj/structure/bookcase/filled_magic/initialize()
	new /obj/item/weapon/book/manual/wand_crafting(src)
	new /obj/item/weapon/book/manual/wand_crafting(src)
	new /obj/item/weapon/book/manual/potions(src)
	new /obj/item/weapon/book/manual/potions(src)
	new /obj/item/weapon/book/manual/student_handbook(src)
	new /obj/item/weapon/book/manual/student_handbook(src)
	update_icon()
	..()