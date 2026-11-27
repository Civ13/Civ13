// Wire drawing bench: metal pulled through a draw plate into cable.
//
// By hand one unit of metal makes a 10 m coil. The bench pulls the same unit
// through a plate of narrowing holes round a capstan, so it yields a 25 m
// coil in less time, and keeps drawing through the stack in hand. The coils
// are the standard ones (materials/wire_materials.dm); a prime mover turning
// next to the bench speeds the pull (mechanical_power.dm).

#define WIRE_BENCH_TIME 25
#define WIRE_BENCH_YIELD 25

// Metal stack -> the coil it is drawn into.
var/global/list/wire_bench_coils = list(
	/obj/item/stack/material/copper = /obj/item/stack/cable_coil,
	/obj/item/stack/material/iron = /obj/item/stack/cable_coil/iron,
	/obj/item/stack/material/aluminium = /obj/item/stack/cable_coil/aluminium,
	/obj/item/stack/material/silver = /obj/item/stack/cable_coil/silver,
	/obj/item/stack/material/gold = /obj/item/stack/cable_coil/gold,
)

/obj/structure/workshop_machine/wire_bench
	name = "wire drawing bench"
	desc = "A long bench with an iron draw plate of narrowing holes and a capstan. Use copper, iron, aluminium, silver or gold on it to draw cable: each unit of metal makes a 25 metre coil, where working it by hand makes 10. It keeps drawing until the metal runs out or you step away."
	icon = 'icons/obj/wire_bench.dmi'
	icon_state = "wire_bench"

/obj/structure/workshop_machine/wire_bench/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (!I || !(I.type in wire_bench_coils))
		return ..()
	if (!can_start_material_work(H))
		return
	draw_wire(H, I)

// Draw the stack in hand into coils on the bench's tile. Returns the metres made.
/obj/structure/workshop_machine/wire_bench/proc/draw_wire(mob/living/human/H, obj/item/stack/material/S)
	if (busy || !worker_ready(H, S))
		return 0
	var/coil_type = wire_bench_coils[S.type]
	if (!coil_type)
		return 0
	if (!crafting_recipe_allowed(H, "[type]") || !crafting_recipe_allowed(H, "[coil_type]"))
		to_chat(H, SPAN_WARNING("You do not know how to draw that into cable yet."))
		return 0
	busy = TRUE
	icon_state = "wire_bench_on"
	visible_message(SPAN_NOTICE("[H] points a rod of metal and starts to draw it through \the [src]."))
	var/made = 0
	var/obj/item/stack/cable_coil/coil = null
	while (worker_ready(H, S) && S.amount >= 1)
		if (!do_after(H, driven_time(WIRE_BENCH_TIME), src))
			break
		if (!worker_ready(H, S) || S.amount < 1 || !crafting_recipe_allowed(H, "[coil_type]"))
			break
		var/last = S.amount <= 1
		S.use(1)
		if (QDELETED(coil) || coil.loc != get_turf(src) || coil.amount + WIRE_BENCH_YIELD > coil.max_amount)
			coil = new coil_type(get_turf(src))
			coil.amount = WIRE_BENCH_YIELD
		else
			coil.amount += WIRE_BENCH_YIELD
		coil.update_icon()
		made += WIRE_BENCH_YIELD
		if (last)
			break
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "wire_bench"
	if (made)
		to_chat(H, SPAN_NOTICE("You draw [made] metres of cable."))
	return made

#undef WIRE_BENCH_TIME
#undef WIRE_BENCH_YIELD
