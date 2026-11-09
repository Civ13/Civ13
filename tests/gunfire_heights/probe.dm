// Offline gunfire-on-hills fixture: production projectile code on a 16x8
// plating world with a height file written by the probe. No maps, normal
// startup, clients or saves. Each row is one case; shots run west to east.
/world
	maxx = 16
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating

/obj/map_metadata/gunfire_heights_fixture
	terrain_height_file = "gunfire_heights.txt"

/obj/map_metadata/gunfire_heights_fixture/New()
	map = src

/area/gunfire_heights_roofed
	location = AREA_INSIDE

// Target stand-in: the production human type without the heavy constructor.
/mob/living/human/gunfire_heights_target/New()
	return

/proc/gunfire_heights_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/proc/gunfire_heights_round(mob/firer, x1, x2, y, atom/target = null)
	var/turf/start = locate(x1, y, 1)
	var/obj/item/projectile/bullet/rifle/a762x39/P = new(start)
	P.firer = firer
	P.starting = start
	P.original = target || locate(x2, y, 1)
	P.def_zone = "chest"
	P.no_attack_log = TRUE
	P.penetrating = -1 // no random wall penetration in this fixture
	P.height_plan(start)
	return P

// Runs the shot through x1+1 .. last; returns the first x that stopped it, or 0.
/proc/gunfire_heights_fly(obj/item/projectile/P, x1, last, y)
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
		// North row first: y=8 cliff, 7 flat range, 6 crest, 5 people below, 4 roof, 3 wall, 2 flat, 1 ridge.
		var/list/rows = list("f000000000000000", "0000000000000000", "0012344400000000", "8882100000000000", "8882100000000000",
			"8882100000000000", "0000000000000000", "0000040000000000")
		text2file("civ13-terrain-heights 1\nsize 16 8\nz 1\n[jointext(rows, "\n")]\n", "gunfire_heights.txt")
		new /obj/map_metadata/gunfire_heights_fixture
		gunfire_heights_assert(terrain_height_at(locate(6, 1, 1)) == 4, "Height file not loaded")
		var/mob/living/shooter = new /mob/living(locate(1, 1, 1))
		var/list/notes = list()

		// 1. A ridge between shooter and target stops the shot on the ridge.
		var/stop = gunfire_heights_fly(gunfire_heights_round(shooter, 2, 10, 1), 2, 12, 1)
		gunfire_heights_assert(stop == 6, "Ridge did not stop the shot (stopped at [stop])")
		// Shrapnel ignores heights.
		var/obj/item/projectile/S = gunfire_heights_round(shooter, 2, 10, 1)
		S.is_shrapnel = TRUE
		S.height_plan(S.starting)
		gunfire_heights_assert(isnull(S.height_start), "Shrapnel got a height line")
		notes += "ridge stops at x=[stop]"

		// 2. Flat ground: a wall stops a level shot as before, and nobody is shot over.
		new /turf/wall/rockwall(locate(8, 2, 1))
		stop = gunfire_heights_fly(gunfire_heights_round(shooter, 2, 12, 2), 2, 12, 2)
		gunfire_heights_assert(stop == 8, "Flat wall did not stop the shot (stopped at [stop])")
		var/obj/item/projectile/F = gunfire_heights_round(shooter, 2, 12, 2)
		F.handleTurf(locate(3, 2, 1))
		gunfire_heights_assert(!F.height_passes_over(0.5), "Level shot over flat ground passed over cover")

		// 3. From a hilltop the same wall lower down the slope is shot over.
		new /turf/wall/rockwall(locate(4, 3, 1))
		stop = gunfire_heights_fly(gunfire_heights_round(shooter, 2, 10, 3), 2, 12, 3)
		gunfire_heights_assert(stop != 4, "Shot from the hilltop did not clear the lower wall")
		notes += "hill shot clears the wall, then [stop ? "lands at x=[stop]" : "flies on"]"

		// 4. A roofed tile under the line is passed over with everything in it.
		var/area/gunfire_heights_roofed/roof = new
		roof.contents += locate(4, 4, 1)
		new /turf/wall/rockwall(locate(4, 4, 1))
		roof.contents += locate(4, 4, 1)
		var/obj/item/projectile/R = gunfire_heights_round(shooter, 2, 10, 4)
		gunfire_heights_assert(R.handleTurf(locate(3, 4, 1)) && R.handleTurf(locate(4, 4, 1)) && R.loc == locate(4, 4, 1), "Shot did not pass over the roofed wall")
		// The roofed wall still stops a level shot.
		R = gunfire_heights_round(shooter, 5, 1, 4)
		R.height_start = null
		gunfire_heights_assert(!R.handleTurf(locate(4, 4, 1)), "Roofed wall let a flat shot through")

		// 5. Someone standing well below the line is not hit.
		var/mob/living/bystander = new /mob/living(locate(4, 5, 1))
		bystander.health = 100
		var/obj/item/projectile/B = gunfire_heights_round(shooter, 2, 10, 5)
		gunfire_heights_assert(B.handleTurf(locate(3, 5, 1)) && B.handleTurf(locate(4, 5, 1)) && bystander.health == 100 && !QDELETED(B), "Shot hit a person far below its line")

		// 6. Shooting up a hillside at someone on the crest clears the slope.
		var/mob/living/human/gunfire_heights_target/crest = new(locate(8, 6, 1))
		var/obj/item/projectile/U = gunfire_heights_round(shooter, 2, 8, 6, crest)
		U.p_y = 32 // aim at the part showing over the brow
		U.height_plan(U.starting)
		stop = gunfire_heights_fly(U, 2, 7, 6)
		gunfire_heights_assert(!stop, "Shot up the slope hit the hillside at x=[stop]")

		// 7. Bullet drop: a pistol aimed mid-body falls short at 13 tiles on flat
		// ground; held over (clicked at the top of the sprite) it arrives.
		var/mob/living/human/gunfire_heights_target/far = new(locate(14, 7, 1))
		var/obj/item/projectile/bullet/pistol/D = new(locate(1, 7, 1))
		D.firer = shooter
		D.starting = locate(1, 7, 1)
		D.original = far
		D.penetrating = -1
		D.height_plan(D.starting)
		stop = gunfire_heights_fly(D, 1, 14, 7)
		gunfire_heights_assert(stop && stop <= 14 && !D.height_line, "Pistol shot at mid-body did not fall short at 13 tiles")
		notes += "pistol at 13 tiles aimed mid-body lands at x=[stop]"
		D = new(locate(1, 7, 1))
		D.firer = shooter
		D.starting = locate(1, 7, 1)
		D.original = far
		D.penetrating = -1
		D.p_y = 32
		D.height_plan(D.starting)
		stop = gunfire_heights_fly(D, 1, 13, 7)
		gunfire_heights_assert(!stop, "Held-over pistol shot fell short at x=[stop]")
		gunfire_heights_assert(D.height_enter(locate(14, 7, 1)) == PROJECTILE_HEIGHT_CLEAR && !D.height_buries && !D.height_misses(far), "Held-over pistol shot did not reach the target")
		// A rifle aimed mid-body still reaches the same target.
		var/obj/item/projectile/RF = gunfire_heights_round(shooter, 1, 14, 7, far)
		gunfire_heights_assert(!gunfire_heights_fly(RF, 1, 13, 7) && RF.height_enter(locate(14, 7, 1)) == PROJECTILE_HEIGHT_CLEAR && !RF.height_buries, "Rifle shot fell short at 14 tiles")
		// The same mid-body pistol shot that fell short at 13 tiles lands from a
		// 15-level cliff: the steep arc covers more height across the target's tile.
		var/mob/living/human/gunfire_heights_target/below = new(locate(14, 8, 1))
		var/obj/item/projectile/bullet/pistol/C13 = new(locate(1, 8, 1))
		C13.firer = shooter
		C13.starting = locate(1, 8, 1)
		C13.original = below
		C13.penetrating = -1
		C13.height_plan(C13.starting)
		stop = gunfire_heights_fly(C13, 1, 13, 8)
		gunfire_heights_assert(!stop, "Cliff pistol shot stopped at x=[stop]")
		gunfire_heights_assert(C13.height_enter(locate(14, 8, 1)) == PROJECTILE_HEIGHT_CLEAR && !C13.height_misses(below), "Cliff pistol shot did not reach the target")
		notes += "13-tile pistol: flat lands short, from the cliff reaches"

		// 8. NPC sight: the ridge hides a target from cover/peek checks and
		// from target finding; on flat ground the same pair is seen.
		gunfire_heights_assert(!ai_check_los(locate(2, 1, 1), locate(10, 1, 1)), "NPC saw through the ridge")
		gunfire_heights_assert(ai_check_los(locate(2, 2, 1), locate(7, 2, 1)), "NPC lost sight on flat ground")
		var/mob/living/simple_animal/hostile/wolf/W = new(locate(2, 1, 1))
		W.faction = "gunfire_wolves"
		var/mob/living/simple_animal/hostile/wolf/prey = new(locate(8, 1, 1))
		prey.faction = "gunfire_prey"
		W.stance = HOSTILE_STANCE_IDLE
		gunfire_heights_assert(!W.FindTarget(), "NPC picked a target behind the ridge")
		W.loc = locate(2, 2, 1)
		prey.loc = locate(7, 2, 1)
		W.stance = HOSTILE_STANCE_IDLE
		gunfire_heights_assert(W.FindTarget() == prey, "NPC did not find a target on flat ground")
		notes += "NPC sight blocked by the ridge"

		// 9. Cost of the height work per tile.
		var/obj/item/projectile/C = gunfire_heights_round(shooter, 2, 10, 3)
		var/turf/T = locate(5, 3, 1)
		var/start = world.timeofday
		for (var/i in 1 to 100000)
			C.height_enter(T)
			C.height_passes_over(1)
		var/per_tile = (world.timeofday - start) * 100 / 100000 // ms
		var/no_plan = gunfire_heights_round(shooter, 2, 10, 3)
		var/obj/item/projectile/N = no_plan
		N.height_start = null
		start = world.timeofday
		for (var/i in 1 to 100000)
			N.height_enter(T)
			N.height_passes_over(1)
		var/flat_tile = (world.timeofday - start) * 100 / 100000
		notes += "[per_tile] ms per hill tile, [flat_tile] ms per tile without heights"

		result = "PASS: [jointext(notes, "; ")]"
	catch (var/exception/E)
		result = "FAIL: [E.name]"
	text2file(result, "result.txt")
	shutdown()
