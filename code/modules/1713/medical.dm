////////////////////////
////Pill Pack Define////
////////////////////////
/obj/item/weapon/pill_pack
	name = "pill pack"
	desc = "Pills in sterile and handy pack."
	icon = 'icons/obj/surgery.dmi'
	w_class = TRUE//Packed very effective
	icon_state = "pill_pack"
	var/pill_type = null
	var/pop_sound = 'sound/effects/pop_pill.ogg'

/obj/item/weapon/pill_pack/New()
	..()

	if (ispath(pill_type))
		for (var/i = TRUE to 6)
			new pill_type(src)

	update_icon()

/obj/item/weapon/pill_pack/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		if (contents.len > 0)
			if (pop_sound)
				playsound(loc, pop_sound, 50, TRUE)
			var/obj/item/weapon/reagent_containers/pill/pill = contents[1]
			user << "<span class='notice'>You take one [pill.name] from [name].</span>"
			user.put_in_active_hand(pill)
			update_icon()
		else
			user << "<span class='warning'>It's empty!</span>"
	else
		..()

/obj/item/weapon/pill_pack/attack_self(mob/user as mob)
	if (contents.len > 0)
		var/obj/item/weapon/reagent_containers/pill/pill = contents[1]
		if (prob(70))
			if (pop_sound)
				playsound(loc, pop_sound, 50, TRUE)
			user << "<span class='notice'>You take one [pill.name] from [name].</span>"
			pill.loc = user.loc
			update_icon()
		else
			user << "<span class='warning'>You tried to take one [pill.name] from [name] by one hand, but failed.</span>"
	else
		user << "<span class='warning'>[name] is empty!</span>"

/obj/item/weapon/pill_pack/update_icon()
	icon_state = "[initial(icon_state)][contents.len]"

//////////////////
////Pill Packs////
//////////////////
/obj/item/weapon/pill_pack/antitox
	name = "antitoxin pill pack"
	desc = "Removes toxins and poisions from blood."
	pill_type = /obj/item/weapon/reagent_containers/pill/antitox

/obj/item/weapon/pill_pack/tramadol
	name = "tramadol pill pack"
	desc = "Effective painkiller."
	pill_type = /obj/item/weapon/reagent_containers/pill/tramadol

/obj/item/weapon/pill_pack/adrenaline
	name = "adrenaline pill pack"
	desc = "Prevents death by pain shock."
	pill_type = /obj/item/weapon/reagent_containers/pill/adrenaline
/*
/obj/item/weapon/pill_pack/adminordrazine
	name = "adminordrazine pill pack"
	desc = "Where did you even get that?"
	pill_type = /obj/item/weapon/reagent_containers/pill/adminordrazine
*/
/obj/item/weapon/pill_pack/pervitin
	name = "pervitin pill pack"
	desc = "Powerfull stimulant. Don't eat more than one."
	pill_type = /obj/item/weapon/reagent_containers/pill/pervitin