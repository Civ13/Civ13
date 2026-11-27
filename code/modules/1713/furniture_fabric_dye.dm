// Dyed furniture fabric: cloth padding on beds, chairs, sofas and stools, and
// cloth curtains, take a dye from the same list tailoring uses. Padding with
// cloth asks for a colour; using another cloth sheet on cloth padding or a cloth
// curtain re-dyes it for that sheet. See docs/home-finishes.md.

#define FABRIC_UNDYED "#ffffff"

/obj/structure/bed
	var/padding_color = null // dye on cloth padding, or null

/obj/item/weapon/stool
	var/padding_color = null

// Dye name -> hex this person can use on fabric, with undyed first; null asks
// for any colour (textile mills).
/proc/furniture_choose_dye(mob/living/human/user, what, current)
	var/list/dyes = tailoring_known_dyes(user)
	if (!dyes)
		return WWinput(user, "Choose a colour for [what].", "Dye", current || FABRIC_UNDYED, "color")
	var/list/menu = list()
	for (var/dye in dyes)
		menu["[dye][dyes[dye] == lowertext(current) ? " (current)" : ""]"] = dyes[dye]
	var/picked = WWinput(user, "Choose a dye for [what]. Learning more tailoring brings more dyes.", "Dye", null, menu)
	return (picked in menu) ? menu[picked] : null

/proc/fabric_dye_label(color)
	if (!color || lowertext(color) == FABRIC_UNDYED)
		return null
	var/name = tailoring_dye_name(color)
	return name ? name : "dyed"

/proc/fabric_cloth_sheet(obj/item/W)
	if (!istype(W, /obj/item/stack/material/cloth))
		return null
	var/obj/item/stack/material/cloth/C = W
	return C.amount >= 1 ? C : null

/obj/structure/bed/proc/padding_shade()
	if (padding_color && padding_material && padding_material.name == "cloth")
		return padding_color
	return padding_material ? padding_material.icon_colour : null

/obj/item/weapon/stool/proc/padding_shade()
	if (padding_color && padding_material && padding_material.name == "cloth")
		return padding_color
	return padding_material ? padding_material.icon_colour : null

/obj/structure/bed/proc/padding_label(use_name = FALSE)
	var/base = use_name ? padding_material.use_name : padding_material.display_name
	var/dye = padding_material.name == "cloth" ? fabric_dye_label(padding_color) : null
	return dye ? "[dye] [base]" : base

/obj/item/weapon/stool/proc/padding_label(use_name = FALSE)
	var/base = use_name ? padding_material.use_name : padding_material.display_name
	var/dye = padding_material.name == "cloth" ? fabric_dye_label(padding_color) : null
	return dye ? "[dye] [base]" : base

// Returns TRUE when the click was a dye step.
/obj/structure/bed/proc/fabric_dye_step(obj/item/W, mob/user)
	if (!ishuman(user) || !padding_material || padding_material.name != "cloth")
		return FALSE
	var/obj/item/stack/material/cloth/C = fabric_cloth_sheet(W)
	if (!C)
		return FALSE
	var/colour = furniture_choose_dye(user, "\the [src]'s padding", padding_color)
	if (!colour || !user.Adjacent(src) || C.loc != user || C.amount < 1 || !padding_material)
		return TRUE
	C.use(1)
	padding_color = lowertext(colour) == FABRIC_UNDYED ? null : colour
	update_icon()
	to_chat(user, "<span class='notice'>You recover \the [src] in fresh cloth.</span>")
	return TRUE

/obj/item/weapon/stool/proc/fabric_dye_step(obj/item/W, mob/user)
	if (!ishuman(user) || !padding_material || padding_material.name != "cloth")
		return FALSE
	var/obj/item/stack/material/cloth/C = fabric_cloth_sheet(W)
	if (!C)
		return FALSE
	var/colour = furniture_choose_dye(user, "\the [src]'s padding", padding_color)
	if (!colour || !user.Adjacent(src) || C.loc != user || C.amount < 1 || !padding_material)
		return TRUE
	C.use(1)
	padding_color = lowertext(colour) == FABRIC_UNDYED ? null : colour
	update_icon()
	to_chat(user, "<span class='notice'>You recover \the [src] in fresh cloth.</span>")
	return TRUE

/obj/structure/bed/attackby(obj/item/weapon/W, mob/user)
	if (fabric_dye_step(W, user))
		return TRUE
	var/had = padding_material
	. = ..()
	if (!had && padding_material && padding_material.name == "cloth" && ishuman(user))
		var/colour = furniture_choose_dye(user, "the new padding", null)
		if (colour && lowertext(colour) != FABRIC_UNDYED && padding_material)
			padding_color = colour
			update_icon()

/obj/item/weapon/stool/attackby(obj/item/weapon/W, mob/user)
	if (fabric_dye_step(W, user))
		return TRUE
	var/had = padding_material
	. = ..()
	if (!had && padding_material && padding_material.name == "cloth" && ishuman(user))
		var/colour = furniture_choose_dye(user, "the new padding", null)
		if (colour && lowertext(colour) != FABRIC_UNDYED && padding_material)
			padding_color = colour
			update_icon()

/obj/structure/bed/after_load()
	..()
	if (padding_color || furniture_finish)
		update_icon()

/obj/item/weapon/stool/after_load()
	..()
	if (padding_color)
		update_icon()

// A cloth curtain re-dyed for one sheet of cloth.
/obj/structure/curtain/attackby(obj/item/weapon/W, mob/user)
	var/obj/item/stack/material/cloth/C = fabric_cloth_sheet(W)
	if (!C || !ishuman(user) || istype(src, /obj/structure/curtain/leather))
		return ..()
	var/colour = furniture_choose_dye(user, "\the [src]", color)
	if (!colour || !user.Adjacent(src) || C.loc != user || C.amount < 1)
		return TRUE
	C.use(1)
	color = lowertext(colour) == FABRIC_UNDYED ? null : colour
	var/dye = fabric_dye_label(colour)
	name = dye ? "[dye] curtain" : initial(name)
	to_chat(user, "<span class='notice'>You hang a freshly dyed cloth on \the [src].</span>")
	return TRUE

#undef FABRIC_UNDYED
