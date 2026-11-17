// Headless full-game crewed airship regression (air_hull.dm).
// ride.py --probe air_hull_probe.dm appends it to a temporary copy of
// civ13.dme. A builder stands a ladder into the open air, lays a deck beside
// its top, hangs gas cells and sets up a helm, commissions her, finds one cell
// too few to cast off, adds another, flies her two tiles with the builder
// aboard, comes about, is stopped by an upper storey, fires down at the
// ground, saves and restores her, has a cell holed
// from the ground and patched, drops a bomb through the hatch, and is wrecked
// when both cells burn. A second airship is built two levels up, over an
// open level, and flies, sees, shoots, is shot, bombs and falls from there. Production code runs unchanged.
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
	expect(!H.craft, "decommission left her")
	expect(locate(/obj/covers/airship_deck) in get_turf(H), "struck deck vanished")
	H.after_load()
	expect(H.craft && H.craft.body.tile_count() == tiles && H.craft.anchored, "restore: [H.craft ? H.craft.body.tile_count() : "none"]")
	notes["restored_tiles"] = H.craft ? H.craft.body.tile_count() : 0
	if(H.craft)
		fight(H, B, start.z)
	B.loc = null

// Ground fire holes a cell, cloth patches it, a bomb drops through the hatch,
// one burnt cell holds her in place and a second wrecks her.
/datum/air_hull_probe/proc/fight(obj/structure/airship_helm/H, mob/living/human/air_hull_actor/B, ground_z)
	var/datum/craft/air/C = H.craft
	var/datum/craft_body/built/air/body = C.body
	var/list/gas = list()
	var/turf/free = null
	for(var/turf/D in body.cells())
		var/obj/structure/airship_gas_cell/G = locate() in D
		if(G)
			gas += G
		else if(!free && !(locate(/obj/structure/airship_helm) in D))
			free = D
	expect(gas.len == 2, "[gas.len] gas cells after restore")
	if(gas.len != 2 || !free)
		return
	var/obj/structure/airship_gas_cell/G1 = gas[1]
	var/obj/structure/airship_gas_cell/G2 = gas[2]
	B.forceMove(free)
	sleep(2)
	// A rifleman on the ground shoots along the row under the first cell.
	var/mob/living/human/air_hull_actor/S = new(locate(G1.x - 3, G1.y, ground_z))
	var/mob/living/human/air_hull_actor/mark = new(locate(G1.x + 3, G1.y, ground_z))
	S.a_intent = I_HARM
	var/obj/item/weapon/gun/projectile/revolver/nagant_revolver/gun = new(S)
	S.put_in_active_hand(gun)
	gun.safetyon = FALSE
	var/shots = 0
	while(!G1.holes && !G2.holes && shots < 12)
		// Spent casings stay in a revolver's cylinder: give it a fresh round.
		for(var/obj/item/ammo_casing/spent in gun.loaded)
			spent.loc = null
		gun.loaded = list(new gun.ammo_type(gun))
		S.last_movement = world.time - 100
		gun.Fire(mark, S)
		shots++
		sleep(10)
	notes["shots_to_hole"] = shots
	// The row under the first cell may pass under the second as well.
	var/obj/structure/airship_gas_cell/holed = G1.holes ? G1 : G2
	expect(holed.holes > 0, "[shots] shots from the ground never holed a cell overhead")
	expect(holed.lift() < 12 && holed.icon_state == "gas_cell_holed", "a holed cell still lifts [holed.lift()]")
	expect(!QDELETED(C) && !body.lift_refusal(), "one hole grounded her: [body.lift_refusal()]")
	S.loc = null
	mark.loc = null
	gun.loc = null
	// Patched with cloth from the deck.
	var/holes = holed.holes
	var/obj/item/stack/material/cloth/rag = new(B)
	rag.amount = 5
	B.put_in_active_hand(rag)
	holed.attackby(rag, B)
	expect(holed.holes == holes - 1, "cloth did not patch a hole: [holed.holes] of [holes]")
	for(var/obj/structure/airship_gas_cell/G in gas)
		G.holes = 0
		G.update_icon()
	// The bomb hatch drops a filled bomb onto the ground below.
	var/obj/structure/airship_bomb_hatch/hatch = new(free)
	var/obj/item/weapon/aircraft_bomb/bomb = new(B)
	bomb.filled = TRUE
	B.drop_from_inventory(rag)
	rag.loc = null
	B.put_in_active_hand(bomb)
	hatch.attackby(bomb, B)
	expect(bomb.loc == hatch, "the hatch did not take the bomb")
	var/mob/living/human/air_hull_actor/V = new(locate(free.x, free.y, ground_z))
	sleep(2)
	hatch.attack_hand(B)
	sleep(10)
	notes["bomb_victim_brute"] = V.getBruteLoss()
	expect(!length(hatch.bombs()), "the bomb stayed in the cradle")
	expect(QDELETED(bomb) || bomb.z == ground_z, "the bomb did not fall: [bomb.x],[bomb.y],[bomb.z]")
	expect(V.getBruteLoss() > 0 || V.stat == DEAD || QDELETED(V), "the bomb hurt no one below")
	expect(!QDELETED(C) && B.z == body.z, "the bomb blast reached the deck")
	if(!QDELETED(V))
		V.loc = null
	// A fire arrow burns one cell out: she hangs where she is.
	var/turf/D1 = get_turf(G1)
	var/obj/item/projectile/arrow/arrow/fire/F = new(locate(D1.x, D1.y, ground_z))
	C.set_anchor(FALSE)
	C.struck_by(F, D1, F.loc)
	notes["one_cell_burnt"] = "lift [body.lift()] load [body.load()]"
	expect(G1.burnt && G1.lift() == 0, "a fire arrow did not burn the cell")
	expect(!QDELETED(C) && C.anchored && C.speed == VESSEL_SPEED_STOP, "half her lift gone and she kept flying")
	expect(B.z == body.z, "builder fell when one cell burned")
	// Burning the second wrecks her: the builder falls hurt, deck and helm go.
	var/brute = B.getBruteLoss()
	var/turf/D2 = get_turf(G2)
	var/obj/item/projectile/arrow/arrow/fire/F2 = new(locate(D2.x, D2.y, ground_z))
	C.struck_by(F2, D2, F2.loc)
	sleep(5)
	notes["crash_brute"] = B.getBruteLoss() - brute
	expect(QDELETED(C) && !(C in air_hull_crafts), "she did not break up with no lift")
	expect(QDELETED(H), "the helm survived the wreck")
	expect(B.z == ground_z && B.getBruteLoss() > brute, "builder not thrown down hurt: z [B.z]")
	expect(!(locate(/obj/covers/airship_deck) in D2) && !(locate(/obj/structure/airship_gas_cell) in D2), "wreck left deck in the air")
	expect(QDELETED(hatch), "the bomb hatch stayed in the air")
	if(!QDELETED(F))
		qdel(F)
	if(!QDELETED(F2))
		qdel(F2)

// Two levels up: a floor on the first open level, a ladder from it to the next,
// and a deck there. Everything is seen, dropped and shot through the open
// level between her and the ground.
/datum/air_hull_probe/proc/high_flight(turf/start, sky_z)
	var/high_z = multiz_level_above(sky_z)
	if(!high_z)
		building_allocate_level(world.maxz + 1)
		high_z = multiz_level_above(sky_z)
	expect(high_z, "no level above the open air: [world_z_budget.last_error]")
	if(!high_z)
		return
	notes["high_z"] = high_z
	for(var/dx = -2 to 8)
		for(var/dy = -2 to 6)
			var/turf/T = locate(start.x + dx, start.y + dy, high_z)
			if(T && T.type != /turf/sky/building)
				new /turf/sky/building(T)
	var/turf/landing = sky(start, 0, 0, sky_z)
	new /obj/covers/repairedfloor(landing)
	var/obj/structure/multiz/ladder/up/placed/bottom = new(landing)
	var/turf/top_turf = sky(start, 0, 0, high_z)
	var/obj/structure/multiz/ladder/placed/top = new(top_turf)
	bottom.target = top
	top.target = bottom
	var/mob/living/human/air_hull_actor/B = new(top_turf)
	B.a_intent = I_HELP
	sleep(5)
	expect(B.z == high_z, "builder fell off the upper ladder top")
	// A 3x2 deck, one cell and a helm.
	for(var/dx = 1 to 3)
		for(var/dy = 0 to 1)
			var/turf/T = sky(start, dx, dy, high_z)
			for(var/turf/S in range(1, T))
				if(S != T && ((locate(/obj/covers/airship_deck) in S) || (locate(/obj/structure/multiz) in S)))
					B.forceMove(S)
					break
			expect(lay(B, T), "no high deck laid at +[dx],+[dy]: [air_deck_lay_refusal(T, B)]")
	B.forceMove(sky(start, 1, 0, high_z))
	var/obj/item/airship_gas_cell/cell = new(B)
	B.put_in_active_hand(cell)
	cell.resolve_attackby(sky(start, 2, 1, high_z), B)
	var/obj/structure/airship_gas_cell/G = locate() in sky(start, 2, 1, high_z)
	expect(G, "no high gas cell hung")
	var/obj/item/airship_helm_kit/kit = new(B)
	B.put_in_active_hand(kit)
	B.dir = EAST
	kit.resolve_attackby(sky(start, 2, 0, high_z), B)
	var/obj/structure/airship_helm/H = locate() in sky(start, 2, 0, high_z)
	expect(H, "no high helm set up")
	if(!H || !G)
		return
	var/problem = H.commission("high ship", EAST)
	expect(!problem, "high commission refused: [problem]")
	var/datum/craft/air/C = H.craft
	if(!C)
		return
	var/datum/craft_body/built/air/body = C.body
	expect(body.z == high_z && body.tile_count() == 6, "high body: z [body.z], [body.tile_count()] tiles")
	// Her shadow and the crew's view reach the ground through the open level.
	expect(C.shadow_anchor && C.shadow_anchor.z == start.z, "high shadow on z [C.shadow_anchor ? C.shadow_anchor.z : 0], not the ground")
	var/ground_seen = 0
	for(var/turf/V in C.ground_view.vis_contents)
		if(V.z == start.z)
			ground_seen++
	expect(ground_seen > 50, "the crew sees [ground_seen] ground tiles from two levels up")
	// A floor in between is what she sees and drops onto there.
	var/turf/roof_under = sky(start, 3, 1, sky_z)
	new /obj/covers/repairedfloor(roof_under)
	expect(air_hull_solid_below(sky(start, 3, 1, high_z)) == roof_under, "a floor between her and the ground is not what lies under her")
	expect(air_hull_levels_between(locate(start.x + 3, start.y + 1, start.z), sky(start, 3, 1, high_z)) == 0, "a floor between did not shield her")
	expect(air_hull_levels_between(locate(start.x + 2, start.y + 1, start.z), sky(start, 2, 1, high_z)) == 2, "two open levels not counted")
	for(var/obj/covers/repairedfloor/F in roof_under)
		F.loc = null
	// She flies a tile east, two levels up.
	B.forceMove(sky(start, 1, 1, high_z))
	C.set_anchor(FALSE)
	C.speed = VESSEL_SPEED_SLOW
	C.stop_sailing()
	var/turf/was = body.origin()
	expect(C.sail_hop(), "high hop refused: [C.last_refusal]")
	var/turf/now = body.origin()
	expect(now.x == was.x + 1 && now.z == high_z, "high hop went to [now.x],[now.y],[now.z]")
	expect(B.z == high_z && body.contains(get_turf(B)), "builder fell from the high deck")
	C.set_anchor(TRUE)
	var/turf/GT = get_turf(G)
	// The crew's shots and clicks on open air go to the ground two levels down.
	var/turf/here = get_turf(B)
	var/turf/aim = locate(here.x, here.y + 2, start.z)
	expect(airborne_launch_turf(B, aim) == locate(here.x, here.y, start.z), "a high deck shot does not start on the ground under her")
	var/turf/air = locate(here.x, here.y + 2, high_z)
	expect(airborne_aim_turf(B, air) == aim, "clicking open air from the high deck does not aim at the ground below")
	var/mob/living/human/air_hull_actor/T = new(aim)
	sleep(5)
	var/obj/item/weapon/gun/projectile/revolver/nagant_revolver/gun = new(B)
	B.put_in_active_hand(gun)
	gun.safetyon = FALSE
	for(var/i = 1 to 3)
		gun.loaded += new gun.ammo_type(gun)
	B.last_movement = world.time - 100
	gun.Fire(air, B)
	sleep(20)
	notes["high_click_shot_brute"] = T.getBruteLoss()
	expect(T.getBruteLoss() > 0, "a click on open air from the high deck missed the person below")
	T.loc = null
	B.drop_from_inventory(gun)
	gun.loc = null
	// Ground fire reaches her through the open level, less often.
	notes["high_levels_under_cell"] = air_hull_levels_between(locate(GT.x, GT.y, start.z), GT)
	// Close under her, so the shot's spread cannot carry it wide of the cell.
	var/mob/living/human/air_hull_actor/S = new(locate(GT.x - 1, GT.y, start.z))
	var/mob/living/human/air_hull_actor/mark = new(locate(GT.x + 2, GT.y, start.z))
	S.a_intent = I_HARM
	gun = new(S)
	S.put_in_active_hand(gun)
	gun.safetyon = FALSE
	var/shots = 0
	while(!G.holes && shots < 30)
		// Spent casings stay in a revolver's cylinder: give it a fresh round.
		for(var/obj/item/ammo_casing/spent in gun.loaded)
			spent.loc = null
		gun.loaded = list(new gun.ammo_type(gun))
		S.last_movement = world.time - 100
		gun.Fire(mark, S)
		shots++
		sleep(10)
	notes["high_shots_to_hole"] = shots
	expect(G.holes > 0, "[shots] shots from two levels down never holed her cell")
	S.loc = null
	mark.loc = null
	gun.loc = null
	G.holes = 0
	G.update_icon()
	// The bomb falls through the open level to the ground.
	var/turf/hatch_turf = null
	for(var/turf/D in body.cells())
		if(!(locate(/obj/structure/airship_gas_cell) in D) && !(locate(/obj/structure/airship_helm) in D) && D != get_turf(B))
			hatch_turf = D
			break
	var/obj/structure/airship_bomb_hatch/hatch = new(hatch_turf)
	for(var/turf/D in range(1, hatch_turf))
		if(D != hatch_turf && D != GT && body.contains(D) && !(locate(/obj/structure/airship_helm) in D))
			B.forceMove(D)
			break
	var/obj/item/weapon/aircraft_bomb/bomb = new(hatch)
	bomb.filled = TRUE
	var/mob/living/human/air_hull_actor/V = new(locate(hatch_turf.x, hatch_turf.y, start.z))
	sleep(2)
	hatch.attack_hand(B)
	sleep(10)
	notes["high_bomb_victim_brute"] = V.getBruteLoss()
	expect(QDELETED(bomb) || bomb.z == start.z, "the high bomb stopped at z [bomb.z]")
	expect(V.getBruteLoss() > 0 || V.stat == DEAD || QDELETED(V), "the high bomb hurt no one on the ground")
	expect(!QDELETED(C) && B.z == high_z, "the high bomb blast reached her")
	if(!QDELETED(V))
		V.loc = null
	// Burnt out, she falls two levels and the fall hurts more.
	var/brute = B.getBruteLoss()
	var/turf/GG = locate(GT.x, GT.y, start.z)
	var/obj/item/projectile/arrow/arrow/fire/F = new(GG)
	C.struck_by(F, GT, GG)
	sleep(5)
	notes["high_crash_brute"] = B.getBruteLoss() - brute
	expect(QDELETED(C), "the burnt high airship did not break up")
	expect(B.z == start.z && B.getBruteLoss() - brute >= 30, "builder not thrown to the ground hard: z [B.z], [B.getBruteLoss() - brute] brute")
	if(!QDELETED(F))
		qdel(F)
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
		high_flight(locate(start.x - 8, start.y - 8, start.z), sky_z)
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
