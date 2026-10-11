#define TRUE 1
#define QDELETED(a) (!a)
#define FALSE 0
#define OPPOSITE_DIR(d) turn(d,180)
#define SPAN_WARNING(s) s
#define TURN_LEFT(d) turn(d,90)
#define TURN_RIGHT(d) turn(d,-90)
/proc/playsound(atom/A,S,vary,volume)
/proc/isemptylist(list/L)
	return !L || !L.len
/proc/get_turf(atom/A)
	while(A && !isturf(A))
		A = A.loc
	return A
/proc/to_chat(mob/M, message)
/proc/qdel(datum/D)
	del(D)
/atom/movable
	var/anchored = FALSE
/atom/movable/proc/forceMove(atom/A)
	loc = A
	return TRUE
/obj/proc/update_icon()
/obj/proc/Destroy()
	del(src)
/obj/structure
/obj/structure/vehicleparts
/obj/structure/vehicleparts/axis
	var/doorcode = 0
	var/list/masts = list()
	var/obj/structure/engine/engine
	var/obj/item/wheel_stub/wheel
	var/reg_number = "fixture"
	var/list/components = list()
	var/list/wheels = list()
	var/list/corners = list()
	var/list/matrix = list()
	var/list/matrix_current_locs = list()
	var/list/transporting = list()
	var/tmp/transforming_vehicle = FALSE
	var/tmp/list/transform_tiles
	var/maxdist = 5
	var/matrix_l
	var/matrix_h
	var/ship = FALSE
	var/moving = FALSE
	var/currentspeed = 0
	var/reverse = FALSE
	var/anchor = FALSE
	var/movement_processes = 0
	var/current_weight = 200
	var/vehicle_m_delay = 1
	var/mob/driver
/obj/structure/vehicleparts/axis/proc/new_number()
/obj/structure/vehicleparts/frame
	var/doorcode = 0
	var/obj/structure/vehicleparts/axis/axis
	var/obj/structure/vehicleparts/movement/mwheel
/obj/structure/vehicleparts/frame/ship
/obj/structure/vehicleparts/movement
	var/obj/structure/vehicleparts/axis/axis
	var/obj/structure/vehicleparts/frame/connected
	var/reversed = FALSE
	var/ntype = "wheel"
/obj/structure/vehicleparts/movement/sail
	var/obj/item/sail/sails
	var/sails_on = TRUE
	var/broken = FALSE
/obj/structure/vehicleparts/axis/ship
	ship = TRUE
/obj/effect/pseudovehicle
	var/obj/structure/vehicleparts/axis/link
/obj/item
/obj/item/reentrant
	var/obj/structure/vehicleparts/axis/boat_axis
	var/armed = TRUE
	forceMove(atom/T)
		..()
		if(armed && boat_axis)
			armed = FALSE
			boat_axis.do_move()
/obj/item/deleting
	var/atom/movable/victim
	forceMove(atom/T)
		..()
		if(victim) qdel(victim)
/obj/structure/engine
	var/on = TRUE
	var/obj/structure/engine/fueltank
	var/engineclass
/obj/structure/engine/internal
/obj/structure/vehicleparts/axis/car
/obj/structure/bed/chair/drivers
	var/obj/structure/vehicleparts/axis/axis
	var/obj/item/wheel_stub/wheel
/obj/item/wheel_stub
	var/obj/structure/vehicleparts/frame/control
/obj/structure/vehicleparts/shipwheel
	var/obj/structure/vehicleparts/axis/ship
	var/lastdirchange = 0
/obj/item/weapon/reagent_containers/glass/barrel/fueltank
/obj/structure/lamp/lamp_small/tank
	var/obj/structure/engine/connection
/obj/structure/vehicleparts/license_plate
	var/obj/structure/vehicleparts/axis/axis
	var/reg_number
/obj/structure/vehicleparts/movement/MouseDrop(obj/structure/vehicleparts/frame/F)
var/datum/map_stub/map = new
/datum/map_stub
	var/list/caribbean_blocking_area_types = list()
	proc/faction1_can_cross_blocks()
		return TRUE
	proc/faction2_can_cross_blocks()
		return TRUE
/proc/get_area(atom/A)
	var/turf/T = get_turf(A)
	return T ? T.loc : null
/proc/ishuman(atom/A)
	return istype(A,/mob/living/human)
/atom/proc/visible_message(message,second)
/obj/structure/vehicleparts/axis/proc/check_engine()
	return 2
/obj/structure/vehicleparts/axis/proc/get_weight()
	return current_weight
/obj/structure/vehicleparts/axis/ship/proc/check_sails()
/obj/item/sail
/obj/item/weapon/grenade/proc/mark_vehicle_exterior(obj/structure/vehicleparts/axis/A, turf/T)
/obj/item/weapon/grenade/proc/is_vehicle_exterior(obj/structure/vehicleparts/axis/A)
	return FALSE
/obj/item/ammo_casing
/obj/item/mine/boobytrap
/obj/item/mine/ap
/obj/item/mine/at/proc/trigger(atom/A)
/obj/structure/mailbox
/obj/structure/barricade/antitank
/obj/structure/barricade/stone_h/cliffside
/mob/living/human/proc/adjustBruteLoss(n)
/mob/living/human/proc/Weaken(n)
/mob/living/simple_animal
	var/mob_size = 100
/mob/living/simple_animal/proc/adjustBruteLoss(n)
/obj/structure/wild
/obj/structure/cannon
	bound_width = 32
	bound_height = 64
/obj/structure/catapult
/obj/structure/turret/course/proc/turn_to_dir(d)
/obj/item/weapon/gun/projectile/automatic/stationary/proc/update_pixels(mob/M)
/obj/item/weapon/gun/projectile/automatic/stationary/autocannon
/obj/structure/barricade
	var/health = 1000
/obj/covers
/obj/structure/sign/traffic/zebracrossing
/obj/structure/sign/traffic/side
/obj/structure/sign/traffic/central
/obj/structure/rails
/obj/structure/cable
/obj/structure/redmailbox
/obj/structure/gate
/obj/structure/lamp/lamppost_small
/obj/structure/lamp/lamp_big/alwayson
/obj/structure/lamp/lamp_small/alwayson
/obj/structure/billboard
/mob/living
	var/obj/using_object
/mob/living/proc/crush()
	world.log << "CRUSH [src]"
	del(src)
/turf
	var/tmp/obj/structure/vehicleparts/axis/vehicle_transforming
/turf/floor/beach/water
/turf/floor/beach/water/ice
/turf/floor/trench/flooded
world
	turf = /turf/floor/beach/water
	maxx = 40
	maxy = 40
	maxz = 1
	fps = 10
	New()
		..()
		spawn(1) run_tests()
var/failures = 0
/proc/check(condition,label)
	world.log << "[condition ? "PASS" : "FAIL"] [label]"
	if(!condition) failures++
/proc/boat(w=2,h=3, axis_type=/obj/structure/vehicleparts/axis/ship, frame_type=/obj/structure/vehicleparts/frame/ship)
	var/obj/structure/vehicleparts/axis/A = new axis_type(locate(15,25,1))
	A.dir = NORTH
	for(var/i=0,i<w,i++)
		for(var/j=0,j<h,j++)
			var/obj/structure/vehicleparts/frame/F = new frame_type(locate(15+i,25-j,1))
			F.axis = A
			F.dir = NORTH
			A.components += F
	A.loc = A.components[1]
	A.check_corners()
	A.check_matrix()
	return A
/proc/clear_boats()
	for(var/obj/structure/vehicleparts/A in world) del(A)
	for(var/obj/effect/pseudovehicle/A in world) del(A)
	for(var/mob/living/M in world) del(M)
	for(var/obj/item/I in world) del(I)
/proc/snapshot(obj/structure/vehicleparts/axis/A)
	var/list/result = list()
	for(var/atom/movable/M in (A.components | A.transporting))
		result["\ref[M]"] = list(M,M.loc)
	return result
/proc/same_locations(list/before)
	for(var/id in before)
		var/list/entry = before[id]
		var/atom/movable/M = entry[1]
		if(!M || M.loc != entry[2]) return FALSE
	return TRUE
/proc/run_tests()
	// Exercise production autoassembler rather than assigning component membership here.
	var/obj/structure/vehicleparts/axis/ship/assembled = new(locate(15,25,1))
	assembled.dir = NORTH
	for(var/i=0,i<2,i++)
		for(var/j=0,j<3,j++)
			new /obj/structure/vehicleparts/frame/ship(locate(15+i,25-j,1))
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(15,24,1))
	var/obj/structure/vehicleparts/shipwheel/wheel = new(locate(15,25,1))
	new /obj/effect/autoassembler(locate(17,23,1))
	sleep(14)
	check(assembled.components.len == 9,"assembler limits rectangular boat placeholders to 3x3")
	check(istype(assembled.loc,/obj/structure/vehicleparts/frame/ship),"assembler nests axis in hull frame")
	check(mast in assembled.masts,"assembler registers mast")
	check(wheel.ship == assembled,"assembler links ship wheel")
	wheel.ship.moving = TRUE
	wheel.ship.currentspeed = 1
	var/turf/assembly_shore = new /turf/floor(locate(17,25,1))
	wheel.lastdirchange = -1000
	check(!wheel.turndir(null,"right"),"ship wheel reports rejected turn")
	check(wheel,"ship wheel survives attempted turn")
	new /turf/floor/beach/water(assembly_shore)
	if(wheel)
		wheel.lastdirchange = -1000
		check(wheel.turndir(null,"right"),"ship wheel performs water turn")
	clear_boats()
	var/obj/structure/vehicleparts/axis/ship/A = boat()
	var/obj/item/outside = new(locate(17,23,1))
	var/turf/origin = outside.loc
	var/mob/living/passenger = new(locate(15,25,1))
	var/obj/item/cargo = new(locate(16,24,1))
	check(A.do_matrix(NORTH,EAST,"right"),"rectangular quarter turn")
	check(outside && outside.loc == origin,"object outside deck stays put")
	check(passenger && passenger.x == 17 && passenger.y == 25,"passenger turns with deck")
	check(cargo && cargo.x == 16 && cargo.y == 24,"cargo at pivot survives")
	clear_boats()
	A = boat()
	var/turf/shore = new /turf/floor(locate(17,25,1))
	check(!A.do_matrix(NORTH,EAST,"right"),"shoreline rotation rejected")
	check(A.dir == NORTH && get_turf(A) == locate(15,25,1),"rejected turn preserves heading and hull")
	new /turf/floor/beach/water(shore)
	clear_boats()
	A = boat()
	var/obj/structure/vehicleparts/frame/other = new(locate(17,25,1))
	check(!A.do_matrix(NORTH,EAST,"right"),"other vehicle blocks turn")
	check(other && other.x == 17 && other.y == 25,"other vehicle preserved")
	clear_boats()
	A = boat()
	other = new /obj/structure/vehicleparts/frame(locate(16,24,1))
	check(!A.do_matrix(NORTH,EAST,"right"),"foreign frame on shared deck blocks turn")
	check(!(other in A.transporting),"foreign frame does not become cargo")
	clear_boats()
	A = boat()
	var/obj/item/scenery = new(locate(17,25,1))
	var/obj/covers/blocker = new(locate(17,24,1))
	blocker.density = TRUE
	check(!A.do_matrix(NORTH,EAST,"right"),"later obstacle rejects whole rotation")
	check(scenery && scenery.loc == locate(17,25,1),"failed turn does not delete earlier scenery")
	clear_boats()
	del(blocker)
	for(var/size in list(2,3,5))
		for(var/tdir in list("left","right"))
			A = boat(size == 3 ? 2 : size,size)
			passenger = new(locate(15,25,1))
			cargo = new(locate(16,24,1))
			var/obj/structure/cannon/fixture = new(locate(15,24,1))
			fixture.dir = WEST
			// Assembly fills only the rotation square with invisible placeholders.
			for(var/i=0,i<size,i++)
				for(var/j=0,j<size,j++)
					var/turf/T = locate(15+i,25-j,1)
					if(!(locate(/obj/structure/vehicleparts/frame) in T))
						var/obj/effect/pseudovehicle/PV = new(T)
						PV.link = A
						A.components += PV
			A.add_transporting()
			var/list/before = snapshot(A)
			for(var/turns=1,turns<=8,turns++)
				var/newdir = turn(A.dir,tdir == "left" ? 90 : -90)
				check(A.do_matrix(A.dir,newdir,tdir),"size [size] [tdir] quarter turn [turns]")
			check(same_locations(before),"size [size] [tdir] two full rotations no drift/loss")
			check(passenger && cargo && fixture,"size [size] [tdir] occupants and fixture survive")
			check(fixture.dir == WEST,"cannon retains independent aim")
			for(var/heading in list(NORTH,EAST,SOUTH,WEST))
				if(A.dir != heading)
					check(A.do_matrix(A.dir,heading,"right"),"turn toward heading [heading] before movement")
				var/list/move_before = snapshot(A)
				A.reverse = FALSE
				var/turf/old_axis_turf = get_turf(A)
				A.do_move()
				check(get_turf(A) == get_step(old_axis_turf,heading),"size [size] heading [heading] advances in commanded direction")
				A.reverse = TRUE
				A.do_move()
				check(same_locations(move_before),"size [size] heading [heading] advance/reverse no drift")
			clear_boats()
	A = boat()
	// Shift every hull member close to the east boundary without entering null.
	for(var/obj/F in A.components) F.loc = locate(F.x+24,F.y,1)
	A.dir = EAST
	for(var/obj/F in A.components) F.dir = EAST
	var/list/before = snapshot(A)
	A.do_move()
	check(same_locations(before),"movement edge failure preserves all hull parts")
	A.dir = NORTH
	for(var/obj/F in A.components) F.dir = NORTH
	check(!A.do_matrix(NORTH,EAST,"right"),"rotation at edge rejected")
	check(same_locations(before) && A.dir == NORTH,"edge turn preserves all hull parts and heading")
	clear_boats()
	A = boat(2,2)
	var/obj/item/reentrant/callback = new(locate(15,25,1))
	callback.boat_axis = A
	A.add_transporting()
	before = snapshot(A)
	for(var/turns=1,turns<=4,turns++)
		A.do_matrix(A.dir,turn(A.dir,-90),"right")
	check(same_locations(before),"reentrant movement callback cannot split hull")
	clear_boats()
	A = boat(2,2)
	var/obj/item/deleting/deletion = new(locate(15,25,1))
	var/obj/item/deleted_cargo = new(locate(16,24,1))
	deletion.victim = deleted_cargo
	A.add_transporting()
	before = snapshot(A)
	before.Remove("\ref[deleted_cargo]")
	for(var/turns=1,turns<=4,turns++)
		A.do_matrix(A.dir,turn(A.dir,-90),"right")
	check(!deleted_cargo && same_locations(before),"deleted cargo callback leaves other parts intact")
	check(!A.transforming_vehicle,"callback turn releases transform guard")
	clear_boats()
	A = boat(2,2)
	A.engine = new /obj/structure/engine(locate(15,25,1))
	A.currentspeed = 1
	A.moving = TRUE
	check(A.do_vehicle_check(),"powered boat movement preflight in water")
	A.add_transporting()
	before = snapshot(A)
	shore = new /turf/floor(locate(15,26,1))
	check(!A.do_vehicle_check(),"movement preflight rejects shoreline")
	check(!A.moving && A.currentspeed == 0 && same_locations(before),"shoreline stops boat without moving hull")
	new /turf/floor/beach/water(shore)
	A.currentspeed = 1
	A.moving = TRUE
	var/obj/structure/barricade/obstacle = new(locate(15,26,1))
	obstacle.density = TRUE
	check(!A.do_vehicle_check(),"movement preflight rejects solid obstacle")
	check(obstacle && same_locations(before),"blocked movement preserves obstacle and hull")
	del(obstacle)
	A.currentspeed = 1
	A.moving = TRUE
	A.movementloop()
	A.stopmovementloop()
	check(get_turf(A) == locate(15,26,1),"movement loop advances exactly one tile")
	sleep(3)
	check(A.movement_processes == 0,"stopped movement loop releases scheduled process")
	clear_boats()
#ifndef BASELINE
	A = boat(6,2)
	before = snapshot(A)
	check(!A.do_matrix(NORTH,EAST,"right") && same_locations(before),"unsupported oversized hull rejects turn without mutation")
	clear_boats()
#endif
	A = boat()
	for(var/i=0,i<5,i++)
		for(var/j=0,j<5,j++)
			var/turf/T = locate(15+i,25-j,1)
			if(!(locate(/obj/structure/vehicleparts/frame) in T))
				var/obj/effect/pseudovehicle/PV = new(T)
				PV.link = A
				A.components += PV
	A.add_transporting()
	check(A.components.len == 9,"existing assembly removes only excess invisible placeholders")
	before = snapshot(A)
	for(var/turns=1,turns<=4,turns++)
		A.do_matrix(A.dir,turn(A.dir,-90),"right")
	check(same_locations(before),"existing assembly full rotation has no stale placeholder drift")
	clear_boats()
	var/obj/structure/vehicleparts/axis/car/ground = boat(2,2,/obj/structure/vehicleparts/axis/car,/obj/structure/vehicleparts/frame)
	cargo = new(locate(16,24,1))
	passenger = new(locate(15,25,1))
	ground.add_transporting()
	before = snapshot(ground)
	for(var/turns=1,turns<=4,turns++)
		ground.do_matrix(ground.dir,turn(ground.dir,-90),"right")
	check(same_locations(before),"shared vehicle rotation preserves ordinary vehicle and cargo")
	clear_boats()
	world.log << "RESULT failures=[failures]"
	del(world)

/obj/structure/vehicleparts/axis/proc/do_vehicle_check()
/obj/structure/vehicleparts/axis/proc/movementloop()
/obj/structure/vehicleparts/axis/proc/stopmovementloop()
