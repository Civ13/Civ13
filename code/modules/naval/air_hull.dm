// ============================================================
// Crewed airships: built hulls in the open air (docs/craft-core.md)
// ------------------------------------------------------------
// Stand a ladder up from the ground into the open air, then lay airship planks
// on the open air beside its top. Every plank joined to the first is one deck.
// Gas cells hung over the deck hold it up; an airship helm set on the deck
// commissions it, like a tiller commissions a hull on the water. She then
// flies like a built hull sails (craft/built_body.dm, craft/under_way.dm):
// over open air only, stopped by upper storeys, ladders and the map edge.
// Engines running aboard drive her faster (naval/hull_drives.dm); sails and
// oars do nothing up here.
//
// The crew sees the ground below through the open air around her, and the
// ground sees her shadow. Both views live in nullspace and are drawn through
// turf vis_contents, like the planes' (aircraft_view.dm), so no save records
// them. People aboard shoot and throw at the ground below from the deck
// (pedal_airship_combat.dm, airborne_launch_turf).
// ============================================================

#define AIR_HULL_MAX_TILES 60
// Tiles of deck, or people aboard, one gas cell holds up.
#define AIR_HULL_CELL_LIFT 12
// Ground shown around her in full, and a fainter ring beyond.
#define AIR_HULL_VIEW_RANGE 7
#define AIR_HULL_VIEW_FAR 10
#define AIR_HULL_LAY_TIME 20
#define AIR_HULL_CELL_TIME 30

var/global/list/air_hull_crafts = list()

// ---- The deck ----

/obj/covers/airship_deck
	name = "airship deck"
	desc = "Light planks lashed into the gondola deck of an airship. It hangs in the open air: step off its edge and you fall."

/obj/item/airship_planks
	name = "airship planks"
	desc = "A lashed bundle of light planks for an airship's gondola deck. Use it on the open air beside the top of a ladder, or beside a deck already laid, to lay one tile of deck."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "airship_planks"
	w_class = ITEM_SIZE_LARGE
	weight = 6
	flammable = TRUE

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

// Why a plank cannot go on T for user, or null. The deck starts from the top
// of a ladder standing in the open air and grows edge to edge.
/proc/air_deck_lay_refusal(turf/T, mob/user)
	var/turf/here = get_turf(user)
	if (!T || !here || T.z != here.z || get_dist(here, T) > 1)
		return "Lay the planks on the open air right beside you."
	if (!air_deck_open(T))
		return "Airship planks are laid on clear open air, above the ground."
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
		if (locate(/obj/structure/multiz) in N)
			return null
	return "Start the deck beside the top of a ladder standing in the open air, and grow it edge to edge."

/obj/item/airship_planks/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = isturf(A) ? A : null
	if (!istype(T, /turf/sky/building))
		return ..()
	var/why = air_deck_lay_refusal(T, user)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts lashing planks into the open air."), SPAN_NOTICE("You start lashing the planks into place..."))
	if (!do_after(user, AIR_HULL_LAY_TIME, T) || QDELETED(src) || user.get_active_hand() != src || air_deck_lay_refusal(T, user))
		return TRUE
	qdel(src)
	new /obj/covers/airship_deck(T)
	to_chat(user, SPAN_NOTICE("You lay a tile of airship deck."))
	return TRUE

// ---- Gas cells ----

/obj/item/airship_gas_cell
	name = "folded gas cell"
	desc = "An oiled-cloth gas cell, rolled tight. Use it on an airship deck to hang it there. Each cell holds up 12 tiles of deck or people aboard."
	icon = 'icons/obj/vehicles/airship_hull.dmi'
	icon_state = "gas_cell_folded"
	w_class = ITEM_SIZE_LARGE
	weight = 8
	flammable = TRUE

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
	new /obj/structure/airship_gas_cell(T)
	to_chat(user, SPAN_NOTICE("The gas cell fills and strains at its rigging."))
	return TRUE

/obj/structure/airship_gas_cell
	name = "gas cell"
	desc = "A gas cell rigged over an airship's deck. It holds up tiles of deck and the people aboard. A wrench takes it down."
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

/obj/structure/airship_gas_cell/proc/lift()
	return AIR_HULL_CELL_LIFT

/obj/structure/airship_gas_cell/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_WRENCH))
		var/datum/craft/C = craft_at(get_turf(src))
		if (C && !C.anchored)
			to_chat(user, SPAN_WARNING("Hold the airship in place at her helm before taking down a gas cell."))
			return
		to_chat(user, SPAN_NOTICE("You start letting the gas out of \the [src]..."))
		if (!do_after(user, AIR_HULL_CELL_TIME, src) || QDELETED(src))
			return
		var/turf/T = get_turf(src)
		qdel(src)
		new /obj/item/airship_gas_cell(T)
		to_chat(user, SPAN_NOTICE("You fold the gas cell up."))
		return
	return ..()

// ---- The body ----

/datum/craft_body/built/air
	hull_name = "airship"

// No upper deck: she is on the top level already.
/datum/craft_body/built/air/upper_z()
	return 0

/datum/craft_body/built/air/tile_refusal(turf/D)
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

// What her gas cells hold up, and what they must.
/datum/craft_body/built/air/proc/lift()
	. = 0
	for (var/turf/T in cells())
		for (var/obj/structure/airship_gas_cell/G in T)
			. += G.lift()

/datum/craft_body/built/air/proc/load()
	. = offsets.len
	for (var/turf/T in cells())
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
	if (!istype(start, /turf/sky/building) || !(locate(/obj/covers/airship_deck) in start))
		return "The helm must stand on an airship deck laid in the open air."
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
	var/tmp/obj/effect/aircraft_ground_view/ground_view
	var/tmp/obj/effect/aircraft_ground_view/ground_view_far
	var/tmp/turf/ground_view_anchor
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
	return (istype(B) && B.placed()) ? multiz_level_below(B.z) : 0

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
	var/max_x = B.px + box[3]
	var/max_y = B.py + box[4]
	// Her shadow, laid out from the corner of her box on the ground.
	if (!shadow)
		shadow = new
		shadow.loc = null
	var/turf/corner = locate(min_x, min_y, ground)
	if (shadow_anchor != corner)
		if (shadow_anchor)
			shadow_anchor.vis_contents -= shadow
		shadow_anchor = corner
		if (corner)
			corner.vis_contents += shadow
	shadow.vis_contents = deck
	// The ground around her, seen through the open air.
	var/list/near = list()
	var/list/far = list()
	var/vx = world.maxx + 1
	var/vy = world.maxy + 1
	for (var/turf/air in block(locate(max(1, min_x - AIR_HULL_VIEW_FAR), max(1, min_y - AIR_HULL_VIEW_FAR), B.z), locate(min(world.maxx, max_x + AIR_HULL_VIEW_FAR), min(world.maxy, max_y + AIR_HULL_VIEW_FAR), B.z)))
		if (!istype(air, /turf/sky/building) || (locate(/obj/covers) in air))
			continue
		var/turf/G = locate(air.x, air.y, ground)
		if (!G)
			continue
		var/dx = max(0, min_x - air.x, air.x - max_x)
		var/dy = max(0, min_y - air.y, air.y - max_y)
		if (max(dx, dy) <= AIR_HULL_VIEW_RANGE)
			near += G
		else
			far += G
		vx = min(vx, G.x)
		vy = min(vy, G.y)
	var/turf/anchor = (near.len || far.len) ? locate(vx, vy, B.z) : null
	// Never anchored on her own deck: the shadow already draws the deck.
	if (anchor && B.contains(anchor))
		anchor = null
	if (!ground_view)
		ground_view = new
		ground_view.loc = null
	if (!ground_view_far)
		ground_view_far = new /obj/effect/aircraft_ground_view/far
		ground_view_far.loc = null
	if (ground_view_anchor != anchor)
		if (ground_view_anchor)
			ground_view_anchor.vis_contents -= ground_view
			ground_view_anchor.vis_contents -= ground_view_far
		ground_view_anchor = anchor
		if (anchor)
			anchor.vis_contents += ground_view_far
			anchor.vis_contents += ground_view
	ground_view.vis_contents = anchor ? near : list()
	ground_view_far.vis_contents = anchor ? far : list()

/datum/craft/air/proc/clear_views()
	if (shadow_anchor && shadow)
		shadow_anchor.vis_contents -= shadow
	shadow_anchor = null
	if (shadow)
		shadow.vis_contents = list()
		qdel(shadow)
	shadow = null
	if (ground_view_anchor)
		ground_view_anchor.vis_contents -= ground_view
		ground_view_anchor.vis_contents -= ground_view_far
	ground_view_anchor = null
	if (ground_view)
		ground_view.vis_contents = list()
		qdel(ground_view)
	if (ground_view_far)
		ground_view_far.vis_contents = list()
		qdel(ground_view_far)
	ground_view = null
	ground_view_far = null

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
		return "The helm is not commissioned. It must stand on an airship deck laid in the open air."
	var/datum/craft_body/built/air/B = craft.body
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	var/engines = 0
	for (var/datum/craft_drive/D in craft.drives)
		if (D.ready())
			engines++
	return "[capitalize(craft.name)]: [B.tile_count()] tiles of deck, gas cells holding up [B.lift()] of her [B.load()], [speeds[craft.speed + 1]], bow to the [dir2text(B.dir)], [craft.anchored ? "holding position" : "cast off"]. [engines ? "[engines] engine[engines == 1 ? "" : "s"] running." : "No engine is running: she drifts along at slow ahead."]"

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
	options += list("Slow ahead", "All stop", "Head north", "Head east", "Head south", "Head west", craft.anchored ? "Cast off" : "Hold position", "Refit the deck", "Strike the airship", "Cancel")
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
		if ("Head north", "Head east", "Head south", "Head west")
			var/heading = text2dir(copytext(choice, 6))
			if (craft.anchored)
				to_chat(H, SPAN_WARNING("Cast off before coming about."))
				return
			if (!craft.order_turn(heading))
				to_chat(H, SPAN_WARNING("She cannot come about here: [craft.last_refusal]."))
				return
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
			if (WWinput(H, "Strike the [craft.name]? Her deck stays where it is, hanging in the air, but she no longer flies.", name, "No", list("Yes", "No")) != "Yes" || !craft || get_dist(H, src) > 1)
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
#undef AIR_HULL_VIEW_RANGE
#undef AIR_HULL_VIEW_FAR
#undef AIR_HULL_LAY_TIME
#undef AIR_HULL_CELL_TIME
