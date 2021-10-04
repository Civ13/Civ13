
/obj/map_metadata/voyage
	ID = MAP_VOYAGE
	title = "Voyage"
	no_winner ="The ship is on the way."
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0


	faction_organization = list(
		PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/no_mans_land,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Transatlantic Voyage"
	mission_start_message = "<font size=4>The travel is starting. Hold the ship against the pirates!</font>"
	is_singlefaction = TRUE
	is_RP = TRUE

	var/longitude = 71 //71 to 77 W
	var/latitude = 21 //21 to 27 N
	var/list/mapgen = list()
	var/list/islands = list()
	var/navmoving = FALSE //if the ship is moving
	var/navdirection = "North"
	var/navprogress = 0 //how far along on moving to a neighbouring tile the ship is
	var/navspeed = 0
	var/inzone = FALSE //if the ship is currently in an event zone
	var/ship_anchored = FALSE
/obj/map_metadata/voyage/proc/nav()
	if (navmoving && !ship_anchored)
		if (!inzone)
			navspeed = calc_speed()
			navprogress += navspeed
			if (navprogress >= 100)
				navprogress = 0
				if (navdirection == "island" || navdirection == "ship")
					enter_event()
				else
					switch(navdirection)
						if ("North")
							if(latitude < 27)
								latitude++
							else
								navmoving = FALSE
						if ("South")
							if(latitude > 21)
								latitude--
							else
								navmoving = FALSE
						if ("East")
							if(longitude < 77)
								longitude++
							else
								navmoving = FALSE
						if ("West")
							if(longitude > 71)
								longitude--
							else
								navmoving = FALSE

	spawn(600)
		nav()

/obj/map_metadata/voyage/proc/calc_speed()
	var/spd = 0
	var/snum = 0
	for(var/obj/structure/barricade/ship/mast/large/S in world)
		if (S.owner == "ship")
			spd += (S.sailstat+S.sailhealth+S.rigginghealth)/300
			snum++
	if (spd != 0 && snum != 0)
		spd/=snum //divide by number of masts
	spd*=33 //how much % of progress per minute for each spd unit, ex: 2 masts in full condition = 1*33 = 33, 3 mins to change tiles
	return spd

/obj/map_metadata/voyage/proc/enter_event()
	navmoving = FALSE
	inzone = TRUE
	ship_anchored = TRUE
	world << "<big>The ship arrives at the destination.</big>"
	return

/obj/map_metadata/voyage/proc/abandon_event()
	navmoving = TRUE
	inzone = FALSE
	ship_anchored = FALSE
	world << "<big>The ship returns to the high seas.</big>"
	clear_maps()
	return

/obj/map_metadata/voyage/proc/clear_maps()
	//North
	for(var/turf/T in get_area_turfs(/area/caribbean/sea/top))
		for (var/mob/living/M in T)
			qdel(M)
		for (var/obj/O in T)
			qdel(O)
		if (T.type != /turf/floor/beach/water/deep/saltwater)
			T.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	for(var/turf/T1 in get_area_turfs(/area/caribbean/sea/top/roofed))
		for (var/mob/living/M in T1)
			qdel(M)
		for (var/obj/O in T1)
			qdel(O)
		if (T1.type != /turf/floor/beach/water/deep/saltwater)
			T1.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
		new/area/caribbean/sea/top(T1)
		for (var/atom/movable/lighting_overlay/LO in T1)
			LO.update_overlay()
	//South
	for(var/turf/T2 in get_area_turfs(/area/caribbean/sea/bottom))
		for (var/mob/living/M in T2)
			qdel(M)
		for (var/obj/O in T2)
			qdel(O)
		if (T2.type != /turf/floor/beach/water/deep/saltwater)
			T2.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	for(var/turf/T3 in get_area_turfs(/area/caribbean/sea/bottom/roofed))
		for (var/mob/living/M in T3)
			qdel(M)
		for (var/obj/O in T3)
			qdel(O)
		if (T3.type != /turf/floor/beach/water/deep/saltwater)
			T3.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
		new/area/caribbean/sea/bottom(T3)
		for (var/atom/movable/lighting_overlay/LO in T3)
			LO.update_overlay()
/obj/map_metadata/voyage/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1 || admin_ended_all_grace_periods)

/obj/map_metadata/voyage/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1 || admin_ended_all_grace_periods)

/obj/map_metadata/voyage/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_prison == TRUE)
		. = FALSE
	else if (J.is_ww1 == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/pirates/cook) || istype(J, /datum/job/pirates/carpenter) || istype(J, /datum/job/pirates/midshipman))
		. = FALSE
	else
		. = TRUE

/obj/map_metadata/voyage/New()
	..()
	for(var/lon = 70, lon <= 77, lon++)
		for(var/lat = 21, lat <= 27, lat++)
			mapgen["[lat],[lon]"] = list(lat, lon, "sea")
			if (prob(25))
				mapgen["[lat],[lon]"][3] = "island"
				islands += list(lat, lon)

/obj/map_metadata/voyage/cross_message()
	return ""
/obj/map_metadata/voyage/reverse_cross_message()
	return ""
///////////////Specific objects////////////////////
/obj/structure/voyage_shipwheel
	name = "ship wheel"
	desc = "Used to steer the ship."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "ship_wheel"
	layer = 2.99
	density = TRUE
	anchored = TRUE
	attack_hand(mob/living/human/H)
		var/obj/map_metadata/voyage/nmap = map
		if (nmap)
			var/optlist = list("North","South","East","West")
			var/def_dir = nmap.navdirection
			var/currtile = nmap.mapgen["[nmap.latitude],[nmap.longitude]"][3]
			if (currtile != "sea")
				optlist = list("Approach [currtile]","North","South","East","West")
				def_dir = "Approach [currtile]"
			var/newdir = WWinput(H, "The Ship is currently moving [nmap.navdirection]. Which direction to you want to head to?","Ship Wheel",def_dir,optlist)
			if (newdir != nmap.navdirection)
				if (do_after(H, 50, src))
					nmap.navdirection = newdir
					visible_message("<font size=2>The ship turns <b>[nmap.navdirection]</b>.</font>")
					return
/obj/structure/voyage_tablemap
	name = "map"
	desc = "A map of the regeion. Used by the captain to plan the next moves."
	icon = 'icons/obj/items.dmi'
	icon_state = "table_map"
	layer = 3.2
	var/mob/living/user = null
	anchored = TRUE
	var/image/img

	New()
		..()
		img = image(icon = 'icons/minimaps.dmi', icon_state = "voyage")


	examine(mob/user)
		update_icon()
		user << browse("<img src=voyage.png></img>","window=popup;size=630x630")

	attack_hand(mob/user)
		update_icon()
		examine(user)

/obj/structure/voyage_boatswain_book
	name = "crew log"
	desc = "A book listing all the ship's crew and their assigned jobs."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_bs"
	layer = 3.2
	anchored = TRUE
	attack_hand(mob/living/human/H)
		if (H.original_job_title == "Pirate Boatswain")
			var/dat = "<h1>CREW LOG</h1>"
			dat += tally_crew()
			H << browse(dat, "window=Crew Log")
	proc/tally_crew()
		var/t_text = "<style>table, th, td {border: 1px solid black;}</style><table><tr><th>Name</th><th>Job</th></tr>"
		for(var/mob/living/human/HM in world)
			if (HM.stat != DEAD)
				t_text += "<tr><td>[HM.name]</td><td>[HM.original_job_title]</td></tr>"
		t_text += "</table>"
		return t_text
					
/obj/structure/voyage_quartermaster_book
	name = "ship inventory"
	desc = "A diary tracking the current inventory in the ship."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_qm"
	layer = 3.2
	anchored = TRUE

	attack_hand(mob/living/human/H)
		if (H.original_job_title == "Pirate Quartermaster")
			var/tres = tally_treasure()
			var/mats = tally_materials()
			var/mats_wood = mats["wood"]
			var/mats_cloth = mats["cloth"]
			var/mats_rope = mats["rope"]
			var/food = tally_food()
			var/mats_food = food["food"]
			var/mats_water = food["water"]
			var/wep = tally_weapons()
			var/mats_cannon = wep["cannonballs"]
			var/mats_musket = wep["musket"]
			var/mats_pistol = wep["pistol"]

			var/dat = "<h1>SHIP STOCKS</h1>"
			dat += "<b>Treasury:</b> [tres] reales<br>"
			dat += "<b>Wood:</b> [mats_wood] logs<br>"
			dat += "<b>Cloth:</b> [mats_cloth] sheets<br>"
			dat += "<b>Rope:</b> [mats_rope] coils<br>"
			dat += "<b>Food:</b> [mats_food] doses<br>"
			dat += "<b>Water:</b> [mats_water] units<br>"
			dat += "<b>Cannon Ammo:</b> [mats_cannon] balls<br>"
			dat += "<b>Musket Ammo:</b> [mats_musket] projectiles<br>"
			dat += "<b>Pistol Ammo:</b> [mats_pistol] projectiles<br>"
			H << browse(dat, "window=Ship Stocks")
	proc/tally_treasure()
		var/tally = 0
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/upper/inside/treasury)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/chest/treasury/ship/S in sel_turf)
				for(var/obj/item/stack/money/M in S)
					tally += M.value*M.amount
				for(var/obj/item/stack/money/M1 in S.loc)
					tally += M1.value*M1.amount
		return tally

	proc/tally_materials()
		var/list/tally = list("cloth" = 0, "wood" = 0, "rope" = 0)
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/S in sel_turf)
				for(var/obj/item/stack/material/cloth/M in S)
					tally["cloth"] += M.amount
				for(var/obj/item/stack/material/rope/M1 in S)
					tally["rope"] += M1.amount
				for(var/obj/item/stack/material/wood/M2 in S)
					tally["wood"] += M2.amount
			for(var/obj/item/stack/material/cloth/M in sel_turf)
				tally["cloth"] += M.amount
			for(var/obj/item/stack/material/rope/M1 in sel_turf)
				tally["rope"] += M1.amount
			for(var/obj/item/stack/material/wood/M2 in sel_turf)
				tally["wood"] += M2.amount
		return tally

	proc/tally_food()
		var/list/tally = list("food" = 0, "water" = 0)
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage/kitchen)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/S in sel_turf)
				for(var/obj/item/weapon/reagent_containers/food/F in S)
					tally["food"]++
			for(var/obj/item/weapon/reagent_containers/food/F in sel_turf)
				tally["food"]++
			for(var/obj/item/weapon/reagent_containers/glass/barrel/B in sel_turf)
				for (var/datum/reagent/R in B.reagents.reagent_list)
					if (istype(R, /datum/reagent/water))
						tally["water"] += R.volume
			for(var/obj/structure/reagent_dispensers/largebarrel/L in sel_turf)
				for (var/datum/reagent/R in L.reagents.reagent_list)
					if (istype(L, /datum/reagent/water))
						tally["water"] += R.volume
		return tally

	proc/tally_weapons()
		var/list/tally = list("musket" = 0, "pistol" = 0, "cannonballs" = 0)
		var/list/t_turfs = get_area_turfs(/area/caribbean/pirates/ship/voyage/lower/storage/magazine)
		for(var/turf/sel_turf in t_turfs)
			for(var/obj/structure/closet/crate/S in sel_turf)
				for(var/obj/item/ammo_casing/musketball/MB in S)
					tally["musket"]++
				for(var/obj/item/ammo_casing/musketball_pistol/MBP in S)
					tally["pistol"]++
				for(var/obj/item/cannon_ball/CB in S)
					tally["cannonballs"]++
			for(var/obj/item/ammo_casing/musketball/MB in sel_turf)
				tally["musket"]++
			for(var/obj/item/ammo_casing/musketball_pistol/MBP in sel_turf)
				tally["pistol"]++
			for(var/obj/item/cannon_ball/CB in sel_turf)
				tally["cannonballs"]++
		return tally

/obj/structure/voyage_sextant
	name = "sextant"
	desc = "Used to determine the current latitude and longitude using the sun and stars."
	icon = 'icons/obj/items.dmi'
	icon_state = "sextant_tool"
	layer = 3.2
	anchored = TRUE

	attack_hand(mob/living/human/H)
		var/obj/map_metadata/voyage/nmap = map
		if (nmap)
			H << "The ship is currently at <b>[nmap.latitude]</b>°N, <b>[nmap.longitude]</b>°W."
			H << "The ship is facing the <b>[nmap.navdirection]</b>."

/obj/structure/voyage_ropeladder
	name = "rope ladder"
	desc = "A strong rope ladder leading up the mast."
	icon = 'icons/turf/64x64.dmi'
	icon_state = "ropeladder"
	layer = 5
	density = FALSE
	anchored = TRUE

/obj/structure/voyage_anchor
	name = "anchor"
	desc = "A large iron anchor."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "anchor"
	layer = 5
	density = FALSE
	anchored = TRUE

/obj/structure/voyage_anchor_capstan
	name = "anchor capstan"
	desc = "A vertical-axled rotating machine used to raise and lower the ship's anchor."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "capstan"
	layer = 4
	density = TRUE
	anchored = TRUE

	attack_hand(mob/user)
		if(map.ID == MAP_VOYAGE)
			var/obj/map_metadata/voyage/nmap = map
			if (nmap.inzone)
				if (nmap.ship_anchored)
					var/resp = WWinput(user, "You are currently in an event, are you sure you want to raise the anchor and leave? It will take two minutes.","Anchor","No",list("Yes","No"))
					if (resp == "No")
						return
					else
						world << "<big>The ship is getting ready to leave, all crew outside must return within <b>2</b> minutes or be left behind!</big>"
						spawn(1200)
							nmap.ship_anchored = TRUE
							nmap.navmoving = FALSE
							nmap.abandon_event()
				else
					user << "You start pulling the anchor..."
					if (do_after(user, 60, src))
						user << "You lower the anchor."
						nmap.ship_anchored = TRUE
						nmap.navmoving = FALSE	

			else
				user << "You start pulling the anchor..."
				if (do_after(user, 60, src))
					if (nmap.ship_anchored)
						user << "You raise the anchor."
						nmap.ship_anchored = FALSE
						nmap.navmoving = TRUE
					else
						user << "You lower the anchor."
						nmap.ship_anchored = TRUE
						nmap.navmoving = FALSE
	
/obj/structure/voyage_ropeladder/thin
	icon_state = "ropeladder_thin"

/obj/structure/closet/crate/chest/treasury/ship
	name = "ship's treasury"
	desc = "Where the ship's treasury is stored."
	faction = "ship"
	anchored = TRUE

/obj/structure/voyage_grid
	name = "loading gate"
	desc = "A large gridded gate, used to load the ship."
	icon = 'icons/turf/64x64.dmi'
	icon_state = "grid"
	layer = 2.99
	density = FALSE
	anchored = TRUE

/obj/structure/voyage_grid/partial
	icon_state = "grid_partial"

