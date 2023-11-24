/obj/effect/decal/cleanable/generic
	name = "clutter"
	desc = "Someone should clean that up."
	gender = PLURAL
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/obj/objects.dmi'
	icon_state = "shards"

/obj/effect/decal/cleanable/ash
	name = "ashes"
	desc = "Ashes to ashes, dust to dust."
	gender = PLURAL
	icon = 'icons/obj/objects.dmi'
	icon_state = "ash"
	anchored = TRUE
	decay_timer = 16000
	New()
		..()
		pixel_x = rand(-8, 8)
		pixel_y = rand(-8, 8)

/obj/effect/decal/cleanable/ash/attackby(obj/item/weapon/reagent_containers/glass/C as obj, mob/user as  mob )
	if (istype(C))
		C.reagents.add_reagent("ash", 1)
		to_chat(user, "You collect ash into the [C.name].")
		qdel(src)
		return

/obj/effect/decal/cleanable/ash/attack_hand(mob/user as mob)
	to_chat(user, SPAN_NOTICE("[src] sifts through your fingers."))
	var/turf/floor/F = get_turf(src)
	if (istype(F))
		F.dirt += 4
	qdel(src)

/obj/effect/decal/cleanable/dirt
	name = "dirt"
	desc = "Someone should clean that up."
	gender = PLURAL
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/effects.dmi'
	icon_state = "dirt"
	mouse_opacity = FALSE

/obj/effect/decal/cleanable/flour
	name = "flour"
	desc = "It's still good. Four second rule!"
	gender = PLURAL
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/effects.dmi'
	icon_state = "flour"
	decay_timer = 18000

/obj/effect/decal/cleanable/greenglow
	name = "glowing goo"
	desc = "Jeez. I hope that's not for lunch."
	gender = PLURAL
	density = FALSE
	anchored = TRUE
	layer = 2
	light_range = TRUE
	icon = 'icons/effects/effects.dmi'
	icon_state = "greenglow"

	decay_timer = 1200

/obj/effect/decal/cleanable/foam
	name = "foam"
	desc = "White foam from a fire extinguisher."
	gender = PLURAL
	density = FALSE
	anchored = TRUE
	layer = 2
	light_range = TRUE
	icon = 'icons/effects/effects.dmi'
	icon_state = "foam"

	decay_timer = 300


/obj/effect/decal/cleanable/cobweb
	name = "cobweb"
	desc = "Somebody should remove that."
	density = FALSE
	anchored = TRUE
	layer = 3
	icon = 'icons/effects/effects.dmi'
	icon_state = "cobweb1"

/obj/effect/decal/cleanable/molten_item
	name = "gooey grey mass"
	desc = "It looks like a melted... something."
	density = FALSE
	anchored = TRUE
	layer = 3
	icon = 'icons/obj/chemical.dmi'
	icon_state = "molten"
	decay_timer = 18000

/obj/effect/decal/cleanable/cobweb2
	name = "cobweb"
	desc = "Somebody should remove that."
	density = FALSE
	anchored = TRUE
	layer = 3
	icon = 'icons/effects/effects.dmi'
	icon_state = "cobweb2"

//Vomit (sorry)
/obj/effect/decal/cleanable/vomit
	name = "vomit"
	desc = "Gosh, how unpleasant."
	gender = PLURAL
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/blood.dmi'
	icon_state = "vomit_1"
	random_icon_states = list("vomit_1", "vomit_2", "vomit_3", "vomit_4")
	decay_timer = 18000

	Destroy()
		..()

/obj/effect/decal/cleanable/vomit/bloody
	name = "bloody vomit"
	icon_state = "vomit_b1"
	random_icon_states = list("vomit_b1", "vomit_b2", "vomit_b3", "vomit_b4")

	Destroy()
		..()
/obj/effect/decal/cleanable/tomato_smudge
	name = "tomato smudge"
	desc = "It's red."
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/tomatodecal.dmi'
	random_icon_states = list("tomato_floor1", "tomato_floor2", "tomato_floor3")
	decay_timer = 18000

/obj/effect/decal/cleanable/egg_smudge
	name = "smashed egg"
	desc = "Seems like this one won't hatch."
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/tomatodecal.dmi'
	random_icon_states = list("smashed_egg1", "smashed_egg2", "smashed_egg3")
	decay_timer = 12000

/obj/effect/decal/cleanable/pie_smudge //honk
	name = "smashed pie"
	desc = "It's pie cream from a cream pie."
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/tomatodecal.dmi'
	random_icon_states = list("smashed_pie")
	decay_timer = 18000

/obj/effect/decal/cleanable/fruit_smudge
	name = "smudge"
	desc = "Some kind of fruit smear."
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/blood.dmi'
	icon_state = "mfloor1"
	random_icon_states = list("mfloor1", "mfloor2", "mfloor3", "mfloor4", "mfloor5", "mfloor6", "mfloor7")
	decay_timer = 18000