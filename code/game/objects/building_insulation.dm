// Insulation: a roof alone no longer keeps you warm.
//
// An inside (roofed) tile belongs to a room: the roofed tiles reachable
// without crossing a wall, door or window, the same rooms home comfort
// judges. What bounds the room decides how well it holds its warmth:
// - Each edge tile has a value (building_insulation_edge): mapped walls are
//   well-insulated stone (1), caves better, earth and clay walls good, stone
//   and timber less, metal and glass poor.
// - An open door, an empty window frame or a roofed tile open to the outside
//   is a gap. A room with a gap is draughty and keeps half its value.
// - A roof with nothing round it only keeps off the wind (a few degrees).
// get_temp() pulls an inside tile towards 10-22 C by up to 40 C times the
// room's value. A fire, stove or engine in the room heats it, divided by the
// room's size and kept by its insulation; in the open a fire only warms
// people right beside it (nearby_heat_source).
//
// Insulation you add:
// - A wall lined on its inside with straw, cloth or wool (two of them on a
//   built wall, not on harm intent) holds more warmth.
// - A closed curtain closes a doorway or covers a window; it bounds a room.
// - A tapestry hung on a wall, and rugs or boards over most of the floor,
//   add a little.
//
// Each room is surveyed when someone in it first asks, and the answer is kept
// for BUILDING_ROOM_KEEP, so nothing scans the map on a timer.

#define BUILDING_ROOM_LIMIT 400
#define BUILDING_ROOM_KEEP 100
// Degrees an inside tile moves towards comfort per unit of insulation.
#define BUILDING_INSULATION_DEGREES 40
// Degrees a bare roof shelters from the wind.
#define BUILDING_ROOF_SHELTER 5
// Tiles of room one unit of heat warms fully at insulation 1.
#define BUILDING_HEAT_TILES 30
// What a closed curtain in a doorway or empty frame is worth.
#define BUILDING_CURTAIN_VALUE 0.35
// What a closed curtain adds over glazing that already seals the room.
#define BUILDING_GLAZED_CURTAIN_BONUS 0.2
#define BUILDING_LINING_COST 2

var/global/list/building_room_of = list()

/datum/building_room
	var/list/turfs = list()
	var/expires = 0
	// Average insulation over the room's edge, before draughts.
	var/insulation = 0
	var/draughty = FALSE
	var/gaps = 0
	var/edges = 0
	// How far the room's fires lift it towards 22 C, 0 to 1.
	var/heat = 0

// Degrees this room moderates the outside temperature by.
/datum/building_room/proc/moderation()
	return max(BUILDING_ROOF_SHELTER, round(BUILDING_INSULATION_DEGREES * effective_insulation()))

/datum/building_room/proc/effective_insulation()
	return draughty ? insulation / 2 : insulation

// The room around T, surveyed or remembered, or null when T is not inside a room.
/proc/building_room_at(turf/T)
	if (!T || !home_turf_inside(T))
		return null
	var/datum/building_room/R = building_room_of[T]
	if (R && world.time < R.expires)
		return R
	if (R)
		for (var/turf/old in R.turfs)
			if (building_room_of[old] == R)
				building_room_of -= old
	R = building_room_survey(T)
	if (!R)
		return null
	for (var/turf/inside in R.turfs)
		building_room_of[inside] = R
	return R

/proc/building_room_survey(turf/start)
	if (home_turf_bounds_room(start))
		return null
	var/datum/building_room/R = new
	R.expires = world.time + BUILDING_ROOM_KEEP
	var/list/turfs = R.turfs
	var/list/seen = list()
	seen[start] = TRUE
	turfs += start
	var/total = 0
	var/i = 1
	while (i <= turfs.len && turfs.len < BUILDING_ROOM_LIMIT)
		var/turf/T = turfs[i]
		i++
		for (var/dir in cardinal)
			var/turf/N = get_step(T, dir)
			if (!N || seen[N])
				continue
			seen[N] = TRUE
			if (home_turf_bounds_room(N))
				var/value = building_insulation_edge(N, T, dir)
				R.edges++
				total += value
				if (value <= 0)
					R.gaps++
			else if (home_turf_inside(N))
				turfs += N
				if (turfs.len >= BUILDING_ROOM_LIMIT)
					break
			else
				// Roofed floor that runs straight out under the sky.
				R.edges++
				R.gaps++
	R.insulation = R.edges ? total / R.edges : 0
	// Rugs, boards or carpet over most of the floor keep a little more in.
	var/covered = 0
	for (var/turf/F in turfs)
		if (home_floor_covered(F))
			covered++
	if (covered * 2 >= turfs.len)
		R.insulation += 0.05
	R.draughty = R.gaps > 0
	R.heat = building_room_heat(R)
	return R

// How well what stands on an edge tile holds warmth in. from and dir are the
// room tile it was reached from and the way to it, for what hangs on the wall.
/proc/building_insulation_edge(turf/N, turf/from = null, dir = 0)
	if (!N)
		return 0
	var/value = building_insulation_edge_base(N)
	if (value > 0 && from && building_tapestry_on(from, dir))
		value += 0.1
	return value

/proc/building_insulation_edge_base(turf/N)
	if (N.density)
		if (istype(N, /turf/wall/rockwall))
			return 1.2
		return 1
	var/curtained = FALSE
	for (var/obj/structure/curtain/CU in N)
		if (CU.opacity)
			curtained = TRUE
			break
	for (var/obj/structure/simple_door/D in N)
		if (D.door_seals_room())
			var/door_value = building_insulation_material(D.material ? D.material.name : "wood") * 0.8
			if (curtained && istype(D, /obj/structure/simple_door/key_door/anyone/casement))
				door_value += BUILDING_GLAZED_CURTAIN_BONUS
			return door_value
		// Open shutters can expose an intact pane on the same tile.
		if (!istype(D, /obj/structure/simple_door/key_door/anyone/window_shutters))
			return curtained ? BUILDING_CURTAIN_VALUE : 0
	for (var/obj/covers/C in N)
		if (C.wall)
			if (C.incomplete)
				return 0.3
			// Log walls (log_wall_building.dm): thick and tight once chinked,
			// draughty through the gaps until then.
			if (istype(C, /obj/covers/wood_wall/log))
				var/obj/covers/wood_wall/log/L = C
				return (L.chinked ? 0.8 : 0.5) + building_lining_bonus(C.insulation_lining)
			return building_insulation_material(C.material) + building_lining_bonus(C.insulation_lining)
	for (var/obj/structure/window/W in N)
		if (istype(W, /obj/structure/window/barrier))
			return building_insulation_material(W.structure_impact_material() || "dirt")
		return 0.3 + (curtained ? BUILDING_GLAZED_CURTAIN_BONUS : 0)
	// An empty window frame or doorway, closed only by a curtain if anything.
	return curtained ? BUILDING_CURTAIN_VALUE : 0

// Whether a tapestry hangs on T facing dir.
/proc/building_tapestry_on(turf/T, dir)
	for (var/obj/structure/painting_frame/F in T)
		if (F.dir == dir && istype(F.held_canvas(), /obj/item/canvas/woven/tapestry))
			return TRUE
	return FALSE

// ---- wall linings -------------------------------------------------------

/obj/covers/var/insulation_lining = null

/proc/building_lining_kind(obj/item/W)
	if (istype(W, /obj/item/stack/material/straw))
		return "straw"
	if (istype(W, /obj/item/stack/material/wool))
		return "wool"
	if (istype(W, /obj/item/stack/material/cloth))
		return "cloth"
	return null

/proc/building_lining_bonus(kind)
	switch (kind)
		if ("straw", "cloth")
			return 0.15
		if ("wool")
			return 0.25
	return 0

/obj/covers/proc/building_line_wall(obj/item/stack/S, mob/living/user)
	var/kind = building_lining_kind(S)
	if (insulation_lining)
		to_chat(user, SPAN_WARNING("\The [src] is already lined with [insulation_lining]."))
		return
	if (S.amount < BUILDING_LINING_COST)
		to_chat(user, SPAN_WARNING("You need [BUILDING_LINING_COST] [S.name] to line \the [src]."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts packing [kind] against \the [src]."), SPAN_NOTICE("You start lining \the [src] with [kind] to keep the warmth in."))
	if (!do_after(user, 40, src) || QDELETED(src) || QDELETED(S) || insulation_lining || S.amount < BUILDING_LINING_COST)
		return
	S.use(BUILDING_LINING_COST)
	insulation_lining = kind
	user.visible_message(SPAN_NOTICE("[user] lines \the [src] with [kind]."), SPAN_NOTICE("You line \the [src] with [kind]."))

/proc/building_insulation_material(name)
	switch (lowertext("[name]"))
		if ("dirt", "earth", "clay", "adobe", "mud", "cob", "sandbag", "snow", "ice", "turf")
			return 0.9
		if ("thatch", "straw", "hide", "leather")
			return 0.75
		if ("stone", "brick", "sandstone", "marble", "granite", "basalt", "limestone", "rock")
			return 0.8
		if ("wood")
			return 0.7
		if ("concrete", "cement", "reinforced concrete")
			return 0.7
		if ("bamboo", "cloth", "canvas", "paper")
			return 0.4
		if ("steel", "iron", "metal", "aluminium", "bronze", "copper", "lead")
			return 0.3
		if ("glass")
			return 0.2
	return 0.6

// Heat a lit source gives its room.
/proc/building_heat_power(obj/O)
	if (istype(O, /obj/structure/brazier))
		var/obj/structure/brazier/B = O
		return B.on ? 1 : 0
	if (istype(O, /obj/structure/heatsource))
		var/obj/structure/heatsource/HS = O
		return HS.on ? 1 : 0
	if (istype(O, /obj/structure/oven/fireplace))
		var/obj/structure/oven/fireplace/FP = O
		return FP.on ? 2 : 0
	if (istype(O, /obj/structure/oven/big))
		var/obj/structure/oven/big/OB = O
		return OB.on ? 3 : 0
	if (istype(O, /obj/structure/engine))
		var/obj/structure/engine/EN = O
		return EN.on ? 1 : 0
	if (istype(O, /obj/structure/chimney)) // the fire below, carried up (storey_chimney.dm)
		var/obj/structure/chimney/CH = O
		return CH.chimney_heat()
	return 0

/proc/building_room_heat(datum/building_room/R)
	var/power = 0
	for (var/turf/T in R.turfs)
		for (var/obj/structure/S in T)
			power += building_heat_power(S)
	if (power <= 0)
		return 0
	return min(1, power * BUILDING_HEAT_TILES * R.effective_insulation() / max(1, R.turfs.len))

// A few words on how a room holds its warmth, for Judge This Room.
/proc/building_room_warmth_text(datum/building_room/R)
	if (!R)
		return null
	var/eff = R.effective_insulation()
	var/word = "barely sheltered from the wind"
	if (eff >= 0.85)
		word = "very well insulated"
	else if (eff >= 0.65)
		word = "well insulated"
	else if (eff >= 0.45)
		word = "fairly insulated"
	else if (eff >= 0.2)
		word = "poorly insulated"
	var/text = "It is [word]"
	if (R.draughty)
		text += ", and draughty: [R.gaps == 1 ? "a gap" : "[R.gaps] gaps"] in its walls, an open door or an empty window let the warmth out"
	text += "."
	if (R.heat >= 1)
		text += " Its fire keeps it warm."
	else if (R.heat > 0)
		text += " Its fire is too small for it to keep it warm."
	return text

#undef BUILDING_ROOM_LIMIT
#undef BUILDING_ROOM_KEEP
#undef BUILDING_INSULATION_DEGREES
#undef BUILDING_ROOF_SHELTER
#undef BUILDING_HEAT_TILES
#undef BUILDING_CURTAIN_VALUE
#undef BUILDING_GLAZED_CURTAIN_BONUS
#undef BUILDING_LINING_COST
