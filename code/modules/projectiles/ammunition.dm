/obj/item/ammo_casing
	name = "bullet casing"
	desc = "A bullet casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "s-casing"
	flags = CONDUCT
	slot_flags = SLOT_EARS
	throwforce = TRUE
	w_class = TRUE
	flammable = TRUE
	var/leaves_residue = TRUE
	var/caliber = ""					//Which kind of guns it can be loaded into
	var/projectile_type					//The bullet type to create when New() is called
	var/obj/item/projectile/BB = null	//The loaded bullet - make it so that the projectiles are created only when needed?
	var/spent_icon = null
	var/thrown_force_divisor = 0.1
	var/btype = "normal" //normal, AP (armor piercing) and HP (hollow point)

/obj/item/ammo_casing/New()
	..()
	if (ispath(projectile_type))
		BB = new projectile_type(src)
	pixel_x = rand(-10, 10)
	pixel_y = rand(-10, 10)
	bullet_casings += src
	randomrotation()

/obj/item/ammo_casing/proc/checktype()
	BB.btype = btype
	BB.checktype()
	if (btype == "AP")
		name = "[name] (AP)"
	else if (btype == "HP")
		name = "[name] (HP)"

/obj/item/ammo_casing/Destroy()
	bullet_casings -= src
	..()
/obj/item/ammo_casing/proc/randomrotation()
	transform = matrixangle(rand(1,360))
	spawn(1)
		pixel_x = rand(-10, 10)
		pixel_y = rand(-10, 10)
//removes the projectile from the ammo casing
/obj/item/ammo_casing/proc/expend()
	. = BB
	BB = null
	set_dir(pick(cardinal)) //spin spent casings
	update_icon()

/obj/item/ammo_casing/update_icon()
	if (spent_icon && !BB)
		icon_state = spent_icon
		name = "empty [replacetext(name,"bullet", "casing")]"

/obj/item/ammo_casing/examine(mob/user)
	..()
	if (!BB)
		user << "This one is spent."

//An item that holds casings and can be used to put them inside guns
/obj/item/ammo_magazine
	name = "ammo magazine"
	var/pouch = FALSE
	var/opened = FALSE
	desc = "A magazine for some kind of gun."
	icon_state = "357"
	icon = 'icons/obj/ammo.dmi'
	flags = CONDUCT
	slot_flags = SLOT_BELT
	item_state = "syringe_kit"
	matter = list(DEFAULT_WALL_MATERIAL = 500)
	throwforce = 5
	w_class = 2
	throw_speed = 4
	throw_range = 10
	secondary_action = 1
	var/clip = FALSE
	var/belt = FALSE

	var/list/stored_ammo = list()
	var/mag_type = SPEEDLOADER //ammo_magazines can only be used with compatible guns. This is not a bitflag, the load_method var on guns is.
	var/caliber = "357"
	var/ammo_mag = "default"
	var/max_ammo = 7

	var/ammo_type = /obj/item/ammo_casing //ammo type that is initially loaded
	var/initial_ammo = null

	var/multiple_sprites = FALSE
	//because BYOND doesn't support numbers as keys in associative lists
	var/list/icon_keys = list()		//keys
	var/list/ammo_states = list()	//values

	// are we an ammo box
	var/is_box = FALSE

/obj/item/ammo_magazine/secondary_attack_self(mob/living/carbon/human/user)
	if (stored_ammo.len >= max_ammo)
		user << "<span class='warning'>[src] is full!</span>"
		return
	else if (!caliber)
		user << "<span class='warning'>This [src] has no caliber associated - manually add ammunition first.</span>"
		return
	else
		var/count = 0
		for(var/obj/item/ammo_casing/AC in get_turf(user))
			if (AC.caliber == caliber && stored_ammo.len < max_ammo)
				AC.loc = src
				stored_ammo.Insert(1, AC) //add to the head of the list
				count = 1
		if (count > 0)
			user << "<span class='warning'>You fill the [src] with the ammunition on the floor.</span>"
			update_icon()
		return

/obj/item/ammo_magazine/emptypouch
	name = "bullet pouch (20)"
	icon_state = "pouch_closed"
	ammo_type = null
	caliber = null
	max_ammo = 20
	weight = 0.70
	multiple_sprites = TRUE
	mag_type = SPEEDLOADER
	pouch = TRUE

/obj/item/ammo_magazine/emptyclip
	name = "clip (5)"
	clip = TRUE
	icon_state = "clip-0"
	ammo_type = null
	caliber = null
	max_ammo = 5
	weight = 0.1
	multiple_sprites = TRUE

/obj/item/ammo_magazine/emptymagazine
	name = "drum magazine (65)"
	mag_type = MAGAZINE
	icon_state = "ppsh-0"
	ammo_type = null
	caliber = null
	max_ammo = 65
	weight = 0.8
	multiple_sprites = TRUE

/obj/item/ammo_magazine/emptymagazine/small
	name = "magazine (30)"
	mag_type = MAGAZINE
	icon_state = "pps-0"
	ammo_type = null
	caliber = null
	max_ammo = 30
	weight = 0.25
	multiple_sprites = TRUE
/obj/item/ammo_magazine/emptymagazine/pistol
	name = "pistol magazine (15)"
	mag_type = MAGAZINE
	icon_state = "m9beretta-0"
	ammo_type = null
	caliber = null
	max_ammo = 15
	weight = 0.2
	multiple_sprites = TRUE
/obj/item/ammo_magazine/emptymagazine/pistol/a45
	name = "pistol magazine (8)"
	mag_type = MAGAZINE
	icon_state = "waltherp-0"
	ammo_type = null
	caliber = null
	max_ammo = 8
	weight = 0.1
	multiple_sprites = TRUE
/obj/item/ammo_magazine/emptybelt
	name = "belt (100)"
	mag_type = MAGAZINE
	icon_state = "b762x54-0"
	ammo_type = null
	caliber = null
	max_ammo = 100
	weight = 1
	w_class = 4
	multiple_sprites = TRUE
	belt = TRUE

/obj/item/ammo_magazine/verb/toggle_open()
	set category = null
	set src in view(1)
	set name = "Toggle Open"

	if (opened)
		opened=FALSE
		usr << "You close the [src]."
	else
		opened=TRUE
		usr << "You open the [src]."
	update_icon()
	return

/obj/item/ammo_magazine/attack_hand(mob/user as mob)
//	if (user.get_inactive_hand() == src)
	if (opened)
		unload_ammo(user, allow_dump=0)
	else
		return ..()

/obj/item/ammo_magazine/proc/unload_ammo(var/mob/living/carbon/human/user, allow_dump=0)
	if (stored_ammo.len > 0)
		if (allow_dump)
			var/count = FALSE
			var/turf/T = get_turf(user)
			if (T)
				for (var/obj/item/ammo_casing/C in stored_ammo)
					C.loc = T
					count++
				stored_ammo.Cut()
			if (count)
				visible_message("[user] empties \the [src].", "<span class='notice'>You remove [count] round\s from [src].</span>")
			update_icon()
			return
		else
			var/obj/item/ammo_casing/C = stored_ammo[stored_ammo.len]
			stored_ammo.len--
			user.put_in_hands(C)
			visible_message("[user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
			update_icon()
			return
	else
		user << "<span class='warning'>[src] is empty.</span>"
		update_icon()
		return

/obj/item/ammo_magazine/update_icon()
	if (pouch)
		if (!opened)
			icon_state = "pouch_closed"
		else
			if (multiple_sprites)
				if (stored_ammo.len >= max_ammo)
					icon_state = "pouch_full"
				else if (stored_ammo.len >= max_ammo*0.75)
					icon_state = "pouch_75"
				else if (stored_ammo.len >= max_ammo*0.50)
					icon_state = "pouch_50"
				else if (stored_ammo.len >= max_ammo*0.25)
					icon_state = "pouch_25"
				else if (stored_ammo.len != FALSE)
					icon_state = "pouch_0"
				else
					icon_state = "pouch_empty"
					name = "bullet pouch ([max_ammo])"
					desc = "an ammo pouch."
					caliber = null
	else
		if (multiple_sprites && icon_keys.len)
			//find the lowest key greater than or equal to stored_ammo.len
			var/new_state = null
			for (var/idx in TRUE to icon_keys.len)
				var/ammo_count = icon_keys[idx]
				if (ammo_count >= stored_ammo.len)
					new_state = ammo_states[idx]
					break
			icon_state = (new_state)? new_state : initial(icon_state)
		if (clip)
			if (stored_ammo.len == FALSE)
				caliber = null
				name = "clip ([max_ammo])"
		else if (belt)
			if (stored_ammo.len == FALSE)
				caliber = null
				name = "belt ([max_ammo])"
		else
			if (stored_ammo.len == FALSE)
				caliber = null
				name = "magazine ([max_ammo])"

/obj/item/ammo_magazine/New()
	..()
	if (multiple_sprites)
		initialize_magazine_icondata(src)

	if (isnull(initial_ammo) && ammo_type != null)
		initial_ammo = max_ammo

	if (initial_ammo && ammo_type != null)
		for (var/i in TRUE to initial_ammo)
			stored_ammo += new ammo_type(src)
	update_icon()
	if (istype(src, /obj/item/ammo_magazine/emptyclip))
		for (var/i = FALSE, i <= max_ammo, i++)
			var/ammo_state = "clip-[i]"
			icon_keys += i
			ammo_states += ammo_state

/obj/item/ammo_magazine/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W == src)
		return
	if (istype(W, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = W
		if (C.caliber != caliber && caliber != null)
			user << "<span class='warning'>[C] does not fit into [src].</span>"
			return
		if (stored_ammo.len >= max_ammo)
			user << "<span class='warning'>[src] is full!</span>"
			return
		user.remove_from_mob(C)
		C.loc = src
		stored_ammo.Insert(1, C) //add to the head of the list
		if (caliber == null)
			caliber = C.caliber
			name = "[C] magazine ([max_ammo])"
			if (pouch)
				name = "[C] ammo pouch"
			if (clip)
				name = "[C] clip"
			if (belt)
				name = "[C] belt ([max_ammo])"
		name = replacetext(name, " bullet","")
		update_icon()
	else if (istype(W, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/M = W
		if (M.caliber != caliber && caliber != null)
			user << "<span class='warning'>[M]'s ammo type does not fit into [src].</span>"
			return
		if (stored_ammo.len >= max_ammo)
			user << "<span class='warning'>[src] is full!</span>"
			return
		if (M.stored_ammo.len == FALSE)
			user << "<span class='warning'>[M] is empty!</span>"
			return

		var/filled = FALSE
		for (var/obj/item/ammo_casing/C in M.stored_ammo)
			if (stored_ammo.len >= max_ammo)
				break
			C.loc = src
			stored_ammo.Insert(1, C)
			M.stored_ammo -= C
			filled = TRUE
			if (caliber == null)
				caliber = C.caliber
				name = "bullet pouch ([C])"
		if (filled)
			user << "<span class = 'notice'>You fill [src] with [M]'s ammo.</span>"

		update_icon()
		W.update_icon()

// empty the mag
/obj/item/ammo_magazine/attack_self(mob/user)

	var/cont = FALSE
	if (stored_ammo.len > 0 && stored_ammo.len < 20)
		if ((input(user, "Are you sure you want to empty the [src]?", "[src]") in list ("Yes", "No")) == "Yes")
			cont = TRUE

	if (cont)
		var/turf/T = get_turf(src)
		// so people know who to lynch
		T.visible_message("<span class = 'notice'>[user] empties [src].</span>", "<span class='notice'>You empty [src].</span>")
		for (var/obj/item/ammo_casing/C in stored_ammo)
			C.loc = user.loc
			C.set_dir(pick(cardinal))
		stored_ammo.Cut()
		caliber = null
		update_icon()

/obj/item/ammo_magazine/examine(mob/user)
	..()
	user << "There [(stored_ammo.len == TRUE)? "is" : "are"] [stored_ammo.len] round\s left!"

//magazine icon state caching
/var/global/list/magazine_icondata_keys = list()
/var/global/list/magazine_icondata_states = list()

/proc/initialize_magazine_icondata(var/obj/item/ammo_magazine/M)
	var/typestr = "[M.type]"
	if (!(typestr in magazine_icondata_keys) || !(typestr in magazine_icondata_states))
		magazine_icondata_cache_add(M)

	M.icon_keys = magazine_icondata_keys[typestr]
	M.ammo_states = magazine_icondata_states[typestr]

/proc/magazine_icondata_cache_add(var/obj/item/ammo_magazine/M)
	if (!M.icon)
		return
	var/list/icon_keys = list()
	var/list/ammo_states = list()
	var/list/states = icon_states(M.icon)
	for (var/i = FALSE, i <= M.max_ammo, i++)
		var/ammo_state = "[M.icon_state]-[i]"
		if (ammo_state in states)
			icon_keys += i
			ammo_states += ammo_state

	magazine_icondata_keys["[M.type]"] = icon_keys
	magazine_icondata_states["[M.type]"] = ammo_states

//weight stuff
/obj/item/ammo_magazine/get_weight()
	. = ..()
	for (var/obj/item/I in stored_ammo)
		.+= I.get_weight()
	return .
