/obj/item/clothing/accessory/holster
	name = "shoulder holster"
	desc = "A handgun holster."
	icon_state = "holster"
	slot = "utility"
	var/obj/item/holstered = null
	var/obj/item/holstered2 = null //for double holsters
	var/capacity = 1
	ripable = FALSE
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;holstered;holstered2"
/obj/item/clothing/accessory/holster/proc/holster(var/obj/item/I, var/mob/living/user)
	if (holstered && istype(user) && capacity == 1)
		user << "<span class='warning'>There is already \a [holstered] holstered here!</span>"
		return

	if (holstered && holstered2 && istype(user) && capacity == 2)
		user << "<span class='warning'>There are already \a [holstered] and \a [holstered2] holstered here!</span>"
		return

	if (!(I.slot_flags & SLOT_HOLSTER))
		user << "<span class='warning'>[I] won't fit in [src]!</span>"
		return
	/*if (istype(I, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = I
		if (G.silencer)
			user << "<span class='warning'>[I] won't fit in [src]!</span>"
			return*/ //Comments it out until special holsters for silenced pistols can be made
	if (istype(user))
		user.stop_aiming(no_message=1)
	if (capacity == 1)
		holstered = I
		user.drop_from_inventory(holstered)
		holstered.loc = src
		holstered.add_fingerprint(user)
		w_class = max(w_class, holstered.w_class)
		user.visible_message("<span class='notice'>[user] holsters \the [holstered].</span>", "<span class='notice'>You holster \the [holstered].</span>")
		name = "occupied [initial(name)]"
	else if (capacity == 2)
		if (holstered && !holstered2)
			holstered2 = I
			user.drop_from_inventory(holstered2)
			holstered2.loc = src
			holstered2.add_fingerprint(user)
			w_class = max(w_class, holstered2.w_class)
			user.visible_message("<span class='notice'>[user] holsters \the [holstered2].</span>", "<span class='notice'>You holster \the [holstered2].</span>")
			name = "occupied [initial(name)]"
		else if (!holstered)
			holstered = I
			user.drop_from_inventory(holstered)
			holstered.loc = src
			holstered.add_fingerprint(user)
			w_class = max(w_class, holstered.w_class)
			user.visible_message("<span class='notice'>[user] holsters \the [holstered].</span>", "<span class='notice'>You holster \the [holstered].</span>")
			name = "occupied [initial(name)]"
		else //this really shouldnt happen
			return

/obj/item/clothing/accessory/holster/proc/clear_holster()
	if (capacity == 1)
		holstered = null
		name = initial(name)

/obj/item/clothing/accessory/holster/proc/unholster(mob/user as mob)
	if (capacity == 1)
		if (!holstered)
			return

	else if (capacity == 2)
		if (!holstered && !holstered2)
			return

	if (holstered && capacity == 1)
		if (istype(user.get_active_hand(),/obj) && istype(user.get_inactive_hand(),/obj))
			user << "<span class='warning'>You need an empty hand to draw \the [holstered]!</span>"
		else
			if (user.a_intent == I_HARM)
				usr.visible_message(
					"<span class='danger'>[user] draws \the [holstered], ready to shoot!</span>",
					"<span class='warning'>You draw \the [holstered], ready to shoot!</span>"
					)
			else
				user.visible_message(
					"<span class='notice'>[user] draws \the [holstered], pointing it at the ground.</span>",
					"<span class='notice'>You draw \the [holstered], pointing it at the ground.</span>"
					)
			user.put_in_hands(holstered)
			holstered.add_fingerprint(user)
			w_class = initial(w_class)
			clear_holster()
			return
	else if (holstered2 && capacity == 2)
		if (istype(user.get_active_hand(),/obj) && istype(user.get_inactive_hand(),/obj))
			user << "<span class='warning'>You need an empty hand to draw \the [holstered2]!</span>"
		else
			if (user.a_intent == I_HARM)
				usr.visible_message(
					"<span class='danger'>[user] draws \the [holstered2], ready to shoot!</span>",
					"<span class='warning'>You draw \the [holstered2], ready to shoot!</span>"
					)
			else
				user.visible_message(
					"<span class='notice'>[user] draws \the [holstered2], pointing it at the ground.</span>",
					"<span class='notice'>You draw \the [holstered2], pointing it at the ground.</span>"
					)
			user.put_in_hands(holstered2)
			holstered.add_fingerprint(user)
			w_class = initial(w_class)
			holstered2 = null

	else if (holstered && capacity == 2)
		if (istype(user.get_active_hand(),/obj) && istype(user.get_inactive_hand(),/obj))
			user << "<span class='warning'>You need an empty hand to draw \the [holstered]!</span>"
		else
			if (user.a_intent == I_HARM)
				usr.visible_message(
					"<span class='danger'>[user] draws \the [holstered], ready to shoot!</span>",
					"<span class='warning'>You draw \the [holstered], ready to shoot!</span>"
					)
			else
				user.visible_message(
					"<span class='notice'>[user] draws \the [holstered], pointing it at the ground.</span>",
					"<span class='notice'>You draw \the [holstered], pointing it at the ground.</span>"
					)
			user.put_in_hands(holstered)
			holstered.add_fingerprint(user)
			w_class = initial(w_class)
			holstered = null
			name = initial(name)

/obj/item/clothing/accessory/holster/attack_hand(mob/user as mob)
	if (has_suit)	//if we are part of a suit
		if (holstered || holstered2)
			unholster(user)
		return

	..(user)

/obj/item/clothing/accessory/holster/attackby(obj/item/W as obj, mob/user as mob)
	holster(W, user)

/obj/item/clothing/accessory/holster/emp_act(severity)
	if (holstered)
		holstered.emp_act(severity)
	if (holstered2)
		holstered2.emp_act(severity)
	..()

/obj/item/clothing/accessory/holster/examine(mob/user)
	..(user)
	if (capacity == 1)
		if (holstered)
			user << "A [holstered] is holstered here."
		else
			user << "It is empty."
	else if (capacity == 2)
		if (holstered && !holstered2)
			user << "A [holstered] is holstered here."
		else if (holstered && holstered2)
			user << "A [holstered] and a [holstered2] are holstered here."
		else if (!holstered && holstered2)
			user << "A [holstered2] is holstered here."
		else
			user << "It is empty."
/obj/item/clothing/accessory/holster/on_attached(obj/item/clothing/under/S, mob/user as mob)
	..()
	has_suit.verbs += /obj/item/clothing/accessory/holster/verb/holster_verb

/obj/item/clothing/accessory/holster/on_removed(mob/user as mob)
	has_suit.verbs -= /obj/item/clothing/accessory/holster/verb/holster_verb
	..()

//For the holster hotkey
/obj/item/clothing/accessory/holster/verb/holster_verb()
	set name = "Holster"
	set category = null
	set src in usr
	if (!istype(usr, /mob/living)) return
	if (usr.stat) return

	//can't we just use src here?
	var/obj/item/clothing/accessory/holster/H = null
	if (istype(src, /obj/item/clothing/accessory/holster))
		H = src
	else if (istype(src, /obj/item/clothing/under))
		var/obj/item/clothing/under/S = src
		if (S.accessories.len)
			H = locate() in S.accessories

	if (!H)
		usr << "<span class='warning'>Something is very wrong.</span>"

	if (!H.holstered)
		var/obj/item/W = usr.get_active_hand()
		if (!istype(W, /obj/item))
			usr << "<span class='warning'>You need your gun equiped to holster it.</span>"
			return
		H.holster(W, usr)
	else
		H.unholster(usr)

/obj/item/clothing/accessory/holster/armpit
	name = "armpit holster"
	desc = "A worn-out handgun holster. Perfect for concealed carry"
	icon_state = "holster"

/obj/item/clothing/accessory/holster/waist
	name = "waist holster"
	desc = "A handgun holster. Made of expensive leather."
	icon_state = "holster"
	overlay_state = "holster_low"

/obj/item/clothing/accessory/holster/chest
	name = "chest holster"
	desc = "A handgun holster with slung around the chest."
	icon_state = "waist_holster"
	overlay_state = "waist_holster"

/obj/item/clothing/accessory/holster/hip
	name = "hip holster"
	desc = "A handgun holster slung low on the hip."
	icon_state = "holster_hip"

/obj/item/clothing/accessory/holster/hip/double
	name = "double hip holster"
	desc = "A double handgun holster slung low on the hip."
	icon_state = "holster_hip2"
	capacity = 2

/obj/item/clothing/accessory/holster/tactical
	name = "hip holster"
	desc = "A handgun holster slung low on the hip."
	icon_state = "tacholster"

/obj/item/clothing/accessory/holster/replicantkama
	name = "replicant kama"
	desc = "A kama skirt with a built in holster slung low on the hip."
	icon_state = "replicant_kama"
