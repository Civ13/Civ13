
/obj/item/weapon/soap
	name = "soap"
	desc = "A cheap bar of soap. Doesn't smell."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "soap"
	w_class = ITEM_SIZE_SMALL
	throwforce = FALSE
	throw_speed = 4
	throw_range = 20
	var/used = 0 //Times it have been used
	var/mood_boost_wait = 9000 //Around 15 minutes
	var/washing = FALSE
	flags = FALSE

/obj/item/weapon/soap/deluxe
	icon_state = "soapdeluxe"

/obj/item/weapon/soap/deluxe/New()
	desc = "A deluxe brand bar of soap. Smells of [pick("lavender", "vanilla", "strawberry")]."
	..()

/obj/item/weapon/soap/New()
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)
	..()

/obj/item/weapon/soap/lard
	name = "lard soap"
	desc = "A bit stinky and oily poorly shaped lard soap."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "soap_lard_1"
	w_class = ITEM_SIZE_SMALL
	throwforce = FALSE
	throw_speed = 4
	throw_range = 20

/mob/living/human
	var/soap_cooldown = 0 //Used to stop abuse from the mood boost that the soap gives

//Cleaning with soap routines
/mob/living/human/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/soap))
		var/obj/item/weapon/soap/S = W
		if( src.is_nude())
			var/keep_going = FALSE
			var/turf/T = get_turf(src)
			if(istype(user.loc, /turf/floor/beach/water))
				keep_going = TRUE
			else if(locate(/obj/structure/shower) in T.contents)
				for (var/obj/A in T.contents) //Checking if the shower is on(bathtub open or shower on)
					if(istype(A, /obj/structure/shower))
						var/obj/structure/shower/Y = A
						if(Y.on)
							keep_going = TRUE
						else keep_going = FALSE
						break
			else if(locate(/obj/structure/sink) in T.contents)
				keep_going = TRUE
			else
				keep_going = FALSE

			if(keep_going)
				if(S.washing) //No spam
					return
				if(src == user)
					user.visible_message("<span class='notice'>[user] starts to wash himself with \the [W.name]</span>", "<span class = 'notice'>You start to wash yourself with \the [W.name].</span>")
				else
					user.visible_message("<span class='notice'>[user] start to wash [src.name] with \the [W.name]</span>", "<span class = 'notice'>You start to wash [src.name] with \the [W.name].</span>")
				S.washing = TRUE
				src.hygiene = HYGIENE_LEVEL_CLEAN //Very clean
				if(do_after(user, 40))
					src.hygiene = HYGIENE_LEVEL_CLEAN //Very clean
					S.washing = FALSE
					S.used += 1
					if(S.used >= 30) //Delete the soap if its used to it's maximum
						qdel(S)
					else
						S.update_icon()
					if((world.time - src.soap_cooldown >= S.mood_boost_wait) || !soap_cooldown)
						src.mood += 10 //Same mood boost as eating a delicious food
						src << "You really enjoy bathing with the [W.name]. You feel much better!"
						src.soap_cooldown = world.time
					else
						src << "You dont really enjoy bathing with the [W.name], you did that not long ago."
				else
					S.washing = FALSE //Moved before finishing the do_after
			else
				return
	else
		return ..()

/obj/item/weapon/soap/lard/update_icon()
	var/i
	if(used < 5)
		i = 1
	else if(used < 15)
		i = 2
	else if(used < 25)
		i = 3
	else i = 4
	icon_state = "soap_lard_[i]"