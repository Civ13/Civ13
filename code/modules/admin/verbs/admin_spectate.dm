// Admin spectating tools (admins and moderators).
//
// "Hide Ghost" makes the admin's observer ghost invisible to every other
// player and ghost. It stays on for later aghosts until switched off.
//
// "View As Player" shares a player's camera: the admin's ghost follows the
// player, and the admin's client mirrors that player's eye, view size, screen
// (HUD, plane masters, darkness and line-of-sight masks) and client images, and
// copies the body's sight flags, so the admin sees what the player sees. A
// transparent shield over the mirrored screen swallows clicks, so nothing on the
// player's HUD can be used from the admin's side. Moving the ghost, following
// someone else, re-entering a body or "Stop Viewing Player" ends it.

#define ADMIN_VIEW_SYNC_DELAY 1 // deciseconds between camera syncs

var/global/list/datum/admin_player_view/admin_player_views = list()

/client/var/tmp/admin_ghost_hidden = FALSE
/client/var/tmp/datum/admin_player_view/admin_player_view

/mob/observer/ghost/var/tmp/admin_hidden = FALSE

/proc/admin_spectate_allowed(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_MOD))

// Hides or shows this ghost to everyone else. SEE_SELF keeps it visible to its owner.
/mob/observer/ghost/proc/set_admin_hidden(hidden)
	hidden = hidden ? TRUE : FALSE
	if (admin_hidden == hidden)
		return
	admin_hidden = hidden
	if (hidden)
		invisibility = INVISIBILITY_MAXIMUM
		if (ghost_image)
			ghost_darkness_images -= ghost_image
			ghost_sightless_images -= ghost_image
			for (var/client/C in clients)
				C.images -= ghost_image
	else
		invisibility = initial(invisibility)
		if (ghost_image)
			if (ghost_image_flag & GHOST_IMAGE_DARKNESS)
				ghost_darkness_images |= ghost_image
			if (ghost_image_flag & GHOST_IMAGE_SIGHTLESS)
				ghost_sightless_images |= ghost_image
	updateallghostimages()

// True when this ghost should be left out of lists shown to user (players' follow/jump lists).
/mob/observer/ghost/proc/admin_hidden_from(mob/user)
	return admin_hidden && !(user && user.client && user.client.holder)

// getfitmobs() for the ghost Follow / Jump to Mob verbs, without hidden admin ghosts for non-staff.
/proc/ghost_follow_targets()
	var/list/mobs = getfitmobs()
	for (var/name in mobs.Copy())
		var/mob/observer/ghost/G = mobs[name]
		if (istype(G) && G.admin_hidden_from(usr))
			mobs -= name
	return mobs

/client/proc/toggle_admin_ghost_hidden()
	set category = "Admin"
	set name = "Hide Ghost"
	set desc = "Toggle whether your admin ghost is visible to players and other ghosts."
	if (!check_rights(R_ADMIN|R_MOD))
		return
	admin_ghost_hidden = !admin_ghost_hidden
	if (isghost(mob))
		var/mob/observer/ghost/G = mob
		G.set_admin_hidden(admin_ghost_hidden)
	if (admin_ghost_hidden)
		to_chat(src, SPAN_NOTICE("Your ghost is now hidden from players and other ghosts. It stays hidden whenever you aghost until you switch this off."))
	else
		to_chat(src, SPAN_NOTICE("Your ghost is visible again."))
	log_admin("[key_name(src)] [admin_ghost_hidden ? "hid" : "unhid"] their admin ghost")

/client/proc/admin_view_player()
	set category = "Admin"
	set name = "View As Player"
	set desc = "See exactly what a player sees, sharing their camera."
	if (!check_rights(R_ADMIN|R_MOD))
		return
	var/list/choices = list()
	for (var/mob/M in mob_list)
		if (!M.client || M == mob || isnewplayer(M) || !get_turf(M))
			continue
		choices["[M.real_name || M.name] ([M.ckey])"] = M
	if (!choices.len)
		to_chat(src, SPAN_WARNING("No connected player is in the game world."))
		return
	var/pick = input(src, "Whose view do you want to share?", "View As Player") as null|anything in sortList(choices)
	if (!pick)
		return
	admin_start_player_view(choices[pick])

/client/proc/admin_stop_player_view()
	set category = "Admin"
	set name = "Stop Viewing Player"
	set desc = "Stop sharing a player's camera."
	if (!admin_player_view)
		to_chat(src, SPAN_WARNING("You are not viewing anyone."))
		return
	admin_player_view.stop(TRUE)

// Starts sharing M's camera, aghosting first. Returns TRUE when the view started.
/client/proc/admin_start_player_view(mob/M)
	if (!admin_spectate_allowed(src))
		return FALSE
	if (!istype(M) || QDELETED(M) || !get_turf(M))
		to_chat(src, SPAN_WARNING("That mob is not in the game world any more."))
		return FALSE
	if (M == mob || isnewplayer(M))
		to_chat(src, SPAN_WARNING("You cannot view that mob."))
		return FALSE
	if (!config.allow_admin_jump)
		WWalert(src, "Admin jumping is disabled", "View As Player")
		return FALSE
	if (!isghost(mob))
		if (istype(mob, /mob/new_player))
			to_chat(src, SPAN_WARNING("Join or Observe first."))
			return FALSE
		admin_ghost()
		sleep(2)
	if (!isghost(mob) || M == mob)
		return FALSE
	if (admin_player_view)
		admin_player_view.stop(FALSE)
	var/datum/admin_player_view/V = new(src, mob, M)
	if (!V.start())
		return FALSE
	log_admin("[key_name(src)] started viewing as [key_name(M)]")
	message_admins("[key_name_admin(src)] is viewing as [key_name_admin(M)]")
	return TRUE

// Swallows clicks over the mirrored HUD so the admin cannot press the player's buttons.
/obj/screen/admin_view_shield
	name = ""
	icon = 'icons/mob/screen1_full.dmi'
	icon_state = "blank"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	plane = HUD_PLANE
	layer = 1000
	mouse_opacity = 2

/obj/screen/admin_view_shield/Click()
	return

/obj/screen/admin_view_label
	name = "stop viewing"
	icon = null
	screen_loc = "CENTER-3,NORTH"
	plane = HUD_PLANE
	layer = 1001
	mouse_opacity = 2
	maptext_width = 224
	maptext_height = 32
	maptext_y = 4
	var/datum/admin_player_view/view

/obj/screen/admin_view_label/Click()
	if (view && usr && usr.client == view.viewer)
		view.stop(TRUE)

/obj/screen/admin_view_label/Destroy()
	view = null
	return ..()

/datum/admin_player_view
	should_save = FALSE
	var/client/viewer
	var/mob/observer/ghost/ghost
	var/mob/target
	var/client/target_client // follows the player into a new body (death, ghosting)
	var/active = FALSE
	var/list/own_screen
	var/list/own_images
	var/own_view
	var/own_sight
	var/own_see_in_dark
	var/list/mirrored_screen = list() // atom = TRUE
	var/list/mirrored_images = list() // image = TRUE
	var/obj/screen/admin_view_shield/shield
	var/obj/screen/admin_view_label/label
	var/sync_timer

/datum/admin_player_view/New(client/C, mob/observer/ghost/G, mob/M)
	..()
	viewer = C
	ghost = G
	target = M
	target_client = M.client

/datum/admin_player_view/Destroy()
	if (active)
		stop(FALSE)
	admin_player_views -= src
	QDEL_NULL(shield)
	QDEL_NULL(label)
	viewer = null
	ghost = null
	target = null
	target_client = null
	return ..()

/datum/admin_player_view/proc/start()
	if (!viewer || !ghost || viewer.mob != ghost || !target)
		qdel(src)
		return FALSE
	own_screen = viewer.screen.Copy()
	own_images = viewer.images.Copy()
	own_view = viewer.view
	own_sight = ghost.sight
	own_see_in_dark = ghost.see_in_dark
	shield = new
	label = new
	label.view = src
	ghost.ManualFollow(target)
	if (ghost.following != target)
		qdel(src)
		return FALSE
	active = TRUE
	viewer.admin_player_view = src
	admin_player_views += src
	relabel()
	if (!sync())
		stop(FALSE)
		return FALSE
	to_chat(viewer, SPAN_NOTICE("You are now seeing what [target] sees. Click the label at the top of the screen, use \"Stop Viewing Player\" or move your ghost to stop."))
	sync_timer = addtimer(CALLBACK(src, PROC_REF(tick)), ADMIN_VIEW_SYNC_DELAY, TIMER_LOOP | TIMER_STOPPABLE)
	return TRUE

/datum/admin_player_view/proc/tick()
	if (active && !sync())
		stop(TRUE)

/datum/admin_player_view/proc/relabel()
	if (label)
		label.maptext = "<span style='color:#ffd24a;font-family:Verdana;font-size:7pt;-dm-text-outline:1px black'>Viewing as [html_encode(target ? target.name : "?")] - click to stop</span>"

// Follows the player into another body when their client moves (death, ghosting, cloning).
/datum/admin_player_view/proc/follow_player_client()
	if (!target_client || QDELETED(target_client.mob) || target_client.mob == target)
		return
	var/mob/M = target_client.mob
	if (M == ghost || isnewplayer(M) || !get_turf(M))
		return
	target = M
	ghost.ManualFollow(M)
	relabel()

// One camera sync. FALSE ends the view.
/datum/admin_player_view/proc/sync()
	if (!active || !viewer || QDELETED(ghost) || viewer.mob != ghost || !admin_spectate_allowed(viewer))
		return FALSE
	follow_player_client()
	if (QDELETED(target) || ghost.following != target)
		return FALSE
	var/client/T = target.client
	var/atom/eye = (T && T.eye) ? T.eye : target
	if (viewer.eye != eye)
		viewer.eye = eye
	if (viewer.perspective != EYE_PERSPECTIVE)
		viewer.perspective = EYE_PERSPECTIVE
	var/wanted_view = T ? T.view : own_view
	if (viewer.view != wanted_view)
		viewer.view = wanted_view
	var/px = T ? T.pixel_x : 0
	var/py = T ? T.pixel_y : 0
	if (viewer.pixel_x != px)
		viewer.pixel_x = px
	if (viewer.pixel_y != py)
		viewer.pixel_y = py
	ghost.sight = target.sight
	ghost.see_invisible = target.see_invisible
	ghost.see_in_dark = target.see_in_dark

	var/list/want = list()
	if (T)
		for (var/A in T.screen)
			want[A] = TRUE
	else if (ghost.hud_used)
		// A body with nobody in it has no HUD; keep the admin's own plane masters so lighting still draws.
		for (var/key in ghost.hud_used.plane_masters)
			var/P = ghost.hud_used.plane_masters[key]
			if (P)
				want[P] = TRUE
	want[shield] = TRUE
	want[label] = TRUE
	mirrored_screen = mirror(viewer.screen, want)

	want = list()
	if (T)
		for (var/I in T.images)
			want[I] = TRUE
	mirrored_images = mirror(viewer.images, want)
	return TRUE

// Makes current (a client's screen or images) hold exactly the keys of want. Returns want.
/datum/admin_player_view/proc/mirror(list/current, list/want)
	var/list/have = list()
	var/list/remove = list()
	for (var/A in current)
		if (!A || !want[A])
			remove += A
		else
			have[A] = TRUE
	var/list/add = list()
	for (var/A in want)
		if (!have[A])
			add += A
	if (remove.len)
		current -= remove
	if (add.len)
		current += add
	return want

// Ends the view. restore puts the admin's own screen, images and eye back when
// they are still in the same ghost; a new mob's Login rebuilds them otherwise.
/datum/admin_player_view/proc/stop(restore = TRUE)
	if (!active)
		return
	active = FALSE
	admin_player_views -= src
	if (sync_timer)
		deltimer(sync_timer)
		sync_timer = null
	if (viewer && viewer.admin_player_view == src)
		viewer.admin_player_view = null
	if (viewer && !QDELETED(ghost) && viewer.mob == ghost)
		viewer.screen -= mirrored_screen
		viewer.images -= mirrored_images
		if (restore)
			for (var/atom/A in own_screen)
				if (!QDELETED(A))
					viewer.screen |= A
			for (var/I in own_images)
				if (I)
					viewer.images |= I
		viewer.eye = ghost
		viewer.perspective = MOB_PERSPECTIVE
		viewer.view = own_view
		viewer.pixel_x = 0
		viewer.pixel_y = 0
		ghost.sight = own_sight
		ghost.see_in_dark = own_see_in_dark
		ghost.updateghostsight()
		if (target && ghost.following == target)
			ghost.stop_following()
		to_chat(viewer, SPAN_NOTICE("You stopped viewing as [target ? target : "the player"]."))
	mirrored_screen = list()
	mirrored_images = list()
	own_screen = null
	own_images = null
	if (!QDELING(src))
		qdel(src)

#undef ADMIN_VIEW_SYNC_DELAY
