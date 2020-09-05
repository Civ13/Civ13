/obj/item/clothing/under/flamengo
	name = "flamengo shirt with yellow shorts"
	desc = "A C.R. Flamengo football shirt, with yellow swimming trunks."
	icon_state = "flamengo"
	item_state = "flamengo"
	worn_state = "flamengo"

/obj/item/clothing/under/football_red
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"

/obj/item/clothing/under/football_blue
	name = "Chad Town jersey"
	desc = "A football jersey of the Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue"
	item_state = "football_blue"
	worn_state = "football_blue"

/obj/item/clothing/shoes/football
	name = "football trainers"
	desc = "A pair of football trainers."
	icon_state = "football"
	item_state = "football"
	worn_state = "football"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 60, arrow = 5, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = 0.6

/mob/living/human/var/obj/item/football/football = null

/obj/item/football
	name = "football"
	desc = "A classic black and white football."
	icon = 'icons/obj/football.dmi'
	icon_state = "football"
	force = 0.0
	throwforce = 0.0
	throw_speed = 4
	throw_range = 7
	item_state = "football"
	w_class = 4.0
	layer = 6
	opacity = FALSE
	density = TRUE
	allow_spin = FALSE

	var/mob/living/human/owner = null

/obj/item/football/proc/update_movement()
	if (owner)
		src.dir = owner.dir
		src.forceMove(owner.loc)
	return