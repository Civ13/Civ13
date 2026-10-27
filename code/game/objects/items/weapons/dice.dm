/obj/item/weapon/dice
	name = "d6"
	desc = "A dice with six sides."
	icon = 'icons/obj/dice.dmi'
	icon_state = "d66"
	w_class = ITEM_SIZE_TINY
	var/sides = 6
	attack_verb = list("diced")
	flags = FALSE

/obj/item/weapon/dice/New()
	icon_state = "[name][rand(1,sides)]"

/obj/item/weapon/dice/d20
	name = "d20"
	desc = "A dice with twenty sides. The prefered dice to throw at the GM."
	icon_state = "d20"
	sides = 20

/obj/item/weapon/dice/attack_self(mob/user as mob)
	var/result = rand(1, sides)
	var/comment = ""
	if (sides == 20 && result == 20)
		comment = "Nat 20!"
	if (sides == 12 && result == 12)
		comment = "Good roll!"
	if (sides == 10 && result == 10)
		comment = "Great roll!"
	if (sides == 8 && result == 8)
		comment = "Good roll!"
	if (sides == 6 && result == 6)
		comment = "Fine roll!"
	if (sides == 4 && result == 4)
		comment = "Nice roll!"
	if (sides == 2 && result == 2)
		comment = "Nice filp!"
	if (sides == 10 && (initial(icon_state) == "d00") && result == 1)
		comment = "Bad luck, maybe..."
	else if (result == 1 && (initial(icon_state) != "d00"))
		comment = "Ouch, snake eye."
	icon_state = "[name][result]"
	if(initial(icon_state) == "d00")
		result = (result - 1)*10
	user.visible_message("<span class='notice'>[user] has thrown [src]. It lands on [result]. [comment]</span>", \
						 "<span class='notice'>You throw [src]. It lands on [result]. [comment]</span>", \
						 "<span class='notice'>You hear [src] landing on [result]. [comment]</span>")

/obj/item/weapon/dice/d2
	name = "d2"
	desc = "A die with two sides. Coins are undignified!"
	icon_state = "d2"
	sides = 2

/obj/item/weapon/dice/d4
	name = "d4"
	desc = "A dice with four sides. Nerd caltrop."
	icon_state = "d4"
	sides = 4

/obj/item/weapon/dice/d8
	name = "d8"
	desc = "A dice with eight sides. The prefered dice to throw at the enemy."
	icon_state = "d8"
	sides = 8

obj/item/weapon/dice/d10
	name = "d10"
	desc = "A die with ten sides. Useful for percentages."
	icon_state = "d10"
	sides = 10

/obj/item/weapon/dice/d00
	name = "d00"
	desc = "A die with ten sides. Works better for d100 rolls than a golfball."
	icon_state = "d00"
	sides = 10

/obj/item/weapon/dice/d12
	name = "d12"
	desc = "A die with twelve sides. There's an air of neglect about it."
	icon_state = "d12"
	sides = 12

/obj/item/weapon/storage/pill_bottle/dice
	name = "bag of dice"
	desc = "It's a small container with dice inside."
	icon = 'icons/obj/dice.dmi'
	icon_state = "dicebag"

	New()
		..()
		new /obj/item/weapon/dice/d2( src )
		new /obj/item/weapon/dice/d4( src )
		new /obj/item/weapon/dice( src )
		new /obj/item/weapon/dice/d8( src )
		new /obj/item/weapon/dice/d10( src )
		new /obj/item/weapon/dice/d00( src )
		new /obj/item/weapon/dice/d12( src )
		new /obj/item/weapon/dice/d20( src )