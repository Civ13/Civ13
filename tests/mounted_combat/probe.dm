// Native probe for mounted charges, braced spears and shield walls
// (code/modules/1713/mounted_combat.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/mounted_combat/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 14
	maxy = 10
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/mc_probe/New()
	return
// Bare men: no organs, so damage is recorded instead of applied.
/mob/living/human/mc_fixture
	var/taken = 0
	m_intent = "stealth" // no footstep sounds without a movement process
/mob/living/human/mc_fixture/New()
	return
/mob/living/human/mc_fixture/adaptStat(stat, amount)
	return
/mob/living/human/mc_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/mc_fixture/update_icons()
	return
/mob/living/human/mc_fixture/regenerate_icons()
	return
/mob/living/human/mc_fixture/apply_damage(damage = 0, damagetype = BRUTE, def_zone = null, blocked = FALSE, used_weapon = null, sharp = FALSE, edge = FALSE)
	taken += damage
	return TRUE
var/mc_failures = 0
var/mc_runtime_error = FALSE
/proc/mc_check(condition, label)
	if (!condition)
		mc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/mc_probe
		mc_checks()
	catch(var/exception/e)
		mc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mc_failures, "runtime_error" = mc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mc_hold(mob/living/human/H, obj/item/I)
	I.forceMove(H)
	H.r_hand = I
	H.hand = 0

/proc/mc_mount(mob/living/human/R, mob/living/simple_animal/horse/A)
	R.forceMove(A.loc)
	R.riding = TRUE
	R.riding_mob = A
	A.rider = R
	A.ride = TRUE

// Rides R east one tile at a time, n steps, as the movement hook would.
/proc/mc_ride(mob/living/human/R, n)
	for (var/i in 1 to n)
		var/turf/from = get_turf(R)
		var/turf/dest = get_step(from, EAST)
		R.forceMove(dest)
		R.dir = EAST
		if (R.riding_mob)
			R.riding_mob.forceMove(dest)
			R.riding_mob.dir = EAST
		R.ride_charge_step(from)

/proc/mc_checks()
	// A couched spear rides a man down after four straight steps.
	var/mob/living/simple_animal/horse/A = new /mob/living/simple_animal/horse(locate(1, 2, 1))
	var/mob/living/human/mc_fixture/R = new(locate(1, 2, 1))
	mc_mount(R, A)
	mc_hold(R, new /obj/item/weapon/material/spear/iron)
	var/mob/living/human/mc_fixture/T = new(locate(7, 2, 1))
	mc_ride(R, 3)
	mc_check(!T.taken, "no blow before the charge builds")
	mc_ride(R, 2)
	mc_check(T.taken > 0 && T.weakened, "the charge strikes and knocks the man down ([T.taken])")
	mc_check(R.charge_steps == 0, "the blow spends the charge")

	// Turning breaks the charge.
	R.charge_steps = 3
	R.charge_dir = NORTH
	var/turf/from = get_turf(R)
	R.forceMove(get_step(from, EAST))
	R.ride_charge_step(from)
	mc_check(R.charge_steps == 1, "changing direction starts the charge over")

	// No polearm, no couched blow.
	var/mob/living/simple_animal/horse/A2 = new /mob/living/simple_animal/horse(locate(1, 4, 1))
	var/mob/living/human/mc_fixture/R2 = new(locate(1, 4, 1))
	mc_mount(R2, A2)
	var/mob/living/human/mc_fixture/T2 = new(locate(6, 4, 1))
	mc_ride(R2, 4)
	mc_check(!T2.taken, "an unarmed rider doesn't strike")

	// A braced spear facing the charge throws the rider.
	var/mob/living/simple_animal/horse/A3 = new /mob/living/simple_animal/horse(locate(1, 6, 1))
	var/mob/living/human/mc_fixture/R3 = new(locate(1, 6, 1))
	mc_mount(R3, A3)
	mc_hold(R3, new /obj/item/weapon/material/spear/iron)
	var/mob/living/human/mc_fixture/D = new(locate(6, 6, 1))
	D.dir = WEST
	mc_hold(D, new /obj/item/weapon/material/pike)
	D.brace_polearm()
	mc_check(D.braced_until > world.time && D.braced_at == get_turf(D), "Brace sets the footman")
	var/horse_health = A3.health
	mc_ride(R3, 4)
	mc_check(!R3.riding && !R3.riding_mob && !A3.rider, "the rider is thrown off the braced point")
	mc_check(A3.health < horse_health, "the horse is hurt on the point")
	mc_check(!D.taken, "the braced man takes no blow")

	// Facing away, or having stepped off, doesn't count.
	D.braced_until = world.time + 100
	D.dir = EAST
	mc_check(!D.is_braced_against(R), "a man facing away isn't braced against the rider")
	D.dir = WEST
	D.braced_at = locate(1, 1, 1)
	mc_check(!D.is_braced_against(R3), "bracing ends once the man moves")

	// Shield wall: shoulder to shoulder, facing the same way.
	var/mob/living/human/mc_fixture/S1 = new(locate(10, 8, 1))
	var/mob/living/human/mc_fixture/S2 = new(locate(11, 8, 1))
	var/mob/living/human/mc_fixture/S3 = new(locate(12, 8, 1))
	var/mob/living/human/mc_fixture/S4 = new(locate(11, 7, 1))
	for (var/mob/living/human/mc_fixture/S in list(S1, S2, S3, S4))
		S.dir = NORTH
		mc_hold(S, new /obj/item/weapon/shield/roman)
	var/obj/item/weapon/shield/SH = S2.r_hand
	mc_check(SH.shield_wall_bonus(S2) == 30, "two neighbours with shields add the full bonus ([SH.shield_wall_bonus(S2)])")
	mc_check(SH.get_block_chance(S2) == SH.base_block_chance + 30, "the bonus reaches the block chance")
	var/obj/item/weapon/shield/SH1 = S1.r_hand
	mc_check(SH1.shield_wall_bonus(S1) == 15, "one neighbour adds one step")
	var/obj/item/weapon/shield/SH4 = S4.r_hand
	mc_check(SH4.shield_wall_bonus(S4) == 0, "a man behind the line isn't part of the wall")
	S3.dir = SOUTH
	mc_check(SH.shield_wall_bonus(S2) == 15, "a neighbour facing the other way doesn't help")
	// A diagonal wall (issue 6921): facing northeast, the flanks are northwest
	// and southeast; the men north and east stand ahead of the line.
	var/mob/living/human/mc_fixture/DC = new(locate(11, 3, 1))
	var/mob/living/human/mc_fixture/DN = new(locate(11, 4, 1))
	var/mob/living/human/mc_fixture/DE = new(locate(12, 3, 1))
	for (var/mob/living/human/mc_fixture/S in list(DC, DN, DE))
		S.dir = NORTHEAST
		mc_hold(S, new /obj/item/weapon/shield/roman)
	var/obj/item/weapon/shield/DSH = DC.r_hand
	mc_check(DSH.shield_wall_bonus(DC) == 0, "facing northeast, men ahead to the north and east aren't the wall ([DSH.shield_wall_bonus(DC)])")
	var/mob/living/human/mc_fixture/DNW = new(locate(10, 4, 1))
	var/mob/living/human/mc_fixture/DSE = new(locate(12, 2, 1))
	for (var/mob/living/human/mc_fixture/S in list(DNW, DSE))
		S.dir = NORTHEAST
		mc_hold(S, new /obj/item/weapon/shield/roman)
	mc_check(DSH.shield_wall_bonus(DC) == 30, "facing northeast, the northwest and southeast flanks make the wall ([DSH.shield_wall_bonus(DC)])")
