
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
	var/inzone = FALSE //if the ship is currently in an event zone

/obj/map_metadata/voyage/proc/nav()
	if (navmoving)
		if (!inzone)
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

	spawn(1200)
		nav()

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
			var/newdir = WWinput(H, "The Ship is currently moving [nmap.navdirection]. Which direction to you want to switch to?","Ship Wheel",nmap.navdirection,list("North","South","East","West"))
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
	name = "crew book"
	desc = "A book listing all the ship's crew and their assigned jobs."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_bs"
	layer = 3.2
	var/mob/living/user = null
	anchored = TRUE

/obj/structure/voyage_quartermaster_book
	name = "ship inventory"
	desc = "A diary tracking the current inventory in the ship."
	icon = 'icons/obj/library.dmi'
	icon_state = "book_qm"
	layer = 3.2
	var/mob/living/user = null
	anchored = TRUE

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

