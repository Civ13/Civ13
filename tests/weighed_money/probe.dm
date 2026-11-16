// Native weighed money probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/weighed_money.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/weigh_probe/New()
	map = src
/mob/living/human/weigh_probe
	var/obj/item/probe_hand = null
/mob/living/human/weigh_probe/New()
	icon_update = FALSE
	return
/mob/living/human/weigh_probe/get_active_hand()
	return probe_hand
/mob/living/human/weigh_probe/restrained()
	return FALSE
var/weigh_failures = 0
var/weigh_runtime_error = FALSE
/proc/weigh_check(condition, label)
	if (!condition)
		weigh_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	weigh_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/weigh_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		weigh_checks()
	catch(var/exception/e)
		weigh_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = weigh_failures, "runtime_error" = weigh_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/weigh_checks()
	var/list/W = weighed_money_of(new /obj/item/stack/money/silvercoin(locate(5, 5, 1), 12))
	weigh_check(W && W[1] == "silver" && W[2] == 12 && W[3] == 12, "twelve silver coins weigh twelve shekels, worth 12 silver")
	W = weighed_money_of(new /obj/item/stack/money/goldcoin(locate(5, 5, 1), 3))
	weigh_check(W && W[2] == 3 && W[3] == 12, "three gold coins are worth 12 silver")
	W = weighed_money_of(new /obj/item/stack/money/coppercoin(locate(5, 5, 1), 30))
	weigh_check(W && abs(W[3] - 3) < 0.001, "thirty copper coins are worth 3 silver")
	var/obj/item/stack/material/copper/sheet = new(locate(5, 5, 1), 2)
	W = weighed_money_of(sheet)
	weigh_check(W && W[1] == "copper" && W[2] == 20 && abs(W[3] - 2) < 0.001, "two copper sheets weigh twenty shekels, worth 2 silver")
	var/obj/item/stack/material/wood/logs = new(locate(5, 5, 1), 5)
	weigh_check(!weighed_money_of(logs), "wood has no weighed worth")
	weigh_check(findtext(weighed_money_line(sheet), "20 shekels of copper"), "the weighing line names shekels and metal")

	var/obj/structure/barter_mat/M = new(locate(10, 10, 1))
	var/mob/living/human/weigh_probe/A = new(locate(9, 10, 1))
	A.real_name = "Ada"
	A.name = "Ada"
	A.stat = CONSCIOUS
	var/mob/living/human/weigh_probe/B = new(locate(11, 10, 1))
	B.real_name = "Bo"
	B.name = "Bo"
	B.stat = CONSCIOUS
	M.offer(A, new /obj/item/stack/money/silvercoin(locate(9, 10, 1), 5))
	M.offer(A, new /obj/item/stack/material/wood(locate(9, 10, 1), 1))
	M.offer(B, new /obj/item/stack/material/gold(locate(11, 10, 1), 1))
	var/text = M.weighed_offers_text()
	weigh_check(findtext(text, "Ada offers metal worth 5 silver") && findtext(text, "1 other thing"), "the mat weighs the first offer and counts what it cannot price")
	weigh_check(findtext(text, "Bo offers metal worth 40 silver"), "a gold sheet is ten shekels worth 40 silver")
	var/obj/item/weighing_balance/scale = new(locate(9, 10, 1))
	var/before = length(M.contents)
	M.attackby(scale, A)
	weigh_check(length(M.contents) == before && scale.loc != M, "weighing on the mat does not offer the balance")
