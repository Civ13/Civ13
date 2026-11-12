// ============================================================
// Built turrets (docs/craft-core.md): a traversing turret for a hand-built tank
// ------------------------------------------------------------
// A works-built tank carries a turret (siege/turret.dm) that holds its gun
// and its crew seats and turns on its own. A hand-built tank could only
// carry a bare tank cannon. The built turret is the same turret, made by a
// player and empty until it is fitted: assembling the vehicle (or "Fit new
// parts") takes the tank cannon and the gunner's, loader's and commander's
// seats standing on the turret's tile into it. Taking the vehicle apart
// sets them down again.
//
// It reuses the turret pictures the game already has; the builder picks one
// from the axis menu.
// ============================================================

/obj/structure/turret/built
	name = "tank turret"
	desc = "An empty turret ring and shell. Stand it on a frame of a vehicle with a tank cannon and the crew's seats on the same tile; they are fitted into it when the vehicle is assembled."
	turret_icon = "tank_turret"
	turret_color = "#585A5C"

/obj/structure/turret/built/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE(fitting_text()))

// What the turret holds and what it still lacks, in words.
/obj/structure/turret/built/proc/fitting_text()
	var/list/has = list()
	for (var/obj/O in weapons)
		has += "\a [O.name]"
	if (gunner_seat)
		has += "a gunner's seat"
	if (loader_seat)
		has += "a loader's seat"
	if (commander_seat)
		has += "a commander's seat"
	var/list/lacks = lacking()
	. = has.len ? "It is fitted with [english_list(has)]." : "Nothing is fitted in it yet."
	if (lacks.len)
		. += " To fire it still needs [english_list(lacks)] on its tile."

// What the turret needs before it can fire.
/obj/structure/turret/built/proc/lacking()
	. = list()
	if (!weapons.len)
		. += "a tank cannon"
	if (!gunner_seat)
		. += "a gunner's seat"

// The turret pictures a builder may pick in this age: name -> icon.
/proc/built_turret_styles()
	. = list("plain" = "tank_turret", "round" = "round_tank_turret")
	var/age = map ? map.ordinal_age : 0
	var/list/more = list()
	if (age == 6)
		more = list("pziv", "jap", "kv1", "t34", "t3485", "is3")
	else if (age == 7)
		more = list("is3", "t3485", "t55", "t62a", "t72", "t72m1", "t72b3", "pt76", "m48", "m48a3", "m60a3")
	else if (age >= 8)
		more = list("t62m", "t62mv", "t64bv", "t64bm", "t72m1", "t72b3", "t90a", "challenger2", "2a6")
	for (var/style in more)
		.[uppertext(style)] = "[style]_turret"

// Takes the gun and the seats standing on the turret's tile into it.
// Returns how many things were fitted.
/obj/structure/turret/built/proc/fit()
	. = 0
	var/turf/T = get_turf(src)
	if (!T)
		return
	for (var/obj/structure/cannon/modern/tank/C in T)
		C.forceMove(src)
		weapons += C
		.++
	if (!gunner_seat)
		for (var/obj/structure/bed/chair/gunner/G in T)
			if (G.turret || G.buckled_mob)
				continue
			gunner_seat = G
			G.anchored = TRUE
			G.setup(src)
			.++
			break
	if (!loader_seat)
		for (var/obj/structure/bed/chair/loader/L in T)
			if (L.turret || L.buckled_mob)
				continue
			loader_seat = L
			L.anchored = TRUE
			L.setup(src)
			.++
			break
	if (!commander_seat)
		for (var/obj/structure/bed/chair/commander/K in T)
			if (K.turret || K.buckled_mob)
				continue
			commander_seat = K
			K.anchored = TRUE
			K.setup(src)
			.++
			break
	if (.)
		update_icon()

// Sets the gun and the seats down beside the turret again, loose.
/obj/structure/turret/built/proc/release()
	var/turf/T = get_turf(src)
	is_firing = FALSE
	for (var/obj/O in weapons)
		if (T)
			O.forceMove(T)
	weapons = list()
	selected_weapon = 1
	if (gunner_seat)
		gunner_seat.turret = null
		if (gunner_seat.controls)
			gunner_seat.controls.turret = null
		gunner_seat.anchored = FALSE
		gunner_seat.pixel_x = 0
		gunner_seat.pixel_y = 0
		gunner_seat = null
	if (loader_seat)
		loader_seat.turret = null
		loader_seat.anchored = FALSE
		loader_seat.pixel_x = 0
		loader_seat.pixel_y = 0
		loader_seat = null
	if (commander_seat)
		var/obj/structure/bed/chair/commander/K = commander_seat
		if (istype(K))
			K.turret = null
			K.anchored = FALSE
		commander_seat = null
	gunner = null
	loader = null
	commander = null

// The built turrets standing on this vehicle's frames.
/obj/structure/vehicleparts/axis/proc/built_turrets()
	. = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		for (var/obj/structure/turret/built/B in get_turf(F))
			. += B
