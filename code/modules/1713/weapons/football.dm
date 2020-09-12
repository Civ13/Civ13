/obj/item/clothing/under/football
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"
	force = 0.0
	throwforce = 0.0
	var/player_number = 0

/obj/item/clothing/under/football/flamengo
	name = "flamengo shirt with yellow shorts"
	desc = "A C.R. Flamengo football shirt, with yellow swimming trunks."
	icon_state = "flamengo"
	item_state = "flamengo"
	worn_state = "flamengo"
	player_number = 10

/obj/item/clothing/under/football/red
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"

/obj/item/clothing/under/football/red/goalkeeper
	name = "Unga Bunga goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Unga Bunga United, U.B.U."
	icon_state = "football_red_gk"
	item_state = "football_red_gk"
	worn_state = "football_red_gk"

/obj/item/clothing/under/football/blue
	name = "Chad Town jersey"
	desc = "A football jersey of the Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue"
	item_state = "football_blue"
	worn_state = "football_blue"

/obj/item/clothing/under/football/blue/goalkeeper
	name = "Chad Town goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue_gk"
	item_state = "football_blue_gk"
	worn_state = "football_blue_gk"
///////////CUSTOM JERSEY//////////////
/obj/item/clothing/under/football/custom
	name = "football jersey"
	desc = "A football team's official jersey."
	var/uncolored = FALSE
	var/shirt_color = 0
	var/shorts_color = 0
	var/shorts_sides_color = 0
	var/shirt_sides_color = 0
	var/shirt_sleeves_color = 0
	var/shirt_hstripes_color = 0
	var/shirt_vstripes_color = 0
	item_state = "football_custom"
	icon_state = "football_custom"
	worn_state = "football_custom"
	heat_protection = LOWER_TORSO|UPPER_TORSO
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/football/custom/attack_self(mob/user as mob)
	if (uncolored)
		if (!shorts_color)
			var/input = WWinput(user, "Shorts - Choose a color:", "Shorts Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shorts_color = input
		var/add1 = WWinput(user, "Short Stripes", "Do you want to add side stripes to the shorts?", "No", list("Yes","No"))
		if (!shorts_sides_color && add1 == "Yes")
			var/input = WWinput(user, "Shorts Stripes - Choose a color:", "Short Stripes Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shorts_sides_color = input

		if (!shirt_color)
			var/input = WWinput(user, "Shirt - Choose a color:", "Shirt Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirt_color = input

		var/add3 = WWinput(user, "Shirt Sleeves", "Do you want to add a different color to sleeves?", "No", list("Yes","No"))
		if (!shirt_sleeves_color && add3 == "Yes")
			var/input = WWinput(user, "Shirt Sleeves - Choose a color:", "Shirt Sleeves Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirt_sleeves_color = input

		var/add4 = WWinput(user, "Shirt Stripes", "Do you want to add a shirt stripes?", "No", list("Horizontal Stripes", "Vertical Stripes", "No"))
		if (!shirt_hstripes_color && add4 == "Horizontal Stripes")
			var/input = WWinput(user, "Shirt Horizontal Stripes - Choose a color:", "Shirt Horizontal Stripes Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirt_hstripes_color = input

		if (!shirt_vstripes_color && add4 == "Vertical Stripes")
			var/input = WWinput(user, "Shirt Vertical Stripes - Choose a color:", "Shirt Vertical Stripes Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirt_vstripes_color = input

		var/add2 = WWinput(user, "Shirt Collar", "Do you want to add a different color to collars and sleeve tips?", "No", list("Yes","No"))
		if (!shirt_sides_color && add2 == "Yes")
			var/input = WWinput(user, "Shirt Collar - Choose a color:", "Shirt Collar Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirt_sides_color = input
		var/add5 = WWinput(user, "Shirt Number", "Do you want to add a number to the shirt?", "No", list("Yes","No"))
		if (add5 == "Yes")
			var/input = WWinput(user, "Shirt Collar - Choose a number:", "Shirt Number" , "Cancel", list(1,2,3,4,5,6,7,8,9,10,11, "Cancel"))
			if (input != "Cancel")
				player_number = input
		if (shirt_color && shorts_color)
			uncolored = FALSE
			var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt")
			shirt.color = shirt_color
			var/image/shorts = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts")
			shorts.color = shorts_color
			var/image/shorts_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts_sides")
			shorts_sides.color = shorts_sides_color
			var/image/shirt_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sides")
			shirt_sides.color = shirt_sides_color
			var/image/shirt_sleeves = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sleeves")
			shirt_sleeves.color = shirt_sleeves_color
			var/image/shirt_vstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_vertical")
			shirt_vstripes.color = shirt_vstripes_color
			var/image/shirt_hstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_horizontal")
			shirt_hstripes.color = shirt_hstripes_color
			overlays += shirt
			overlays += shorts
			if (shorts_sides_color)
				overlays += shorts_sides
			if (shirt_sides_color)
				overlays += shirt_sides
			if (shirt_sleeves_color)
				overlays += shirt_sleeves
			if (shirt_vstripes_color)
				overlays += shirt_vstripes
			if (shirt_hstripes_color)
				overlays += shirt_hstripes
			var/image/symbols = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_symbols")
			overlays += symbols
			return
	else
		..()
//for automatic assignement of colors, ie, roundstart
/obj/item/clothing/under/football/custom/proc/assign_style(tname,tshorts_color,tshirt_color,tshorts_sides_color=null,tshirt_sleeves_color=null,tshirt_sides_color=null,tshirt_vstripes_color=null,tshirt_hstripes_color=null,c_player_number=0)
	uncolored = FALSE
	if (tshorts_color != "null" && tshorts_color != "" && tshorts_color != "0")
		src.shorts_color = tshorts_color
	if (tshirt_color != "null" && tshirt_color != "" && tshirt_color != "0")
		src.shirt_color = tshirt_color
	if (tshorts_sides_color != "null" && tshorts_sides_color != "" && tshorts_sides_color != "0")
		src.shorts_sides_color = tshorts_sides_color
	if (tshirt_sleeves_color != "null" && tshirt_sleeves_color != "" && tshirt_sleeves_color != "0")
		src.shirt_sleeves_color = tshirt_sleeves_color
	if (tshirt_sides_color != "null" && tshirt_sides_color != "" && tshirt_sides_color != "0")
		src.shirt_sides_color = tshirt_sides_color
	if (tshirt_vstripes_color != "null" && tshirt_vstripes_color != "" && tshirt_vstripes_color != "0")
		src.shirt_vstripes_color = tshirt_vstripes_color
	if (tshirt_hstripes_color != "null" && tshirt_hstripes_color != "" && tshirt_hstripes_color != "0")
		src.shirt_hstripes_color = tshirt_hstripes_color
	if (tshirt_color && tshorts_color)
		var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt")
		shirt.color = shirt_color
		var/image/shorts = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts")
		shorts.color = shorts_color
		var/image/shorts_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts_sides")
		shorts_sides.color = shorts_sides_color
		var/image/shirt_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sides")
		shirt_sides.color = shirt_sides_color
		var/image/shirt_sleeves = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sleeves")
		shirt_sleeves.color = shirt_sleeves_color
		var/image/shirt_vstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_vertical")
		shirt_vstripes.color = shirt_vstripes_color
		var/image/shirt_hstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_horizontal")
		shirt_hstripes.color = shirt_hstripes_color
		overlays += shirt
		overlays += shorts
		if (shorts_sides_color)
			overlays += shorts_sides
		if (shirt_sides_color)
			overlays += shirt_sides
		if (shirt_sleeves_color)
			overlays += shirt_sleeves
		if (shirt_vstripes_color)
			overlays += shirt_vstripes
		if (shirt_hstripes_color)
			overlays += shirt_hstripes
		var/image/symbols = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_symbols")
		overlays += symbols
		if (c_player_number != 0)
			src.player_number = c_player_number
		spawn(10)
			uncolored = FALSE
		return
/////////SHOES////////////////////////
/obj/item/clothing/shoes/football
	name = "football trainers"
	desc = "A pair of football trainers."
	icon_state = "football"
	item_state = "football"
	worn_state = "football"
	armor = list(melee = 60, arrow = 5, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = 0.6
	force = 0.0
	throwforce = 0.0

////////////GLOVES/////////////////
/obj/item/clothing/gloves/goalkeeper/red
	name = "goalkeeper gloves"
	initial_name = "goalkeeper gloves"
	icon_state = "latex"
	item_state = "latex"
	color = "#ffffff"

/obj/item/clothing/gloves/goalkeeper/blue
	name = "goalkeeper gloves"
	initial_name = "goalkeeper gloves"
	icon_state = "latex"
	item_state = "latex"
	color = "#ffffff"

/mob/living/human/var/obj/item/football/football = null

/obj/item/football
	name = "ball"
	desc = "A classic black and white football."
	icon = 'icons/obj/football.dmi'
	icon_state = "football"
	force = 0.0
	throwforce = 0.0
	throw_speed = 0.5
	throw_range = 9
	item_state = "football"
	w_class = 4.0
	layer = 6
	opacity = FALSE
	density = FALSE
	allow_spin = FALSE

	var/mob/living/human/owner = null
	var/mob/living/human/last_owner = null
/obj/item/football/proc/update_movement()
	if (owner)
		src.dir = owner.dir
		src.forceMove(owner.loc)
	return

/obj/item/football/Crossed(mob/living/human/user)
	if (ishuman(user))
		if (!owner && !user.football)
			owner = user
			user.football = src
			return
		else
			..()
	else
		..()

/obj/item/football/attack_hand(mob/user as mob)
	var/area/A = get_area(src)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (!istype(A, /area/caribbean/football/blue/goalkeeper) && !istype(A, /area/caribbean/football/red/goalkeeper))
			return
		else if (!(findtext(H.original_job_title, "goalkeeper")))
			return
		else
			if (owner)
				owner.football = null
				owner = null
	..()
//goal posts
/obj/effect/step_trigger/goal
	name = "goalpost"
	var/team = null

	New()
		..()
		spawn(10)
			assign()
/obj/effect/step_trigger/goal/proc/assign()
	return

/obj/effect/step_trigger/goal/Trigger(var/atom/movable/A)
	if (istype(A, /obj/item/football) && team)
		if (istype(map, /obj/map_metadata/football))
			var/obj/map_metadata/football/MF = map
			MF.reset_ball()
			MF.teams[team][2] += 1
			var/obj/item/football/FB = A
			world << "<font size=4 color='orange'>GOAL! <b>[FB.last_owner ? FB.last_owner : "Unknown"] [FB.last_owner ? "([FB.last_owner.ckey])" : ""]</b> scores for <b>[team]</b>!</font>"
			var/scorer = " [FB.last_owner.name] ([FB.last_owner.ckey]) <b>([FB.last_owner.team])</b>"
			FB.last_owner = null
			FB.owner = null
			if (MF.scorers[scorer])
				MF.scorers[scorer] += 1
			else
				MF.scorers += list("[scorer]" = 1)
			return

/obj/effect/step_trigger/goal/red
	name = "team 1 goalpost"
	team = "red"

	assign()
		if (map && map.ID == MAP_FOOTBALL)
			var/obj/map_metadata/football/FBM = map
			team = FBM.teams[FBM.team1][1]

/obj/effect/step_trigger/goal/blue
	name = "team 2 goalpost"
	team = "blue"

	assign()
		if (map && map.ID == MAP_FOOTBALL)
			var/obj/map_metadata/football/FBM = map
			team = FBM.teams[FBM.team2][1]
/////////////////TEAM CREATOR/////////////////////

/obj/structure/submitter
	name = "Team Registration Terminal"
	desc = "Register your team here!"
	icon = 'icons/obj/computers.dmi'
	icon_state = "1980_computer_on"
	var/active = FALSE
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/mob/living/user = null
	var/list/pending = list()
/obj/structure/submitter/attack_hand(mob/living/human/mob as mob)
	if (!ishuman(mob))
		return
	if (!active)
		return
	mob.setClickCooldown(40)
	mob << "You take a blank kit from the Terminal. You can now customise it."
	new/obj/item/clothing/under/football/custom(loc)
	return

/obj/structure/submitter/attackby(obj/item/clothing/W as obj, mob/living/mob as mob)
	if (!istype(W, /obj/item/clothing/under/football/custom))
		return
	var/obj/item/clothing/under/football/custom/CU = W
	if (mob.ckey in pending) //continue
		var/list/T = pending[mob.ckey]
		var/list/olist = list("Cancel")
		if (!T["main_uniform"])
			olist += "Main"
		if (!T["secondary_uniform"])
			olist += "Secondary"
		if (!T["goalkeeper_uniform"])
			olist += "Goalkeeper"
		if (olist.len > 1)
			var/input4 = WWinput(mob, "Team Creator", "Welcome back! You are creating [T["name"]]. Which uniform is this?","Cancel",olist)
			switch(input4)
				if ("Main")
					T["main_uniform"] = list()
					T["main_uniform"]["shorts_color"] = CU.shorts_color
					T["main_uniform"]["shirt_color"] = CU.shirt_color
					T["main_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
					T["main_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
					T["main_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
					T["main_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
					T["main_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
				if ("Secondary")
					T["secondary_uniform"] = list()
					T["secondary_uniform"]["shorts_color"] = CU.shorts_color
					T["secondary_uniform"]["shirt_color"] = CU.shirt_color
					T["secondary_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
					T["secondary_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
					T["secondary_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
					T["secondary_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
					T["secondary_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
				if ("Goalkeeper")
					T["goalkeeper_uniform"] = list()
					T["goalkeeper_uniform"]["shorts_color"] = CU.shorts_color
					T["goalkeeper_uniform"]["shirt_color"] = CU.shirt_color
					T["goalkeeper_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
					T["goalkeeper_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
					T["goalkeeper_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
					T["goalkeeper_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
					T["goalkeeper_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
			if (T["goalkeeper_uniform"] && T["secondary_uniform"] && T["main_uniform"])
				var/obj/map_metadata/football/FM = map
				FM.teams += list("[T["name"]]" = T)
				WWalert(mob,"You sucessfully added the team! It is now selectable.")
				FM.save_teams()
				pending -= pending[mob.ckey]
				return
		return
	else //start new team
		var/input1 = WWinput(mob, "Team Creator", "Welcome to the team creator! Here you will be able to design your new sports team. You will need 3 kits (main, alternative, goalkeeper). Lets start by choosing a name.","Cancel",list("Cancel", "Start"))
		if (input1 == "Cancel")
			return
		else
			var/input2 = input(mob, "Team Name", "Choose a Team Name. Keep it under 20 characters!") as text
			if (!input2 || input2 == "")
				return
			else
				var/list/T = list()
				T["name"] = input2
				pending += list("[mob.ckey]" = T)
				var/input3 = WWinput(mob, "Team Creator", "Which type is the kit you submitted?","Main",list("Main", "Secondary", "Goalkeeper"))
				switch(input3)
					if ("Main")
						T["main_uniform"] = list()
						T["main_uniform"]["shorts_color"] = CU.shorts_color
						T["main_uniform"]["shirt_color"] = CU.shirt_color
						T["main_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
						T["main_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
						T["main_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
						T["main_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
						T["main_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
					if ("Secondary")
						T["secondary_uniform"] = list()
						T["secondary_uniform"]["shorts_color"] = CU.shorts_color
						T["secondary_uniform"]["shirt_color"] = CU.shirt_color
						T["secondary_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
						T["secondary_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
						T["secondary_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
						T["secondary_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
						T["secondary_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
					if ("Goalkeeper")
						T["goalkeeper_uniform"] = list()
						T["goalkeeper_uniform"]["shorts_color"] = CU.shorts_color
						T["goalkeeper_uniform"]["shirt_color"] = CU.shirt_color
						T["goalkeeper_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
						T["goalkeeper_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
						T["goalkeeper_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
						T["goalkeeper_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
						T["goalkeeper_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
				WWalert(mob,"You can now continue editing this team by submitting the remaining kits.","Team Creator")
				return

/////////////////GOALPOSTS/////////////////

/obj/structure/goalpost
	name = "goalpost"
	desc = "A goalpost"
	icon = 'icons/obj/fence.dmi'
	icon_state = "goalpostX"
	flammable = FALSE
	opacity = FALSE
	density = TRUE
	layer = 8
	anchored = TRUE

/obj/structure/goalpost/attackby(obj/O as obj, mob/user as mob)
	return
/obj/structure/goalpost/attack_hand(mob/user as mob)
	return

/obj/structure/goalpost/inner
	icon_state = "goalpost_i"
	density = FALSE