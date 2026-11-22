// Clay, lime and fire: the potter's wheel, the brick mould bench, the forge
// bellows and the lime kiln. Each is one structure with a few number vars;
// what a station makes is a shared table below. Hand routes stay as they are,
// the stations are faster or make batches. See docs/clay-lime-fire.md.

// Potter's wheel wares: unfired type = list(clay, hand time in deciseconds).
// Costs and times are the hand recipes in material_recipes_global.txt; the
// wheel works in a third of the time. tests/clay_lime_fire keeps them equal.
var/global/list/potters_wheel_wares = list(
	/obj/item/weapon/clay/verysmallclaypot = list(1, 20),
	/obj/item/weapon/clay/crucible = list(1, 30),
	/obj/item/weapon/clay/smallclaypot = list(1, 30),
	/obj/item/weapon/clay/claypot = list(2, 50),
	/obj/item/weapon/clay/bigclaypot = list(3, 60),
	/obj/item/weapon/clay/cookingpot = list(2, 20),
	/obj/item/weapon/clay/claycup = list(1, 30),
	/obj/item/weapon/clay/winecup = list(1, 30),
	/obj/item/weapon/clay/claybowl = list(1, 30),
	/obj/item/weapon/clay/clayjug = list(2, 50),
	/obj/item/weapon/clay/claypitcher = list(2, 50),
	/obj/item/weapon/clay/largeclaypitcher = list(3, 60),
	/obj/item/weapon/clay/vase = list(3, 50),
	/obj/item/weapon/clay/crock = list(3, 60),
	/obj/item/weapon/clay/storage_jar = list(3, 60), // stone_age_storage.dm
	/obj/item/weapon/clay/storage_jar/zeer_pot = list(4, 80), // stone_age_storage.dm
	/obj/item/weapon/clay/vessel = list(3, 50), // pottery_design.dm
	/obj/item/weapon/clay/washbasin = list(3, 50), // wash_places.dm
)
#define POTTERS_WHEEL_SPEED 3

// Brick mould bench batches: unfired type = list(clay, quicklime) for one
// frame of BRICK_BENCH_BATCH bricks. By hand a cement brick is four clay.
var/global/list/brick_bench_batches = list(
	/obj/item/weapon/clay/claybricks = list(4, 0),
	/obj/item/weapon/clay/advclaybricks = list(4, 0),
	/obj/item/weapon/clay/advclaybricks/cement = list(4, 2),
)
#define BRICK_BENCH_BATCH 8
#define BRICK_BENCH_TIME 100
#define BRICK_BENCH_LIME_LIMIT 20

#define BELLOWS_BLAST_TIME 900
#define BELLOWS_TIME_FACTOR 0.75
#define BELLOWS_FUEL_BACK 0.5
#define LIME_KILN_LIMIT 20

//////////////////////////////////////////////////////////////////////////////
// Shared base: wrench to fasten, hammer to take apart, one worker at a time.

/obj/structure/workshop_machine
	name = "workshop machine"
	icon = 'icons/obj/workshop_machines.dmi'
	density = TRUE
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/busy = FALSE

/obj/structure/workshop_machine/persistence_runtime_var(key)
	return key == "busy" || ..()

// TRUE when the held item was a fastening or dismantling tool and was handled.
/obj/structure/workshop_machine/proc/handle_machine_tool(obj/item/I, mob/living/human/H)
	if (busy)
		return FALSE
	if (is_tool(I, TOOL_WRENCH))
		timed_toggle_anchor(H)
		return TRUE
	if (is_tool(I, TOOL_HAMMER) && H.a_intent == I_HARM)
		visible_message(SPAN_WARNING("[H] starts to take \the [src] apart."))
		playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (do_after(H, 50, src) && !QDELETED(src) && !busy)
			visible_message(SPAN_WARNING("[H] takes \the [src] apart."))
			dismantled()
			qdel(src)
		return TRUE
	return FALSE

/obj/structure/workshop_machine/proc/dismantled()
	return

// The worker still stands at the fastened machine holding this stack.
/obj/structure/workshop_machine/proc/worker_ready(mob/living/human/H, obj/item/stack/S)
	return !QDELETED(src) && anchored && istype(H) && !QDELETED(S) && S.loc == H && get_dist(src, H) <= 1 && !H.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

//////////////////////////////////////////////////////////////////////////////
// Potter's wheel

/obj/structure/workshop_machine/potters_wheel
	name = "potter's wheel"
	desc = "A kick wheel: a heavy stone flywheel under a small wheel head. Use clay on it to throw pots, cups and jugs in a third of the time of shaping them by hand. It keeps turning out the same ware until the clay runs out or you step away."
	icon_state = "potters_wheel"
	// Slip keeps the clay workable on the wheel (station_water.dm).
	water_capacity = 150
	water_per_use = 10

/obj/structure/workshop_machine/potters_wheel/examine(mob/user, distance)
	..(user, distance)
	station_water_examine(user)

/proc/potters_wheel_choices(mob/living/human/H)
	var/list/choices = list()
	for (var/ware in potters_wheel_wares)
		if (!crafting_recipe_allowed(H, "[ware]"))
			continue
		var/obj/item/weapon/clay/W = ware
		var/label = replacetext(initial(W.name), "unfired ", "")
		if (ware == /obj/item/weapon/clay/claybowl)
			label = "clay bowl"
		choices[label] = ware
	return choices

/obj/structure/workshop_machine/potters_wheel/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (station_water_pour(I, H))
		return
	if (!istype(I, /obj/item/stack/material/clay))
		return ..()
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already at \the [src]."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	var/list/choices = potters_wheel_choices(H)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("You do not know how to throw anything on \the [src] yet."))
		return
	var/picked = WWinput(H, "What do you want to throw?", "Potter's wheel", choices[1], choices + "Cancel")
	if (!picked || picked == "Cancel" || !(picked in choices))
		return
	throw_wares(H, I, choices[picked], picked)

/obj/structure/workshop_machine/potters_wheel/proc/throw_wares(mob/living/human/H, obj/item/stack/material/clay/S, ware, label)
	if (busy || !worker_ready(H, S))
		return 0
	var/list/cost = potters_wheel_wares[ware]
	if (S.amount < cost[1])
		to_chat(H, SPAN_WARNING("You need [cost[1]] clay for \a [label]."))
		return 0
	busy = TRUE
	icon_state = "potters_wheel_on"
	visible_message(SPAN_NOTICE("[H] kicks \the [src] up to speed and centres the clay."))
	var/made = 0
	while (worker_ready(H, S) && S.amount >= cost[1])
		if (!station_has_water())
			station_take_water(H)
			break
		if (!do_after(H, driven_time(max(5, round(cost[2] / POTTERS_WHEEL_SPEED))), src))
			break
		if (!worker_ready(H, S) || S.amount < cost[1] || !crafting_recipe_allowed(H, "[ware]") || !station_take_water(H))
			break
		var/last = S.amount <= cost[1]
		S.use(cost[1])
		new ware(get_turf(src))
		made++
		if (last)
			break
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "potters_wheel"
	if (made)
		to_chat(H, SPAN_NOTICE("You throw [made] [label][made == 1 ? "" : "s"]. Fire [made == 1 ? "it" : "them"] to finish."))
	return made

//////////////////////////////////////////////////////////////////////////////
// Brick mould bench

/obj/structure/workshop_machine/brick_bench
	name = "brick mould bench"
	desc = "A stout bench with an eight-cell mould frame. Use four clay on it to strike eight unfired bricks at once. Load quicklime to mould cement bricks from far less clay."
	icon_state = "brick_bench"
	var/lime = 0
	// Clay and sand are mixed wet (station_water.dm).
	water_capacity = 100
	water_per_use = 20

/obj/structure/workshop_machine/brick_bench/examine(mob/user, distance)
	..(user, distance)
	station_water_examine(user)
	if (lime)
		to_chat(user, SPAN_NOTICE("Its lime tub holds [lime] quicklime."))

/obj/structure/workshop_machine/brick_bench/dismantled()
	if (lime > 0)
		var/obj/item/stack/ore/quicklime/Q = new(get_turf(src))
		Q.amount = lime
		lime = 0

/proc/brick_bench_choices(mob/living/human/H)
	var/list/choices = list()
	for (var/brick in brick_bench_batches)
		if (!crafting_recipe_allowed(H, "[brick]"))
			continue
		var/obj/item/weapon/clay/B = brick
		choices[replacetext(initial(B.name), "unfired ", "")] = brick
	return choices

/obj/structure/workshop_machine/brick_bench/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (station_water_pour(I, H))
		return
	if (istype(I, /obj/item/stack/ore/quicklime))
		var/obj/item/stack/ore/quicklime/Q = I
		var/moved = min(Q.amount, BRICK_BENCH_LIME_LIMIT - lime)
		if (moved <= 0)
			to_chat(H, SPAN_WARNING("\The [src]'s lime tub is full."))
			return
		lime += moved
		Q.use(moved)
		to_chat(H, SPAN_NOTICE("You tip [moved] quicklime into \the [src]'s tub."))
		return
	if (!istype(I, /obj/item/stack/material/clay))
		return ..()
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already at \the [src]."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	var/list/choices = brick_bench_choices(H)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("You do not know how to mould anything on \the [src] yet."))
		return
	var/picked = WWinput(H, "What do you want to mould?", "Brick mould bench", choices[1], choices + "Cancel")
	if (!picked || picked == "Cancel" || !(picked in choices))
		return
	mould_bricks(H, I, choices[picked], picked)

/obj/structure/workshop_machine/brick_bench/proc/batch_refusal(obj/item/stack/material/clay/S, brick)
	var/list/cost = brick_bench_batches[brick]
	if (S.amount < cost[1])
		return "You need [cost[1]] clay to fill the mould."
	if (lime < cost[2])
		return "The mould needs [cost[2]] quicklime in the tub for cement bricks."
	return null

/obj/structure/workshop_machine/brick_bench/proc/mould_bricks(mob/living/human/H, obj/item/stack/material/clay/S, brick, label)
	if (busy || !worker_ready(H, S))
		return 0
	var/refusal = batch_refusal(S, brick)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		return 0
	var/list/cost = brick_bench_batches[brick]
	busy = TRUE
	icon_state = "brick_bench_full"
	visible_message(SPAN_NOTICE("[H] packs clay into \the [src]'s mould."))
	var/batches = 0
	while (worker_ready(H, S) && !batch_refusal(S, brick))
		if (!station_has_water())
			station_take_water(H)
			break
		if (!do_after(H, BRICK_BENCH_TIME, src))
			break
		if (!worker_ready(H, S) || batch_refusal(S, brick) || !crafting_recipe_allowed(H, "[brick]") || !station_take_water(H))
			break
		var/last = S.amount <= cost[1]
		S.use(cost[1])
		lime -= cost[2]
		loose_pile_spawn(brick, get_turf(src), BRICK_BENCH_BATCH)
		batches++
		if (last)
			break
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "brick_bench"
	if (batches)
		to_chat(H, SPAN_NOTICE("You turn out [batches * BRICK_BENCH_BATCH] [label]. Fire them to finish."))
	return batches

//////////////////////////////////////////////////////////////////////////////
// Bellows

/obj/structure/workshop_machine/bellows
	name = "bellows"
	desc = "Leather forge bellows on a timber stand. Pump them with an empty hand beside a bloomery, blast furnace or kiln: for a minute and a half, a firing started there takes a quarter less time and fuel. Set beside a treadwheel, horse gin, mill wheel or windmill, or on a line shaft, they blow on their own for as long as they are driven."
	icon_state = "bellows"
	drive_draw = 1

/obj/structure/furnace
	var/tmp/bellows_until = 0 // world.time the air blast lasts to

/obj/structure/furnace/proc/bellows_blowing()
	if (world.time < bellows_until)
		return TRUE
	for (var/obj/structure/workshop_machine/bellows/B in range(1, src))
		if (B.driven())
			return TRUE
	return FALSE

// TRUE while a prime mover works the bellows (mechanical_power.dm).
/obj/structure/workshop_machine/bellows/proc/driven()
	return anchored && isturf(loc) && mechanical_drive_factor(src) < 1

/obj/structure/workshop_machine/bellows/examine(mob/user, distance)
	..(user, distance)
	if (driven())
		to_chat(user, SPAN_NOTICE("A drive works them: every firing started beside them runs hotter."))

// refining.dm starts every bloomery, blast furnace and kiln firing here.
/obj/structure/furnace/start_smelt()
	if (!bellows_blowing())
		return ..()
	var/normal_time = smelt_time
	smelt_time = round(normal_time * BELLOWS_TIME_FACTOR)
	. = ..()
	smelt_time = normal_time
	fuel += BELLOWS_FUEL_BACK

/obj/structure/workshop_machine/bellows/proc/furnaces_in_reach()
	var/list/found = list()
	for (var/obj/structure/furnace/F in range(1, src))
		found += F
	return found

/obj/structure/workshop_machine/bellows/attack_hand(mob/living/human/H)
	if (!istype(H) || busy)
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	if (!length(furnaces_in_reach()))
		to_chat(H, SPAN_WARNING("\The [src] must stand beside a bloomery, blast furnace or kiln."))
		return
	busy = TRUE
	icon_state = "bellows_pump"
	visible_message(SPAN_NOTICE("[H] works \the [src]."))
	var/done = do_after(H, 30, src)
	busy = FALSE
	if (QDELETED(src))
		return
	icon_state = "bellows"
	if (!done || !anchored)
		return
	var/blown = 0
	for (var/obj/structure/furnace/F in furnaces_in_reach())
		F.bellows_until = world.time + BELLOWS_BLAST_TIME
		blown++
	if (blown)
		to_chat(H, SPAN_NOTICE("The fire roars. A firing started in the next minute and a half will run hotter."))

/obj/structure/workshop_machine/bellows/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	return ..()

//////////////////////////////////////////////////////////////////////////////
// Lime kiln and quicklime

/obj/item/stack/ore/quicklime
	name = "quicklime"
	desc = "Burnt lime. Mixed into clay at a brick mould bench it makes cement bricks; slaked in a container of water it makes limewash for walls and floors."
	icon = 'icons/obj/workshop_machines.dmi'
	icon_state = "quicklime"
	singular_name = "lump"
	flammable = FALSE

/obj/structure/furnace/lime_kiln
	name = "lime kiln"
	desc = "A dry-stone shaft kiln. Load stone, marble or crushed shell and fuel, then light it by hand to burn the charge to quicklime."
	icon = 'icons/obj/workshop_machines.dmi'
	icon_state = "lime_kiln"
	base_state = "lime_kiln"
	smelt_time = 400
	var/stone_charge = 0
	var/marble_charge = 0
	var/shell_charge = 0

/obj/structure/furnace/lime_kiln/factory_port_ready()
	return FALSE

/obj/structure/furnace/lime_kiln/proc/charge()
	return stone_charge + marble_charge + shell_charge

/obj/structure/furnace/lime_kiln/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [charge()] of [LIME_KILN_LIMIT] stone or shell and [fuel] fuel."))

/obj/structure/furnace/lime_kiln/attackby(obj/item/I, mob/living/human/H)
	if (!I || !I.loc || !istype(H))
		return
	if (H.a_intent != I_HELP)
		return ..()
	if (handle_structure_tool(I, H))
		return
	if (!istype(I, /obj/item/stack))
		return
	var/obj/item/stack/S = I
	var/kiln_fuel = solid_fuel_value(S, furnace_fuel_rates)
	if (kiln_fuel)
		record_wood_fuel(S, kiln_fuel)
		fuel += kiln_fuel
		to_chat(H, "You place \the [S] in \the [src], refueling it.")
		H.remove_from_mob(S)
		qdel(S)
		return
	var/is_marble = S.type == /obj/item/stack/material/marble
	var/is_shell = istype(S, /obj/item/stack/crushed_shell)
	if (S.type != /obj/item/stack/material/stone && !is_marble && !is_shell)
		to_chat(H, SPAN_WARNING("\The [src] burns only stone, marble or crushed shell."))
		return
	if (on)
		to_chat(H, SPAN_WARNING("\The [src] is burning. Wait for it to finish."))
		return
	var/moved = min(S.amount, LIME_KILN_LIMIT - charge())
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is full."))
		return
	if (is_marble)
		marble_charge += moved
	else if (is_shell)
		shell_charge += moved
	else
		stone_charge += moved
	S.use(moved)
	visible_message(SPAN_NOTICE("[H] loads [moved] [is_marble ? "marble" : (is_shell ? "crushed shell" : "stone")] into \the [src]."))

/obj/structure/furnace/lime_kiln/attack_hand(mob/living/human/H)
	if (on)
		return
	if (charge() <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is empty. Load stone, marble or crushed shell first."))
		return
	return ..()

/obj/structure/furnace/lime_kiln/process()
	var/burnt = charge()
	if (burnt <= 0)
		return
	stone_charge = 0
	marble_charge = 0
	shell_charge = 0
	var/obj/item/stack/ore/quicklime/Q = new(get_turf(src))
	Q.amount = burnt

/obj/structure/furnace/lime_kiln/empty()
	set category = null
	set name = "Empty"
	set src in range(1)
	if (on)
		return
	if (stone_charge > 0)
		var/obj/item/stack/material/stone/S = new(get_turf(src))
		S.amount = stone_charge
		stone_charge = 0
	if (marble_charge > 0)
		var/obj/item/stack/material/marble/M = new(get_turf(src))
		M.amount = marble_charge
		marble_charge = 0
	if (shell_charge > 0)
		new /obj/item/stack/crushed_shell(get_turf(src), shell_charge)
		shell_charge = 0

#undef POTTERS_WHEEL_SPEED
#undef BRICK_BENCH_BATCH
#undef BRICK_BENCH_TIME
#undef BRICK_BENCH_LIME_LIMIT
#undef BELLOWS_BLAST_TIME
#undef BELLOWS_TIME_FACTOR
#undef BELLOWS_FUEL_BACK
#undef LIME_KILN_LIMIT
