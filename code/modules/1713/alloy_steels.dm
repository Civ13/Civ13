// Alloy steels (docs/steelmaking.md, "Alloy steels").
//
// Nickel and cobalt ores turn up in mined rock from the Early Modern age.
// A little nickel added to an open hearth melt makes nickel steel: the
// armour-plate steel of the 1890s. Armour forged from it stops blows a little
// better and bullets and arrows a good deal better, and blades come out a
// little better than from fine steel.

#define NICKEL_ORE_CHANCE 3 // percent per mined wall, from the Early Modern age
#define COBALT_ORE_CHANCE 1.5
#define ALLOY_ORE_AGE 5
#define NICKEL_STEEL_PER_ORE 4 // steel one nickel ore alloys in an open hearth
#define ALLOY_ADDITION_LIMIT 20 // alloy ore one works holds

//////////////////////////////////////////////////////////////////////////////
// Ores

/obj/item/stack/ore/nickel
	name = "nickel ore"
	desc = "Pentlandite: heavy bronze-yellow lumps with a metallic shine. A little of it added to an open hearth melt makes nickel steel."
	icon_state = "ore_iron"
	color = "#c9bd84"
	singular_name = "lump"
	flags = CONDUCT
	flammable = FALSE

/obj/item/stack/ore/cobalt
	name = "cobalt ore"
	desc = "Cobaltite: silvery-white crystals with a faint pink bloom where they weather. Steelmakers alloy cobalt into the hardest steels."
	icon_state = "ore_iron"
	color = "#c8b6c6"
	singular_name = "lump"
	flags = CONDUCT
	flammable = FALSE

// Nickel and cobalt found in one mined wall, independent of the other ore rolls.
/turf/proc/mining_alloy_ores(mob/living/human/H)
	. = 0
	if (!map || map.ordinal_age < ALLOY_ORE_AGE)
		return
	var/doubled = istype(get_area(src), /area/caribbean/void/caves/special)
	if (prob(NICKEL_ORE_CHANCE * continent_ore_factor("nickel", src)))
		var/amount = rand(8, 16) * (doubled ? 2 : 1)
		spawn_stack(/obj/item/stack/ore/nickel, src, amount)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#c9bd84><b>nickel</b></font> ore!"))
		. += amount
	if (prob(COBALT_ORE_CHANCE * continent_ore_factor("cobalt", src)))
		var/amount = rand(4, 8) * (doubled ? 2 : 1)
		spawn_stack(/obj/item/stack/ore/cobalt, src, amount)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#c8b6c6><b>cobalt</b></font> ore!"))
		. += amount

//////////////////////////////////////////////////////////////////////////////
// Nickel steel

/obj/item/stack/material/steel/nickel
	name = "nickel steel"
	stock_grade = 1.15
	armor_blunt_grade = 1.1
	armor_pierce_grade = 1.25

/obj/item/stack/material/steel/nickel/New()
	. = ..()
	stacktype = type

/obj/item/stack/material/steel/nickel/grade_name()
	return "nickel"

/obj/item/stack/material/steel/nickel/grade_desc()
	return "Steel alloyed with a little nickel, tough rather than brittle: armour forged from it turns bullets and arrows far better, and blades come out better than from fine steel."

//////////////////////////////////////////////////////////////////////////////
// Alloy additions in the steelworks (steel_works.dm calls these hooks)

// Alloy ore this works takes as an addition, by key, or null.
/obj/structure/steel_works/proc/addition_key(obj/item/I)
	return null

/obj/structure/steel_works/open_hearth/addition_key(obj/item/I)
	if (istype(I, /obj/item/stack/ore/nickel))
		return "nickel"
	return null

/obj/structure/steel_works/proc/addition_path(key)
	switch (key)
		if ("nickel")
			return /obj/item/stack/ore/nickel
		if ("cobalt")
			return /obj/item/stack/ore/cobalt
	return null

/obj/structure/steel_works/proc/additions_total()
	. = 0
	for (var/key in additions)
		. += additions[key]

// Units of an addition stack this works still has room for.
/obj/structure/steel_works/proc/addition_room()
	return max(0, ALLOY_ADDITION_LIMIT - additions_total())

/obj/structure/steel_works/proc/note_addition(key, units)
	additions[key] = (additions[key] || 0) + units

/obj/structure/steel_works/proc/load_addition(obj/item/stack/S, mob/living/human/H)
	var/key = addition_key(S)
	var/units = min(S.amount, addition_room())
	if (!key || units <= 0)
		to_chat(H, SPAN_WARNING("\The [src] holds no more alloy ore."))
		return
	S.use(units)
	note_addition(key, units)
	visible_message(SPAN_NOTICE("[H] adds [units] [S.name] to \the [src]'s charge."))

/obj/structure/steel_works/proc/return_additions(turf/T)
	for (var/key in additions)
		var/path = addition_path(key)
		if (path && additions[key] > 0)
			spawn_stack(path, T, additions[key])
	additions = list()

/obj/structure/steel_works/proc/additions_text()
	var/list/parts = list()
	for (var/key in additions)
		if (additions[key] > 0)
			parts += "[additions[key]] [key] ore"
	return length(parts) ? english_list(parts) : null

// Of the steel one firing made, how much came out as an alloy (spawned here).
// The rest is the works' ordinary output.
/obj/structure/steel_works/proc/alloy_output(turf/T, made)
	return 0

/obj/structure/steel_works/open_hearth/alloy_output(turf/T, made)
	var/nickel = additions["nickel"] || 0
	if (made <= 0 || nickel <= 0)
		return 0
	var/alloyed = min(made, nickel * NICKEL_STEEL_PER_ORE)
	additions["nickel"] = nickel - CEILING(alloyed / NICKEL_STEEL_PER_ORE, 1)
	if (additions["nickel"] <= 0)
		additions -= "nickel"
	spawn_stack(/obj/item/stack/material/steel/nickel, T, alloyed)
	return alloyed

#undef NICKEL_ORE_CHANCE
#undef COBALT_ORE_CHANCE
#undef ALLOY_ORE_AGE
#undef NICKEL_STEEL_PER_ORE
#undef ALLOY_ADDITION_LIMIT
