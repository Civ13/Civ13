////////////////////////////////////////////////////////////////////////////////
/// Drinks.
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/drinks
	name = "drink"
	desc = "yummy"
	icon = 'icons/obj/drinks.dmi'
	icon_state = null
	flags = OPENCONTAINER
	amount_per_transfer_from_this = 5
	volume = 50
	var/label_text = ""
	var/base_name = " "

	on_reagent_change()
		return

	attack_self(mob/user as mob)
		if (!is_open_container())
			open(user)

	proc/open(mob/user)
		playsound(loc,'sound/effects/canopen.ogg', rand(10,50), TRUE)
		user << "<span class='notice'>You open [src] with an audible pop!</span>"
		flags |= OPENCONTAINER

	attack(mob/M as mob, mob/user as mob, def_zone)
		if (force && !(flags & NOBLUDGEON) && user.a_intent == I_HARM)
			return ..()
		if (istype(M) && standard_feed_mob(user, M))
			return TRUE
		return FALSE

	afterattack(obj/target, mob/user, proximity)
		if (!proximity) return

		if (istype(target, /obj/structure/pot))
			return

		if (standard_dispenser_refill(user, target))
			return
		if (standard_pour_into(user, target))
			return

		return ..()
	attackby(obj/item/weapon/W as obj, mob/user as mob)
		if (istype(W, /obj/item/weapon/pen))
			var/tmp_label = sanitizeSafe(input(user, "Enter a label for [name]", "Label", label_text), MAX_NAME_LEN)
			if (length(tmp_label) > 15)
				user << "<span class='notice'>The label can be at most 15 characters long.</span>"
			else
				user << "<span class='notice'>You set the label to \"[tmp_label]\".</span>"
				label_text = tmp_label
				update_name_label()
		else
			..()

	proc/update_name_label()
		playsound(src,'sound/effects/pen.ogg',40,1)
		if (label_text == "")
			name = base_name
		else
			name = "[base_name] ([label_text])"

	standard_feed_mob(var/mob/user, var/mob/target)
		if (!is_open_container())
			if (istype(target))
				user << "<span class='notice'>You need to open [src]!</span>"
			return TRUE
		return ..()

	standard_dispenser_refill(var/mob/user, var/obj/structure/reagent_dispensers/target)
		if (!is_open_container())
			if (istype(target))
				user << "<span class='notice'>You need to open [src]!</span>"
			return TRUE
		return ..()

	standard_pour_into(var/mob/user, var/atom/target)
		if (!is_open_container())
			if (istype(target) && !istype(target, /obj/structure/table)) // setting on a table
				user << "<span class='notice'>You need to open [src]!</span>"
			return TRUE
		return ..()

	self_feed_message(var/mob/user)
		user << "<span class='notice'>You swallow a gulp from \the [src].</span>"

	feed_sound(var/mob/user)
		playsound(user.loc, "drink", rand(10, 50), TRUE)

	examine(mob/user)
		if (!..(user, TRUE))
			return
		if (!reagents || reagents.total_volume == FALSE)
			user << "<span class='notice'>\The [src] is empty!</span>"
		else if (reagents.total_volume <= volume * 0.25)
			user << "<span class='notice'>\The [src] is almost empty!</span>"
		else if (reagents.total_volume <= volume * 0.66)
			user << "<span class='notice'>\The [src] is half full!</span>"
		else if (reagents.total_volume <= volume * 0.90)
			user << "<span class='notice'>\The [src] is almost full!</span>"
		else
			user << "<span class='notice'>\The [src] is full!</span>"

	New()
		..()
		base_name = name
		spawn (1)
			if (reagents && !istype(src, /obj/item/weapon/reagent_containers/food/drinks/bottle))
				amount_per_transfer_from_this = max(amount_per_transfer_from_this, ceil(reagents.total_volume/5))


////////////////////////////////////////////////////////////////////////////////
/// Drinks. END
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/drinks/gunpowder
	name = "gunpowder pouch"
	desc = "A small pouch, used to carry gunpowder."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "gunpowder"
	volume = 10
	center_of_mass = list("x"=16, "y"=14)
	value = 5
	slot_flags = SLOT_ID

/obj/item/weapon/reagent_containers/food/drinks/gunpowder/full
	value = 5

	New()
		..()
		reagents.add_reagent("gunpowder", 10)

/obj/item/weapon/reagent_containers/food/drinks/golden_cup
	desc = "A golden cup"
	name = "golden cup"
	icon_state = "golden_cup"
	item_state = "" //nope :(
	w_class = ITEM_SIZE_LARGE
	force = WEAPON_FORCE_PAINFUL
	throwforce = 10
	amount_per_transfer_from_this = 20
	possible_transfer_amounts = null
	volume = 150
	flags = CONDUCT | OPENCONTAINER

///////////////////////////////////////////////Drinks
//Notes by Darem: Drinks are simply containers that start preloaded. Unlike condiments, the contents can be ingested directly
//	rather then having to add it to something else first. They should only contain liquids. They have a default container size of 50.
//	Formatting is the same as food.

/obj/item/weapon/reagent_containers/food/drinks/coffee
	name = "Coffee"
	desc = "Careful, the beverage you're about to enjoy is extremely hot."
	icon_state = "coffee"
	center_of_mass = list("x"=15, "y"=10)
	New()
		..()
		reagents.add_reagent("coffee", 30)

/obj/item/weapon/reagent_containers/food/drinks/tea
	name = "teacup"
	desc = "A teacup. Warm."
	icon_state = "teacup"
	item_state = "coffee"
	center_of_mass = list("x"=16, "y"=14)
	New()
		..()
		reagents.add_reagent("tea", 15)
/obj/item/weapon/reagent_containers/food/drinks/tea/empty
	name = "teacup"
	desc = "A teacup. Warm."
	icon_state = "teacup"
	item_state = "coffee"
	center_of_mass = list("x"=16, "y"=14)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/ice
	name = "Ice Cup"
	desc = "Careful, cold ice, do not chew."
	icon_state = "coffee"
	center_of_mass = list("x"=15, "y"=10)
	New()
		..()
		reagents.add_reagent("ice", 30)

/obj/item/weapon/reagent_containers/food/drinks/h_chocolate
	name = "Dutch Hot Coco"
	desc = "Made in South America."
	icon_state = "hot_coco"
	item_state = "coffee"
	center_of_mass = list("x"=15, "y"=13)
	New()
		..()
		reagents.add_reagent("hot_coco", 30)


/obj/item/weapon/reagent_containers/food/drinks/sillycup
	name = "Paper Cup"
	desc = "A paper water cup."
	icon_state = "water_cup_e"
	possible_transfer_amounts = null
	w_class = ITEM_SIZE_TINY
	volume = 10
	center_of_mass = list("x"=16, "y"=12)
	New()
		..()
	on_reagent_change()
		if (reagents.total_volume)
			icon_state = "water_cup"
		else
			icon_state = "water_cup_e"


//////////////////////////drinkingglass and shaker//
//Note by Darem: This code handles the mixing of drinks. New drinks go in three places: In Chemistry-Reagents.dm (for the drink
//	itself), in Chemistry-Recipes.dm (for the reaction that changes the components into the drink), and here (for the drinking glass
//	icon states.

/obj/item/weapon/reagent_containers/food/drinks/shaker
	name = "Shaker"
	desc = "A metal shaker to mix drinks in."
	icon_state = "shaker"
	amount_per_transfer_from_this = 10
	volume = 120
	center_of_mass = list("x"=17, "y"=10)

/obj/item/weapon/reagent_containers/food/drinks/teapot
	name = "teapot"
	desc = "An elegant teapot. It simply oozes class."
	icon_state = "teapot"
	item_state = "teapot"
	amount_per_transfer_from_this = 10
	volume = 120
	center_of_mass = list("x"=17, "y"=7)

/obj/item/weapon/reagent_containers/food/drinks/teapot/filled
	New()
		..()
		reagents.add_reagent("tea", 100)

/obj/item/weapon/reagent_containers/food/drinks/flask
	name = "Officer's Flask"
	desc = "A nice metal flask used by officers"
	icon_state = "flask"
	volume = 60
	center_of_mass = list("x"=17, "y"=7)

/obj/item/weapon/reagent_containers/food/drinks/flask/officer/schnapps
/obj/item/weapon/reagent_containers/food/drinks/flask/officer/schnapps/New()
	..()
	reagents.add_reagent("goldschlager", 60)

/obj/item/weapon/reagent_containers/food/drinks/flask/officer/vodka
/obj/item/weapon/reagent_containers/food/drinks/flask/officer/vodka/New()
	..()
	reagents.add_reagent("vodka", 60)

/obj/item/weapon/reagent_containers/food/drinks/flask/officer/whiskey
/obj/item/weapon/reagent_containers/food/drinks/flask/officer/whiskey/New()
	..()
	reagents.add_reagent("whiskey", 60)

/obj/item/weapon/reagent_containers/food/drinks/flask/officer/tea
/obj/item/weapon/reagent_containers/food/drinks/flask/officer/tea/New()
	..()
	reagents.add_reagent("tea", 60)

/obj/item/weapon/reagent_containers/food/drinks/flask/officer/wine
/obj/item/weapon/reagent_containers/food/drinks/flask/officer/wine/New()
	..()
	reagents.add_reagent("wine", 60)

/obj/item/weapon/reagent_containers/food/drinks/flask/shiny
	name = "shiny flask"
	desc = "A shiny metal flask. It appears to have a Greek symbol inscribed on it."
	icon_state = "shinyflask"

/obj/item/weapon/reagent_containers/food/drinks/flask/lithium
	name = "lithium flask"
	desc = "A flask with a Lithium Atom symbol on it."
	icon_state = "lithiumflask"

/obj/item/weapon/reagent_containers/food/drinks/flask/detflask
	name = "Inspector's Flask"
	desc = "A metal flask with a leather band and golden badge belonging to the inspector."
	icon_state = "detflask"
	volume = 60
	center_of_mass = list("x"=17, "y"=8)

/obj/item/weapon/reagent_containers/food/drinks/flask/barflask
	name = "flask"
	desc = "For those who can't be bothered to hang out at the bar to drink."
	icon_state = "barflask"
	volume = 60
	center_of_mass = list("x"=17, "y"=7)

/obj/item/weapon/reagent_containers/food/drinks/flask/barflask/vodka
/obj/item/weapon/reagent_containers/food/drinks/flask/barflask/vodka/New()
	..()
	reagents.add_reagent("vodka", 60)

/obj/item/weapon/reagent_containers/food/drinks/flask/vacuumflask
	name = "vacuum flask"
	desc = "Keeping your drinks at the perfect temperature since 1892."
	icon_state = "vacuumflask"
	volume = 60
	center_of_mass = list("x"=15, "y"=4)

/obj/item/weapon/reagent_containers/food/drinks/britmug
	name = "coffee mug"
	desc = "A ceramic mug with a bright ensign emblazoned on it."
	icon_state = "britcup"
	volume = 30
	center_of_mass = list("x"=15, "y"=13)

/obj/item/cocktail_stuff
	name = "snackarooni cocktailarooni"
	desc = "Something's off about this."
	icon = 'icons/obj/drinks.dmi'
	var/is_edible = FALSE
	w_class = ITEM_SIZE_TINY

/obj/item/cocktail_stuff/attack(mob/M as mob, mob/user as mob)
	if (!is_edible)
		return
	if (user == M)
		user << "<span class='notice'>You eat [src]. Yum!</span>"
		user.visible_message("<b>[user]</b> eats [src].")
	else
		M << "<span class='notice'>You eat [src]. Yum!</span>"
		user.visible_message("<span class='warning'><b>[user]</b> sticks [src] into <b>[M]</b>'s mouth.</span>")
	playsound(usr.loc,"eat", rand(20,45), TRUE)
	qdel(src)
	..()

/obj/item/cocktail_stuff/maraschino_cherry
	name = "maraschino cherry"
	desc = "A maraschino cherry, or cocktail cherry, is a preserved, artificially colored and sweetened cherry. Very common to see in many cocktails."
	icon_state = "highball-cherry"
	is_edible = TRUE

/obj/item/cocktail_stuff/cocktail_olive
	name = "cocktail olive"
	desc = "An olive on a toothpick. This has no purpose in the drink's flavor, but hey, free olives!"
	icon_state = "highball-olive"
	is_edible = TRUE

/obj/item/cocktail_stuff/celery
	name = "celery stick"
	desc = "A stick of celery. Ants not included."
	icon_state = "highball-celery"
	is_edible = TRUE
