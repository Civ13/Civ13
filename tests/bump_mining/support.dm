#define TRUE 1
#define FALSE 0
#define INCAPACITATION_DEFAULT 1
#define OPPOSITE_DIR(D) turn(D,180)
/world
	maxx = 8
	maxy = 8
	maxz = 1
	fps = 10
	turf = /turf
	hub = ""
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Error(exception/E)
	text2file("runtime error: [E]", "errors.txt")
	del(world)
/datum
	var/should_save = TRUE
	var/gcDestroyed = FALSE
	var/gc_destroyed = FALSE
/client
	var/canmove = TRUE
	var/moving = FALSE
/client/New()
	return FALSE
/atom/proc/Adjacent(atom/A)
	return get_dist(src, A) <= 1 && z == A.z
/mob
	var/canmove = TRUE
	var/stat = 0
	var/lying = FALSE
	var/prone = FALSE
	var/resting = FALSE
	var/sleeping = FALSE
	var/buckled
	var/riding
	var/riding_mob
	var/using_drone
	var/control_object
	var/incorporeal_move
	var/using_object
	var/using_cannon
	var/football
	var/in_throw_mode
	var/now_pushing
	var/civilization
	var/original_job_title = ""
	var/next_click = -1
	var/next_move = -1
	var/hand = FALSE
	var/obj/item/l_hand
	var/obj/item/r_hand
	var/actions = 0
	var/starts = 0
	var/ends = 0
	var/parent_bumps = 0
/mob/proc/get_active_hand()
	return hand ? l_hand : r_hand
/mob/proc/get_inactive_hand()
	return hand ? r_hand : l_hand
/mob/proc/incapacitated(flags = 1)
	return stat
/mob/proc/restrained()
	return FALSE
/mob/proc/canClick()
	return next_move <= world.time
/mob/proc/getStatCoeff(statname)
	return 1
/mob/proc/survival_action_started()
	actions++
	starts++
/mob/proc/survival_action_finished()
	actions--
	ends++
/atom/proc/visible_message(a, b)
	return
/mob/living/Bump(atom/AM, yes)
	parent_bumps++
/mob/living/human/proc/football_bump(atom/A)
	return
/mob/living/human/probe/bump_mining_authority()
	return TRUE // Explicit headless client/movement ownership seam only.
/obj/item/football
/obj/item
	var/usespeed = 2
/obj/item/weapon/material/pickaxe
/obj/item/weapon/material/pickaxe/steel
/obj/item/weapon/material/kitchen/utensil
	usespeed = 0.2
/turf
	var/is_mineable = FALSE
	var/mining_in_progress = FALSE
	var/effects = 0
/turf/floor/dirt/underground
	density = TRUE
	is_mineable = TRUE
/turf/floor/dirt/underground/empty
	density = FALSE
/turf/proc/collapse_check()
	return
/turf/proc/mining_proc(mob/H)
	effects++ // Fixed output observer; not production yield/RNG acceptance.
/turf/floor/dirt/underground/empty/proc/mining_clear_debris()
	effects++
/datum/progressbar/New(user, delay, target)
	return
/datum/progressbar/proc/update(elapsed)
	return
/proc/playsound(a,b,c,d)
	return
/proc/qdel(datum/D)
	del(D)
