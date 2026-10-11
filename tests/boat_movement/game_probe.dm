// Test-only overlay loaded by run-game.ps1; excluded from the production dme.
// Uses real hulls, masts, passengers, forceMove callbacks and boat procedures.
// ChangeTurf initialization can call Entered(null) on this checkout. This adapter
// ignores only that synthetic initializer callback; real movable entries call parent.
/turf/floor/beach/water/shallowsaltwater/vehicle_probe/Entered(atom/movable/AM, atom/old_loc)
	if(!AM)
		return
	return ..()
/datum/configuration/New()
	..()
	webhook_can_fire = FALSE
	ToRban = FALSE
var/global/datum/boat_game_probe/boat_game_probe = new
/datum/boat_game_probe
	var/list/blast_points = list()
	var/failures = 0
	var/passed = 0
	var/running = FALSE
	var/phase = "Preparing isolated boat world"
	var/list/owned = list()
	var/list/boats = list()
	var/obj/structure/vehicleparts/axis/ship/main
	var/obj/structure/vehicleparts/axis/ship/large
	var/obj/structure/vehicleparts/axis/heavy/t34/tank
	var/obj/item/stack/material/wood/outside
	var/turf/shore
	var/mob/living/human/entry_actor
	var/turf/entry_target
	var/entry_attempted = FALSE
	var/entry_result = FALSE
/obj/item/weapon/grenade/frag/vehicle_probe/on_explosion(turf/O)
	boat_game_probe.blast_points += list(list(O.x,O.y,O.z))
	return ..(O)
/datum/boat_game_probe/New()
	spawn(200)
		run_tests()
/datum/boat_game_probe/proc/check(condition, label)
	if(condition)
		passed++
		world.log << "BOAT PASS: [label]"
	else
		failures++
		world.log << "BOAT FAIL: [label]"
/datum/boat_game_probe/proc/clear()
	for(var/obj/structure/vehicleparts/axis/A in boats)
		A.stopmovementloop()
		if(A.engine) A.engine.on = FALSE
		for(var/atom/movable/M in A.components)
			owned |= M
	for(var/atom/movable/M in owned)
		qdel(M)
		// Fixture cleanup must finish before reusing the arena; no deleted fuel containers remain.
		if(M) del(M)
	owned.Cut()
	boats.Cut()
/datum/boat_game_probe/proc/make_boat(x,y,w,h)
	var/obj/structure/vehicleparts/axis/ship/A = new(locate(x,y,1))
	A.name = "LOCAL [w]x[h] test boat"
	A.dir = NORTH
	owned += A
	boats += A
	for(var/i=0,i<w,i++)
		for(var/j=0,j<h,j++)
			var/obj/structure/vehicleparts/frame/ship/F = new(locate(x+i,y-j,1))
			owned += F
	var/obj/structure/vehicleparts/movement/sail/premade/S = new(locate(x,y-1,1))
	S.sails_on = TRUE
	S.update_icon()
	var/obj/structure/vehicleparts/shipwheel/W = new(locate(x,y,1))
	var/obj/item/stack/material/wood/C = new(locate(x+1,y-1,1))
	C.name = "LOCAL onboard cargo"
	var/mob/living/human/H = new(locate(x+1,y,1))
	H.name = "LOCAL test passenger"
	H.real_name = H.name
	var/obj/structure/cannon/G = new(locate(x,y-h+1,1))
	G.dir = WEST
	owned += S
	owned += W
	owned += C
	owned += H
	owned += G
	new /obj/effect/autoassembler(locate(x+2,y-2,1))
	sleep(15)
	A.anchor = FALSE
	A.currentspeed = 1
	A.moving = TRUE
	return A
/datum/boat_game_probe/proc/snapshot(obj/structure/vehicleparts/axis/A)
	A.add_transporting()
	var/list/result = list()
	for(var/atom/movable/M in (A.components | A.transporting))
		result["\ref[M]"] = list(M,M.loc)
	return result
/datum/boat_game_probe/proc/same_locations(list/before)
	for(var/id in before)
		var/list/entry = before[id]
		var/atom/movable/M = entry[1]
		if(!M || M.loc != entry[2])
			text2file("DRIFT: ref=[id] type=[M ? M.type : null] name=[M]; now=[M ? M.loc : null] at [M ? M.x : 0],[M ? M.y : 0],[M ? M.z : 0]; before=[entry[2]]", "boat-drift.txt")
			return FALSE
	return TRUE
/datum/boat_game_probe/proc/make_tank(x=78,y=44)
	var/obj/structure/vehicleparts/axis/heavy/t34/A = new(locate(x,y,1))
	A.dir = NORTH
	A.name = "LOCAL production-assembled T34"
	owned += A
	boats += A
	var/list/rows = list(list(/obj/structure/vehicleparts/frame/t34/lf,/obj/structure/vehicleparts/frame/t34/front,/obj/structure/vehicleparts/frame/t34/rf),list(/obj/structure/vehicleparts/frame/t34/left,/obj/structure/vehicleparts/frame/t34/fc,/obj/structure/vehicleparts/frame/t34/right),list(/obj/structure/vehicleparts/frame/t34/left/door,/obj/structure/vehicleparts/frame/t34/bc,/obj/structure/vehicleparts/frame/t34/right/door),list(/obj/structure/vehicleparts/frame/t34/lb,/obj/structure/vehicleparts/frame/t34/back,/obj/structure/vehicleparts/frame/t34/rb))
	for(var/j=0,j<4,j++)
		var/list/row = rows[j+1]
		for(var/i=0,i<3,i++)
			var/frame_type = row[i+1]
			var/obj/structure/vehicleparts/frame/F = new frame_type(locate(x+i,y-j,1))
			owned += F
	owned += new /obj/structure/vehicleparts/movement/tracks/t34/left_front(locate(x,y,1))
	owned += new /obj/structure/vehicleparts/movement/tracks/t34/right_front(locate(x+2,y,1))
	owned += new /obj/structure/vehicleparts/movement/tracks/t34/left_back(locate(x,y-3,1))
	owned += new /obj/structure/vehicleparts/movement/tracks/t34/right_back(locate(x+2,y-3,1))
	var/obj/structure/engine/internal/E = new /obj/structure/engine/internal/diesel/premade/chiha(locate(x+2,y-3,1))
	owned += E
	owned += new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel(locate(x,y-3,1))
	owned += new /obj/structure/bed/chair/drivers/tank(locate(x+1,y-1,1))
	var/mob/living/human/H = new(locate(x+1,y-2,1))
	H.name = "LOCAL tank passenger"
	H.real_name = H.name
	owned += H
	owned += new /obj/item/stack/material/wood(locate(x+1,y-2,1))
	var/obj/structure/cannon/G = new(locate(x+1,y-1,1))
	G.dir = WEST
	owned += G
	new /obj/effect/autoassembler(locate(x+2,y-2,1))
	sleep(15)
	E.on = TRUE
	A.moving = TRUE
	A.currentspeed = 1
	return A
/datum/boat_game_probe/proc/attempt_entry(atom/movable/mover,atom/old_loc,atom/new_loc)
	if(entry_actor && entry_target && !entry_attempted)
		entry_attempted = TRUE
		entry_result = entry_actor.Move(entry_target,EAST)
/datum/boat_game_probe/proc/run_tank_tests()
	clear()
	for(var/x in 72 to 95)
		for(var/y in 30 to 55)
			var/turf/T = locate(x,y,1)
			for(var/atom/movable/M in T)
				qdel(M)
			T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/vehicleparts/axis/heavy/t34/A = make_tank()
	check(istype(A.loc,/obj/structure/vehicleparts/frame/t34),"tank production assembler nests controller in frame")
	check(A.wheels.len == 4 && A.engine && A.engine.fueltank,"tank production assembler connects real tracks and fueled engine")
	check(A.components.len == 16,"tank assembly limits turning placeholders to 4x4")
	var/list/before = snapshot(A)
	for(var/tdir in list("left","right"))
		for(var/i=1,i<=4,i++)
			check(A.do_matrix(A.dir,turn(A.dir,tdir=="left" ? 90 : -90),tdir),"tank real [tdir] turn [i]")
		check(same_locations(before),"tank real full [tdir] rotation preserves cargo/passenger/multi-tile cannon")
	check(A.do_vehicle_check() && A.do_move(),"tank real fueled engine/tracks forward movement")
	A.reverse = TRUE
	check(A.do_vehicle_check() && A.do_move(),"tank real reverse movement")
	check(same_locations(before),"tank forward/reverse preserves membership")
	A.reverse = FALSE
	for(var/heading in list(NORTH,EAST,SOUTH,WEST))
		if(A.dir != heading)
			check(A.do_matrix(A.dir,heading,"right"),"tank turn toward movement heading [heading]")
		var/list/move_before = snapshot(A)
		var/turf/old_axis = get_turf(A)
		A.currentspeed = 1
		A.moving = TRUE
		check(A.do_vehicle_check() && A.do_move() && get_turf(A) == get_step(old_axis,heading),"tank actual forward heading [heading]")
		A.reverse = TRUE
		check(A.do_vehicle_check() && A.do_move() && same_locations(move_before),"tank actual reverse heading [heading]")
		A.reverse = FALSE
	if(A.dir != NORTH)
		check(A.do_matrix(A.dir,NORTH,"right"),"tank returns NORTH before outsider cases")
	A.engine.on = FALSE
	var/mob/living/human/outsider = new(locate(81,41,1))
	outsider.name = "LOCAL outsider outside old and new hull"
	outsider.real_name = outsider.name
	var/obj/item/weapon/grenade/frag/G = new(locate(81,41,1))
	owned += outsider
	owned += G
	check(!(outsider in A.transporting) && !(G in A.transporting),"tank outsiders start off deck")
	check(A.do_matrix(NORTH,EAST,"right"),"tank turn with outsiders outside physical destination hull")
	check(outsider && outsider.loc == locate(81,41,1) && outsider.stat != DEAD,"tank phantom turning cell cannot move or crush outside player")
	check(G && G.loc == locate(81,41,1) && !(G in A.transporting),"tank phantom turning cell cannot delete or adopt outside grenade")
	phase = "tank teardown after outsiders"
	var/obj/item/fuel_status = A.engine.fueltank
	text2file(json_encode(list("deleted"=QDELETED(fuel_status),"reagents"=!!fuel_status.reagents,"transported"=(fuel_status in A.transporting))),"tank-fuel-state.json")
	clear()
	phase = "tank callback fixture assembly"
	A = make_tank()
	entry_actor = new(locate(77,44,1))
	entry_actor.name = "LOCAL callback entry actor"
	entry_actor.real_name = entry_actor.name
	owned += entry_actor
	entry_target = locate(78,44,1)
	entry_attempted = FALSE
	entry_result = FALSE
	var/obj/structure/vehicleparts/frame/first = A.loc
	GLOB.moved_event.register(first,src,/datum/boat_game_probe/proc/attempt_entry)
	check(A.do_matrix(NORTH,EAST,"right"),"tank rotation during real moved-event entry attempt")
	GLOB.moved_event.unregister(first,src,/datum/boat_game_probe/proc/attempt_entry)
	A.add_transporting()
	text2file(json_encode(list("attempted"=entry_attempted,"move_return"=entry_result,"x"=entry_actor.x,"y"=entry_actor.y,"z"=entry_actor.z,"in_transporting"=(entry_actor in A.transporting))),"tank-entry-state.json")
	check(entry_attempted,"tank callback attempted ordinary human Move during transform")
	check(entry_actor.loc == locate(77,44,1) && !(entry_actor in A.transporting),"tank transient hull vacancy cannot clip outside player into cabin")
	entry_actor.forceMove(locate(77,44,1))
	entry_actor.dir = EAST
	entry_actor.Move(locate(78,44,1),EAST)
	check(entry_actor.loc == locate(77,44,1),"tank closed cabin rejects ordinary boarding after turn")
	entry_actor.forceMove(locate(79,45,1))
	entry_actor.dir = SOUTH
	entry_actor.Move(locate(79,44,1),SOUTH)
	check(entry_actor.loc == locate(79,44,1),"tank open door still permits ordinary boarding after turn")
	A.do_matrix(EAST,NORTH,"left")
	entry_actor.forceMove(locate(77,44,1))
	entry_actor.dir = EAST
	entry_attempted = FALSE
	entry_result = FALSE
	GLOB.moved_event.register(first,src,/datum/boat_game_probe/proc/attempt_entry)
	A.engine.on = TRUE
	check(A.do_vehicle_check() && A.do_move(),"tank normal linear movement with callback entry attempt")
	GLOB.moved_event.unregister(first,src,/datum/boat_game_probe/proc/attempt_entry)
	A.add_transporting()
	check(entry_attempted && entry_actor.loc == locate(77,44,1) && !(entry_actor in A.transporting),"tank linear movement vacancy cannot admit outside player")
	entry_actor = null
	entry_target = null
	clear()
	A = make_tank()
	var/list/blocked_before = snapshot(A)
	var/obj/covers/blocker = new(locate(81,44,1))
	blocker.density = TRUE
	owned += blocker
	check(!A.do_matrix(NORTH,EAST,"right") && same_locations(blocked_before),"tank blocked turn preserves all owned actors")
	check(!A.transforming_vehicle && !locate(78,44,1):vehicle_transforming,"tank blocked turn leaves no transient reservation")
	clear()
	A = make_tank()
	var/obj/item/weapon/grenade/frag/loose = new(locate(81,44,1))
	owned += loose
	check(A.do_matrix(NORTH,EAST,"right"),"tank turn around unarmed exterior grenade")
	A.add_transporting()
	check(!(loose in A.transporting) && loose.is_vehicle_exterior(A),"unarmed exterior grenade is not automatically cargo")
	var/mob/living/human/loader = locate() in A.transporting
	check(loader && loader.put_in_active_hand(loose) && loose.loc == loader,"ordinary grenade pickup still works")
	if(loader)
		loader.drop_from_inventory(loose)
	A.add_transporting()
	check((loose in A.transporting) && !loose.is_vehicle_exterior(A),"explicit pickup and drop onto deck establishes ordinary cargo")
	clear()
	A = make_tank()
	var/obj/item/weapon/grenade/frag/vehicle_probe/armed = new(locate(81,44,1))
	owned += armed
	armed.det_time = 30
	armed.active = TRUE
	armed.activate()
	blast_points.Cut()
	check(!(armed in A.transporting),"external primed grenade starts outside tank")
	var/turf/grenade_origin = get_turf(armed)
	A.do_matrix(NORTH,EAST,"right")
	check(armed && !QDELETED(armed) && get_turf(armed) == grenade_origin && !(armed in A.transporting),"tank turn preserves outside grenade at original location with fuse alive")
	A.add_transporting()
	check(!(armed in A.transporting),"rotation-covered grenade is not newly adopted as cargo")
	for(var/i=1,i<=2,i++)
		check(A.do_vehicle_check() && A.do_move(),"tank advances while exterior grenade fuse runs [i]")
	check(armed && get_turf(armed) == grenade_origin && !(armed in A.transporting),"outside grenade stays at original location after following movement")
	sleep(40)
	check(blast_points.len == 1 && blast_points[1][1] == 81 && blast_points[1][2] == 44,"outside grenade still produces real explosion at original location")
	clear()
	for(var/x in 150 to 155)
		for(var/y in 38 to 48)
			var/turf/T = locate(x,y,1)
			for(var/atom/movable/M in T)
				qdel(M)
			T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	A = make_tank(153,44)
	var/list/edge_before = snapshot(A)
	check(!A.do_matrix(NORTH,EAST,"right") && same_locations(edge_before),"tank edge rotation cannot lose or partially move parts")
	A.dir = EAST
	for(var/obj/F in A.components) F.dir = EAST
	check(!A.do_move() && same_locations(edge_before),"tank edge linear move cannot lose or partially move parts")
	clear()
/datum/boat_game_probe/proc/save_result()
	fdel("boat-result.json")
	text2file(json_encode(list("commit"=world.params["tested_commit"], "map_id"=map.ID, "maxx"=world.maxx, "maxy"=world.maxy, "maxz"=world.maxz, "version"=world.byond_version, "build"=world.byond_build, "passed"=passed, "failures"=failures, "phase"=phase, "adapters"="test-only scene preparation and inspection; real production boat procedures and forceMove")), "boat-result.json")
	fdel("boat-result.txt")
	text2file("RESULT failures=[failures]; passed=[passed]", "boat-result.txt")
/datum/boat_game_probe/proc/run_tests()
	try
		if(!map || !ticker)
			throw EXCEPTION("Map/ticker unavailable")
		world.name = "Civ13 LOCAL boat verification"
		// Prepare only this temporary world's capture area; no production storage.
		for(var/x in 32 to 58)
			for(var/y in 28 to 50)
				var/turf/T = locate(x,y,1)
				for(var/atom/movable/M in T)
					qdel(M)
				T.ChangeTurf(/turf/floor/beach/water/shallowsaltwater/vehicle_probe, FALSE, FALSE)
		if(world.params["tank_only"])
			run_tank_tests()
			phase = "Tank-only assertions completed"
			save_result()
			del(world)
			return
		for(var/size in list(2,3,5))
			var/obj/structure/vehicleparts/axis/ship/A = make_boat(38,44,size==3 ? 2 : size,size)
			check(A.components.len == size*size,"real assembly [size] turning square")
			var/list/before = snapshot(A)
			for(var/tdir in list("left","right"))
				for(var/i=1,i<=4,i++)
					check(A.do_matrix(A.dir,turn(A.dir,tdir=="left" ? 90 : -90),tdir),"real [size] [tdir] quarter turn [i]")
				check(same_locations(before),"real [size] [tdir] full rotation preserves hull/passenger/cargo/fixtures")
			check(A.do_vehicle_check(),"real sail/weight/water preflight [size]")
			check(A.do_move(),"real forward movement [size]")
			A.reverse = TRUE
			check(A.do_vehicle_check() && A.do_move(),"real reverse movement [size]")
			check(same_locations(before),"real forward/reverse preserves all members [size]")
			A.reverse = FALSE
			// A square hull turns within its existing footprint. Use the rectangular
			// case for a valid shoreline destination that starts outside the deck.
			if(size == 3)
				var/turf/T = locate(40,44,1)
				T.ChangeTurf(/turf/floor/beach, FALSE, FALSE)
				check(!A.do_matrix(NORTH,EAST,"right") && same_locations(before),"real shoreline turn rejected without hull movement")
				T = locate(40,44,1)
				T.ChangeTurf(/turf/floor/beach/water/shallowsaltwater/vehicle_probe, FALSE, FALSE)
			clear()
		run_tank_tests()
		phase = "Full-game assertions completed"
		save_result()
		if(world.params["visual"])
			prepare_visual()
		else
			del(world)
	catch(var/exception/e)
		failures++
		phase = "Probe exception during [phase]: [e] ([e.file]:[e.line])"
		save_result()
		world.log << "BOAT EXCEPTION: [e]"
		if(!world.params["visual"])
			del(world)
/datum/boat_game_probe/proc/prepare_visual()
	clear()
	for(var/x in 72 to 95)
		for(var/y in 30 to 55)
			var/turf/T = locate(x,y,1)
			for(var/atom/movable/M in T)
				qdel(M)
				if(M) del(M)
			T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	tank = make_tank()
	main = make_boat(38,44,2,3)
	large = make_boat(48,44,5,5)
	outside = new(locate(40,42,1))
	outside.name = "LOCAL off-deck item (outside before/right turn)"
	owned += outside
	shore = locate(40,44,1)
	shore = shore.ChangeTurf(/turf/floor/beach, FALSE, FALSE)
	phase = "READY: shore blocks the next right turn; Run local boat sequence demonstrates rejection then restored-water rotation"
	save_result()
/datum/boat_game_probe/proc/sequence(client/viewer)
	if(running || failures)
		return
	running = TRUE
	phase = "1: rejecting shoreline right turn"
	var/list/before = snapshot(main)
	check(!main.do_matrix(NORTH,EAST,"right") && same_locations(before),"visual shore rejection preserves crew and hull")
	to_chat(viewer, phase)
	sleep(20)
	shore = shore.ChangeTurf(/turf/floor/beach/water/shallowsaltwater/vehicle_probe, FALSE, FALSE)
	phase = "2: test scene restores water; successful right turn; off-deck item stays at 40,42"
	check(main.do_matrix(NORTH,EAST,"right"),"visual quarter turn")
	check(outside && outside.loc == locate(40,42,1),"visual off-deck item stays put")
	to_chat(viewer, phase)
	sleep(30)
	check(main.do_matrix(EAST,NORTH,"left"),"visual return turn")
	phase = "3: moving two tiles north away from the off-deck item"
	for(var/i=1,i<=2,i++)
		check(main.do_vehicle_check() && main.do_move(),"visual forward step [i]")
		sleep(10)
	for(var/tdir in list("right","left"))
		phase = "4: rectangular hull four [tdir] turns"
		for(var/i=1,i<=4,i++)
			check(main.do_matrix(main.dir,turn(main.dir,tdir=="left" ? 90 : -90),tdir),"visual rectangle [tdir] turn [i]")
			sleep(10)
	for(var/i=1,i<=4,i++)
		phase = "5: 5x5 hull right turn [i]"
		check(large.do_matrix(large.dir,turn(large.dir,-90),"right"),"visual large turn [i]")
		sleep(10)
	phase = "COMPLETE: real quarter/full turns and shore rejection; all [passed] checks, failures=[failures]"
	to_chat(viewer, phase)
	running = FALSE
	save_result()
/client/verb/inspect_boat_probe()
	set name = "Inspect local boat probe"
	set category = "Local Verification"
	if(!world.params["visual"])
		return
	src << browse(null,"window=playersetup")
	screen.Cut()
	mob.sight = SEE_TURFS | SEE_OBJS | SEE_MOBS | SEE_SELF
	mob.see_in_dark = 8
	eye = locate(45,43,1)
	perspective = EYE_PERSPECTIVE
	view = 10
	to_chat(src,"<b>LOCAL isolated boat verification</b><br>Commit: [world.params["tested_commit"]]<br>BYOND [world.byond_version].[world.byond_build], map [map.ID] [world.maxx]x[world.maxy]x[world.maxz]<br>[file2text("boat-result.txt")]<br>Test-only water/shore scene and actors; production boat assembly, transforms, icons and callbacks.<br>[boat_game_probe.phase]")
/client/verb/run_boat_probe()
	set name = "Run local boat sequence"
	set category = "Local Verification"
	if(world.params["visual"])
		boat_game_probe.sequence(src)

/datum/boat_game_probe/proc/tank_sequence(client/viewer)
	if(running || failures)
		return
	running = TRUE
	phase = "Tank: ordinary player entry callback during first turn must stay outside"
	entry_actor = new(locate(77,44,1))
	entry_actor.name = "LOCAL outside entry actor"
	entry_actor.real_name = entry_actor.name
	owned += entry_actor
	entry_target = locate(78,44,1)
	entry_attempted = FALSE
	var/obj/structure/vehicleparts/frame/first = tank.loc
	GLOB.moved_event.register(first,src,/datum/boat_game_probe/proc/attempt_entry)
	check(tank.do_matrix(NORTH,EAST,"right"),"visual tank callback turn")
	GLOB.moved_event.unregister(first,src,/datum/boat_game_probe/proc/attempt_entry)
	check(entry_actor.loc == locate(77,44,1),"visual tank outsider remains outside")
	to_chat(viewer,phase)
	sleep(30)
	tank.do_matrix(EAST,NORTH,"left")
	entry_actor = null
	entry_target = null
	for(var/tdir in list("right","left"))
		for(var/i=1,i<=4,i++)
			phase = "Tank: [tdir] quarter turn [i], real T34 frames/tracks/cannon"
			check(tank.do_matrix(tank.dir,turn(tank.dir,tdir=="left" ? 90 : -90),tdir),"visual tank [tdir] turn [i]")
			sleep(10)
	phase = "Tank: two actual forward movement steps"
	for(var/i=1,i<=2,i++)
		check(tank.do_vehicle_check() && tank.do_move(),"visual tank forward [i]")
		sleep(10)
	var/obj/item/weapon/grenade/frag/vehicle_probe/G = new(locate(81,46,1))
	owned += G
	G.det_time = 50
	G.active = TRUE
	G.activate()
	phase = "Tank: real primed exterior grenade remains at 81,46; fuse and blast are not suppressed"
	check(tank.do_matrix(NORTH,EAST,"right"),"visual tank grenade turn")
	tank.add_transporting()
	check(G && G.loc == locate(81,46,1) && !(G in tank.transporting),"visual grenade stays exterior at original tile")
	to_chat(viewer,phase)
	sleep(60)
	phase = "Tank COMPLETE: [passed] assertions, failures=[failures]; real grenade exploded at its floor location"
	running = FALSE
	to_chat(viewer,phase)
	save_result()
/client/verb/inspect_tank_probe()
	set name = "Inspect local tank probe"
	set category = "Local Verification"
	if(!world.params["visual"])
		return
	src << browse(null,"window=playersetup")
	screen.Cut()
	mob.sight = SEE_TURFS | SEE_OBJS | SEE_MOBS | SEE_SELF
	mob.see_in_dark = 8
	eye = locate(81,44,1)
	perspective = EYE_PERSPECTIVE
	view = 10
	to_chat(src,"<b>LOCAL production-assembled T34 verification</b><br>Commit: [world.params["tested_commit"]]<br>BYOND [world.byond_version].[world.byond_build], map [map.ID] [world.maxx]x[world.maxy]x[world.maxz]<br>[file2text("boat-result.txt")]<br>Test-only actor/callback setup; real frames/tracks/engine/movement, ordinary human Move and grenade blast.<br>[boat_game_probe.phase]")
/client/verb/run_tank_probe()
	set name = "Run local tank sequence"
	set category = "Local Verification"
	if(world.params["visual"])
		boat_game_probe.tank_sequence(src)
