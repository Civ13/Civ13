// Composite armour (docs/aluminium.md "Composite armour"): ceramic tiles of
// fired alumina bonded to aramid make a composite panel, which is fitted over
// an armoured wall of any frame vehicle - tanks, armoured cars, carriers,
// hand-built frames. A panel adds half the wall's steel armour again (at
// least 20) and a third of that in health, and it weighs half what the same
// protection in steel would, so heavy tanks get much tougher for less speed.
//
// Ceramic: the kiln fires alumina into tiles (refining.dm hooks). Panels: two
// tiles bonded to one sheet of prepared Kevlar by hand, once Composite Armour
// is known.
// ============================================================

#define COMPOSITE_KILN_LIMIT 40     // alumina one kiln fires at once
#define COMPOSITE_MIN_BONUS 20
#define COMPOSITE_FIT_TIME 80

/obj/item/stack/ceramic_tile
	name = "ceramic armour tile"
	desc = "Hard white alumina tiles, fired in a kiln. Bond two to a sheet of prepared Kevlar to make a composite armour panel."
	icon = 'icons/obj/aluminium.dmi'
	icon_state = "ceramic_tile"
	singular_name = "tile"
	max_amount = 50
	w_class = ITEM_SIZE_NORMAL
	value = 3

/obj/item/stack/ceramic_tile/New()
	..()
	update_icon()

/obj/item/stack/ceramic_tile/update_icon()
	icon_state = "ceramic_tile[pile_suffix(amount, list(10, 20, 35))]"

/obj/item/stack/ceramic_tile/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/stack/material/preparedkevlar))
		make_composite_panel(H, W)
		return
	return ..()

// Two tiles on one sheet of prepared Kevlar make one panel.
/obj/item/stack/ceramic_tile/proc/make_composite_panel(mob/living/human/H, obj/item/stack/material/preparedkevlar/K)
	if (!istype(H) || !istype(K))
		return FALSE
	if (!research_node_known(H, "composite_armour"))
		to_chat(H, SPAN_WARNING("You don't know how to bond ceramic to aramid. Composite Armour research is required."))
		return FALSE
	if (amount < 2)
		to_chat(H, SPAN_WARNING("A panel takes two ceramic tiles."))
		return FALSE
	to_chat(H, SPAN_NOTICE("You start bonding the tiles to the Kevlar..."))
	if (!do_after(H, 40, src) || QDELETED(src) || QDELETED(K) || amount < 2 || K.amount < 1)
		return FALSE
	use(2)
	K.use(1)
	spawn_stack(/obj/item/stack/composite_panel, get_turf(H), 1)
	to_chat(H, SPAN_NOTICE("You bond a composite armour panel."))
	return TRUE

/obj/item/stack/composite_panel
	name = "composite armour panel"
	desc = "Ceramic tiles bonded to layers of aramid. Use it on an armoured wall of a vehicle to fit it over the plate."
	icon = 'icons/obj/aluminium.dmi'
	icon_state = "composite_panel"
	singular_name = "panel"
	max_amount = 20
	w_class = ITEM_SIZE_LARGE
	value = 12

/obj/item/stack/composite_panel/New()
	..()
	update_icon()

/obj/item/stack/composite_panel/update_icon()
	icon_state = "composite_panel[pile_suffix(amount, list(5, 10, 15))]"

// ---- On the vehicle ----

/obj/structure/vehicleparts/frame
	var/list/composite_bonus = null // side name -> armour a panel added

// The wall lists by side name.
/obj/structure/vehicleparts/frame/proc/walls_by_side()
	return list("front" = w_front, "back" = w_back, "left" = w_left, "right" = w_right)

// Armour a composite panel adds to wall: half its steel armour, at least
// COMPOSITE_MIN_BONUS. Zero for a side that takes no panel.
/obj/structure/vehicleparts/frame/proc/composite_bonus_for(list/wall)
	if (!islist(wall) || wall.len < 5 || !wall[1] || wall[1] == "none" || wall[4] <= 0)
		return 0
	return max(COMPOSITE_MIN_BONUS, round(wall[4] * 0.5))

// The sides of this frame that can still take a panel.
/obj/structure/vehicleparts/frame/proc/composite_free_sides()
	. = list()
	var/list/walls = walls_by_side()
	for (var/side in walls)
		if (composite_bonus && composite_bonus[side])
			continue
		if (composite_bonus_for(walls[side]))
			. += side

// Fits one panel over side. TRUE when it was fitted.
/obj/structure/vehicleparts/frame/proc/fit_composite(side)
	var/list/walls = walls_by_side()
	var/list/wall = walls[side]
	var/bonus = composite_bonus_for(wall)
	if (!bonus || (composite_bonus && composite_bonus[side]))
		return FALSE
	wall[4] += bonus
	wall[5] += round(bonus / 3)
	if (!composite_bonus)
		composite_bonus = list()
	composite_bonus[side] = bonus
	if (axis)
		axis.get_load_factor(TRUE)
	return TRUE

// Armour the panel on wall added, or 0 (vehicle_load.dm wall_weight()).
/obj/structure/vehicleparts/frame/proc/composite_bonus_on(list/wall)
	if (!composite_bonus)
		return 0
	var/list/walls = walls_by_side()
	for (var/side in walls)
		if (walls[side] == wall && composite_bonus[side])
			return composite_bonus[side]
	return 0

// frame_parts.dm attackby hook: a panel used on a frame.
/obj/structure/vehicleparts/frame/proc/fit_composite_panel(obj/item/I, mob/living/human/H)
	if (!istype(I, /obj/item/stack/composite_panel) || !istype(H))
		return FALSE
	var/list/sides = composite_free_sides()
	if (!sides.len)
		to_chat(H, SPAN_WARNING("No armoured wall of \the [src] can take another panel."))
		return TRUE
	var/side = sides.len == 1 ? sides[1] : WWinput(H, "Fit the panel over which wall?", "Composite armour", sides[1], sides + list("Cancel"))
	if (!(side in sides))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] starts fitting a composite panel to \the [src]."), SPAN_NOTICE("You start fitting the panel over the [side] wall..."))
	var/obj/item/stack/composite_panel/P = I
	if (!do_after(H, COMPOSITE_FIT_TIME, src) || QDELETED(P) || P.amount < 1 || !(side in composite_free_sides()))
		return TRUE
	P.use(1)
	fit_composite(side)
	to_chat(H, SPAN_NOTICE("The [side] wall is covered in composite armour."))
	return TRUE

// Examine text for a frame with panels (vehicle_hulls.dm examine).
/obj/structure/vehicleparts/frame/proc/composite_examine_text()
	if (!length(composite_bonus))
		return null
	var/list/sides = list()
	for (var/side in composite_bonus)
		sides += side
	return "Composite armour panels cover its [english_list(sides)] wall[sides.len > 1 ? "s" : ""]."

// ---- The kiln fires alumina into tiles ----

// refining.dm's kiln attackby offers alumina here.
/obj/structure/furnace/kiln/proc/accept_alumina(obj/item/I, mob/living/human/H)
	if (!istype(I, /obj/item/stack/ore/alumina))
		return FALSE
	var/obj/item/stack/S = I
	var/held = 0
	for (var/obj/item/stack/ore/alumina/A in contents)
		held += A.amount
	var/units = min(S.amount, COMPOSITE_KILN_LIMIT - held)
	if (units <= 0)
		to_chat(H, SPAN_WARNING("\The [src] holds no more alumina."))
		return TRUE
	S.use(units)
	var/obj/item/stack/ore/alumina/A = new(src)
	A.amount = units
	visible_message(SPAN_NOTICE("[H] packs [units] measure\s of alumina into \the [src] to fire."))
	return TRUE

// After every kiln firing: alumina comes out as ceramic tiles.
/obj/structure/furnace/kiln/proc/fire_alumina()
	var/fired = 0
	for (var/obj/item/stack/ore/alumina/A in contents)
		fired += A.amount
		qdel(A)
	if (fired > 0)
		spawn_stack(/obj/item/stack/ceramic_tile, get_turf(src), fired)
		visible_message(SPAN_NOTICE("[fired] ceramic tile\s come out of \the [src]."))
	return fired

#undef COMPOSITE_KILN_LIMIT
#undef COMPOSITE_MIN_BONUS
#undef COMPOSITE_FIT_TIME
