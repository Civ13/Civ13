//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

/obj/item/weapon/implantcase
	name = "glass case"
	desc = "A case containing an implant."
	icon = 'icons/obj/items.dmi'
	icon_state = "implantcase-0"
	item_state = "implantcase"
	throw_speed = TRUE
	throw_range = 5
	w_class = 1.0
	var/obj/item/weapon/implant/implant = null
	var/implant_type = null

/obj/item/weapon/implantcase/New()
	implant = new implant_type(src)
	..()
	return

/obj/item/weapon/implantcase/proc/update()
	if (implant)
		icon_state = text("implantcase-[]", implant.implant_color)
	else
		icon_state = "implantcase-0"
	return

/obj/item/weapon/implantcase/attackby(obj/item/weapon/I as obj, mob/user as mob)
	..()
	if (istype(I, /obj/item/weapon/pen))
		var/t = input(user, "What would you like the label to be?", text("[]", name), null)  as text
		if (user.get_active_hand() != I)
			return
		if((!in_range(src, usr) && loc != user))
			return
		t = sanitizeSafe(t, MAX_NAME_LEN)
		if(t)
			name = text("Glass Case - '[]'", t)
		else
			name = "Glass Case"
	else if(istype(I, /obj/item/weapon/reagent_containers/syringe))
		if(!implant)	return
		if(!implant.allow_reagents)	return
		if(implant.reagents.total_volume >= implant.reagents.maximum_volume)
			user << "<span class='warning'>\The [src] is full.</span>"
		else
			spawn(5)
				I.reagents.trans_to_obj(implant, 5)
				user << "<span class='notice'>You inject 5 units of the solution. The syringe now contains [I.reagents.total_volume] units.</span>"
	else if (istype(I, /obj/item/weapon/implanter))
		var/obj/item/weapon/implanter/M = I
		if (M.implant)
			if ((implant || M.implant.implanted))
				return
			M.implant.loc = src
			implant = M.implant
			M.implant = null
			update()
			M.update()
		else
			if (implant)
				if (M.implant)
					return
				implant.loc = M
				M.implant = implant
				implant = null
				update()
			M.update()
	return
