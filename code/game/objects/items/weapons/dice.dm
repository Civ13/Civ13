/obj/item/weapon/dice
	name = "d6"
	desc = "A dice with six sides."
	icon = 'icons/obj/dice.dmi'
	icon_state = "d66"
	w_class = TRUE
	var/sides = 6
	attack_verb = list("diced")

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
	else if (sides == 20 && result == TRUE)
		comment = "Ouch, bad luck."
	icon_state = "[name][result]"
	user.visible_message("<span class='notice'>[user] has thrown [src]. It lands on [result]. [comment]</span>", \
						 "<span class='notice'>You throw [src]. It lands on a [result]. [comment]</span>", \
						 "<span class='notice'>You hear [src] landing on a [result]. [comment]</span>")

/obj/item/weapon/dice/d4
	name = "d4"
	desc = "A dice with four sides. The prefered dice to throw at the enemy."
	icon_state = "d4"
	sides = 4

/obj/item/weapon/dice/attack_self(mob/user as mob)
	var/result = rand(1, sides)
	var/comment = ""
	if (sides == 4 && result == 4)
		comment = "Nat 4?"
	else if (sides == 4 && result == TRUE)
		comment = "Ouch, bad luck."
	icon_state = "[name][result]"
	user.visible_message("<span class='notice'>[user] has thrown [src]. It lands on [result]. [comment]</span>", \
						 "<span class='notice'>You throw [src]. It lands on a [result]. [comment]</span>", \
						 "<span class='notice'>You hear [src] landing on a [result]. [comment]</span>")
/obj/item/weapon/dice/d8
	name = "d8"
	desc = "A dice with eight sides. The prefered dice to throw at the enemy."
	icon_state = "d8"
	sides = 8

/obj/item/weapon/dice/attack_self(mob/user as mob)
	var/result = rand(1, sides)
	var/comment = ""
	if (sides == 8 && result == 8)
		comment = "Nat 8?"
	else if (sides == 8 && result == TRUE)
		comment = "Ouch, bad luck."
	icon_state = "[name][result]"
	user.visible_message("<span class='notice'>[user] has thrown [src]. It lands on [result]. [comment]</span>", \
						 "<span class='notice'>You throw [src]. It lands on a [result]. [comment]</span>", \
						 "<span class='notice'>You hear [src] landing on a [result]. [comment]</span>")

/obj/item/storage/pill_bottle/dice
	name = "bag of dice"
	desc = "Contains all the dice you'll ever need."
	icon = 'icons/obj/dice.dmi'
	icon_state = "dicebag"
