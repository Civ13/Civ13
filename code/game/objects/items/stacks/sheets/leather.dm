/obj/item/stack/material/animalhide/human
	name = "human skin"
	desc = "The by-product of human farming."
	singular_name = "human skin piece"
	icon_state = "sheet-hide"
	flammable = TRUE
	value = 0
/obj/item/stack/material/animalhide/cat
	name = "cat hide"
	desc = "The by-product of cat farming."
	singular_name = "cat hide piece"
	icon_state = "sheet-cat"
	flammable = TRUE
	value = 0
/obj/item/stack/material/animalhide/monkey
	name = "monkey hide"
	desc = "The by-product of monkey farming."
	singular_name = "monkey hide piece"
	icon_state = "sheet-monkey"
	flammable = TRUE
	value = 0
/obj/item/stack/material/hairlesshide
	name = "hairless hide"
	desc = "This hide was stripped of it's hair, but still needs tanning."
	singular_name = "hairless hide piece"
	icon_state = "sheet-hairlesshide"
	flammable = TRUE
	value = 0
/obj/item/stack/material/wetleather
	name = "wet leather"
	desc = "This leather has been cleaned but still needs to be dried."
	singular_name = "wet leather piece"
	icon_state = "sheet-wetleather"
	value = 0
	var/wetness = 30 //Reduced when exposed to high temperautres
	var/drying_threshold_temperature = 500 //Kelvin to start drying
	flammable = TRUE
//Step one - dehairing.
/obj/item/stack/material/animalhide/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(	istype(W, /obj/item/weapon/material/knife) || \
		istype(W, /obj/item/weapon/material/kitchen/utensil/knife) || \
		istype(W, /obj/item/weapon/material/hatchet) )

		//visible message on mobs is defined as visible_message(var/message, var/self_message, var/blind_message)
		usr.visible_message("<span class='notice'>\The [usr] starts cutting hair off \the [src]</span>", "<span class='notice'>You start cutting the hair off \the [src]</span>", "You hear the sound of a knife rubbing against flesh")
		if(do_after(user,50))
			usr << "<span class='notice'>You cut the hair from this [singular_name]</span>"
			//Try locating an exisitng stack on the tile and add to there if possible
			for(var/obj/item/stack/material/hairlesshide/HS in usr.loc)
				if(HS.amount < 50)
					HS.amount++
					use(1)
					break
			//If it gets to here it means it did not find a suitable stack on the tile.
			var/obj/item/stack/material/hairlesshide/HS = new(usr.loc)
			HS.amount = TRUE
			use(1)
	else
		..()


//Step two - washing..... it's actually in washing machine code.

//Step three - drying
/obj/item/stack/material/wetleather/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	..()
	if(exposed_temperature >= drying_threshold_temperature)
		wetness--
		if(wetness == FALSE)
			//Try locating an exisitng stack on the tile and add to there if possible
			for(var/obj/item/stack/material/leather/HS in loc)
				if(HS.amount < 50)
					HS.amount++
					use(1)
					wetness = initial(wetness)
					break
			//If it gets to here it means it did not find a suitable stack on the tile.
			var/obj/item/stack/material/leather/HS = new(loc)
			HS.amount = TRUE
			wetness = initial(wetness)
			use(1)
