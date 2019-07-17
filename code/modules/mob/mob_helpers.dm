/mob/proc/update_client_colour(var/time = 10) //Update the mob's client.color with an animation the specified time in length.
	if(!client) //No client_colour without client. If the player logs back in they'll be back through here anyway.
		return
	client.colour_transition(get_screen_colour(), time = time) //Get the colour matrix we're going to transition to depending on relevance (magic glasses first, eyes second).

/mob/proc/get_screen_colour()

/mob/living/get_screen_colour() //Fetch the colour matrix from wherever (e.g. eyes) so it can be compared to client.color.
	var/list/colour_matrix = null
	if(global_colour_matrix)
		colour_matrix = global_colour_matrix
	else
		var/newcolor1 = (1 - (health/maxHealth)) * 0.33
		if(0.33 < newcolor1 || 0 > newcolor1)
			newcolor1 = 0.33
		var/newcolor2 = 1 - (2* newcolor1)
		colour_matrix = list(newcolor2, newcolor1, newcolor1,\
							newcolor1, newcolor2, newcolor1,\
							newcolor1, newcolor1, newcolor2)
	return colour_matrix

/client/proc/colour_transition(var/list/colour_to = null, var/time = 10) //Call this with no parameters to reset to default.
	animate(src, color=colour_to, time=time, easing=SINE_EASING)

/proc/issmall(A)
	if (A && istype(A, /mob/living))
		var/mob/living/L = A
		return L.mob_size <= MOB_SMALL
	return FALSE


proc/isdeaf(A)
	if (isliving(A))
		var/mob/living/M = A
		return (M.sdisabilities & DEAF) || M.ear_deaf
	return FALSE

proc/hasorgans(A) // Fucking really??
	return ishuman(A)

proc/iscuffed(A)
	if (istype(A, /mob/living/carbon))
		var/mob/living/carbon/C = A
		if (C.handcuffed)
			return TRUE
	return FALSE
/

/proc/is_admin(var/mob/user)
	return check_rights(R_ADMIN, FALSE, user) != FALSE


/proc/hsl2rgb(h, s, l)
	return //TODO: Implement

//Used to weight organs when an organ is hit randomly (i.e. not a directed, aimed attack).
//Also used to weight the protection value that armor provides for covering that body part when calculating protection from full-body effects.
var/list/global/organ_rel_size = list(
	"head" = 25,
	"chest" = 70,
	"groin" = 30,
	"l_leg" = 25,
	"r_leg" = 25,
	"l_arm" = 25,
	"r_arm" = 25,
	"l_hand" = 10,
	"r_hand" = 10,
	"l_foot" = 10,
	"r_foot" = 10,
)

/proc/check_zone(zone)
	if (!zone)	return "chest"
	switch(zone)
		if ("eyes")
			zone = "head"
		if ("mouth")
			zone = "head"
	return zone

// Returns zone with a certain probability. If the probability fails, or no zone is specified, then a random body part is chosen.
// Do not use this if someone is intentionally trying to hit a specific body part.
// Use get_zone_with_miss_chance() for that.
/proc/ran_zone(zone, probability)
	if (zone)
		zone = check_zone(zone)
		if (prob(probability))
			return zone

	var/ran_zone = zone
	while (ran_zone == zone)
		ran_zone = pick (
			organ_rel_size["head"]; "head",
			organ_rel_size["chest"]; "chest",
			organ_rel_size["groin"]; "groin",
			organ_rel_size["l_arm"]; "l_arm",
			organ_rel_size["r_arm"]; "r_arm",
			organ_rel_size["l_leg"]; "l_leg",
			organ_rel_size["r_leg"]; "r_leg",
			organ_rel_size["l_hand"]; "l_hand",
			organ_rel_size["r_hand"]; "r_hand",
			organ_rel_size["l_foot"]; "l_foot",
			organ_rel_size["r_foot"]; "r_foot",
		)

	return ran_zone

// Emulates targetting a specific body part, and miss chances
// May return null if missed
// miss_chance_mod may be negative.

/proc/get_zone_with_miss_chance(zone, var/mob/target, var/miss_chance = 0, var/ranged_attack=0)

	zone = check_zone(zone)

	if (!ranged_attack)
		// you cannot miss if your target is prone or restrained
		if (target.buckled || target.lying)
			return zone
		// if your target is being grabbed aggressively by someone you cannot miss either
		for (var/obj/item/weapon/grab/G in target.grabbed_by)
			if (G.state >= GRAB_AGGRESSIVE)
				return zone

	if (prob(miss_chance))
		return null

	return zone


/proc/stars(n, pr)
	if (pr == null)
		pr = 25
	if (pr <= 0)
		return null
	else
		if (pr >= 100)
			return n
	var/te = n
	var/t = ""
	n = length(n)
	var/p = null
	p = TRUE
	var/intag = FALSE
	while (p <= n)
		var/char = copytext(te, p, p + 1)
		if (char == "<") //let's try to not break tags
			intag = !intag
		if (intag || char == " " || prob(pr))
			t = text("[][]", t, char)
		else
			t = text("[]*", t)
		if (char == ">")
			intag = !intag
		p++
	return t

proc/slur(phrase)
	phrase = rhtml_decode(phrase)
	var/leng=lentext(phrase)
	var/counter=lentext(phrase)
	var/newphrase=""
	var/newletter=""
	while (counter>=1)
		newletter=copytext(phrase,(leng-counter)+1,(leng-counter)+2)
		if (rand(1,3)==3)
			if (lowertext(newletter)=="o")	newletter="u"
			if (lowertext(newletter)=="s")	newletter="ch"
			if (lowertext(newletter)=="a")	newletter="ah"
			if (lowertext(newletter)=="c")	newletter="k"
		switch(rand(1,15))
			if (1,3,5,8)	newletter="[lowertext(newletter)]"
			if (2,4,6,15)	newletter="[uppertext(newletter)]"
			if (7)	newletter+="'"
			//if (9,10)	newletter="<b>[newletter]</b>"
			//if (11,12)	newletter="<big>[newletter]</big>"
			//if (13)	newletter="<small>[newletter]</small>"
		newphrase+="[newletter]";counter-=1
	return rhtml_encode(newphrase)

/proc/stutter(n)
	var/te = rhtml_decode(n)
	var/t = ""//placed before the message. Not really sure what it's for.
	n = length(n)//length of the entire word
	var/p = null
	p = TRUE//1 is the start of any word
	while (p <= n)//while P, which starts at TRUE is less or equal to N which is the length.
		var/n_letter = copytext(te, p, p + 1)//copies text from a certain distance. In this case, only one letter at a time.
		if (prob(80) && (ckey(n_letter) in list("b","c","d","f","g","h","j","k","l","m","n","p","q","r","s","t","v","w","x","y","z")))
			if (prob(10))
				n_letter = text("[n_letter]-[n_letter]-[n_letter]-[n_letter]")//replaces the current letter with this instead.
			else
				if (prob(20))
					n_letter = text("[n_letter]-[n_letter]-[n_letter]")
				else
					if (prob(5))
						n_letter = null
					else
						n_letter = text("[n_letter]-[n_letter]")
		t = text("[t][n_letter]")//since the above is ran through for each letter, the text just adds up back to the original word.
		p++//for each letter p is increased to find where the next letter will be.
	return sanitize(t)

/proc/lisp(message, intensity=100) //Intensity = how hard will the dude be lisped
	message = prob(intensity) ? replacetext(message, "f", "ph") : message
	message = prob(intensity) ? replacetext(message, "t", "ph") : message
	message = prob(intensity) ? replacetext(message, "s", "sh") : message
	message = prob(intensity) ? replacetext(message, "th", "hh") : message
	message = prob(intensity) ? replacetext(message, "ck", "gh") : message
	message = prob(intensity) ? replacetext(message, "c", "gh") : message
	message = prob(intensity) ? replacetext(message, "k", "gh") : message
	return message

proc/Gibberish(t, p)//t is the inputted message, and any value higher than 70 for p will cause letters to be replaced instead of added
	/* Turn text into complete gibberish! */
	var/returntext = ""
	for (var/i = TRUE, i <= length(t), i++)

		var/letter = copytext(t, i, i+1)
		if (prob(50))
			if (p >= 70)
				letter = ""

			for (var/j = TRUE, j <= rand(0, 2), j++)
				letter += pick("#","@","*","&","%","$","/", "<", ">", ";","*","*","*","*","*","*","*")

		returntext += letter

	return returntext


/proc/ninjaspeak(n)
/*
The difference with stutter is that this proc can stutter more than TRUE letter
The issue here is that anything that does not have a space is treated as one word (in many instances). For instance, "LOOKING," is a word, including the comma.
It's fairly easy to fix if dealing with single letters but not so much with compounds of letters./N
*/
	var/te = rhtml_decode(n)
	var/t = ""
	n = length(n)
	var/p = TRUE
	while (p <= n)
		var/n_letter
		var/n_mod = rand(1,4)
		if (p+n_mod>n+1)
			n_letter = copytext(te, p, n+1)
		else
			n_letter = copytext(te, p, p+n_mod)
		if (prob(50))
			if (prob(30))
				n_letter = text("[n_letter]-[n_letter]-[n_letter]")
			else
				n_letter = text("[n_letter]-[n_letter]")
		else
			n_letter = text("[n_letter]")
		t = text("[t][n_letter]")
		p=p+n_mod
	return sanitize(t)


/proc/shake_camera(mob/M, duration, strength=1)
	if (!M || !M.client || M.shakecamera || M.stat || isEye(M))
		return
	M.shakecamera = TRUE
	spawn(1)
		if (isnull(M))
			return

		if (!M.client)
			return

		var/atom/oldeye=M.client.eye

		var/x
		if (M)
			for (x=0; x<duration, x++)
				if (M.client)
					if (M.client.eye)
						M.client.eye = locate(dd_range(1,M.loc.x+rand(-strength,strength),world.maxx),dd_range(1,M.loc.y+rand(-strength,strength),world.maxy),M.loc.z)
						sleep(1)
			if (M.client)
				if (M.client.eye)
					M.client.eye=oldeye
			if (M)
				M.shakecamera = FALSE


/proc/findname(msg)
	for (var/mob/M in mob_list)
		if (M.real_name == text("[msg]"))
			return TRUE
	return FALSE


/mob/proc/abiotic(var/full_body = FALSE)
	if (full_body && ((l_hand && !( l_hand.abstract )) || (r_hand && !( r_hand.abstract )) || (back || wear_mask)))
		return TRUE

	if ((l_hand && !( l_hand.abstract )) || (r_hand && !( r_hand.abstract )))
		return TRUE

	return FALSE

//converts intent-strings into numbers and back
var/list/intents = list(I_HELP,I_DISARM,I_GRAB,I_HURT)
/proc/intent_numeric(argument)
	if (istext(argument))
		switch(argument)
			if (I_HELP)		return FALSE
			if (I_DISARM)	return TRUE
			if (I_GRAB)		return 2
			else			return 3
	else
		switch(argument)
			if (0)			return I_HELP
			if (1)			return I_DISARM
			if (2)			return I_GRAB
			else			return I_HURT


proc/is_blind(A)
	if (istype(A, /mob/living/carbon))
		var/mob/living/carbon/C = A
		if (C.sdisabilities & BLIND || C.blinded)
			return TRUE
		if (istype(C.wear_mask, /obj/item/clothing/glasses/sunglasses/blindfold))
			return TRUE
	return FALSE

/proc/mobs_in_area(var/area/A)
	var/list/mobs = new
	for (var/mob/living/M in mob_list)
		if (get_area(M) == A)
			mobs += M
	return mobs

//Direct dead say used both by emote and say
//It is somewhat messy. I don't know what to do.
//I know you can't see the change, but I rewrote the name code. It is significantly less messy now
/proc/say_dead_direct(var/message, var/mob/subject = null)
	var/name
	var/keyname
	if (subject && subject.client)
		var/client/C = subject.client
		keyname = (C.holder && C.holder.fakekey) ? C.holder.fakekey : C.key
		if (C.mob) //Most of the time this is the dead/observer mob; we can totally use him if there is no better name

		//	name = realname
			name = C.mob.real_name


	for (var/mob/M in player_list)
		if (M.client && ((!istype(M, /mob/new_player) && M.stat == DEAD) || (M.client.holder && !is_mentor(M.client))) && M.is_preference_enabled(/datum/client_preference/show_dsay))
			var/follow
			var/lname
			if (subject)
				if (subject != M)
					follow = "([ghost_follow_link(subject, M)]) "
				if (M.stat != DEAD && M.client.holder)
					follow = "([admin_jump_link(subject, M.client.holder)]) "
				var/mob/observer/ghost/DM
				if (isghost(subject))
					DM = subject
				if (M.client.holder) 							// What admins see
					lname = "[keyname][(DM && DM.anonsay) ? "*" : (DM ? "" : "^")] ([name])"
				else
					if (DM && DM.anonsay)						// If the person is actually observer they have the option to be anonymous
						lname = "Ghost of [name]"
					else if (DM)									// Non-anons
						lname = "[keyname] ([name])"
					else										// Everyone else (dead people who didn't ghost yet, etc.)
						lname = name
				lname = "<span class='name'>[lname]</span> "
			M << "<span class='deadsay'>" + create_text_tag("dead", "DEAD:", M.client) + " [lname][follow][message]</span>"

//Announces that a ghost has joined/left, mainly for use with wizards
/proc/announce_ghost_joinleave(O, var/joined_ghosts = TRUE, var/message = "")
	var/client/C
	//Accept any type, sort what we want here
	if (istype(O, /mob))
		var/mob/M = O
		if (M.client)
			C = M.client
	else if (istype(O, /client))
		C = O
	else if (istype(O, /datum/mind))
		var/datum/mind/M = O
		if (M.current && M.current.client)
			C = M.current.client
		else if (M.original && M.original.client)
			C = M.original.client

	if (C)
		var/name
		if (C.mob)
			var/mob/M = C.mob
			if (M.mind && M.mind.name)
				name = M.mind.name
			if (M.real_name && M.real_name != name)
				if (name)
					name += " ([M.real_name])"
				else
					name = M.real_name
		if (!name)
			name = (C.holder && C.holder.fakekey) ? C.holder.fakekey : C.key
		if (joined_ghosts)
			say_dead_direct("The ghost of <span class='name'>[name]</span> now [pick("skulks","lurks","prowls","creeps","stalks")] among the dead. [message]")
		else
			say_dead_direct("<span class='name'>[name]</span> no longer [pick("skulks","lurks","prowls","creeps","stalks")] in the realm of the dead. [message]")

// Returns true if the mob has a client which has been active in the last given X minutes.
/mob/proc/is_client_active(var/active = TRUE)
	return client && client.inactivity < active MINUTES

/mob/proc/can_eat()
	return TRUE

/mob/proc/can_force_feed()
	return TRUE

#define SAFE_PERP -50
/mob/living/proc/assess_perp(var/obj/access_obj, var/check_access, var/auth_weapons, var/check_records, var/check_arrest)
	if (stat == DEAD)
		return SAFE_PERP

	return FALSE

/mob/living/carbon/assess_perp(var/obj/access_obj, var/check_access, var/auth_weapons, var/check_records, var/check_arrest)
	if (handcuffed)
		return SAFE_PERP

	return ..()

/mob/living/carbon/human/assess_perp(var/obj/access_obj, var/check_access, var/auth_weapons, var/check_records, var/check_arrest)
	var/threatcount = ..()
	if (. == SAFE_PERP)
		return SAFE_PERP
/*
	//Agent cards lower threatlevel.
	var/obj/item/weapon/card/id/id = GetIdCard()

/*	if (id && istype(id, /obj/item/weapon/card/id/syndicate))
		threatcount -= 2*/
	// A proper	CentCom id is hard currency.
	else if (id && istype(id, /obj/item/weapon/card/id/centcom))
		return SAFE_PERP
*/
/*
	if (check_access && !access_obj.allowed(src))
		threatcount += 4
*/
/*
	if (auth_weapons && !access_obj.allowed(src))
		if (istype(l_hand, /obj/item/weapon/gun) || istype(l_hand, /obj/item/weapon/melee))
			threatcount += 4

		if (istype(r_hand, /obj/item/weapon/gun) || istype(r_hand, /obj/item/weapon/melee))
			threatcount += 4

		if (istype(belt, /obj/item/weapon/gun) || istype(belt, /obj/item/weapon/melee))
			threatcount += 2

		if (species.name != "Human")
			threatcount += 2*/
/*
	if (check_records || check_arrest)
		var/perpname = name
		if (id)
			perpname = id.registered_name

		var/datum/data/record/R = find_security_record("name", perpname)
		if (check_records && !R)
			threatcount += 4

		if (check_arrest && R && (R.fields["criminal"] == "*Arrest*"))
			threatcount += 4
*/
	return threatcount

/mob/living/simple_animal/hostile/assess_perp(var/obj/access_obj, var/check_access, var/auth_weapons, var/check_records, var/check_arrest)
	var/threatcount = ..()
	if (. == SAFE_PERP)
		return SAFE_PERP

	return threatcount

#undef SAFE_PERP
/*
/mob/proc/get_multitool(var/obj/item/multitool/P)
	if (istype(P))
		return P

/mob/observer/ghost/get_multitool()
	return can_admin_interact() && ..(ghost_multitool)

/mob/living/carbon/human/get_multitool()
	return ..(get_active_hand())*/