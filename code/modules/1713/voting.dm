/obj/structure/voting
	name = "ballot box"
	desc = "A box storing votes for an election."
	icon = 'icons/obj/storage.dmi'
	icon_state = "bet_box"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

	var/nation = "none"

	var/list/votes = list()
	var/list/voted = list()
	var/in_election = FALSE
	var/election_desc = ""
	var/list/vote_options = list()
	var/total_votes = 0

	//voyage stuff
	var/special_election = FALSE
	var/found_captain = FALSE
	var/found_boatswain = FALSE
	var/found_quartermaster = FALSE
	var/mob/living/human/person = null
	var/person_role = ""
/obj/structure/voting/civa
	name = "ballot box"
	icon_state = "bet_box_red"
	New()
		..()
		spawn(10)
			nation = civname_a
			name = "[nation] ballot box"
	attack_hand(var/mob/living/human/user as mob)
		if (user.original_job_title == "Civilization A Citizen")
			..()
		else
			user << "You are not part of this Nation."
			return

/obj/structure/voting/civb
	name = "ballot box"
	icon_state = "bet_box_green"
	New()
		..()
		spawn(10)
			nation = civname_b
			name = "[nation] ballot box"
	attack_hand(var/mob/living/human/user as mob)
		if (user.original_job_title == "Civilization B Citizen")
			..()
		else
			user << "You are not part of this Nation."
			return

/obj/structure/voting/civc
	name = "ballot box"
	icon_state = "bet_box_blue"
	New()
		..()
		spawn(10)
			nation = civname_c
			name = "[nation] ballot box"
	attack_hand(var/mob/living/human/user as mob)
		if (user.original_job_title == "Civilization C Citizen")
			..()
		else
			user << "You are not part of this Nation."
			return

/obj/structure/voting/pirates
	name = "ballot box"
	icon_state = "bet_box_red"

	attack_hand(var/mob/living/human/user as mob)
		if (user.faction_text == PIRATES)
			..()
		else
			user << "You are not part of this Faction."
			return
/obj/structure/voting/proc/find_roles()
	found_captain = FALSE
	found_boatswain = FALSE
	found_quartermaster = FALSE
	for(var/mob/living/human/H in mob_list)
		if(H.original_job_title == "Pirate Captain" && H.stat != DEAD)
			found_captain = TRUE
		if(H.original_job_title == "Pirate Boatswain" && H.stat != DEAD)
			found_boatswain = TRUE
		if(H.original_job_title == "Pirate Quartermaster" && H.stat != DEAD)
			found_quartermaster = TRUE

/obj/structure/voting/examine(mob/user)
	..()
	if (in_election)
		user << "Currently voting for: <b>[election_desc]</b>"
		user << "<b>A total of [total_votes] votes have been cast.</b>"
	else
		user << "<b>No current vote.</b>"

/obj/structure/voting/attack_hand(var/mob/living/human/user as mob)
	if (in_election)
		if (!(user in voted))
			total_votes += 1
			var/choice = WWinput(user, "[election_desc]", "Electoral System","Null",vote_options+"Null")
			if (choice != "Null" && !(user in voted))
				votes[choice] += 1
				voted += user
				return

		else
			WWalert(user, "You already voted!", "Electoral System")
			return
		return
	else
		if (in_election)
			return
		if (user.original_job.title == "Pirate Surgeon")
			return
		var/previous_input = "Officer"
		if (user.title == "Captain" || user.title == "Boatswain" || user.title == "Quartermaster" || map.ID != MAP_VOYAGE)
			previous_input = "Custom Vote"
		if (previous_input == "Officer")
			find_roles()
			var/list/choicelist = list("Cancel")
			if(!found_captain)
				choicelist += "Captain"
			if(!found_boatswain)
				choicelist += "Boatswain"
			if(!found_quartermaster)
				choicelist += "Quartermaster"
			var/choose_officer = WWinput(user, "Which free position do you want to run for?","Electoral System","Cancel",choicelist)
			if(!choose_officer || choose_officer == "Cancel" || choose_officer == "")
				return
			if(choose_officer != "Captain" && choose_officer != "Quartermaster" && choose_officer != "Boatswain")
				return
			special_election = TRUE
			in_election = TRUE
			election_desc = "Shall [user] be the new [choose_officer]?"
			person = user
			person_role = choose_officer
			vote_options = list("Yes","No")
		else
			var/inpt = input(user, "What do you want the vote to be on? (Leave blank to cancel)", "Electoral System", "") as text
			if (!inpt || inpt == "" || in_election)
				return
			if (in_election)
				return
			var/inpt2 = input(user, "What options should the vote have? Separate them with ';'. (example: 'Yes;No') (Leave blank to cancel)", "Electoral System", "") as text
			if (!inpt || inpt == "" || in_election)
				return
			var/inpt2_parsed = splittext(inpt2,";")
			in_election = TRUE
			election_desc = inpt
			vote_options = inpt2_parsed
		voted = list()
		votes = list()
		total_votes = 0
		for(var/j in vote_options)
			votes += list("[j]" = 0)
		world << "<big><font color='yellow'>A vote has started! Results in 2 minutes.</big></font>"
		world << "<big><font color='yellow'><b><i>[election_desc]</i></b></big></font>"
		for(var/i in vote_options)
			world << "<font color='yellow'><b><i>&nbsp;&nbsp;&nbsp;&nbsp;[i]</i></b></font>"
		start_timer(1200)

/obj/structure/voting/proc/start_timer(var/time = 1800)
	spawn(time)
		in_election = FALSE
		if (total_votes == 0)
			world << "<big><font color='yellow'><b>The election ended with no votes!</b></big></font>"
		var/winner = "none"
		var/sum = 0
		for(var/j in votes)
			if (votes[j] > sum)
				sum = votes[j]
				winner = j
			else if (votes[j] == sum && sum != 0)
				winner = "tie"
		if (winner != "tie")
			world << "<big><font color='yellow'><b><i>[winner]</i></b> is the most voted choice!</big></font>"
		else
			world << "<big><font color='yellow'>The vote ended in a <b><i>tie</i></b>!</big></font>"
		if(total_votes > 0)
			world << "<font color='yellow'><b>Results:</b></font>"
			for(var/i in votes)
				world << "<font color='yellow'><b><i>[i]</i> - [(votes[i]/total_votes)*100]% ([votes[i]] votes)</b></font>"
			total_votes = 0
			if(special_election && winner == "Yes")
				world << "<big><font color='yellow'>[person] has been elected as the new [person_role].</font></big>"
				if(person)
					person.original_job_title = "Pirate [person_role]"
					person.name = replacetext(person.name,"[person.title] ","")
					person.title = person_role
					person.name = "[person.title] [person.name]"
					person.original_job = job_master.GetJob("Pirate [person_role]")
					if(person_role == "Boatswain")
						person.make_title_changer()
					person.make_commander()
					person.make_artillery_officer()
					WWalert(person,"You are the new [person_role]!","Election Winner")
			person = null
			person_role = ""
	return