// Native probe: a dropped gun stops its burst, a chambered shell counts for point-blank
// fire, and machine-gun hits on a target train the machinegun skill (#6309, #6329, #6331).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/gun_followthrough/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/gf_probe/New()
	return

var/gf_failures = 0
var/gf_runtime_error = FALSE
/proc/gf_check(condition, label)
	if (!condition)
		gf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	gf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/gf_probe
		gf_checks()
	catch(var/exception/e)
		gf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = gf_failures, "runtime_error" = gf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/item/weapon/gun/projectile/gf_burst
	var/shots = 0
/obj/item/weapon/gun/projectile/gf_burst/consume_next_projectile(var/check = FALSE)
	shots++
	if (shots == 1 && ismob(loc))
		var/mob/M = loc
		forceMove(get_turf(M)) // the shooter is disarmed after the first round
	return new /obj/item/projectile(get_turf(src))
/obj/item/weapon/gun/projectile/gf_burst/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params = null)
	qdel(projectile)
	return TRUE

/obj/item/weapon/gun/projectile/gf_held
	var/shots = 0
/obj/item/weapon/gun/projectile/gf_held/consume_next_projectile(var/check = FALSE)
	shots++
	return new /obj/item/projectile(get_turf(src))
/obj/item/weapon/gun/projectile/gf_held/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params = null)
	qdel(projectile)
	return TRUE

/proc/gf_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/mob/living/human/target = new(locate(8, 5, 1))

	var/obj/item/weapon/gun/projectile/gf_burst/B = new(user)
	B.Fire(target, user, force = TRUE, forceburst = 3)
	gf_check(B.shots == 1, "a burst stops once the gun leaves the shooter's hands (fired [B.shots])")

	var/obj/item/weapon/gun/projectile/gf_held/K = new(user)
	K.Fire(target, user, force = TRUE, forceburst = 3)
	gf_check(K.shots == 3, "a gun kept in hand fires its whole burst (fired [K.shots])")

	var/obj/item/weapon/gun/projectile/shotgun/pump/remington870/P = new(user)
	P.loaded.Cut()
	if (P.ammo_magazine)
		P.ammo_magazine.stored_ammo.Cut()
	P.chambered = new /obj/item/ammo_casing/shotgun/buckshot(P)
	gf_check(P.has_next_projectile(), "a pumped shell in the chamber counts as the next projectile")
	P.chambered.expend()
	gf_check(!P.has_next_projectile(), "a spent chambered casing does not")

	var/obj/structure/practice_dummy/target/D = new(locate(9, 9, 1))
	D.ranged = TRUE
	var/obj/item/weapon/gun/projectile/MG = new(locate(9, 8, 1))
	MG.gun_type = GUN_TYPE_MG
	var/before = user.stats["machinegun"][1]
	for (var/i in 1 to 30)
		D.health = 1000
		var/obj/item/projectile/proj = new(locate(9, 8, 1))
		proj.firer = user
		proj.firedfrom = MG
		D.bullet_act(proj)
		qdel(proj)
	gf_check(user.stats["machinegun"][1] > before, "machine-gun hits on a target train the machinegun skill ([before] -> [user.stats["machinegun"][1]])")
