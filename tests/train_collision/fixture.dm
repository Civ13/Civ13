#define TRUE 1
#define FALSE 0
#define MOB_MEDIUM 2
#define OPPOSITE_DIR(d) turn(d,180)
#define isliving(a) istype(a,/mob/living)
var/datum/map_stub/map = new
/proc/to_chat(mob/M,message)
/proc/get_turf(atom/A)
	return A.loc
/datum/map_stub/proc/check_caribbean_block(mob/M,turf/T)
	return FALSE
/proc/playsound(atom/A,sound/S,volume,vary)
/atom/proc/set_light(n)
/atom/proc/visible_message(message)
/atom/proc/Bumped(atom/A)
/atom/movable
	var/anchored = FALSE
/atom/movable/Bump(atom/A)
	spawn(0)
		if(A) A.Bumped(src)
/atom/movable/proc/forceMove(atom/A)
	loc = A
/obj
	var/flammable
	var/not_movable
	var/not_disassemblable
	var/mob/living/buckled_mob
	var/w_class = 1
/obj/proc/ex_act(n)
/obj/structure
/obj/structure/rails
	var/switched
	var/sw_direction
	var/turn_dir
/obj/structure/rails/split/switcher
/obj/structure/rails/turn
/obj/structure/trains/transport
/obj/structure/trains/locomotive
	var/fuel = 100
/obj/structure/trains/locomotive/proc/set_speed()
/obj/item/proc/update_light()
/mob/living
	var/mob_size = 2
	var/obj/buckled
/mob/living/proc/adjustBruteLoss(n)
/mob/living/human
world
	maxx = 20
	maxy = 10
	maxz = 1
	fps = 10
#ifdef UNCHECKED
	loop_checks = FALSE
#endif
	New()
		..()
		spawn(1) run_tests()
/mob/living/human/proc/use_hitch(obj/structure/trains/T)
	usr = src
	return T.hitch()
var/failures = 0
/proc/check(condition, label)
	if (!condition)
		failures++
		world.log << "FAIL [label]"
	else
		world.log << "PASS [label]"
/proc/car(x,y,d = EAST)
	var/obj/structure/trains/T = new(locate(x,y,1))
	T.dir = d
	return T
/proc/rails()
	for (var/turf/T in world)
		var/obj/structure/rails/R = new(T)
		R.dir = EAST
/proc/clear_cars()
	for (var/obj/structure/trains/T in world)
		del(T)
/proc/run_tests()
#ifdef BASELINE
	var/obj/structure/trains/A = car(5,5,EAST)
	var/obj/structure/trains/B = car(6,5,WEST)
	var/mob/living/human/user = new(locate(5,4,1))
	user.use_hitch(A)
	user.use_hitch(B)
	world.log << "START cyclic connection Move"
	A.Move(locate(4,5,1),WEST)
	world.log << "END cyclic connection Move"
	del(world)
#else
	rails()
	var/mob/living/human/user = new(locate(5,4,1))
	var/obj/structure/trains/front = car(5,5,WEST)
	var/obj/structure/trains/back = car(4,5,EAST)
	check(user.use_hitch(back) && front.connected == back, "hitch attaches follower")
	check(!user.use_hitch(front) && !back.connected, "opposed hitch rejects reciprocal cycle")
	check(user.use_hitch(back) && !front.connected, "unhitch clears leader connection")
	clear_cars()
	var/obj/structure/trains/A = car(5,5)
	var/obj/structure/trains/B = car(4,5)
	var/obj/structure/trains/C = car(3,5)
	A.connected = B
	B.connected = C
	check(A.can_connect_to(C) == FALSE, "reject new coupling cycle")
	check(A.Move(locate(6,5,1),EAST), "three-car movement")
	check(A.x == 6 && B.x == 5 && C.x == 4, "followers occupy vacated turfs")
	B.connected = A
	check(!A.can_connect_to(C), "reject already cyclic coupling chain")
	check(A.Move(locate(7,5,1),EAST), "existing cyclic connection terminates")
	check(!A.moving_train && !B.moving_train, "movement guards released")
	clear_cars()
	A = car(5,5)
	B = car(4,5)
	A.connected = B
	var/turf/blocked = locate(6,5,1)
	blocked.density = TRUE
	var/mob/living/rider = new(A.loc)
	rider.density = FALSE
	var/obj/item/cargo = new(A.loc)
	cargo.anchored = TRUE
	A.transporting += cargo
	check(!A.Move(blocked,EAST), "blocked move returns failure")
	check(A.x == 5 && B.x == 4, "blocked move leaves followers in place")
	check(rider.x == 5 && cargo.x == 5, "blocked move leaves riders and cargo in place")
	check(!A.moving_train, "failed movement guard released")
	blocked.density = FALSE
	check(A.Move(blocked,EAST), "movement resumes after block removal")
	check(rider.x == 6 && cargo.x == 6, "successful move carries rider and cargo")
	del(rider)
	del(cargo)
	clear_cars()
	for (var/direction in list(WEST,EAST,NORTH))
		A = car(5,5,EAST)
		B = car(6,5,direction)
		A.automovement = TRUE
		check(!A.process_rail_movement(), "train collision stops direction [direction]")
		check(!A.automovement && A.health == 995 && A.x == 5 && B.x == 6, "collision preserves stop/damage direction [direction]")
		check(!B.Bumped(A) && B.x == 6, "train bump cannot push direction [direction]")
		sleep(2)
		check(A.x == 5 && B.x == 6, "no delayed train bump cascade direction [direction]")
		clear_cars()
	A = car(5,5)
	B = car(6,5)
	A.connected = B
	A.automovement = TRUE
	check(!A.process_rail_movement() && A.health == 995, "self-consist contact stops with existing damage")
	clear_cars()
	A = car(5,5)
	B = car(4,5)
	A.connected = B
	del(B)
	check(A.Move(locate(6,5,1),EAST), "deleted follower does not prevent movement")
	A.automovement = TRUE
	check(A.process_rail_movement() && A.x == 7, "normal automatic movement")
	world.log << "RESULT failures=[failures]"
	del(world)


#endif
