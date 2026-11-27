// Glass and stone: the glassblowing bench and the mason's saw. Both build on
// the workshop machine base in clay_lime_fire.dm and hold no lists; what they
// make is the shared tables below. Hand routes stay as they are.
// See docs/glass-stone-machines.md.

// Blown wares: type = list(glass, hand time in deciseconds). Costs and times
// are the hand recipes in material_recipes_global.txt; the bench blows
// GLASS_BENCH_YIELD pieces from that glass. tests/glass_stone_machines keeps
// them equal.
var/global/list/glass_bench_wares = list(
	/obj/item/weapon/reagent_containers/food/drinks/drinkingglass = list(2, 25),
	/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/beermug = list(2, 25),
	/obj/item/weapon/reagent_containers/food/drinks/britmug = list(2, 25),
	/obj/item/weapon/reagent_containers/food/drinks/tea/empty = list(2, 50),
	/obj/item/weapon/reagent_containers/food/drinks/teapot = list(4, 70),
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small = list(2, 40),
	/obj/item/weapon/reagent_containers/food/drinks/bottle/large = list(4, 60),
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/beer = list(2, 40),
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom/fancybeer = list(3, 70),
	/obj/item/weapon/reagent_containers/glass/preserve_jar = list(1, 20),
	/obj/item/weapon/starterjar = list(3, 50),
	/obj/item/glass_jar = list(2, 50),
	/obj/item/weapon/reagent_containers/glass/beaker/vial = list(1, 40),
	/obj/item/weapon/reagent_containers/glass/beaker = list(2, 40),
	/obj/item/weapon/reagent_containers/glass/beaker/large = list(3, 40),
	/obj/item/weapon/reagent_containers/dropper = list(1, 40),
	/obj/item/lightbulb = list(2, 55),
	/obj/item/lightbulb/tube = list(1, 55),
)
#define GLASS_BENCH_YIELD 2
#define GLASS_BENCH_FUEL 0.5

// Mason's saw cuts: block type = list(blocks in, brick type, bricks out).
// By hand one stone or marble block is one brick and three sandstone are one.
var/global/list/masons_saw_cuts = list(
	/obj/item/stack/material/stone = list(1, /obj/item/stack/material/stonebrick, 2),
	/obj/item/stack/material/marble = list(1, /obj/item/stack/material/marblebrick, 2),
	/obj/item/stack/material/sandstone = list(3, /obj/item/stack/material/stonebrick, 2),
)
#define MASONS_SAW_TIME 20

//////////////////////////////////////////////////////////////////////////////
// Glassblowing bench

/obj/structure/workshop_machine/glass_bench
	name = "glassblowing bench"
	desc = "A glassblower's bench with a blowpipe, a marver and a water bucket. Set it beside a fuelled bloomery, blast furnace or kiln and use glass on it: each gather is reheated in the fire and blown into two pieces for the glass of one."
	icon = 'icons/obj/glass_stone_machines.dmi'
	icon_state = "glass_bench"

// The fuelled furnace beside the bench the gather is reheated in, or null.
/obj/structure/workshop_machine/glass_bench/proc/glory_hole()
	for (var/obj/structure/furnace/F in range(1, src))
		if (!QDELETED(F) && F.fuel >= GLASS_BENCH_FUEL && Adjacent(F))
			return F
	return null

// A save or load can finish while the picker or batch is still waiting.
/obj/structure/workshop_machine/glass_bench/proc/glass_worker_ready(mob/living/human/H, obj/item/stack/material/glass/S, datum/admission)
	return !persistence_admission_changed(admission) && !QDELETED(H) && worker_ready(H, S) && isturf(H.loc) && Adjacent(H)

/proc/glass_bench_choices(mob/living/human/H)
	var/list/choices = list()
	for (var/ware in glass_bench_wares)
		if (!crafting_recipe_allowed(H, "[ware]"))
			continue
		var/obj/item/W = ware
		choices[initial(W.name)] = ware
	return choices

/obj/structure/workshop_machine/glass_bench/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (I.type != /obj/item/stack/material/glass)
		return ..()
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already at \the [src]."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	var/datum/admission = persistence_admission_identity
	if (!glass_worker_ready(H, I, admission))
		return
	if (!glory_hole())
		to_chat(H, SPAN_WARNING("\The [src] needs a reachable, fuelled bloomery, blast furnace or kiln to reheat the glass."))
		return
	var/list/choices = glass_bench_choices(H)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("You do not know how to blow anything on \the [src] yet."))
		return
	var/picked = WWinput(H, "What do you want to blow?", "Glassblowing bench", choices[1], choices + "Cancel")
	if (!picked || picked == "Cancel" || !(picked in choices))
		return
	blow_wares(H, I, choices[picked], picked, admission)

/obj/structure/workshop_machine/glass_bench/proc/blow_wares(mob/living/human/H, obj/item/stack/material/glass/S, ware, label, datum/admission)
	if (busy || !glass_worker_ready(H, S, admission))
		return 0
	var/list/cost = glass_bench_wares[ware]
	if (S.amount < cost[1])
		to_chat(H, SPAN_WARNING("You need [cost[1]] glass for [label]."))
		return 0
	busy = TRUE
	icon_state = "glass_bench_on"
	visible_message(SPAN_NOTICE("[H] gathers molten glass on the blowpipe."))
	var/made = 0
	while (glass_worker_ready(H, S, admission) && S.amount >= cost[1] && glory_hole())
		if (!do_after(H, cost[2], src))
			break
		if (!glass_worker_ready(H, S, admission) || S.amount < cost[1] || !crafting_recipe_allowed(H, "[ware]"))
			break
		var/obj/structure/furnace/F = glory_hole()
		if (!F)
			break
		var/last = S.amount <= cost[1]
		F.burn_structure_fuel(GLASS_BENCH_FUEL)
		S.use(cost[1])
		for (var/i in 1 to GLASS_BENCH_YIELD)
			new ware(get_turf(src))
		made += GLASS_BENCH_YIELD
		if (last)
			break
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "glass_bench"
	if (made)
		to_chat(H, SPAN_NOTICE("You blow [made] pieces of [label]."))
	else if (glass_worker_ready(H, S, admission) && !glory_hole())
		to_chat(H, SPAN_WARNING("No reachable furnace has enough fuel to reheat the glass."))
	return made

//////////////////////////////////////////////////////////////////////////////
// Mason's saw

/obj/structure/workshop_machine/masons_saw
	name = "mason's saw"
	desc = "A frame saw over a pair of trestles. Use stone, marble or sandstone blocks on it to saw them into bricks: two bricks from each stone or marble block, or from every three sandstone. It keeps cutting the held stack until it runs out or you step away."
	icon = 'icons/obj/glass_stone_machines.dmi'
	icon_state = "masons_saw"

/obj/structure/workshop_machine/masons_saw/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (!(stone_workshop_feed_type(I) in masons_saw_cuts))
		return ..()
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already at \the [src]."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	saw_blocks(H, I)

/obj/structure/workshop_machine/masons_saw/proc/saw_blocks(mob/living/human/H, obj/item/stack/material/S)
	if (busy || !worker_ready(H, S))
		return 0
	var/list/cut = masons_saw_cuts[stone_workshop_feed_type(S)]
	if (!crafting_recipe_allowed(H, "[cut[2]]"))
		to_chat(H, SPAN_WARNING("You do not know how to cut bricks yet."))
		return 0
	if (S.amount < cut[1])
		to_chat(H, SPAN_WARNING("You need [cut[1]] blocks for a cut."))
		return 0
	busy = TRUE
	icon_state = "masons_saw_on"
	visible_message(SPAN_NOTICE("[H] sets a block on \the [src] and starts sawing."))
	var/made = 0
	var/obj/item/stack/material/pile = null
	while (worker_ready(H, S) && S.amount >= cut[1])
		if (!do_after(H, driven_time(MASONS_SAW_TIME), src))
			break
		if (!worker_ready(H, S) || S.amount < cut[1] || !crafting_recipe_allowed(H, "[cut[2]]"))
			break
		var/last = S.amount <= cut[1]
		var/brick_type = cut[2]
		S.use(cut[1])
		if (QDELETED(pile) || pile.loc != get_turf(src) || pile.amount + cut[3] > pile.max_amount)
			pile = new brick_type(get_turf(src))
			pile.amount = cut[3]
		else
			pile.amount += cut[3]
		pile.update_icon()
		made += cut[3]
		if (last)
			break
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "masons_saw"
	if (made)
		to_chat(H, SPAN_NOTICE("You saw out [made] bricks."))
	return made

#undef GLASS_BENCH_YIELD
#undef GLASS_BENCH_FUEL
#undef MASONS_SAW_TIME
