/obj/item/clothing/gloves
	heat_protection = HANDS


// COLOR GLOVES
/obj/item/clothing/gloves/color
	name = "gloves"
	initial_name = "gloves"
	desc = "A pair of gloves, they don't look special in any way."
	icon_state = "latex"
	item_state = "latex"

/obj/item/clothing/gloves/color/white
	name = "white gloves"
	desc = "These look pretty fancy."
	icon_state = "latex"
	item_state = "latex"

/obj/item/clothing/gloves/watch
	name = "time gloves"
	desc = "Hypothetical time gloves. Works like a watch. If you find these tell an admin"

/obj/item/clothing/gloves/watch/examine(mob/user)
	..()
	user << "<big>It is now [clock_time()].</big>"
/obj/item/clothing/gloves/watch/watch
	name = "watch"
	desc = "A watch you wear on your hand."
	icon_state = "watch"
	item_state = "watch"
	fingerprint_chance = 100

/obj/item/clothing/gloves/watch/specialwatch
	name = "expensive watch"
	desc = "A watch you wear on your hand. Looks quite expensive."
	icon_state = "specialwatch"
	item_state = "watch"
	fingerprint_chance = 100

/obj/item/clothing/gloves/watch/goldwatch
	name = "gold watch"
	desc = "A watch you wear on your hand. This one is plated in gold."
	icon_state = "goldwatch"
	item_state = "watch"
	fingerprint_chance = 100

/obj/item/clothing/gloves/color/yellow
	name = "yellow gloves"
	initial_name = "yellow gloves"
	desc = "A pair of gloves, they don't look special in any way, but seems familiar."
	icon_state = "yellow"
	item_state = "ygloves"

/obj/item/clothing/gloves/color/orange
	name = "orange gloves"
	initial_name = "orange gloves"
	icon_state = "orange"
	item_state = "orangegloves"

/obj/item/clothing/gloves/color/red
	name = "red gloves"
	initial_name = "red gloves"
	icon_state = "red"
	item_state = "redgloves"

/obj/item/clothing/gloves/color/blue
	name = "blue gloves"
	initial_name = "blue gloves"
	icon_state = "blue"
	item_state = "bluegloves"

/obj/item/clothing/gloves/color/purple
	name = "purple gloves"
	initial_name = "purple gloves"
	icon_state = "purple"
	item_state = "purplegloves"

/obj/item/clothing/gloves/color/green
	name = "green gloves"
	initial_name = "green gloves"
	icon_state = "green"
	item_state = "greengloves"

/obj/item/clothing/gloves/color/grey
	name = "grey gloves"
	initial_name = "grey gloves"
	icon_state = "gray"
	item_state = "graygloves"

/obj/item/clothing/gloves/color/light_brown
	name = "light brown gloves"
	initial_name = "light brown gloves"
	icon_state = "lightbrown"
	item_state = "lightbrowngloves"

/obj/item/clothing/gloves/color/brown
	name = "brown gloves"
	initial_name = "brown gloves"
	icon_state = "brown"
	item_state = "browngloves"

/obj/item/clothing/gloves/color/luxglove
	name = "red leather gloves"
	initial_name = "red leather gloves"
	desc = "A pair of gloves, They look fancy and expensive."
	icon_state = "luxglove"
	item_state = "luxglove"

/obj/item/clothing/gloves/color/luxglovepurple
	name = "pink colored gloves"
	initial_name = "red leather gloves"
	desc = "A pair of gloves, They look fancy."
	icon_state = "luxglove1"
	item_state = "luxglove1"

/obj/item/clothing/gloves/rings/silver
	name = "silver ring"
	initial_name = "silver ring"
	desc = "A shiny silver ring. Looks expensive."
	icon_state = "silver_ring"
	item_state = "silver_ring"
	fingerprint_chance = 100
