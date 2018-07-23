/obj/item/flashlight/lantern
	name = "lantern"
	icon_state = "lantern"
	desc = "A simple lantern."
	brightness_on = 4			// luminosity when on
	light_color = rgb(200, 255, 200) // green tint
	on_state = "lantern-on"
	off_state = "lantern"

/obj/item/flashlight/lantern/on
	icon_state = "lantern-on"
	brightness_on = 4			// luminosity when on
	light_color = rgb(200, 255, 200) // green tint~
	on = TRUE

/obj/item/flashlight/lantern/anchored
	on_state = "lantern-on_a"
	off_state = "lantern_a"
	icon_state = "lantern_a"
	anchored = TRUE

/obj/item/flashlight/lantern/on/anchored
	on_state = "lantern-on_a"
	off_state = "lantern_a"
	icon_state = "lantern-on_a"
	anchored = TRUE
