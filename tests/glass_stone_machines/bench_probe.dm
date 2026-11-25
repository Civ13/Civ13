// Minimal game objects; the production bench, proximity and admission logic are projected verbatim.
#define GLASS_BENCH_FUEL 0.5
#define GLASS_BENCH_YIELD 2
#define ON_BORDER 1
#define SPAN_WARNING(X) (X)
#define SPAN_NOTICE(X) (X)
#define QDELETED(X) (!(X))
var/global/datum/persistence_admission_identity
var/global/list/glass_bench_wares = list(/obj/item/ware = list(2, 1))
var/global/at_picker
var/global/at_batch
var/global/obj/structure/window/obstruction
var/global/picks = 0
var/global/batches = 0
var/global/checks = 0
var/global/list/failures = list()

/atom
	var/flags
	var/throwpass
	proc/visible_message(message)
	proc/attackby(obj/item/I, mob/living/human/H)

/obj/structure/window
	density = TRUE
	flags = ON_BORDER
	proc/is_fulltile()
		return dir & (dir - 1)

/obj/structure/furnace
	var/fuel = 1
	proc/burn_structure_fuel(amount)
		fuel -= amount

/obj/structure/workshop_machine
	var/anchored = TRUE
	var/busy = FALSE
	proc/handle_machine_tool(obj/item/I, mob/living/human/H)
		return FALSE
	proc/worker_ready(mob/living/human/H, obj/item/stack/S)
		return anchored && H && S && S.loc == H && get_dist(src, H) <= 1

/obj/item/stack
	var/amount = 2
	proc/use(amount_used)
		amount -= amount_used

/obj/item/stack/material/glass
/obj/item/ware
/mob/living/human

/proc/get_turf(atom/A)
	while (A && !isturf(A))
		A = A.loc
	return A

/proc/persistence_admission_blocked()
	return FALSE // The modeled save finishes during a wait; only the identity remembers it.

/proc/glass_bench_choices(mob/living/human/H)
	return list("Ware" = /obj/item/ware)

/proc/WWinput(mob/living/human/H, question, title, default_pick, list/choices)
	picks++
	bench_event(at_picker)
	return "Ware"

/proc/do_after(mob/living/human/H, time, atom/target)
	batches++
	bench_event(at_batch)
	return TRUE

/proc/bench_event(trigger)
	if (trigger == "window")
		obstruction.dir = EAST
	else if (trigger == "save")
		persistence_admission_identity = new
	else if (trigger == "furnace")
		obstruction.dir = NORTH

/proc/to_chat(mob/M, message)
/proc/crafting_recipe_allowed(mob/M, ware)
	return TRUE

/proc/bench_check(ok, name)
	checks++
	if (!ok)
		failures += name

/world
	maxx = 4
	maxy = 4
	maxz = 1
	visibility = 0

/client/New()
	return null

/world/OpenPort(port)
	return ..("none")

/world/New()
	OpenPort("none")
	var/turf/bench_tile = locate(2, 2, 1)
	var/turf/fire_tile = locate(2, 3, 1)
	var/obj/structure/workshop_machine/glass_bench/bench = new(bench_tile)
	var/obj/structure/furnace/fire = new(fire_tile)
	var/mob/living/human/H = new(locate(3, 2, 1))
	var/obj/item/stack/material/glass/glass = new(H)
	obstruction = new(bench_tile)
	persistence_admission_identity = new
	obstruction.dir = NORTH
	bench.attackby(glass, H)
	bench_check(!picks && !batches && fire.fuel == 1 && glass.amount == 2, "blocked furnace was used")

	// Neither obstruction initially exists. Toggle it at the exact wait boundary.
	obstruction.dir = WEST
	at_picker = "window"
	bench.attackby(glass, H)
	bench_check(picks == 1 && !batches && fire.fuel == 1 && glass.amount == 2, "lost worker reach during picker was ignored")

	obstruction.dir = WEST
	at_picker = "save"
	bench.attackby(glass, H)
	bench_check(picks == 2 && !batches && fire.fuel == 1 && glass.amount == 2, "completed save during picker was ignored")

	at_picker = null
	at_batch = "window"
	bench.attackby(glass, H)
	bench_check(batches == 1 && fire.fuel == 1 && glass.amount == 2 && !bench.busy, "lost worker reach during batch consumed inputs")

	obstruction.dir = WEST
	at_batch = "furnace"
	bench.attackby(glass, H)
	bench_check(batches == 2 && fire.fuel == 1 && glass.amount == 2 && !bench.busy, "blocked furnace during batch consumed inputs")

	obstruction.dir = WEST
	at_batch = "save"
	bench.attackby(glass, H)
	bench_check(batches == 3 && fire.fuel == 1 && glass.amount == 2 && !bench.busy, "completed save during batch consumed inputs")

	var/wares_before = 0
	for (var/obj/item/ware/W in bench_tile)
		wares_before++
	bench_check(!wares_before, "an interrupted action produced wares")
	at_batch = null
	bench.attackby(glass, H)
	bench_check(fire.fuel == 0.5 && glass.amount == 0 && !bench.busy, "valid new action did not pay exactly once")

	var/wares = 0
	for (var/obj/item/ware/W in bench_tile)
		wares++
	bench_check(wares == 2 && !world.port, "valid new action did not make two wares offline")
	text2file(json_encode(list("checks" = checks, "failures" = failures)), "result.json")
	del(world)
