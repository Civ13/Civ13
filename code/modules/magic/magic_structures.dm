
/obj/structure/sign/crest
	name = "house crest"
	desc = "The crest of one of the houses."
	icon = 'icons/misc/crests.dmi'
	icon_state = ""

/obj/structure/sign/crest/mintysnek
	name = "Mintysnek crest"
	desc = "The crest of the Mintysnek house. A minty green lizard and a leek."
	icon_state = "mintysnek"

/obj/structure/sign/crest/rubywyrm
	name = "Rubywyrm crest"
	desc = "The crest of the Rubywyrm house. A welsh dragon coiled around a ruby."
	icon_state = "rubywyrm"

/obj/structure/sign/crest/slatepie
	name = "Slatepie crest"
	desc = "The crest of the Slatepie house. A magpie sitting on top of welsh slate."
	icon_state = "slatepie"

/obj/structure/sign/crest/mustardweasel
	name = "Mustardweasel crest"
	desc = "The crest of the Mustardweasel house. A ferret with a daffodil over its ear."
	icon_state = "mustardweasel"

/obj/structure/sign/house_points
	name = "L.A.M.E. House Points Board"
	desc = "A board displaying up-to-date house points for the four houses."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "house_points"

/obj/structure/sign/house_points/examine(mob/user, distance)
	if (map.ID == MAP_WIZARD_BOY)
		var/obj/map_metadata/wizard_boy/WB = map
		var/leading_house = "None"
		var/max_score = 0
		var/leading_house_color = "#FFFFFF" // Default white for "None"
		for(var/house in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")) // Iterate to find the leading house
			var/score = WB.house_points[house]
			if (score > max_score)
				max_score = score
				leading_house = house
				switch(house) // Determine color for the leading house
					if("Rubywyrm")
						leading_house_color = "#CF0000"
					if("Mintysnek")
						leading_house_color = "#00CF00"
					if("Slatepie")
						leading_house_color = "#0000CF"
					if("Mustardweasel")
						leading_house_color = "#FFD700"

		to_chat(user, "<font size=4 class='wizard'>Current Leading House: <span style='color:[leading_house_color]'><b>[leading_house]</b></span></font>")

		for(var/house in list("Rubywyrm", "Mintysnek", "Slatepie", "Mustardweasel")) // Iterate to display all house scores
			var/score = WB.house_points[house]
			if (house == "Rubywyrm")
				to_chat(user, "<font size=4 class='wizard' style='color:#CF0000'>Rubywyrm: [score]</font>")
			else if (house == "Mintysnek")
				to_chat(user, "<font size=4 class='wizard' style='color:#00CF00'>Mintysnek: [score]</font>")
			else if (house == "Slatepie")
				to_chat(user, "<font size=4 class='wizard' style='color:#0000CF'>Slatepie: [score]</font>")
			else if (house == "Mustardweasel")
				to_chat(user, "<font size=4 class='wizard' style='color:#FFD700'>Mustardweasel: [score]</font>")

	return TRUE
