// Heavy locomotives (docs/trains.md): three tiles wide and four long, built
// from a kit like a platform car. The engine itself is the front section, a
// /obj/structure/trains/locomotive that drives with the same throttle,
// reverser and load rules as the one-tile engines (trains.dm). The three
// sections behind it are platform segments of a "loco_*" car kind, hitched to
// it and to each other, so the body follows curves and reverses with the
// train. The cab is the one section people stand in; the controls work from
// there. A steam cab has three stations (cab_station()), and its fire is fed
// at the firebox door; water goes in from anywhere beside the engine. The
// main-line engine is the same thing six sections long, with a tender.
//
// Side tiles are 1 (left of the heading) and 3 (right), as in
// train_platform_tiles(); sides are -1 and 1 as on train_part.

/obj/structure/trains
	var/car_id = "" // shared by the sections of one platform car or heavy locomotive
	var/tmp/list/roof_images = null // left, centre, right (vehicle_decks.dm)

// TRUE for rolling stock that also covers the tile either side of the track.
/obj/structure/trains/proc/wide_body()
	return FALSE

/obj/structure/trains/platform/wide_body()
	return TRUE

/obj/structure/trains/locomotive/wide_body()
	return !!body_kind

/obj/structure/trains/locomotive
	var/body_kind = null // "steam", "diesel" or "armored" for a heavy locomotive
	var/broken_down = FALSE // holed by explosions until welded
	var/tmp/list/body_parts = null

// The layouts of the locomotive bodies, added to train_car_layout(). "solid"
// is 2 for a section nobody can enter, 1 when only the rail tile is blocked
// (a hood with a walkway either side) and 0 for the cab.
/proc/train_locomotive_layouts(list/layouts)
	var/list/armor_cab = list(list(-1, "out", "armor_door"), list(1, "out", "armor_door"))
	layouts["loco_steam"] = list(
		"name" = "heavy steam locomotive", "desc" = "A main-line steam locomotive with its own coal bunker. Drive it from the cab; it burns coal, wood and branches.",
		"body" = "steam", "cab" = 3, "stations" = TRUE, "roof" = "loco_steam", "engine" = /obj/structure/trains/locomotive/coal/heavy,
		"segments" = list(
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 0),
			list("edges" = list(), "solid" = 2)))
	layouts["loco_diesel"] = list(
		"name" = "heavy diesel locomotive", "desc" = "A diesel locomotive with the cab at the front and walkways along its long hood. It runs on diesel or biodiesel.",
		"body" = "diesel", "cab" = 1, "roof" = "loco_diesel", "engine" = /obj/structure/trains/locomotive/heavy_diesel,
		"segments" = list(
			list("edges" = list(), "solid" = 0),
			list("edges" = list(), "solid" = 1),
			list("edges" = list(), "solid" = 1),
			list("edges" = list(), "solid" = 1)))
	layouts["loco_armored"] = list(
		"name" = "heavy armored locomotive", "desc" = "A steam locomotive under riveted plate from buffer to bunker. Its cab doors stop bullets from outside.",
		"body" = "armored", "cab" = 3, "stations" = TRUE, "roof" = "loco_armored", "armored" = TRUE, "engine" = /obj/structure/trains/locomotive/coal/armored/heavy,
		"segments" = list(
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = armor_cab, "solid" = 0),
			list("edges" = list(), "solid" = 2)))
	// The main-line engine: six sections, the cab last, and no bunker or tank
	// of its own. It runs with a tender coupled behind the cab.
	layouts["loco_mainline"] = list(
		"name" = "main-line steam locomotive", "desc" = "A big express engine with six coupled wheels. It carries no coal or water of its own: couple a tender behind its cab. The driver's stand is on the right of the cab, the firebox door in the middle and the fireman's side on the left.",
		"body" = "mainline", "cab" = 6, "stations" = TRUE, "roof" = "loco_mainline", "engine" = /obj/structure/trains/locomotive/coal/mainline,
		"segments" = list(
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 0)))
	// The main-line diesel (train_diesel.dm): six sections with a cab at each
	// end, "cab2" being the rear one, and a hood with walkways between them.
	var/list/cab_end = list(list(-1, "back", "cab_end"), list(0, "back", "cab_end"), list(1, "back", "cab_end"))
	layouts["loco_dieselmain"] = list(
		"name" = "main-line diesel locomotive", "desc" = "A big diesel locomotive with a cab at each end and walkways along its hood. It runs on diesel or biodiesel, and works in multiple with other diesels coupled next to it.",
		"body" = "dieselmain", "cab" = 1, "cab2" = 6, "roof" = "loco_dieselmain", "engine" = /obj/structure/trains/locomotive/heavy_diesel/mainline,
		"segments" = list(
			list("edges" = list(), "solid" = 0),
			list("edges" = list(), "solid" = 1),
			list("edges" = list(), "solid" = 1),
			list("edges" = list(), "solid" = 1),
			list("edges" = list(), "solid" = 1),
			list("edges" = cab_end, "solid" = 0)))
	// Not an engine: a tender is drawn and built the same way, in one piece.
	layouts["tender"] = list(
		"name" = "tender", "desc" = "A locomotive tender: a coal bunker and a water tank on wheels, with a shovelling plate at the front. Couple it next to a steam locomotive.",
		"body" = "tender",
		"segments" = list(
			list("edges" = list(), "solid" = 0),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2),
			list("edges" = list(), "solid" = 2)))

/////////////////////////////////////////////////////////////////////////////
// Body tiles either side of the track

/obj/structure/train_part/deck/body
	var/obj/structure/trains/locomotive/engine = null

// Body art is drawn for the way the locomotive heads, not for the tile edge.
/obj/structure/train_part/deck/body/facing(heading)
	return heading

/obj/structure/train_part/deck/body/proc/car_engine()
	if (engine)
		return engine
	if (segment)
		return segment.car_engine()
	return null

/obj/structure/train_part/deck/body/Destroy()
	if (engine && engine.body_parts)
		engine.body_parts -= src
	engine = null
	return ..()

/obj/structure/train_part/deck/body/attack_hand(mob/user)
	var/obj/structure/trains/locomotive/E = car_engine()
	if (E)
		return E.attack_hand(user)
	return ..()

/obj/structure/train_part/deck/body/attackby(obj/item/W as obj, mob/user as mob)
	if (segment)
		return segment.attackby(W, user)
	if (engine)
		return engine.attackby(W, user)
	return ..()

/obj/structure/train_part/deck/body/examine(mob/user)
	if (engine && !segment)
		return engine.examine(user)
	return ..()

// The invisible front of a walk-in cab at the head of a locomotive.
/obj/structure/train_part/edge/cab_front
	icon = null
	icon_state = null
	mouse_opacity = 0

// The engine itself rolls out from behind its own windscreen.
/obj/structure/train_part/edge/cab_front/CheckExit(atom/movable/O as mob|obj, target as turf, exit_direction = null)
	if (istype(O, /obj/structure/trains))
		return TRUE
	return ..()

// The engine of the locomotive this section belongs to.
/obj/structure/trains/platform/proc/car_engine()
	var/list/L = layout()
	if (!L || !L["body"] || !car_id)
		return null
	for (var/obj/structure/trains/locomotive/E in range(car_length(), src))
		if (E.car_id == car_id)
			return E
	return null

/obj/structure/trains/platform/unit_engine()
	return car_engine()

/obj/structure/trains/platform/attack_hand(mob/user)
	var/obj/structure/trains/locomotive/E = car_engine()
	if (E)
		return E.attack_hand(user)
	return ..()

// A solid section is not pushed along the track by walking into it.
/obj/structure/trains/platform/Bumped(atom/AM)
	return FALSE

// The car id of the roofed vehicle O is part of, for hiding its roof from
// the people inside (process_train_roofs).
/proc/train_roof_car_id(obj/O)
	var/obj/structure/trains/platform/S = train_deck_segment(O)
	if (S)
		return S.car_id
	if (istype(O, /obj/structure/trains/locomotive))
		var/obj/structure/trains/locomotive/E = O
		return E.body_kind ? E.car_id : null
	if (istype(O, /obj/structure/train_part/deck/body))
		var/obj/structure/train_part/deck/body/B = O
		return B.engine ? B.engine.car_id : null
	return null

/////////////////////////////////////////////////////////////////////////////
// The engine section

/obj/structure/trains/locomotive/proc/body_layout()
	return body_kind ? train_car_layout("loco_[body_kind]") : null

// 2: nobody can enter the front section; 0: it is the cab.
/obj/structure/trains/locomotive/proc/head_solid()
	var/list/L = body_layout()
	if (!L)
		return 2
	var/list/segs = L["segments"]
	return segs[1]["solid"]

// The section the driver stands in: the engine itself or a section behind it.
// With two cabs (train_diesel.dm) it is the one user stands at.
/obj/structure/trains/locomotive/proc/control_spot(mob/user)
	var/list/L = body_layout()
	if (user && L && L["cab2"] && get_dist(user, src) > 1)
		var/obj/structure/trains/platform/rear = rear_cab()
		if (rear && get_dist(user, rear) <= 1)
			return rear
	if (!L || L["cab"] == 1)
		return src
	for (var/obj/structure/trains/platform/P in range(body_length(), src))
		if (P.car_id == car_id && P.seg_index == L["cab"])
			return P
	return null

/obj/structure/trains/locomotive/proc/body_length()
	return body_kind ? train_car_length("loco_[body_kind]") : 1

// Cab stations. A steam cab has three, one to each of its tiles, so a full
// crew is a driver and a fireman: the driver's stand on the right (throttle,
// brake and reverser), the firebox door in the middle (the fire, the shovel
// and fuel by hand) and the fireman's side on the left (the injector).
/obj/structure/trains/locomotive/proc/has_stations()
	var/list/L = body_layout()
	return L && L["stations"]

// The station user stands at: "driver", "fire" or "fireman"; "all" for an
// engine worked from one place; null in a cab with stations when user is not
// on one of its tiles.
/obj/structure/trains/locomotive/proc/cab_station(mob/user)
	if (!has_stations())
		return "all"
	var/obj/structure/trains/spot = control_spot()
	if (!spot || !user || !isturf(user.loc) || !isturf(spot.loc))
		return null
	var/list/tiles = train_platform_tiles(spot.loc, spot.dir)
	var/i = tiles.Find(user.loc)
	return i ? list("fireman", "fire", "driver")[i] : null

/obj/structure/trains/locomotive/proc/at_firebox(mob/user)
	var/station = cab_station(user)
	return station == "all" || station == "fire"

/obj/structure/trains/locomotive/proc/station_text(station)
	switch (station)
		if ("driver")
			return "Driver's stand. "
		if ("fire")
			return "Firebox door. "
		if ("fireman")
			return "Fireman's side. "
	return ""

/obj/structure/trains/locomotive/on_runtime_spawn()
	..()
	if (body_kind)
		if (!car_id)
			car_id = "[rand(100000, 999999)]-[rand(100000, 999999)]"
		build_body()

/obj/structure/trains/locomotive/after_load()
	..()
	if (body_kind)
		build_body()

/obj/structure/trains/locomotive/proc/clear_body()
	for (var/obj/structure/train_part/P in body_parts)
		qdel(P)
	body_parts = null
	roof_images = null

/obj/structure/trains/locomotive/proc/build_body()
	clear_body()
	var/list/L = body_layout()
	if (!L)
		return
	name = L["name"]
	desc = L["desc"]
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "loco_[body_kind]_1c"
	layer = 2.6
	var/solid = head_solid()
	density = solid >= 1
	if (!isturf(loc))
		return
	body_parts = list()
	for (var/side in list(-1, 1))
		var/obj/structure/train_part/deck/body/D = new(null)
		D.engine = src
		D.side = side
		D.name = name
		D.desc = desc
		D.icon_state = "loco_[body_kind]_1[side == -1 ? "l" : "r"]"
		D.density = solid >= 2
		body_parts += D
	if (!solid)
		// Nobody walks out through the windscreen onto the track.
		for (var/side in list(-1, 0, 1))
			var/obj/structure/train_part/edge/cab_front/G = new(null)
			G.side = side
			G.edge_kind = "front"
			G.style = "wall"
			G.name = "[name] windscreen"
			G.desc = desc
			body_parts += G
		if (L["cab"] == 1 && L["roof"])
			roof_images = list()
			for (var/i in 1 to 3)
				roof_images += image(icon, null, "roof_[L["roof"]]_[copytext("lcr", i, i + 1)]", 8, dir)
			var/image/C = roof_images[2]
			C.loc = src
			for (var/obj/structure/train_part/deck/body/D in body_parts)
				var/image/R = roof_images[D.side + 2]
				R.loc = D
			train_roof_segments |= src
	place_body()

/obj/structure/trains/locomotive/proc/place_body(plain = FALSE)
	var/list/tiles = train_platform_tiles(loc, dir)
	for (var/image/R in roof_images)
		R.dir = dir
	for (var/obj/structure/train_part/P in body_parts)
		var/turf/where = tiles[P.side + 2]
		if (!where)
			continue
		P.dir = P.facing(dir)
		if (P.loc != where)
			P.train_shift(where, plain)

// A heavy locomotive is too heavy to shove along the track by hand.
/obj/structure/trains/locomotive/Bumped(atom/AM)
	if (body_kind)
		return FALSE
	return ..()

// What rides in a walk-in cab at the head: atom -> tile 1..3.
/obj/structure/trains/locomotive/proc/cab_cargo(list/tiles)
	var/list/cargo = list()
	// On a tight curve a cab side tile is also a tile of a section behind;
	// what stands there stays with that section.
	var/list/behind = list()
	for (var/obj/structure/trains/platform/P in range(body_length(), src))
		if (P.car_id == car_id)
			behind += train_platform_tiles(P.loc, P.dir)
	for (var/i in 1 to 3)
		var/turf/T = tiles[i]
		if (!T || (i != 2 && ((T in behind) || train_centre_of_other(T, src))))
			continue
		for (var/atom/movable/AM in T)
			if (AM.loc == T && train_platform_carries(AM))
				cargo[AM] = i
	return cargo

// People standing beside the track where the front of the body arrives are
// hit like those on the rails, and thrown clear.
/obj/structure/trains/locomotive/proc/sweep_sides(turf/newloc, fdir)
	var/list/tiles = train_platform_tiles(newloc, fdir)
	var/impact = collision_impact()
	for (var/i in list(1, 3))
		var/turf/T = tiles[i]
		if (!T)
			continue
		var/out = (i == 1) ? turn(fdir, 90) : turn(fdir, -90)
		for (var/mob/living/M in T)
			if (impact < 0.5)
				visible_message("<span class = 'warning'>\The [src] shoves \the [M] aside!</span>")
				M.adjustBruteLoss(5)
			else
				visible_message("<span class = 'warning'>\The [src] hits \the [M]!</span>")
				M.adjustBruteLoss(min(250, round(100 * impact)))
			var/turf/clear = get_step(T, out)
			if (clear && !clear.density)
				M.persistence_set_loc(clear)
			train_knock_down(M, impact)

/obj/structure/trains/locomotive/Move(var/turf/newloc, var/fdir = null)
	if (!body_kind || !body_parts)
		return ..()
	if (moving_train || !isturf(loc) || !newloc)
		return FALSE
	if (!fdir)
		fdir = train_heading()
	var/list/old_tiles = train_platform_tiles(loc, dir)
	var/list/cargo = density ? null : cab_cargo(old_tiles)
	if (!train_solo_move)
		sweep_sides(newloc, fdir)
	var/old_dir = dir
	// On a curve the next rail tile is one of the engine's own side tiles: a
	// solid boiler or bunker there must not stop the engine itself.
	var/list/solid_parts = null
	for (var/obj/structure/train_part/P in body_parts)
		if (P.density && P.loc == newloc)
			P.density = FALSE
			LAZYADD(solid_parts, P)
	. = ..()
	for (var/obj/structure/train_part/P in solid_parts)
		P.density = TRUE
	if (!.)
		return
	var/list/new_tiles = train_platform_tiles(loc, dir)
	var/plain = train_tile_unwatched(loc)
	var/turning = 0
	if (dir == turn(old_dir, 90))
		turning = 90
	else if (dir == turn(old_dir, -90))
		turning = -90
	for (var/atom/movable/AM in cargo)
		var/i = cargo[AM]
		if (AM.loc == old_tiles[i] && new_tiles[i] && AM.train_shift(new_tiles[i], plain))
			if (turning && isobj(AM))
				AM.set_dir(turn(AM.dir, turning))
	place_body(plain)

// Fuel this engine takes from the hand.
/obj/structure/trains/locomotive/proc/takes_fuel(obj/item/W)
	return fuel_value(W) > 0

/////////////////////////////////////////////////////////////////////////////
// Damage: explosions wear a heavy locomotive down instead of destroying it.
// At zero health the engine dies until it is welded.

/obj/structure/trains/locomotive/proc/heavy_damage(amount)
	health = max(0, health - amount)
	if (health <= 0 && !broken_down)
		broken_down = TRUE
		automovement = FALSE
		on = FALSE
		throttle = 0
		visible_message(SPAN_DANGER("\The [src] is wrecked and its engine dies!"))

// TRUE when the welder was used on the engine.
/obj/structure/trains/locomotive/proc/heavy_weld(obj/item/W, mob/user)
	if (!is_tool(W, TOOL_WELDER))
		return FALSE
	if (!broken_down && health >= initial(health))
		to_chat(user, "\The [src] is in good repair.")
		return TRUE
	user.visible_message("[user] starts welding \the [src]...", "You start welding \the [src]...")
	if (do_after(user, 100, src))
		health = min(initial(health), health + 600)
		if (broken_down && health >= initial(health) / 2)
			broken_down = FALSE
		user.visible_message("[user] welds \the [src].", "You weld \the [src].")
	return TRUE

/obj/structure/trains/locomotive/proc/heavy_examine(mob/user)
	if (broken_down)
		to_chat(user, SPAN_WARNING("It is wrecked. A welding tool will get it running again."))
	else if (health < initial(health))
		to_chat(user, "It is damaged ([round(100 * health / initial(health))]%). A welding tool repairs it.")
	if (derailed)
		to_chat(user, SPAN_WARNING("It is off the rails. It takes the crane of a crane car and a rerailing jack to put it back."))
	if (has_stations())
		to_chat(user, "It is worked from its cab: the driver's stand on the right, the firebox door in the middle, the fireman's side on the left.")
	else if (rear_cab())
		to_chat(user, "It is driven from the cab at either end. Drive from the cab that leads: with nobody there to see the line it keeps to three quarters of its speed.")
	else
		to_chat(user, "It is driven from its cab.")

/////////////////////////////////////////////////////////////////////////////
// The three engines. Speeds are the locomotive rows of docs/vehicle-speeds.md;
// a heavy engine pulls about twice the train of its one-tile counterpart.

/obj/structure/trains/locomotive/coal/heavy
	name = "heavy steam locomotive"
	body_kind = "steam"
	health = 2500
	max_fuel = 250
	train_weight = 4.5 // with its three body sections the locomotive weighs 6
	haul = 30
	water = 600
	max_water = 600
	boiler_water = 100
	max_boiler = 100
	steam_time = 240

/obj/structure/trains/locomotive/coal/heavy/ex_act(severity)
	blast_couplings(severity)
	heavy_damage(severity == 1.0 ? 450 : (severity == 2.0 ? 220 : 80))

/obj/structure/trains/locomotive/coal/heavy/attackby(obj/item/W as obj, mob/user as mob)
	if (heavy_weld(W, user))
		return
	return ..()

/obj/structure/trains/locomotive/coal/heavy/examine(mob/user)
	..()
	heavy_examine(user)

/obj/structure/trains/locomotive/heavy_diesel
	name = "heavy diesel locomotive"
	desc = "A diesel locomotive with the cab at the front and walkways along its long hood. It runs on diesel or biodiesel."
	body_kind = "diesel"
	health = 2500
	max_fuel = 300
	train_weight = 3.5 // 5 with its body sections
	haul = 32
	fuel_store = "fuel tank"

/obj/structure/trains/locomotive/heavy_diesel/takes_fuel(obj/item/W)
	if (!istype(W, /obj/item/weapon/reagent_containers) || !W.reagents)
		return FALSE
	return W.reagents.has_reagent("diesel") || W.reagents.has_reagent("biodiesel")

/obj/structure/trains/locomotive/heavy_diesel/ex_act(severity)
	blast_couplings(severity)
	heavy_damage(severity == 1.0 ? 450 : (severity == 2.0 ? 220 : 80))

/obj/structure/trains/locomotive/heavy_diesel/attackby(obj/item/W as obj, mob/user as mob)
	if (heavy_weld(W, user))
		return
	if (!takes_fuel(W))
		return ..()
	var/room = max_fuel - fuel
	if (room < 1)
		to_chat(user, "<span class = 'notice'>The fuel tank is full.</span>")
		return
	var/poured = 0
	for (var/id in list("diesel", "biodiesel"))
		var/amount = min(W.reagents.get_reagent_amount(id), room - poured)
		if (amount > 0)
			W.reagents.remove_reagent(id, amount)
			poured += amount
	fuel += poured
	playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
	user.visible_message("[user] fuels \the [src].", "You pour [round(poured)] units of fuel into \the [src]'s tank.")

/obj/structure/trains/locomotive/heavy_diesel/examine(mob/user)
	..()
	heavy_examine(user)
	diesel_examine(user)

/obj/structure/trains/locomotive/coal/armored/heavy
	name = "heavy armored locomotive"
	body_kind = "armored"
	health = 6000
	max_fuel = 300
	train_weight = 8.5 // 10 with its body sections
	haul = 40
	water = 600
	max_water = 600
	boiler_water = 100
	max_boiler = 100
	steam_time = 240

/obj/structure/trains/locomotive/coal/armored/heavy/examine(mob/user)
	..()
	to_chat(user, has_stations() ? "It is worked from its cab: the driver's stand on the right, the firebox door in the middle, the fireman's side on the left." : "It is driven from its cab.")

// The main-line engine: twice the train of the heavy engine and faster, on a
// bigger fire. Its feed tank is only what the pipes hold; the water and the
// coal ride in the tender behind the cab.
/obj/structure/trains/locomotive/coal/mainline
	name = "main-line steam locomotive"
	body_kind = "mainline"
	health = 4000
	max_fuel = 400
	train_weight = 7.5 // 10 with its five body sections
	haul = 60
	train_speed = 1.4
	max_train_speed = 1.4
	water = 100
	max_water = 100
	boiler_water = 160
	max_boiler = 160
	steam_time = 360

/obj/structure/trains/locomotive/coal/mainline/ex_act(severity)
	blast_couplings(severity)
	heavy_damage(severity == 1.0 ? 450 : (severity == 2.0 ? 220 : 80))

/obj/structure/trains/locomotive/coal/mainline/attackby(obj/item/W as obj, mob/user as mob)
	if (heavy_weld(W, user))
		return
	return ..()

/obj/structure/trains/locomotive/coal/mainline/examine(mob/user)
	..()
	heavy_examine(user)
	if (!engine_tenders().len)
		to_chat(user, "<span class = 'warning'>It has no tender coupled next to it.</span>")

/////////////////////////////////////////////////////////////////////////////
// Kits

/obj/structure/train_car_kit/tender
	name = "tender kit"
	car_kind = "tender"
/obj/structure/train_car_kit/loco_steam
	name = "heavy steam locomotive kit"
	car_kind = "loco_steam"
/obj/structure/train_car_kit/loco_mainline
	name = "main-line steam locomotive kit"
	car_kind = "loco_mainline"
/obj/structure/train_car_kit/loco_diesel
	name = "heavy diesel locomotive kit"
	car_kind = "loco_diesel"
/obj/structure/train_car_kit/loco_dieselmain
	name = "main-line diesel locomotive kit"
	car_kind = "loco_dieselmain"
/obj/structure/train_car_kit/loco_armored
	name = "heavy armored locomotive kit"
	car_kind = "loco_armored"
