/obj/item/clothing/accessory/armband
	name = "red armband"
	desc = "A fancy red armband!"
	icon_state = "red"
	slot = "armband"

/obj/item/clothing/accessory/armband/get_mob_overlay()
	if (!mob_overlay)
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		if (icon_override)
			if ("[tmp_icon_state]_mob" in icon_states(icon_override))
				tmp_icon_state = "[tmp_icon_state]_mob"
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]", layer = 5)
		else
			mob_overlay = image("icon" = INV_ACCESSORIES_DEF_ICON, "icon_state" = "[tmp_icon_state]", layer = 5)
	return mob_overlay

/obj/item/clothing/accessory/armband/cargo
	name = "cargo armband"
	desc = "An armband, worn by the crew to display which department they're assigned to. This one is brown."
	icon_state = "cargo"

/obj/item/clothing/accessory/armband/engine
	name = "engineering armband"
	desc = "An armband, worn by the crew to display which department they're assigned to. This one is orange with a reflective strip!"
	icon_state = "engie"

/obj/item/clothing/accessory/armband/science
	name = "science armband"
	desc = "An armband, worn by the crew to display which department they're assigned to. This one is purple."
	icon_state = "rnd"

/obj/item/clothing/accessory/armband/hydro
	name = "hydroponics armband"
	desc = "An armband, worn by the crew to display which department they're assigned to. This one is green and blue."
	icon_state = "hydro"

/obj/item/clothing/accessory/armband/med
	name = "medical armband"
	desc = "An armband, worn by the crew to display which department they're assigned to. This one is white."
	icon_state = "med"

/obj/item/clothing/accessory/armband/medgreen
	name = "EMT armband"
	desc = "An armband, worn by the crew to display which department they're assigned to. This one is white and green."
	icon_state = "medgreen"

/obj/item/clothing/accessory/armband/nsdap
	name = "nsdap armband"
	desc = "Sieg heil!"
	icon_state = "nsdap"


/obj/item/clothing/accessory/armband/japanesemp
	name = "Kenpeitai armband"
	desc = "An armband of the Kenpeitai, the Japanese military police."
	icon_state = "japanesemp"

/obj/item/clothing/accessory/armband/usmp
	name = "US MP armband"
	desc = "An armband of the US Army Military Police force."
	icon_state = "usmp"

// prisoner stuff
/obj/item/clothing/accessory/armband/med_pris
	name = "medical armband"
	desc = "An armband, worn by prisoners to indicate what job they were assigned."
	icon_state = "med"

/obj/item/clothing/accessory/armband/col_pris
	name = "collaborator armband"
	desc = "An armband, worn by prisoners to indicate what job they were assigned."
	icon_state = "engie"

/obj/item/clothing/accessory/armband/min_pris
	name = "miner armband"
	desc = "An armband, worn by prisoners to indicate what job they were assigned."
	icon_state = "cargo"

/obj/item/clothing/accessory/armband/jan_pris
	name = "janitor armband"
	desc = "An armband, worn by prisoners to indicate what job they were assigned."
	icon_state = "rnd"

/obj/item/clothing/accessory/armband/chef_pris
	name = "kitchen armband"
	desc = "An armband, worn by prisoners to indicate what job they were assigned."
	icon_state = "hydro"

/obj/item/clothing/accessory/armband/volkssturm
	name = "Volkssturm armband"
	desc = "An armband, worn by the concripted into the Volkssturm."
	icon_state = "volkssturm"

/obj/item/clothing/accessory/armband/penal_ger
	name = "Strafbattalion armband"
	desc = "A white armband with a red triangle worn by a german penal unit. Identifies the scum of the Wehrmacht."
	icon_state = "penal"

/obj/item/clothing/accessory/armband/penal_sov
	name = "Shtrafbat armband"
	desc = "A white armband with a red triangle, worn by a soviet penal unit. Identifies the scum of the Red Army."
	icon_state = "penal"

/obj/item/clothing/accessory/armband/fjk
	name = "Feldjägerkorps armband"
	desc = "A red armband with 'Oberkommando der Wehrmacht - Feldjäger' written on it."
	icon_state = "fjk"

/obj/item/clothing/accessory/armband/partisan
	name = "partisan armband"
	desc = "A white armband, worn by partisans to identify themselves."
	icon_state = "med"

/obj/item/clothing/accessory/armband/redcross
	name = "Red Cross armband"
	desc = "An armband, worn by members of the Red Cross Organization."
	icon_state = "redcross"
