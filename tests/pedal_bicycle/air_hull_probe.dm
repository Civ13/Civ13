// Headless full-game crewed airship regression (air_hull.dm).
// ride.py --probe air_hull_probe.dm appends it to a temporary copy of
// civ13.dme. A builder stands a ladder into the open air, lays a deck beside
// its top, hangs gas cells and sets up a helm, commissions her, finds one cell
// too few to cast off, adds another, flies her two tiles with the builder
// aboard, comes about, is stopped by an upper storey, fires down at the
// ground, and saves and restores her. Production code runs unchanged.
var/global/datum/air_hull_probe/air_hull_probe = new

/mob/living/human/air_hull_actor/ssd_check()
	return FALSE

/datum/air_hull_probe
	var/list/notes = list()
	var/list/problems = list()

/datum/air_hull_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(10)
		run_probe()

/datum/air_hull_probe/proc/ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/air_hull_probe/proc/playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/air_hull_probe/proc/sky_ready()
	return building_standing_present()

/datum/air_hull_probe/proc/wait_for(proc_name, limit)
	var/until = world.time + limit
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION("timeout waiting for [proc_name]")
		sleep(5)

/datum/air_hull_probe/proc/expect(condition, text)
	if(!condition)
		problems += text

/datum/air_hull_probe/proc/prepare(turf/centre, sky_z)
	for(var/dx = -16 to 16)
		for(var/dy = -16 to 16)
			for(var/level in list(centre.z, sky_z))
				var/turf/T = locate(centre.x + dx, centre.y + dy, level)
				if(!T)
					return FALSE
				for(var/atom/movable/A in T)
					if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers) || istype(A, /obj/roof))
						A.loc = null
				if(level == centre.z && T.type != /turf/floor/grass)
					T = new /turf/floor/grass(T)
				if(level == sky_z && T.type != /turf/sky/building)
					T = new /turf/sky/building(T)
	sleep(10)
	return TRUE

/datum/air_hull_probe/proc/lay(mob/living/human/B, turf/T)
	var/obj/item/airship_planks/P = new(B)
	B.put_in_active_hand(P)
	return P.resolve_attackby(T, B) && !QDELETED(P) ? FALSE : !!(locate(/obj/covers/airship_deck) in T)

/datum/air_hull_probe/proc/sky(turf/G, dx, dy, sky_z)
	return locate(G.x + dx, G.y + dy, sky_z)

/datum/air_hull_probe/proc/build_and_fly(turf/start, sky_z)
	// A ladder from the ground into the open air.
	var/obj/structure/multiz/ladder/up/placed/bottom = new(start)
	var/turf/top_turf = sky(start, 0, 0, sky_z)
	var/obj/structure/multiz/ladder/placed/top = new(top_turf)
	bottom.target = top
	top.target = bottom
	var/mob/living/human/air_hull_actor/B = new(top_turf)
	B.a_intent = I_HELP
	sleep(5)
	expect(B.z == sky_z, "builder fell off the ladder top")
	// Planks away from the ladder are refused.
	expect(air_deck_lay_refusal(sky(start, 3, 3, sky_z), B), "a plank far from the ladder was allowed")
	expect(!air_deck_lay_refusal(sky(start, 1, 0, sky_z), B), "a plank beside the ladder top was refused")
	// A 4x3 deck east of the ladder top.
	for(var/dx = 1 to 4)
		for(var/dy = 0 to 2)
			var/turf/T = sky(start, dx, dy, sky_z)
			// Stand on the ladder top or deck already laid beside it.
			for(var/turf/S in range(1, T))
				if(S != T && ((locate(/obj/covers/airship_deck) in S) || (locate(/obj/structure/multiz) in S)))
					B.forceMove(S)
					break
			expect(lay(B, T), "no deck laid at +[dx],+[dy]: [air_deck_lay_refusal(T, B)]")
	B.forceMove(sky(start, 2, 1, sky_z))
	sleep(2)
	expect(B.z == sky_z, "builder fell through the deck")
	// One gas cell and the helm.
	var/obj/item/airship_gas_cell/cell = new(B)
	B.put_in_active_hand(cell)
	cell.resolve_attackby(sky(start, 2, 1, sky_z), B)
	expect(locate(/obj/structure/airship_gas_cell) in sky(start, 2, 1, sky_z), "no gas cell hung")
	var/obj/item/airship_helm_kit/kit = new(B)
	B.put_in_active_hand(kit)
	B.dir = EAST
	kit.resolve_attackby(sky(start, 3, 1, sky_z), B)
	var/obj/structure/airship_helm/H = locate() in sky(start, 3, 1, sky_z)
	expect(H, "no helm set up")
	if(!H)
		throw EXCEPTION("no helm")
	var/problem = H.commission("probe ship", EAST)
	expect(!problem, "commission refused: [problem]")
	var/datum/craft/air/C = H.craft
	var/datum/craft_body/built/air/body = C ? C.body : null
	expect(istype(C) && istype(body) && body.tile_count() == 12, "airship body: [body ? body.tile_count() : "none"] tiles")
	expect(C in air_hull_crafts, "not listed as an airship")
	expect(C.shadow && C.shadow_anchor == locate(start.x + 1, start.y, start.z), "no shadow on the ground at her corner")
	expect(C.ground_view && C.ground_view.vis_contents.len > 100, "no ground view for the crew")
	// Twelve tiles and one person need two cells.
	expect(body.lift_refusal(), "one cell lifted thirteen")
	expect(!body.can_move_to(body.origin().x + 1, body.origin().y, EAST), "moved with too little lift")
	cell = new(B)
	B.put_in_active_hand(cell)
	cell.resolve_attackby(sky(start, 2, 2, sky_z), B)
	expect(!body.lift_refusal(), "two cells still short: [body.lift_refusal()]")
	// Cast off and fly two tiles east with the builder aboard.
	C.set_anchor(FALSE)
	C.speed = VESSEL_SPEED_SLOW
	C.stop_sailing() // The probe steps her itself.
	var/turf/was = body.origin()
	for(var/i = 1 to 2)
		expect(C.sail_hop(), "hop [i] refused: [C.last_refusal]")
	var/turf/now = body.origin()
	notes["flown"] = "[was.x],[was.y] -> [now.x],[now.y]"
	expect(now.x == was.x + 2 && now.y == was.y && now.z == sky_z, "flew to [now.x],[now.y],[now.z]")
	expect(B.z == sky_z && body.contains(get_turf(B)), "builder left behind or fell: [B.x],[B.y],[B.z]")
	expect(B.getBruteLoss() == 0, "builder hurt in flight")
	expect(get_turf(H) == sky(start, 5, 1, sky_z) && H.craft == C, "helm not carried")
	expect(locate(/obj/structure/airship_gas_cell) in sky(start, 4, 1, sky_z), "gas cell not carried")
	expect(locate(/obj/structure/multiz/ladder/placed) in top_turf, "the ladder top went with her")
	expect(!(locate(/obj/covers/airship_deck) in sky(start, 1, 0, sky_z)), "deck left behind")
	expect(C.shadow_anchor == locate(start.x + 3, start.y, start.z), "shadow did not follow")
	// Fired down from the deck at the ground.
	var/turf/aim = locate(B.x + 2, B.y, start.z)
	expect(airborne_launch_turf(B, aim) == locate(B.x, B.y, start.z), "a shot from the deck does not start under it")
	var/mob/living/human/air_hull_actor/T = new(aim)
	sleep(5)
	var/obj/item/weapon/gun/projectile/revolver/nagant_revolver/gun = new(B)
	B.put_in_active_hand(gun)
	gun.safetyon = FALSE
	for(var/i = 1 to 3)
		gun.loaded += new gun.ammo_type(gun)
	B.last_movement = world.time - 100
	gun.Fire(T, B)
	sleep(20)
	notes["deck_shot_brute"] = T.getBruteLoss()
	notes["deck_shot_spent"] = gun.loaded.len
	expect(T.getBruteLoss() > 0, "the shot from the deck missed the person below")
	T.loc = null
	B.drop_from_inventory(gun)
	gun.loc = null
	// Come about to the north.
	expect(body.turn_to(NORTH), "could not come about: [body.last_refusal]")
	expect(B.z == sky_z && body.contains(get_turf(B)), "builder fell when she came about")
	// An upper storey ahead stops her.
	now = body.origin()
	var/list/box = body.box(body.offsets)
	var/obj/covers/wall = new /obj/covers/wood(locate(body.px + box[1], body.py + box[4] + 2, sky_z))
	expect(C.sail_hop(), "first hop north refused: [C.last_refusal]")
	expect(!C.sail_hop() && findtext(C.last_refusal, "floor"), "an upper storey did not stop her: [C.last_refusal]")
	wall.loc = null
	// Saved and restored: she comes back holding her position.
	var/tiles = body.tile_count()
	H.before_save()
	expect(length(H.hull_state), "nothing saved")
	H.decommission()
	expect(!H.craft && !(locate(/obj/structure/airship_gas_cell) in null), "decommission left her")
	H.after_load()
	expect(H.craft && H.craft.body.tile_count() == tiles && H.craft.anchored, "restore: [H.craft ? H.craft.body.tile_count() : "none"]")
	notes["restored_tiles"] = H.craft ? H.craft.body.tile_count() : 0
	H.decommission()
	expect(locate(/obj/covers/airship_deck) in get_turf(H), "struck deck vanished")
	B.loc = null

/datum/air_hull_probe/proc/run_probe()
	var/failure = null
	try
		wait_for("ready", 9000)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("playing", 3000)
		wait_for("sky_ready", 600)
		var/turf/start = null
		var/sky_z = 0
		for(var/level = 1 to world.maxz)
			var/up = multiz_level_above(level)
			if(up && istype(locate(1, 1, up), /turf/sky))
				start = locate(round(world.maxx / 2), round(world.maxy / 2), level)
				sky_z = up
				break
		if(!start || !prepare(start, sky_z))
			throw EXCEPTION("no ground with open sky above found")
		notes["start"] = "[start.x],[start.y],[start.z] under [sky_z]"
		build_and_fly(start, sky_z)
		if(problems.len)
			notes["problems"] = problems
			throw EXCEPTION(jointext(problems, "; "))
	catch(var/exception/e)
		failure = "[e.name] [e.file]:[e.line]"
		if(problems.len)
			notes["problems"] = problems
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "notes" = notes, "tick_lag" = world.tick_lag)
	text2file(json_encode(result), "result.json")
	world.log << "AIR HULL PROBE DONE [failure]"
	sleep(5)
	del(world)
