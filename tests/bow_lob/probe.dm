// Offline lobbed-arrow fixture: production projectile and bow code on a 16x6
// plating world with a height file written by the probe. No maps, normal
// startup, clients or saves. Each row is one case; shots run west to east.
/world
	maxx = 16
	maxy = 6
	maxz = 1
	turf = /turf/floor/plating

/obj/map_metadata/bow_lob_fixture
	terrain_height_file = "bow_lob.txt"

/obj/map_metadata/bow_lob_fixture/New()
	map = src

/area/bow_lob_roofed
	location = AREA_INSIDE

// Counts arrow hits without the damage code.
/mob/living/bow_lob_dummy
	var/hits = 0
	var/last_zone = null

/mob/living/bow_lob_dummy/bullet_act(obj/item/projectile/P, def_zone)
	hits++
	last_zone = def_zone
	return

/proc/bow_lob_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/proc/bow_lob_arrow(mob/firer, obj/item/weapon/gun/bow, x1, y, atom/target, lob = TRUE, spread = 0)
	var/turf/start = locate(x1, y, 1)
	var/obj/item/projectile/arrow/arrow/P = new(start)
	P.firer = firer
	P.firedfrom = bow
	P.starting = start
	P.original = target
	P.def_zone = "chest"
	P.no_attack_log = TRUE
	P.lob_hit_chance = 100
	if (lob)
		P.lob_plan(target, spread)
	else
		P.height_plan(start)
	return P

// Runs the arrow through x1+1 .. last; returns the first x that stopped it, or 0.
/proc/bow_lob_fly(obj/item/projectile/P, x1, last, y)
	for (var/x in x1 + 1 to last)
		if (!P.handleTurf(locate(x, y, 1)) || QDELETED(P) || !P.loc)
			return x
	return 0

/world/OpenPort(port)
	if (port == "none")
		return ..(port)
	return FALSE

/world/New()
	OpenPort("none")
	sleep(1)
	var/result = "FAIL: probe did not finish"
	try
		// North row first: y=6 scatter, 5 roof, 4 bystander, 3 ridge, 2 wall, 1 spare.
		var/list/rows = list("0000000000000000", "0000000000000000", "0000000000000000",
			"000300a000000000", "0000000000000000", "0000000000000000")
		text2file("civ13-terrain-heights 1\nsize 16 6\nz 1\n[jointext(rows, "\n")]\n", "bow_lob.txt")
		new /obj/map_metadata/bow_lob_fixture
		bow_lob_assert(terrain_height_at(locate(7, 3, 1)) == 10, "Height file not loaded")
		var/mob/living/archer = new /mob/living(locate(1, 1, 1))
		var/obj/item/weapon/gun/projectile/bow/longbow/bow = new(locate(1, 1, 1))
		var/list/notes = list()

		// 1. A wall between archer and target: the direct arrow stops on it,
		// the lobbed arrow clears it and comes down on the target.
		new /turf/wall/rockwall(locate(6, 2, 1))
		var/mob/living/bow_lob_dummy/walled = new(locate(10, 2, 1))
		var/stop = bow_lob_fly(bow_lob_arrow(archer, bow, 2, 2, walled, FALSE), 2, 12, 2)
		bow_lob_assert(stop == 6 && !walled.hits, "Direct arrow was not stopped by the wall (stopped at [stop])")
		stop = bow_lob_fly(bow_lob_arrow(archer, bow, 2, 2, walled), 2, 12, 2)
		bow_lob_assert(stop == 10 && walled.hits == 1, "Lob did not clear the wall (stopped at [stop], hits [walled.hits])")
		notes += "direct stops at the wall, lob lands on the target (hit [walled.last_zone])"

		// 2. A bystander under the arc is flown over; the target is hit.
		var/mob/living/bow_lob_dummy/bystander = new(locate(5, 4, 1))
		var/mob/living/bow_lob_dummy/aimed = new(locate(9, 4, 1))
		stop = bow_lob_fly(bow_lob_arrow(archer, bow, 2, 4, aimed), 2, 12, 4)
		bow_lob_assert(stop == 9 && !bystander.hits && aimed.hits == 1, "Lob over a bystander went wrong (stopped at [stop], bystander [bystander.hits], aimed [aimed.hits])")

		// 3. A low rise is passed, a ridge taller than the arc stops it.
		var/obj/item/projectile/R = bow_lob_arrow(archer, bow, 2, 3, locate(12, 3, 1))
		stop = bow_lob_fly(R, 2, 14, 3)
		bow_lob_assert(stop == 7, "Ridge did not stop the lob (stopped at [stop])")
		notes += "ridge 10 high stops a 10-tile lob at x=[stop], the 3-high rise does not"

		// 4. A roofed landing tile takes the arrow on the roof.
		var/area/bow_lob_roofed/roof = new
		roof.contents += locate(8, 5, 1)
		var/mob/living/bow_lob_dummy/indoors = new(locate(8, 5, 1))
		stop = bow_lob_fly(bow_lob_arrow(archer, bow, 2, 5, indoors), 2, 12, 5)
		bow_lob_assert(stop == 8 && !indoors.hits, "Lob hit someone under a roof (stopped at [stop])")

		// 5. Scatter grows with distance; a short steady lob lands on or next to the aim.
		var/near = 0
		var/far = 0
		var/obj/item/projectile/S = bow_lob_arrow(archer, bow, 1, 6, locate(4, 6, 1))
		for (var/i in 1 to 300)
			S.lob_plan(locate(4, 6, 1), lob_scatter(3, 0))
			near += abs(S.lob_landing.x - 4)
			S.lob_plan(locate(14, 6, 1), lob_scatter(13, 0))
			far += abs(S.lob_landing.x - 14)
		near /= 300
		far /= 300
		bow_lob_assert(near < 0.5 && far > near * 2, "Scatter did not grow with distance (near [near], far [far])")
		notes += "mean x scatter [round(near, 0.01)] tiles at 3, [round(far, 0.01)] at 13"

		// 6. Flight time: the arrow waits for its flight time between tiles.
		var/obj/item/projectile/T = bow_lob_arrow(archer, bow, 2, 1, locate(12, 1, 1))
		T.permutated += locate(2, 1, 1)
		T.permutated += locate(3, 1, 1)
		bow_lob_assert(T.lob_flight_time >= 8 && !T.lob_ready(), "Lob flew without waiting ([T.lob_flight_time] ds)")
		T.lob_launch_time = world.time - T.lob_flight_time
		bow_lob_assert(T.lob_ready(), "Lob never became ready")
		notes += "10-tile lob takes [T.lob_flight_time / 10] s"

		// 7. The bow toggles; crossbows and slings stay direct.
		bow.toggle_lob(null)
		bow_lob_assert(bow.lob_mode, "Bow did not switch to lobbed")
		bow.toggle_lob(null)
		bow_lob_assert(!bow.lob_mode, "Bow did not switch back to direct")
		var/obj/item/weapon/gun/projectile/bow/crossbow/C = new(locate(1, 1, 1))
		C.toggle_lob(null)
		bow_lob_assert(!C.lob_mode && !(/obj/item/weapon/gun/projectile/bow/verb/toggle_arc in C.verbs), "Crossbow can lob")

		result = "PASS: [jointext(notes, "; ")]"
	catch (var/exception/E)
		result = "FAIL: [E.name]"
	text2file(result, "result.txt")
	shutdown()
