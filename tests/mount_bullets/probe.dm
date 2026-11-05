// Offline mount gunfire fixture: production projectile and animal code on an
// 8x8 plating world. No maps, normal startup, clients or saves.
/world
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating

/obj/map_metadata/mount_bullets_fixture/New()
	map = src

// Rider stand-in: the production human type without the heavy constructor.
/mob/living/human/mount_bullets_rider/New()
	return

/proc/mount_bullets_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/proc/mount_bullets_round(mob/firer, obj/item/weapon/gun/projectile/gun, turf/start)
	var/obj/item/projectile/bullet/rifle/a762x39/P = new(start)
	P.firer = firer
	P.firedfrom = gun
	P.shot_from = gun
	P.starting = start
	P.def_zone = "chest"
	P.no_attack_log = TRUE
	return P

/world/OpenPort(port)
	if (port == "none")
		return ..(port)
	return FALSE

/world/New()
	OpenPort("none")
	sleep(1)
	var/result = "FAIL: probe did not finish"
	try
		new /obj/map_metadata/mount_bullets_fixture
		var/turf/site = locate(3,3,1)
		var/obj/item/weapon/gun/projectile/gun = new(locate(1,1,1))

		// 1. A rifle shot must hurt a horse and a handful must kill it.
		var/mob/living/simple_animal/horse/H = new(site)
		H.stop_automated_movement = TRUE
		mount_bullets_assert(H.health == H.maxHealth, "Horse health cap mismatch")
		var/mob/living/shooter = new /mob/living(locate(1,3,1))
		var/hits = 0
		while (H.stat != DEAD && hits < 20)
			var/before = H.health
			var/obj/item/projectile/P = mount_bullets_round(shooter, gun, locate(1,3,1))
			P.attack_mob(H, 2)
			mount_bullets_assert(H.health < before, "Rifle round did no damage to the horse")
			hits++
			if (H.health <= 0)
				H.death()
		mount_bullets_assert(H.stat == DEAD, "Horse survived [hits] 7.62x39 rounds")
		mount_bullets_assert(hits <= 5, "Horse took [hits] 7.62x39 rounds to kill")

		// 2. A rider's shot leaves from the mount's tile and must not be eaten by it.
		var/mob/living/simple_animal/horse/M = new(site)
		M.stop_automated_movement = TRUE
		var/mob/living/human/mount_bullets_rider/R = new(site)
		M.ride = TRUE
		M.rider = R
		R.riding = TRUE
		R.riding_mob = M
		var/mount_health = M.health
		var/obj/item/projectile/RP = mount_bullets_round(R, gun, site)
		var/passed = RP.handleTurf(site)
		mount_bullets_assert(M.health == mount_health, "Rider's shot damaged its own mount")
		mount_bullets_assert(passed && !QDELETED(RP) && RP.loc == site, "Rider's own mount stopped the shot")

		result = "PASS: [hits] rounds killed the horse; rider shot passed its mount"
	catch (var/exception/E)
		result = "FAIL: [E.name]"
	text2file(result, "result.txt")
	shutdown()
