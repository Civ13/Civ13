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
		visible_message("<big><font color='yellow'>A vote has started! Results in 3 minutes.</big></font>")
		visible_message("<big><font color='yellow'><b><i>[election_desc]</i></b></big></font>")
		for(var/i in vote_options)
			visible_message("<font color='yellow'><b><i>&nbsp;&nbsp;&nbsp;&nbsp;[i]</i></b></font>")
		start_timer(1800)

/obj/structure/voting/proc/start_timer(var/time = 1800)
	spawn(time)
		in_election = FALSE
		if (total_votes == 0)
			visible_message("<big><font color='yellow'><b>The election ended with no votes!</b></big></font>")
		var/winner = "none"
		var/sum = 0
		for(var/j in votes)
			if (votes[j] > sum)
				sum = votes[j]
				winner = j
			else if (votes[j] == sum && sum != 0)
				winner = "tie"
		if (winner != "tie")
			visible_message("<big><font color='yellow'><b><i>[winner]</i></b> is the most voted choice!</big></font>")
		else
			visible_message("<big><font color='yellow'>The vote ended in a <b><i>tie</i></b>!</big></font>")
		visible_message("<font color='yellow'><b>Results:</b></font>")
		for(var/i in votes)
			visible_message("<font color='yellow'><b><i>[i]</i> - [(votes[i]/total_votes)*100]% ([votes[i]] votes)</b></font>")
		total_votes = 0
	return