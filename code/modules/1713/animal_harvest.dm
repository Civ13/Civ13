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

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines
	name = "animal intestines"
	icon_state = "innards"
	rotten_icon_state = "innards"

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
		var/obj/item/stack/material/rope/cord = new(get_turf(user))
		cord.name = "sinew binding cord"
		user.put_in_any_hand_if_possible(cord)
		to_chat(user, SPAN_NOTICE("You twist the sinew into binding cord."))

/mob/living/simple_animal
	// Persist only the completed claim; an interrupted wait must not lock a save.
	var/harvested = FALSE
	var/tmp/harvesting = FALSE

/mob/living/simple_animal/persistence_runtime_var(key)
	if (key == "harvesting")
		return TRUE
	return ..()

/mob/living/simple_animal/proc/harvest_valid(mob/user, obj/item/tool, turf/site, require_client = TRUE)
	return !QDELETED(src) && !harvested && stat == DEAD && isturf(loc) && loc == site && !QDELETED(user) && (!require_client || user.client) && !QDELETED(tool) && tool.loc == user && tool.sharp && !istype(tool, /obj/item/weapon/reagent_containers) && !istype(tool, /obj/item/weapon/macuahuitl) && user.stat == CONSCIOUS && get_dist(user, src) <= 1

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
	harvest_products(site, skin)
	if (istype(user, /mob/living/human))
		var/mob/living/human/H = user
		H.adaptStat("medical", butcher_yield()/3)
	crush()
	qdel(src)
	return TRUE

/mob/living/simple_animal/proc/harvest_mammal()
	// Explicit anatomy: never infer mammalian organs from size or has_fat.
	if (istype(src, /mob/living/simple_animal/horse) || istype(src, /mob/living/simple_animal/pet/dog) || istype(src, /mob/living/simple_animal/hostile/commanded/dog) || istype(src, /mob/living/simple_animal/hostile/mammoth) || istype(src, /mob/living/simple_animal/blackbat) || istype(src, /mob/living/simple_animal/vampirebatblack))
		return TRUE
	return istype(src, /mob/living/simple_animal/cattle) || istype(src, /mob/living/simple_animal/pig_gilt) || istype(src, /mob/living/simple_animal/pig_boar) || istype(src, /mob/living/simple_animal/boar_gilt) || istype(src, /mob/living/simple_animal/boar_boar) || istype(src, /mob/living/simple_animal/goat) || istype(src, /mob/living/simple_animal/sheep) || istype(src, /mob/living/simple_animal/deer) || istype(src, /mob/living/simple_animal/bison) || istype(src, /mob/living/simple_animal/bisonbull) || istype(src, /mob/living/simple_animal/camel) || istype(src, /mob/living/simple_animal/rabbit) || istype(src, /mob/living/simple_animal/monkey) || istype(src, /mob/living/simple_animal/pet/cat) || istype(src, /mob/living/simple_animal/hostile/bear) || istype(src, /mob/living/simple_animal/hostile/wolf) || istype(src, /mob/living/simple_animal/hostile/fox) || istype(src, /mob/living/simple_animal/hostile/gorilla) || istype(src, /mob/living/simple_animal/hostile/panther) || istype(src, /mob/living/simple_animal/hostile/sabertooth)

/mob/living/simple_animal/proc/harvest_food(typepath, turf/site)
	var/obj/item/weapon/reagent_containers/food/snacks/F = new typepath(site)
	F.radiation = radiation/2
	if (!istype(src, /mob/living/simple_animal/frog/poisonous))
		F.name = "[name] [F.name]"
	return F

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
	if (pig)
		new /obj/item/weapon/pigleg(site)
	else if (chicken)
		new /obj/item/weapon/chicken_carcass(site)
	else
		for (var/i = 1, i <= (poisonous ? 1 : size), i++)
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
		if (size >= 3)
			new /obj/item/stack/sinew(site, min(4, max(1, size-2)))
		if (has_fat)
			for (var/i = 1, i <= min(2, max(0, size-2+fat_extra-fat_penalty)), i++)
				harvest_food(/obj/item/weapon/reagent_containers/food/snacks/animalfat, site)
		new /obj/item/stack/material/bone(site, max(1, size-2))
		if (!skin)
			new /obj/item/stack/material/leather(site, max(1, size-2))
	else if (chicken)
		harvest_food(/obj/item/weapon/reagent_containers/food/snacks/meat/offal, site)
	if (skin)
		harvest_hide(site)
	if (map && map.ID == MAP_WIZARD_BOY && istype(src, /mob/living/simple_animal/pigeon))
		new /obj/item/wand_part/pigeon_feather(site)

/obj/item/weapon/reagent_containers/food/snacks/meat/offal/stomach
	name = "animal stomach"
	icon_state = "stomach"
	rotten_icon_state = "stomach-x"

/mob/living/simple_animal/proc/harvest_hide(turf/site)
	if (istype(src, /mob/living/simple_animal/hostile/bear)) //all bears on the inheritance path drop leather to compensate for improper types.
		var/obj/item/stack/material/leather/NP = new/obj/item/stack/material/leather(site)
		NP.amount = 1
	if (istype(src, /mob/living/simple_animal/hostile/bear/boar/black))
		var/obj/item/stack/material/pelt/bearpelt/black/NP = new/obj/item/stack/material/pelt/bearpelt/black(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/bear/sow/black))
		var/obj/item/stack/material/pelt/bearpelt/black/NP = new/obj/item/stack/material/pelt/bearpelt/black(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/bear/boar/polar))
		var/obj/item/stack/material/pelt/bearpelt/white/NP = new/obj/item/stack/material/pelt/bearpelt/white(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/bear/sow/polar))
		var/obj/item/stack/material/pelt/bearpelt/white/NP = new/obj/item/stack/material/pelt/bearpelt/white(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/bear/boar/brown))
		var/obj/item/stack/material/pelt/bearpelt/brown/NP = new/obj/item/stack/material/pelt/bearpelt/brown(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/bear/sow/brown))
		var/obj/item/stack/material/pelt/bearpelt/brown/NP = new/obj/item/stack/material/pelt/bearpelt/brown(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/wolf/white))
		var/obj/item/stack/material/pelt/wolfpelt/white/NP = new/obj/item/stack/material/pelt/wolfpelt/white(site)
		NP.amount = 4
	else if (istype(src, /mob/living/simple_animal/hostile/wolf))
		var/obj/item/stack/material/pelt/wolfpelt/NP = new/obj/item/stack/material/pelt/wolfpelt(site)
		NP.amount = 4
	else if (istype(src, /mob/living/simple_animal/monkey))
		var/obj/item/stack/material/pelt/monkeypelt/NP = new/obj/item/stack/material/pelt/monkeypelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/gorilla/gigantopithecus))
		var/obj/item/stack/material/pelt/gorillapelt/NP = new/obj/item/stack/material/pelt/gorillapelt(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/gorilla))
		var/obj/item/stack/material/pelt/gorillapelt/NP = new/obj/item/stack/material/pelt/gorillapelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/fox/arctic))
		var/obj/item/stack/material/pelt/foxpelt/white/NP = new/obj/item/stack/material/pelt/foxpelt/white(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/fox))
		var/obj/item/stack/material/pelt/foxpelt/NP = new/obj/item/stack/material/pelt/foxpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/pet/cat))
		var/obj/item/stack/material/pelt/catpelt/NP = new/obj/item/stack/material/pelt/catpelt(site)
		NP.amount = 2
	else if (istype(src, /mob/living/simple_animal/hostile/panther) && !istype(src, /mob/living/simple_animal/hostile/panther/jaguar))
		var/obj/item/stack/material/pelt/pantherpelt/NP = new/obj/item/stack/material/pelt/pantherpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/sabertooth) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/white))
		var/obj/item/stack/material/pelt/lionpelt/NP = new/obj/item/stack/material/pelt/lionpelt(site)
		NP.amount = 6
	else if (istype(src, /mob/living/simple_animal/hostile/sabertooth/lion) && !istype(src, /mob/living/simple_animal/hostile/sabertooth/lion/gladiator))
		var/obj/item/stack/material/pelt/lionpelt/NP = new/obj/item/stack/material/pelt/lionpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/alligator))
		var/obj/item/stack/material/pelt/gatorpelt/NP = new/obj/item/stack/material/pelt/gatorpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/trex))
		var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(site)
		NP.amount = 10
	else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/velociraptor))
		var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/pachy))
		var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/hostile/dinosaur/compsognathus))
		var/obj/item/stack/material/pelt/lizardpelt/NP = new/obj/item/stack/material/pelt/lizardpelt(site)
		NP.amount = 1
	else if (istype(src, /mob/living/simple_animal/sheep))
		var/obj/item/stack/material/pelt/sheeppelt/NP = new/obj/item/stack/material/pelt/sheeppelt(site)
		NP.amount = 2
	else if (istype(src, /mob/living/simple_animal/goat))
		var/obj/item/stack/material/pelt/goatpelt/NP = new/obj/item/stack/material/pelt/goatpelt(site)
		NP.amount = 2
	else if (istype(src, /mob/living/simple_animal/cattle/cow))
		var/obj/item/stack/material/pelt/cowpelt/NP = new/obj/item/stack/material/pelt/cowpelt(site)
		NP.amount = 2
	else if (istype(src, /mob/living/simple_animal/cattle/bull))
		var/obj/item/stack/material/pelt/cowpelt/NP = new/obj/item/stack/material/pelt/cowpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/bison))
		var/obj/item/stack/material/pelt/bisonpelt/NP = new/obj/item/stack/material/pelt/bisonpelt(site)
		NP.amount = 3
	else if (istype(src, /mob/living/simple_animal/bisonbull))
		var/obj/item/stack/material/pelt/bisonpelt/NP = new/obj/item/stack/material/pelt/bisonpelt(site)
		NP.amount = 4
	else if (harvest_mammal() && !istype(src, /mob/living/simple_animal/hostile/bear))
		new /obj/item/stack/material/leather(site, max(1, butcher_yield()-2))
