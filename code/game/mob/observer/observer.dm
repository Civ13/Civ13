var/const/GHOST_IMAGE_NONE = FALSE
var/const/GHOST_IMAGE_DARKNESS = TRUE
var/const/GHOST_IMAGE_SIGHTLESS = 2
var/const/GHOST_IMAGE_ALL = ~GHOST_IMAGE_NONE

/mob/observer
	density = FALSE
	invisibility = INVISIBILITY_OBSERVER
	layer = 11 // above areas now
	see_invisible = SEE_INVISIBLE_OBSERVER
	sight = SEE_TURFS|SEE_MOBS|SEE_OBJS|SEE_SELF
	simulated = FALSE
	stat = DEAD
	status_flags = GODMODE
	var/ghost_image_flag = GHOST_IMAGE_DARKNESS
	var/image/ghost_image = null //this mobs ghost image, for deleting and stuff

/mob/observer/New()
	..()
	ghost_image = image(icon,src)
	ghost_image.appearance = src
	ghost_image.appearance_flags = RESET_ALPHA
	if (ghost_image_flag & GHOST_IMAGE_DARKNESS)
		ghost_darkness_images |= ghost_image //so ghosts can see the eye when they disable darkness
	if (ghost_image_flag & GHOST_IMAGE_SIGHTLESS)
		ghost_sightless_images |= ghost_image //so ghosts can see the eye when they disable ghost sight
	updateallghostimages()

/mob/observer/Destroy()
	observer_mob_list -= src
	if (ghost_image)
		ghost_darkness_images -= ghost_image
		ghost_sightless_images -= ghost_image
		qdel(ghost_image)
		ghost_image = null
		updateallghostimages()
	. = ..()
/*
mob/observer/check_airflow_movable()
	return FALSE
*/
/mob/observer/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	return TRUE

/mob/observer/gib()		//observers can't be gibbed.
	return
