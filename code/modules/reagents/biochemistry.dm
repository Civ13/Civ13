// Chemistry Expansion game conversions, not real extraction/synthesis methods.
/datum/reagent/collagen
	name = "Collagen Proteins"
	id = "collagen"
	description = "An animal protein feedstock for the game's gelatin chain."
	reagent_state = SOLID
	color = "#EEDDBB"

// Cleaned bones are separate paid feedstock, not a replacement for bone material.
/obj/item/stack/cleaned_bones
	name = "cleaned bones"
	singular_name = "cleaned bone"
	desc = "A cleaned bone for collagen extraction."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-bone"
	w_class = ITEM_SIZE_SMALL
	max_amount = 50
	can_stack = TRUE
	stacktype = /obj/item/stack/cleaned_bones
	value = 0

/obj/item/stack/material/bone/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/material/thrown/throwing_knife) || istype(W, /obj/item/weapon/material/thrown/throwing_knife1))
		var/turf/site = get_turf(src)
		if(!user || user.stat || gcDestroyed || gc_destroyed || !site || !use(1))
			return
		new /obj/item/stack/cleaned_bones(site, 1)
		to_chat(user, SPAN_NOTICE("You clean a bone for collagen extraction."))
		return
	..()

/obj/item/weapon/reagent_containers/glass/extraction_kit/proc/extract_clean_bone(obj/item/stack/cleaned_bones/bones)
	if(!bones || bones.gcDestroyed || bones.gc_destroyed || !bones.can_use(1) || !reagents || reagents.total_volume || reagents.get_free_space() < 4 || !chemical_reagents_list["collagen"])
		return FALSE
	if(!bones.use(1))
		return FALSE
	reagents.add_reagent("collagen", 4)
	return TRUE

/obj/item/stack/cleaned_bones/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = W
		if(kit.extract_clean_bone(src))
			to_chat(user, SPAN_NOTICE("You extract collagen from a cleaned bone."))
		else
			to_chat(user, SPAN_WARNING("An empty extraction kit and a cleaned bone are required."))
		return
	..()

/datum/reagent/proteolytic_enzyme
	name = "Digestive Protease"
	id = "proteolytic_enzyme"
	description = "A simplified digestive enzyme extract, distinct from the game's plasma protein reagents."
	reagent_state = LIQUID
	color = "#99AA55"

/datum/reagent/fruit_protease
	name = "Fruit Protease"
	id = "fruit_protease"
	description = "A papaya enzyme extract used in game gelatin processing. Papain is a protease, not collagenase."
	reagent_state = LIQUID
	color = "#FFBB55"

/datum/reagent/unpurified_gelatin
	name = "Unpurified Gelatin"
	id = "unpurified_gelatin"
	description = "A crude game gelatin mixture requiring centrifuge purification."
	reagent_state = LIQUID
	color = "#BBAA77"

/datum/reagent/purified_gelatin
	name = "Purified Gelatin"
	id = "purified_gelatin"
	description = "A centrifuged game gelatin solution."
	reagent_state = LIQUID
	color = "#EECC88"

/datum/reagent/gelatin
	name = "Gelatin"
	id = "gelatin"
	description = "Solid gelatin produced by a simplified game recipe."
	reagent_state = SOLID
	color = "#EEDD99"

/datum/reagent/purified_cellulose
	name = "Purified Cellulose"
	id = "purified_cellulose"
	description = "Purified wood fibre feedstock from the game's centrifuge."
	reagent_state = SOLID
	color = "#EDE9DC"

/datum/reagent/rayon_fiber
	name = "Rayon Fibre"
	id = "rayon_fiber"
	description = "Regenerated fibre for the laboratory bench's cloth conversion."
	reagent_state = SOLID
	color = "#F1EFE7"

/datum/reagent/lyocell_fiber
	name = "Lyocell Fibre"
	id = "lyocell_fiber"
	description = "Regenerated fibre for the laboratory bench's cloth conversion."
	reagent_state = SOLID
	color = "#F5F2EA"

/proc/wood_fiber_year_allowed(first_year)
	if(!map || !istext(map.age))
		return FALSE
	var/year = text2num(map.age)
	return isnum(year) && year == round(year) && "[year]" == map.age && year >= first_year

/datum/chemical_reaction/rayon_fiber
	name = "Rayon fibre"
	id = "rayon_fiber"
	result = "rayon_fiber"
	required_reagents = list("purified_cellulose" = 4, "sodium_hydroxide" = 1)
	result_amount = 4

/datum/chemical_reaction/rayon_fiber/can_happen(datum/reagents/holder)
	if(!..() || !wood_fiber_year_allowed(1890))
		return FALSE
	var/obj/structure/reaction_bench/bench = holder.my_atom ? holder.my_atom.loc : null
	return istype(bench) && bench.collector == holder.my_atom

/datum/chemical_reaction/lyocell_fiber
	name = "Lyocell fibre"
	id = "lyocell_fiber"
	result = "lyocell_fiber"
	required_reagents = list("purified_cellulose" = 4, "n_methylmorpholine_n_oxide" = 1)
	result_amount = 4

/datum/chemical_reaction/lyocell_fiber/can_happen(datum/reagents/holder)
	if(!..() || !wood_fiber_year_allowed(1980))
		return FALSE
	var/obj/structure/reaction_bench/bench = holder.my_atom ? holder.my_atom.loc : null
	return istype(bench) && bench.collector == holder.my_atom

// One paid chip batch becomes a finite amount of pulp. An occupied kit or
// unavailable reagent must never consume the batch.
/obj/item/weapon/reagent_containers/glass/extraction_kit/proc/extract_wood_pulp(obj/item/stack/wood_chips/chips)
	if(!chips || chips.gcDestroyed || chips.gc_destroyed || !chips.can_use(1) || !reagents || reagents.total_volume || reagents.get_free_space() < 4 || !chemical_reagents_list["woodpulp"])
		return FALSE
	if(!chips.use(1))
		return FALSE
	reagents.add_reagent("woodpulp", 4)
	return TRUE

/obj/item/stack/wood_chips/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = W
		if(kit.extract_wood_pulp(src))
			to_chat(user, SPAN_NOTICE("You process one batch of chips into wood pulp."))
		else
			to_chat(user, SPAN_WARNING("An empty extraction kit and a batch of chips are required."))
		return
	..()

/datum/reagent/polypropylene
	name = "Polypropylene"
	id = "polypropylene"
	description = "A solid plastic produced at a heated laboratory bench."
	reagent_state = SOLID
	color = "#EEEEEE"

/datum/reagent/enginefuel
	parent_type = /datum/reagent/gasoline
	name = "Blended Engine Fuel"
	id = "enginefuel"
	description = "The game's 9:1 gasoline and purified-ethanol blend for gasoline engines."
	reagent_state = LIQUID
	color = "#DDBB66"

/datum/chemical_reaction/gelatin_acid
	name = "Gelatin - acid treatment"
	id = "gelatin_acid"
	result = "unpurified_gelatin"
	required_reagents = list("collagen" = 4, "hclacid" = 1)
	result_amount = 5

/datum/chemical_reaction/gelatin_enzyme
	name = "Gelatin - digestive protease treatment"
	id = "gelatin_enzyme"
	result = "unpurified_gelatin"
	required_reagents = list("collagen" = 4, "proteolytic_enzyme" = 1)
	result_amount = 5

/datum/chemical_reaction/gelatin_fruit
	name = "Gelatin - fruit protease treatment"
	id = "gelatin_fruit"
	result = "unpurified_gelatin"
	required_reagents = list("collagen" = 4, "fruit_protease" = 1)
	result_amount = 5

/datum/chemical_reaction/gelatin_water
	name = "Solid gelatin - water"
	id = "gelatin_water"
	result = "gelatin"
	required_reagents = list("purified_gelatin" = 4, "water" = 1)
	result_amount = 5

/datum/chemical_reaction/gelatin_ethanol
	name = "Solid gelatin - purified ethanol"
	id = "gelatin_ethanol"
	result = "gelatin"
	required_reagents = list("purified_gelatin" = 4, "pethanol" = 1)
	result_amount = 5

/datum/chemical_reaction/enginefuel
	name = "Engine fuel - 9:1 blend"
	id = "enginefuel"
	result = "enginefuel"
	required_reagents = list("gasoline" = 9, "pethanol" = 1)
	result_amount = 10

/datum/chemical_reaction/polypropylene/can_happen(datum/reagents/holder)
	if(!..())
		return FALSE
	var/obj/structure/reaction_bench/bench = holder.my_atom ? holder.my_atom.loc : null
	return istype(bench) && bench.collector == holder.my_atom && bench.is_heated()

// Commit the extraction only after a registered product fits in an empty kit.
/obj/item/weapon/reagent_containers/glass/extraction_kit/proc/extract_biological(atom/source)
	if(!source || !reagents || reagents.total_volume > 0 || reagents.get_free_space() < 4)
		return FALSE
	var/product
	if(istype(source, /obj/item/weapon/reagent_containers/food/snacks/meat))
		var/obj/item/weapon/reagent_containers/food/snacks/meat/M = source
		if(M.rotten || M.roasted || !M.raw)
			return FALSE
		product = "collagen"
	else if(istype(source, /obj/effect/decal/cleanable/vomit))
		product = "proteolytic_enzyme"
	else if(istype(source, /obj/item/weapon/reagent_containers/food/snacks/grown/papaya))
		var/obj/item/weapon/reagent_containers/food/snacks/grown/papaya/P = source
		if(P.rotten)
			return FALSE
		product = "fruit_protease"
	if(!product || !chemical_reagents_list[product])
		return FALSE
	if(!reagents.add_reagent(product, 4))
		return FALSE
	qdel(source)
	return TRUE

/obj/effect/decal/cleanable/vomit/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = W
		if(kit.extract_biological(src))
			to_chat(user, SPAN_NOTICE("You collect a digestive enzyme extract."))
		return
	..()

/obj/item/weapon/reagent_containers/food/snacks/grown/papaya
	name = "papaya"
	desc = "A tropical fruit. An extraction kit can collect fruit protease from it."
	icon_state = "orange" // Reuse the existing fruit sprite until dedicated art exists.
	color = "#FFBB55"

/obj/item/weapon/reagent_containers/food/snacks/grown/papaya/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = W
		if(kit.extract_biological(src))
			to_chat(user, SPAN_NOTICE("You collect a fruit enzyme extract."))
		return
	..()

/obj/item/stack/farming/seeds/papaya
	name = "papaya seeds"
	plant = "papaya"
	biomes = list("jungle", "savanna")
	seasons = list("SUMMER", "SPRING", "Wet Season")
	color = "#FFBB55"

/obj/structure/farming/plant/papaya
	name = "papaya tree"
	desc = "A tropical fruit tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "orange-grow1"
	plant = "papaya"
	sprite_plant = "orange"
	biomes = list("jungle", "savanna")
	seasons = list("SUMMER", "SPRING", "Wet Season")
