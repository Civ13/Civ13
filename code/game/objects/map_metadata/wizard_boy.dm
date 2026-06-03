
/obj/map_metadata/wizard_boy
	ID = MAP_WIZARD_BOY
	title = "Wizard Boy"
	description = "Welcome to Llanboarwart Academy of Magical Education!"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	lobby_icon = "icons/lobby/wizard_boy.png"
	faction_organization = list(CIVILIAN)

	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/british)
	age = "2013"

	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "Llanboarwart Academy of Magical Education"
	mission_start_message = "<font size=6 class='wizard'>Welcome to <b>L.A.M.E.</b>, the <span style='color:grey'>Llanboarwart Academy of Magical Education</span>! Get sorted into a house and duel your fellow wizards!</font>"
	ambience = list("sound/ambience/desert.ogg")
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	songs = list(
		"Magistar by Kevin MacLeod:1" = "sound/music/magistar.ogg",)
	gamemode = "Wizarding Shenanigans"
	ordinal_age = 8
	default_research = 230
	research_active = FALSE
	gamemode_vote = FALSE
	var/list/list/house_info = list()
	var/list/list/house_points = list(
		"Mustardweasel" = 0,
		"Mintysnek" = 0,
		"Slatepie" = 0,
		"Rubywyrm" = 0,
	)
	New()
		..()
		spawn(30)
			load_houses()

	update_win_condition()
		return

/obj/map_metadata/wizard_boy/proc/load_houses()
	if (fexists("SQL/houses.txt"))
		house_info = list()
		//load a txt file from config/houses.txt, format is ckey;housename;level
		var/list/houses = file2list("SQL/houses.txt")
		for(var/i = 1, i <= length(houses), i++)
			var/list/parts = splittext(houses[i], ";")
			if(length(parts) != 3)
				continue
			var/ckey = parts[1]
			var/housename = parts[2]
			var/levels = parts[3]
			house_info[ckey] = list(housename,levels)

/obj/map_metadata/wizard_boy/proc/save_houses()
	if (fexists("SQL/houses.txt"))
		if (fexists("SQL/houses_backup.txt"))
			fdel("SQL/houses_backup.txt")
		fcopy("SQL/houses.txt", "SQL/houses_backup.txt")
		fdel("SQL/houses.txt")

	for (var/ckey in house_info)
		var/list/data = house_info[ckey]
		if (islist(data) && data.len >= 2)
			text2file("[ckey];[data[1]];[data[2]]", "SQL/houses.txt")

/obj/map_metadata/wizard_boy/proc/change_level(ckey, new_level = "1")
	if(!house_info[ckey])
		load_houses()
		if(!house_info[ckey])
			return FALSE
	if (islist(house_info[ckey]) && house_info[ckey].len >= 2)
		house_info[ckey][2] = new_level
		save_houses()
		for (var/mob/living/human/H in player_list)
			if (H.client && H.client.ckey == ckey)
				H.nationality = new_level
				switch(new_level)
					if("R") // loser
						if(H.wear_id) qdel(H.wear_id)
						if(H.wear_suit) qdel(H.wear_suit)
						if(H.head) qdel(H.head)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/loser(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/pinkrobe(H), slot_wear_suit)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/dunce_cap(H), slot_head)
						H.setStat("magic", 10)
						H.refresh_spells()
					if("0") // idiot
						if(H.wear_id) qdel(H.wear_id)
						if(H.wear_suit) qdel(H.wear_suit)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/idiot(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/wizard/greyrobe(H), slot_wear_suit)
						H.setStat("magic", 0)
						H.refresh_spells()
					if("1") // unga
						if(H.wear_id) qdel(H.wear_id)
						if(H.head) qdel(H.head)
						if(H.eyes) qdel(H.eyes)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/unga(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
						H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
						H.setStat("magic", 10)
						H.refresh_spells()
					if("2") // coal
						if(H.wear_id) qdel(H.wear_id)
						if(H.head) qdel(H.head)
						if(H.eyes) qdel(H.eyes)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/coal(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
						H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
						H.setStat("magic", 20)
						H.refresh_spells()
					if("3") // slate
						if(H.wear_id) qdel(H.wear_id)
						if(H.head) qdel(H.head)
						if(H.eyes) qdel(H.eyes)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/slate(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
						H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular/circle(H), slot_eyes)
						H.setStat("magic", 40)
						H.refresh_spells()
					if("4") // based
						if(H.wear_id) qdel(H.wear_id)
						if(H.head) qdel(H.head)
						if(H.eyes) qdel(H.eyes)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/based(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
						H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
						H.setStat("magic", 70)
						H.refresh_spells()
					if("5") // chad
						if(H.wear_id) qdel(H.wear_id)
						if(H.head) qdel(H.head)
						if(H.eyes) qdel(H.eyes)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id/chad(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
						H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
						H.setStat("magic", 100)
						H.refresh_spells()
					if("T") // teacher/professor
						if(H.wear_id) qdel(H.wear_id)
						if(H.head) qdel(H.head)
						H.equip_to_slot_or_del(new /obj/item/weapon/magic_id(H), slot_wear_id)
						H.equip_to_slot_or_del(new /obj/item/clothing/head/wizard(H), slot_head)
						H.setStat("magic", 100)
						H.refresh_spells()
		return TRUE
	return FALSE

/mob/living/human/proc/refresh_spells()
	hud_used.remove_wizard_hud(src)
	hud_used.add_wizard_hud(src)

/obj/map_metadata/wizard_boy/proc/check_house(ckey)
	if(!house_info[ckey])
		load_houses()
		if(!house_info[ckey])
			return "Unknown"
	if (islist(house_info[ckey]) && house_info[ckey].len >= 1)
		return house_info[ckey][1]
	return "Unknown"

/obj/map_metadata/wizard_boy/proc/check_level(ckey)
	if(!house_info[ckey])
		load_houses()
		if(!house_info[ckey])
			return "1" //return U.N.G.A. level by default
	if (islist(house_info[ckey]) && house_info[ckey].len >= 2)
		return house_info[ckey][2]
	return "1" //return U.N.G.A. level by default

/obj/map_metadata/wizard_boy/proc/remove_from_house(ckey)
	if(!house_info[ckey])
		load_houses()
		if(!house_info[ckey])
			return FALSE
	house_info.Remove(ckey)
	save_houses()
	return TRUE

/obj/map_metadata/wizard_boy/proc/change_house(ckey, new_house)
	if(!house_info[ckey])
		load_houses()
		if(!house_info[ckey])
			return FALSE
	if (islist(house_info[ckey]) && house_info[ckey].len >= 2)
		house_info[ckey][1] = new_house
		save_houses()
		return TRUE
	return FALSE

/obj/map_metadata/wizard_boy/proc/level_to_text(level)
	switch(level)
		if ("0")
			return "I.D.I.O.T."
		if("1")
			return "U.N.G.A."
		if("2")
			return "C.O.A.L."
		if("3")
			return "G.E.M."
		if("4")
			return "B.A.S.E.D."
		if("5")
			return "C.H.A.D."
		if ("R")
			return "L.O.S.E.R."
		if ("T")
			return "Professor of Magical Arts"
	return "Unknown"

/obj/map_metadata/wizard_boy/proc/level_to_formatted_text(level)
	switch(level)
		if ("0")
			return "<b>I.D.I.O.T. - <span style='color:#b1b1b1'><i>Inept & Deficient Individual's Ordinary Test</i></span> (qualification level 0)"
		if ("1")
			return "<b>U.N.G.A. - <span style='color:#818181'><i>Underperforming Numpty General Assessment</i></span> (qualification level 1)"
		if ("2")
			return "<b>C.O.A.L. - <span style='color:#5c5c5c'><i>Community Ordinary Amateur License</i></span> (qualification level 2)"
		if ("3")
			return "<b>G.E.M. - <span style='color:#ff966c'><i>Gravity & Elemental Manipulation</i></span> (qualification level 3)"
		if ("4")
			return "<b>B.A.S.E.D. - <span style='color: #5c5c5c'><i>Boarwart Advanced Sorcery & Experimental Deeds</i></span> (qualification level 4)"
		if ("5")
			return "<b>C.H.A.D. - <span style='color:#EFBF04'><i>Classified High-level Arcane Destruction</i></span> (qualification level 5)"
		if ("R")
			return "<b>L.O.S.E.R.</b> - <span style='color:#FF8DA1'><i>Llanboarwart Outcast & Sub-standard Educational Reject</i></span>"
		if ("T")
			return "<b><i>Professor of Magical Arts</i></b>"
	return "Unknown"

/obj/map_metadata/wizard_boy/proc/add_to_house(ckey, house)
	if (house_info[ckey])
		return FALSE
	//sanitise first
	if (house == "Rubywyrm" || house == "Mintysnek" || house == "Slatepie" || house == "Mustardweasel")
		var/txtexport = "[ckey];[house];1"

		//save to houses.txt
		if (fexists("SQL/houses.txt"))
			text2file(txtexport, "SQL/houses.txt")
		else
			var/F = file("SQL/houses.txt")
			text2file(txtexport, F)
		house_info[ckey] = list(house, "1")
		return TRUE
	return FALSE
var/wizard_style = {"
<style>
	@font-face {
		font-family: 'Civ13Custom';
		src: url('Alegreya-Regular.ttf') format('truetype');
		font-weight: normal;
		font-style: normal;
	}
	@font-face {
		font-family: 'Civ13Custom';
		src: url('Alegreya-Bold.ttf') format('truetype');
		font-weight: bold;
		font-style: normal;
	}
	@font-face {
		font-family: 'Civ13Custom';
		src: url('Alegreya-Italic.ttf') format('truetype');
		font-weight: normal;
		font-style: italic;
	}
	@font-face {
		font-family: 'MagicSchoolOne';
		src: url('MagicSchoolOne.ttf') format('truetype');
		font-weight: normal;
		font-style: normal;
	}
	body {
		background-color: #392611;
		color: #e1e1d7;
		font-family: "Civ13Custom", "Book Antiqua", "Bookman Old Style", serif;
		font-size: 14px;
		padding: 20px;
		margin: 0;
		text-align: center;
	}
	.container {
		max-width: 600px;
		margin: 40px auto;
		background: #271a0c;
		border: 2px solid #a68b7d;
		border-radius: 12px;
		padding: 30px;
		box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.5);
	}
	h1, h2 {
		color: #E1E1FF;
		font-family: "Civ13Custom", "Book Antiqua", serif;
		font-weight: bold;
		margin-top: 0;
	}
	.wizard {
		font-family: "MagicSchoolOne", "Civ13Custom", serif;
	}
	.btn {
		display: block;
		width: 100%;
		padding: 14px;
		margin: 12px 0;
		background: #392611;
		border: 1px solid #a68b7d;
		border-radius: 8px;
		color: #e1e1d7;
		text-decoration: none;
		font-size: 15px;
		transition: all 0.2s ease-in-out;
		cursor: pointer;
		text-align: left;
		box-sizing: border-box;
	}
	.btn:hover {
		background: #a68b7d;
		color: #271a0c;
	}
	.btn-start {
		text-align: center;
		background: #5a6d8d;
		border-color: #E1E1FF;
	}
	.btn-start:hover {
		background: #E1E1FF;
		color: #271a0c;
	}
	.progress {
		font-size: 12px;
		color: #a68b7d;
		margin-bottom: 20px;
		text-transform: uppercase;
		letter-spacing: 1px;
	}
</style>
"}

/datum/wizard_sorting
	var/client/owner
	var/done = FALSE
	var/result = null
	var/stage = 0
	var/list/scores = list("Rubywyrm" = 0, "Slatepie" = 0, "Mintysnek" = 0, "Mustardweasel" = 0)
	var/list/questions
	var/list/current_question_keys

	New(client/C)
		..()
		owner = C
		questions = list(
			list(
				"q" = "Question 1: You find a locked wooden door blocking your path. How do you bypass it?",
				"choices" = list(
					"Cast Explodus! directly at the hinges. Who cares if the wall collapses?" = "Rubywyrm",
					"Examine the wood grain, find the keyhole, and use Pullus! to slide the key under the door from the inside." = "Slatepie",
					"Lie to a first-year student and convince them that picking the lock is part of their exam." = "Mintysnek",
					"Knock politely. If that fails, sit down and wait outside with a thermos of tea." = "Mustardweasel"
				)
			),
			list(
				"q" = "Question 2: Franco Badfaith challenges you to a midnight Mop Ball duel. What is your strategy?",
				"choices" = list(
					"Show up with a modified O-Cedar Master-Sweep and immediately challenge him to a fistfight instead." = "Rubywyrm",
					"Study his previous flight patterns and calculate the exact angle to deflect his next spell." = "Slatepie",
					"Sneak into the stables and grease his mop-handle with lard before the match starts." = "Mintysnek",
					"Offer him a Choco-Toad and ask if he wants to just play cards in the common room." = "Mustardweasel"
				)
			),
			list(
				"q" = "Question 3: It is a rainy Tuesday in the Welsh valleys (again). What are you doing?",
				"choices" = list(
					"Running bare-chested through the mud to build \"character\" and immunity to frostbite." = "Rubywyrm",
					"Sitting in the draftiest corner of the library, quietly sighing and reading about ancient runes." = "Slatepie",
					"Selling watered-down Taffia rum behind the greenhouse to the older students." = "Mintysnek",
					"Helping Hagrag clean out the giant badger cages because they looked lonely." = "Mustardweasel"
				)
			),
			list(
				"q" = "Question 4: Choose your ideal magical companion:",
				"choices" = list(
					"A miniature red dragon that accidentally sets your homework on fire." = "Rubywyrm",
					"A cynical magpie that steals shiny objects and corrects people's spelling." = "Slatepie",
					"A venomous garden lizard that you keep hidden in your sock." = "Mintysnek",
					"A very long, chaotic ferret that sleeps in your sleeve and steals everyone's pens." = "Mustardweasel"
				)
			),
			list(
				"q" = "Question 5: What is the true meaning of magic?",
				"choices" = list(
					"Blowing things up in a spectacular fashion to show off." = "Rubywyrm",
					"The systematic study of universal laws, logic, and ancient lore." = "Slatepie",
					"A tool to get rich, skip chores, and outsmart the people in charge." = "Mintysnek",
					"Making cool glowing lights and helping your friends survive." = "Mustardweasel"
				)
			)
		)
		show_window()

	proc/show_window()
		if (!owner)
			done = TRUE
			return

		var/html = {"
<html>
<head>
<title>The Placing Fedora</title>
[wizard_style]
</head>
<body>
<div class="container">
"}

		if (stage == 0)
			html += {"
	<h1 class='wizard'>The Placing Fedora</h1>
	<p style='font-size: 16px; line-height: 1.5; margin-bottom: 30px;'>Hold your horses, lad. You have not been sorted into a house yet! How would you like to proceed?</p>
	<a class="btn btn-start" href="?src=\ref[src];action=start">I'll take the 5 question sorting test!</a>
	<a class="btn" style="text-align: center;" href="?src=\ref[src];action=random">Just randomly assign me</a>
"}
		else if (stage >= 1 && stage <= 5)
			var/list/qdata = questions[stage]
			var/q_text = qdata["q"]
			if (!current_question_keys)
				var/list/choices_assoc = qdata["choices"]
				var/list/q_keys = list()
				for (var/key in choices_assoc)
					q_keys += key
				current_question_keys = shuffle(q_keys)

			html += {"
	<div class="progress">Question [stage] of 5</div>
	<h2>[q_text]</h2>
"}
			for (var/i = 1, i <= current_question_keys.len, i++)
				var/choice = current_question_keys[i]
				html += "<a class=\"btn\" href=\"?src=\ref[src];action=answer;index=[i]\">[choice]</a>"

		html += {"
</div>
</body>
</html>
"}
		owner << browse(html, "window=wizard_sorting;size=600x800;can_close=0;can_resize=0")

	Topic(href, href_list[])
		if (usr.client != owner)
			return

		var/action = href_list["action"]
		if (action == "start")
			stage = 1
			current_question_keys = null
			show_window()
		else if (action == "random")
			result = pick("Mustardweasel", "Mintysnek", "Rubywyrm", "Slatepie")
			done = TRUE
			owner << browse(null, "window=wizard_sorting")
		else if (action == "answer")
			var/idx = text2num(href_list["index"])
			if (current_question_keys && idx >= 1 && idx <= current_question_keys.len)
				var/selected_choice = current_question_keys[idx]
				var/list/qdata = questions[stage]
				var/list/choices_assoc = qdata["choices"]
				var/house = choices_assoc[selected_choice]
				if (house)
					scores[house]++
				stage++
				current_question_keys = null
				if (stage > 5)
					var/winning_house = pick("Mustardweasel", "Mintysnek", "Rubywyrm", "Slatepie")
					var/max_score = -1
					for (var/h in scores)
						if (scores[h] > max_score)
							max_score = scores[h]
							winning_house = h
					result = winning_house
					done = TRUE
					owner << browse(null, "window=wizard_sorting")
				else
					show_window()

/obj/map_metadata/wizard_boy/proc/house_test(client/C)
	if (!C || !istype(C))
		return FALSE
	if (check_house(C.ckey) != "Unknown")
		return FALSE

	var/datum/wizard_sorting/WS = new(C)
	var/timeout = 600 // 2 minutes max timeout
	while (WS && !WS.done && timeout > 0)
		if (!C)
			break
		timeout--
		sleep(2)

	if (!C || !WS || !WS.result)
		if (WS)
			qdel(WS)
		return FALSE

	var/winning_house = WS.result
	qdel(WS)

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