/obj/item/clothing/accessory/locket
	name = "silver locket"
	desc = "This oval shaped, argentium sterling silver locket hangs on an incredibly fine, refractive string, almost thin as hair and microweaved from links to a deceptive strength, of similar material. The edges are engraved very delicately with an elegant curving design, but overall the main is unmarked and smooth to the touch, leaving room for either remaining as a stolid piece or future alterations. There is an obvious internal place for a picture or lock of some sort, but even behind that is a very thin compartment unhinged with the pinch of a thumb and forefinger."
	icon_state = "locket"
	item_state = "locket"
	slot_flags = FALSE
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_ID | SLOT_ACCESSORY
	var/base_icon
	var/open
	var/obj/item/held //Item inside locket.
	ripable = FALSE
	flags = CONDUCT
/obj/item/clothing/accessory/locket/attack_self(mob/user as mob)
	if (!base_icon)
		base_icon = icon_state

	if (!("[base_icon]_open" in icon_states(icon)))
		user << "\The [src] doesn't seem to open."
		return

	open = !open
	user << "You flip \the [src] [open?"open":"closed"]."
	if (open)
		icon_state = "[base_icon]_open"
		if (held)
			user << "\The [held] falls out!"
			held.loc = get_turf(user)
			held = null
	else
		icon_state = "[base_icon]"

/obj/item/clothing/accessory/locket/attackby(var/obj/item/O as obj, mob/user as mob)
	if (!open)
		user << "You have to open it first."
		return

	if (istype(O,/obj/item/weapon/paper))
		if (held)
			usr << "\The [src] already has something inside it."
		else
			usr << "You slip [O] into [src]."
			user.drop_item()
			O.loc = src
			held = O
		return
	..()
