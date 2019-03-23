//ARTILLERY

#define kanonier_msg " A Kanonier can now fire within <b>15 square meters</b> of this position."

var/global/list/valid_coordinates = list()
/mob/living/carbon/human/var/checking_coords[4]
/mob/living/carbon/human/var/can_check_distant_coordinates = FALSE

/mob/living/carbon/human/proc/make_artillery_officer()
	verbs += /mob/living/carbon/human/proc/Check_Coordinates
	verbs += /mob/living/carbon/human/proc/Reset_Coordinates
	can_check_distant_coordinates = TRUE

/mob/living/carbon/human/proc/make_artillery_scout()
	verbs += /mob/living/carbon/human/proc/Check_Coordinates_Chump
	verbs += /mob/living/carbon/human/proc/Reset_Coordinates_Chump
	can_check_distant_coordinates = TRUE

/mob/living/carbon/human/proc/make_commander()
	verbs += /mob/living/carbon/human/proc/Commander_Announcement

/mob/living/carbon/human/proc/remove_commander()
	verbs -= /mob/living/carbon/human/proc/Commander_Announcement


/mob/living/carbon/human/proc/make_title_changer()
	verbs += /mob/living/carbon/human/proc/Add_Title
	verbs += /mob/living/carbon/human/proc/Remove_Title

/mob/living/carbon/human/proc/remove_title_changer()
	verbs -= /mob/living/carbon/human/proc/Add_Title
	verbs -= /mob/living/carbon/human/proc/Remove_Title


/proc/check_coords_check()
	return (!map || (map.faction2_can_cross_blocks() && map.faction1_can_cross_blocks()))
/mob/living/carbon/human/proc/Commander_Announcement()
	set category = "Officer"
	set name = "Faction Announcement"
	set desc="Announce to everyone in your faction."
	var/messaget = "Governor Announcement"
	var/message = russian_to_cp1251(input("Global message to send:", "IC Announcement", null, null))  as message
	if (message)
		message = sanitize(message, 500, extra = FALSE)
		message = replacetext(message, "\n", "<br>") // required since we're putting it in a <p> tag
	for (var/mob/living/carbon/human/M)
		if (!map.civilizations)
			if (faction_text == M.faction_text)
				messaget = "[name] announces:"
				M.show_message("<big><span class=notice><b>[messaget]</b></big><p style='text-indent: 50px'>[message]</p></span>", 2)
			log_admin("Governor Announcement: [key_name(usr)] - [messaget] : [message]")
		else
			if (civilization == M.civilization && civilization != "none")
				messaget = "[name] announces:"
				M.show_message("<big><span class=notice><b>[messaget]</b></big><p style='text-indent: 50px'>[message]</p></span>", 2)
			log_admin("Faction Announcement: [key_name(usr)] - [messaget] : [message]")

/mob/living/carbon/human/proc/Check_Coordinates()
	set category = "Officer"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		checking_coords[3] = x
		checking_coords[4] = y
		valid_coordinates["[x],[y]"] = TRUE
		var/dist = "[checking_coords[3] - checking_coords[1]],[checking_coords[4] - checking_coords[2]]"
		usr << "<span class = 'notice'>You finished tracking coordinates at <b>[x],[y]</b>. You moved an offset of <b>[dist]</b>.[kanonier_msg]</span>"
		checking_coords[3] = null
		checking_coords[4] = null // continue to track from the same starting location
	else
		checking_coords[1] = x
		checking_coords[2] = y
		usr << "<span class = 'notice'>You've started checking coordinates at <b>[x], [y]</b>.</span>"

/mob/living/carbon/human/proc/Reset_Coordinates()
	set category = "Officer"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		var/x = checking_coords[1]
		var/y = checking_coords[2]
		checking_coords[1] = null
		checking_coords[2] = null
		usr << "<span class = 'notice'>You are no longer tracking from <b>[x],[y]</b>.</span>"
		checking_coords[3] = null
		checking_coords[4] = null

// the only thing different about these verbs is the category

/mob/living/carbon/human/proc/Check_Coordinates_Chump()
	set category = "Scout"
	set name = "Check Coordinates"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		checking_coords[3] = x
		checking_coords[4] = y
		valid_coordinates["[x],[y]"] = TRUE
		var/dist = "[checking_coords[3] - checking_coords[1]],[checking_coords[4] - checking_coords[2]]"
		usr << "<span class = 'notice'>You finished tracking coordinates at <b>[x],[y]</b>. You moved an offset of <b>[dist]</b>.[kanonier_msg]</span>"
		checking_coords[3] = null
		checking_coords[4] = null // continue to track from the same starting location
	else
		checking_coords[1] = x
		checking_coords[2] = y
		usr << "<span class = 'notice'>You've started checking coordinates at <b>[x],[y]</b>.</span>"

/mob/living/carbon/human/proc/Reset_Coordinates_Chump()
	set category = "Scout"
	set name = "Reset Coordinates"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		var/x = checking_coords[1]
		var/y = checking_coords[2]
		checking_coords[1] = null
		checking_coords[2] = null
		usr << "<span class = 'warning'>You are no longer tracking from <b>[x],[y]</b>.</span>"
		checking_coords[3] = null
		checking_coords[4] = null

// artyman/officer/scout getting coordinates
/mob/living/carbon/human/RangedAttack(var/turf/t)
	if (checking_coords[1] && istype(t))
		if (can_check_distant_coordinates && get_turf(src) != t)
			var/offset_x = t.x - x
			var/offset_y = t.y - y
			src << "<span class = 'notice'>This turf has an offset of <b>[offset_x],[offset_y]</b> and coordinates of <b>[t.x],[t.y]</b>.[kanonier_msg]</span>"
			valid_coordinates["[t.x],[t.y]"] = TRUE
	else
		return ..()

//OTHER
