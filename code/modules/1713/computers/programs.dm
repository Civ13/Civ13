///////////DATUMS////////////////////
/datum/email
	var/subject = "no subject"
	var/sender = "unknown"
	var/receiver = "unknown"
	var/message = ""
	var/date = "0:00"

/datum/email/New(list/properties = null)
	..()
	if (!properties) return

	for (var/propname in vars)
		if (!isnull(properties[propname]))
			vars[propname] = properties[propname]

/datum/program
	var/name = "program"
	var/description = "a basic computer program."
	var/list/compatible_os = list("unga OS 94")
	var/list/tmp_comp_vars = list() //where local vars get stored, as items in the list
	var/mainbody = "---"
	var/mainmenu = "---"

	var/mob/living/human/user //who is using the computer, from origin
	var/obj/structure/computer/origin //where the program is located

/datum/program/proc/reset_tmp_vars()
	tmp_comp_vars = list()

/datum/program/proc/do_html(mob/living/human/user)
	mainbody = "<head>[computer_browser_style]</head>[mainbody]"
	usr << browse(mainbody,"window=[name];border=1;can_close=1;can_resize=0;can_minimize=0;titlebar=1;size=800x600")

/datum/program/Topic(href, href_list, hsrc)
	
	if (!origin)
		return
	
	var/mob/living/human/user = origin.user

	if (!user || user.lying || !ishuman(user))
		return

	user.face_atom(origin)

	if (!locate(user) in range(1,origin))
		user << "<span class = 'danger'>Get next to \the [origin] to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

///////////////////ORION TRAIL GAME//////////////////////////////////
//////////////////////////////////////////////////////////////////////
#define ORION_TRAIL_WINTURN		9

//Orion Trail Events
#define ORION_TRAIL_RAIDERS		"Raiders"
#define ORION_TRAIL_FLUX		"Interstellar Flux"
#define ORION_TRAIL_ILLNESS		"Illness"
#define ORION_TRAIL_BREAKDOWN	"Breakdown"
#define ORION_TRAIL_LING		"Changelings?"
#define ORION_TRAIL_LING_ATTACK "Changeling Ambush"
#define ORION_TRAIL_MALFUNCTION	"Malfunction"
#define ORION_TRAIL_COLLISION	"Collision"
#define ORION_TRAIL_SPACEPORT	"Spaceport"
#define ORION_TRAIL_BLACKHOLE	"BlackHole"
#define ORION_TRAIL_OLDSHIP		"Old Ship"
#define ORION_TRAIL_SEARCH		"Old Ship Search"

#define ORION_STATUS_START		1
#define ORION_STATUS_NORMAL		2
#define ORION_STATUS_GAMEOVER	3
#define ORION_STATUS_MARKET		4

/datum/program/orion_trail
	name = "The Orion Trail"
	description = "Learn how our descendants will get to Orion, and have fun in the process!"
	var/busy = FALSE //prevent clickspam that allowed people to ~speedrun~ the game.
	var/engine = 0
	var/hull = 0
	var/electronics = 0
	var/food = 80
	var/fuel = 60
	var/turns = 4
	var/alive = 4
	var/eventdat = null
	var/event = null
	var/list/settlers = list("Harry","Larry","Bob")
	var/list/events = list(ORION_TRAIL_RAIDERS		= 3,
						   ORION_TRAIL_FLUX			= 1,
						   ORION_TRAIL_ILLNESS		= 3,
						   ORION_TRAIL_BREAKDOWN	= 2,
						   ORION_TRAIL_LING			= 3,
						   ORION_TRAIL_MALFUNCTION	= 2,
						   ORION_TRAIL_COLLISION	= 1,
						   ORION_TRAIL_SPACEPORT	= 2,
						   ORION_TRAIL_OLDSHIP		= 2
						   )
	var/list/stops = list()
	var/list/stopblurbs = list()
	var/lings_aboard = 0
	var/spaceport_raided = 0
	var/spaceport_freebie = 0
	var/last_spaceport_action = ""
	var/gameStatus = ORION_STATUS_START
	var/canContinueEvent = 0

	var/killed_crew = 0

/datum/program/orion_trail/proc/Reset()
	// Sets up the main trail
	stops = list("Pluto","Asteroid Belt","Proxima Centauri","Dead Space","Rigel Prime","Tau Ceti Beta","Black Hole","Space Outpost Beta-9","Orion Prime")
	stopblurbs = list(
		"Pluto, long since occupied with long-range sensors and scanners, stands ready to, and indeed continues to probe the far reaches of the galaxy.",
		"At the edge of the Sol system lies a treacherous asteroid belt. Many have been crushed by stray asteroids and misguided judgement.",
		"The nearest star system to Sol, in ages past it stood as a reminder of the boundaries of sub-light travel, now a low-population sanctuary for adventurers and traders.",
		"This region of space is particularly devoid of matter. Such low-density pockets are known to exist, but the vastness of it is astounding.",
		"Rigel Prime, the center of the Rigel system, burns hot, basking its planetary bodies in warmth and radiation.",
		"Tau Ceti Beta has recently become a waypoint for colonists headed towards Orion. There are many ships and makeshift stations in the vicinity.",
		"Sensors indicate that a black hole's gravitational field is affecting the region of space we were headed through. We could stay of course, but risk of being overcome by its gravity, or we could change course to go around, which will take longer.",
		"You have come into range of the first man-made structure in this region of space. It has been constructed not by travellers from Sol, but by colonists from Orion. It stands as a monument to the colonists' success.",
		"You have made it to Orion! Congratulations! Your crew is one of the few to start a new foothold for mankind!"
		)

/datum/program/orion_trail/proc/newgame()
	// Set names of settlers in crew
	settlers = list()
	for(var/i = 1; i <= 3; i++)
		add_crewmember()
	add_crewmember("[usr]")
	// Re-set items to defaults
	engine = 1
	hull = 1
	electronics = 1
	food = 80
	fuel = 60
	alive = 4
	turns = 1
	event = null
	gameStatus = ORION_STATUS_NORMAL
	lings_aboard = 0
	killed_crew = 0

	//spaceport junk
	spaceport_raided = 0
	spaceport_freebie = 0
	last_spaceport_action = ""

/datum/program/orion_trail/do_html(mob/living/human/user)
	if(fuel <= 0 || food <=0 || settlers.len == 0)
		gameStatus = ORION_STATUS_GAMEOVER
		event = null
	mainbody = ""
	if(gameStatus == ORION_STATUS_GAMEOVER)
		mainbody = "<center><h1>Game Over</h1></center>"
		mainbody += "Like many before you, your crew never made it to Orion, lost to space... <br><b>Forever</b>."
		if(!settlers.len)
			mainbody += "<br>Your entire crew died, and your ship joins the fleet of ghost-ships littering the galaxy."
		else
			if(food <= 0)
				mainbody += "<br>You ran out of food and starved."
			if(fuel <= 0)
				mainbody += "<br>You ran out of fuel, and drift, slowly, into a star."

		mainbody += "<P ALIGN=Right><a href='?src=\ref[src];menu=1'>May They Rest In Peace</a></P>"

	else if(event)
		mainbody = "[eventdat]"
	else if(gameStatus == ORION_STATUS_NORMAL)
		var/title = "title"
		var/subtext = "subtext"
		if (stops.len && stops[turns])
			title = stops[turns]
		if (stopblurbs.len && stopblurbs[turns])
			subtext = stopblurbs[turns]
		mainbody = "<center><h1>[title]</h1></center>"
		mainbody += "[subtext]"
		mainbody += "<h3><b>Crew:</b></h3>"
		mainbody += english_list(settlers)
		mainbody += "<br><b>Food: </b>[food] | <b>Fuel: </b>[fuel]"
		mainbody += "<br><b>Engine Parts: </b>[engine] | <b>Hull Panels: </b>[hull] | <b>Electronics: </b>[electronics]"
		if(turns == 7)
			mainbody += "<P ALIGN=Right><a href='?src=\ref[src];pastblack=1'>Go Around</a> <a href='?src=\ref[src];blackhole=1'>Continue</a></P>"
		else
			mainbody += "<P ALIGN=Right><a href='?src=\ref[src];continue=1'>Continue</a></P>"
		mainbody += "<P ALIGN=Right><a href='?src=\ref[src];killcrew=1'>Kill a Crewmember</a></P>"
		mainbody += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
	else
		mainbody = "<center><h2>The Orion Trail</h2></center>"
		mainbody += "<br><center><h3>Experience the journey of your descendants!</h3></center><br><br>"
		mainbody += "<center><b><a href='?src=\ref[src];newgame=1'>New Game</a></b></center>"
	..()

/datum/program/orion_trail/Topic(href, href_list, hsrc)
	..()
	if(busy)
		return
	busy = TRUE

	var/xp_gained = 0
	if (href_list["continue"]) //Continue your travels
		if(gameStatus == ORION_STATUS_NORMAL && !event && turns != 7)
			if(turns >= ORION_TRAIL_WINTURN)
				win(user)
				xp_gained += 34
			else
				food -= (alive+lings_aboard)*2
				fuel -= 5
				if(turns == 2 && prob(30))
					event = ORION_TRAIL_COLLISION
					event()
				else if(prob(75))
					event = pickweight(events)
					if(lings_aboard)
						if(event == ORION_TRAIL_LING || prob(55))
							event = ORION_TRAIL_LING_ATTACK
					event()
				turns += 1

	else if(href_list["newgame"]) //Reset everything
		if(gameStatus == ORION_STATUS_START)
			Reset()
			newgame()
	else if(href_list["menu"]) //back to the main menu
		if(gameStatus == ORION_STATUS_GAMEOVER)
			gameStatus = ORION_STATUS_START
			event = null
			food = 80
			fuel = 60
			settlers = list("Harry","Larry","Bob")
	else if(href_list["search"]) //search old ship
		if(event == ORION_TRAIL_OLDSHIP)
			event = ORION_TRAIL_SEARCH
			event()
	else if(href_list["slow"]) //slow down
		if(event == ORION_TRAIL_FLUX)
			food -= (alive+lings_aboard)*2
			fuel -= 5
		event = null
	else if(href_list["pastblack"]) //slow down
		if(turns == 7)
			food -= ((alive+lings_aboard)*2)*3
			fuel -= 15
			turns += 1
			event = null
	else if(href_list["useengine"]) //use parts
		if(event == ORION_TRAIL_BREAKDOWN)
			engine = max(0, --engine)
			event = null
	else if(href_list["useelec"]) //use parts
		if(event == ORION_TRAIL_MALFUNCTION)
			electronics = max(0, --electronics)
			event = null
	else if(href_list["usehull"]) //use parts
		if(event == ORION_TRAIL_COLLISION)
			hull = max(0, --hull)
			event = null
	else if(href_list["wait"]) //wait 3 days
		if(event == ORION_TRAIL_BREAKDOWN || event == ORION_TRAIL_MALFUNCTION || event == ORION_TRAIL_COLLISION)
			food -= ((alive+lings_aboard)*2)*3
			event = null
	else if(href_list["keepspeed"]) //keep speed
		if(event == ORION_TRAIL_FLUX)
			if(prob(75))
				event = "Breakdown"
				event()
			else
				event = null
	else if(href_list["blackhole"]) //keep speed past a black hole
		if(turns == 7)
			if(prob(75))
				event = ORION_TRAIL_BLACKHOLE
				event()
			else
				event = null
				turns += 1
	else if(href_list["holedeath"])
		if(event == ORION_TRAIL_BLACKHOLE)
			gameStatus = ORION_STATUS_GAMEOVER
			event = null
	else if(href_list["eventclose"]) //end an event
		if(canContinueEvent)
			event = null

	else if(href_list["killcrew"]) //shoot a crewmember
		if(gameStatus == ORION_STATUS_NORMAL || event == ORION_TRAIL_LING)
			var/sheriff = remove_crewmember() //I shot the sheriff
			killed_crew++

			if(settlers.len == 0 || alive == 0)
				usr << "The last crewmember [sheriff], shot themselves, GAME OVER!"
				gameStatus = ORION_STATUS_GAMEOVER
				event = null

				if(killed_crew >= 4)
					xp_gained -= 15//no cheating by spamming game overs

			if(event == ORION_TRAIL_LING) //only ends the ORION_TRAIL_LING event, since you can do this action in multiple places
				event = null
				killed_crew-- // the kill was valid

	//Spaceport specific interactions
	//they get a header because most of them don't reset event (because it's a shop, you leave when you want to)
	//they also call event() again, to regen the eventdata, which is kind of odd but necessary
	else if(href_list["buycrew"]) //buy a crewmember
		if(gameStatus == ORION_STATUS_MARKET)
			if(!spaceport_raided && food >= 10 && fuel >= 10)
				var/bought = add_crewmember()
				last_spaceport_action = "You hired [bought] as a new crewmember."
				fuel -= 10
				food -= 10
				event()
				killed_crew-- // I mean not really but you know

	else if(href_list["sellcrew"]) //sell a crewmember
		if(gameStatus == ORION_STATUS_MARKET)
			if(!spaceport_raided && settlers.len > 1)
				var/sold = remove_crewmember()
				last_spaceport_action = "You sold your crewmember, [sold]!"
				fuel += 7
				food += 7
				event()

	else if(href_list["leave_spaceport"])
		if(gameStatus == ORION_STATUS_MARKET)
			event = null
			gameStatus = ORION_STATUS_NORMAL
			spaceport_raided = 0
			spaceport_freebie = 0
			last_spaceport_action = ""

	else if(href_list["raid_spaceport"])
		if(gameStatus == ORION_STATUS_MARKET)
			if(!spaceport_raided)
				var/success = min(15 * alive,100) //default crew (4) have a 60% chance
				spaceport_raided = 1

				var/FU = 0
				var/FO = 0
				if(prob(success))
					FU = rand(5,15)
					FO = rand(5,15)
					last_spaceport_action = "You successfully raided the spaceport! You gained [FU] Fuel and [FO] Food! (+[FU]FU,+[FO]FO)"
					xp_gained += 10
				else
					FU = rand(-5,-15)
					FO = rand(-5,-15)
					last_spaceport_action = "You failed to raid the spaceport! You lost [FU*-1] Fuel and [FO*-1] Food in your scramble to escape! ([FU]FU,[FO]FO)"

					//your chance of lose a crewmember is 1/2 your chance of success
					//this makes higher % failures hurt more, don't get cocky space cowboy!
					if(prob(success*5))
						var/lost_crew = remove_crewmember()
						last_spaceport_action = "You failed to raid the spaceport! You lost [FU*-1] Fuel and [FO*-1] Food, AND [lost_crew] in your scramble to escape! ([FU]FI,[FO]FO,-Crew)"


				fuel += FU
				food += FO
				event()

	else if(href_list["buyparts"])
		if(gameStatus == ORION_STATUS_MARKET)
			if(!spaceport_raided && fuel > 5)
				switch(text2num(href_list["buyparts"]))
					if(1) //Engine Parts
						engine++
						last_spaceport_action = "Bought Engine Parts"
					if(2) //Hull Plates
						hull++
						last_spaceport_action = "Bought Hull Plates"
					if(3) //Spare Electronics
						electronics++
						last_spaceport_action = "Bought Spare Electronics"
				fuel -= 5 //they all cost 5
				event()

	else if(href_list["trade"])
		if(gameStatus == ORION_STATUS_MARKET)
			if(!spaceport_raided)
				switch(text2num(href_list["trade"]))
					if(1) //Fuel
						if(fuel > 5)
							fuel -= 5
							food += 5
							last_spaceport_action = "Traded Fuel for Food"
							event()
					if(2) //Food
						if(food > 5)
							fuel += 5
							food -= 5
							last_spaceport_action = "Traded Food for Fuel"
							event()
	busy = FALSE
	sleep(0.5)
	do_html()
/datum/program/orion_trail/proc/event()
	eventdat = "<center><h1>[event]</h1></center>"
	canContinueEvent = 0
	switch(event)
		if(ORION_TRAIL_RAIDERS)
			eventdat += "Raiders have come aboard your ship!"
			if(prob(50))
				var/sfood = rand(1,10)
				var/sfuel = rand(1,10)
				food -= sfood
				fuel -= sfuel
				eventdat += "<br>They have stolen [sfood] <b>Food</b> and [sfuel] <b>Fuel</b>."
			else if(prob(10))
				var/deadname = remove_crewmember()
				eventdat += "<br>[deadname] tried to fight back, but was killed."
			else
				eventdat += "<br>Fortunately, you fended them off without any trouble."
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];eventclose=1'>Continue</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			canContinueEvent = 1

		if(ORION_TRAIL_FLUX)
			eventdat += "This region of space is highly turbulent. <br>If we go slowly we may avoid more damage, but if we keep our speed we won't waste supplies."
			eventdat += "<br>What will you do?"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];slow=1'>Slow Down</a> <a href='?src=\ref[src];keepspeed=1'>Continue</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"

		if(ORION_TRAIL_OLDSHIP)
			eventdat += "<br>Your crew spots an old ship floating through space. It might have some supplies, but then again it looks rather unsafe."
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];search=1'>Search it</a><a href='?src=\ref[src];eventclose=1'>Leave it</a></P><P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			canContinueEvent = 1

		if(ORION_TRAIL_SEARCH)
			switch(rand(100))
				if(0 to 15)
					var/rescued = add_crewmember()
					var/oldfood = rand(1,7)
					var/oldfuel = rand(4,10)
					food += oldfood
					fuel += oldfuel
					eventdat += "<br>As you look through it you find some supplies and a living person!"
					eventdat += "<br>[rescued] was rescued from the abandoned ship!"
					eventdat += "<br>You found [oldfood] <b>Food</b> and [oldfuel] <b>Fuel</b>."
				if(15 to 35)
					var/lfuel = rand(4,7)
					var/deadname = remove_crewmember()
					fuel -= lfuel
					eventdat += "<br>[deadname] was lost deep in the wreckage, and your own vessel lost [lfuel] <b>Fuel</b> maneuvering to the the abandoned ship."
				if(35 to 65)
					var/oldfood = rand(5,11)
					food += oldfood
					engine++
					eventdat += "<br>You found [oldfood] <b>Food</b> and some parts amongst the wreck."
				else
					eventdat += "<br>As you look through the wreck you cannot find much of use."
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];eventclose=1'>Continue</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			canContinueEvent = 1

		if(ORION_TRAIL_ILLNESS)
			eventdat += "A deadly illness has been contracted!"
			var/deadname = remove_crewmember()
			eventdat += "<br>[deadname] was killed by the disease."
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];eventclose=1'>Continue</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			canContinueEvent = 1

		if(ORION_TRAIL_BREAKDOWN)
			eventdat += "Oh no! The engine has broken down!"
			eventdat += "<br>You can repair it with an engine part, or you can make repairs for 3 days."
			if(engine >= 1)
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];useengine=1'>Use Part</a><a href='?src=\ref[src];wait=1'>Wait</a></P>"
			else
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];wait=1'>Wait</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"

		if(ORION_TRAIL_MALFUNCTION)
			eventdat += "The ship's systems are malfunctioning!"
			eventdat += "<br>You can replace the broken electronics with spares, or you can spend 3 days troubleshooting the AI."
			if(electronics >= 1)
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];useelec=1'>Use Part</a><a href='?src=\ref[src];wait=1'>Wait</a></P>"
			else
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];wait=1'>Wait</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"

		if(ORION_TRAIL_COLLISION)
			eventdat += "Something hit us! Looks like there's some hull damage."
			if(prob(25))
				var/sfood = rand(5,15)
				var/sfuel = rand(5,15)
				food -= sfood
				fuel -= sfuel
				eventdat += "<br>[sfood] <b>Food</b> and [sfuel] <b>Fuel</b> was vented out into space."
			if(prob(10))
				var/deadname = remove_crewmember()
				eventdat += "<br>[deadname] was killed by rapid depressurization."
			eventdat += "<br>You can repair the damage with hull plates, or you can spend the next 3 days welding scrap together."
			if(hull >= 1)
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];usehull=1'>Use Part</a><a href='?src=\ref[src];wait=1'>Wait</a></P>"
			else
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];wait=1'>Wait</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"

		if(ORION_TRAIL_BLACKHOLE)
			eventdat += "You were swept away into the black hole."
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];holedeath=1'>Oh...</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			settlers = list()

		if(ORION_TRAIL_LING)
			eventdat += "Strange reports warn of changelings infiltrating crews on trips to Orion..."
			if(settlers.len <= 2)
				eventdat += "<br>Your crew's chance of reaching Orion is so slim the changelings likely avoided your ship..."
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];eventclose=1'>Continue</a></P>"
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
				if(prob(10)) // "likely", I didn't say it was guaranteed!
					lings_aboard = min(++lings_aboard,2)
			else
				if(lings_aboard) //less likely to stack lings
					if(prob(20))
						lings_aboard = min(++lings_aboard,2)
				else if(prob(70))
					lings_aboard = min(++lings_aboard,2)

				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];killcrew=1'>Kill a Crewmember</a></P>"
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];eventclose=1'>Risk it</a></P>"
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			canContinueEvent = 1

		if(ORION_TRAIL_LING_ATTACK)
			if(lings_aboard <= 0) //shouldn't trigger, but hey.
				eventdat += "Haha, fooled you, there are no changelings on board!"
				eventdat += "<br>(You should report this to a coder :S)"
			else
				var/ling1 = remove_crewmember()
				var/ling2 = ""
				if(lings_aboard >= 2)
					ling2 = remove_crewmember()

				eventdat += "Changelings among your crew suddenly burst from hiding and attack!"
				if(ling2)
					eventdat += "<br>[ling1] and [ling2]'s arms twist and contort into grotesque blades!"
				else
					eventdat += "<br>[ling1]'s arm twists and contorts into a grotesque blade!"

				var/chance2attack = alive*20
				if(prob(chance2attack))
					var/chancetokill = 30*lings_aboard-(5*alive) //eg: 30*2-(10) = 50%, 2 lings, 2 crew is 50% chance
					if(prob(chancetokill))
						var/deadguy = remove_crewmember()
						var/murder_text = pick("The changeling[ling2 ? "s" : ""] bring[ling2 ? "" : "s"] down [deadguy] and disembowel[ling2 ? "" : "s"] them in a spray of gore!", \
						"[ling2 ? pick(ling1, ling2) : ling1] corners [deadguy] and impales them through the stomach!", \
						"[ling2 ? pick(ling1, ling2) : ling1] decapitates [deadguy] in a single cleaving arc!")
						eventdat += "<br>[murder_text]"
					else
						eventdat += "<br><br><b>You valiantly fight off the changeling[ling2 ? "s":""]!</b>"
						if(ling2)
							food += 30
							lings_aboard = max(0,lings_aboard-2)
						else
							food += 15
							lings_aboard = max(0,--lings_aboard)
						eventdat += "<br><i>Well, it's perfectly good food...</i>\
						<br>You cut the changeling[ling2 ? "s" : ""] into meat, gaining <b>[ling2 ? "30" : "15"]</b> Food!"
				else
					eventdat += "<br><br>[pick("Sensing unfavorable odds", "After a failed attack", "Suddenly breaking nerve")], \
					the changeling[ling2 ? "s":""] vanish[ling2 ? "" : "es"] into space through the airlocks! You're safe... for now."
					if(ling2)
						lings_aboard = max(0,lings_aboard-2)
					else
						lings_aboard = max(0,--lings_aboard)

			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];eventclose=1'>Continue</a></P>"
			eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			canContinueEvent = 1


		if(ORION_TRAIL_SPACEPORT)
			gameStatus = ORION_STATUS_MARKET
			if(spaceport_raided)
				eventdat += "The spaceport is on high alert! You've been barred from docking by the local authorities after your failed raid."
				if(last_spaceport_action)
					eventdat += "<br><b>Last Spaceport Action:</b> [last_spaceport_action]"
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];leave_spaceport=1'>Depart Spaceport</a></P>"
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];close=1'>Close</a></P>"
			else
				eventdat += "Your jump into the sector yields a spaceport - a lucky find!"
				eventdat += "<br>This spaceport is home to travellers who failed to reach Orion, but managed to find a different home..."
				eventdat += "<br>Trading terms: FU = Fuel, FO = Food"
				if(last_spaceport_action)
					eventdat += "<br><b>Last action:</b> [last_spaceport_action]"
				eventdat += "<h3><b>Crew:</b></h3>"
				eventdat += english_list(settlers)
				eventdat += "<br><b>Food: </b>[food] | <b>Fuel: </b>[fuel]"
				eventdat += "<br><b>Engine Parts: </b>[engine] | <b>Hull Panels: </b>[hull] | <b>Electronics: </b>[electronics]"


				//If your crew is pathetic you can get freebies (provided you haven't already gotten one from this port)
				if(!spaceport_freebie && (fuel < 20 || food < 20))
					spaceport_freebie++
					var/FU = 10
					var/FO = 10
					var/freecrew = 0
					if(prob(30))
						FU = 25
						FO = 25

					if(prob(10))
						add_crewmember()
						freecrew++

					eventdat += "<br>The traders of the spaceport take pity on you, and generously give you some free supplies! (+[FU]FU, +[FO]FO)"
					if(freecrew)
						eventdat += "<br>You also gain a new crewmember!"

					fuel += FU
					food += FO

				//CREW INTERACTIONS
				eventdat += "<P ALIGN=Right>Crew Management:</P>"

				//Buy crew
				if(food >= 10 && fuel >= 10)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];buycrew=1'>Hire a New Crewmember (-10FU, -10FO)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You cannot afford a new crewmember.</P>"

				//Sell crew
				if(settlers.len > 1)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];sellcrew=1'>Sell Crew for Fuel and Food (+7FU, +7FO)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You have no other crew to sell.</P>"

				//BUY/SELL STUFF
				eventdat += "<P ALIGN=Right>Spare Parts:</P>"

				//Engine parts
				if(fuel > 5)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];buyparts=1'>Buy Engine Parts (-5FU)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You cannot afford engine parts.</a>"

				//Hull plates
				if(fuel > 5)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];buyparts=2'>Buy Hull Plates (-5FU)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You cannot afford hull plates.</a>"

				//Electronics
				if(fuel > 5)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];buyparts=3'>Buy Spare Electronics (-5FU)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You cannot afford spare electronics.</a>"

				//Trade
				if(fuel > 5)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];trade=1'>Trade Fuel for Food (-5FU,+5FO)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You don't have 5FU to trade.</P"

				if(food > 5)
					eventdat += "<P ALIGN=Right><a href='?src=\ref[src];trade=2'>Trade Food for Fuel (+5FU,-5FO)</a></P>"
				else
					eventdat += "<P ALIGN=Right>You don't have 5FO to trade.</P"

				//Raid the spaceport
				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];raid_spaceport=1'>!! Raid Spaceport !!</a></P>"

				eventdat += "<P ALIGN=Right><a href='?src=\ref[src];leave_spaceport=1'>Depart Spaceport</a></P>"


//Add Random/Specific crewmember
/datum/program/orion_trail/proc/add_crewmember(var/specific = "")
	var/newcrew = ""
	if(specific)
		newcrew = specific
	else
		if(prob(50))
			newcrew = pick(first_names_male)
		else
			newcrew = pick(first_names_female)
	if(newcrew)
		settlers += newcrew
		alive++
	return newcrew


//Remove Random/Specific crewmember
/datum/program/orion_trail/proc/remove_crewmember(specific = "", dont_remove = "")
	var/list/safe2remove = settlers
	var/removed = ""
	if(dont_remove)
		safe2remove -= dont_remove
	if(specific && specific != dont_remove)
		safe2remove = list(specific)
	else
		removed = pick(safe2remove)

	if(removed)
		if(lings_aboard && prob(40*lings_aboard)) //if there are 2 lings you're twice as likely to get one, obviously
			lings_aboard = max(0,--lings_aboard)
		settlers -= removed
		alive--
	return removed


/datum/program/orion_trail/proc/win(mob/user)
	gameStatus = ORION_STATUS_START

#undef ORION_TRAIL_WINTURN
#undef ORION_TRAIL_RAIDERS
#undef ORION_TRAIL_FLUX
#undef ORION_TRAIL_ILLNESS
#undef ORION_TRAIL_BREAKDOWN
#undef ORION_TRAIL_LING
#undef ORION_TRAIL_LING_ATTACK
#undef ORION_TRAIL_MALFUNCTION
#undef ORION_TRAIL_COLLISION
#undef ORION_TRAIL_SPACEPORT
#undef ORION_TRAIL_BLACKHOLE
#undef ORION_TRAIL_OLDSHIP
#undef ORION_TRAIL_SEARCH

#undef ORION_STATUS_START
#undef ORION_STATUS_NORMAL
#undef ORION_STATUS_GAMEOVER
#undef ORION_STATUS_MARKET

/////////////////////////////////////////////////////////////
/datum/program/monkeysoftmail
	name = "MonkeySoft E-Mail Client"
	description = "Send and Receive emails using the latest MonkeySoft Mail Client!"
	compatible_os = list("unga OS 94","unga OS")
	tmp_comp_vars = list(
		"mail_rec" = "Recipient",
		"mail_snd" = "Sender",
		"mail_subj" = "Subject",
		"mail_msg" = "Message",
	)

/datum/program/monkeysoftmail/reset_tmp_vars()
	tmp_comp_vars = list(
		"mail_rec" = "Recipient",
		"mail_snd" = "Sender",
		"mail_subj" = "Subject",
		"mail_msg" = "Message",
	)

/datum/program/monkeysoftmail/do_html(mob/living/human/user)
	mainbody = "<h2>MONKEYSOFT E-MAIL CLIENT</h2><br>"
	mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<a href='?src=\ref[src];mail=99999'>Inbox</a><hr><br>"
	..()

/datum/program/monkeysoftmail/Topic(href, href_list, hsrc)
	..()
	var/mdomain = "monkeysoft.ug"
	switch(user.civilization)
		if ("Rednikov Industries")
			mdomain = "rednikov.ug"
		if ("Giovanni Blu Stocks")
			mdomain = "blu.ug"

		if ("MacGreene Traders")
			mdomain = "greene.ug"

		if ("Goldstein Solutions")
			mdomain = "goldstein.ug"

	var/uname = "[lowertext(replacetext(user.real_name," ",""))]@[mdomain]"
	var/cname = "mail@[mdomain]"
	if (tmp_comp_vars["mail_snd"]=="Sender")
		tmp_comp_vars["mail_snd"] = uname
	mainbody = "<h2>MONKEYSOFT E-MAIL CLIENT</h2><br>"
	mainbody += "<b>Logged in as <i>[uname]</i></b><br>"
	mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<a href='?src=\ref[src];mail=99999'>Inbox</a><hr><br>"
	if (href_list["mail"])
		mainbody = "<h2>MONKEYSOFT E-MAIL CLIENT</h2><br>"
		mainbody += "<b>Logged in as <i>[uname]</i></b><br>"
		mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<a href='?src=\ref[src];mail=99999'>Inbox</a><hr><br>"
		if (href_list["mail"]=="99999")
			if (islist(map.emails[uname]))
				for(var/i, i <= map.emails[uname].len, i++)
					if (istype(map.emails[uname][i], /datum/email))
						var/datum/email/em =  map.emails[uname][i]
						mainbody += "<a href='?src=\ref[src];mail=[i]'>[em.date] ([em.sender]): <b>[em.subject]</b></a><br>"
			if (islist(map.emails[cname]))
				for(var/i, i <= map.emails[cname].len, i++)
					if (istype(map.emails[cname][i], /datum/email))
						var/datum/email/em =  map.emails[cname][i]
						mainbody += "<a href='?src=\ref[src];mail=c[i]'>[em.date] ([em.sender]): <b>[em.subject]</b></a><br>"

		else
			if (findtext(href_list["mail"],"c"))
				var/tcode = text2num(replacetext(href_list["mail"],"c",""))
				var/datum/email/chosen = map.emails[cname][tcode]
				mainbody += "---<br>From: <i>[chosen.sender]</i><br>To: <i>[chosen.receiver]</i><br><i>Received at [chosen.date]</i><br>---<br><b>[chosen.subject]</b><br>[chosen.message]<br>"
				mainbody += "<br>"
			else
				var/datum/email/chosen = map.emails[uname][text2num(href_list["mail"])]
				mainbody += "---<br>From: <i>[chosen.sender]</i><br>To: <i>[chosen.receiver]</i><br><i>Received at [chosen.date]</i><br>---<br><b>[chosen.subject]</b><br>[chosen.message]<br>"
				mainbody += "<br>"
	if (href_list["sendmail"])
		switch(href_list["sendmail"])
			if ("2")
				tmp_comp_vars["mail_rec"] = input(user, "Who to send the e-mail to?") as text
			if ("3")
				tmp_comp_vars["mail_subj"] = input(user, "What is the subject?") as text
			if ("4")
				tmp_comp_vars["mail_msg"] = input(user, "What is the message?") as message
			if ("5")
				tmp_comp_vars["mail_snd"] = WWinput(user, "Send from which e-mail account?","e-mail",tmp_comp_vars["mail_snd"],list(uname,cname))
			
		mainbody = "<h2>MONKEYSOFT E-MAIL CLIENT</h2><br>"
		mainbody += "<b>Logged in as <i>[uname]</i></b><br>"
		mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<a href='?src=\ref[src];mail=99999'>Inbox</a><br><br>"
		mainbody += "From: <a href='?src=\ref[src];sendmail=5'>[tmp_comp_vars["mail_snd"]]</a><br>To: <a href='?src=\ref[src];sendmail=2'>[tmp_comp_vars["mail_rec"]]</a><br>"
		mainbody += "Subject: <a href='?src=\ref[src];sendmail=3'>[tmp_comp_vars["mail_subj"]]</a><br>"
		mainbody += "Message: <a href='?src=\ref[src];sendmail=4'>[tmp_comp_vars["mail_msg"]]</a><br>"
		mainbody += "<a href='?src=\ref[src];mail_send=1'>Send</a><br>"
	if (href_list["mail_send"])
		var/datum/email/eml = new/datum/email
		eml.subject = tmp_comp_vars["mail_subj"]
		eml.sender = tmp_comp_vars["mail_snd"]
		eml.receiver = tmp_comp_vars["mail_rec"]
		eml.message = tmp_comp_vars["mail_msg"]
		eml.date = roundduration2text()
		map.emails[eml.receiver] += list(eml)
		reset_tmp_vars()
		WWalert(user,"Mail sent successfully!","E-mail Sent")

