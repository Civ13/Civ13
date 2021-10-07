
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
	battle_name = "Pirate life"
	mission_start_message = "<font size=4>Your crew of pirates assembles for the first voyage. Will you get rich, or perish like the others?</font>"
	is_singlefaction = TRUE
	is_RP = TRUE
	has_hunger = TRUE

	var/longitude = 71 //71 to 77 W
	var/latitude = 21 //21 to 27 N
	var/list/mapgen = list()
	var/list/islands = list()
	var/list/ships = list()
	var/navmoving = FALSE //if the ship is moving
	var/navdirection = "North"
	var/navprogress = 0 //how far along on moving to a neighbouring tile the ship is
	var/navspeed = 0
	var/inzone = FALSE //if the ship is currently in an event zone
	var/ship_anchored = TRUE
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
								for(var/obj/effect/sailing_effect/S in world)
									S.icon_state = "sailing_effect_stopped"
									S.update_icon()
						if ("South")
							if(latitude > 21)
								latitude--
							else
								navmoving = FALSE
								for(var/obj/effect/sailing_effect/S in world)
									S.icon_state = "sailing_effect_stopped"
									S.update_icon()
						if ("East")
							if(longitude < 77)
								longitude++
							else
								navmoving = FALSE
								for(var/obj/effect/sailing_effect/S in world)
									S.icon_state = "sailing_effect_stopped"
									S.update_icon()
						if ("West")
							if(longitude > 71)
								longitude--
							else
								navmoving = FALSE
								for(var/obj/effect/sailing_effect/S in world)
									S.icon_state = "sailing_effect_stopped"
									S.update_icon()

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
	for(var/obj/effect/sailing_effect/S in world)
		S.icon_state = "sailing_effect_stopped"
		S.update_icon()
	inzone = TRUE
	ship_anchored = TRUE
	world << "<big>The ship arrives at the destination.</big>"
	load_map(pick("island1","island2"),"random")
	return

/obj/map_metadata/voyage/proc/abandon_event()
	navmoving = TRUE
	for(var/obj/effect/sailing_effect/S in world)
		S.icon_state = "sailing_effect"
		S.update_icon()
	inzone = FALSE
	ship_anchored = FALSE
	world << "<big>The ship returns to the high seas.</big>"
	for(var/obj/structure/grapplehook/G in world)
		G.undeploy()
	clear_map()
	return

/obj/map_metadata/voyage/proc/clear_map()
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
////////////////////////////////////////////////////////////////
//////////////////LOADING AND SAVING PARTIAL MAPS//////////////
/obj/map_metadata/voyage/proc/load_map(mapname = "ship1", location = "random")
	if (location == "random")
		location = pick("south","north")
	var/y_offset = 0 //for north maps
	if (location == "north")
		y_offset = 50
	var/partpath = "maps/zones/[location]/[mapname]"
	world.log << "Importing [partpath]..."
	var/F = file("[partpath]/turfs.txt")
	if (fexists(F))
		world.log << "Importing turfs..."
		var/tmpturfs = file2text(F)
		var/list/impturfs = splittext(tmpturfs, "\n")
		for (var/i in impturfs)
			var/list/impturfs2 = splittext(i, ";")
			if (impturfs2.len && impturfs2[1] == "TURF")
				var/resultp = text2path(impturfs2[5])
				var/turf/T = locate(text2num(impturfs2[2]),text2num(impturfs2[3])+y_offset,text2num(impturfs2[4]))
				if (T)
					T.ChangeTurf(resultp)
	var/F1 = file("[partpath]/areas.txt")
	if (fexists(F1))
		world.log << "Importing areas..."
		var/tmpareas = file2text(F1)
		var/list/impareas = splittext(tmpareas, "\n")
		for (var/i in impareas)
			var/list/impareas2 = splittext(i, ";")
			if (impareas2.len && impareas2[1] == "AREA")
				var/resultp = text2path(impareas2[5])
				new resultp(locate(text2num(impareas2[2]),text2num(impareas2[3])+y_offset,text2num(impareas2[4])))

	var/F2 = file("[partpath]/mobs.txt")
	if (fexists(F2))
		world.log << "Importing mobs..."
		var/tmpmobs = file2text(F2)
		var/list/impmobs = splittext(tmpmobs, "\n")
		for (var/i in impmobs)
			var/list/impmobs2 = splittext(i, ";")
			if (impmobs2.len >= 5 && impmobs2[1] == "MOB" && impmobs2[5] != "/mob/new_player" && impmobs2[5] != "/mob/observer")
				var/resultp = text2path(impmobs2[5])
				var/mob/newmob = new resultp(locate(text2num(impmobs2[2]),text2num(impmobs2[3])+y_offset,text2num(impmobs2[4])))
				newmob.stat = text2num(impmobs2[6])
	var/F3 = file("[partpath]/objs.txt")
	if (fexists(F3))
		world.log << "Importing objects..."
		var/tmpobjs = file2text(F3)
		var/list/impobjs = splittext(tmpobjs, "\n")
		for (var/i in impobjs)
			var/list/impobjs2 = splittext(i, ";")
			if (impobjs2.len >= 5)
				var/resultp = text2path(impobjs2[5])
				var/obj/tmpobj = new resultp(locate(text2num(impobjs2[2]),text2num(impobjs2[3])+y_offset,text2num(impobjs2[4])))
				if (impobjs2[1] == "OBJECT")
					for (var/j=6, j<=impobjs2.len, j++)
						var/list/tempvars = splittext(impobjs2[j], "===")
						if (tempvars.len == 2)
							if (tempvars[1] == "name")
								tmpobj.name = tempvars[2]
							else if (tempvars[1] == "desc")
								tmpobj.desc = tempvars[2]
							else if (tempvars[1] == "dir")
								tmpobj.dir = text2num(tempvars[2])
							else if (tempvars[1] == "icon_state")
								tmpobj.icon_state = tempvars[2]
							else
								if (tmpobj.vars[tempvars[1]] && tempvars[1] != "loc" && tempvars[1] != "locs" && tempvars[1] != "verbs")
									tmpobj.vars[tempvars[1]] = tempvars[2]
	world.log << "Imported all objects."
	world.log << "Finished all imports."
///////////////////////////////////////////////////////////////////
/obj/map_metadata/voyage/proc/list2text_assoc(var/atom/A, nx = -1, ny = -1, nz = -1)
	. = list()
	if (istype(A, /obj/structure/wild) || (!istype(A, /obj/item) && !istype(A, /obj/structure) && !istype(A, /obj/map_metadata) && !istype(A, /obj/covers)))
		return "SIMPLE_OBJ;[A.x];[A.y];[A.z];[A.type]"
	else
		var/keylist = list("name","desc","icon_state","dir")
		if (istype(A, /obj/item/stack))
			keylist += "amount"
		for (var/key in keylist)
			if (A.vars[key] && A.vars[key] != initial(A.vars[key]))
				if (islist(A.vars[key]))
					if (isemptylist(A.vars[key]))
						. += "[key]===EMPTYLIST"
					else
						. += "[key]==={{"
						for(var/i in A.vars[key])
							. += "[i]|"
						. += "}}"
				else
					. += "[key]===[A.vars[key]]"
		if (nx == -1)
			nx = A.x
		if (ny == -1)
			ny = A.y
		if (nz == -1)
			nz = A.z
		return "OBJECT;[nx];[ny];[nz];[A.type];[list2text(.)]"

/obj/map_metadata/voyage/proc/do_export(saveloc = "maps/test")
	world << "<i><b>Saving the game... Might lag for a few seconds.</b></i>"
	world.log << "Started saving at [time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]."
	var/F = file("[saveloc]/mobs.txt")
	if (fexists(F))
		fdel(F)
	var/F1 = file("[saveloc]/turfs.txt")
	if (fexists(F1))
		fdel(F1)
	var/F2 = file("[saveloc]/objs.txt")
	if (fexists(F2))
		fdel(F2)
	var/F3 = file("[saveloc]/areas.txt")
	if (fexists(F3))
		fdel(F3)
	spawn(10)
		for (var/turf/T in world)
			if (!istype(T, /turf/floor/beach/water/deep/saltwater))
				text2file("TURF;[T.x];[T.y];[T.z];[T.type]",F1)
			var/area/AR = get_area(T)
			if (istype(AR,/area/caribbean/sea/bottom/roofed) || istype(AR,/area/caribbean/sea/top/roofed))
				text2file("AREA;[T.x];[T.y];[T.z];[AR.type]",F3)
			for (var/mob/living/A in T)
				text2file("MOB;[A.x];[A.y];[A.z];[A.type];[A.stat]",F)
			for (var/obj/O in T)
				if (!istype(O,/obj/screen) && !istype(O,/atom/movable/lighting_overlay) && !istype(O,/obj/map_metadata) && !istype(O,/obj/effect))
					if(istype(O, /obj/structure/closet))
						for(var/obj/CT in O)
							text2file(list2text_assoc(CT, O.x, O.y, O.z),F2)
					text2file(list2text_assoc(O),F2)
	sleep(1)
	world.log << "Finished saving at [time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]."
	world << "<i><b>Finished saving.</b></i>"
	return saveloc

/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////
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
	nav()
	for(var/lon = 71, lon <= 77, lon++)
		for(var/lat = 21, lat <= 27, lat++)
			mapgen["[lat],[lon]"] = list(lat, lon, "sea")
			if (prob(25))
				mapgen["[lat],[lon]"][3] = "island"
				islands += list(list("[pick(country_names)]",lat, lon))

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
			if (nmap.ship_anchored)
				WWalert(H, "The ship is anchored! Raise the anchor first","Ship Anchored")
				return
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
					if (findtext(nmap.navdirection,"Approach "))
						nmap.navdirection = replacetext(nmap.navdirection,"Approach ","")
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
	var/icon/img_flattened
	New()
		..()
		img = image(icon = 'icons/minimaps.dmi', icon_state = "voyage")
		spawn(20)
			if(map.ID == MAP_VOYAGE)
				var/obj/map_metadata/voyage/nmap = map
				for(var/list/L in nmap.islands)
					var/image/newisland = image(icon='icons/minimap_effects.dmi', icon_state=pick("island1","island2","island3"),layer=src.layer+1)
					newisland.pixel_x = 42+((L[3]-71)*70)
					newisland.pixel_y = 25+((L[2]-21)*67)
					img.overlays+=newisland
		img_flattened = getFlatIcon(img)

	examine(mob/user)
		update_icon()
		user << browse(getFlatIcon(img),"window=popup;size=630x630")

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
			H << "The ship is heading <b>[nmap.navdirection]</b>."
			if(nmap.ship_anchored)
				H << "The ship is <font color='red'><b>anchored</b></font>."

/obj/structure/voyage_shipbell
	name = "ship's bell"
	desc = "Used to relay signals to the crew."
	icon = 'icons/obj/structures.dmi'
	icon_state = "bell_stand"
	layer = 4
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/cooldown_bell_stand = 0

	attack_hand(mob/living/human/user)
		if(!ishuman(user))
			return
		play()

	proc/play()
		if (world.time >= cooldown_bell_stand)
			for (var/mob/M in player_list)
				M.client << sound('sound/effects/bell_stand.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			world << "<font size=4>You hear the ship's bell!</font>"
			cooldown_bell_stand = world.time+50
			icon_state = "bell_stand_ringing"
			spawn(15)
				icon_state = "bell_stand"


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
	var/image/anchor

	New()
		..()
		anchor = image(icon = 'icons/obj/vehicles/vehicleparts.dmi', icon_state = "anchor", layer = 5, pixel_y = -32)

	update_icon()
		..()
		overlays.Cut()
		if(anchored)
			overlays += anchor

	attack_hand(mob/user)
		if(map.ID == MAP_VOYAGE)
			var/obj/map_metadata/voyage/nmap = map
			if (nmap.inzone)
				if (nmap.ship_anchored)
					var/resp = WWinput(user, "You are currently in an event, are you sure you want to raise the anchor and leave? It will take two minutes.","Anchor","No",list("Yes","No"))
					if (resp == "No")
						return
					else
						world << "<big>The ship is getting ready to leave, ALL crew outside must return within <b>2</b> minutes or be left behind!</big>"
						spawn(1200)
							nmap.ship_anchored = FALSE
							nmap.navmoving = TRUE
							for(var/obj/effect/sailing_effect/S in world)
								S.icon_state = "sailing_effect"
								S.update_icon()
							update_icon()
							nmap.abandon_event()
				else
					user << "You start [nmap.ship_anchored ? "raising" : "lowering"] the anchor..."
					if (do_after(user, 60, src))
						user << "You lower the anchor."
						nmap.ship_anchored = TRUE
						nmap.navmoving = FALSE
						for(var/obj/effect/sailing_effect/S in world)
							S.icon_state = "sailing_effect_stopped"
							S.update_icon()
						update_icon()

			else
				user << "You start [nmap.ship_anchored ? "raising" : "lowering"] the anchor..."
				if (do_after(user, 60, src))
					if (nmap.ship_anchored)
						user << "You raise the anchor."
						world << "<big>The ship starts moving.</big>"
						nmap.ship_anchored = FALSE
						nmap.navmoving = TRUE
						for(var/obj/effect/sailing_effect/S in world)
							S.icon_state = "sailing_effect"
							S.update_icon()
						update_icon()
					else
						user << "You lower the anchor."
						nmap.ship_anchored = TRUE
						nmap.navmoving = FALSE
						for(var/obj/effect/sailing_effect/S in world)
							S.icon_state = "sailing_effect_stopped"
							S.update_icon()
						update_icon()
	
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

/obj/effect/sailing_effect
	name = "waves"
	desc = "Waves caused by the ship's movement."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "sailing_effect_stopped"
	layer = 4
	density = FALSE
	anchored = TRUE
