// Alloy steels (docs/steelmaking.md, "Alloy steels").
//
// Nickel turns up in mined rock when Open Hearth Steel can first be
// researched (1873); cobalt and chromite still start in 1903 and 1943.
// - Nickel steel (open hearth, 1890s): a little nickel in the melt. Armour
//   forged from it stops blows a little better and bullets and arrows a good
//   deal better; blades come out a little better than from fine steel.
// - Inconel (arc furnace, 1940s): mostly nickel with chromium. Not a steel:
//   it keeps its strength red hot, so an engine overhauled with Inconel parts
//   wears half as fast.
// - Maraging steel (arc furnace, 1960s on): nickel and cobalt steel that comes
//   out of the melt soft and is aged in a kiln to full hardness. The best
//   steel for armour and blades.

#define NICKEL_ORE_CHANCE 3 // percent per mined wall
#define NICKEL_ORE_AGE 4 // Open Hearth Steel needs a tier-4 bench (1873).
#define COBALT_ORE_CHANCE 1.5
#define COBALT_ORE_AGE 5
#define NICKEL_STEEL_PER_ORE 4 // steel one nickel ore alloys in an open hearth
#define ALLOY_ADDITION_LIMIT 20 // alloy ore one works holds
#define CHROMITE_ORE_CHANCE 3
#define CHROMITE_ORE_AGE 6
#define INCONEL_NICKEL 3 // nickel ore per Inconel bar
#define INCONEL_CHROMITE 1 // chromite per Inconel bar
#define MARAGING_PER_PAIR 2 // maraging bars one nickel and one cobalt ore alloy
#define MARAGING_AGE 7 // first age that makes maraging steel
#define MARAGING_KILN_LIMIT 20 // unaged bars one kiln ages per firing

//////////////////////////////////////////////////////////////////////////////
// Ores

/obj/item/stack/ore/nickel
	name = "nickel ore"
	desc = "Pentlandite: heavy bronze-yellow lumps with a metallic shine. A little of it added to an open hearth melt makes nickel steel."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "ore_nickel"
	singular_name = "lump"
	flags = CONDUCT
	flammable = FALSE

/obj/item/stack/ore/cobalt
	name = "cobalt ore"
	desc = "Cobaltite: silvery-white crystals with a faint pink bloom where they weather. Steelmakers alloy cobalt into the hardest steels."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "ore_cobalt"
	singular_name = "lump"
	flags = CONDUCT
	flammable = FALSE

// Nickel and cobalt found in one mined wall, independent of the other ore rolls.
/turf/proc/mining_alloy_ores(mob/living/human/H)
	. = 0
	if (!map || map.ordinal_age < NICKEL_ORE_AGE)
		return
	var/doubled = istype(get_area(src), /area/caribbean/void/caves/special)
	if (prob(NICKEL_ORE_CHANCE * continent_ore_factor("nickel", src)))
		var/amount = rand(8, 16) * (doubled ? 2 : 1)
		spawn_stack(/obj/item/stack/ore/nickel, src, amount)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#c9bd84><b>nickel</b></font> ore!"))
		. += amount
	if (map.ordinal_age >= COBALT_ORE_AGE && prob(COBALT_ORE_CHANCE * continent_ore_factor("cobalt", src)))
		var/amount = rand(4, 8) * (doubled ? 2 : 1)
		spawn_stack(/obj/item/stack/ore/cobalt, src, amount)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#c8b6c6><b>cobalt</b></font> ore!"))
		. += amount
	if (map.ordinal_age >= CHROMITE_ORE_AGE && prob(CHROMITE_ORE_CHANCE * continent_ore_factor("chromite", src)))
		var/amount = rand(8, 16) * (doubled ? 2 : 1)
		spawn_stack(/obj/item/stack/ore/chromite, src, amount)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#5d5a63><b>chromite</b></font>!"))
		. += amount

/obj/item/stack/ore/chromite
	name = "chromite"
	desc = "Chromium ore: heavy black grains with a dull metallic lustre. Melted with nickel in an electric arc furnace it makes Inconel."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "ore_chromite"
	singular_name = "lump"
	flags = CONDUCT
	flammable = FALSE

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

/obj/item/stack/material/steel/nickel/grade_sheet()
	return "sheet-nickel"

/obj/item/stack/material/steel/nickel/update_icon()
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = grade_sheet()

/obj/item/stack/material/steel/nickel/grade_name()
	return "nickel"

/obj/item/stack/material/steel/nickel/grade_desc()
	return "Steel alloyed with a little nickel, tough rather than brittle: armour forged from it turns bullets and arrows far better, and blades come out better than from fine steel."

//////////////////////////////////////////////////////////////////////////////
// Maraging steel

// Straight from the arc furnace: nickel-cobalt steel still soft from the melt.
/obj/item/stack/material/steel/maraging_soft
	name = "unaged maraging steel"

/obj/item/stack/material/steel/maraging_soft/New()
	. = ..()
	stacktype = type

/obj/item/stack/material/steel/maraging_soft/grade_sheet()
	return "sheet-maraging_soft"

/obj/item/stack/material/steel/maraging_soft/update_icon()
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = grade_sheet()

/obj/item/stack/material/steel/maraging_soft/grade_name()
	return "unaged maraging"

/obj/item/stack/material/steel/maraging_soft/grade_desc()
	return "Nickel-cobalt steel still soft from the melt. Age it in a kiln firing to bring it to full hardness; forged now, it is only ordinary steel."

/obj/item/stack/material/steel/maraging
	name = "maraging steel"
	stock_grade = 1.25
	armor_blunt_grade = 1.2
	armor_pierce_grade = 1.35

/obj/item/stack/material/steel/maraging/New()
	. = ..()
	stacktype = type

/obj/item/stack/material/steel/maraging/grade_sheet()
	return "sheet-maraging"

/obj/item/stack/material/steel/maraging/update_icon()
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = grade_sheet()

/obj/item/stack/material/steel/maraging/grade_name()
	return "maraging"

/obj/item/stack/material/steel/maraging/grade_desc()
	return "Aged nickel-cobalt steel, very strong and still tough: the best steel for armour and blades."

// refining.dm's kiln attackby offers unaged maraging steel here.
/obj/structure/furnace/kiln/proc/accept_aging_steel(obj/item/I, mob/living/human/H)
	if (!istype(I, /obj/item/stack/material/steel/maraging_soft))
		return FALSE
	var/obj/item/stack/S = I
	var/held = 0
	for (var/obj/item/stack/material/steel/maraging_soft/A in contents)
		held += A.amount
	var/units = min(S.amount, MARAGING_KILN_LIMIT - held)
	if (units <= 0)
		to_chat(H, SPAN_WARNING("\The [src] holds no more steel to age."))
		return TRUE
	S.use(units)
	var/obj/item/stack/material/steel/maraging_soft/A = new(src)
	A.amount = units
	visible_message(SPAN_NOTICE("[H] sets [units] bar\s of unaged maraging steel in \the [src] to age."))
	return TRUE

// After every kiln firing: unaged maraging steel comes out aged.
/obj/structure/furnace/kiln/proc/age_steel()
	var/turf/T = get_turf(src)
	var/aged = 0
	for (var/obj/item/stack/material/steel/maraging_soft/A in contents)
		aged += A.amount
		qdel(A)
	if (aged > 0)
		spawn_stack(/obj/item/stack/material/steel/maraging, T, aged)
		visible_message(SPAN_NOTICE("[aged] bar\s of maraging steel come out of \the [src], aged hard."))

//////////////////////////////////////////////////////////////////////////////
// Inconel

/obj/item/stack/inconel
	name = "Inconel"
	desc = "Dull grey bars of a nickel-chromium superalloy that keeps its strength red hot. Overhaul an engine with Inconel parts and it wears half as fast."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "sheet-inconel"
	singular_name = "bar"
	max_amount = 50
	w_class = ITEM_SIZE_NORMAL
	flags = CONDUCT
	value = 6

/obj/item/stack/inconel/New()
	. = ..()
	stacktype = type
	update_icon()

/obj/item/stack/inconel/update_icon()
	icon_state = "sheet-inconel[pile_suffix(amount, list(13, 26, 39))]"

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
		if ("chromite")
			return /obj/item/stack/ore/chromite
	return null

/obj/structure/steel_works/arc_furnace/addition_key(obj/item/I)
	if (istype(I, /obj/item/stack/ore/nickel))
		return "nickel"
	if (istype(I, /obj/item/stack/ore/cobalt))
		return "cobalt"
	if (istype(I, /obj/item/stack/ore/chromite))
		return "chromite"
	return null

// Why this works won't take an addition now, or null.
/obj/structure/steel_works/proc/addition_refusal(key)
	return null

/obj/structure/steel_works/arc_furnace/addition_refusal(key)
	if (key == "cobalt" && (!map || map.ordinal_age < MARAGING_AGE))
		return "Nobody knows yet how to make steel of nickel and cobalt. Maraging steel comes in the Cold War age."
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
	var/refusal = addition_refusal(key)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		return
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
	use_addition("nickel", CEILING(alloyed / NICKEL_STEEL_PER_ORE, 1))
	spawn_stack(/obj/item/stack/material/steel/nickel, T, alloyed)
	return alloyed

/obj/structure/steel_works/proc/use_addition(key, units)
	additions[key] = (additions[key] || 0) - units
	if (additions[key] <= 0)
		additions -= key

// The arc furnace makes maraging steel from nickel and cobalt, then Inconel
// from nickel and chromite. Each bar of either takes one unit of the melt.
/obj/structure/steel_works/arc_furnace/alloy_output(turf/T, made)
	. = 0
	if (made <= 0)
		return
	var/nickel = additions["nickel"] || 0
	var/cobalt = additions["cobalt"] || 0
	if (nickel > 0 && cobalt > 0 && map && map.ordinal_age >= MARAGING_AGE)
		var/pairs = min(nickel, cobalt, CEILING(made / MARAGING_PER_PAIR, 1))
		var/maraging = min(made, pairs * MARAGING_PER_PAIR)
		use_addition("nickel", pairs)
		use_addition("cobalt", pairs)
		spawn_stack(/obj/item/stack/material/steel/maraging_soft, T, maraging)
		. += maraging
	nickel = additions["nickel"] || 0
	var/chromite = additions["chromite"] || 0
	var/inconel = min(made - ., round(nickel / INCONEL_NICKEL), round(chromite / INCONEL_CHROMITE))
	if (inconel > 0)
		use_addition("nickel", inconel * INCONEL_NICKEL)
		use_addition("chromite", inconel * INCONEL_CHROMITE)
		spawn_stack(/obj/item/stack/inconel, T, inconel)
		. += inconel

// What automation may take out beside the works' ordinary output.
/obj/structure/steel_works/proc/alloy_output_types()
	return list()

/obj/structure/steel_works/open_hearth/alloy_output_types()
	return list(/obj/item/stack/material/steel/nickel)

/obj/structure/steel_works/arc_furnace/alloy_output_types()
	return list(/obj/item/stack/material/steel/maraging_soft, /obj/item/stack/inconel)

#undef NICKEL_ORE_CHANCE
#undef NICKEL_ORE_AGE
#undef COBALT_ORE_CHANCE
#undef COBALT_ORE_AGE
#undef NICKEL_STEEL_PER_ORE
#undef ALLOY_ADDITION_LIMIT
#undef CHROMITE_ORE_CHANCE
#undef CHROMITE_ORE_AGE
#undef INCONEL_NICKEL
#undef INCONEL_CHROMITE
#undef MARAGING_PER_PAIR
#undef MARAGING_AGE
#undef MARAGING_KILN_LIMIT
