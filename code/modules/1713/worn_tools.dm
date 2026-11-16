// Tools built into wearable gear: a tool worn at the belt, the hip, on the
// clothes or in a sewn-in sheath counts as at hand. Backpacks, satchels on the
// back and pockets do not: reaching into those means unpacking.
// Included after belt_pouches.dm and lanyards.dm. See docs/worn-tools.md.

// The worn things a person can reach into without unpacking: the belt slot item,
// the hip slot item, and whatever hangs from the uniform, belt, coat and shoes.
/mob/living/human/proc/worn_tool_holders()
	. = list()
	for (var/obj/item/I in list(belt, wear_id))
		. += I
	for (var/obj/item/clothing/C in list(w_uniform, belt, wear_id, wear_suit, shoes))
		for (var/obj/item/clothing/accessory/A in C.accessories)
			. |= A

// The first worn thing of tool_type a free hand can reach: the other hand first,
// then the worn holders above and what they carry (one level deep).
/mob/living/human/proc/reach_worn_tool(tool_type)
	var/obj/item/held = get_inactive_hand()
	if (istype(held, tool_type))
		return held
	for (var/obj/item/holder in worn_tool_holders())
		if (istype(holder, tool_type))
			return holder
		for (var/obj/item/I in worn_tool_contents(holder))
			if (istype(I, tool_type))
				return I
	return null

/proc/worn_tool_contents(obj/item/holder)
	if (istype(holder, /obj/item/clothing/accessory/storage))
		var/obj/item/clothing/accessory/storage/S = holder
		return S.hold ? S.hold.contents : list()
	if (istype(holder, /obj/item/weapon/storage))
		return holder.contents
	return list()

// ---------------------------------------------------------------- fittings
// A sheath sewn into a boot or a coat sleeve: one per garment, slot "fitting".
// It is never drawn on the character or on the garment's icon; examine shows it.

/obj/item/clothing/accessory/storage/sheath/fitting
	name = "boot sheath"
	desc = "A narrow leather sheath sewn inside a boot. It holds one small knife."
	icon = 'icons/obj/worn_tools.dmi' // drawn by tests/sprites/create_worn_tools.py
	base_icon = "boot_sheath"
	icon_state = "boot_sheath"
	item_state = ""
	slot = "fitting"
	slots = 1
	w_class = ITEM_SIZE_SMALL
	value = 2
	// The garment kind this fitting is made for.
	var/fitting_garment = /obj/item/clothing/shoes
	// Also takes the bone needle and awl (sleeve sheath).
	var/takes_awl = FALSE

/obj/item/clothing/accessory/storage/sheath/fitting/New()
	..()
	hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil/knife, /obj/item/weapon/bone_needle)
	hold.max_w_class = ITEM_SIZE_SMALL
	hold.max_storage_space = 2

/obj/item/clothing/accessory/storage/sheath/fitting/sleeve
	name = "sleeve sheath"
	desc = "A slim leather sheath sewn along the inside of a coat sleeve. It holds one small knife or an awl."
	base_icon = "sleeve_sheath"
	icon_state = "sleeve_sheath"
	fitting_garment = /obj/item/clothing/suit
	takes_awl = TRUE

// Hidden inside the garment: nothing is drawn on the garment or the wearer.
/obj/item/clothing/accessory/storage/sheath/fitting/get_inv_overlay()
	if (!inv_overlay)
		inv_overlay = image(null)
	return inv_overlay

/obj/item/clothing/accessory/storage/sheath/fitting/get_mob_overlay()
	if (!mob_overlay)
		mob_overlay = image(null)
	return mob_overlay

// Knives too big to hide in a boot or sleeve: farm and kitchen blades and
// large fighting knives.
/proc/worn_fitting_refuses_knife(obj/item/W)
	return is_type_in_list(W, list(
		/obj/item/weapon/material/kitchen/utensil/knife/sickle,
		/obj/item/weapon/material/kitchen/utensil/knife/flint_sickle,
		/obj/item/weapon/material/kitchen/utensil/knife/butcher,
		/obj/item/weapon/material/kitchen/utensil/knife/meat,
		/obj/item/weapon/material/kitchen/utensil/knife/bread,
		/obj/item/weapon/material/kitchen/utensil/knife/bowie,
		/obj/item/weapon/material/kitchen/utensil/knife/hook))

/obj/item/clothing/accessory/storage/sheath/fitting/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	var/fits = (is_tool(W, TOOL_KNIFE) && istype(W, /obj/item/weapon/material/kitchen/utensil) && !worn_fitting_refuses_knife(W)) || (takes_awl && istype(W, /obj/item/weapon/bone_needle))
	if (!fits && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [W] does not fit in \the [src]; it only takes a small knife[takes_awl ? " or an awl" : ""]."))
	return fits

// Clicking the worn boot or coat with an empty hand draws what the fitting holds.
/obj/item/clothing/accessory/storage/sheath/fitting/attack_hand(mob/user)
	if (has_suit && has_suit.loc == user && hold.contents.len && !user.get_active_hand())
		var/obj/item/I = hold.contents[1]
		hold.remove_from_storage(I, get_turf(user))
		if (user.put_in_hands(I))
			user.visible_message(SPAN_WARNING("\The [user] pulls \a [I] from \the [has_suit]!"), SPAN_NOTICE("You pull \the [I] from \the [src]."))
			playsound(user, 'sound/items/unholster_knife.ogg', 50, TRUE)
			return
	..()

// A fitting only goes into the garment kind it is made for.
/obj/item/clothing/can_attach_accessory(obj/item/clothing/accessory/A)
	if (istype(A, /obj/item/clothing/accessory/storage/sheath/fitting))
		var/obj/item/clothing/accessory/storage/sheath/fitting/F = A
		if (!istype(src, F.fitting_garment))
			return FALSE
	return ..()

/obj/item/clothing/accessory/storage/sheath/fitting/on_attached(obj/item/clothing/S, mob/user)
	..()
	if (user)
		to_chat(user, SPAN_NOTICE("It sits hidden inside \the [S]. Click the worn [S.name] with an empty hand to draw from it."))

// Examine says what a fitting holds, so nothing worn is truly invisible.
/obj/item/clothing/examine(mob/user)
	..(user)
	for (var/obj/item/clothing/accessory/storage/sheath/fitting/F in accessories)
		if (F.hold && F.hold.contents.len)
			var/obj/item/I = F.hold.contents[1]
			to_chat(user, "\The [F] holds \a [I].")

// Shoes used to hide a knife in a `holding` var. A shoe saved with one still
// carries it in its contents: drop it beside the shoe so nothing is lost.
/obj/item/clothing/shoes/after_load()
	..()
	var/turf/T = get_turf(src)
	if (!T)
		return
	for (var/obj/item/I in contents)
		if (I in accessories)
			continue
		if (istype(I, /obj/item/weapon/material/kitchen/utensil) || istype(I, /obj/item/weapon/material/shard) || istype(I, /obj/item/weapon/attachment/bayonet) || istype(I, /obj/item/weapon/gun/projectile/revolver/derringer))
			I.forceMove(T)
