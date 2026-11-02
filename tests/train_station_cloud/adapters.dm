// Isolated engine fixture seams. No game startup, save, shell, network or client.
#define TRUE 1
#define FALSE 0
#define MOB_MEDIUM 2
#define OPPOSITE_DIR(d) turn(d,180)
#define isliving(a) istype(a,/mob/living)
var/list/cardinal = list(NORTH,SOUTH,EAST,WEST)
var/datum/map_stub/map = new
/datum/map_stub/proc/check_caribbean_block(mob/M,turf/T)
	return FALSE
/proc/to_chat(mob/M,message)
/proc/get_turf(atom/A)
	while(A && !isturf(A))
		A = A.loc
	return A
/proc/playsound(atom/A,sound/S,volume,vary)
/proc/dir2text(d)
	return "[d]"
/atom/proc/set_dir(d)
	dir = d
	return TRUE
/atom/proc/set_light(n)
/atom/proc/update_icon()
/atom/proc/attack_hand(mob/M)
/atom/proc/visible_message(a,b,c)
/atom/proc/Bumped(atom/A)
/atom/movable
	var/anchored = FALSE
/atom/movable/Bump(atom/A)
	spawn(0)
		if(A) A.Bumped(src)
/atom/movable/proc/persistence_set_loc(atom/A)
	loc = A
	return loc == A
/atom/movable/proc/forceMove(atom/A)
	return persistence_set_loc(A)
/obj
	var/flammable
	var/not_movable
	var/not_disassemblable
	var/crushable
	var/mob/living/buckled_mob
	var/w_class = 1
/obj/proc/ex_act(n)
/obj/item/proc/update_light()
/obj/structure
/obj/structure/trains/transport
/mob/living
	density = FALSE
	var/mob_size = 2
	var/obj/buckled
/mob/living/proc/adjustBruteLoss(n)
/mob/living/human
/mob/living/human/proc/use_hitch(obj/structure/trains/T)
	usr = src
	return T.hitch()
/mob/living/human/proc/use_rotator(obj/structure/rails/rotate/R,right)
	usr = src
	if(right) return R.rotate_right()
	return R.rotate_left()
/client/New()
	del(src)
/world/OpenPort(p)
	return ..("none")
world
	maxx = 64
	maxy = 24
	maxz = 1
	fps = 10
	visibility = 0
	loop_checks = TRUE
