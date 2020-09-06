/obj/item/clothing/under/football
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"
	force = 0.0
	throwforce = 0.0
	var/player_number = 0

/obj/item/clothing/under/football/flamengo
	name = "flamengo shirt with yellow shorts"
	desc = "A C.R. Flamengo football shirt, with yellow swimming trunks."
	icon_state = "flamengo"
	item_state = "flamengo"
	worn_state = "flamengo"
	player_number = 10

/obj/item/clothing/under/football/red
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"

/obj/item/clothing/under/football/red/goalkeeper
	name = "Unga Bunga goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Unga Bunga United, U.B.U."
	icon_state = "football_red_gk"
	item_state = "football_red_gk"
	worn_state = "football_red_gk"

/obj/item/clothing/under/football/blue
	name = "Chad Town jersey"
	desc = "A football jersey of the Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue"
	item_state = "football_blue"
	worn_state = "football_blue"

/obj/item/clothing/under/football/blue/goalkeeper
	name = "Chad Town goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue_gk"
	item_state = "football_blue_gk"
	worn_state = "football_blue_gk"

/obj/item/clothing/shoes/football
	name = "football trainers"
	desc = "A pair of football trainers."
	icon_state = "football"
	item_state = "football"
	worn_state = "football"
	armor = list(melee = 60, arrow = 5, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = 0.6
	force = 0.0
	throwforce = 0.0

/mob/living/human/var/obj/item/football/football = null

/obj/item/football
	name = "ball"
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
	density = FALSE
	allow_spin = FALSE

	var/mob/living/human/owner = null

/obj/item/football/proc/update_movement()
	if (owner)
		src.dir = owner.dir
		src.forceMove(owner.loc)
	return

/obj/item/football/Crossed(mob/living/human/user)
	if (!owner && !user.football)
		owner = user
		user.football = src
		return
	else
		..()

/obj/item/football/attack_hand(mob/user as mob)
	var/area/A = get_area(src)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (!istype(A, /area/caribbean/football/blue/goalkeeper) && !istype(A, /area/caribbean/football/red/goalkeeper))
			return
		else if (!(findtext(H.original_job_title, "goalkeeper")))
			return
		else
			if (owner)
				owner.football = null
				owner = null
	..()
//goal posts
/obj/effect/step_trigger/goal
	name = "goalpost"
	var/team = null
/obj/effect/step_trigger/goal/Trigger(var/atom/movable/A)
	if (istype(A, /obj/item/football) && team)
		if (istype(map, /obj/map_metadata/football))
			var/obj/map_metadata/football/MF = map
			MF.reset_ball()
			MF.scores[team] += 1
			world << "<font size=4 color='orange'>GOAL! [team] scores!</font>"
			return

/obj/effect/step_trigger/goal/red
	name = "UBU goalpost"
	team = "U.B.U."

/obj/effect/step_trigger/goal/blue
	name = "CTFC goalpost"
	team = "C.T.F.C."