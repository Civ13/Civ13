//overlay chat mostly ported from BurgerStation, 17/05/2020

#define TILE_SIZE 32

/client
	var/obj/chat_text/chat_text
	var/list/stored_chat_text = list()
	var/list/seen_chat_text = list()

/client/proc/overlay_cleaner(message = null)
	spawn(50)
		if (message)
			src.images -= message

/obj/chat_text
	name = "overlay"
	desc = "overlay object"
	mouse_opacity = FALSE
	plane = CHAT_PLANE
	icon = null

	var/client/owner
	var/client/target
	var/image/message
/obj/chat_text/Destroy()
	if (owner)
		owner.stored_chat_text -= src
		owner.seen_chat_text -= src
		owner = null
	if (target)
		target.stored_chat_text -= src
		target.seen_chat_text -= src
		target.images -= src.message
		target = null
	message = null
	loc = null
	return ..()

// A bubble only ever shows as its client image; it never lies on the map.
/obj/chat_text/Move()
	return FALSE

/obj/chat_text/forceMove(atom/destination, var/special_event, list/throw_hop_token = null)
	loc = null
	return FALSE

/image/var/target = null
/image/var/owner = null

/obj/chat_text/New(var/mob/origin_loc, var/desired_text, var/mob/target_mob)
	// Out of the speaker at once: a bubble left inside a mob is dropped onto the
	// floor with its other contents and then lies there for good.
	loc = null
	..()
	loc = null
	if(isliving(origin_loc) && target_mob && target_mob.client)
		owner = origin_loc.client
		target = target_mob.client

		for (var/image/CT in target.images)
			if(CT.plane == CHAT_PLANE && (CT.loc == origin_loc || (owner && CT.owner == owner)))
				animate(CT,pixel_y = CT.pixel_y + 11,time = 1)

		message = image(loc = origin_loc)
		message.target = target
		message.owner = owner
		message.plane = CHAT_PLANE
		// Keep speech upright: do not inherit the speaker's lying or scale transform.
		message.appearance_flags |= RESET_TRANSFORM
		#ifdef OPENDREAM
		message.maptext_width = TILE_SIZE*5
		message.maptext_x = 0
		message.layer = 35
		#endif
		#ifndef OPENDREAM
		message.maptext_width = TILE_SIZE*7
		message.maptext_x = (maptext_width * -0.5)-TILE_SIZE*2.5
		#endif
		message.maptext_y = TILE_SIZE*1
		// RESET_TRANSFORM drops the standing scale, so lift text over the head of a larger human.
		if (ishuman(origin_loc))
			var/mob/living/human/H = origin_loc
			if (!H.lying && !H.prone && H.size_multiplier > 1)
				message.maptext_y += round(TILE_SIZE*(H.size_multiplier-1))
		message.maptext_height = TILE_SIZE*3
		message.maptext = "<center><span style=\"-dm-text-outline: 1 black; vertical-align: bottom;\">[desired_text]</span></center>"
		if(target)
			if (!(message in target.images))
				target.images += message
			target.overlay_cleaner(message)
		spawn(50)
			animate(message,alpha=0,time=10)
			sleep(10)
			if(src && !QDELETED(src))
				qdel(src)
	else
		qdel(src)

	return FALSE

/mob/proc/show_chat_overlay(var/mob/speaker, var/text, var/color = null)
	if (!client || !speaker || !text)
		return
	if (!client.is_preference_enabled(/datum/client_preference/show_chat_overlays))
		return

	var/overlay_text = text
	if (color)
		overlay_text = "<span style=\"color:[color];\">[overlay_text]</span>"

	var/obj/chat_text/CT = new/obj/chat_text(speaker, overlay_text, src)
	// A speaker who is not a living mob (a ghost) gets no bubble: it is gone
	// already and must not be kept in the client's lists for good.
	if (QDELETED(CT))
		return
	client.seen_chat_text += CT
	if (speaker.client)
		speaker.client.stored_chat_text += CT
