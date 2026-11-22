// ============================================================
// Travel posts become signposts (docs/ocean-regions.md, "Switch-on")
// ------------------------------------------------------------
// Once the host turns on edge travel (shard_group edge_travel_oceans), every
// part of Earth is reached by walking, riding, sailing or flying off a map
// edge, so the posts that sent people elsewhere go:
// - building a trail marker is refused (region_trail_build_refusal) and
//   admins cannot place trails (place_region_trail);
// - every trail marker and plain trail standing in the world becomes a
//   signpost in the same spot, keeping its name, with its 10 wood beside it.
//   Its old destination goes to the admin log, and a player still waiting on
//   a trail request is told.
// Launch pads, railway stations and the hidden gates of crossings are other
// kinds of gate and stay. The sweep runs once a minute after the world has
// loaded, so posts restored from a save and any built meanwhile are caught.
// ============================================================

#define REGION_POSTS_SWEEP 600
#define REGION_POSTS_REFUND 10

var/global/region_posts_timer = 0

// TRUE for a gate that is a travel post: a trail marker or a plain trail.
/proc/region_post_retired_kind(obj/structure/region_gate/G)
	return G && (G.type == /obj/structure/region_gate || G.type == /obj/structure/region_gate/trail_marker)

// Turns one post into a signpost. Returns the signpost, or null.
/proc/region_post_retire(obj/structure/region_gate/G)
	if (!region_post_retired_kind(G) || QDELETED(G))
		return null
	var/turf/T = get_turf(G)
	if (!T || G.busy)
		return null
	for (var/mob/M in G.contents)
		return null // someone is on their way through it
	var/was = G.destination
	var/obj/structure/region_gate/trail_marker/M = G
	if (istype(M))
		if (!was)
			was = M.requested_destination
		if (M.requester_ckey && !M.approved && M.requested_destination)
			var/client/C = directory[M.requester_ckey]
			if (C)
				to_chat(C, SPAN_NOTICE("Your trail request toward [region_trail_name(M.requested_destination)] is closed: lands are now reached by going off the edge of the map."))
	var/obj/structure/sign/signpost/S = new(T)
	S.name = G.name
	S.desc = "An old marker of the way to distant lands. Now the land itself goes on: walk, ride or sail off its edge, or fly off it."
	S.dir = G.dir
	S.pixel_x = G.pixel_x
	S.pixel_y = G.pixel_y
	var/obj/item/stack/material/wood/W = new(T)
	W.amount = REGION_POSTS_REFUND
	W.update_icon()
	log_game("Travel posts: [G.name] ([G.type]) at [T.x],[T.y],[T.z] became a signpost; it led to [was || "nowhere"].")
	qdel(G)
	return S

// Retires every post in the world. Returns how many.
/proc/region_posts_retire_all()
	. = 0
	if (!sea_edge_travel_on() || persistence_save_in_progress)
		return
	for (var/obj/structure/region_gate/G in region_gates.Copy())
		if (region_post_retire(G))
			.++
	if (.)
		message_admins("[.] travel post\s became signposts: lands are now reached over the map edges.")

/proc/region_posts_tick()
	if (!persistence_player_restore_ready)
		return
	region_posts_retire_all()

/hook/roundstart/proc/region_posts_begin()
	if (!region_posts_timer)
		region_posts_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(region_posts_tick)), REGION_POSTS_SWEEP, TIMER_LOOP | TIMER_STOPPABLE)
	return TRUE

#undef REGION_POSTS_SWEEP
#undef REGION_POSTS_REFUND
