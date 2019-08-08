/datum/admins/Topic(href, href_list)
	..()

	if (usr.client != owner || !check_rights(0))
		log_admin("[key_name(usr)] tried to use the admin panel without authorization.")
		message_admins("[usr.key] has attempted to override the admin panel!")
		return

	else if (href_list["editrights"])
		if (!check_rights(R_PERMISSIONS))
			message_admins("[key_name_admin(usr)] attempted to edit the admin permissions without sufficient rights.")
			log_admin("[key_name(usr)] attempted to edit the admin permissions without sufficient rights.")
			return

		var/adm_ckey

		var/task = href_list["editrights"]
		if (task == "add")
			var/new_ckey = ckey(input(usr,"New admin's ckey","Admin ckey", null) as text|null)
			if (!new_ckey)	return
			if (new_ckey in admin_datums)
				usr << "<font color='red'>Error: Topic 'editrights': [new_ckey] is already an admin.</font>"
				return
			adm_ckey = new_ckey
			task = "rank"
		else if (task != "show")
			adm_ckey = ckey(href_list["ckey"])
			if (!adm_ckey)
				usr << "<font color='red'>Error: Topic 'editrights': No valid ckey</font>"
				return

		var/datum/admins/D = admin_datums[adm_ckey]

		if (task == "remove")
			if (WWinput(usr, "Are you sure you want to remove [adm_ckey]?", "Remove Admin", "Yes", list("Yes","No")) == "Yes")
				if (!D)	return
				admin_datums -= adm_ckey
				D.disassociate()

				message_admins("[key_name_admin(usr)] removed [adm_ckey] from the admins list")
				log_admin("[key_name(usr)] removed [adm_ckey] from the admins list")
				log_admin_rank_modification(adm_ckey, "Removed")

		else if (task == "rank")

			var/new_rank
			if (admin_ranks.len)
				new_rank = input("Please select a rank", "New rank", null, null) as null|anything in (admin_ranks|"*New Rank*")
			else
				new_rank = input("Please select a rank", "New rank", null, null) as null|anything in list("Host","Sergeant", "Trial Sergeant", "Mentor","*New Rank*")

	/*		var/rights = FALSE
			if (D)
				rights = D.rights */

			switch(new_rank)
				if (null,"") return
				if ("*New Rank*")
					new_rank = input("Please input a new rank", "New custom rank", null, null) as null|text

					if (!new_rank)
						usr << "<font color='red'>Error: Topic 'editrights': Invalid rank</font>"
						return
			/*
			if (D)
				D.disassociate()								//remove adminverbs and unlink from client
				D.rank = new_rank								//update the rank
				D.rights = rights								//update the rights based on admin_ranks (default: FALSE)
			else
				*/

			if (directory.Find(adm_ckey)) // they don't need to be online
				var/client/C = directory[adm_ckey]						//find the client with the specified ckey (if they are logged in)
				if (C.holder)
					C.holder.disassociate()

				D = new /datum/admins(new_rank, FALSE, adm_ckey) // initial rights must be FALSE or their rights do not change!
				D.associate(C)											//link up with the client and add verbs

				C << "<b>[key_name_admin(usr)] has set your admin rank to: [new_rank].</b>"

			message_admins("[key_name_admin(usr)] edited the admin rank of [adm_ckey] to [new_rank].")
			log_admin("[key_name(usr)] edited the admin rank of [adm_ckey] to [new_rank].")
			log_admin_rank_modification(adm_ckey, new_rank)
		//	load_admins(1)

		else if (task == "permissions")
			if (!D)	return
			var/list/permissionlist = list()
			for (var/i=1, i<=R_MAXPERMISSION, i<<=1)		//that <<= is shorthand for i = i << 1. Which is a left bitshift
				permissionlist[rights2text(i)] = i
			var/new_permission = input("Select a permission to turn on/off", "Permission toggle", null, null) as null|anything in permissionlist
			if (!new_permission)	return
			D.rights ^= permissionlist[new_permission]

			var/client/C = directory[adm_ckey]
			C << "[key_name_admin(usr)] has toggled your permission: [new_permission]."
			message_admins("[key_name_admin(usr)] toggled the [new_permission] permission of [adm_ckey]")
			log_admin("[key_name(usr)] toggled the [new_permission] permission of [adm_ckey]")
			log_admin_permission_modification(adm_ckey, permissionlist[new_permission])

		edit_admin_permissions()

	else if (href_list["delay_round_end"])
		if (!check_rights(R_SERVER))	return

		ticker.delay_end = !ticker.delay_end
		log_admin("[key_name(usr)] [ticker.delay_end ? "delayed the round end" : "has made the round end normally"].")
		message_admins("<span class = 'notice'>[key_name(usr)] [ticker.delay_end ? "delayed the round end" : "has made the round end normally"].</span>", TRUE)
		href_list["secretsadmin"] = "check_antagonist"
	else if (href_list["simplemake"])

		if (!check_rights(R_SPAWN))	return

		var/mob/M = locate(href_list["mob"])

		if (!istype(M))
			usr << "This can only be used on instances of type /mob"
			return


		var/delmob = FALSE
		if (href_list["simplemake"] != "gorilla" && href_list["simplemake"] != "werewolf" && href_list["simplemake"] != "default" && href_list["simplemake"] != "orc"&& href_list["simplemake"] != "lizard" && href_list["simplemake"] != "ant" && href_list["simplemake"] != "crab" && href_list["simplemake"] != "wolfman")
			switch(WWinput(usr, "Delete old mob?", "Delete Mob", "Yes", list("Yes","No","Cancel")))
				if ("Cancel")	return
				if ("Yes")		delmob = TRUE

		log_admin("[key_name(usr)] has used rudimentary transformation on [key_name(M)]. Transforming to [href_list["simplemake"]]; deletemob=[delmob]")
		message_admins("<span class = 'notice'>[key_name_admin(usr)] has used rudimentary transformation on [key_name_admin(M)]. Transforming to [href_list["simplemake"]]; deletemob=[delmob]</span>", TRUE)

		switch(href_list["simplemake"])
			if ("observer")			M.change_mob_type( /mob/observer/ghost , null, null, delmob )
			if ("monkey")			M.change_mob_type( /mob/living/simple_animal/monkey , null, null, delmob )
			if ("cat")				M.change_mob_type( /mob/living/simple_animal/cat , null, null, delmob )
			if ("parrot")			M.change_mob_type( /mob/living/simple_animal/parrot , null, null, delmob )
			if ("chicken")			M.change_mob_type( /mob/living/simple_animal/chicken , null, null, delmob )
			if ("turkey")			M.change_mob_type( /mob/living/simple_animal/turkey_m , null, null, delmob )
			if ("cow")			M.change_mob_type( /mob/living/simple_animal/cow , null, null, delmob )
			if ("bull")			M.change_mob_type( /mob/living/simple_animal/bull , null, null, delmob )
			if ("mouse")			M.change_mob_type( /mob/living/simple_animal/mouse , null, null, delmob )
			if ("bear")			M.change_mob_type( /mob/living/simple_animal/hostile/bear , null, null, delmob )
			if ("velociraptor")			M.change_mob_type( /mob/living/simple_animal/hostile/dinosaur/velociraptor , null, null, delmob )
			if ("default")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.gorillaman = 0
					HM.werewolf = 0
					HM.orc = 0
					HM.ant= 0
					HM.lizard = 0
					HM.wolfman = 0
					HM.crab = 0
					HM.body_build = get_body_build(M.gender,"Default")
					HM.update_hair()
					HM.change_facial_hair()
					HM.force_update_limbs()
					HM.update_body()
					HM.update_hair()
			if ("gorilla")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.gorillaman = 1
					HM.werewolf = 0
					HM.orc = 0
					HM.ant= 0
					HM.lizard = 0
					HM.wolfman = 0
					HM.crab = 0
			if ("werewolf")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.werewolf = 1
					HM.gorillaman = 0
					HM.orc = 0
					HM.ant= 0
					HM.lizard = 0
					HM.wolfman = 0
					HM.crab = 0
			if ("orc")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.orc = 1
					HM.gorillaman = 0
					HM.werewolf = 0
					HM.ant= 0
					HM.lizard = 0
					HM.wolfman = 0
					HM.crab = 0
			if ("ant")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.ant = 1
					HM.gorillaman = 0
					HM.werewolf = 0
					HM.orc = 0
					HM.lizard = 0
					HM.wolfman = 0
					HM.crab = 0
			if ("lizard")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.lizard = 1
					HM.ant = 0
					HM.gorillaman = 0
					HM.werewolf = 0
					HM.orc = 0
					HM.wolfman = 0
					HM.crab = 0
			if ("crab")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.lizard = 0
					HM.ant = 0
					HM.gorillaman = 0
					HM.werewolf = 0
					HM.orc = 0
					HM.wolfman = 0
					HM.crab = 1
			if ("wolfman")
				var/mob/living/carbon/human/HM = M
				if (!ishuman(M))
					usr << "This can only be used on instances of type /mob/living/carbon/human"
					return
				else
					HM.lizard = 0
					HM.ant = 0
					HM.gorillaman = 0
					HM.werewolf = 0
					HM.orc = 0
					HM.wolfman = 1
					HM.crab = 0
	else if (href_list["warn"])
		usr.client.warn(href_list["warn"])

	else if (href_list["boot2"])
		var/mob/M = locate(href_list["boot2"])
		if (ismob(M))
			if (!check_if_greater_rights_than(M.client))
				return
			var/reason = sanitize(input("Please enter reason"))
			if (!reason)
				M << "<span class = 'userdanger'>You have been kicked from the server.</span>"
			else
				M << "<span class = 'userdanger'>You have been kicked from the server. ([reason])</span>"
			log_admin("[key_name(usr)] booted [key_name(M)].")
			message_admins("<span class = 'notice'>[key_name_admin(usr)] booted [key_name_admin(M)].</span>", TRUE)
			//M.client = null
			qdel(M.client)

	else if (href_list["mute"])
		if (!check_rights(R_MOD,0) && !check_rights(R_ADMIN))  return

		var/mob/M = locate(href_list["mute"])
		if (!ismob(M))	return
		if (!M.client)	return

		var/mute_type = href_list["mute_type"]
		if (istext(mute_type))	mute_type = text2num(mute_type)
		if (!isnum(mute_type))	return

		cmd_admin_mute(M, mute_type)


	else if (href_list["forcespeech"])
		if (!check_rights(R_FUN))	return

		var/mob/M = locate(href_list["forcespeech"])
		if (!ismob(M))
			usr << "this can only be used on instances of type /mob"

		var/speech = input("What will [key_name(M)] say?.", "Force speech", "")// Don't need to sanitize, since it does that in say(), we also trust our admins.
		if (!speech)	return
		M.say(speech)
		speech = sanitize(speech) // Nah, we don't trust them
		log_admin("[key_name(usr)] forced [key_name(M)] to say: [speech]")
		message_admins("<span class = 'notice'>[key_name_admin(usr)] forced [key_name_admin(M)] to say: [speech]</span>")

	else if (href_list["revive"])
		if (!check_rights(R_REJUVINATE))	return

		var/mob/living/L = locate(href_list["revive"])
		if (!istype(L))
			usr << "This can only be used on instances of type /mob/living"
			return

		if (config.allow_admin_rev)
			L.revive()
			message_admins("<span class = 'red'>Admin [key_name_admin(usr)] healed / revived [key_name_admin(L)]!</span>", TRUE)
			log_admin("[key_name(usr)] healed / revived [key_name(L)]")
		else
			usr << "Admin Rejuvinates have been disabled"

	else if (href_list["adminplayeropts"])
		var/mob/M = locate(href_list["adminplayeropts"])
		show_player_panel(M)

	else if (href_list["adminplayerobservejump"])
		if (!check_rights(R_MENTOR|R_MOD|R_ADMIN))	return

		var/mob/M = locate(href_list["adminplayerobservejump"])

		var/client/C = usr.client
		if (!isghost(usr))	C.admin_ghost()
		sleep(2)
		C.jumptomob(M)
/*
	else if (href_list["check_antagonist"])
		check_antagonists()*/

	else if (href_list["adminplayerobservecoodjump"])
		if (!check_rights(R_ADMIN|R_MOD))	return

		var/x = text2num(href_list["X"])
		var/y = text2num(href_list["Y"])
		var/z = text2num(href_list["Z"])

		var/client/C = usr.client
		if (!isghost(usr))	C.admin_ghost()
		sleep(2)
		C.jumptocoord(x,y,z)

	else if (href_list["adminchecklaws"])
		output_ai_laws()

	else if (href_list["adminmoreinfo"])
		var/mob/M = locate(href_list["adminmoreinfo"])
		if (!ismob(M))
			usr << "This can only be used on instances of type /mob"
			return

		var/location_description = ""
		var/special_role_description = ""
		var/health_description = ""
		var/gender_description = ""
		var/turf/T = get_turf(M)

		//Location
		if (isturf(T))
			if (isarea(T.loc))
				location_description = "([M.loc == T ? "at coordinates " : "in [M.loc] at coordinates "] [T.x], [T.y], [T.z] in area <b>[T.loc]</b>)"
			else
				location_description = "([M.loc == T ? "at coordinates " : "in [M.loc] at coordinates "] [T.x], [T.y], [T.z])"

		//Job + antagonist
		if (M.mind)
			special_role_description = "Role: <b>[M.mind.assigned_role]</b>; Antagonist: <font color='red'><b>[M.mind.special_role]</b></font>; Has been rev: [(M.mind.has_been_rev)?"Yes":"No"]"
		else
			special_role_description = "Role: <i>Mind datum missing</i> Antagonist: <i>Mind datum missing</i>; Has been rev: <i>Mind datum missing</i>;"

		//Health
		if (isliving(M))
			var/mob/living/L = M
			var/status
			switch (M.stat)
				if (0) status = "Alive"
				if (1) status = "<font color='orange'><b>Unconscious</b></font>"
				if (2) status = "<font color='red'><b>Dead</b></font>"
			health_description = "Status = [status]"
			health_description += "<BR>Oxy: [L.getOxyLoss()] - Tox: [L.getToxLoss()] - Fire: [L.getFireLoss()] - Brute: [L.getBruteLoss()] - Clone: [L.getCloneLoss()] - Brain: [L.getBrainLoss()]"
		else
			health_description = "This mob type has no health to speak of."

		//Gener
		switch(M.gender)
			if (MALE,FEMALE)	gender_description = "[M.gender]"
			else			gender_description = "<font color='red'><b>[M.gender]</b></font>"

		owner << "<b>Info about [M.name]:</b> "
		owner << "Mob type = [M.type]; Gender = [gender_description] Damage = [health_description]"
		owner << "Name = <b>[M.name]</b>; Real_name = [M.real_name]; Mind_name = [M.mind?"[M.mind.name]":""]; Key = <b>[M.key]</b>;"
		owner << "Location = [location_description];"
		owner << "[special_role_description]"
		owner << "(<a href='?src=\ref[usr];priv_msg=\ref[M]'>PM</a>) (<A HREF='?src=\ref[src];adminplayeropts=\ref[M]'>PP</A>) (<A HREF='?_src_=vars;Vars=\ref[M]'>VV</A>) (<A HREF='?src=\ref[src];subtlemessage=\ref[M]'>SM</A>) ([admin_jump_link(M, src)]) (<A HREF='?src=\ref[src];secretsadmin=check_antagonist'>CA</A>)"

	else if (href_list["adminspawncookie"])
		if (!check_rights(R_ADMIN|R_FUN))	return

		var/mob/living/carbon/human/H = locate(href_list["adminspawncookie"])
		if (!ishuman(H))
			usr << "This can only be used on instances of type /mob/living/carbon/human"
			return

		H.equip_to_slot_or_del( new /obj/item/weapon/reagent_containers/food/snacks/cookie(H), slot_l_hand )
		if (!(istype(H.l_hand,/obj/item/weapon/reagent_containers/food/snacks/cookie)))
			H.equip_to_slot_or_del( new /obj/item/weapon/reagent_containers/food/snacks/cookie(H), slot_r_hand )
			if (!(istype(H.r_hand,/obj/item/weapon/reagent_containers/food/snacks/cookie)))
				log_admin("[key_name(H)] has their hands full, so they did not receive their cookie, spawned by [key_name(owner)].")
				message_admins("[key_name(H)] has their hands full, so they did not receive their cookie, spawned by [key_name(owner)].")
				return
			else
				H.update_inv_r_hand()//To ensure the icon appears in the HUD
		else
			H.update_inv_l_hand()
		log_admin("[key_name(H)] got their cookie, spawned by [key_name(owner)]")
		message_admins("[key_name(H)] got their cookie, spawned by [key_name(owner)]")

		H << "<span class = 'notice'>Your prayers have been answered!! You received the <b>best cookie</b>!</span>"

	else if (href_list["jumpto"])
		if (!check_rights(R_ADMIN))	return

		var/mob/M = locate(href_list["jumpto"])
		usr.client.jumptomob(M)

	else if (href_list["getmob"])
		if (!check_rights(R_ADMIN))	return

		if (WWinput(usr, "Confirm?", "Message", "Yes", list("Yes", "No")) != "Yes")	return
		var/mob/M = locate(href_list["getmob"])
		usr.client.Getmob(M)

	else if (href_list["sendmob"])
		if (!check_rights(R_ADMIN))	return

		var/mob/M = locate(href_list["sendmob"])
		usr.client.sendmob(M)

	else if (href_list["narrateto"])
		if (!check_rights(R_ADMIN))	return

		var/mob/M = locate(href_list["narrateto"])
		usr.client.cmd_admin_direct_narrate(M)

	else if (href_list["subtlemessage"])
		if (!check_rights(R_MOD,0) && !check_rights(R_ADMIN))  return

		var/mob/M = locate(href_list["subtlemessage"])
		usr.client.cmd_admin_subtle_message(M)

	else if (href_list["create_object"])
		if (!check_rights(R_SPAWN))	return
		return create_object(usr)

	else if (href_list["quick_create_object"])
		if (!check_rights(R_SPAWN))	return
		return quick_create_object(usr)

	else if (href_list["create_turf"])
		if (!check_rights(R_SPAWN))	return
		return create_turf(usr)

	else if (href_list["create_mob"])
		if (!check_rights(R_SPAWN))	return
		return create_mob(usr)

	else if (href_list["debug_global"])
		if (!check_rights(R_DEBUG))	return
		var/client/C = isclient(usr) ? usr : usr.client
		var/somevar = input(usr, "Debug what global variable?") as text
		if (global.vars:Find(somevar)) // prevents runtimes
			var/thing = global.vars[somevar]
			if (isdatum(thing) || isclient(thing))
				C.debug_variables(thing)
			else if (!islist(thing))
				usr << "[somevar] = [thing]"
			else
				var/list/L = thing
				if (!L.len)
					usr << "[somevar] is an empty list"
				else if (list_is_assoc(L))
					usr << "[somevar] is an <b>ASSOCIATIVE</b> list"
					for (var/i in TRUE to L.len)
						usr << "element [i]: [thing[i]] = [thing[thing[i]]]"
				else
					usr << "[thing] is a list"
					for (var/i in TRUE to L.len)
						usr << "element [i]: [thing[i]]"

	else if (href_list["modify_global"])
		if (!check_rights(R_DEBUG))	return
		var/somevar = input(usr, "Modify what global variable?") as text
		if (global.vars:Find(somevar)) // prevents runtimes
			var/thing = global.vars[somevar]
			if (isdatum(thing) || isclient(thing) || islist(thing))
				usr << "[somevar] is a datum, client, or list. You can't edit it here. For datums & clients, use the 'View/Debug a global' to edit their variables."
				return
			else
				var/changeto = input(usr, "Change this global variable to what type?") in list("Empty List", "Text", "Num", "Cancel")
				switch (lowertext(changeto))
					if ("empty list")
						global.vars[somevar] = list()
					if ("text")
						global.vars[somevar] = input(usr, "What text?") as text
					if ("num")
						global.vars[somevar] = input(usr, "What num?") as num

	else if (href_list["modify_world_var"])
		if (!check_rights(R_DEBUG))	return
		var/somevar = input(usr, "Modify what world variable?") as text
		if (world.vars.Find(somevar)) // prevents runtimes
			var/thing = world.vars[somevar]
			if (isdatum(thing) || isclient(thing) || islist(thing))
				usr << "[somevar] is a datum, client, or list. You can't edit it here. For datums & clients, use the 'View/Debug a global' to edit their variables."
				return
			else
				usr << "[somevar] is [thing]"
				// this is somehow broken
				var/changeto = input(usr, "Change this world variable to what type?") in list("Empty List", "Text", "Num", "Cancel")
				switch (lowertext(changeto))
					if ("empty list")
						world.vars[somevar] = list()
					if ("text")
						world.vars[somevar] = input(usr, "What text?") as text
					if ("num")
						world.vars[somevar] = input(usr, "What num?") as num

	else if (href_list["object_list"])			//this is the laggiest thing ever
		if (!check_rights(R_SPAWN))	return

		if (!config.allow_admin_spawning)
			usr << "Spawning of items is not allowed."
			return

		var/atom/loc = usr.loc

		var/dirty_paths
		if (istext(href_list["object_list"]))
			dirty_paths = list(href_list["object_list"])
		else if (istype(href_list["object_list"], /list))
			dirty_paths = href_list["object_list"]

		var/paths = list()

		for (var/dirty_path in dirty_paths)
			var/path = text2path(dirty_path)
			if (!path)
				continue
			paths += path

		if (!paths)
			WWalert(usr, "The path list you sent is empty", "Error")
			return
		if (length(paths) > 5)
			WWalert(usr, "Select fewer object types, (max 5)", "Error")
			return

		var/list/offset = splittext(href_list["offset"],",")
		var/number = dd_range(1, 100, text2num(href_list["object_count"]))
		var/X = offset.len > 0 ? text2num(offset[1]) : FALSE
		var/Y = offset.len > 1 ? text2num(offset[2]) : FALSE
		var/Z = offset.len > 2 ? text2num(offset[3]) : FALSE
		var/tmp_dir = href_list["object_dir"]
		var/obj_dir = tmp_dir ? text2num(tmp_dir) : 2
		if (!obj_dir || !(obj_dir in list(1,2,4,8,5,6,9,10)))
			obj_dir = 2
		var/obj_name = sanitize(href_list["object_name"])


		var/atom/target //Where the object will be spawned
		var/where = href_list["object_where"]
		if (!( where in list("onfloor","inhand","inmarked") ))
			where = "onfloor"

		switch(where)
			if ("inhand")
				if (!iscarbon(usr))
					usr << "Can only spawn in hand when you're a carbon mob."
					where = "onfloor"
				target = usr

			if ("onfloor")
				switch(href_list["offset_type"])
					if ("absolute")
						target = locate(0 + X,0 + Y,0 + Z)
					if ("relative")
						target = locate(loc.x + X,loc.y + Y,loc.z + Z)
			if ("inmarked")
				if (!marked_datum())
					usr << "You don't have any object marked. Abandoning spawn."
					return
				else if (!istype(marked_datum(),  /atom))
					usr << "The object you have marked cannot be used as a target. Target must be of type /atom. Abandoning spawn."
					return
				else
					target = marked_datum()

		if (target)
			for (var/path in paths)
				for (var/i = FALSE; i < number; i++)
					if (path in typesof(/turf))
						var/turf/O = target
						var/turf/N = O.ChangeTurf(path)
						if (N && obj_name)
							N.name = obj_name
					else
						var/atom/O = new path(target)
						if (O)
							O.set_dir(obj_dir)
							if (obj_name)
								O.name = obj_name
								if (istype(O,/mob))
									var/mob/M = O
									M.real_name = obj_name
							if (where == "inhand" && isliving(usr) && istype(O, /obj/item))
								var/mob/living/L = usr
								var/obj/item/I = O
								L.put_in_hands(I)


		log_and_message_admins("created [number] [english_list(paths)]")
		return

	else if (href_list["admin_secrets"])
		var/datum/admin_secret_item/item = locate(href_list["admin_secrets"]) in admin_secrets.items
		item.execute(usr)

	else if (href_list["toglang"])
		if (check_rights(R_SPAWN))
			var/mob/M = locate(href_list["toglang"])
			if (!istype(M))
				usr << "[M] is illegal type, must be /mob!"
				return
			var/lang2toggle = href_list["lang"]
			var/datum/language/L = all_languages[lang2toggle]

			if (L in M.languages)
				if (!M.remove_language(lang2toggle))
					usr << "Failed to remove language '[lang2toggle]' from \the [M]!"
			else
				if (!M.add_language(lang2toggle))
					usr << "Failed to add language '[lang2toggle]' from \the [M]!"

			show_player_panel(M)

	// player info stuff

	if (href_list["add_player_info"])
		var/key = href_list["add_player_info"]
		var/add = sanitize(input("Add Player Info") as null|text)
		if (!add) return

		notes_add(key,add,usr)
		show_player_info(key)

	if (href_list["remove_player_info"])
		var/key = href_list["remove_player_info"]
		var/index = text2num(href_list["remove_index"])

		notes_del(key, index)
		show_player_info(key)

	if (href_list["notes"])
		var/ckey = href_list["ckey"]
		if (!ckey)
			var/mob/M = locate(href_list["mob"])
			if (ismob(M))
				ckey = M.ckey

		switch(href_list["notes"])
			if ("show")
				show_player_info(ckey)
			if ("list")
				PlayerNotesPage(text2num(href_list["index"]))
		return

mob/living/proc/can_centcom_reply()
	return FALSE

mob/living/carbon/human/can_centcom_reply()
	return FALSE

/atom/proc/extra_admin_link()
	return

/mob/extra_admin_link(var/source)
/*	if (client && eyeobj)
		return "|<A HREF='?[source];adminplayerobservejump=\ref[eyeobj]'>EYE</A>"
*/
	return null

/mob/observer/ghost/extra_admin_link(var/source)
	if (mind && mind.current)
		return "|<A HREF='?[source];adminplayerobservejump=\ref[mind.current]'>BDY</A>"

/proc/admin_jump_link(var/atom/target, var/source)
	if (!target) return
	// The way admin jump links handle their src is weirdly inconsistent...
	if (istype(source, /datum/admins))
		source = "src=\ref[source]"
	else
		source = "_src_=holder"

	. = "<A HREF='?[source];adminplayerobservejump=\ref[target]'>JMP</A>"
	. += target.extra_admin_link(source)
