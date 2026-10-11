#define TRUE 1
#define FALSE 0
#define OPPOSITE_DIR(d) turn(d,180)
#define SPAN_WARNING(s) s
/proc/isemptylist(list/L)
	return !L || !L.len
/proc/get_turf(atom/A)
	while(A && !isturf(A))
		A = A.loc
	return A
/proc/to_chat(mob/M, message)
/proc/qdel(datum/D)
	del(D)
/atom/movable/proc/forceMove(atom/A)
	loc = A
	return TRUE
/obj/proc/update_icon()
/obj/proc/Destroy()
	del(src)
/obj/structure
/obj/structure/vehicleparts
/obj/structure/vehicleparts/axis
	var/list/components = list()
	var/list/wheels = list()
	var/list/corners = list()
	var/list/matrix = list()
	var/list/matrix_current_locs = list()
	var/list/transporting = list()
	var/maxdist = 5
	var/matrix_l
	var/matrix_h
	var/moving = FALSE
	var/currentspeed = 0
	var/reverse = FALSE
/obj/structure/vehicleparts/frame
	var/obj/structure/vehicleparts/axis/axis
	var/obj/structure/vehicleparts/movement/mwheel
/obj/structure/vehicleparts/frame/ship
/obj/structure/vehicleparts/movement
	var/obj/structure/vehicleparts/axis/axis
	var/obj/structure/vehicleparts/frame/connected
	var/reversed = FALSE
	var/ntype = "wheel"
/obj/structure/vehicleparts/movement/sail
/obj/structure/vehicleparts/axis/ship
/obj/effect/pseudovehicle
	var/obj/structure/vehicleparts/axis/link
/obj/item
/obj/structure/wild
/obj/structure/cannon
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
world
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
/proc/boat(w=2,h=3)
	var/obj/structure/vehicleparts/axis/ship/A = new(locate(15,25,1))
	A.dir = NORTH
	for(var/i=0,i<w,i++)
		for(var/j=0,j<h,j++)
			var/obj/structure/vehicleparts/frame/ship/F = new(locate(15+i,25-j,1))
			F.axis = A
			F.dir = NORTH
			A.components += F
	A.loc = A.components[1]
	A.check_corners()
	A.check_matrix()
	return A
/proc/run_tests()
	var/obj/structure/vehicleparts/axis/ship/A = boat()
	var/obj/item/outside = new(locate(17,25,1))
	var/turf/origin = outside.loc
	check(A.do_matrix(NORTH,EAST,"right"),"rectangular quarter turn")
	check(outside && outside.loc == origin,"object outside deck stays put")
	world.log << "RESULT failures=[failures]"
	del(world)
/obj/structure/vehicleparts/axis/proc/add_transporting()
