// Food byproducts deliberately inherit meat processing, nutrition and decay.
// These are food portions, not transplantable human organ datums.
/obj/item/weapon/reagent_containers/food/snacks/meat/offal
	name = "animal giblets"
	desc = "A small portion of edible animal organs. Cook before eating."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "innards"
	rotten_icon_state = "innards"

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/New()
	..()
	reagents.remove_reagent("protein", 3)

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/heart
	name = "animal heart"
	icon_state = "heart-off"
	rotten_icon_state = "heart-x"

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/liver
	name = "animal liver"
	icon_state = "liver"
	rotten_icon_state = "liver-x"

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/kidneys
	name = "animal kidneys"
	icon_state = "kidneys"
	rotten_icon_state = "kidneys-x"

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/lungs
	name = "animal lungs"
	icon_state = "lungs"
	rotten_icon_state = "lungs-x"

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/brain
	name = "animal brain"
	icon_state = "brain"
	rotten_icon_state = "brain-x"

// Art adapted from Pocket Stronghold 13; see the DMI's LICENSE.md.
/obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines
	name = "animal intestines"
	desc = "Edible animal intestines. Use a knife on grab intent to prepare one sausage casing from a whole, fresh, uncooked portion."
	icon = 'icons/obj/food/pocket_stronghold_food.dmi'
	icon_state = "intestines"
	rotten_icon_state = "intestines"

// Grab intent reserves knife preparation for casings; other intents retain meat cutting.
/obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines/attackby(obj/item/weapon/W, mob/user)
	if (!is_tool(W, TOOL_KNIFE) || !user || user.a_intent != I_GRAB)
		return ..()
	if (QDELETED(src) || QDELETED(W) || QDELETED(user) || user.stat != CONSCIOUS || user.get_active_hand() != W)
		return
	var/turf/site = get_turf(user)
	if (!site || (loc != user && loc != site))
		return
	if (!map || map.ordinal_age < 1)
		to_chat(user, SPAN_WARNING("Sausage casings require the Bronze Age or later."))
		return
	if (!raw || roasted || boiled || bitecount || !can_cut_preserved_meat() || radiation > 0 || germ_level > GERM_LEVEL_AMBIENT)
		to_chat(user, SPAN_WARNING("Use whole, fresh, uncooked and uncontaminated intestines."))
		return
	// Casings are non-food stacks and cannot retain food reagents. Refuse added
	// chemicals rather than laundering poison or infection through this recipe.
	if (!reagents || reagents.get_reagent_amount("protein") < 2)
		return
	for (var/datum/reagent/R in reagents.reagent_list)
		if (R.id != "protein")
			to_chat(user, SPAN_WARNING("These intestines contain added substances and cannot become casings."))
			return
	if (loc == user)
		if (!user.canUnEquip(src))
			return
		user.remove_from_mob(src)
		if (QDELETED(src) || loc != site)
			return
	// No wait: retire the one paid input before a stack constructor can merge.
	qdel(src)
	new /obj/item/stack/sausagecasing(site, 1)
	to_chat(user, SPAN_NOTICE("You prepare the intestines into one sausage casing."))

// One bounded stack per carcass. No registration, processing loop or timer.
/obj/item/stack/sinew
	name = "sinew"
	desc = "Animal tendons. Use in hand to twist one portion into binding cord."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	color = "#DFC4AC"
	singular_name = "sinew portion"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/sinew/attack_self(mob/user)
	if (QDELETED(src) || QDELETED(user) || loc != user || amount < 1)
		return
	// Existing rope recipes consume this cord for tools and other bindings.
	if (use(1))
		// Keep the new item live until the hand placement; automatic merging can
		// queue the constructor's returned item for deletion.
		var/obj/item/stack/material/rope/cord = new(get_turf(user), 1, FALSE)
		cord.name = "sinew binding cord"
		user.put_in_any_hand_if_possible(cord)
		to_chat(user, SPAN_NOTICE("You twist the sinew into binding cord."))

/obj/item/stack/grass_cuttings
	name = "grass cuttings"
	desc = "Fresh grass fibres. Use in hand to twist two portions into crude twine."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	color = "#709744"
	singular_name = "grass cutting"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/grass_cuttings/attack_self(mob/user)
	if (QDELETED(src) || QDELETED(user) || loc != user || user.stat != CONSCIOUS || amount < 2)
		return
	if (use(2))
		var/obj/item/stack/crude_twine/cord = new(get_turf(user), 1, FALSE)
		user.put_in_any_hand_if_possible(cord)
		to_chat(user, SPAN_NOTICE("You twist the grass cuttings into crude twine."))

// Weak binding is deliberately separate from general-purpose rope recipes.
/obj/item/stack/crude_twine
	name = "crude twine"
	desc = "Twisted grass fibres. Can bind a flint axe, but the binding wears out quickly."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	color = "#A59A61"
	singular_name = "twine binding"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL

/mob/living/simple_animal
	// Persist only the completed claim; an interrupted wait must not lock a save.
	var/harvested = FALSE
	var/tmp/harvesting = FALSE
	// Hunting skill bonus of whoever is butchering; set only during harvest_products.
	var/tmp/harvest_bonus = 0

/mob/living/simple_animal/persistence_runtime_var(key)
	if (key == "harvesting" || key == "harvest_bonus")
		return TRUE
	return ..()

/mob/living/simple_animal/proc/harvest_valid(mob/user, obj/item/tool, turf/site, require_client = TRUE)
	return !QDELETED(src) && !harvested && stat == DEAD && isturf(loc) && loc == site && !QDELETED(user) && (!require_client || user.client || agent_character_for(user)) && !QDELETED(tool) && tool.loc == user && tool.sharp && !istype(tool, /obj/item/weapon/reagent_containers) && !istype(tool, /obj/item/weapon/macuahuitl) && user.stat == CONSCIOUS && get_dist(user, src) <= 1

/mob/living/simple_animal/proc/harvest_wait(mob/user, delay)
	return do_after(user, delay, src)

/mob/living/simple_animal/proc/harvest_animal(mob/user, obj/item/tool, skin = FALSE)
	var/turf/site = loc
	if (harvesting || !harvest_valid(user, tool, site))
		return FALSE
	harvesting = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts to [skin ? "skin and butcher" : "butcher"] [src]."))
	var/completed = harvest_wait(user, skin ? 100 : 30)
	if (QDELETED(src))
		return FALSE
	harvesting = FALSE
	if (!completed || !harvest_valid(user, tool, site))
		return FALSE
	// Claim before constructing anything. This proc does not yield after claiming.
	harvested = TRUE
	user.visible_message(SPAN_NOTICE("[user] [skin ? "skins and butchers" : "butchers"] [src]."))
	harvest_bonus = harvest_skill_user_bonus(user, "hunting")
	harvest_products(site, skin)
	harvest_bonus = 0
	if (istype(user, /mob/living/human))
		var/mob/living/human/H = user
		H.adaptStat("medical", butcher_yield()/3)
		H.adaptStat("hunting", butcher_yield()/2)
		note_field_work(H, "butchering")
		H.soil(3, DIRTY_HANDS_GRIME) // hygiene_work.dm
	crush()
	qdel(src)
	return TRUE

/mob/living/simple_animal/proc/harvest_mammal()
	// Explicit anatomy: never infer mammalian organs from size or has_fat.
	if (istype(src, /mob/living/simple_animal/horse) || istype(src, /mob/living/simple_animal/pet/dog) || istype(src, /mob/living/simple_animal/hostile/commanded/dog) || istype(src, /mob/living/simple_animal/hostile/mammoth) || istype(src, /mob/living/simple_animal/blackbat) || istype(src, /mob/living/simple_animal/vampirebatblack))
		return TRUE
	return istype(src, /mob/living/simple_animal/cattle) || istype(src, /mob/living/simple_animal/pig_gilt) || istype(src, /mob/living/simple_animal/pig_boar) || istype(src, /mob/living/simple_animal/boar_gilt) || istype(src, /mob/living/simple_animal/boar_boar) || istype(src, /mob/living/simple_animal/goat) || istype(src, /mob/living/simple_animal/sheep) || istype(src, /mob/living/simple_animal/deer) || istype(src, /mob/living/simple_animal/bison) || istype(src, /mob/living/simple_animal/bisonbull) || istype(src, /mob/living/simple_animal/camel) || istype(src, /mob/living/simple_animal/rabbit) || istype(src, /mob/living/simple_animal/monkey) || istype(src, /mob/living/simple_animal/pet/cat) || istype(src, /mob/living/simple_animal/hostile/bear) || istype(src, /mob/living/simple_animal/hostile/wolf) || istype(src, /mob/living/simple_animal/hostile/fox) || istype(src, /mob/living/simple_animal/hostile/gorilla) || istype(src, /mob/living/simple_animal/hostile/panther) || istype(src, /mob/living/simple_animal/hostile/sabertooth) || istype(src, /mob/living/simple_animal/hostile/buffalo) || istype(src, /mob/living/simple_animal/hostile/groundsloth)

// Usable bone: every mammal, large reptiles and the larger birds (penguins,
// turkeys, geese, pelicans). Chickens keep their carcass route; small birds
// (crows, gulls, pigeons) and small animals (lizards, mice, frogs) have nothing
// worth working.
/mob/living/simple_animal/proc/harvest_bones()
	if (harvest_mammal())
		return TRUE
	if (istype(src, /mob/living/simple_animal/hostile/dinosaur/compsognathus))
		return FALSE
	if (istype(src, /mob/living/simple_animal/penguin) || istype(src, /mob/living/simple_animal/turkey_f) || istype(src, /mob/living/simple_animal/turkey_m) || istype(src, /mob/living/simple_animal/goose) || istype(src, /mob/living/simple_animal/pelican))
		return TRUE
	return istype(src, /mob/living/simple_animal/hostile/alligator) || istype(src, /mob/living/simple_animal/hostile/dinosaur) || istype(src, /mob/living/simple_animal/pachy) || istype(src, /mob/living/simple_animal/hostile/poison/snake/constrictor)

// Shell plates: crabs, trilobites and beetles have a hard shell instead of
// bone. A small crab gives one plate, a full-grown crab or trilobite two.
/mob/living/simple_animal/proc/harvest_chitin_pieces()
	if (istype(src, /mob/living/simple_animal/crab/small/trilobite))
		return 2
	if (istype(src, /mob/living/simple_animal/crab))
		return mob_size >= MOB_SMALL ? 2 : 1
	if (istype(src, /mob/living/simple_animal/hostile/phosphor_beetle))
		return 1
	return 0

// Tendons come from every animal with usable bone that is at least small sized.
/mob/living/simple_animal/proc/harvest_sinew()
	return harvest_bones()

/mob/living/simple_animal/proc/harvest_food(typepath, turf/site)
	var/obj/item/weapon/reagent_containers/food/snacks/F = new typepath(site)
	F.radiation = radiation/2
	// One mammal cut in ten carries worm eggs in its raw meat; cooking kills them.
	if (harvest_mammal() && istype(F, /obj/item/weapon/reagent_containers/food/snacks/meat) && F.reagents && prob(10))
		F.reagents.add_reagent("worm_eggs", 1)
	if (!istype(src, /mob/living/simple_animal/frog/poisonous))
		F.name = "[name] [F.name]"
	return F

// Whole-hide area in pieces. One piece is about 60 cm square (4 sq ft), the
// same unit as one leather sheet or one pelt sheet in recipes, so a recipe
// cost reads as the area of hide the item really needs. Most specific first.
/mob/living/simple_animal/proc/harvest_hide_pieces()
	if (istype(src, /mob/living/simple_animal/turkey_f) || istype(src, /mob/living/simple_animal/turkey_m))
		return 1 // Chicks yield no skin.
	// Bears
	if (istype(src, /mob/living/simple_animal/hostile/bear/boar/polar))
		return 11
	if (istype(src, /mob/living/simple_animal/hostile/bear/sow/polar))
		return 7
	if (istype(src, /mob/living/simple_animal/hostile/bear/boar/brown))
		return 9
	if (istype(src, /mob/living/simple_animal/hostile/bear/sow/brown))
		return 6
	if (istype(src, /mob/living/simple_animal/hostile/bear/sow))
		return 4
	if (istype(src, /mob/living/simple_animal/hostile/bear))
		return 5
	// Canids and cats
	if (istype(src, /mob/living/simple_animal/hostile/wolf))
		return 3
	if (istype(src, /mob/living/simple_animal/hostile/fox) || istype(src, /mob/living/simple_animal/pet/cat) || istype(src, /mob/living/simple_animal/pet/dog))
		return 1
	if (istype(src, /mob/living/simple_animal/hostile/commanded/dog))
		return 2
	if (istype(src, /mob/living/simple_animal/hostile/panther))
		return 4
	if (istype(src, /mob/living/simple_animal/hostile/sabertooth/lion))
		return 6
	if (istype(src, /mob/living/simple_animal/hostile/sabertooth))
		return 7
	// Apes
	if (istype(src, /mob/living/simple_animal/hostile/gorilla/gigantopithecus))
		return 9
	if (istype(src, /mob/living/simple_animal/hostile/gorilla))
		return 5
	if (istype(src, /mob/living/simple_animal/monkey))
		return 1
	// Livestock and game
	if (istype(src, /mob/living/simple_animal/cattle/bull))
		return 13
	if (istype(src, /mob/living/simple_animal/cattle))
		return 11
	if (istype(src, /mob/living/simple_animal/bisonbull))
		return 16
	if (istype(src, /mob/living/simple_animal/bison))
		return 11
	if (istype(src, /mob/living/simple_animal/hostile/buffalo))
		return 13
	if (istype(src, /mob/living/simple_animal/horse) || istype(src, /mob/living/simple_animal/camel))
		return istype(src, /mob/living/simple_animal/camel) ? 11 : 10
	if (istype(src, /mob/living/simple_animal/deer/dikdik))
		return 1
	if (istype(src, /mob/living/simple_animal/deer/elk/female))
		return 6
	if (istype(src, /mob/living/simple_animal/deer/elk))
		return 8
	if (istype(src, /mob/living/simple_animal/deer/reindeer/female))
		return 3
	if (istype(src, /mob/living/simple_animal/deer/reindeer))
		return 4
	if (istype(src, /mob/living/simple_animal/deer/female))
		return 3
	if (istype(src, /mob/living/simple_animal/deer))
		return 4
	if (istype(src, /mob/living/simple_animal/pig_boar) || istype(src, /mob/living/simple_animal/boar_boar))
		return 4
	if (istype(src, /mob/living/simple_animal/pig_gilt) || istype(src, /mob/living/simple_animal/boar_gilt))
		return 3
	if (istype(src, /mob/living/simple_animal/sheep) || istype(src, /mob/living/simple_animal/goat))
		return 2
	if (istype(src, /mob/living/simple_animal/rabbit))
		return 1
	if (istype(src, /mob/living/simple_animal/blackbat) || istype(src, /mob/living/simple_animal/vampirebatblack))
		return 0 // Bat skin is too thin and small to work.
	// Giants
	if (istype(src, /mob/living/simple_animal/hostile/mammoth))
		return 45
	if (istype(src, /mob/living/simple_animal/hostile/groundsloth))
		return 20
	// Reptiles
	if (istype(src, /mob/living/simple_animal/hostile/dinosaur/trex))
		return 50
	if (istype(src, /mob/living/simple_animal/hostile/alligator))
		return 5
	if (istype(src, /mob/living/simple_animal/pachy) || istype(src, /mob/living/simple_animal/hostile/dinosaur/pachycephalosaurus))
		return 9
	if (istype(src, /mob/living/simple_animal/hostile/dinosaur/velociraptor))
		return 3
	if (istype(src, /mob/living/simple_animal/hostile/dinosaur/dimetrodon))
		return 5
	if (istype(src, /mob/living/simple_animal/hostile/dinosaur/compsognathus))
		return 1
	// Any other mammal: estimate from body size.
	if (harvest_mammal())
		switch (mob_size)
			if (MOB_HUGE)
				return 15
			if (MOB_LARGE)
				return 6
			if (MOB_MEDIUM)
				return 2
		return 1
	return 0

// Pieces of animal fat a carcass gives before the butcher's skill, by how fat
// the living animal is: a wolf is lean, a pig or an autumn bear carries a thick
// layer, a mammoth far more. Species not listed give one or two by body size.
/mob/living/simple_animal/proc/harvest_fat_pieces(size)
	if (!has_fat)
		return 0
	var/by_size = min(2, max(0, size - 2 + fat_extra - fat_penalty))
	if (size < 4) // small animals and the young of big ones
		return by_size
	if (istype(src, /mob/living/simple_animal/hostile/wolf))
		return 1
	if (istype(src, /mob/living/simple_animal/pig_boar) || istype(src, /mob/living/simple_animal/pig_gilt))
		return 3
	if (size < 5) // half-grown
		return by_size
	if (istype(src, /mob/living/simple_animal/hostile/mammoth))
		return 8
	if (istype(src, /mob/living/simple_animal/hostile/groundsloth))
		return 5
	if (istype(src, /mob/living/simple_animal/hostile/bear/boar/polar) || istype(src, /mob/living/simple_animal/hostile/bear/sow/polar))
		return 5
	if (istype(src, /mob/living/simple_animal/hostile/bear))
		return 4
	if (istype(src, /mob/living/simple_animal/bisonbull) || istype(src, /mob/living/simple_animal/bison) || istype(src, /mob/living/simple_animal/hostile/buffalo) || istype(src, /mob/living/simple_animal/camel))
		return 4
	if (istype(src, /mob/living/simple_animal/cattle) || istype(src, /mob/living/simple_animal/deer/elk))
		return 3
	return by_size

// Quick butchering hacks the skin apart: only half the hide survives as raw
// hide. Skinning (grab intent) takes longer and keeps the whole hide.
/mob/living/simple_animal/proc/harvest_skin_yield()
	var/pieces = harvest_hide_pieces()
	if (pieces < 1)
		return 0
	return max(1, round(pieces / 2))

/mob/living/simple_animal/proc/harvest_products(turf/site, skin)
	var/size = min(8, max(1, butcher_yield()))
	var/mammal = harvest_mammal()
	var/pig = istype(src, /mob/living/simple_animal/pig_gilt) || istype(src, /mob/living/simple_animal/pig_boar) || istype(src, /mob/living/simple_animal/boar_gilt) || istype(src, /mob/living/simple_animal/boar_boar)
	var/chicken = istype(src, /mob/living/simple_animal/chicken) || istype(src, /mob/living/simple_animal/rooster)
	var/poisonous = istype(src, /mob/living/simple_animal/frog/poisonous)
	var/crab = istype(src, /mob/living/simple_animal/crab)
	var/zombie = istype(src, /mob/living/simple_animal/hostile/human/zombie)
	var/meat_type = poisonous ? /obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog : (crab ? /obj/item/weapon/reagent_containers/food/snacks/rawcrab : /obj/item/weapon/reagent_containers/food/snacks/meat)
	// Pig legs and chicken carcasses retain their existing multi-portion processing.
	// A skilled hunter cuts more food from the same carcass.
	var/portions = harvest_skill_amount(poisonous ? 1 : ((pig || chicken) ? 1 : size), poisonous ? 0 : harvest_bonus)
	if (pig)
		for (var/i = 1, i <= portions, i++)
			new /obj/item/weapon/pigleg(site)
	else if (chicken)
		for (var/i = 1, i <= portions, i++)
			new /obj/item/weapon/chicken_carcass(site)
	else
		for (var/i = 1, i <= portions, i++)
			var/obj/item/weapon/reagent_containers/food/snacks/F = harvest_food(meat_type, site)
			if (zombie)
				F.name = "rotten zombie meat"
				F.icon_state = "rottenmeat"
				F.reagents.remove_reagent("protein", 2)
				F.reagents.add_reagent("food_poisoning", 1)
				F.rotten = TRUE
				F.satisfaction = -30
	if (mammal)
		if (size >= 3)
			for (var/path in list(/obj/item/weapon/reagent_containers/food/snacks/meat/offal/heart, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/liver, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/kidneys, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/lungs, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/brain, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines))
				harvest_food(path, site)
		else
			harvest_food(/obj/item/weapon/reagent_containers/food/snacks/meat/offal, site)
		if (pig)
			harvest_food(/obj/item/weapon/reagent_containers/food/snacks/pig/stomach, site)
		else if (istype(src, /mob/living/simple_animal/cattle))
			harvest_food(/obj/item/weapon/reagent_containers/food/snacks/cow/stomach, site)
		else if (istype(src, /mob/living/simple_animal/goat))
			harvest_food(/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/goat, site)
		else if (istype(src, /mob/living/simple_animal/sheep))
			harvest_food(/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/sheep, site)
		else if (size >= 3)
			harvest_food(/obj/item/weapon/reagent_containers/food/snacks/meat/offal/stomach, site)
		if (has_fat)
			var/fat_portions = harvest_skill_amount(harvest_fat_pieces(size), harvest_bonus)
			for (var/i = 1, i <= fat_portions, i++)
				harvest_food(/obj/item/weapon/reagent_containers/food/snacks/animalfat, site)
	else if (chicken)
		harvest_food(/obj/item/weapon/reagent_containers/food/snacks/meat/offal, site)
	if (size >= 3 && harvest_sinew())
		new /obj/item/stack/sinew(site, min(4, max(1, size-2)))
	if (harvest_bones())
		new /obj/item/stack/material/bone(site, max(1, size-2))
	var/chitin_pieces = harvest_skill_amount(harvest_chitin_pieces(), harvest_bonus)
	if (chitin_pieces > 0)
		new /obj/item/stack/material/chitin(site, chitin_pieces)
	if (skin)
		harvest_hide(site)
	else
		var/skin_units = harvest_skin_yield()
		if (skin_units > 0)
			new /obj/item/stack/material/rawhide(site, skin_units)
	if (map && map.ID == MAP_WIZARD_BOY && istype(src, /mob/living/simple_animal/pigeon))
		new /obj/item/wand_part/pigeon_feather(site)

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/stomach
	name = "animal stomach"
	icon_state = "stomach"
	rotten_icon_state = "stomach-x"

/mob/living/simple_animal/proc/harvest_hide(turf/site)
	var/pieces = harvest_hide_pieces()
	if (pieces < 1)
		return
	if (istype(src, /mob/living/simple_animal/hostile/bear/boar/black))
		new /obj/item/stack/material/pelt/bearpelt/black(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/bear/sow/black))
		new /obj/item/stack/material/pelt/bearpelt/black(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/bear/boar/polar))
		new /obj/item/stack/material/pelt/bearpelt/white(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/bear/sow/polar))
		new /obj/item/stack/material/pelt/bearpelt/white(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/bear/boar/brown))
		new /obj/item/stack/material/pelt/bearpelt/brown(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/bear/sow/brown))
		new /obj/item/stack/material/pelt/bearpelt/brown(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/bear))
		new /obj/item/stack/material/pelt/bearpelt/black(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/wolf/white))
		new /obj/item/stack/material/pelt/wolfpelt/white(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/wolf))
		new /obj/item/stack/material/pelt/wolfpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/monkey))
		new /obj/item/stack/material/pelt/monkeypelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/gorilla/gigantopithecus))
		new /obj/item/stack/material/pelt/gorillapelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/gorilla))
		new /obj/item/stack/material/pelt/gorillapelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/fox/arctic))
		new /obj/item/stack/material/pelt/foxpelt/white(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/fox))
		new /obj/item/stack/material/pelt/foxpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/pet/cat))
		new /obj/item/stack/material/pelt/catpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/panther) && !istype(src, /mob/living/simple_animal/hostile/panther/jaguar))
		new /obj/item/stack/material/pelt/pantherpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/sabertooth/lion) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/lion/gladiator))
		new /obj/item/stack/material/pelt/lionpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/sabertooth) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/white) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/lion))
		new /obj/item/stack/material/pelt/lionpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/alligator))
		new /obj/item/stack/material/pelt/gatorpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/trex))
		new /obj/item/stack/material/pelt/lizardpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/velociraptor))
		new /obj/item/stack/material/pelt/lizardpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/pachy))
		new /obj/item/stack/material/pelt/lizardpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/compsognathus))
		new /obj/item/stack/material/pelt/lizardpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/sheep))
		new /obj/item/stack/material/pelt/sheeppelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/goat))
		new /obj/item/stack/material/pelt/goatpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/cattle/cow))
		new /obj/item/stack/material/pelt/cowpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/cattle/bull))
		new /obj/item/stack/material/pelt/cowpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/bison))
		new /obj/item/stack/material/pelt/bisonpelt(site, pieces)
	else if (istype(src, /mob/living/simple_animal/bisonbull))
		new /obj/item/stack/material/pelt/bisonpelt(site, pieces)
	else
		new /obj/item/stack/material/rawhide(site, pieces)
