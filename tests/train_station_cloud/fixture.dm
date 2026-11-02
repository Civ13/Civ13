// Observer + scenario driver. Production rail, hitch, Move and timer procs are
// included unchanged except inert sound literals. No per-pulse teleport driver.
var/current_case = "startup"
var/sequence = 0
var/failures = 0
var/list/consist = list()
var/mob/living/human/operator
var/obj/structure/trains/locomotive/coal/proof/engine
var/target_x = 44
var/target_y = 0
var/list/levers = list()
/obj/structure/trains
	var/proof_id
/obj/structure/trains/locomotive/coal/proof/process_rail_movement()
	. = ..()
	frame("pulse", .)
	if(. && loc == at(target_x,target_y))
		// Scripted operator action at an observed tile, not an automatic signal.
		attack_hand(operator)
		emit(list("event"="target_stop","x"=x-10,"y"=y-12,"on"=on,"auto"=automovement,"method"="locomotive.attack_hand"))
	return .
/proc/at(px,py)
	return locate(px+10,py+12,1)
/proc/emit(list/row)
	sequence++
	if(sequence > 1024)
		world.log << "TRACE_CAP_FAILURE"
		del(world)
		return
	row["seq"] = sequence
	row["case"] = current_case
	row["tick"] = world.time
	row["source"] = SOURCE_PIN
	world.log << "TRAIN_TRACE [json_encode(row)]"
/proc/check(ok,label)
	if(!ok) failures++
	emit(list("event"="check","label"=label,"ok"=!!ok))
/proc/frame(kind,moved=FALSE)
	var/list/cars = list()
	for(var/obj/structure/trains/C in consist)
		cars += list(list("id"=C.proof_id,"x"=C.x-10,"y"=C.y-12,"dir"=C.dir,"health"=C.health,"icon"=C.icon_state,"next"=C.connected ? C.connected.proof_id : 0))
	var/list/switches = list()
	for(var/obj/structure/rails/split/switcher/S in world)
		switches += list(list("x"=S.x-10,"y"=S.y-12,"state"=S.switched,"dir"=S.dir,"icon"=S.icon_state))
	var/list/handles = list()
	for(var/obj/structure/train_lever/L in levers)
		handles += list(list("x"=L.x-10,"y"=L.y-12,"state"=L.switched,"icon"=L.icon_state))
	var/list/rotators = list()
	for(var/obj/structure/rails/rotate/R in world)
		rotators += list(list("x"=R.x-10,"y"=R.y-12,"dir"=R.dir,"icon"=R.icon_state))
	emit(list("event"="frame","kind"=kind,"moved"=!!moved,"cars"=cars,"switches"=switches,"levers"=handles,"rotators"=rotators,"on"=engine ? engine.on : FALSE,"auto"=engine ? engine.automovement : FALSE))
/proc/rail(path,px,py,d)
	var/obj/structure/rails/R = new path(at(px,py))
	// Mirrors recipe creation default SOUTH then facing rotation; set_dir must
	// update turn_dir on every crafted left-turn orientation.
	R.set_dir(d)
	return R
/proc/replace_rail(path,px,py,d)
	for(var/obj/structure/rails/R in at(px,py)) del(R)
	return rail(path,px,py,d)
/proc/lever(px,py)
	var/obj/structure/train_lever/L = new(at(px,py))
	levers += L
	return L
/proc/layout()
	var/list/rails = list()
	for(var/obj/structure/rails/R in world)
		rails += list(list("x"=R.x-10,"y"=R.y-12,"type"="[R.type]","dir"=R.dir,"turn"=R.turn_dir,"icon"=R.icon_state))
	emit(list("event"="layout","rails"=rails))
/proc/setup(name)
	current_case = name
	for(var/obj/O in world) del(O)
	for(var/turf/T in world) T.density = FALSE
	consist = list()
	levers = list()
	engine = null
	for(var/px=-8,px<=47,px++) rail(/obj/structure/rails/regular/horizontal,px,0,EAST)
	for(var/px=4,px<=17,px++) rail(/obj/structure/rails/regular/horizontal,px,1,EAST)
	replace_rail(/obj/structure/rails/split/switcher,4,0,EAST)
	replace_rail(/obj/structure/rails/split/switcher/right,16,1,EAST)
	replace_rail(/obj/structure/rails/split/switcher/right,22,0,EAST)
	for(var/px=22,px<=23,px++) rail(/obj/structure/rails/regular/horizontal,px,-1,EAST)
	rail(/obj/structure/rails/turn,24,-1,NORTH)
	rail(/obj/structure/rails/turn,24,-8,SOUTH)
	rail(/obj/structure/rails/turn,34,-8,EAST)
	rail(/obj/structure/rails/turn,34,-1,WEST)
	for(var/py=-7,py<=-2,py++)
		rail(/obj/structure/rails/regular,24,py,SOUTH)
		rail(/obj/structure/rails/regular,34,py,NORTH)
	replace_rail(/obj/structure/rails/rotate,24,-4,SOUTH)
	for(var/px=25,px<=33,px++) rail(/obj/structure/rails/regular/horizontal,px,-8,EAST)
	for(var/px=35,px<=37,px++) rail(/obj/structure/rails/regular/horizontal,px,-1,EAST)
	replace_rail(/obj/structure/rails/split/switcher,36,-1,EAST)
	for(var/px=25,px<=28,px++) rail(/obj/structure/rails/regular/horizontal,px,-4,EAST)
	lever(4,2)
	lever(16,3)
	lever(22,-2)
	lever(36,-3)
	if(!operator) operator = new(at(4,3))
	operator.loc = at(4,3)
	emit(list("event"="begin","world"=list(64,24,1),"offset"=list(10,12),"scope"="extracted native fixture"))
/proc/pull(index)
	var/obj/structure/train_lever/L = levers[index]
	operator.loc = get_step(L,NORTH)
	L.attack_hand(operator)
	frame("lever")
	sleep(10)
/proc/train(px=0,py=0,count=8)
	engine = new(at(px,py))
	engine.dir = EAST
	engine.fuel = 100
	engine.proof_id = 1
	consist += engine
	var/list/sprites = list("coal_wagon","flatbed_wagon","closed_wagon","cabinfloor","flatbed_wagon","closed_wagon","flatbed_wagon")
	for(var/i=2,i<=count,i++)
		var/obj/structure/trains/C = new(at(px-i+1,py))
		C.dir = EAST
		C.proof_id = i
		C.icon_state = sprites[i-1]
		consist += C
		operator.loc = get_step(C,NORTH)
		check(operator.use_hitch(C),"native hitch [i]")
	frame("initial")
/proc/start_to(px,py)
	target_x = px
	target_y = py
	engine.attack_hand(operator)
	check(engine.on && engine.automovement,"native locomotive start")
/proc/wait_stop()
	var/deadline = world.time + 600
	while(engine && engine.automovement && world.time < deadline) sleep(1)
	check(engine && !engine.automovement,"bounded native timer stop")
	if(!engine || engine.automovement)
		if(engine)
			engine.automovement = FALSE
			engine.on = FALSE
		return FALSE
	var/oldloc = engine.loc
	sleep(engine.train_speed+2)
	check(engine.loc == oldloc,"no movement after pending timer drains")
	frame("stopped")
	return TRUE
/proc/finish()
	emit(list("event"="end","failures"=failures))
/proc/route(name)
	setup(name)
	if(name == "passenger")
		pull(1)
		pull(2)
	if(name == "depot")
		pull(3)
		pull(4)
	sleep(6)
	layout()
	train()
	if(name == "passenger" || name == "depot")
		if(name == "passenger") start_to(13,1)
		else start_to(32,-8)
		if(!wait_stop())
			finish()
			return
		check(engine.loc == at(target_x,target_y),"service stop reached")
		var/oldloc = engine.loc
		sleep(10)
		check(engine.loc == oldloc,"service dwell remains stationary")
		frame("service_dwell")
	start_to(44,0)
	if(wait_stop())
		check(engine.loc == at(44,0),"engine reaches x44 on main")
		var/obj/structure/trains/tail = consist[8]
		check(tail.loc == at(37,0),"eight vehicle tail clears x36 merge")
		for(var/obj/structure/trains/C in consist) check(C.health == 1000,"no collision damage [C.proof_id]")
	finish()
/proc/controls()
	setup("lever_radius")
	var/obj/structure/rails/split/switcher/nearby = rail(/obj/structure/rails/split/switcher,6,4,EAST)
	var/obj/structure/rails/split/switcher/outside = rail(/obj/structure/rails/split/switcher,7,2,EAST)
	pull(1)
	check(nearby.switched == "split" && outside.switched == "forward","lever inclusive radius two")
	pull(1)
	check(nearby.switched == "forward" && outside.switched == "forward","lever reset")
	layout()
	finish()
	setup("detached_rotator")
	var/obj/structure/rails/rotate/R = locate(/obj/structure/rails/rotate) in at(24,-4)
	var/obj/structure/trains/A = new(at(24,-4))
	var/obj/structure/trains/B = new(at(25,-4))
	A.proof_id = 1
	B.proof_id = 2
	A.dir = SOUTH
	B.dir = EAST
	consist = list(A,B)
	operator.loc = at(23,-4)
	layout()
	frame("initial")
	sleep(10)
	operator.use_rotator(R,TRUE)
	frame("rotate_right")
	check(A.dir == EAST && B.dir == EAST && !A.connected && !B.connected,"right verb rotates only detached car on tile")
	sleep(10)
	operator.use_rotator(R,FALSE)
	frame("rotate_left")
	check(A.dir == SOUTH && B.dir == EAST,"left verb reverses platform orientation")
	sleep(10)
	R.attack_hand(operator)
	frame("rotate_hand")
	check(A.dir == EAST && B.dir == EAST,"hand rotation uses source cardinal cycle")
	finish()
	for(var/name in list("missing_siding_guard","missing_depot_guard","end_of_track","blocked_switch_target","wrong_facing_switch","fuel_stall"))
		setup(name)
		var/px = 16
		var/py = 1
		if(name == "missing_siding_guard")
			pull(2)
			for(var/obj/structure/rails/G in at(17,1)) del(G)
		if(name == "missing_depot_guard")
			px = 36
			py = -1
			pull(4)
			for(var/obj/structure/rails/G in at(37,-1)) del(G)
		if(name == "end_of_track")
			px = 47
			py = 0
		if(name == "blocked_switch_target" || name == "wrong_facing_switch")
			px = 4
			py = 0
			pull(1)
		if(name == "fuel_stall")
			px = 0
			py = 0
		train(px,py,1)
		if(name == "blocked_switch_target")
			var/obj/structure/trains/blocker = new(at(4,1))
			blocker.proof_id = 2
			consist += blocker
		if(name == "wrong_facing_switch")
			var/obj/structure/rails/S = locate(/obj/structure/rails/split/switcher) in at(4,0)
			S.set_dir(WEST)
		if(name == "fuel_stall")
			engine.fuel = 0
			engine.on = TRUE
		sleep(6)
		layout()
		frame("before_control")
		engine.automovement = TRUE
		var/oldloc = engine.loc
		var/ok = engine.process_rail_movement()
		if(name == "wrong_facing_switch")
			check(ok && engine.loc == at(5,0) && engine.dir == EAST,"opposing facing switch keeps straight heading")
		else
			check(!ok && !engine.automovement && engine.loc == oldloc,"unsafe route boundary stops without moving")
			check(engine.health == (name == "blocked_switch_target" ? 995 : 1000),"native collision health rule")
		engine.automovement = FALSE
		engine.on = FALSE
		frame("stopped")
		finish()
/world/New()
	OpenPort("none")
	spawn(1)
		check(world.port == 0,"native port closed")
		for(var/name in list("bypass","passenger","depot")) route(name)
		controls()
		emit(list("event"="complete","failures"=failures,"port"=world.port))
		del(world)
		return
