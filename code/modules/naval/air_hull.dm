// ============================================================
// Crewed airships: built hulls in the open air (docs/craft-core.md)
// ------------------------------------------------------------
// Lay airship planks on clear, level ground (or on the open air beside the top
// of a ladder). Every plank joined to the first is one deck.
// Gas cells hung over the deck hold it up; an airship helm set on the deck
// commissions it, like a tiller commissions a hull on the water. Built on the
// ground she creeps over clear ground until she lifts off; in the air she
// flies like a built hull sails (craft/built_body.dm, craft/under_way.dm):
// over open air only, stopped by upper storeys, ladders and the map edge.
// Engines running aboard drive her faster (naval/hull_drives.dm); sails and
// oars do nothing up here.
//
// She can fly on any open-air level, however high. The crew sees the first
// solid level under the open air around her (the ground, or a roof or floor
// built in between), and that level sees her shadow. Both views live in nullspace and are drawn through
// turf vis_contents, like the planes' (aircraft_view.dm), so no save records
// them. People aboard shoot and throw at the ground below from the deck
// (pedal_airship_combat.dm, airborne_launch_turf).
// ============================================================

#define AIR_HULL_MAX_TILES AIR_DRAUGHT_MAX_DECK
// Tiles of deck, or people aboard, one gas cell holds up.
#define AIR_HULL_CELL_LIFT 12
#define AIR_HULL_LAY_TIME 20
#define AIR_HULL_CELL_TIME 30
// Lift a gas cell loses for each hole.
#define AIR_HULL_HOLE_LIFT 3
// Ground fire under her deck: the chance a shot crossing the tile under a
// deck tile strikes her, and the share of those that hit someone standing there.
#define AIR_HULL_HIT_CHANCE 50
#define AIR_HULL_CREW_HIT_CHANCE 25
#define AIR_HULL_PATCH_TIME 40
// Units of gas that fill one cell (naval/gas_works.dm).
#define AIR_HULL_CELL_GAS AIR_DRAUGHT_CELL_GAS
// Plastic sheets to rubberise a cloth cell, and skin layers to line one.
#define AIR_HULL_RUBBER_SHEETS 5
#define AIR_HULL_SKIN_LAYERS 6
#define AIR_HULL_HATCH_BOMBS 2
// Open-air levels she can look, drop or be shot through, at most.
#define AIR_HULL_MAX_DROP 8
// Deciseconds she takes to sink, lift or land one level.
#define AIR_HULL_LEVEL_TIME 30
// Over trees under more than one in this many of her tiles she snags in the
// canopy; under fewer, her weight flattens them.
#define AIR_HULL_TREE_SHARE 4

var/global/list/air_hull_crafts = list()

// ---- The deck ----

/obj/covers/airship_deck
	name = "airship deck"
	desc = "Light planks lashed into the gondola deck of an airship. It hangs in the open air: step off its edge and you fall."
	// What one tile weighs against her gas cells' lift.
	var/air_weight = 1
	// Too stout a frame for branches to catch: she flattens the trees under it.
	var/snag_proof = FALSE

/obj/covers/airship_deck/aluminium
	name = "aluminium airship deck"
	desc = "Riveted aluminium plates on a light girder frame, half the weight of planks. It does not burn. It hangs in the open air: step off its edge and you fall."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "airship_deck_aluminium"
	base_icon_state = "airship_deck_aluminium"
	air_weight = 0.5
	wood = FALSE
	flammable = FALSE
	material = "Aluminium"
	buildstack = /obj/item/stack/material/aluminium

/obj/covers/airship_deck/steel
	name = "steel airship deck"
	desc = "Riveted steel plates on a girder frame, twice the weight of planks. It does not burn, and treetops cannot catch it. It hangs in the open air: step off its edge and you fall."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "airship_deck_steel"
	base_icon_state = "airship_deck_steel"
	air_weight = 2
	snag_proof = TRUE
	wood = FALSE
	flammable = FALSE
	material = "Steel"
	buildstack = /obj/item/stack/material/steel

/obj/item/airship_planks
	name = "airship planks"
	desc = "A lashed bundle of light planks for an airship's gondola deck. Use it on clear, level ground, on the open air beside the top of a ladder, or beside a deck already laid, to lay one tile of deck."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "airship_planks"
	w_class = ITEM_SIZE_LARGE
	weight = 6
	flammable = TRUE
	var/deck_type = /obj/covers/airship_deck

/obj/item/airship_planks/aluminium
	name = "aluminium airship frame"
	desc = "Aluminium girders and plates for one tile of airship deck: half the weight of planks, and fireproof. Lay it like airship planks."
	icon_state = "aluminium_frame"
	weight = 3
	flammable = FALSE
	deck_type = /obj/covers/airship_deck/aluminium

/obj/item/airship_planks/steel
	name = "steel airship frame"
	desc = "Steel girders and plates for one tile of airship deck: twice the weight of planks, but fireproof and too stout for treetops to catch. Lay it like airship planks."
	icon_state = "steel_frame"
	weight = 12
	flammable = FALSE
	deck_type = /obj/covers/airship_deck/steel

// Open air a plank can be laid on: nothing built or standing in it.
/proc/air_deck_open(turf/T)
	if (!istype(T, /turf/sky/building) || !building_open_turf(T))
		return FALSE
	for (var/atom/movable/A in T)
		if (A.loc != T)
			continue
		if (istype(A, /obj/covers) || istype(A, /obj/structure/multiz) || (A.density && !istype(A, /atom/movable/lighting_overlay)))
			return FALSE
	return TRUE

// Ground an airship can be built on, creep over or land on: dry, level, solid
// floor with nothing built or standing on it.
/proc/air_ground_open(turf/T)
	if (!istype(T, /turf/floor) || istype(T, /turf/sky) || istype(T, /turf/floor/broken_floor) || !T.aircraft_rough_ground())
		return FALSE
	for (var/atom/movable/A in T)
		if (A.loc != T)
			continue
		if (istype(A, /obj/covers) || istype(A, /obj/roof) || istype(A, /obj/structure/multiz) || (A.density && !istype(A, /atom/movable/lighting_overlay)))
			return FALSE
	return TRUE

// The tree standing on T, or null.
/proc/air_hull_tree(turf/T)
	if (!T)
		return null
	for (var/obj/structure/wild/W in T)
		if (bump_choppable_tree(W))
			return W
	return null

// Somewhere clear beside T for someone falling onto a tree there.
/proc/air_hull_beside(turf/T)
	if (!T)
		return null
	for (var/turf/N in orange(1, T))
		if (N.z != T.z || N.density || air_hull_tree(N))
			continue
		var/blocked = FALSE
		for (var/atom/movable/A in N)
			if (A.density && !ismob(A))
				blocked = TRUE
				break
		if (!blocked)
			return N
	return T

// Why a plank cannot go on T for user, or null. On the ground a deck starts
// anywhere clear and level; in the open air it starts from the top of a
// ladder. Either way it grows edge to edge.
/proc/air_deck_lay_refusal(turf/T, mob/user)
	var/turf/here = get_turf(user)
	if (!T || !here || T.z != here.z || get_dist(here, T) > 1)
		return "Lay the planks right beside you."
	var/aloft = istype(T, /turf/sky)
	if (aloft ? !air_deck_open(T) : !air_ground_open(T))
		return aloft ? "Airship planks are laid on clear open air." : "Airship planks are laid on clear, dry, level ground with nothing on it."
	if (persistence_save_in_progress)
		return "You can't build while the world is saving."
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (!N)
			continue
		if (locate(/obj/covers/airship_deck) in N)
			var/datum/craft/C = craft_at(N)
			if (C && !C.anchored)
				return "Hold the airship in place at her helm before adding to her deck."
			return null
		if (aloft && (locate(/obj/structure/multiz) in N))
			return null
	if (!aloft)
		return null
	return "Start the deck on the ground, or beside the top of a ladder standing in the open air, and grow it edge to edge."

/obj/item/airship_planks/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = isturf(A) ? A : null
	if (!istype(T, /turf/sky/building) && !istype(T, /turf/floor))
		return ..()
	var/why = air_deck_lay_refusal(T, user)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts lashing planks into an airship deck."), SPAN_NOTICE("You start lashing the planks into place..."))
	if (!do_after(user, AIR_HULL_LAY_TIME, T) || QDELETED(src) || user.get_active_hand() != src || air_deck_lay_refusal(T, user))
		return TRUE
	qdel(src)
	new deck_type(T)
	to_chat(user, SPAN_NOTICE("You lay a tile of airship deck."))
	return TRUE

// ---- Gas cells ----

/obj/item/airship_gas_cell
	name = "folded gas cell"
	desc = "An oiled-cloth gas cell, rolled tight. Use it on an airship deck to hang it there. Each cell holds up 12 tiles of wooden deck or people aboard, and loses a quarter of that for each hole. Coat it with 5 plastic sheets to rubberise it, or line it with 6 sausage casings of goldbeater's skin."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "gas_cell_folded"
	w_class = ITEM_SIZE_LARGE
	weight = 8
	flammable = TRUE
	var/cell_type = /obj/structure/airship_gas_cell
	// Goldbeater's skin layers laid into a cloth cell so far.
	var/skin_layers = 0

/obj/item/airship_gas_cell/rubber
	name = "folded rubberised gas cell"
	desc = "A gas cell of rubberised cloth, rolled tight. Use it on an airship deck to hang it there. It holds up 12 tiles of wooden deck or people aboard and holds its gas better when holed than plain cloth. Patch it with cloth or plastic."
	icon_state = "gas_cell_folded_rubber"
	cell_type = /obj/structure/airship_gas_cell/rubber

/obj/item/airship_gas_cell/skin
	name = "folded goldbeater's skin cell"
	desc = "A cloth gas cell lined with goldbeater's skin, rolled tight. Use it on an airship deck to hang it there. It holds up 15 tiles of wooden deck or people aboard, but every hole lets out a third of that."
	icon_state = "gas_cell_folded_skin"
	weight = 7
	cell_type = /obj/structure/airship_gas_cell/skin

// A cloth cell is rubberised with plastic sheeting or lined with skin.
/obj/item/airship_gas_cell/attackby(obj/item/W, mob/user)
	if (type != /obj/item/airship_gas_cell)
		return ..()
	if (istype(W, /obj/item/stack/material/plastic) || istype(W, /obj/item/stack/material/rubber))
		var/obj/item/stack/S = W
		if (S.amount < AIR_HULL_RUBBER_SHEETS)
			to_chat(user, SPAN_WARNING("You need [AIR_HULL_RUBBER_SHEETS] sheets of plastic or rubber to coat the whole cell."))
			return
		to_chat(user, SPAN_NOTICE("You start coating \the [src] with rubber..."))
		if (!do_after(user, AIR_HULL_CELL_TIME, src) || QDELETED(src) || !S.use(AIR_HULL_RUBBER_SHEETS))
			return
		become(/obj/item/airship_gas_cell/rubber, user)
		to_chat(user, SPAN_NOTICE("The cloth is rubberised: it will hold its gas better when holed."))
		return
	if (istype(W, /obj/item/stack/sausagecasing))
		var/obj/item/stack/S = W
		if (!do_after(user, AIR_HULL_PATCH_TIME, src) || QDELETED(src) || !S.use(1))
			return
		skin_layers++
		if (skin_layers < AIR_HULL_SKIN_LAYERS)
			to_chat(user, SPAN_NOTICE("You glue a layer of goldbeater's skin into \the [src]. [AIR_HULL_SKIN_LAYERS - skin_layers] more to line it."))
			return
		become(/obj/item/airship_gas_cell/skin, user)
		to_chat(user, SPAN_NOTICE("The cell is lined with goldbeater's skin: it lifts more, but tears worse when holed."))
		return
	return ..()

/obj/item/airship_gas_cell/examine(mob/user, distance)
	. = ..()
	if (skin_layers)
		to_chat(user, SPAN_NOTICE("It is lined with [skin_layers] of [AIR_HULL_SKIN_LAYERS] layers of goldbeater's skin."))

/obj/item/airship_gas_cell/proc/become(new_type, mob/user)
	var/held = (loc == user)
	var/obj/item/N = new new_type(get_turf(src))
	if (held)
		user.drop_from_inventory(src)
	qdel(src)
	if (held)
		user.put_in_hands(N)

/obj/item/airship_gas_cell/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = get_turf(A)
	if (!T || !(locate(/obj/covers/airship_deck) in T))
		return ..()
	if (get_dist(user, T) > 1 || T.z != user.z)
		return TRUE
	if (locate(/obj/structure/airship_gas_cell) in T)
		to_chat(user, SPAN_WARNING("A gas cell already hangs over that tile."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts rigging a gas cell over the deck."), SPAN_NOTICE("You start rigging the gas cell..."))
	if (!do_after(user, AIR_HULL_CELL_TIME, T) || QDELETED(src) || user.get_active_hand() != src || (locate(/obj/structure/airship_gas_cell) in T) || !(locate(/obj/covers/airship_deck) in T))
		return TRUE
	qdel(src)
	var/obj/structure/airship_gas_cell/G = new cell_type(T)
	G.gas = null
	G.gas_amount = 0
	G.update_icon()
	to_chat(user, SPAN_NOTICE("You hang the gas cell, empty. Fill it with hydrogen or helium from a gasbag, a gas cylinder or a gas holder's hose."))
	return TRUE

/obj/structure/airship_gas_cell
	name = "gas cell"
	desc = "A gas cell rigged over an airship's deck. It holds up tiles of deck and the people aboard. Cloth patches its holes; a wrench takes it down."
	icon = 'icons/obj/vehicles/airship_gas_cell.dmi'
	icon_state = "gas_cell"
	pixel_x = -16
	pixel_y = 12
	// Under the crew, so people stand in front of it and stay clickable.
	layer = MOB_LAYER - 0.1
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	flammable = TRUE
	var/holes = 0
	var/burnt = FALSE
	// What it holds up when whole, and what each hole costs.
	var/max_lift = AIR_HULL_CELL_LIFT
	var/hole_lift = AIR_HULL_HOLE_LIFT
	var/base_state = "gas_cell"
	var/folded_type = /obj/item/airship_gas_cell
	var/list/patches = list(/obj/item/stack/material/cloth)
	var/patch_text = "cloth"
	// The lifting gas in it, and how much: hydrogen burns, helium lifts a
	// tenth less. A cell hangs empty and is filled from a gasbag, a cylinder
	// or a gas holder's hose (gas_works.dm).
	var/gas = "hydrogen"
	var/gas_amount = AIR_HULL_CELL_GAS

/obj/structure/airship_gas_cell/rubber
	name = "rubberised gas cell"
	desc = "A rubberised cloth gas cell rigged over an airship's deck. It holds its gas better than plain cloth when holed. Cloth or plastic patches its holes; a wrench takes it down."
	icon_state = "gas_cell_rubber"
	hole_lift = 2
	base_state = "gas_cell_rubber"
	folded_type = /obj/item/airship_gas_cell/rubber
	patches = list(/obj/item/stack/material/cloth, /obj/item/stack/material/plastic)
	patch_text = "cloth or plastic"

/obj/structure/airship_gas_cell/skin
	name = "goldbeater's skin cell"
	desc = "A gas cell lined with goldbeater's skin, rigged over an airship's deck. It lifts more than cloth, but a hole lets out more. Cloth patches its holes; a wrench takes it down."
	icon_state = "gas_cell_skin"
	max_lift = 15
	hole_lift = 5
	base_state = "gas_cell_skin"
	folded_type = /obj/item/airship_gas_cell/skin

/obj/structure/airship_gas_cell/proc/lift()
	if (burnt || !gas || gas_amount <= 0)
		return 0
	var/full = max_lift * min(1, gas_amount / AIR_HULL_CELL_GAS) * (gas == "helium" ? 0.9 : 1)
	return max(0, round(full - holes * hole_lift, 0.1))

/obj/structure/airship_gas_cell/update_icon()
	icon_state = burnt ? "gas_cell_burnt" : (gas_amount <= 0 ? "[base_state]_empty" : (holes ? "[base_state]_holed" : base_state))

// Only hydrogen catches fire.
/obj/structure/airship_gas_cell/proc/flammable_gas()
	return gas == "hydrogen" && gas_amount > 0

/obj/structure/airship_gas_cell/after_load()
	..()
	update_icon()

/obj/structure/airship_gas_cell/examine(mob/user, distance)
	. = ..()
	if (!burnt)
		to_chat(user, SPAN_NOTICE(gas_amount > 0 && gas ? "It holds [round(gas_amount)] of [AIR_HULL_CELL_GAS] units of [gas]." : "It hangs empty. Fill it with hydrogen or helium."))
	if (burnt)
		to_chat(user, SPAN_DANGER("It has burnt out and lifts nothing. Take it down with a wrench and hang a new one."))
	else if (holes)
		to_chat(user, SPAN_WARNING("It is holed in [holes] place\s and lifts [lift()] instead of [max_lift]. Patch it with [patch_text]."))

/obj/structure/airship_gas_cell/attackby(obj/item/W, mob/user)
	if (is_type_in_list(W, patches) && holes && !burnt)
		to_chat(user, SPAN_NOTICE("You start stitching a patch over a hole in \the [src]..."))
		if (!do_after(user, AIR_HULL_PATCH_TIME, src) || QDELETED(src) || burnt || !holes)
			return
		var/obj/item/stack/C = W
		if (!C.use(1))
			return
		holes--
		update_icon()
		to_chat(user, SPAN_NOTICE(holes ? "You patch a hole. [holes] more to go." : "You patch the last hole. The gas cell is taut again."))
		return
	if (is_tool(W, TOOL_WRENCH))
		var/datum/craft/C = craft_at(get_turf(src))
		if (C && !C.anchored)
			to_chat(user, SPAN_WARNING("Hold the airship in place at her helm before taking down a gas cell."))
			return
		to_chat(user, SPAN_NOTICE("You start letting the gas out of \the [src]..."))
		if (!do_after(user, AIR_HULL_CELL_TIME, src) || QDELETED(src))
			return
		var/turf/T = get_turf(src)
		var/was_burnt = burnt
		qdel(src)
		if (was_burnt)
			to_chat(user, SPAN_NOTICE("You cut the charred rags of the gas cell away."))
			return
		new folded_type(T)
		to_chat(user, SPAN_NOTICE("You fold the gas cell up."))
		return
	return ..()

// A shot from below rips through it.
/obj/structure/airship_gas_cell/proc/hole(obj/item/projectile/P)
	holes++
	update_icon()
	visible_message(SPAN_DANGER("\The [P] rips through \the [src]!"))
	playsound(get_turf(src), 'sound/effects/bang.ogg', 30, TRUE)

// The gas catches: it burns out, and whoever stands under it is set alight.
/obj/structure/airship_gas_cell/proc/ignite()
	burnt = TRUE
	update_icon()
	visible_message(SPAN_DANGER("\The [src] bursts into flame!"))
	playsound(get_turf(src), 'sound/effects/bang.ogg', 60, TRUE)
	air_deck_catch_fire(get_turf(src))
	for (var/mob/living/L in get_turf(src))
		L.fire_stacks = max(L.fire_stacks, 2)
		L.IgniteMob()
		L.adjustBurnLoss(rand(5, 15))

// ---- The body ----

/datum/craft_body/built/air
	hull_name = "airship"

// No upper deck: she is on the top level already.
/datum/craft_body/built/air/upper_z()
	return 0

// No hold: what lies below her is the ground she flies over.
/datum/craft_body/built/air/lower_z()
	return 0

// TRUE while she stands on the ground rather than hanging in the open air.
/datum/craft_body/built/air/proc/landed()
	if (!placed())
		return FALSE
	var/list/C = cells()
	return C.len && !istype(C[1], /turf/sky)

/datum/craft_body/built/air/tile_refusal(turf/D)
	if (landed())
		if (air_ground_open(D))
			return null
		return "[air_hull_tree(D) ? "a tree" : "rough ground or something in the way"] at [D.x],[D.y]: she can only creep over clear, level ground"
	if (!air_deck_open(D))
		for (var/obj/covers/C in D)
			if (C.loc == D)
				return "a floor in the way at [D.x],[D.y]"
		for (var/obj/structure/multiz/L in D)
			if (L.loc == D)
				return "a ladder in the way at [D.x],[D.y]"
		for (var/atom/movable/M in D)
			if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
				return "[M.name] in the way at [D.x],[D.y]"
		return "[D.name] ahead at [D.x],[D.y]"
	return null

// Moves her, and everything aboard, straight up or down to level new_z.
/datum/craft_body/built/air/proc/shift_level(new_z)
	if (moving || persistence_save_in_progress || !placed() || !new_z)
		return FALSE
	var/list/old = cells()
	var/list/cargo = list()
	for (var/turf/S in old)
		var/list/riders = list()
		for (var/atom/movable/M in S)
			if (M.loc != S || QDELETED(M) || !M.craft_cargo())
				continue
			// Floors first, so nobody reaches open air before the deck does.
			if (istype(M, /obj/covers))
				riders.Insert(1, M)
			else
				riders += M
		cargo += list(riders)
	moving = TRUE
	z = new_z
	for (var/i = 1, i <= old.len, i++)
		var/turf/S = old[i]
		var/turf/D = locate(S.x, S.y, new_z)
		for (var/atom/movable/M in cargo[i])
			if (!QDELETED(M))
				M.forceMove(D)
	moving = FALSE
	return TRUE

// What her gas cells hold up, and what they must.
/datum/craft_body/built/air/proc/lift()
	. = 0
	for (var/turf/T in cells())
		for (var/obj/structure/airship_gas_cell/G in T)
			. += G.lift()

/datum/craft_body/built/air/proc/load()
	. = 0
	for (var/turf/T in cells())
		var/obj/covers/airship_deck/K = locate() in T
		if (K)
			. += K.air_weight
		for (var/mob/living/L in T)
			if (L.loc == T)
				.++

/datum/craft_body/built/air/proc/lift_refusal()
	var/need = load()
	var/have = lift()
	if (have < need)
		return "her gas cells hold up [have] and she weighs [need]: hang more gas cells, or carry fewer people"
	return null

/datum/craft_body/built/air/plan(x, y, heading)
	var/short = placed() ? lift_refusal() : null
	if (short)
		last_refusal = short
		return null
	return ..()

// The deck around start: every tile of airship deck joined to it edge to edge.
// Returns the list of turfs, or a text saying why this is not an airship.
/proc/air_hull_survey(turf/start, datum/craft/refitting = null)
	if (!start || !(locate(/obj/covers/airship_deck) in start))
		return "The helm must stand on an airship deck."
	var/list/found = list(start)
	var/list/queue = list(start)
	while (queue.len)
		var/turf/T = queue[1]
		queue.Cut(1, 2)
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (!N || (N in found) || !(locate(/obj/covers/airship_deck) in N))
				continue
			var/datum/craft/other = craft_at(N)
			if (other && other != refitting)
				return "The deck is joined to the [other.name] at [N.x],[N.y]."
			found += N
			queue += N
			if (found.len > AIR_HULL_MAX_TILES)
				return "The deck is too large: more than [AIR_HULL_MAX_TILES] tiles. Gas cells cannot hold up more."
	return found

// ---- The craft ----

/datum/craft/air
	name = "airship"
	var/tmp/obj/effect/air_hull_shadow/shadow
	var/tmp/turf/shadow_anchor

/datum/craft/air/New(datum/craft_body/new_body)
	..()
	air_hull_crafts += src

/datum/craft/air/Destroy()
	air_hull_crafts -= src
	clear_views()
	return ..()

// She creeps a tile at a time, never by pixels: a crewman carried by pixels
// over the open air beside her deck would fall.
/datum/craft/air/offset_sails()
	return FALSE

// Only engines drive her: a sail or an oar finds nothing to push on up here.
/datum/craft/air/fit_drives()
	. = ..()
	for (var/datum/craft_drive/D in drives.Copy())
		if (!istype(D, /datum/craft_drive/fitted/engine))
			D.under_way(FALSE)
			remove_drive(D)
			qdel(D)
	return drives.len

/datum/craft/air/on_hop(turf/old_origin)
	..()
	update_views()

/datum/craft/air/on_turn(angle)
	..()
	update_views()

/datum/craft/air/proc/ground_z()
	var/datum/craft_body/built/air/B = body
	return (istype(B) && B.placed() && !B.landed()) ? multiz_level_below(B.z) : 0

// The silhouette of her deck, gas cells and crew on the ground below.
/obj/effect/air_hull_shadow
	name = "shadow"
	mouse_opacity = 0
	anchored = TRUE
	appearance_flags = KEEP_TOGETHER | RESET_TRANSFORM
	color = list(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0.35, 0,0,0,0)
	plane = FLOOR_PLANE
	layer = TURF_LAYER + 0.05
	pixel_x = 12
	pixel_y = -12

/datum/craft/air/proc/update_views()
	var/datum/craft_body/built/air/B = body
	var/ground = ground_z()
	if (!istype(B) || !ground)
		clear_views()
		return
	var/list/deck = B.cells()
	if (!deck.len)
		clear_views()
		return
	var/list/box = B.box(B.offsets)
	var/min_x = B.px + box[1]
	var/min_y = B.py + box[2]
	// Her shadow, laid out from the corner of her box on the ground.
	if (!shadow)
		shadow = new
		shadow.loc = null
	var/turf/corner = air_hull_solid_below(locate(min_x, min_y, B.z))
	if (shadow_anchor != corner)
		if (shadow_anchor)
			shadow_anchor.vis_contents -= shadow
		shadow_anchor = corner
		if (corner)
			corner.vis_contents += shadow
	shadow.vis_contents = deck

/datum/craft/air/proc/clear_views()
	if (shadow_anchor && shadow)
		shadow_anchor.vis_contents -= shadow
	shadow_anchor = null
	if (shadow)
		shadow.vis_contents = list()
		qdel(shadow)
	shadow = null

// ---- Seeing, dropping and shooting through open air ----

// Open air nothing stands in the way of: no floor, roof or ladder.
/proc/air_hull_open_air(turf/T)
	return istype(T, /turf/sky/building) && !(locate(/obj/covers) in T) && !(locate(/obj/roof) in T) && !(locate(/obj/structure/multiz) in T)

// The first solid turf straight under T, through any levels of open air.
/proc/air_hull_solid_below(turf/T)
	if (!T)
		return null
	var/turf/at = T
	for (var/i = 1 to AIR_HULL_MAX_DROP)
		var/z = multiz_level_below(at.z)
		var/turf/next = z ? locate(at.x, at.y, z) : null
		if (!next)
			return at == T ? null : at
		at = next
		if (!air_hull_open_air(at))
			return at
	return at

// How many levels high lies over low, counting only open air in between;
// 0 when something solid is in the way or high is not over low.
/proc/air_hull_levels_between(turf/low, turf/high)
	if (!low || !high || low.x != high.x || low.y != high.y || !istype(high, /turf/sky))
		return 0
	var/turf/at = high
	for (var/steps = 1 to AIR_HULL_MAX_DROP)
		var/z = multiz_level_below(at.z)
		at = z ? locate(at.x, at.y, z) : null
		if (!at)
			return 0
		if (at.z == low.z)
			return steps
		if (!air_hull_open_air(at))
			return 0
	return 0

// ---- Fire from below ----

// Called by the projectile code for every turf a projectile crosses while an
// airship flies. A shot under her deck with only open air above it may strike
// her: half the time one level below her, half that again for each level
// further down. Returns what it struck (someone on her deck, or the turf T
// under her), else null. Her own crew's shots go down, not up.
/proc/air_hull_overhead_fire(obj/item/projectile/P, turf/T)
	if (!P || !T || P.is_shrapnel)
		return null
	for (var/datum/craft/air/C in air_hull_crafts)
		var/datum/craft_body/built/air/B = C.body
		if (!istype(B) || !B.placed() || T.z == B.z)
			continue
		var/turf/D = locate(T.x, T.y, B.z)
		if (!D || !B.contains(D))
			continue
		if (P.firer && B.contains(get_turf(P.firer)))
			continue
		var/levels = air_hull_levels_between(T, D)
		if (!levels || !prob(AIR_HULL_HIT_CHANCE / (2 ** (levels - 1))))
			continue
		return C.struck_by(P, D, T)
	return null

/datum/craft/air/proc/struck_by(obj/item/projectile/P, turf/D, turf/T)
	var/list/people = list()
	for (var/mob/living/L in D)
		if (L.loc == D)
			people += L
	if (people.len && prob(AIR_HULL_CREW_HIT_CHANCE))
		var/mob/living/L = pick(people)
		L.visible_message(SPAN_DANGER("\The [P] punches up through the deck into [L]!"))
		P.def_zone = pickweight(list("l_leg" = 3, "r_leg" = 3, "groin" = 2, "chest" = 1))
		P.attack_mob(L, 1)
		return L
	var/obj/structure/airship_gas_cell/G = locate() in D
	if (G && !G.burnt)
		if (projectile_ignites_gas(P) && G.flammable_gas())
			G.ignite()
		else
			G.hole(P)
		check_lift()
		return T
	if (projectile_ignites_gas(P) && prob(25))
		air_deck_catch_fire(D)
	D.visible_message(SPAN_WARNING("\The [P] thuds into the deck."))
	return T

// A wooden deck tile on T catches fire; metal decks do not burn.
/proc/air_deck_catch_fire(turf/T)
	var/obj/covers/airship_deck/D = locate() in T
	if (!D || !D.wood || D.onfire)
		return
	D.onfire = TRUE
	D.visible_message(SPAN_DANGER("\The [D] catches fire!"))
	D.start_fire()

// After a cell is holed or burnt: short of lift she sinks, and with less than
// half the lift she needs she breaks up and falls.
/datum/craft/air/proc/check_lift()
	var/datum/craft_body/built/air/B = body
	if (!istype(B) || !B.placed() || B.landed())
		return
	var/have = B.lift()
	var/need = B.load()
	if (have * 2 < need)
		crash()
		return
	if (have < need)
		crew_message(SPAN_DANGER("The [name] is losing lift: her gas cells hold up [have] of her [need]. She sinks until the cells are patched, she is lightened or she comes to rest."))
		speed = VESSEL_SPEED_STOP
		set_anchor(TRUE)
		sink()

/datum/craft/air/var/tmp/changing_level = FALSE

// Sinks a level at a time while she is short of lift.
/datum/craft/air/proc/sink()
	set waitfor = FALSE
	if (changing_level)
		return
	changing_level = TRUE
	while (!QDELETED(src))
		sleep(AIR_HULL_LEVEL_TIME)
		var/datum/craft_body/built/air/B = body
		if (QDELETED(src) || !istype(B) || !B.placed() || B.landed())
			break
		var/have = B.lift()
		var/need = B.load()
		if (have * 2 < need)
			changing_level = FALSE
			crash()
			return
		if (have >= need)
			crew_message(SPAN_NOTICE("The [name] steadies: her gas cells hold her up again."))
			break
		if (!sink_step())
			break
	changing_level = FALSE

// One level down while sinking. Returns TRUE when she can sink further.
/datum/craft/air/proc/sink_step()
	var/datum/craft_body/built/air/B = body
	var/next = multiz_level_below(B.z)
	if (!next)
		return FALSE
	var/list/deck = B.cells()
	var/list/trees = list()
	var/turf/blocked = null
	for (var/turf/D in deck)
		var/turf/N = locate(D.x, D.y, next)
		if (!N)
			blocked = D
			break
		if (istype(N, /turf/sky))
			if (!air_deck_open(N))
				blocked = N
			continue
		var/obj/structure/wild/W = air_hull_tree(N)
		if (W)
			trees[W] = D
		else if (!air_ground_open(N))
			blocked = N
	if (blocked)
		crew_message(SPAN_WARNING("The [name] comes to rest against what lies below her at [blocked.x],[blocked.y]. She stays there until her cells hold her up again."))
		return FALSE
	if (trees.len)
		// Steel frames are never caught: only trees under the rest count.
		var/snaggers = 0
		for (var/obj/structure/wild/W in trees)
			var/obj/covers/airship_deck/K = locate() in trees[W]
			if (!K || !K.snag_proof)
				snaggers++
		if (snaggers * AIR_HULL_TREE_SHARE > deck.len)
			// Too much forest: she hangs in the canopy, torn.
			for (var/obj/structure/wild/W in trees)
				tear_on_tree(trees[W], W, FALSE)
			crew_message(SPAN_DANGER("The [name] snags in the treetops! The branches tear at her gas cells. She hangs there until her cells hold her up again."))
			check_lift()
			return FALSE
		// A few trees: her weight flattens them.
		for (var/obj/structure/wild/W in trees)
			tear_on_tree(trees[W], W, TRUE)
		crew_message(SPAN_DANGER("The [name] settles onto the trees under her and flattens them, tearing her gas cells."))
		if (B.lift() * 2 < B.load())
			crash()
			return FALSE
		for (var/turf/D in deck)
			var/turf/N = locate(D.x, D.y, next)
			if (!air_ground_open(N))
				crew_message(SPAN_WARNING("The [name] comes to rest on the broken trees."))
				return FALSE
	B.shift_level(next)
	update_views()
	if (B.landed())
		crew_message(SPAN_NOTICE("The [name] settles onto the ground."))
		return FALSE
	crew_message(SPAN_WARNING("The [name] sinks lower."))
	return TRUE

// A tree under her deck tile D: the branches hole the cell over it and hurt
// whoever stands there; it is flattened, or only damaged when she snags.
/datum/craft/air/proc/tear_on_tree(turf/D, obj/structure/wild/W, flatten)
	var/obj/structure/airship_gas_cell/G = locate() in D
	if (G && !G.burnt)
		G.holes++
		G.update_icon()
	for (var/mob/living/L in D)
		if (L.loc == D)
			to_chat(L, SPAN_DANGER("Branches whip up through the deck!"))
			L.adjustBruteLoss(rand(3, 8))
	if (QDELETED(W))
		return
	W.health = flatten ? 0 : W.health - 25
	W.try_destroy()

// ---- Lifting off and landing ----

// Why she cannot lift off now, or null.
/datum/craft/air/proc/lift_off_refusal()
	var/datum/craft_body/built/air/B = body
	if (!istype(B) || !B.landed())
		return "she is not on the ground"
	if (changing_level)
		return "she is already rising or sinking"
	if (!anchored)
		return "hold position first"
	var/short = B.lift_refusal()
	if (short)
		return short
	var/up = multiz_level_above(B.z)
	if (!up)
		return "there is no open sky above this place"
	for (var/turf/D in B.cells())
		var/turf/U = locate(D.x, D.y, up)
		if ((locate(/obj/roof) in D) || !air_deck_open(U))
			return "a roof or something overhead at [D.x],[D.y]: walk her out into the open first"
	return null

/datum/craft/air/proc/lift_off()
	var/why = lift_off_refusal()
	if (why)
		last_refusal = why
		return FALSE
	var/datum/craft_body/built/air/B = body
	B.shift_level(multiz_level_above(B.z))
	update_views()
	crew_message(SPAN_NOTICE("The [name] lifts off the ground and hangs in the open air."))
	return TRUE

// Why she cannot land straight down from here, or null. Every tile under her
// must be clear, dry, level ground on one level, with only open air between.
/datum/craft/air/proc/land_refusal()
	var/datum/craft_body/built/air/B = body
	if (!istype(B) || !B.placed() || B.landed())
		return "she is already on the ground"
	if (changing_level)
		return "she is already rising or sinking"
	if (!anchored)
		return "hold position first"
	var/ground = 0
	for (var/turf/D in B.cells())
		var/turf/G = air_hull_solid_below(D)
		if (!G)
			return "there is no ground under her"
		if (istype(G, /turf/sky))
			return "a floor or roof under her at [G.x],[G.y]"
		if (ground && G.z != ground)
			return "uneven ground under her"
		ground = G.z
		if (air_hull_tree(G))
			return "a tree under her at [G.x],[G.y]"
		if (!air_ground_open(G))
			return "[G.density ? "\the [G]" : "rough ground or something in the way"] under her at [G.x],[G.y]"
	return null

// Brings her down a level at a time to the ground below.
/datum/craft/air/proc/land()
	var/why = land_refusal()
	if (why)
		last_refusal = why
		return FALSE
	crew_message(SPAN_NOTICE("The [name] vents gas and starts down."))
	descend_to_ground()
	return TRUE

/datum/craft/air/proc/descend_to_ground()
	set waitfor = FALSE
	changing_level = TRUE
	while (!QDELETED(src))
		sleep(AIR_HULL_LEVEL_TIME)
		var/datum/craft_body/built/air/B = body
		if (QDELETED(src) || !istype(B) || !B.placed() || B.landed())
			break
		// Whatever came under her on the way down stops her.
		changing_level = FALSE
		var/why = land_refusal()
		changing_level = TRUE
		if (why)
			crew_message(SPAN_WARNING("The [name] stops her descent: [why]."))
			break
		B.shift_level(multiz_level_below(B.z))
		update_views()
		if (B.landed())
			crew_message(SPAN_NOTICE("The [name] settles gently onto the ground."))
			break
	changing_level = FALSE

// She breaks up: everyone and everything aboard falls to the ground below,
// and her deck, cells and helm are wrecked.
/datum/craft/air/proc/crash()
	var/datum/craft_body/built/air/B = body
	var/ground = ground_z()
	if (!istype(B) || !ground)
		return FALSE
	var/list/deck = B.cells()
	crew_message(SPAN_DANGER("The [name] breaks up and falls!"))
	stop_sailing()
	clear_views()
	var/list/wreck = list()
	for (var/turf/D in deck)
		var/turf/G = air_hull_solid_below(D)
		// A longer fall hurts more.
		var/levels = max(1, air_hull_levels_between(G, D))
		// Whoever falls onto a tree comes down beside its trunk, the branches
		// breaking the fall a little, and the tree is battered.
		var/obj/structure/wild/tree = air_hull_tree(G)
		var/cushion = 0
		if (tree)
			G = air_hull_beside(G)
			cushion = 10
			tree.health -= 20
			tree.try_destroy()
		for (var/atom/movable/M in D.contents.Copy())
			if (M.loc != D || QDELETED(M) || !M.craft_cargo())
				continue
			if (istype(M, /obj/covers/airship_deck) || istype(M, /obj/structure/airship_gas_cell) || istype(M, /obj/structure/airship_helm) || istype(M, /obj/structure/airship_bomb_hatch))
				wreck += M
				continue
			if (!G)
				continue
			M.forceMove(G)
			if (isliving(M))
				var/mob/living/L = M
				to_chat(L, SPAN_DANGER("The deck breaks up beneath you and you fall!"))
				L.adjustBruteLoss(max(5, rand(15, 35) + 15 * (levels - 1) - cushion))
				L.Weaken(3)
			else if (isitem(M))
				falling_item_strike(M, G)
		if (G && prob(40))
			var/obj/item/stack/material/wood/W = new(G)
			W.amount = rand(1, 3)
		if (G)
			G.visible_message(SPAN_DANGER("Wreckage of the [name] crashes down!"))
	// The helm goes last: destroying it ends the craft.
	var/obj/structure/airship_helm/helm = null
	for (var/atom/movable/M in wreck)
		if (istype(M, /obj/structure/airship_helm))
			helm = M
			continue
		qdel(M)
	if (helm)
		qdel(helm)
	else
		qdel(src)
	return TRUE

// ---- Bomb hatch ----

/obj/structure/airship_bomb_hatch
	name = "bomb hatch"
	desc = "A trapdoor in an airship's deck with a cradle for two aircraft bombs. Load bombs into it, then pull the ring to drop one onto the ground below. A wrench takes a bomb back out."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "bomb_hatch"
	layer = 2.0
	anchored = TRUE
	density = FALSE
	not_movable = TRUE

/obj/structure/airship_bomb_hatch/proc/bombs()
	. = list()
	for (var/obj/item/weapon/aircraft_bomb/B in contents)
		. += B

/obj/structure/airship_bomb_hatch/examine(mob/user, distance)
	. = ..()
	var/n = length(bombs())
	to_chat(user, n ? "[n] bomb\s sit\s in its cradle." : "Its cradle is empty.")

/obj/structure/airship_bomb_hatch/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/aircraft_bomb))
		if (length(bombs()) >= AIR_HULL_HATCH_BOMBS)
			to_chat(user, SPAN_WARNING("The cradle is full."))
			return
		if (!user.unEquip(W))
			return
		W.forceMove(src)
		to_chat(user, SPAN_NOTICE("You set \the [W] in the hatch's cradle."))
		return
	if (is_tool(W, TOOL_WRENCH))
		var/list/held = bombs()
		if (!held.len)
			return
		var/obj/item/weapon/aircraft_bomb/B = held[1]
		B.forceMove(get_turf(user))
		user.put_in_hands(B)
		to_chat(user, SPAN_NOTICE("You lift \the [B] out of the cradle."))
		return
	return ..()

// The ground straight under the hatch when it hangs in the open air.
/obj/structure/airship_bomb_hatch/proc/drop_turf()
	var/turf/T = get_turf(src)
	if (!istype(T, /turf/sky/building))
		return null
	return air_hull_solid_below(T)

/obj/structure/airship_bomb_hatch/attack_hand(mob/living/user)
	if (!isliving(user) || get_dist(user, src) > 1)
		return
	var/list/held = bombs()
	if (!held.len)
		to_chat(user, SPAN_WARNING("There is no bomb in the cradle."))
		return
	var/turf/G = drop_turf()
	if (!G)
		to_chat(user, SPAN_WARNING("There is only deck under the hatch here: fly over open ground first."))
		return
	var/obj/item/weapon/aircraft_bomb/B = held[1]
	flick("bomb_hatch_open", src)
	visible_message(SPAN_WARNING("\The [src] swings open and a bomb falls away!"))
	log_game("[key_name(user)] dropped a bomb from an airship onto [G.x],[G.y],[G.z].")
	B.forceMove(G)
	B.detonate()

// The airship whose deck user stands on, or null.
/proc/air_hull_under(mob/user)
	if (!user || !air_hull_crafts.len)
		return null
	var/turf/T = get_turf(user)
	if (!istype(T, /turf/sky/building))
		return null
	for (var/datum/craft/air/C in air_hull_crafts)
		if (C.body && C.body.contains(T))
			return C
	return null

// ---- The helm ----

/obj/item/airship_helm_kit
	name = "airship helm kit"
	desc = "An airship's wheel and post, knocked down. Use it on an airship deck to set the helm up there, facing the way you face. The helm commissions the deck around it as an airship."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "helm_kit"
	w_class = ITEM_SIZE_LARGE
	weight = 10

/obj/item/airship_helm_kit/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = get_turf(A)
	if (!T || !(locate(/obj/covers/airship_deck) in T))
		return ..()
	if (get_dist(user, T) > 1 || T.z != user.z)
		return TRUE
	for (var/atom/movable/M in T)
		if (M.density && M.loc == T)
			to_chat(user, SPAN_WARNING("\The [M] is in the way."))
			return TRUE
	if (!do_after(user, AIR_HULL_CELL_TIME, T) || QDELETED(src) || user.get_active_hand() != src || !(locate(/obj/covers/airship_deck) in T))
		return TRUE
	qdel(src)
	var/obj/structure/airship_helm/H = new(T)
	H.dir = user.dir
	to_chat(user, SPAN_NOTICE("You set up the helm. Use it to commission the deck around it as an airship."))
	return TRUE

/obj/structure/airship_helm
	name = "airship helm"
	desc = "An airship's wheel and compass. It commissions the deck around it, casts her off and steers her."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "helm"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	var/tmp/datum/craft/air/craft
	// Saved: the airship (json of body_state() with speed and holding).
	var/hull_state = ""

/obj/structure/airship_helm/persistence_runtime_var(key)
	return key == "craft" || ..()

/obj/structure/airship_helm/Destroy()
	decommission()
	return ..()

/obj/structure/airship_helm/proc/body()
	return craft ? craft.body : null

// Surveys the deck around the helm and makes (or remakes) the airship.
// Returns null when done, else the reason.
/obj/structure/airship_helm/proc/commission(hull_name = null, heading = null)
	var/turf/T = get_turf(src)
	var/survey = air_hull_survey(T, craft)
	if (istext(survey))
		return survey
	var/datum/craft_body/built/air/B = body()
	if (!B)
		B = new /datum/craft_body/built/air
		craft = new /datum/craft/air(B)
	if (B.placed())
		B.set_afloat(FALSE)
	B.adopt(survey, T, heading || B.dir)
	if (hull_name)
		B.hull_name = hull_name
		craft.name = hull_name
	craft.fit_drives()
	craft.update_views()
	return null

/obj/structure/airship_helm/proc/decommission()
	if (!craft)
		return
	var/datum/craft/air/C = craft
	craft = null
	var/datum/craft_body/built/B = C.body
	if (istype(B))
		B.set_afloat(FALSE)
	C.clear_views()
	qdel(C.body)
	qdel(C)

/obj/structure/airship_helm/before_save()
	..()
	var/datum/craft_body/built/air/B = body()
	if (!B || !B.placed())
		hull_state = ""
		return
	var/list/state = B.body_state()
	state["speed"] = craft.speed
	state["anchored"] = craft.anchored
	hull_state = json_encode(state)

/obj/structure/airship_helm/after_load()
	..()
	if (craft || !hull_state)
		return
	var/list/state = null
	try
		state = json_decode(hull_state)
	catch
		return
	var/datum/craft_body/built/air/B = new
	if (!B.restore_state(state, get_turf(src)))
		qdel(B)
		return
	craft = new /datum/craft/air(B)
	craft.name = B.hull_name
	// A save restored in mid flight holds her where she is.
	craft.anchored = TRUE
	craft.update_views()

/obj/structure/airship_helm/proc/status_text()
	if (!craft)
		return "The helm is not commissioned. It must stand on an airship deck."
	var/datum/craft_body/built/air/B = craft.body
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	var/engines = 0
	for (var/datum/craft_drive/D in craft.drives)
		if (D.ready())
			engines++
	return "[capitalize(craft.name)]: [B.tile_count()] tiles of deck, gas cells holding up [B.lift()] of her [B.load()], [speeds[craft.speed + 1]], bow to the [dir2text(B.dir)], [B.landed() ? "on the ground, " : ""][craft.changing_level ? "changing height" : (craft.anchored ? "holding position" : "cast off")]. [engines ? "[engines] engine[engines == 1 ? "" : "s"] running." : "No engine is running: she drifts along at slow ahead."]"

/obj/structure/airship_helm/examine(mob/user)
	..()
	to_chat(user, status_text())

/obj/structure/airship_helm/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (!craft)
		commission_menu(H)
		return
	craft.fit_drives()
	var/list/options = list()
	var/best = craft.max_speed()
	if (best >= VESSEL_SPEED_FULL)
		options += "Full ahead"
	if (best >= VESSEL_SPEED_HALF)
		options += "Half ahead"
	options += list("Slow ahead", "All stop", "Head north", "Head east", "Head south", "Head west", craft.anchored ? "Cast off" : "Hold position")
	var/datum/craft_body/built/air/AB = craft.body
	options += AB.landed() ? "Lift off" : "Land"
	options += list("Refit the deck", "Draw her lines", "Strike the airship", "Cancel")
	var/choice = WWinput(H, status_text(), name, "Cancel", options)
	if (!choice || choice == "Cancel" || !craft || get_dist(H, src) > 1)
		return
	switch (choice)
		if ("Full ahead") craft.set_speed(VESSEL_SPEED_FULL)
		if ("Half ahead") craft.set_speed(VESSEL_SPEED_HALF)
		if ("Slow ahead") craft.set_speed(VESSEL_SPEED_SLOW)
		if ("All stop") craft.set_speed(VESSEL_SPEED_STOP)
		if ("Cast off")
			var/datum/craft_body/built/air/B = craft.body
			var/short = B.lift_refusal()
			if (short)
				to_chat(H, SPAN_WARNING("She cannot cast off: [short]."))
				return
			craft.set_anchor(FALSE)
		if ("Hold position") craft.set_anchor(TRUE)
		if ("Lift off")
			if (!craft.lift_off())
				to_chat(H, SPAN_WARNING("She cannot lift off: [craft.last_refusal]."))
				return
		if ("Land")
			if (!craft.land())
				to_chat(H, SPAN_WARNING("She cannot land here: [craft.last_refusal]."))
				return
		if ("Head north", "Head east", "Head south", "Head west")
			var/heading = text2dir(copytext(choice, 6))
			if (craft.anchored)
				to_chat(H, SPAN_WARNING("Cast off before coming about."))
				return
			if (!craft.order_turn(heading))
				to_chat(H, SPAN_WARNING("She cannot come about here: [craft.last_refusal]."))
				return
			return
		// A blank sheet of paper in hand becomes her airship sheet (air_draught.dm).
		if ("Draw her lines")
			draw_air_lines(H)
			return
		if ("Refit the deck")
			if (!craft.anchored)
				to_chat(H, SPAN_WARNING("Hold position before refitting."))
				return
			var/problem = commission()
			if (problem)
				to_chat(H, SPAN_WARNING(problem))
				return
			to_chat(H, SPAN_NOTICE("The deck is surveyed again. [status_text()]"))
			return
		if ("Strike the airship")
			if (!craft.anchored)
				to_chat(H, SPAN_WARNING("Hold position before striking her."))
				return
			if (WWinput(H, "Strike the [craft.name]? Her deck stays where it is, but she no longer flies.", name, "No", list("Yes", "No")) != "Yes" || !craft || get_dist(H, src) > 1)
				return
			log_game("[key_name(H)] struck the airship [craft.name] at [x],[y],[z].")
			craft.crew_message(SPAN_NOTICE("[H] strikes the [craft.name]."))
			decommission()
			return
	if (craft)
		craft.crew_message(SPAN_NOTICE("[H] at the helm: [choice]. [status_text()]"))

/obj/structure/airship_helm/proc/commission_menu(mob/living/human/H)
	var/survey = air_hull_survey(get_turf(src))
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/list/found = survey
	var/list/headings = list("Bow to the north" = NORTH, "Bow to the east" = EAST, "Bow to the south" = SOUTH, "Bow to the west" = WEST)
	var/choice = WWinput(H, "The deck around this helm is [found.len] tiles. Commission her as an airship? Choose where her bow points.", name, "Cancel", headings + list("Cancel"))
	if (isnull(headings[choice]) || craft || get_dist(H, src) > 1)
		return
	var/hull_name = player_input(H, "Name her.", name, "airship", "text", null, TRUE)
	if (isnull(hull_name) || craft || get_dist(H, src) > 1)
		return
	hull_name = sanitize(copytext(hull_name, 1, 40))
	if (!length(hull_name))
		hull_name = "airship"
	var/problem = commission(hull_name, headings[choice])
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	log_game("[key_name(H)] commissioned the airship [hull_name] ([found.len] tiles) at [x],[y],[z].")
	visible_message(SPAN_NOTICE("[H] commissions the [hull_name]. She holds her position."))

#undef AIR_HULL_MAX_TILES
#undef AIR_HULL_CELL_LIFT
#undef AIR_HULL_LAY_TIME
#undef AIR_HULL_CELL_TIME
#undef AIR_HULL_HOLE_LIFT
#undef AIR_HULL_HIT_CHANCE
#undef AIR_HULL_CREW_HIT_CHANCE
#undef AIR_HULL_PATCH_TIME
#undef AIR_HULL_RUBBER_SHEETS
#undef AIR_HULL_SKIN_LAYERS
#undef AIR_HULL_HATCH_BOMBS
#undef AIR_HULL_MAX_DROP
#undef AIR_HULL_LEVEL_TIME
#undef AIR_HULL_TREE_SHARE
