/obj/structure/boiling_oil
	name = "boiling oil pot"
	icon = 'icons/obj/kitchen.dmi'
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "oil_pot0"
	anchored = TRUE
	var/direction = SOUTH
	var/timer = 0
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/boiling_oil/attack_hand(var/mob/user as mob)
	if (timer == 2)
		visible_message("[user] empties the [name] over the wall!")
		splash()
		return
	..()

obj/structure/boiling_oil/New()
	..()
	dir = direction

obj/structure/boiling_oil/proc/boil()
	if (timer == 1)
		spawn(500)
			timer = 2
			icon_state = "oil_pot2"
			visible_message("The oil pot is now boiling!")
			return

obj/structure/boiling_oil/proc/splash()
	timer = 0
	icon_state = "oil_pot3"
	spawn(18)
		icon_state = "oil_pot0"
	spawn(8)
		if (direction == SOUTH)
			for (var/mob/living/LS1 in locate(x-1,y-1,z))
				LS1.adjustFireLoss(35)
				LS1.fire_stacks += rand(2,3)
				LS1.IgniteMob()
			new/obj/effect/oil(locate(x-1,y-1,z))
			for (var/mob/living/LS2 in locate(x,y-1,z))
				LS2.adjustFireLoss(35)
				LS2.fire_stacks += rand(2,3)
				LS2.IgniteMob()
			new/obj/effect/oil(locate(x,y-1,z))
			for (var/mob/living/LS3 in locate(x+1,y-1,z))
				LS3.adjustFireLoss(35)
				LS3.fire_stacks += rand(2,3)
				LS3.IgniteMob()
			new/obj/effect/oil(locate(x+1,y-1,z))
			for (var/mob/living/LS4 in locate(x-1,y-2,z))
				LS4.adjustFireLoss(18)
				LS4.fire_stacks += rand(1,2)
				if (prob(45))
					LS4.IgniteMob()
			new/obj/effect/oil(locate(x-1,y-2,z))
			for (var/mob/living/LS5 in locate(x,y-2,z))
				LS5.adjustFireLoss(18)
				LS5.fire_stacks += rand(1,2)
				if (prob(45))
					LS5.IgniteMob()
			new/obj/effect/oil(locate(x,y-2,z))
			for (var/mob/living/LS6 in locate(x+1,y-2,z))
				LS6.adjustFireLoss(18)
				LS6.fire_stacks += rand(1,2)
				if (prob(45))
					LS6.IgniteMob()
			new/obj/effect/oil(locate(x+1,y-2,z))
			return
		else if (direction == NORTH)
			for (var/mob/living/LN1 in locate(x-1,y+1,z))
				LN1.adjustFireLoss(35)
				LN1.fire_stacks += rand(2,3)
				LN1.IgniteMob()
			new/obj/effect/oil(locate(x-1,y+1,z))
			for (var/mob/living/LN2 in locate(x,y+1,z))
				LN2.adjustFireLoss(35)
				LN2.fire_stacks += rand(2,3)
				LN2.IgniteMob()
			new/obj/effect/oil(locate(x,y+1,z))
			for (var/mob/living/LN3 in locate(x+1,y+1,z))
				LN3.adjustFireLoss(35)
				LN3.fire_stacks += rand(2,3)
				LN3.IgniteMob()
			new/obj/effect/oil(locate(x+1,y+1,z))
			for (var/mob/living/LN4 in locate(x-1,y+2,z))
				LN4.adjustFireLoss(18)
				LN4.fire_stacks += rand(1,2)
				if (prob(45))
					LN4.IgniteMob()
			new/obj/effect/oil(locate(x-1,y+2,z))
			for (var/mob/living/LN5 in locate(x,y+2,z))
				LN5.adjustFireLoss(18)
				LN5.fire_stacks += rand(1,2)
				if (prob(45))
					LN5.IgniteMob()
			new/obj/effect/oil(locate(x,y+2,z))
			for (var/mob/living/LN6 in locate(x+1,y+2,z))
				LN6.adjustFireLoss(18)
				LN6.fire_stacks += rand(1,2)
				if (prob(45))
					LN6.IgniteMob()
			new/obj/effect/oil(locate(x+1,y+2,z))
			return
		else if (direction == EAST)
			for (var/mob/living/LE1 in locate(x+1,y-1,z))
				LE1.adjustFireLoss(35)
				LE1.fire_stacks += rand(2,3)
				LE1.IgniteMob()
			new/obj/effect/oil(locate(x+1,y-1,z))
			for (var/mob/living/LE2 in locate(x+1,y,z))
				LE2.adjustFireLoss(35)
				LE2.fire_stacks += rand(2,3)
				LE2.IgniteMob()
			new/obj/effect/oil(locate(x+1,y,z))
			for (var/mob/living/LE3 in locate(x+1,y+1,z))
				LE3.adjustFireLoss(35)
				LE3.fire_stacks += rand(2,3)
				LE3.IgniteMob()
			new/obj/effect/oil(locate(x+1,y+1,z))
			for (var/mob/living/LE4 in locate(x+2,y-1,z))
				LE4.adjustFireLoss(18)
				LE4.fire_stacks += rand(1,2)
				if (prob(45))
					LE4.IgniteMob()
			new/obj/effect/oil(locate(x+2,y-1,z))
			for (var/mob/living/LE5 in locate(x+2,y,z))
				LE5.adjustFireLoss(18)
				LE5.fire_stacks += rand(1,2)
				if (prob(45))
					LE5.IgniteMob()
			new/obj/effect/oil(locate(x+2,y,z))
			for (var/mob/living/LE6 in locate(x+2,y+1,z))
				LE6.adjustFireLoss(18)
				LE6.fire_stacks += rand(1,2)
				if (prob(45))
					LE6.IgniteMob()
			new/obj/effect/oil(locate(x+2,y+1,z))
			return
		else if (direction == WEST)
			for (var/mob/living/LW1 in locate(x-1,y-1,z))
				LW1.adjustFireLoss(35)
				LW1.fire_stacks += rand(2,3)
				LW1.IgniteMob()
			new/obj/effect/oil(locate(x-1,y-1,z))
			for (var/mob/living/LW2 in locate(x-1,y,z))
				LW2.adjustFireLoss(35)
				LW2.fire_stacks += rand(2,3)
				LW2.IgniteMob()
			new/obj/effect/oil(locate(x-1,y,z))
			for (var/mob/living/LW3 in locate(x-1,y+1,z))
				LW3.adjustFireLoss(35)
				LW3.fire_stacks += rand(2,3)
				LW3.IgniteMob()
			new/obj/effect/oil(locate(x-1,y+1,z))
			for (var/mob/living/LW4 in locate(x-2,y-1,z))
				LW4.adjustFireLoss(18)
				LW4.fire_stacks += rand(1,2)
				if (prob(45))
					LW4.IgniteMob()
			new/obj/effect/oil(locate(x-2,y-1,z))
			for (var/mob/living/LW5 in locate(x-2,y,z))
				LW5.adjustFireLoss(18)
				LW5.fire_stacks += rand(1,2)
				if (prob(45))
					LW5.IgniteMob()
			new/obj/effect/oil(locate(x-2,y,z))
			for (var/mob/living/LW6 in locate(x-2,y+1,z))
				LW6.adjustFireLoss(18)
				LW6.fire_stacks += rand(1,2)
				if (prob(45))
					LW6.IgniteMob()
			new/obj/effect/oil(locate(x-2,y+1,z))
			return

obj/structure/boiling_oil/attackby(obj/item/weapon/oilbarrel/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		if (W.reagents.has_reagent("olive_oil", 50))
			W.reagents.remove_reagent("olive_oil", 50)
			timer = 1
			visible_message("[user] fills the pot with oil and starts heating it!")
			icon_state = "oil_pot1"
			boil()
			return
		else
			user << "This barrel has no olive oil inside!"
			return

	if (istype(W, /obj/item/weapon/oilbarrel))
		if (W.full > 0 && timer == 0)
			W.full -= 1
			timer = 1
			visible_message("[user] fills the pot with oil and starts heating it!")
			icon_state = "oil_pot1"
			boil()
			return
		else if (timer > 0)
			user << "The pot is already filled!"
			return
		else if (W.full <= 0)
			user << "This barrel is empty!"
			W.name = "empty olive oil barrel"
			return
	else
		..()

/obj/item/weapon/oilbarrel
	name = "olive oil barrel"
	desc = "A barrel of olive oil."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	density = TRUE
	var/full = 3
	flammable = TRUE
obj/structure/boiling_oil/west
	..()
	direction = WEST
obj/structure/boiling_oil/east
	..()
	direction = EAST
obj/structure/boiling_oil/north
	..()
	direction = NORTH
obj/structure/boiling_oil/south
	..()
	direction = SOUTH

/obj/effect/oil
	icon = 'icons/effects/effects.dmi'
	icon_state = "foam-dissolve"
	layer = TURF_LAYER+2.2
	anchored = TRUE
	density = FALSE

/obj/effect/oil/New()
	..()
	icon = 'icons/effects/effects.dmi'
	icon_state = "foam-dissolve"
	spawn(110)
		qdel(src)