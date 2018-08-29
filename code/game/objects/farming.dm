/obj/item/farming/seeds
	name = "seeds"
	desc = "Some seeds."
	icon = 'icons/farming/plants.dmi'
	icon_state = "seeds"
	w_class = 1
	var/plant = null

/obj/item/farming/seeds/tomato
	name = "tomato seeds"
	plant = "tomato"

/obj/item/farming/seeds/tobacco
	name = "tobacco seeds"
	plant = "tobacco"

/obj/item/farming/seeds/sugarcane
	name = "sugarcane seeds"
	plant = "sugarcane"

/obj/item/farming/seeds/wheat
	name = "wheat seeds"
	plant = "wheat"

/obj/item/farming/seeds/apple
	name = "apple seeds"
	plant = "apple"

/obj/item/farming/seeds/orange
	name = "orange seeds"
	plant = "orange"

/obj/item/farming/seeds/potato
	name = "seed potato"
	desc = "a potato selected for its characteristics."
	plant = "potato"
	icon_state = "potato"

/obj/item/farming/seeds/corn
	name = "corn seeds"
	plant = "corn"

/obj/structure/farming/plant
	name = "plant"
	desc = "a generic plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "tomato_grow1"
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/plant = FALSE
	var/stage = 1

/obj/structure/farming/plant/tomato
	name = "tomato plant"
	desc = "a tomato plant."
	icon_state = "tomato_grow1"
	plant = "tomato"

/obj/structure/farming/plant/corn
	name = "tomato plant"
	desc = "a tomato plant."
	icon_state = "tomato_grow1"
	plant = "tomato"

/obj/structure/farming/plant/wheat
	name = "tomato plant"
	desc = "a tomato plant."
	icon_state = "tomato_grow1"
	plant = "tomato"