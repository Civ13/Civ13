/*
CONTAINS:
SAFES
FLOOR SAFES
*/

//SAFES
/obj/structure/safe
	name = "safe"
	desc = "A huge chunk of metal with a dial embedded in it. Fine print on the dial reads \"Scarborough Arms - 2 tumbler safe, guaranteed thermite resistant, explosion resistant, and assistant resistant.\""
	icon = 'icons/obj/structures.dmi'
	icon_state = "safe"
	anchored = TRUE
	density = TRUE
	var/open = FALSE		//is the safe open?
	var/tumbler_1_pos	//the tumbler position- from FALSE to 72
	var/tumbler_1_open	//the tumbler position to open at- 0 to 72
	var/tumbler_2_pos
	var/tumbler_2_open
	var/dial = FALSE		//where is the dial pointing?
	var/space = FALSE		//the combined w_class of everything in the safe
	var/maxspace = 24	//the maximum combined w_class of stuff in the safe
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/safe/New()
	tumbler_1_pos = rand(0, 71)
	tumbler_1_open = rand(0, 71)

	tumbler_2_pos = rand(0, 71)
	tumbler_2_open = rand(0, 71)


/obj/structure/safe/initialize()
	for (var/obj/item/I in loc)
		if (space >= maxspace)
			return
		if (I.w_class + space <= maxspace)
			space += I.w_class
			I.loc = src


/obj/structure/safe/proc/check_unlocked(mob/user as mob, canhear)
	if (user && canhear)
		if (tumbler_1_pos == tumbler_1_open)
			to_chat(user, "<span class='notice'>You hear a [pick("tonk", "krunk", "plunk")] from [src].</span>")
		if (tumbler_2_pos == tumbler_2_open)
			to_chat(user, "<span class='notice'>You hear a [pick("tink", "krink", "plink")] from [src].</span>")
	if (tumbler_1_pos == tumbler_1_open && tumbler_2_pos == tumbler_2_open)
		if (user) visible_message("<b>[pick("Spring", "Sprang", "Sproing", "Clunk", "Krunk")]!</b>")
		return TRUE
	return FALSE


/obj/structure/safe/proc/decrement(num)
	num -= 1
	if (num < 0)
		num = 71
	return num


/obj/structure/safe/proc/increment(num)
	num += 1
	if (num > 71)
		num = FALSE
	return num


/obj/structure/safe/update_icon()
	if (open)
		icon_state = "[initial(icon_state)]-open"
	else
		icon_state = initial(icon_state)


/obj/structure/safe/attack_hand(mob/user as mob)
	ui_interact(user)

/obj/structure/safe/ui_actions(ui_key)
	return list("open", "decrement", "increment", "retrieve")

/obj/structure/safe/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/list/sections = list(panel_section("Lock", rows = list(
		panel_row("Dial", dial * 5, buttons = list(panel_button("-", "decrement"), panel_button("+", "increment"))),
		panel_row("Door", open ? "Open" : "Shut", open ? "good" : "muted")),
		buttons = list(panel_button("[open ? "Close" : "Open"] the safe", "open"))))
	if (open)
		var/list/items = list()
		for (var/i = contents.len, i>=1, i--)
			var/obj/item/P = contents[i]
			items += list(panel_item(P.name, buttons = list(panel_button("Take", "retrieve", "\ref[P]"))))
		sections += list(panel_section("Contents", items = items, empty = "The safe is empty."))
	open_panel(user, name, 380, 480, sections, ui = ui, force_open = force_open)


/obj/structure/safe/Topic(href, href_list)
	if (!ishuman(usr))	return
	var/mob/living/human/user = usr

	var/canhear = FALSE

	/*if (istype(user.l_hand, /obj/item/clothing/accessory/stethoscope) || istype(user.r_hand, /obj/item/clothing/accessory/stethoscope))
		canhear = TRUE*/

	if (href_list["open"])
		if (check_unlocked())
			to_chat(user, "<span class='notice'>You [open ? "close" : "open"] [src].</span>")
			open = !open
			update_icon()
			updateUsrDialog()
			return
		else
			to_chat(user, "<span class='notice'>You can't [open ? "close" : "open"] [src], the lock is engaged!</span>")
			return

	if (href_list["decrement"])
		dial = decrement(dial)
		if (dial == tumbler_1_pos + 1 || dial == tumbler_1_pos - 71)
			tumbler_1_pos = decrement(tumbler_1_pos)
			if (canhear)
				to_chat(user, "<span class='notice'>You hear a [pick("clack", "scrape", "clank")] from [src].</span>")
			if (tumbler_1_pos == tumbler_2_pos + 37 || tumbler_1_pos == tumbler_2_pos - 35)
				tumbler_2_pos = decrement(tumbler_2_pos)
				if (canhear)
					to_chat(user, "<span class='notice'>You hear a [pick("click", "chink", "clink")] from [src].</span>")
			check_unlocked(user, canhear)
		updateUsrDialog()
		return

	if (href_list["increment"])
		dial = increment(dial)
		if (dial == tumbler_1_pos - 1 || dial == tumbler_1_pos + 71)
			tumbler_1_pos = increment(tumbler_1_pos)
			if (canhear)
				to_chat(user, "<span class='notice'>You hear a [pick("clack", "scrape", "clank")] from [src].</span>")
			if (tumbler_1_pos == tumbler_2_pos - 37 || tumbler_1_pos == tumbler_2_pos + 35)
				tumbler_2_pos = increment(tumbler_2_pos)
				if (canhear)
					to_chat(user, "<span class='notice'>You hear a [pick("click", "chink", "clink")] from [src].</span>")
			check_unlocked(user, canhear)
		updateUsrDialog()
		return

	if (href_list["retrieve"])
		var/obj/item/P = locate(href_list["retrieve"]) in src
		if (open)
			if (P && in_range(src, user))
				space -= P.w_class
				user.put_in_hands(P)
				updateUsrDialog()


/obj/structure/safe/attackby(obj/item/I as obj, mob/user as mob)
	if (open)
		if (I.w_class + space <= maxspace)
			var/mob/living/actor = user
			if (!istype(actor) || !actor.transfer_held_item_to(I, src))
				to_chat(user, SPAN_WARNING("You can't put [I] in [src]."))
				return
			space += I.w_class
			to_chat(user, "<span class='notice'>You put [I] in [src].</span>")
			updateUsrDialog()
			return
		else
			to_chat(user, "<span class='notice'>[I] won't fit in [src].</span>")
			return
/*	else
		if (istype(I, /obj/item/clothing/accessory/stethoscope))
			to_chat(user, "Hold [I] in one of your hands while you manipulate the dial.")
			return*/


obj/structure/safe/ex_act(severity)
	return

//FLOOR SAFES
/obj/structure/safe/floor
	name = "floor safe"
	icon_state = "floorsafe"
	density = FALSE
	level = TRUE	//underfloor
	layer = 2.5

/obj/structure/safe/floor/initialize()
	..()
	var/turf/T = loc
	if (istype(T) && !T.is_plating())
		hide(1)
	update_icon()

/obj/structure/safe/floor/hide()
	invisibility = 101

/obj/structure/safe/floor/hides_under_flooring()
	return TRUE
