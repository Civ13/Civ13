// Looking up: a player under open sky, in a stairwell, under a hole in a roof or
// at the foot of a ladder can turn their view to the level above, to see who
// stands on the roofs and walls around them. A roof or a floor overhead blocks
// it. The view stays on the level above until the player moves, presses again
// or can no longer look; a label at the top of the screen says so and stops it
// when clicked. The level above shows the level below through its open air
// (open_air_view.dm), so the player still sees the ground, darkened, around
// their own feet.
//
// IC > Look Up toggles it; so does Alt+clicking the HUD up arrow.

/mob/living/human/var/tmp/turf/looking_up_at = null
/mob/living/human/var/tmp/obj/screen/look_up_label/look_up_label = null

/mob/living/human/persistence_runtime_var(key)
	return key == "looking_up_at" || key == "look_up_label" || ..()

// The open-air cell straight above, or null with the reason in why[1].
/mob/living/human/proc/look_up_target(list/why)
	var/turf/here = loc
	if (!isturf(here))
		return look_up_refuse(why, "You can't see the sky from in here.")
	var/above_z = multiz_level_above(here.z)
	var/turf/above = above_z ? locate(here.x, here.y, above_z) : null
	if (!above)
		return look_up_refuse(why, "There is only sky above you.")
	if (locate(/obj/roof) in here)
		return look_up_refuse(why, "The roof over you blocks the view.")
	if (trapdoor_shut_at(above))
		return look_up_refuse(why, "A shut trapdoor above you blocks the view.")
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/P = dug_pit_above_ladder_site(here)
	if (P && P.dug_open_to_below(here))
		return above // A real dug aperture, even when the cave area is indoors.
	if (los_turf_roofed(here))
		return look_up_refuse(why, "The roof over you blocks the view.")
	if (P || !building_open_turf(above) || (locate(/obj/covers) in above))
		return look_up_refuse(why, "A floor above you blocks the view.")
	return above

/mob/living/human/proc/look_up_refuse(list/why, reason)
	if (why)
		why.Cut()
		why += reason
	return null

/mob/living/human/proc/look_up_can_see()
	if (stat || paralysis || stunned || weakened || eye_blind > 0 || using_drone)
		return FALSE
	return TRUE

/mob/living/human/proc/start_looking_up()
	if (!client)
		return FALSE
	if (!look_up_can_see())
		to_chat(src, SPAN_WARNING("You can't look up right now."))
		return FALSE
	var/list/why = list()
	var/turf/above = look_up_target(why)
	if (!above)
		to_chat(src, SPAN_WARNING(why.len ? why[1] : "You can't look up here."))
		return FALSE
	if (looking)
		look_into_distance(src, FALSE)
	if (laddervision)
		update_laddervision(null)
	looking_up_at = above
	client.perspective = EYE_PERSPECTIVE
	client.eye = above
	if (!look_up_label)
		look_up_label = new
		look_up_label.owner = src
	client.screen |= look_up_label
	to_chat(src, SPAN_NOTICE("You look up. Move, or look up again, to look back down."))
	return TRUE

/mob/living/human/proc/stop_looking_up(quiet = FALSE)
	if (!looking_up_at)
		return
	looking_up_at = null
	if (client)
		client.screen -= look_up_label
		if (client.eye != src && !laddervision)
			client.perspective = MOB_PERSPECTIVE
			client.eye = src
	if (look_up_label)
		qdel(look_up_label)
		look_up_label = null
	if (!quiet)
		to_chat(src, SPAN_NOTICE("You look back down."))

/mob/living/human/proc/toggle_look_up()
	if (looking_up_at)
		stop_looking_up()
		return TRUE
	return start_looking_up()

// Each vision update: keep the eye up there while nothing changed, else stop.
/mob/living/human/proc/look_up_vision()
	if (!looking_up_at)
		return
	if (!client || !look_up_can_see() || look_up_target() != looking_up_at)
		stop_looking_up()
		return
	client.perspective = EYE_PERSPECTIVE
	client.eye = looking_up_at

/mob/living/human/handle_vision()
	. = ..()
	look_up_vision()

/mob/living/human/verb/look_up_verb()
	set name = "Look Up"
	set category = "IC"
	set desc = "Look up at the level above, if nothing overhead blocks the view."
	toggle_look_up()

/obj/screen/look_up_label
	name = "stop looking up"
	icon = null
	screen_loc = "CENTER-5,NORTH-2"
	plane = HUD_PLANE
	layer = 1001
	mouse_opacity = 2
	maptext_width = 352
	maptext_height = 16
	should_save = FALSE
	maptext = "<span style='font-family:Verdana;font-size:8pt;text-align:center;color:#f2e6c8;-dm-text-outline:1px #1b140c'>Looking up: click here or move to stop</span>"
	var/tmp/mob/living/human/owner

/obj/screen/look_up_label/Click()
	if (owner && usr == owner)
		owner.stop_looking_up()
	return TRUE

/obj/screen/look_up_label/Destroy()
	owner = null
	return ..()
