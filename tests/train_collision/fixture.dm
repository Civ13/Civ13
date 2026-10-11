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
	New()
		..()
		spawn(1) run_tests()
/proc/run_tests()
	var/obj/structure/trains/A = new(locate(5,5,1))
	var/obj/structure/trains/B = new(locate(4,5,1))
	A.dir = EAST
	B.dir = WEST
	A.connected = B
	B.connected = A
	world.log << "START cyclic connection Move"
	A.Move(locate(6,5,1),EAST)
	world.log << "END cyclic connection Move"
	del(world)

