/obj/item/radio/loudspeaker
	name = "base loudspeaker"
	desc = "This is where your commandant shouts at you from."
	icon_state = "loudspeaker"
	canhear_range = 7
	listening = TRUE
	broadcasting = FALSE
	layer = MOB_LAYER + 1
	anchored = TRUE

/obj/item/radio/loudspeaker/german
	frequency = DE_BASE_FREQ
	name = "german base loudspeaker"
	is_supply_radio = FALSE
	faction = GERMAN
	internal_channels = list(
	1004.0)

/obj/item/radio/loudspeaker/russian
	name = "soviet base loudspeaker"
	frequency = SO_BASE_FREQ
	is_supply_radio = FALSE
	faction = SOVIET
	internal_channels = list(
	1001.0)

/obj/item/radio/loudspeaker/interact(mob/user)
	return //It's just a loudspeaker

/obj/item/radio/loudspeaker/process()
	return //to stop icon from changing

