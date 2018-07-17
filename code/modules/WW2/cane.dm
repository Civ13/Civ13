/obj/item/weapon/cane
	name = "cane"
	desc = "A cane used by a true gentlemen."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "cane"
	item_state = "stick"
	flags = CONDUCT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_WEAK
	w_class = 2.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bludgeoned", "whacked", "disciplined", "thrashed")

/obj/item/weapon/cane/concealed
	var/concealed_blade

/obj/item/weapon/cane/concealed/New()
	..()
	var/obj/item/weapon/material/butterfly/switchblade/temp_blade = new(src)
	concealed_blade = temp_blade
	temp_blade.attack_self()

/obj/item/weapon/cane/concealed/attack_self(var/mob/user)
	if (concealed_blade)
		user.visible_message("<span class='warning'>[user] has unsheathed \a [concealed_blade] from \his [src]!</span>", "You unsheathe \the [concealed_blade] from \the [src].")
		// Calling drop/put in hands to properly call item drop/pickup procs
		playsound(user.loc, 'sound/weapons/flipblade.ogg', 50, TRUE)
		user.drop_from_inventory(src)
		user.put_in_hands(concealed_blade)
		user.put_in_hands(src)
		user.update_inv_l_hand(0)
		user.update_inv_r_hand()
		concealed_blade = null
	else
		..()

/obj/item/weapon/cane/concealed/attackby(var/obj/item/weapon/material/butterfly/W, var/mob/user)
	if (!concealed_blade && istype(W))
		user.visible_message("<span class='warning'>[user] has sheathed \a [W] into \his [src]!</span>", "You sheathe \the [W] into \the [src].")
		user.drop_from_inventory(W)
		W.loc = src
		concealed_blade = W
		update_icon()
	else
		..()

/obj/item/weapon/cane/concealed/update_icon()
	if (concealed_blade)
		name = initial(name)
		icon_state = initial(icon_state)
		item_state = initial(icon_state)
	else
		name = "cane shaft"
		icon_state = "nullrod"
		item_state = "foldcane"
