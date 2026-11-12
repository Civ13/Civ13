// The sea chart and harbours (code/modules/naval/craft_chart.dm,
// docs/craft-core.md): a mirror chart per sea level whose tokens follow the
// real ships and mooring posts; the chart read at a helm; a mooring post
// that answers a ship with a ticket, the marked slide alongside, the mooring
// and casting off; owners, guests and a foul berth.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

/proc/naval_checks()
	naval_fixture()
	var/obj/structure/berth/quay/post = new(locate(20, 20, 2))
	naval_check((post in sea_harbours) && post.water_side() == EAST, "a mooring post on the sand finds the water to its east")
	var/obj/structure/berth/quay/inland = new(locate(10, 20, 2))
	naval_check(!inland.water_side() && findtext(inland.status_text(), "no open water"), "a post inland has no water beside it")
	qdel(inland)
	naval_check(!(inland in sea_harbours), "and leaves the harbour list when it goes")

	// ---- Two hulls ----
	for (var/x = 40, x <= 44, x++)
		hull_lay(x, 10)
		hull_lay(x, 11)
	var/obj/structure/hull_tiller/tiller = new(locate(42, 10, 2))
	naval_check(isnull(tiller.commission("Wren", EAST)), "the Wren is commissioned")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	for (var/x = 50, x <= 52, x++)
		hull_lay(x, 12)
	var/obj/structure/hull_tiller/tiller2 = new(locate(51, 12, 2))
	naval_check(isnull(tiller2.commission("Kite", EAST)), "the Kite is commissioned")
	var/datum/craft/K = tiller2.craft
	var/turf/mid = C.centre()
	naval_check(mid.x == 42 && mid.y == 10 && !C.making_way(), "the Wren's middle is 42,10 and she is stopped ([mid.x],[mid.y])")

	// ---- The chart ----
	var/datum/chart/sea/S = sea_chart(2)
	naval_check(S == sea_chart(2) && S.mode == CHART_MODE_MIRROR && S.width == 7 && S.height == 6, "one mirror chart for the level, 7 squares by 6 ([S.width],[S.height])")
	naval_check(S.square_name(1, 1) == "A1" && S.square_name(5, 3) == "E3" && S.square_name(27, 10) == "AA10", "squares are lettered across and numbered up")
	naval_check(S.refresh() == 3 && C.token && C.token.x == 5 && C.token.y == 1 && post.token && post.token.x == 2 && post.token.y == 2, "the chart holds both ships and the harbour where they really are")
	var/text = C.sea_chart_text()
	naval_check(findtext(text, "the Wren lies in square E1 (42, 10)"), "the chart says where she is ([text])")
	naval_check(findtext(text, "Kite, 9 tiles northeast, square F2, bow to the east, stopped"), "her lookout sees the Kite")
	naval_check(findtext(text, "the mooring post at 20, 20, 22 tiles northwest, square B2: she may berth here"), "and the harbour is charted with its answer")
	K.token.dark = TRUE
	text = C.sea_chart_text()
	naval_check(findtext(text, "unknown contact, 9 tiles northeast, square F2.") && !findtext(text, "Kite"), "a ship running dark is seen but not known")
	K.token.dark = FALSE
	C.token.sensor_range = 5
	naval_check(findtext(C.sea_chart_text(), "no other ship within 5 tiles"), "a ship beyond the lookout is not listed")
	C.token.sensor_range = CHART_SENSOR_RANGE

	// ---- Asking for the berth ----
	naval_check(!C.order_dock(post) && findtext(C.last_refusal, "more than 20 tiles off") && !post.reserved, "a berth 22 tiles off is too far to make for ([C.last_refusal])")
	naval_check(B.move_to(30, 10, EAST), "she closes to 12 tiles")
	var/mob/living/human/naval_probe/ann = new(locate(32, 10, 2))
	ann.real_name = "Ann"
	ann.civilization = "Reds"
	var/mob/living/human/naval_probe/bob = new(locate(51, 12, 2))
	bob.real_name = "Bob"
	bob.civilization = "Blues"
	post.owner_party = party_train_party_of(ann)
	post.welcome = BERTH_WELCOME_OWNERS
	naval_check(!C.order_dock(post) && findtext(C.last_refusal, "does not welcome") && !post.reserved && !C.ticket, "a claimed post turns an unregistered ship away ([C.last_refusal])")
	naval_check(findtext(C.sea_chart_text(), "square B2: the berth does not welcome her party"), "and her chart says so")
	C.register = new /datum/craft_register
	C.register.claim(ann)
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(C.order_dock(post) && post.reserved && C.ticket == post.reserved && C.ticket.granted(), "registered to the owners she is given a ticket")
	naval_check(C.docking && C.docking[1] == 21 && C.docking[2] == 18 && C.docking[3] == NORTH && C.path_markers.len == 10, "she will lie along the shore abreast of the post, and the water is marked ([C.path_markers.len])")
	naval_check(!C.sail_tick() && B.origin().x == 30 && C.speed == VESSEL_SPEED_SLOW, "she does not hop while she waits to slide in")
	naval_check(findtext(post.refusal(K), "promised to Wren") && findtext(post.status_text(), "Wren is making for it"), "the berth is promised to her")
	naval_check(!C.order_dock(post) && findtext(C.last_refusal, "already coming about"), "a second order waits for the first")

	// ---- Alongside ----
	naval_check(C.finish_dock(), "she slides in")
	var/turf/O = B.origin()
	naval_check(O.x == 21 && O.y == 18 && B.heading() == NORTH && B.contains(get_turf(tiller)) && B.contains(get_turf(ann)), "she lies at 21,18 with her bow to the north, tiller and sailor aboard ([O.x],[O.y])")
	naval_check(C.berth == post && post.occupant == C && !post.reserved && !C.ticket && !C.docking && !C.turning_to && !C.path_markers.len, "she is moored and the ticket is spent")
	naval_check(C.anchored && C.speed == VESSEL_SPEED_STOP, "all stop, anchor down")
	post.harbour = "Port Ann"
	naval_check(findtext(C.sea_chart_text(), "moored at Port Ann") && findtext(post.status_text(), "The Wren is moored here"), "chart and post both say she is moored at Port Ann")
	naval_check(findtext(K.sea_chart_text(), "Port Ann, ") && findtext(post.refusal(K), "taken by Wren"), "the Kite reads the harbour's name and that it is taken")
	naval_check(!C.order_dock(post) && findtext(C.last_refusal, "already lies there"), "she cannot make for the berth she lies in")

	// ---- A foul berth, guests ----
	var/datum/craft_body/built/KB = K.body
	naval_check(KB.move_to(30, 30, EAST), "the Kite closes")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(C.sail_tick() && B.origin().y == 20 && !C.berth && !post.occupant, "a moored ship that sails has cast off")
	naval_check(!K.order_dock(post) && findtext(K.last_refusal, "does not welcome"), "the Kite is nobody's guest")
	K.register = new /datum/craft_register
	K.register.claim(bob)
	post.welcome = BERTH_WELCOME_GUESTS
	var/list/found = post.guest_candidates()
	naval_check(found.len == 1 && found["Blues (the Kite)"] == party_train_party_of(bob), "her owners can be made guests while she lies in reach")
	naval_check(!K.order_dock(post), "until they are she is turned away")
	post.guests |= party_train_party_of(bob)
	naval_check(!K.order_dock(post) && findtext(K.last_refusal, "the berth is foul") && !post.reserved && !K.ticket && !K.docking, "a guest is welcome, but the Wren lies across the berth ([K.last_refusal])")
	naval_check(C.sail_tick() && C.sail_tick() && B.origin().y == 24, "the Wren stands clear")
	naval_check(K.order_dock(post) && K.finish_dock() && K.berth == post && KB.origin().x == 21 && KB.origin().y == 19, "and the Kite berths ([KB.origin().x],[KB.origin().y])")

	// ---- Already alongside (after a restart) ----
	K.cast_off()
	var/redock = K.order_dock(post)
	var/refusal_was = K.last_refusal
	naval_check(!K.berth && redock && K.finish_dock() && K.berth == post && KB.origin().y == 19, "a ship already lying alongside is made fast where she lies ([redock], [refusal_was], [KB.origin().y], [KB.heading()])")

	// ---- Gone ----
	qdel(post)
	naval_check(!K.berth && !sea_harbours.len && S.refresh() == 2, "with the post gone she is moored to nothing and the chart shows two ships")
	tiller2.decommission()
	naval_check(S.refresh() == 1 && !findtext(C.sea_chart_text(), "Kite"), "a struck hull leaves the chart")

	// ---- A slipway ship berths the same way ----
	var/datum/vessel/schooner/V = new
	naval_check(V.place(30, 40, 2, EAST), "a schooner is laid on the sea ([V.last_refusal])")
	var/datum/craft/P = craft_at(locate(32, 42, 2))
	var/obj/structure/berth/quay/post2 = new(locate(20, 45, 2))
	mid = P.centre()
	naval_check(mid.x == 36 && mid.y == 42 && findtext(P.sea_chart_text(), "the mooring post at 20, 45, 16 tiles"), "the schooner charts the new post 16 tiles off ([mid.x],[mid.y])")
	V.set_anchor(FALSE)
	V.set_speed(VESSEL_SPEED_SLOW)
	naval_check(P.order_dock(post2) && V.turning_to == NORTH && P.path_markers.len > 0 && !V.sail_hop() && V.ox == 30, "she is given the berth, her water is marked and she holds her hops")
	naval_check(P.finish_dock() && V.ox == 21 && V.oy == 39 && V.dir == NORTH && !V.turning_to, "she slides in along the shore, bow to the north ([V.ox],[V.oy])")
	naval_check(P.berth == post2 && post2.occupant == P && V.anchored && V.speed == VESSEL_SPEED_STOP && !P.making_way(), "and is made fast")
	V.set_anchor(FALSE)
	V.set_speed(VESSEL_SPEED_SLOW)
	naval_check(P.making_way() && V.sail_hop() && !P.berth && !post2.occupant, "sailing on, she has cast off")

	// ---- Wiring rides a slipway ship too (craft/rigid_move.dm) ----
	var/list/deck = list()
	for (var/turf/T in V.cells())
		if (T.z == 2)
			deck += T
	var/obj/structure/cable/c1 = new(deck[1])
	var/obj/structure/cable/c2 = new(deck[2])
	var/obj/structure/cable/ashore = new(locate(10, 50, 2))
	c1.connections = list(c2, ashore)
	c2.connections = list(c1)
	ashore.connections = list(c1)
	var/y_was = c1.y
	naval_check(V.sail_hop() && c1.y > y_was && (c2 in c1.connections) && (c1 in c2.connections), "cables on her deck hop with her and stay joined ([c1.y])")
	naval_check(!(ashore in c1.connections) && !(c1 in ashore.connections) && isnull(craft_rigid_cargo), "and the cable to the shore has parted")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
