var/global/list/image/ghost_darkness_images = list() //this is a list of images for things ghosts should still be able to see when they toggle darkness
var/global/list/image/ghost_sightless_images = list() //this is a list of images for things ghosts should still be able to see even without ghost sight

/mob/observer/ghost
	name = "ghost"
	desc = "It's a g-g-g-g-ghooooost!" //jinkies!
	icon = 'icons/mob/mob.dmi'
	icon_state = "ghost2"
	canmove = FALSE
	blinded = FALSE
	anchored = TRUE	//  don't get pushed around
	var/can_reenter_corpse
	var/datum/hud/living/carbon/hud = null // hud
	var/started_as_observer //This variable is set to TRUE when you enter the game as an observer.
							//If you died in the game and are a ghsot - this will remain as null.
							//Note that this is not a reliable way to determine if admins started as observers, since they change mobs a lot.
	universal_speak = TRUE
	var/atom/movable/following = null
	var/admin_ghosted = FALSE
	var/anonsay = FALSE
	var/ghostvision = TRUE //is the ghost able to see things humans can't?
	var/seedarkness = TRUE

	incorporeal_move = TRUE

	var/original_icon = null
	var/list/original_overlays = list()

	//ghostcombat stuff
	var/combatmode = "melee"
	var/ghostlife = 100

/mob/observer/ghost/New(mob/body)
	see_in_dark = 100

	var/turf/T
	if (ismob(body))
		T = get_turf(body)				//Where is the body located?
		attack_log = body.attack_log	//preserve our attack logs by copying them to our ghost

		if (ishuman(body))
			icon = body:stand_icon
			overlays = body:overlays_standing
			original_icon = icon
			original_overlays = body:overlays_standing
		else
			icon = body.icon
			icon_state = body.icon_state
			original_icon = icon(icon, icon_state)
			original_overlays = overlays

		alpha = 127

		gender = body.gender

		if (body.real_name)
			name = body.real_name
		else
			if (body.mind.name)
				name = body.mind.name
			else
				if (gender == MALE)
					name = capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))
				else
					name = capitalize(pick(first_names_female)) + " " + capitalize(pick(last_names))

		mind = body.mind	//we don't transfer the mind but we keep a reference to it.

	if (!T)	T = get_turf(locate(1,1,world.maxz))			//Safety in case we cannot find the body's position
	forceMove(T)

	if (!name)							//To prevent nameless ghosts
		name = capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))
	real_name = name
	if (ismob(body))
		body.client.pixel_x = 0 //Resets the pixel offset of the ghost
		body.client.pixel_y = 0

	..()

/mob/observer/ghost/Destroy()
	stop_following()
	return ..()

/mob/observer/ghost/Topic(href, href_list)
	if (href_list["track"])
		if (istype(href_list["track"],/mob))
			var/mob/target = locate(href_list["track"]) in mob_list
			if (target)
				ManualFollow(target)
		else
			var/atom/target = locate(href_list["track"])
			if (istype(target))
				ManualFollow(target)

/mob/observer/ghost/attackby(obj/item/W, mob/user)
	return FALSE

/mob/observer/ghost/attack_ghost(mob/observer/ghost/user as mob)
	if (user.client && istype(user, /mob/observer/ghost))
		src.attack_hand(user)
		return
	..()

/mob/observer/ghost/attack_hand(mob/user)
	if (istype(user, /mob/observer/ghost))
		var/mob/observer/ghost/G = user
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		var/attverb = pick("punches", "kicks", "slaps")
		for(var/mob/observer/ghost/NG in range(7,src))
			NG << "<span class='notice'>[G] [attverb] \the [src]!</span>"
		user.do_attack_animation(src)
		src.ghostlife = max(0, src.ghostlife - 15)
		if (src.ghostlife <= 0)
			var/anim = "dust-ghost"
			src << "<span class='warning'>Your ethereal self vaporizes!</span>"
			var/atom/movable/overlay/animation = null
			animation = new(loc)
			animation.icon_state = "blank"
			animation.icon = 'icons/mob/mob.dmi'
			animation.master = src
			animation.invisibility = 60
			flick(anim, animation)
			src.forceMove(locate(1,1,1))
			src.ghostlife = 100
			spawn(15)
				if (animation)
					qdel(animation)
	else
		..()

/mob/observer/ghost/Life()
	..()

	if (!loc) return FALSE
	if (!client) return FALSE

	if (client.images.len)
		for (var/image/hud in client.images)
			if (copytext(hud.icon_state,1,4) == "hud")
				client.images.Remove(hud)

/mob/proc/ghostize(var/can_reenter_corpse = TRUE)
	// don't create bad ghosts - Kachnov
	if (!client)
		return

	if (!lastKnownCkey)
		return

	src << browse(null, "window=memory")

	// remove weather sounds
	src << sound(null, channel = 778)
	// remove ambient sounds
	stop_ambience(src)
	if (map && map.battleroyale)
		world << "<big><font color='red'><b>[client.ckey]</b> has died at ([x],[y])! <b>[alive_n_of_side(PIRATES)]</b> remaining.</font></big>"
	if (key)
		var/mob/observer/ghost/ghost = new(src)	//Transfer safety to observer spawning proc.
		ghost.can_reenter_corpse = can_reenter_corpse
		ghost.timeofdeath = stat == DEAD ? timeofdeath : world.time
		ghost.key = key
		if (ishuman(src))
			if (human_clients_mob_list.Find(src))
				human_clients_mob_list -= src
		return ghost

/mob/observer/ghost/can_use_hands()	return FALSE
/mob/observer/ghost/is_active()		return FALSE

/mob/observer/ghost/verb/reenter_corpse()
	set category = "Ghost"
	set name = "Re-enter Corpse"
	if (!client)	return
	if (!(mind && mind.current && can_reenter_corpse))
		src << "<span class='warning'>You have no body.</span>"
		return
	if (mind.current.key && copytext(mind.current.key,1,2)!="@")	//makes sure we don't accidentally kick any clients
		usr << "<span class='warning'>Another consciousness is in your body... it is resisting you.</span>"
		return

	stop_following()
	mind.current.key = key
	mind.current.teleop = null

	if (!admin_ghosted)
		announce_ghost_joinleave(mind, FALSE, "They now occupy their body again.")

	mind.current.regenerate_icons()

	// workaround for language bug that happens when you're spawned in
	var/mob/living/human/H = mind.current
	if (istype(H))
		if (!H.languages.Find(H.default_language))
			H.languages.Insert(1, H.default_language)
		human_clients_mob_list |= H
		if (config.allow_selfheal)
			H.verbs |= /mob/living/human/proc/selfheal
			H.verbs |= /mob/living/human/proc/selfrevive

	return TRUE

/mob/observer/ghost/verb/follow(input in getfitmobs()+"Cancel")
	set category = "Ghost"
	set name = "Follow" // "Haunt"
	set desc = "Follow and haunt a mob."

	if (input != "Cancel")
		var/list/mobs = getfitmobs()
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/follow_pirates(input in getfitmobs(PIRATES)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Pirate"
	set desc = "Follow and haunt a living Pirate."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(PIRATES)
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/follow_british(input in getfitmobs(BRITISH)+"Cancel")
	set category = "Ghost"
	set name = "Follow a British"
	set desc = "Follow and haunt a living British."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(BRITISH)
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/follow_civilian(input in getfitmobs(CIVILIAN)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Civilian"
	set desc = "Follow and haunt a living Civilian."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(CIVILIAN)
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/follow_portuguese(input in getfitmobs(PORTUGUESE)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Portuguese"
	set desc = "Follow and haunt a living Portuguese."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(PORTUGUESE)
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/follow_spanish(input in getfitmobs(SPANISH)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Spanish"
	set desc = "Follow and haunt a living Spanish."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(SPANISH)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_french(input in getfitmobs(FRENCH)+"Cancel")
	set category = "Ghost"
	set name = "Follow a French"
	set desc = "Follow and haunt a living French."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(FRENCH)
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/follow_dutch(input in getfitmobs(DUTCH)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Dutch"
	set desc = "Follow and haunt a living Dutch."

	if (input != "Cancel")
		var/list/mobs = getfitmobs(DUTCH)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_indians(input in getfitmobs(INDIANS)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Native"
	set desc = "Follow and haunt a living Native."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(INDIANS)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_roman(input in getfitmobs(ROMAN)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Roman"
	set desc = "Follow and haunt a living Roman."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(ROMAN)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_greek(input in getfitmobs(GREEK)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Greek"
	set desc = "Follow and haunt a living Greek."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(GREEK)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_german(input in getfitmobs(GERMAN)+"Cancel")
	set category = "Ghost"
	set name = "Follow a German"
	set desc = "Follow and haunt a living German."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(GERMAN)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_american(input in getfitmobs(AMERICAN)+"Cancel")
	set category = "Ghost"
	set name = "Follow an American"
	set desc = "Follow and haunt a living American."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(AMERICAN)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_vietnamese(input in getfitmobs(VIETNAMESE)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Vietnamese"
	set desc = "Follow and haunt a living Vietnamese."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(VIETNAMESE)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_filipino(input in getfitmobs(FILIPINO)+"Cancel")
	set category = "Ghost"
	set name = "Follow a Filipino"
	set desc = "Follow and haunt a living Filipino."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(FILIPINO)
		if (mobs[input])
			ManualFollow(mobs[input])
/mob/observer/ghost/verb/follow_arab(input in getfitmobs(ARAB)+"Cancel")
	set category = "Ghost"
	set name = "Follow an Arab"
	set desc = "Follow and haunt a living Arab."
	if (input != "Cancel")
		var/list/mobs = getfitmobs(ARAB)
		if (mobs[input])
			ManualFollow(mobs[input])

/mob/observer/ghost/verb/toggle_visibility()
	set category = "Ghost"
	set name = "Toggle Visibility"
	if (!icon)
		icon = original_icon
		overlays = original_overlays
		src << "<span class = 'good'>You are now visible again.</span>"
	else
		icon = null
		overlays.Cut()
		src << "<span class = 'good'>You are now invisible.</span>"

// This is the ghost's follow verb with an argument
/mob/observer/ghost/proc/ManualFollow(var/atom/movable/target)
	if (!target || target == following || target == src)
		return

	stop_following()
	if (istype(target, /mob/observer/ghost))
		return
	following = target
	moved_event.register(following, src, /atom/movable/proc/move_to_destination)
	dir_set_event.register(following, src, /atom/proc/recursive_dir_set)
	destroyed_event.register(following, src, /mob/observer/ghost/proc/stop_following)

	src << "<span class='notice'>Now following \the [following]</span>"

	move_to_destination(following, following.loc, following.loc)

/mob/observer/ghost/proc/stop_following()
	if (following)
		src << "<span class='notice'>No longer following \the [following]</span>"
		moved_event.unregister(following, src)
		dir_set_event.unregister(following, src)
		destroyed_event.unregister(following, src)
		following = null

/mob/observer/ghost/verb/jumptomob(target in getfitmobs() + "Cancel") //Moves the ghost instead of just changing the ghosts's eye -Nodrak
	set category = "Ghost"
	set name = "Jump to Mob"
	set desc = "Teleport to a mob"

	if (target == "Cancel") // also prevents sending the observer to nullspace when there are no mobs
		return

	if (isghost(usr)) //Make sure they're an observer!

		if (!target)//Make sure we actually have a target
			return
		else
			var/mob/M = getfitmobs()[target] //Destination mob
			var/turf/T = get_turf(M) //Turf of the destination mob
			stop_following()
			forceMove(T)

/mob/observer/ghost/memory()
	set hidden = TRUE
	src << "<span class = 'red'>You are dead! You have no mind to store memory!</span>"

/mob/observer/ghost/add_memory()
	set hidden = TRUE
	src << "<span class = 'red'>You are dead! You have no mind to store memory!</span>"

/mob/observer/ghost/Post_Incorpmove()
	stop_following()

/mob/observer/ghost/proc/try_possession(var/mob/living/M)
	if (!config.ghosts_can_possess_animals)
		usr << "<span class='warning'>Ghosts are not permitted to possess animals.</span>"
		return FALSE
	if (!M.can_be_possessed_by(src))
		return FALSE
	return M.do_possession(src)

/mob/observer/ghost/verb/pointed(atom/A as mob|obj|turf in view())
	set category = "Ghost"
	set name = "Point To"
	return TRUE

/mob/observer/ghost/canface()
	return TRUE

/mob/proc/can_admin_interact()
	return FALSE

/mob/observer/ghost/can_admin_interact()
	return check_rights(R_ADMIN, FALSE, src)

/mob/observer/ghost/verb/toggle_ghostsee()
	set name = "Toggle Ghost Vision"
	set desc = "Toggles your ability to see things only ghosts can see, like other ghosts"
	set category = "Ghost"
	ghostvision = !(ghostvision)
	updateghostsight()
	usr << "You [(ghostvision?"now":"no longer")] have ghost vision."

/mob/observer/ghost/verb/toggle_darkness()
	set name = "Toggle Darkness"
	set category = "Ghost"
	seedarkness = !(seedarkness)
	updateghostsight()

/mob/observer/ghost/proc/updateghostsight()
	if (!seedarkness)
		see_invisible = SEE_INVISIBLE_OBSERVER_NOLIGHTING
	else
		see_invisible = ghostvision ? SEE_INVISIBLE_OBSERVER : SEE_INVISIBLE_LIVING

	updateghostimages()

/mob/observer/ghost/proc/updateghostimages()
	if (!client)
		return
	client.images -= ghost_sightless_images
	client.images -= ghost_darkness_images
	if (!seedarkness)
		client.images |= ghost_sightless_images
		if (ghostvision)
			client.images |= ghost_darkness_images
	else if (seedarkness && !ghostvision)
		client.images |= ghost_sightless_images
	client.images -= ghost_image //remove ourself

/mob/observer/ghost/MayRespawn(var/feedback = FALSE, var/respawn_time = FALSE)
	if (!client)
		return FALSE
	if (mind && mind.current && mind.current.stat != DEAD && can_reenter_corpse)
		if (feedback)
			src << "<span class='warning'>Your non-dead body prevent you from respawning.</span>"
		return FALSE

	var/timedifference = world.time - timeofdeath
	if (respawn_time && timeofdeath && timedifference < respawn_time MINUTES)
		var/timedifference_text = time2text(respawn_time MINUTES - timedifference,"mm:ss")
		src << "<span class='warning'>You must have been dead for [respawn_time] minute\s to respawn. You have [timedifference_text] left.</span>"
		return FALSE

	return TRUE

/atom/proc/extra_ghost_link()
	return

/mob/extra_ghost_link(var/atom/ghost)
	return null

/mob/observer/ghost/extra_ghost_link(var/atom/ghost)
	if (mind && mind.current)
		return "|<a href='byond://?src=\ref[ghost];track=\ref[mind.current]'>body</a>"

/proc/ghost_follow_link(var/atom/target, var/atom/ghost)
	if ((!target) || (!ghost)) return
	. = "<a href='byond://?src=\ref[ghost];track=\ref[target]'>follow</a>"
	. += target.extra_ghost_link(ghost)