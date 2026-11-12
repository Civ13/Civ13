// The craft core (code/modules/craft/, docs/craft-core.md): a turf-built
// vessel is a craft through a template body that forwards to it; moves and
// turns made through the body reach the craft's hooks; drives add up to a
// push per tile of hull; a register decides who may steer; berths answer a
// docking request with a ticket; charts hold tokens, sites and hazards; a
// plane pool hands out levels.
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

// A craft that remembers what its body told it.
/datum/craft/probe
	var/hops = 0
	var/last_angle = null
/datum/craft/probe/on_hop(turf/old_origin)
	..()
	hops++
/datum/craft/probe/on_turn(angle)
	last_angle = angle

/datum/craft_drive/probe_sail
	name = "sail"
	thrust = 31
/datum/craft_drive/probe_engine
	name = "engine"
	thrust = 93
	var/tank = 0
/datum/craft_drive/probe_engine/fuel_left()
	return tank
/datum/craft_drive/probe_engine/fuel_capacity()
	return 100

// Something with a facing, and something that refuses to turn.
/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_compass
	name = "probe compass"
	anchored = TRUE
/obj/structure/probe_compass/craft_turned(datum/craft/C, angle)
	return

/datum/chart/probe
	mode = CHART_MODE_MIRROR
	width = 70
	height = 60
/datum/chart/probe/chart_position(turf/T)
	return T ? list(T.x, T.y) : null

/proc/naval_checks()
	naval_fixture()

	// ---- A vessel is a craft through a template body ----
	var/datum/vessel/schooner/S = new
	naval_check(S.place(30, 20, 2, EAST), "the schooner is laid on the sea ([S.last_refusal])")
	naval_check(!crafts.len, "laying a vessel down makes no craft until one is asked for")
	var/datum/craft/C = craft_at(locate(32, 22, 2))
	naval_check(C && crafts.len == 1 && craft_at(locate(40, 22, 2)) == C && craft_of_vessel(S) == C, "the deck answers with one craft, the same from every tile")
	naval_check(!craft_at(locate(60, 50, 2)) && !craft_at(locate(29, 22, 2)), "open sea beside her is no craft")
	var/datum/craft_body/template/B = C.body
	naval_check(istype(B) && B.vessel == S && B.craft == C && C.name == "sailing schooner", "her body is a template body around the vessel and gives the craft its name")
	naval_check(B.placed() && B.length_tiles() == 14 && B.beam_tiles() == 5 && B.tile_count() == 62 && C.mass() == 62, "the body reports 14 by 5 and 62 tiles of hull ([B.tile_count()])")
	var/turf/O = B.origin()
	naval_check(O && O.x == 30 && O.y == 20 && O.z == 2 && B.heading() == EAST, "origin and heading are the vessel's")
	naval_check(B.contains(locate(32, 22, 2)) && !B.contains(locate(30, 20, 2)), "contains() follows the hull shape, not the box")
	var/list/aboard = B.aboard()
	naval_check((locate(/obj/structure/vessel_helm) in aboard) && (locate(/obj/structure/vessel_mast) in aboard), "the helm and masts are aboard")

	// ---- Moving through the body moves the vessel and tells the craft ----
	qdel(C)
	naval_check(!crafts.len, "a deleted craft leaves the list")
	var/datum/craft/probe/P = new(new /datum/craft_body/template(S))
	B = P.body
	naval_check(craft_at(locate(32, 22, 2)) == P && crafts.len == 1, "a craft made around the vessel is the one the deck answers with")
	var/obj/item/weapon/reagent_containers/glass/bucket/bucket = new(locate(34, 22, 2))
	naval_check(B.can_move_to(34, 20, EAST) && S.ox == 30, "can_move_to() checks a move and writes nothing")
	naval_check(B.move_to(34, 20, EAST) && S.ox == 34 && P.hops == 1 && isnull(P.last_angle), "move_to() hops the vessel four tiles and calls on_hop() once")
	naval_check(bucket.x == 38 && bucket.y == 22, "cargo rides the hop ([bucket.x],[bucket.y])")
	naval_check(!B.can_move_to(65, 20, EAST) && findtext(B.last_refusal, "edge of the world"), "a move off the map is refused with the vessel's reason ([B.last_refusal])")
	naval_check(!B.move_to(65, 20, EAST) && S.ox == 34 && P.hops == 1, "a refused move leaves her where she is and calls nothing")
	// Things aboard: a gun over the port rail, a compass that never turns, a
	// bucket set down off-centre and a sailor looking aft.
	var/obj/structure/probe_gun/gun = new(locate(39, 22, 2))
	gun.dir = NORTH
	var/obj/structure/probe_compass/compass = new(locate(39, 22, 2))
	compass.dir = NORTH
	bucket.pixel_x = 8
	bucket.pixel_y = 2
	var/mob/living/human/naval_probe/sailor = new(locate(40, 22, 2))
	sailor.dir = WEST
	naval_check(S.relocate(35, 20, EAST) && P.hops == 2 && gun.dir == NORTH && bucket.pixel_x == 8 && sailor.dir == WEST, "a straight hop made by the vessel itself tells the craft and turns nothing")
	naval_check(S.relocate(34, 20, EAST) && P.hops == 3, "and back")
	P.hops = 1
	naval_check(B.turn_to(NORTH) && S.dir == NORTH && B.heading() == NORTH && P.hops == 2 && P.last_angle == 90, "coming about from east to north is a quarter turn to the left ([P.last_angle])")
	naval_check(gun.dir == WEST && S.contains(get_turf(gun)), "the gun over the port rail still points over the port rail ([dir2text(gun.dir)])")
	naval_check(compass.dir == NORTH, "a thing that overrides craft_turned() keeps its own facing")
	naval_check(bucket.pixel_x == -2 && bucket.pixel_y == 8, "the bucket keeps its place on its plank ([bucket.pixel_x],[bucket.pixel_y])")
	naval_check(sailor.dir == SOUTH, "the sailor looking aft still looks aft ([dir2text(sailor.dir)])")
	naval_check(B.turn_to(NORTH) && P.hops == 2, "turning to the heading she already has does nothing")
	naval_check(B.turn_to(EAST) && P.last_angle == -90, "back to east is a quarter turn to the right ([P.last_angle])")
	naval_check(gun.dir == NORTH && bucket.pixel_x == 8 && bucket.pixel_y == 2 && sailor.dir == WEST, "and all of it comes back with her")
	naval_check(S.turn_to(WEST) && gun.dir == SOUTH && bucket.pixel_x == -8 && bucket.pixel_y == -2 && sailor.dir == EAST && P.last_angle == 180, "going about by the wheel turns everything half a circle ([P.last_angle])")
	naval_check(S.turn_to(EAST) && gun.dir == NORTH, "and round again")
	qdel(gun)
	qdel(compass)
	qdel(sailor)
	naval_check(craft_turn_angle(NORTH, SOUTH) == 180 && craft_turn_angle(SOUTH, NORTH) == 180 && craft_turn_angle(NORTH, WEST) == 90 && craft_turn_angle(WEST, NORTH) == -90 && craft_turn_angle(SOUTH, EAST) == 90 && craft_turn_angle(EAST, EAST) == 0, "turn angles are the ones turn() takes")

	// ---- Drives ----
	naval_check(P.thrust() == 0 && P.thrust_per_tile() == 0, "a craft with no drive has no push")
	var/datum/craft_drive/probe_sail/sail = new
	var/datum/craft_drive/probe_engine/engine = new
	naval_check(P.add_drive(sail) && !P.add_drive(sail) && P.add_drive(engine) && P.drives.len == 2, "drives are fitted once each")
	naval_check(P.thrust() == 31 && P.thrust_per_tile() == 0.5, "a dry engine gives nothing: the sail pushes 31 over 62 tiles")
	engine.tank = 40
	naval_check(P.thrust() == 124 && P.thrust_per_tile() == 2, "with fuel both push: 124 over 62 tiles")
	sail.enabled = FALSE
	naval_check(P.thrust() == 93, "a drive switched off gives nothing")
	qdel(sail)
	naval_check(P.drives.len == 1 && P.remove_drive(engine) && !P.drives.len && !engine.craft, "drives come off again")

	// ---- The register ----
	var/mob/living/human/naval_probe/ann = new(locate(36, 22, 2))
	ann.real_name = "Ann"
	var/mob/living/human/naval_probe/bob = new(locate(37, 22, 2))
	bob.real_name = "Bob"
	naval_check(P.may_steer(ann) && isnull(P.party()), "a craft nobody registered is open to anyone")
	var/datum/craft_register/R = new
	P.register = R
	naval_check(P.may_steer(ann), "a register with no party guards nothing")
	R.name = "Gull"
	R.party = party_train_faction_party("Reds")
	naval_check(P.party() == R.party && !P.may_steer(ann) && !R.is_crew(ann), "once a party owns her a stranger may not steer")
	ann.civilization = "Reds"
	naval_check(R.is_owner(ann) && P.may_steer(ann) && R.is_crew(ann), "a member of the owning party may")
	naval_check(!R.ask_to_join(bob) && !R.requests.len, "a closed register takes nobody")
	R.join_mode = CRAFT_JOIN_ASK
	naval_check(R.ask_to_join(bob) && ("Bob" in R.requests) && !R.is_crew(bob), "an asking register notes the request")
	naval_check(R.set_role("Bob", CRAFT_ROLE_HAND) && R.is_crew(bob) && !R.requests.len && !P.may_steer(bob), "a hand is crew but may not steer")
	R.set_role("Bob", CRAFT_ROLE_HELMSMAN)
	naval_check(P.may_steer(bob) && R.role_of(bob) == CRAFT_ROLE_HELMSMAN, "a helmsman may")
	R.memo = "Fresh water at the north quay."
	var/datum/craft_register/R2 = craft_register_restore(R.register_state())
	naval_check(R2 && R2.name == "Gull" && R2.party == R.party && R2.crew["Bob"] == CRAFT_ROLE_HELMSMAN && R2.join_mode == CRAFT_JOIN_ASK && R2.memo == R.memo, "the register survives a trip through its saved text")
	naval_check(R.bar("Bob") && !R.is_crew(bob) && !P.may_steer(bob) && !R.ask_to_join(bob), "a barred character is off the crew and cannot ask again")
	R.join_mode = CRAFT_JOIN_OPEN
	R.barred.Cut()
	naval_check(R.ask_to_join(bob) && R.role_of(bob) == CRAFT_ROLE_HAND, "an open register signs anyone on as a hand")
	naval_check(!R.owners_online(), "nobody is online in the fixture, so the raid rule says no")
	naval_check(isnull(craft_register_restore("")) && isnull(craft_register_restore("not json")), "unusable saved text gives no register")

	// ---- Berths and tickets ----
	var/obj/structure/berth/small = new(locate(25, 40, 2))
	small.berth_length = 16
	small.berth_beam = 6
	var/obj/structure/berth/big = new(locate(25, 50, 2))
	big.berth_length = 24
	big.berth_beam = 8
	var/datum/vessel/freighter/F = new
	naval_check(F.place(30, 5, 2, EAST), "a freighter is laid down ([F.last_refusal])")
	var/datum/craft/FC = craft_of_vessel(F)
	naval_check(berth_best_fit(list(big, small), P) == small && berth_best_fit(list(big, small), FC) == big, "a harbour gives the schooner the small berth and the freighter the big one")
	var/refusal = small.refusal(FC)
	naval_check(refusal && findtext(refusal, "too big"), "the small berth refuses the freighter ([refusal])")
	var/datum/berth_ticket/T = small.request(P)
	naval_check(T.granted() && small.reserved == T && P.ticket == T, "the schooner is given a ticket that holds the berth")
	var/datum/berth_ticket/T2 = big.request(P)
	naval_check(!T2.granted() && findtext(T2.refusal, "another berth") && !big.reserved, "she cannot hold two berths at once ([T2.refusal])")
	small.berth_length = 24
	small.berth_beam = 8
	var/datum/berth_ticket/T3 = small.request(FC)
	naval_check(!T3.granted() && findtext(T3.refusal, "promised"), "a promised berth refuses another craft ([T3.refusal])")
	naval_check(T.complete() && small.occupant == P && P.berth == small && !small.reserved && !P.ticket, "completing the ticket berths her")
	T3 = small.request(FC)
	naval_check(!T3.granted() && findtext(T3.refusal, "taken"), "a taken berth refuses another craft ([T3.refusal])")
	naval_check(P.cast_off() && !small.occupant && !P.berth && !P.cast_off(), "casting off frees the berth")
	T = small.request(P)
	T.release()
	naval_check(!small.reserved && !P.ticket && !T.granted(), "a released ticket gives the berth back")
	big.owner_party = party_train_faction_party("Blues")
	refusal = big.refusal(P)
	naval_check(refusal && findtext(refusal, "does not welcome"), "an owned berth refuses another party ([refusal])")
	naval_check(!big.refusal(P, TRUE), "a forced docking skips the welcome")
	big.welcome = BERTH_WELCOME_GUESTS
	big.guests += R.party
	naval_check(!big.refusal(P) && big.refusal(FC), "a guest party is welcome; a craft with no party is not")
	big.welcome = BERTH_WELCOME_EVERYONE
	naval_check(!big.refusal(FC), "a berth open to everyone takes anyone that fits")
	T = big.request(FC)
	T.complete()
	qdel(big)
	naval_check(!FC.berth, "a berth that is removed lets its craft go")

	// ---- Carried crafts ----
	FC.carried += P
	P.carrier = FC
	var/datum/craft/tender = new
	tender.carrier = P
	P.carried += tender
	var/list/all = FC.all_carried()
	naval_check(all.len == 2 && all[1] == P && all[2] == tender, "carried crafts are listed in nesting order")
	qdel(tender)
	naval_check(!P.carried.len, "a deleted craft leaves its carrier")
	FC.carried -= P
	P.carrier = null

	// ---- Charts ----
	var/datum/chart/probe/chart = new
	var/datum/chart_token/mine = new
	mine.name = "Gull"
	mine.craft = P
	P.token = mine
	naval_check(chart.add_token(mine, 1, 1) && mine.follow_craft() && mine.x == S.ox && mine.y == S.oy, "on a mirror chart a token stands where its craft is ([mine.x],[mine.y])")
	B.move_to(S.ox + 2, S.oy, EAST)
	naval_check(mine.x == S.ox && mine.y == S.oy, "and follows her when she hops")
	var/datum/chart_token/near = new
	near.name = "Heron"
	var/datum/chart_token/far = new
	chart.add_token(near, mine.x + 10, mine.y)
	chart.add_token(far, mine.x - 30, mine.y + 30)
	mine.sensor_range = 20
	var/list/seen = chart.contacts_of(mine)
	naval_check(seen.len == 1 && seen[1] == near && near.contact_name() == "Heron", "contacts are the tokens inside sensor range")
	near.dark = TRUE
	naval_check(near.contact_name() == "unknown contact" && (near in chart.contacts_of(mine)), "a token running dark is seen but not named")
	naval_check(!chart.add_token(far, 0, 5) && !chart.add_token(far, 71, 5), "a token cannot be put off the chart")
	var/datum/chart_hazard/storm = new
	storm.x = mine.x
	storm.y = mine.y
	storm.radius = 3
	chart.hazards += storm
	naval_check(length(chart.hazards_at(mine.x + 3, mine.y - 3)) == 1 && !length(chart.hazards_at(mine.x + 4, mine.y)), "a hazard covers the square around it")
	var/datum/chart_site/site = new
	naval_check(!site.can_unload(), "a site that is not loaded has nothing to unload")
	site.loaded = TRUE
	naval_check(site.can_unload(), "a loaded site may go")
	site.kept = TRUE
	naval_check(!site.can_unload() && isnull(site.site_template()), "a keep beacon holds it")
	qdel(mine)
	naval_check(!P.token && !(mine in chart.tokens), "a deleted token leaves its chart and its craft")

	// ---- Plane pools ----
	var/datum/plane_pool/pool = new
	naval_check(findtext(pool.claim_refusal("station:x"), "every plane is taken") && !pool.claim("station:x"), "an empty pool has nothing to give")
	pool.paused = TRUE
	naval_check(findtext(pool.claim_refusal("station:x"), "paused"), "a paused pool says so")
	var/datum/plane_pool/orbit/orbit = new
	naval_check(!orbit.free_planes().len && !orbit.claim("station:x") && orbit.quota("station:x") == 6, "off an orbit world the orbit pool is empty; its quota is the station quota")

	// ---- Clean-up ----
	S.remove()
	qdel(S)
	crafts_prune()
	naval_check(!(P in crafts) && (FC in crafts), "pruning drops the craft whose vessel is gone and keeps the other")

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
