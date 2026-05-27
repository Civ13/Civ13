
/obj/map_metadata/wizard_boy
	ID = MAP_WIZARD_BOY
	title = "Test Map"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	lobby_icon = "icons/lobby/wizard_boy.png"
	faction_organization = list(CIVILIAN)

	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/british)
	age = "2013"

	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = ""
	mission_start_message = ""
	ambience = list("sound/ambience/desert.ogg")
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	gamemode = "Testing"
	ordinal_age = 8
	default_research = 230
	research_active = FALSE
	gamemode_vote = FALSE
	var/alist/house_info = alist()

	New()
		..()
		spawn(30)
			ticker.pregame_timeleft = 5
			load_houses()

	update_win_condition()
		return

/obj/map_metadata/wizard_boy/proc/load_houses()
	if (fexists("SQL/houses.txt"))
		house_info = alist()
		//load a txt file from config/houses.txt, format is ckey;housename
		var/list/houses = file2list("SQL/houses.txt")
		for(var/i = 1, i <= length(houses), i++)
			var/list/house_info = splittext(houses[i], ";")
			if(length(house_info) != 2)
				continue
			var/ckey = house_info[1]
			var/housename = house_info[2]
			house_info[ckey] = housename

/obj/map_metadata/wizard_boy/proc/check_house(ckey)
	if(!house_info[ckey])
		load_houses()
		if(!house_info[ckey])
			return "Unknown"
	return house_info[ckey]

/obj/map_metadata/wizard_boy/proc/add_to_house(ckey, house)
	//sanitise first
	if (house == "Rubywyrm" || house == "Mintysnek" || house == "Slatepie" || house == "Mustardweasel")
		var/txtexport = ckey + ";" + house

		//save to houses.txt
		if (fexists("SQL/houses.txt"))
			text2file(txtexport,"SQL/houses.txt")
		else
			var/F = file("SQL/houses.txt")
			text2file(txtexport, F)

/obj/map_metadata/wizard_boy/proc/house_test(client/C)
	if (!C || !istype(C))
		return FALSE
	if (check_house(C.ckey) != "Unknown")
		return FALSE

	var/choice = WWinput(C, "Hold your horses, lad. You have not been sorted into a house yet! How would you like to proceed?", "House Selection", null, list("I'll take the 5 question sorting test!", "Just randomly assign me"))
	if (!choice)
		return FALSE

	if (choice == "Just randomly assign me")
		var/winning_house = pick("Mustardweasel","Mintysnek","Rubywyrm", "Slatepie")
		add_to_house(C.ckey, winning_house)
		var/color = "#FFFFFF"
		switch(winning_house)
			if("Rubywyrm")
				color = "#CF0000"
			if("Mintysnek")
				color = "#00CF00"
			if("Slatepie")
				color = "#0000CF"
			if("Mustardweasel")
				color = "#FFD700"
		to_chat(C, "<font size=4>You have been sorted into <b><span style='color:[color];'>[winning_house]</span></b>!</font>")
		return TRUE

	var/list/scores = list("Rubywyrm" = 0, "Slatepie" = 0, "Mintysnek" = 0, "Mustardweasel" = 0)

	// Question 1
	var/list/q1_choices = list(
		"Cast Explodus! directly at the hinges. Who cares if the wall collapses?" = "Rubywyrm",
		"Examine the wood grain, find the keyhole, and use Pullus! to slide the key under the door from the inside." = "Slatepie",
		"Lie to a first-year student and convince them that picking the lock is part of their exam." = "Mintysnek",
		"Knock politely. If that fails, sit down and wait outside with a thermos of tea." = "Mustardweasel"
	)
	var/list/q1_keys = list(
		"Cast Explodus! directly at the hinges. Who cares if the wall collapses?",
		"Examine the wood grain, find the keyhole, and use Pullus! to slide the key under the door from the inside.",
		"Lie to a first-year student and convince them that picking the lock is part of their exam.",
		"Knock politely. If that fails, sit down and wait outside with a thermos of tea."
	)
	var/choice1 = WWinput(C, "Question 1: You find a locked wooden door blocking your path. How do you bypass it?", "House Selection", null, shuffle(q1_keys))
	if (!choice1)
		return FALSE
	var/house1 = q1_choices[choice1]
	if (house1)
		scores[house1]++

	// Question 2
	var/list/q2_choices = list(
		"Show up with a modified O-Cedar Master-Sweep and immediately challenge him to a fistfight instead." = "Rubywyrm",
		"Study his previous flight patterns and calculate the exact angle to deflect his next spell." = "Slatepie",
		"Sneak into the stables and grease his mop-handle with lard before the match starts." = "Mintysnek",
		"Offer him a Choco-Toad and ask if he wants to just play cards in the common room." = "Mustardweasel"
	)
	var/list/q2_keys = list(
		"Show up with a modified O-Cedar Master-Sweep and immediately challenge him to a fistfight instead.",
		"Study his previous flight patterns and calculate the exact angle to deflect his next spell.",
		"Sneak into the stables and grease his mop-handle with lard before the match starts.",
		"Offer him a Choco-Toad and ask if he wants to just play cards in the common room."
	)
	var/choice2 = WWinput(C, "Question 2: Franco Badfaith challenges you to a midnight Mop Ball duel. What is your strategy?", "House Selection", null, shuffle(q2_keys))
	if (!choice2)
		return FALSE
	var/house2 = q2_choices[choice2]
	if (house2)
		scores[house2]++

	// Question 3
	var/list/q3_choices = list(
		"Running bare-chested through the mud to build \"character\" and immunity to frostbite." = "Rubywyrm",
		"Sitting in the draftiest corner of the library, quietly sighing and reading about ancient runes." = "Slatepie",
		"Selling watered-down Taffia rum behind the greenhouse to the older students." = "Mintysnek",
		"Helping Hagrag clean out the giant badger cages because they looked lonely." = "Mustardweasel"
	)
	var/list/q3_keys = list(
		"Running bare-chested through the mud to build \"character\" and immunity to frostbite.",
		"Sitting in the draftiest corner of the library, quietly sighing and reading about ancient runes.",
		"Selling watered-down Taffia rum behind the greenhouse to the older students.",
		"Helping Hagrag clean out the giant badger cages because they looked lonely."
	)
	var/choice3 = WWinput(C, "Question 3: It is a rainy Tuesday in the Welsh valleys (again). What are you doing?", "House Selection", null, shuffle(q3_keys))
	if (!choice3)
		return FALSE
	var/house3 = q3_choices[choice3]
	if (house3)
		scores[house3]++

	// Question 4
	var/list/q4_choices = list(
		"A miniature red dragon that accidentally sets your homework on fire." = "Rubywyrm",
		"A cynical magpie that steals shiny objects and corrects people's spelling." = "Slatepie",
		"A venomous garden lizard that you keep hidden in your sock." = "Mintysnek",
		"A very long, chaotic ferret that sleeps in your sleeve and steals everyone's pens." = "Mustardweasel"
	)
	var/list/q4_keys = list(
		"A miniature red dragon that accidentally sets your homework on fire.",
		"A cynical magpie that steals shiny objects and corrects people's spelling.",
		"A venomous garden lizard that you keep hidden in your sock.",
		"A very long, chaotic ferret that sleeps in your sleeve and steals everyone's pens."
	)
	var/choice4 = WWinput(C, "Question 4: Choose your ideal magical companion:", "House Selection", null, shuffle(q4_keys))
	if (!choice4)
		return FALSE
	var/house4 = q4_choices[choice4]
	if (house4)
		scores[house4]++

	// Question 5
	var/list/q5_choices = list(
		"Blowing things up in a spectacular fashion to show off." = "Rubywyrm",
		"The systematic study of universal laws, logic, and ancient lore." = "Slatepie",
		"A tool to get rich, skip chores, and outsmart the people in charge." = "Mintysnek",
		"Making cool glowing lights and helping your friends survive." = "Mustardweasel"
	)
	var/list/q5_keys = list(
		"Blowing things up in a spectacular fashion to show off.",
		"The systematic study of universal laws, logic, and ancient lore.",
		"A tool to get rich, skip chores, and outsmart the people in charge.",
		"Making cool glowing lights and helping your friends survive."
	)
	var/choice5 = WWinput(C, "Question 5: What is the true meaning of magic?", "House Selection", null, shuffle(q5_keys))
	if (!choice5)
		return FALSE
	var/house5 = q5_choices[choice5]
	if (house5)
		scores[house5]++

	var/winning_house = pick("Mustardweasel","Mintysnek","Rubywyrm", "Slatepie")
	var/max_score = -1
	for (var/house in scores)
		if (scores[house] > max_score)
			max_score = scores[house]
			winning_house = house

	add_to_house(C.ckey, winning_house)
	var/color = "#FFFFFF"
	switch(winning_house)
		if("Rubywyrm")
			color = "#CF0000"
		if("Mintysnek")
			color = "#00CF00"
		if("Slatepie")
			color = "#0000CF"
		if("Mustardweasel")
			color = "#FFD700"
	to_chat(C, "<font size=4>You have been sorted into <b><span style='color:[color];'>[winning_house]</span></b>!</font>")
	return TRUE