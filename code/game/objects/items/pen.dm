/* Pens!
 * Contains:
 *		Pens
 *		Sleepy Pens
 *		Parapens
 */


/*
 * Pens
 */
/obj/item/weapon/pen
	desc = "It's a normal black ink pen."
	name = "pen"
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "pen"
	item_state = "pen"
	slot_flags = SLOT_BELT | SLOT_EARS
	throwforce = FALSE
	w_class = 1.0
	throw_speed = 7
	throw_range = 15
	matter = list(DEFAULT_WALL_MATERIAL = 10)
	var/colour = "black"	//what colour the ink is!

/obj/item/weapon/pen/pencil
	name = "pencil"
	desc = "a normal graphite pencil."
	icon_state = "pencil"

/obj/item/weapon/pen/blue
	desc = "It's a normal blue ink pen."
	icon_state = "pen"
	colour = "blue"

/obj/item/weapon/pen/red
	desc = "It's a normal red ink pen."
	icon_state = "pen"
	colour = "red"

/obj/item/weapon/pen/multi
	desc = "It's a pen with multiple colors of ink!"
	var/selectedColor = TRUE
	var/colors = list("black","blue","red")

/obj/item/weapon/pen/multi/attack_self(mob/user)
	if (++selectedColor > 3)
		selectedColor = TRUE

	colour = colors[selectedColor]

	if (colour == "black")
		icon_state = "pen"
	else
		icon_state = "pen_[colour]"

	user << "<span class='notice'>Changed color to '[colour].'</span>"

/obj/item/weapon/pen/invisible
	desc = "It's an invisble pen marker."
	icon_state = "pen"
	colour = "white"


/obj/item/weapon/pen/attack(mob/M as mob, mob/user as mob)
	if (!ismob(M))
		return
	user << "<span class='warning'>You stab [M] with the pen.</span>"
//	M << "<span class = 'red'>You feel a tiny prick!</span>" //That's a whole lot of meta!
	M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been stabbed with [name]  by [user.name] ([user.ckey])</font>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>Used the [name] to stab [M.name] ([M.ckey])</font>")
	msg_admin_attack("[user.name] ([user.ckey]) Used the [name] to stab [M.name] ([M.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
	return

/*
 * Reagent pens
 */

/obj/item/weapon/pen/reagent
	flags = OPENCONTAINER
	slot_flags = SLOT_BELT
//	origin_tech = list(TECH_MATERIAL = 2, TECH_ILLEGAL = 5)

/obj/item/weapon/pen/reagent/New()
	..()
	create_reagents(30)

/obj/item/weapon/pen/reagent/attack(mob/living/M as mob, mob/user as mob)

	if (!istype(M))
		return

	. = ..()

	if (M.can_inject(user,1))
		if (reagents.total_volume)
			if (M.reagents)
				var/contained_reagents = reagents.get_reagents()
				var/trans = reagents.trans_to_mob(M, 30, CHEM_BLOOD)
				admin_inject_log(user, M, src, contained_reagents, trans)

/*
 * Sleepy Pens
 */
/obj/item/weapon/pen/reagent/sleepy
	desc = "It's a black ink pen with a sharp point and a carefully engraved \"Waffle Co.\""
//	origin_tech = list(TECH_MATERIAL = 2, TECH_ILLEGAL = 5)

/obj/item/weapon/pen/reagent/sleepy/New()
	..()
	reagents.add_reagent("chloralhydrate", 22)	//Used to be 100 sleep toxin//30 Chloral seems to be fatal, reducing it to 22./N


/*
 * Parapens
 */
/obj/item/weapon/pen/reagent/paralysis
//	origin_tech = "materials=2;syndicate=5"

/obj/item/weapon/pen/reagent/paralysis/New()
	..()
	reagents.add_reagent("zombiepowder", 10)
	reagents.add_reagent("cryptobiolin", 15)

/*
 * Chameleon pen
 */
/obj/item/weapon/pen/chameleon
	var/signature = ""

/obj/item/weapon/pen/chameleon/attack_self(mob/user as mob)
	/*
	// Limit signatures to official crew members
	var/personnel_list[] = list()
	for (var/datum/data/record/t in data_core.locked) //Look in data core locked.
		personnel_list.Add(t.fields["name"])
	personnel_list.Add("Anonymous")

	var/new_signature = WWinput(user, "Enter new signature pattern.", "New Signature", WWinput_first_choice(personnel_list), WWinput_list_or_null(personnel_list))
	if (new_signature)
		signature = new_signature
	*/
	signature = sanitize(WWinput(user, "Enter new signature. Leave blank for 'Anonymous'", "New Signature", signature, "text"))

/obj/item/weapon/pen/proc/get_signature(var/mob/user)
	return (user && user.real_name) ? user.real_name : "Anonymous"

/obj/item/weapon/pen/chameleon/get_signature(var/mob/user)
	return signature ? signature : "Anonymous"

/obj/item/weapon/pen/chameleon/verb/set_colour()
	set name = "Change Pen Colour"
	set category = null

	var/list/possible_colors = list("Yellow", "Green", "Pink", "Blue", "Orange", "Cyan", "Red", "Invisible", "Black")
	var/selected_type = WWinput(usr, "Pick new colour.", "Pen Colour", possible_colors[1], WWinput_list_or_null(possible_colors))

	if (selected_type)
		switch(selected_type)
			if ("Yellow")
				colour = COLOR_YELLOW
			if ("Green")
				colour = COLOR_LIME
			if ("Pink")
				colour = COLOR_PINK
			if ("Blue")
				colour = COLOR_BLUE
			if ("Orange")
				colour = COLOR_ORANGE
			if ("Cyan")
				colour = COLOR_CYAN
			if ("Red")
				colour = COLOR_RED
			if ("Invisible")
				colour = COLOR_WHITE
			else
				colour = COLOR_BLACK
		usr << "<span class='info'>You select the [lowertext(selected_type)] ink container.</span>"


/*
 * Crayons
 */

/obj/item/weapon/pen/crayon
	name = "crayon"
	desc = "A colourful crayon. Please refrain from eating it or putting it in your nose."
	icon = 'icons/obj/crayons.dmi'
	icon_state = "crayonred"
	w_class = 1.0
	attack_verb = list("attacked", "coloured")
	colour = "#FF0000" //RGB
	var/shadeColour = "#220000" //RGB
	var/uses = 30 //0 for unlimited uses
	var/instant = FALSE
	var/colourName = "red" //for updateIcon purposes

	New()
		name = "[colourName] crayon"
		..()
