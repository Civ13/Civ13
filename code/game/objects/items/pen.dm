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
	icon_state = "pen" // feather
	item_state = "pen"
	slot_flags = SLOT_BELT | SLOT_EARS
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	throw_speed = 7
	throw_range = 15

	var/colour = COLOR_BLACK	//what colour the ink is!

/obj/item/weapon/pen/New()
	..()
	if (map && map.ordinal_age >= 4 && !istype(src, /obj/item/weapon/pen/pencil || /obj/item/weapon/pen/crayon))
		icon_state = "pennew" // from feather to modern black-point plastic pen.

/obj/item/weapon/pen/update_icon()
	..()
	if (map && map.ordinal_age >= 4 && !istype(src, /obj/item/weapon/pen/pencil || /obj/item/weapon/pen/crayon))
		icon_state = "pennew" // from feather to modern black-point plastic pen.

/obj/item/weapon/pen/pencil
	name = "pencil"
	desc = "a normal graphite pencil."
	icon_state = "pencil"

/obj/item/weapon/pen/fancy
	name = "expensive pen"
	desc = "a pen used by the boss."
	icon_state = "fancypen"

/obj/item/weapon/pen/blue
	desc = "It's a normal blue ink pen."
	icon_state = "pen"
	colour = COLOR_BLUE

/obj/item/weapon/pen/red
	desc = "It's a normal red ink pen."
	icon_state = "pen"
	colour = COLOR_RED

/obj/item/weapon/pen/multi
	desc = "It's a pen with multiple colors of ink!"
	var/selectedColor = 1 // starts off with the color "black", index 1
	var/colors = list("black","blue","red")

/obj/item/weapon/pen/multi/attack_self(mob/user)
	if (++selectedColor > 3)
		selectedColor = 1 // going 1-2-3-1 through the list "colors"

	colour = colors[selectedColor]

// These icon states do not exist.
/*
	if (colour == "black")
		icon_state = "pen"
	else
		icon_state = "pen_[colour]"
*/

	to_chat(user, SPAN_NOTICE("\The [src] will now write in [colour] ink."))

/obj/item/weapon/pen/invisible
	desc = "It's an invisble pen marker."
	icon_state = "pen"
	colour = COLOR_WHITE

// parent proc only continues if this pen has force, no special 'stab' attack only attacked like a blunt object, TODO this to properly stab; but I'm just gonna comment this out fully.
/*
/obj/item/weapon/pen/attack(mob/target as mob, mob/user as mob)
	if (!ismob(target))
		return
	// user.visible_message(SPAN_DANGER("[user] stabs [target] with \the [src]"), SPAN_DANGER("You stab [target] with \the [src]."))
	//	M << "<span class = 'red'>You feel a tiny prick!</span>" //That's a whole lot of meta!
	target.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been stabbed with [name]  by [user.name] ([user.ckey])</font>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>Used the [name] to stab [target.name] ([target.ckey])</font>")
	msg_admin_attack("[user.name] ([user.ckey]) Used the [name] to stab [target.name] ([target.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)", user.ckey, target.ckey)
*/

/*
 * Reagent pens
 */

/obj/item/weapon/pen/reagent
	flags = OPENCONTAINER
	slot_flags = SLOT_BELT | SLOT_EARS

/obj/item/weapon/pen/reagent/New()
	..()
	create_reagents(30)

/obj/item/weapon/pen/reagent/attack(mob/living/M as mob, mob/user as mob)

	if (!istype(M))
		return

	. = ..()

	if (M.can_inject(user,1)) // alerts "There is no exposed flesh or thin material on their [x] to inject into." if false.
		if (reagents.total_volume)
			if (M.reagents)
				var/contained_reagents = reagents.get_reagents()
				var/trans = reagents.trans_to_mob(M, 30, CHEM_BLOOD)
				admin_inject_log(user, M, src, contained_reagents, trans)

/*
 * Sleepy Pens
 */
/obj/item/weapon/pen/reagent/sleepy
	desc = "It's a black ink pen with a sharp point."

/obj/item/weapon/pen/reagent/sleepy/New()
	..()
	reagents.add_reagent("chloralhydrate", 22)	//Used to be 100 sleep toxin//30 Chloral seems to be fatal, reducing it to 22./N


/*
 * Parapen
 */
/obj/item/weapon/pen/reagent/paralysis

	New()
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
		to_chat(usr, SPAN_NOTICE("\The [src] will now write in [lowertext(selected_type)] ink."))


/*
 * Crayons
 */

/obj/item/weapon/pen/crayon
	name = "crayon"
	desc = "A colourful crayon. Please refrain from eating it or putting it in your nose."
	icon = 'icons/obj/crayons.dmi'
	icon_state = "crayonred"
	w_class = ITEM_SIZE_TINY
	attack_verb = list("attacked", "coloured")
	colour = "#FF0000" //RGB
	var/shadeColour = "#220000" //RGB
	var/uses = 30 //0 for unlimited uses
	var/instant = FALSE
	var/colourName = "red" //for updateIcon purposes

	New()
		name = "[colourName] crayon"
		..()
