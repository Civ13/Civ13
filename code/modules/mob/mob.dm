/mob/Destroy()//This makes sure that mobs with clients/keys are not just deleted from the game.
	mob_list -= src
	dead_mob_list -= src
	living_mob_list -= src
	unset_using_object()
	qdel(hud_used)

	if (client)
		remove_screen_obj_references()
		for (var/atom/movable/AM in client.screen)
			qdel(AM)
		client.screen = list()

	ghostize()

	..()

/mob/proc/remove_screen_obj_references()//FIX THIS SHIT
//	flash = null
//	blind = null
	hands = null
	pullin = null
	purged = null
//	internals = null
//	oxygen = null
	i_select = null
	m_select = null
//	toxin = null
//	fire = null
//	bodytemp = null
//	healths = null
//	throw_icon = null
//	nutrition_icon = null
//	pressure = null
//	damageoverlay = null
//	pain = null
//	item_use_icon = null
//	gun_move_icon = null
//	gun_setting_icon = null
//	spell_masters = null
	zone_sel = null

// /mob/new_player doesn't callback to this, it needs to - Kachnov
/mob/New()
	mob_list += src
	if (stat == DEAD)
		dead_mob_list += src
	else
		living_mob_list += src
	..()


	if (!isnewplayer(src))
		src << browse(null, "window=playersetup;")

	spawn (10)
		if (client)
			if (!isnewplayer(src))
				movementMachine_clients |= client


/mob/proc/show_message(msg, type, alt, alt_type)//Message, type of message (1 or 2), alternative message, alt message type (1 or 2)

	if (!client)	return

	if (type)
		if (type & TRUE && (sdisabilities & BLIND || blinded || paralysis) )//Vision related
			if (!( alt ))
				return
			else
				msg = alt
				type = alt_type
		if (type & 2 && (sdisabilities & DEAF || ear_deaf))//Hearing related
			if (!( alt ))
				return
			else
				msg = alt
				type = alt_type
				if ((type & TRUE && sdisabilities & BLIND))
					return
	// Added voice muffling for Issue 41.
	if (stat == UNCONSCIOUS || sleeping > 0)
		src << "<I>... You can almost hear someone talking ...</I>"
	else
		src << msg
	return

// Show a message to all mobs and objects in sight of this one
// This would be for visible actions by the src mob
// message is the message output to anyone who can see e.g. "[src] does something!"
// self_message (optional) is what the src mob sees  e.g. "You do something!"
// blind_message (optional) is what blind people will hear e.g. "You hear something!"

/mob/visible_message(var/message, var/self_message, var/blind_message)
	var/list/see = get_mobs_or_objects_in_view(7,src) | viewers(7,src)

	for (var/I in see)
		if (isobj(I))
			spawn(0)
				if (I) //It's possible that it could be deleted in the meantime.
					var/obj/O = I
					O.show_message( message, TRUE, blind_message, 2)
		else if (ismob(I))
			var/mob/M = I
			if (self_message && M==src)
				M.show_message( self_message, TRUE, blind_message, 2)
			else if (M.see_invisible >= invisibility) // Cannot view the invisible
				M.show_message( message, TRUE, blind_message, 2)
			else if (blind_message)
				M.show_message(blind_message, 2)

// Returns an amount of power drawn from the object (-1 if it's not viable).
// If drain_check is set it will not actually drain power, just return a value.
// If surge is set, it will destroy/damage the recipient and not return any power.
// Not sure where to define this, so it can sit here for the rest of time.
/atom/proc/drain_power(var/drain_check,var/surge, var/amount = FALSE)
	return -1

// Show a message to all mobs and objects in earshot of this one
// This would be for audible actions by the src mob
// message is the message output to anyone who can hear.
// self_message (optional) is what the src mob hears.
// deaf_message (optional) is what deaf people will see.
// hearing_distance (optional) is the range, how many tiles away the message can be heard.
/mob/audible_message(var/message, var/deaf_message, var/hearing_distance, var/self_message)

	var/range = 7
	if (hearing_distance)
		range = hearing_distance
	var/list/hear = get_mobs_or_objects_in_view(range,src)

	for (var/I in hear)
		if (isobj(I))
			spawn(0)
				if (I) //It's possible that it could be deleted in the meantime.
					var/obj/O = I
					O.show_message( message, 2, deaf_message, TRUE)
		else if (ismob(I))
			var/mob/M = I
			var/msg = message
			if (self_message && M==src)
				msg = self_message
			M.show_message( msg, 2, deaf_message, TRUE)


/mob/proc/findname(msg)
	for (var/mob/M in mob_list)
		if (M.real_name == text("[]", msg))
			return M
	return FALSE

#define UNBUCKLED FALSE
#define PARTIALLY_BUCKLED TRUE
#define FULLY_BUCKLED 2
/mob/proc/buckled()
	// Preliminary work for a future buckle rewrite,
	// where one might be fully restrained (like an elecrical chair), or merely secured (shuttle chair, keeping you safe but not otherwise restrained from acting)
	if (!buckled)
		return UNBUCKLED
	return restrained() ? FULLY_BUCKLED : PARTIALLY_BUCKLED

/mob/proc/is_physically_disabled()
	return incapacitated(INCAPACITATION_DISABLED)

/mob/proc/incapacitated(var/incapacitation_flags = INCAPACITATION_DEFAULT)
	if ((incapacitation_flags & INCAPACITATION_DISABLED) && (stat || paralysis || stunned || weakened || resting || sleeping || (status_flags & FAKEDEATH)))
		return TRUE

	if ((incapacitation_flags & INCAPACITATION_RESTRAINED) && restrained())
		return TRUE

	if ((incapacitation_flags & (INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY)))
		var/buckling = buckled()
		if (buckling >= PARTIALLY_BUCKLED && (incapacitation_flags & INCAPACITATION_BUCKLED_PARTIALLY))
			return TRUE
		if (buckling == FULLY_BUCKLED && (incapacitation_flags & INCAPACITATION_BUCKLED_FULLY))
			return TRUE

	return FALSE

#undef UNBUCKLED
#undef PARTIALLY_BUCKLED
#undef FULLY_BUCKLED

/mob/proc/restrained()
	return FALSE

/mob/proc/reset_view(atom/A)
	if (client)
		if (istype(A, /atom/movable))
			client.perspective = EYE_PERSPECTIVE
			client.eye = A
		else
			if (isturf(loc))
				client.eye = client.mob
				client.perspective = MOB_PERSPECTIVE
			else
				client.perspective = EYE_PERSPECTIVE
				client.eye = loc
	return


/mob/proc/show_inv(mob/user as mob)
	return

//mob verbs are faster than object verbs. See http://www.byond.com/forum/?post=1326139&page=2#comment8198716 for why this isn't atom/verb/examine()
/mob/verb/examinate(atom/A as mob|obj|turf in view())
	set name = "Examine"
	set category = "IC"

	if ((is_blind(src) || stat) && !isobserver(src))
		src << "<span class='notice'>Something is there but you can't see it.</span>"
		return TRUE

	// changing direction counts as a movement, so don't do it unless we have to - Kachnov
	if (dir != get_dir(src,A))
		face_atom(A)
	//A.visible_message("<small>[A] looks at [src].</small>")//Doesn't work for everything yet.
	A.examine(src)
/mob/verb/pointed(atom/A as mob|obj|turf in view())
	set name = "Point To"
	set category = "Object"

	if(!src || !isturf(src.loc) || !(A in view(src.loc)))
		return 0
	if(istype(A, /obj/effect/decal/point))
		return 0

	var/tile = get_turf(A)
	if (!tile)
		return 0

	var/obj/P = new /obj/effect/decal/point(tile)
	P.invisibility = invisibility
	spawn (20)
		if(P)
			qdel(P)	// qdel

	face_atom(A)
	return 1

/mob/proc/ret_grab(obj/effect/list_container/mobl/L as obj, flag)
	if ((!( istype(l_hand, /obj/item/weapon/grab) ) && !( istype(r_hand, /obj/item/weapon/grab) )))
		if (!( L ))
			return null
		else
			return L.container
	else
		if (!( L ))
			L = new /obj/effect/list_container/mobl( null )
			L.container += src
			L.master = src
		if (istype(l_hand, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = l_hand
			if (!( L.container.Find(G.affecting) ))
				L.container += G.affecting
				if (G.affecting)
					G.affecting.ret_grab(L, TRUE)
		if (istype(r_hand, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = r_hand
			if (!( L.container.Find(G.affecting) ))
				L.container += G.affecting
				if (G.affecting)
					G.affecting.ret_grab(L, TRUE)
		if (!( flag ))
			if (L.master == src)
				var/list/temp = list(  )
				temp += L.container
				//L = null
				qdel(L)
				return temp
			else
				return L.container
	return

/mob/verb/mode()
	set name = "Activate Held Object"
	set category = null
	set src = usr

	if (hand)
		var/obj/item/W = l_hand
		if (W)
			W.attack_self(src)
			update_inv_l_hand()
	else
		var/obj/item/W = r_hand
		if (W)
			W.attack_self(src)
			update_inv_r_hand()
	return

/*
/mob/verb/dump_source()

	var/master = "<PRE>"
	for (var/t in typesof(/area))
		master += text("[]\n", t)
		//Foreach goto(26)
	src << browse(master)
	return
*/

/mob/verb/memory()
	set name = "Notes"
	set category = "IC"
	if (mind)
		mind.show_memory(src)
	else
		src << "The game appears to have misplaced your mind datum, so we can't show you your notes."


/mob/verb/add_memory(msg as message)
	set name = "Add Note"
	set category = "IC"

	msg = replacetext(msg, "<i>", "")
	msg = replacetext(msg, "</i>", "")
	msg = replacetext(msg, "<b>", "")
	msg = replacetext(msg, "</b>", "")

	msg = sanitize(msg)

	if (mind)
		mind.store_memory(msg)

/mob/proc/replace_memory(replacing, replacewith)
	if (isnum(replacing))
		replacing = num2text(replacing)
	if (isnum(replacewith))
		replacewith = num2text(replacewith)
	if (mind && mind.memory)
		mind.memory = replacetext(mind.memory, replacing, replacewith)
		return TRUE
	return FALSE

/mob/proc/store_memory(msg as message, popup, sane = TRUE)
	msg = copytext(msg, TRUE, MAX_MESSAGE_LEN)

	msg = replacetext(msg, "<i>", "")
	msg = replacetext(msg, "</i>", "")
	msg = replacetext(msg, "<b>", "")
	msg = replacetext(msg, "</b>", "")

	if (sane)
		msg = sanitize(msg)

	if (length(memory) == 0)
		memory += msg
	else
		memory += "<br>[msg]"

	if (popup)
		memory()

/mob/proc/add_note(section, note)
	if (!mind)
		return
	return mind.add_note(section, note)

/mob/proc/wipe_notes()
	if (!mind)
		return
	return mind.wipe_notes()

/mob/proc/update_flavor_text()
	set src in usr
	if (usr != src)
		usr << "No."
	var/msg = sanitize(input(usr,"Set the flavor text in your 'examine' verb. Can also be used for OOC notes about your character.","Flavor Text",rhtml_decode(flavor_text)) as message|null, extra = FALSE)

	if (msg != null)
		flavor_text = msg

/mob/proc/print_flavor_text()
	if (flavor_text && flavor_text != "")
		var/msg = trim(replacetext(flavor_text, "\n", " "))
		if (!msg) return ""
		if (lentext(msg) <= 40)
			return "<span class = 'notice'>[msg]</span>"
		else
			return "<span class = 'notice'>[copytext_preserve_html(msg, TRUE, 37)]... <a href='byond://?src=\ref[src];flavor_more=1'>More...</a></span>"

/*
/mob/verb/help()
	set name = "Help"
	src << browse('html/help.html', "window=help")
	return
*/

/mob/verb/abandon_mob()
	set name = "Respawn"
	set category = "IC"

	if (!( config.abandon_allowed ))
		usr << "<span class='notice'>Respawn is disabled.</span>"
		return

	if ((stat != DEAD || !( ticker )))
		usr << "<span class='notice'><b>You must be dead to use this!</b></span>"
		return

	src << browse(null, "window=memory")

	src << "You can respawn now, enjoy your new life!"
	stop_ambience(usr)

	log_game("[name]/[key] used abandon mob.")

	usr << "<span class='notice'><b>Make sure to play a different character, and please roleplay correctly!</b></span>"

	if (!client)
		log_game("[key] AM failed due to disconnect.")
		return
	client.screen.Cut()
	if (!client)
		log_game("[key] AM failed due to disconnect.")
		return

	announce_ghost_joinleave(client, FALSE)

	var/mob/new_player/M = new /mob/new_player()
	if (!client)
		log_game("[key] AM failed due to disconnect.")
		qdel(M)
		return

	M.key = key
	if (M.mind)
		M.mind.reset()
	return

/mob/verb/observe()
	set name = "Observe"
	set category = "OOC"
	var/is_admin = FALSE

	if (client.holder && (client.holder.rights & R_ADMIN))
		is_admin = TRUE
	else if (stat != DEAD || istype(src, /mob/new_player))
		usr << "<span class = 'notice'>You must be observing to use this!</span>"
		return

	if (is_admin && stat == DEAD)
		is_admin = FALSE

	var/list/names = list()
	var/list/namecounts = list()
	var/list/creatures = list()

	for (var/mob/M in sortAtom(mob_list))
		var/name = M.name
		if (names.Find(name))
			namecounts[name]++
			name = "[name] ([namecounts[name]])"
		else
			names.Add(name)
			namecounts[name] = TRUE

		creatures[name] = M

	client.perspective = EYE_PERSPECTIVE

	var/eye_name = null

	var/ok = "[is_admin ? "Admin Observe" : "Observe"]"
	eye_name = input("Please, select a player!", ok, null, null) as null|anything in creatures

	if (!eye_name)
		return

	var/mob/mob_eye = creatures[eye_name]

	if (client && mob_eye)
		client.eye = mob_eye
		if (is_admin)
			client.adminobs = TRUE
			if (mob_eye == client.mob || client.eye == client.mob)
				client.adminobs = FALSE

/mob/Topic(href, href_list)
	if (href_list["mach_close"])
		var/t1 = text("window=[href_list["mach_close"]]")
		unset_using_object()
		src << browse(null, t1)

	if (href_list["flavor_more"])
		if (src in view(usr))
			usr << browse(text("<HTML><HEAD><TITLE>[]</TITLE></HEAD><BODY><TT>[]</TT></BODY></HTML>", name, cp1251_to_utf8(replacetext(flavor_text, "\n", "<BR>"))), text("window=[];size=500x200", name))
			onclose(usr, "[name]")
	if (href_list["flavor_change"])
		update_flavor_text()
//	..()
	return


/mob/proc/pull_damage()
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.health - H.halloss <= config.health_threshold_softcrit)
			for (var/name in H.organs_by_name)
				var/obj/item/organ/external/e = H.organs_by_name[name]
				if (e && H.lying)
					if (((e.status & ORGAN_BROKEN && !(e.status & ORGAN_SPLINTED)) || e.status & ORGAN_BLEEDING) && (H.getBruteLoss() + H.getFireLoss() >= 100))
						return TRUE
						break
		return FALSE

/mob/MouseDrop(mob/M as mob)
	..()
	if (M != usr) return
	if (usr == src) return
	if (!Adjacent(usr)) return
	show_inv(usr)


/mob/verb/stop_pulling()

	set name = "Stop Pulling"
	set category = "IC"

	if (pulling)
		pulling.pulledby = null
		pulling = null
		/*if (pullin)
			pullin.icon_state = "pull0"*/

/mob/proc/start_pulling(var/atom/movable/AM)

	if ( !AM || !usr || src==AM || !isturf(loc) )	//if there's no person pulling OR the person is pulling themself OR the object being pulled is inside something: abort!
		return

	if (AM.anchored)
		src << "<span class='warning'>It won't budge!</span>"
		return

	var/mob/M = AM
	if (ismob(AM))

		if (!can_pull_mobs || !can_pull_size)
			src << "<span class='warning'>It won't budge!</span>"
			return

		if ((mob_size < M.mob_size) && (can_pull_mobs != MOB_PULL_LARGER))
			src << "<span class='warning'>It won't budge!</span>"
			return

		if ((mob_size == M.mob_size) && (can_pull_mobs == MOB_PULL_SMALLER))
			src << "<span class='warning'>It won't budge!</span>"
			return

		// If your size is larger than theirs and you have some
		// kind of mob pull value AT ALL, you will be able to pull
		// them, so don't bother checking that explicitly.

		if (!iscarbon(src))
			M.LAssailant = null
		else
			M.LAssailant = usr

	else if (isobj(AM))
		var/obj/I = AM
		if (!can_pull_size || can_pull_size < I.w_class)
			src << "<span class='warning'>It won't budge!</span>"
			return

	if (pulling)
		var/pulling_old = pulling
		stop_pulling()
		// Are we pulling the same thing twice? Just stop pulling.
		if (pulling_old == AM)
			return

	pulling = AM
	AM.pulledby = src

	/*if (pullin)
		pullin.icon_state = "pull1"*/
/*
	if (ishuman(AM))
		var/mob/living/carbon/human/H = AM
		if (H.pull_damage())
			src << "\red <b>Pulling \the [H] in their current condition would probably be a bad idea.</b>"
*/
	//Attempted fix for people flying away through space when cuffed and dragged.
	if (ismob(AM))
		var/mob/pulled = AM
		pulled.inertia_dir = FALSE

/mob/proc/can_use_hands()
	return

/mob/proc/is_active()
	return (0 >= usr.stat)

/mob/proc/is_dead()
	return stat == DEAD

/mob/proc/is_ready()
	return client && !!mind

/mob/proc/get_gender()
	return gender

/mob/proc/see(message)
	if (!is_active())
		return FALSE
	src << message
	return TRUE

/mob/proc/show_viewers(message)
	for (var/mob/M in viewers())
		M.see(message)

// this CSS is terrible but its the only thing that works - Kachnov
/mob/proc/stat_header(title)
	return "<span style = 'font-size: 13px;'><small><b>[title]</b></small></span>"

/mob/Stat()
	..()
	. = (is_client_active(10 MINUTES))
	if (.)
		if (client.status_tabs && statpanel("Status") && ticker)
			stat("")
			stat(stat_header("Server"))
			stat("")
			stat("Players Online (Playing, Observing, Lobby):", "[clients.len] ([human_clients_mob_list.len], [clients.len-human_clients_mob_list.len-new_player_mob_list.len], [new_player_mob_list.len])")
			stat("Round Duration:", roundduration2text())

			if (map && !map.civilizations)
				var/grace_period_string = ""
				for (var/faction in map.faction_organization)
					if (!list(BRITISH, PIRATES, INDIANS, PORTUGUESE, SPANISH, FRENCH, DUTCH, CIVILIAN, ROMAN, GREEK, ARAB, JAPANESE, RUSSIAN, GERMAN, AMERICAN, VIETNAMESE).Find(faction))
						continue
					if (grace_period_string)
						grace_period_string += ", "
					if (!map.civilizations)
						if (map.last_crossing_block_status[faction])
							grace_period_string += "[faction_const2name(faction,map.ordinal_age)] may cross"
						else
							grace_period_string += "[faction_const2name(faction,map.ordinal_age)] may not cross"
					else
						if (map.last_crossing_block_status[faction])
							grace_period_string += "The grace wall has been removed."
						else
							grace_period_string += "The grace wall is in effect."

				stat("Grace Period Status:", grace_period_string)
				stat("Round End Condition:", map.current_stat_message())
			if (map)
				stat("Map:", map.title)
				if (map.civilizations)
					stat("Mode:", map.gamemode)
				stat("Epoch:", map.age)
				stat("Season:", get_season())
				stat("Wind:", map.winddesc)
//				stat("Weather:", get_weather())
				stat("Time of Day:", time_of_day)


			// give the client some information about how the server is running
			if (processes.ping_track && client)
				var/our_ping = ceil(client.last_ping)
				var/avg_ping = ceil(processes.ping_track.avg)
				if (clients.len == 1)
					avg_ping = our_ping
				stat("Ping (Average):", "[our_ping] ms ([avg_ping] ms)")
			stat("Time Dilation (Average):", processes.time_track ? "[ceil(processes.time_track.dilation)]% ([ceil(processes.time_track.stored_averages["dilation"])]%)" : "0% (0%)")

		if (client.holder && client.status_tabs)
			if (statpanel("Status"))
				stat("")
				stat(stat_header("Developer"))
				stat("")
				if (processes.time_track)
					stat("CPU (Average) (Movement Scheduler (Average)):","[world.cpu]% ([ceil(processes.time_track.stored_averages["cpu"])]%) ([ceil(movementMachine.last_cpu)]% ([ceil(movementMachine.average_cpu)]%))")
					stat("Tick Usage (Average) (Movement Scheduler (Average)):","[ceil(world.tick_usage)]% ([ceil(processes.time_track.stored_averages["tick_usage"])]%) ([ceil(movementMachine.last_tick_usage)]% ([ceil(movementMachine.average_tick_usage)]%))")
				if (client.holder.rights & R_MOD)
					stat("Location:", "([x], [y], [z]) - [loc ? loc : "nullspace"]")
				stat("Object Count:","[world.contents.len] Datums")
/*			if (statpanel("Processes"))
				if (processScheduler)
					processScheduler.statProcesses()*/

		if (listed_turf && client && client.status_tabs)
			if (!TurfAdjacent(listed_turf))
				listed_turf = null
			else
				if (statpanel("Turf"))
					stat(listed_turf)
					for (var/atom/A in listed_turf)
						if (!A.mouse_opacity)
							continue
						if (A.invisibility > see_invisible)
							continue
						if (is_type_in_list(A, shouldnt_see))
							continue
						stat(A)



// facing verbs
/mob/proc/canface()
	if (!canmove)						return FALSE
	if (stat)							return FALSE
	if (anchored)						return FALSE
	if (transforming)						return FALSE
	return TRUE

/mob/proc/cannot_stand()
	return incapacitated(INCAPACITATION_DEFAULT & (~INCAPACITATION_RESTRAINED))

//Updates canmove, lying and icons. Could perhaps do with a rename but I can't think of anything to describe it.
/mob/proc/update_canmove()

	var/noose = FALSE
	var/gallows = FALSE
	for (var/obj/structure/noose/N in get_turf(src))
		if (N.hanging == src)
			lying = FALSE
			canmove = FALSE
			anchored = TRUE
			noose = TRUE
			prone = FALSE
			update_icons()
	for (var/obj/structure/gallows/G in get_turf(src))
		if (G.hanging == src)
			lying = FALSE
			canmove = FALSE
			anchored = TRUE
			gallows = TRUE
			prone = FALSE
			update_icons()
	if (!noose && !gallows)
		if (buckled)
			anchored = TRUE
			canmove = FALSE
			if (istype(buckled))
				if (buckled.buckle_lying != -1)
					lying = buckled.buckle_lying
				if (buckled.buckle_movable)
					anchored = FALSE
					canmove = TRUE

		else if (cannot_stand())
			lying = TRUE
			canmove = FALSE
		else if (stunned)
			canmove = FALSE
		else if (captured)
			anchored = TRUE
			canmove = FALSE
			lying = FALSE
		else
			lying = FALSE
			canmove = TRUE
			anchored = FALSE
	if (lying || prone)
		density = FALSE
		anchored = FALSE
	//	if (l_hand) unEquip(l_hand)
	//	if (r_hand) unEquip(r_hand)
	else
		density = initial(density)

	for (var/obj/item/weapon/grab/G in grabbed_by)
		if (G.state >= GRAB_AGGRESSIVE)
			canmove = FALSE
			break

	//Temporarily moved here from the various life() procs
	//I'm fixing stuff incrementally so this will likely find a better home.
	//It just makes sense for now. ~Carn
	if ( update_icon )	//forces a full overlay update
		update_icon = FALSE
		regenerate_icons()
	else if ( lying != lying_prev )
		update_icons()

	return canmove

/mob/proc/Life()
	return

/mob/proc/facedir(var/ndir)
	if (!canface() || client.moving || world.time < client.move_delay)
		return FALSE
	set_dir(ndir)
	if (buckled && buckled.buckle_movable)
		buckled.set_dir(ndir)
	client.move_delay += movement_delay()
	update_vision_cone()
	return TRUE


/mob/verb/eastface()
	set hidden = TRUE
	return facedir(client.client_dir(EAST))


/mob/verb/westface()
	set hidden = TRUE
	return facedir(client.client_dir(WEST))


/mob/verb/northface()
	set hidden = TRUE
	return facedir(client.client_dir(NORTH))


/mob/verb/southface()
	set hidden = TRUE
	return facedir(client.client_dir(SOUTH))


//This might need a rename but it should replace the can this mob use things check
/mob/proc/IsAdvancedToolUser()
	return FALSE

/mob/proc/get_species()
	return ""


/mob/proc/get_visible_implants(var/class = FALSE)
	var/list/visible_implants = list()
	for (var/obj/item/O in embedded)
		if (O.w_class > class)
			visible_implants += O
	return visible_implants

/mob/proc/embedded_needs_process()
	return (embedded.len > 0)

mob/proc/yank_out_object()
	set category = null
	set name = "Yank out object"
	set desc = "Remove an embedded item at the cost of bleeding and pain."
	set src in view(1)

	if (!isliving(usr) || !usr.canClick())
		return
	usr.setClickCooldown(20)

	if (usr.stat == TRUE)
		usr << "You are unconcious and cannot do that!"
		return

	if (usr.restrained())
		usr << "You are restrained and cannot do that!"
		return

	var/mob/S = src
	var/mob/U = usr
	var/list/valid_objects = list()
	var/self = null

	if (S == U)
		self = TRUE // Removing object from yourself.

	valid_objects = get_visible_implants(0)
	if (!valid_objects.len)
		if (self)
			src << "You have nothing stuck in your body that is large enough to remove."
		else
			U << "[src] has nothing stuck in their wounds that is large enough to remove."
		return

	var/obj/item/weapon/selection = input("What do you want to yank out?", "Embedded objects") in valid_objects

	if (self)
		src << "<span class='warning'>You attempt to get a good grip on [selection] in your body.</span>"
	else
		U << "<span class='warning'>You attempt to get a good grip on [selection] in [S]'s body.</span>"

	if (!do_mob(U, S, 30))
		return
	if (!selection || !S || !U)
		return

	if (self)
		visible_message("<span class='warning'><b>[src] rips [selection] out of their body.</b></span>","<span class='warning'><b>You rip [selection] out of your body.</b></span>")
	else
		visible_message("<span class='warning'><b>[usr] rips [selection] out of [src]'s body.</b></span>","<span class='warning'><b>[usr] rips [selection] out of your body.</b></span>")
	valid_objects = get_visible_implants(0)
	if (valid_objects.len == TRUE) //Yanking out last object - removing verb.
		verbs -= /mob/proc/yank_out_object

	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		var/obj/item/organ/external/affected

		for (var/obj/item/organ/external/organ in H.organs) //Grab the organ holding the implant.
			for (var/obj/item/O in organ.implants)
				if (O == selection)
					affected = organ

		affected.implants -= selection
		H.shock_stage+=20
		affected.take_damage((selection.w_class * 3), FALSE, FALSE, TRUE, "Embedded object extraction")

		if (prob(selection.w_class * 5)) //I'M SO ANEMIC I COULD JUST -DIE-.
			var/datum/wound/internal_bleeding/I = new (min(selection.w_class * 5, 15), src)
			affected.wounds += I
			H.custom_pain("Something tears wetly in your [affected] as [selection] is pulled free!", 30)

		if (ishuman(U))
			var/mob/living/carbon/human/human_user = U
			human_user.bloody_hands(H)

	selection.forceMove(get_turf(src))
	if (!(U.l_hand && U.r_hand))
		U.put_in_hands(selection)

	for (var/obj/item/weapon/O in pinned)
		if (O == selection)
			pinned -= O
		if (!pinned.len)
			anchored = FALSE
	return TRUE

/mob/living/proc/handle_statuses()
	handle_stunned()
	handle_weakened()
	handle_stuttering()
	handle_silent()
	handle_drugged()
	handle_slurring()
	handle_lisp()

/mob/living/proc/handle_stunned()
	if (stunned)
		AdjustStunned(-1)
	return stunned

/mob/living/proc/handle_weakened()
	if (weakened)
		weakened = max(weakened-1, 0)	//before you get mad Rockdtben: I done this so update_canmove isn't called multiple times
	return weakened

/mob/living/proc/handle_stuttering()
	if (stuttering)
		stuttering = max(stuttering-1, 0)
	return stuttering

/mob/living/proc/handle_silent()
	if (silent)
		silent = max(silent-1, 0)
	return silent

/mob/living/proc/handle_drugged()
	if (druggy)
		druggy = max(druggy-1, 0)
	return druggy

/mob/living/proc/handle_slurring()
	if (slurring)
		slurring = max(slurring-1, 0)
	return slurring

/mob/living/proc/handle_lisp()
	return FALSE

/mob/living/proc/handle_paralysed() // Currently only used by simple_animal.dm, treated as a special case in other mobs
	if (paralysis)
		AdjustParalysis(-1)
	return paralysis


/mob/proc/updateicon()
	return

/mob/verb/face_direction()

	set name = "Face Direction"
	set category = "IC"
	set src = usr

	set_face_dir()

	if (!facing_dir)
		usr << "You are now not facing anything."
	else
		usr << "You are now facing [dir2text(facing_dir)]."
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.HUDneed.Find("fixeye"))
			var/obj/screen/tactic/I = H.HUDneed["fixeye"]
			I.update_icon()

/mob/proc/set_face_dir(var/newdir)
	if (!isnull(facing_dir) && newdir == facing_dir)
		facing_dir = null
	else if (newdir)
		set_dir(newdir)
		facing_dir = newdir
	else if (facing_dir)
		facing_dir = null
	else
		set_dir(dir)
		facing_dir = dir

/mob/set_dir()
	if (facing_dir)
		if (!canface() || lying || prone || buckled || restrained())
			facing_dir = null
		else if (dir != facing_dir)
			return ..(facing_dir)
	else
		return ..()

/mob/verb/northfaceperm()
	set hidden = TRUE
	set_face_dir(client.client_dir(NORTH))

/mob/verb/southfaceperm()
	set hidden = TRUE
	set_face_dir(client.client_dir(SOUTH))

/mob/verb/eastfaceperm()
	set hidden = TRUE
	set_face_dir(client.client_dir(EAST))

/mob/verb/westfaceperm()
	set hidden = TRUE
	set_face_dir(client.client_dir(WEST))

/mob/proc/adjustEarDamage()
	return

/mob/proc/setEarDamage()
	return

//Throwing stuff

/mob/proc/toggle_throw_mode()
	if (in_throw_mode)
		throw_mode_off()
	else
		throw_mode_on()

/mob/proc/throw_mode_off()
	in_throw_mode = FALSE


/mob/proc/throw_mode_on()
	in_throw_mode = TRUE


/mob/proc/swap_hand()
	return