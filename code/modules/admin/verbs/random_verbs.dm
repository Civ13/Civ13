/client/proc/cmd_admin_drop_everything(mob/M as mob in mob_list)
	set category = null
	set name = "Drop Everything"
	if (!holder)
		src << "Only administrators may use this command."
		return

	var/confirm = WWinput(src, "Make [M] drop everything?", null, "Yes", list("Yes", "No"))
	if (confirm != "Yes")
		return

	for (var/obj/item/W in M)
		M.drop_from_inventory(W)

	log_admin("[key_name(usr)] made [key_name(M)] drop everything!")
	message_admins("[key_name_admin(usr)] made [key_name_admin(M)] drop everything!", TRUE)


/client/proc/cmd_admin_subtle_message(mob/M as mob in mob_list)
	set category = "Special"
	set name = "Subtle Message"

	if (!ismob(M))	return
	if (!holder)
		src << "Only administrators may use this command."
		return

	var/msg = sanitize(input("Message:", text("Subtle PM to [M.key]")) as text)

	if (!msg)
		return
	if (usr)
		if (usr.client)
			if (usr.client.holder)
				M << "\bold You hear a voice in your head... \italic [msg]"

	log_admin("SubtlePM: [key_name(usr)] -> [key_name(M)] : [msg]")
	message_admins("<span class = 'notice'>\bold SubtleMessage: [key_name_admin(usr)] -> [key_name_admin(M)] : [msg]</span>", TRUE)


/client/proc/cmd_mentor_check_new_players()	//Allows mentors / admins to determine who the newer players are.
	set category = "Admin"
	set name = "Check new Players"
	if (!holder)
		src << "Only staff members may use this command."

	var/age = WWinput(src, "Age check", "Show accounts yonger then ___ days", "7", list("7", "30" , "All"))

	if (age == "All")
		age = 9999999
	else
		age = text2num(age)

	var/missing_ages = FALSE
	var/msg = ""

	var/highlight_special_characters = TRUE
	if (is_mentor(usr.client))
		highlight_special_characters = FALSE

	for (var/client/C in clients)
		if (C.player_age == "Requires database")
			missing_ages = TRUE
			continue
		if (C.player_age < age)
			msg += "[key_name(C, TRUE, TRUE, highlight_special_characters)]: account is [C.player_age] days old<br>"

	if (missing_ages)
		src << "Some accounts did not have proper ages set in their clients.  This function requires database to be present"

	if (msg != "")
		src << browse(msg, "window=Player_age_check")
	else
		src << "No matches for that age range found."


/client/proc/cmd_admin_world_narrate() // Allows administrators to fluff events a little easier -- TLE
	set category = "Special"
	set name = "Global Narrate"

	if (!holder)
		src << "Only administrators may use this command."
		return

	var/msg = sanitize(input("Message:", text("Enter the text you wish to appear to everyone:")) as text)

	if (!msg)
		return
	world << "[msg]"
	log_admin("GlobalNarrate: [key_name(usr)] : [msg]")
	message_admins("<span class = 'notice'>\bold GlobalNarrate: [key_name_admin(usr)] : [msg]</span><br>", TRUE)


/client/proc/cmd_admin_direct_narrate(var/mob/M)	// Targetted narrate -- TLE
	set category = "Special"
	set name = "Direct Narrate"

	if (!holder)
		src << "Only administrators may use this command."
		return

	if (!M)
		M = input("Direct narrate to who?", "Active Players") as null|anything in get_mob_with_client_list()

	if (!M)
		return

	var/msg = sanitize(input("Message:", text("Enter the text you wish to appear to your target:")) as text)

	if ( !msg )
		return

	M << msg
	log_admin("DirectNarrate: [key_name(usr)] to ([M.name]/[M.key]): [msg]")
	message_admins("<span class = 'notice'>\bold DirectNarrate: [key_name(usr)] to ([M.name]/[M.key]): [msg]</span><BR>", TRUE)


/client/proc/cmd_admin_godmode(mob/M as mob in mob_list)
	set category = "Special"
	set name = "Godmode"
	if (!holder)
		src << "Only administrators may use this command."
		return
	M.status_flags ^= GODMODE
	usr << "<span class = 'notice'>Toggled [(M.status_flags & GODMODE) ? "ON" : "OFF"]</span>"

	log_admin("[key_name(usr)] has toggled [key_name(M)]'s nodamage to [(M.status_flags & GODMODE) ? "On" : "Off"]")
	message_admins("[key_name_admin(usr)] has toggled [key_name_admin(M)]'s nodamage to [(M.status_flags & GODMODE) ? "On" : "Off"]", TRUE)


proc/cmd_admin_mute(mob/M as mob, mute_type, automute = FALSE)
	if (automute)
		if (!config.automute_on)	return
	else
		if (!usr || !usr.client)
			return
		if (!usr.client.holder)
			usr << "<font color='red'>Error: cmd_admin_mute: You don't have permission to do this.</font>"
			return
		if (!M.client)
			usr << "<font color='red'>Error: cmd_admin_mute: This mob doesn't have a client tied to it.</font>"
		if (M.client.holder)
			usr << "<font color='red'>Error: cmd_admin_mute: You cannot mute an admin/mod.</font>"
	if (!M.client)		return
	if (M.client.holder)	return

	var/muteunmute
	var/mute_string

	switch(mute_type)
		if (MUTE_IC)			mute_string = "IC (say and emote)"
		if (MUTE_OOC)		mute_string = "OOC"
		if (MUTE_PRAY)		mute_string = "pray"
		if (MUTE_ADMINHELP)	mute_string = "adminhelp, admin PM and ASAY"
		if (MUTE_DEADCHAT)	mute_string = "deadchat and DSAY"
		if (MUTE_ALL)		mute_string = "everything"
		else				return

	if (automute)
		muteunmute = "auto-muted"
		M.client.prefs.muted |= mute_type
		log_admin("SPAM AUTOMUTE: [muteunmute] [key_name(M)] from [mute_string]")
		message_admins("SPAM AUTOMUTE: [muteunmute] [key_name_admin(M)] from [mute_string].", TRUE)
		M << "<span class='alert'>You have been [muteunmute] from [mute_string] by the SPAM AUTOMUTE system. Contact an admin.</span>"

		return

	if (M.client.prefs.muted & mute_type)
		muteunmute = "unmuted"
		M.client.prefs.muted &= ~mute_type
	else
		muteunmute = "muted"
		M.client.prefs.muted |= mute_type

	log_admin("[key_name(usr)] has [muteunmute] [key_name(M)] from [mute_string]")
	message_admins("[key_name_admin(usr)] has [muteunmute] [key_name_admin(M)] from [mute_string].", TRUE)
	M << "<span class = 'alert'>You have been [muteunmute] from [mute_string].</span>"

/*
Allow admins to set players to be able to respawn/bypass 30 min wait, without the admin having to edit variables directly
Ccomp's first proc.
*/

/client/proc/get_ghosts(var/notify = FALSE,var/what = 2)
	// what = TRUE, return ghosts ass list.
	// what = 2, return mob list

	var/list/mobs = list()
	var/list/ghosts = list()
	var/list/sortmob = sortAtom(mob_list)                           // get the mob list.
	var/any=0
	for (var/mob/observer/ghost/M in sortmob)
		mobs.Add(M)                                             //filter it where it's only ghosts
		any = TRUE                                                 //if no ghosts show up, any will just be FALSE
	if (!any)
		if (notify)
			src << "There doesn't appear to be any ghosts for you to select."
		return

	for (var/mob/M in mobs)
		var/name = M.name
		ghosts[name] = M                                        //get the name of the mob for the popup list
	if (what==1)
		return ghosts
	else
		return mobs


/client/proc/allow_character_respawn()
	set category = "Special"
	set name = "Allow player to respawn"
	set desc = "Let's the player bypass the 30 minute wait to respawn or allow them to re-enter their corpse."
	if (!holder)
		src << "Only administrators may use this command."
	var/list/ghosts= get_ghosts(1,1)

	var/target = input("Please, select a ghost!", "COME BACK TO LIFE!", null, null) as null|anything in ghosts
	if (!target)
		return

	var/mob/observer/ghost/G = ghosts[target]
	if (G.has_enabled_antagHUD && config.antag_hud_restricted)
		var/response = WWinput(src, "Are you sure you wish to allow this individual to play?", "Ghost has used AntagHUD", "No", list("Yes","No"))
		if (response == "No") return
	G.timeofdeath=-19999						/* time of death is checked in /mob/verb/abandon_mob() which is the Respawn verb.
									   timeofdeath is used for bodies on autopsy but since we're messing with a ghost I'm pretty sure
									   there won't be an autopsy.
									*/
	G.has_enabled_antagHUD = 2
	G.can_reenter_corpse = TRUE

	G:show_message(text("<span class = 'notice'><b>You may now respawn.  You should roleplay as if you learned nothing about the round during your time with the dead.</b></span>"), TRUE)
	log_admin("[key_name(usr)] allowed [key_name(G)] to bypass the 30 minute respawn limit")
	message_admins("Admin [key_name_admin(usr)] allowed [key_name_admin(G)] to bypass the 30 minute respawn limit", TRUE)


/client/proc/toggle_antagHUD_use()
	set category = "Server"
	set name = "Toggle antagHUD usage"
	set desc = "Toggles antagHUD usage for observers"

	if (!holder)
		src << "Only administrators may use this command."
	var/action=""
	if (config.antag_hud_allowed)
		for (var/mob/observer/ghost/g in get_ghosts())
		//	if (!g.client.holder)						//Remove the verb from non-admin ghosts
		//		g.verbs -= /mob/observer/ghost/verb/toggle_antagHUD
			if (g.antagHUD)
				g.antagHUD = FALSE						// Disable it on those that have it enabled
				g.has_enabled_antagHUD = 2				// We'll allow them to respawn
				g << "<span class = 'red'><b>An administrator has disabled AntagHUD.</b></span>"
		config.antag_hud_allowed = FALSE
		src << "<span class = 'red'><b>AntagHUD usage has been disabled.</b></span>"
		action = "disabled"
	else
		for (var/mob/observer/ghost/g in get_ghosts())
		//	if (!g.client.holder)						// Add the verb back for all non-admin ghosts
			//	g.verbs += /mob/observer/ghost/verb/toggle_antagHUD
			g << "<span class = 'notice'><b>The Administrator has enabled AntagHUD </b></span>"	// Notify all observers they can now use AntagHUD
		config.antag_hud_allowed = TRUE
		action = "enabled"
		src << "<span class = 'notice'><b>AntagHUD usage has been enabled</b></span>"


	log_admin("[key_name(usr)] has [action] antagHUD usage for observers")
	message_admins("Admin [key_name_admin(usr)] has [action] antagHUD usage for observers", TRUE)



/client/proc/toggle_antagHUD_restrictions()
	set category = "Server"
	set name = "Toggle antagHUD Restrictions"
	set desc = "Restricts players that have used antagHUD from being able to join this round."
	if (!holder)
		src << "Only administrators may use this command."
	var/action=""
	if (config.antag_hud_restricted)
		for (var/mob/observer/ghost/g in get_ghosts())
			g << "<span class = 'notice'><b>The administrator has lifted restrictions on joining the round if you use AntagHUD</b></span>"
		action = "lifted restrictions"
		config.antag_hud_restricted = FALSE
		src << "<span class = 'notice'><b>AntagHUD restrictions have been lifted</b></span>"
	else
		for (var/mob/observer/ghost/g in get_ghosts())
			g << "<span class = 'red'><b>The administrator has placed restrictions on joining the round if you use AntagHUD</b></span>"
			g << "<span class = 'red'><b>Your AntagHUD has been disabled, you may choose to re-enabled it but will be under restrictions</b></span>"
			g.antagHUD = FALSE
			g.has_enabled_antagHUD = FALSE
		action = "placed restrictions"
		config.antag_hud_restricted = TRUE
		src << "<span class = 'red'><b>AntagHUD restrictions have been enabled</b></span>"

	log_admin("[key_name(usr)] has [action] on joining the round if they use AntagHUD")
	message_admins("Admin [key_name_admin(usr)] has [action] on joining the round if they use AntagHUD", TRUE)

/*
If a guy was gibbed and you want to revive him, this is a good way to do so.
Works kind of like entering the game with a new character. Character receives a new mind if they didn't have one.
Traitors and the like can also be revived with the previous role mostly intact.
/N */
/client/proc/respawn_character()
	set category = "Special"
	set name = "Respawn Character"
	set desc = "Respawn a person that has been gibbed/dusted/killed. They must be a ghost for this to work and preferably should not have a body to go back into."
	if (!holder)
		src << "Only administrators may use this command."
		return
	var/input = ckey(input(src, "Please specify which key will be respawned.", "Key", ""))
	if (!input)
		return

	var/mob/observer/ghost/G_found
	for (var/mob/observer/ghost/G in player_list)
		if (G.ckey == input)
			G_found = G
			break

	if (!G_found)//If a ghost was not found.
		usr << "<font color='red'>There is no active key like that in the game or the person is not currently a ghost.</font>"
		return

	var/mob/living/carbon/human/new_character = new(pick(latejoin))//The mob being spawned.


	new_character.gender = pick(MALE,FEMALE)
	var/datum/preferences/A = new()
	A.randomize_appearance_for (new_character)
	new_character.real_name = G_found.real_name

	if (!new_character.real_name)
		if (new_character.gender == MALE)
			new_character.real_name = capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))
		else
			new_character.real_name = capitalize(pick(first_names_female)) + " " + capitalize(pick(last_names))
	new_character.name = new_character.real_name

	if (G_found.mind && !G_found.mind.active)
		G_found.mind.transfer_to(new_character)	//be careful when doing stuff like this! I've already checked the mind isn't in use
	//	new_character.mind.special_verbs = list()
	else
		new_character.mind_initialize()
	if (!new_character.mind.assigned_role)	new_character.mind.assigned_role = "Assistant"//If they somehow got a null assigned role.

	//DNA
	new_character.dna.ready_dna(new_character)

	new_character.key = G_found.key

	/*
	The code below functions with the assumption that the mob is already a traitor if they have a special role.
	So all it does is re-equip the mob with powers and/or items. Or not, if they have no special role.
	If they don't have a mind, they obviously don't have a special role.
	*/

	//Two variables to properly announce later on.
	var/admin = key_name_admin(src)
	var/player_key = G_found.key

	job_master.EquipRank(new_character, new_character.mind.assigned_role, TRUE)

	message_admins("<span class = 'notice'>[admin] has respawned [player_key] as [new_character.real_name].</span>", TRUE)

	new_character << "You have been fully respawned. Enjoy the game."


	return new_character

/client/proc/cmd_admin_rejuvenate(mob/living/M as mob in mob_list)
	set category = "Special"
	set name = "Rejuvenate"
	if (!holder)
		src << "Only administrators may use this command."
		return
	if (!mob)
		return
	if (!istype(M))
		WWalert(src, "Cannot revive a ghost", "Rejuvenate - Error")
		return
	if (config.allow_admin_rev)
		M.revive()
		log_admin("[key_name(usr)] healed / revived [key_name(M)]")
		message_admins("<span class = 'red'>Admin [key_name_admin(usr)] healed / revived [key_name_admin(M)]!</span>", TRUE)
	else
		WWalert(src, "Admin rejuvenation is disabled.", "Admin Rejuvenation")


/client/proc/cmd_admin_create_centcom_report()
	set category = "Special"
	set name = "Create Command Report"
	return FALSE

/client/proc/cmd_admin_delete(atom/O as obj|mob|turf in range(world.view))
	set category = "Admin"
	set name = "Delete"

	if (!holder)
		src << "Only administrators may use this command."
		return

	if (WWinput(src, "Are you sure you want to delete:\n[O]\nat ([O.x], [O.y], [O.z])?", "Deletion Confirmation", "Yes", list("Yes", "No")) == "Yes")
		log_admin("[key_name(usr)] deleted [O] at ([O.x],[O.y],[O.z])")
		message_admins("[key_name_admin(usr)] deleted [O] at ([O.x],[O.y],[O.z])", TRUE)

		qdel(O)

/client/proc/cmd_admin_get(atom/movable/O as obj|mob in range(world.view))
	set category = "Admin"
	set name = "Get"

	if (!holder)
		src << "Only administrators may use this command."
		return

	if (!mob || !mob.loc)
		src << "You need a mob to get something."
		return

	if (WWinput(src, "Are you sure you want to get:\n[O]\nat ([O.x], [O.y], [O.z])?", "Get Confirmation", "Yes", list("Yes", "No")) == "Yes")
		O.loc = get_turf(mob)

/client/proc/cmd_admin_list_open_jobs()
	set category = "Admin"
	set name = "List free slots"

	if (!holder)
		src << "Only administrators may use this command."
		return
	if (job_master)
		for (var/datum/job/job in job_master.occupations)
			src << "[job.title]: [job.total_positions]"


/client/proc/cmd_admin_explosion(atom/O as obj|mob|turf in range(world.view))
	set category = "Special"
	set name = "Explosion"

	if (!check_rights(R_DEBUG|R_FUN))	return

	var/devastation = input("Range of total devastation. -1 to none", text("Input"))  as num|null
	if (devastation == null) return
	var/heavy = input("Range of heavy impact. -1 to none", text("Input"))  as num|null
	if (heavy == null) return
	var/light = input("Range of light impact. -1 to none", text("Input"))  as num|null
	if (light == null) return
	var/flash = input("Range of flash. -1 to none", text("Input"))  as num|null
	if (flash == null) return

	if ((devastation != -1) || (heavy != -1) || (light != -1) || (flash != -1))
		if ((devastation > 20) || (heavy > 20) || (light > 20))
			if (WWinput(src, "Are you sure you want to do this? It will laaag.", "Confirmation", "No", list("Yes", "No")) == "No")
				return

		explosion(O, devastation, heavy, light, flash)
		log_admin("[key_name(usr)] created an explosion ([devastation],[heavy],[light],[flash]) at ([O.x],[O.y],[O.z])")
		message_admins("[key_name_admin(usr)] created an explosion ([devastation],[heavy],[light],[flash]) at ([O.x],[O.y],[O.z])", TRUE)

		return
	else
		return

/client/proc/cmd_admin_emp(atom/O as obj|mob|turf in range(world.view))
	set category = "Special"
	set name = "EM Pulse"

	if (!check_rights(R_DEBUG|R_FUN))	return

	var/heavy = input("Range of heavy pulse.", text("Input"))  as num|null
	if (heavy == null) return
	var/light = input("Range of light pulse.", text("Input"))  as num|null
	if (light == null) return

	if (heavy || light)

		empulse(O, heavy, light)
		log_admin("[key_name(usr)] created an EM Pulse ([heavy],[light]) at ([O.x],[O.y],[O.z])")
		message_admins("[key_name_admin(usr)] created an EM PUlse ([heavy],[light]) at ([O.x],[O.y],[O.z])", TRUE)


		return
	else
		return

/client/proc/cmd_admin_gib(mob/M as mob in mob_list)
	set category = "Special"
	set name = "Gib"

	if (!check_rights(R_ADMIN|R_FUN))	return

	var/confirm = WWinput(src, "Are you sure?", "Gib Confirmation", "Yes", list("Yes", "No"))
	if (confirm != "Yes") return
	//Due to the delay here its easy for something to have happened to the mob
	if (!M)	return

	log_admin("[key_name(usr)] has gibbed [key_name(M)]")
	message_admins("[key_name_admin(usr)] has gibbed [key_name_admin(M)]", TRUE)

	if (isobserver(M))
		gibs(M.loc)
		return

	M.gib()

/client/proc/cmd_admin_crush(mob/M as mob in mob_list)
	set category = "Special"
	set name = "Crush"

	if (!check_rights(R_ADMIN|R_FUN))	return

	var/confirm = WWinput(src, "Are you sure?", "Crush Confirmation", "Yes", list("Yes", "No"))
	if (confirm != "Yes") return
	//Due to the delay here its easy for something to have happened to the mob
	if (!M)	return

	log_admin("[key_name(usr)] has crushed [key_name(M)]")
	message_admins("[key_name_admin(usr)] has crushed [key_name_admin(M)]", TRUE)

	if (isobserver(M))
		gibs(M.loc)
		return

	M.crush()

/client/proc/cmd_admin_gib_self()
	set name = "Gibself"
	set category = "Fun"

	var/confirm = WWinput(src, "Are you sure?", "Gibself Confirmation", "Yes", list("Yes", "No"))
	if (confirm == "Yes")
		if (isobserver(mob)) // so they don't spam gibs everywhere
			return
		else
			mob.gib()

		log_admin("[key_name(usr)] used gibself.")
		message_admins("<span class = 'notice'>[key_name_admin(usr)] used gibself.</span>", TRUE)

/client/proc/cmd_admin_crush_self()
	set name = "Crushself"
	set category = "Fun"

	var/confirm = WWinput(src, "Are you sure?", "Crushself Confirmation", "Yes", list("Yes", "No"))
	if (confirm == "Yes")
		if (isobserver(mob)) // so they don't spam gibs everywhere
			return
		else
			mob.crush()

		log_admin("[key_name(usr)] used crushself.")
		message_admins("<span class = 'notice'>[key_name_admin(usr)] used crushself.</span>", TRUE)


/client/proc/update_world()
	// If I see anyone granting powers to specific keys like the code that was here,
	// I will both remove their SVN access and permanently ban them from my servers.
	return

/client/proc/cmd_admin_check_contents(mob/living/M as mob in mob_list)
	set category = "Special"
	set name = "Check Contents"

	var/list/L = M.get_contents()
	for (var/t in L)
		usr << "[t]"


/* This proc is DEFERRED. Does not do anything.
/client/proc/cmd_admin_remove_plasma()
	set category = "Debug"
	set name = "Stabilize Atmos."
	if (!holder)
		src << "Only administrators may use this command."
		return

// DEFERRED
	spawn(0)
		for (var/turf/T in view())
			T.poison = FALSE
			T.oldpoison = FALSE
			T.tmppoison = FALSE
			T.oxygen = 755985
			T.oldoxy = 755985
			T.tmpoxy = 755985
			T.co2 = 14.8176
			T.oldco2 = 14.8176
			T.tmpco2 = 14.8176
			T.n2 = 2.844e+006
			T.on2 = 2.844e+006
			T.tn2 = 2.844e+006
			T.tsl_gas = FALSE
			T.osl_gas = FALSE
			T.sl_gas = FALSE
			T.temp = 293.15
			T.otemp = 293.15
			T.ttemp = 293.15
*/

/client/proc/toggle_view_range()
	set category = "Special"
	set name = "Change View Range"
	set desc = "switches between 1x and custom views"

	if (view == world.view)
		view = input("Select view range:", "FUCK YE", 7) in list(1,2,3,4,5,6,7,8,9,10,11,12,13,14,128)
	else
		view = world.view

	log_admin("[key_name(usr)] changed their view range to [view].")
	//message_admins("\blue [key_name_admin(usr)] changed their view range to [view].", TRUE)	//why? removed by order of XSI



/client/proc/admin_call_shuttle()

	set category = "Admin"
	set name = "Call Shuttle"

	return FALSE

/client/proc/admin_cancel_shuttle()
	set category = "Admin"
	set name = "Cancel Shuttle"

	return FALSE

/client/proc/admin_deny_shuttle()
	set category = "Admin"
	set name = "Toggle Deny Shuttle"

	return FALSE

/client/proc/cmd_admin_attack_log(mob/M as mob in mob_list)
	set category = "Special"
	set name = "Attack Log"

	usr << text("<span class = 'red'><b>Attack Log for []</b></span>", mob)
	for (var/t in M.attack_log)
		usr << t