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
	var/fits = worn_small_knife(W) || (takes_awl && istype(W, /obj/item/weapon/bone_needle))
	if (!fits && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [W] does not fit in \the [src]; it only takes a small knife[takes_awl ? " or an awl" : ""]."))
	return fits

// Clicking the worn boot or coat with an empty hand draws what the fitting holds.
/obj/item/clothing/accessory/storage/sheath/fitting/attack_hand(mob/user)
	if (draw_worn_contents(user))
		return
	..()

// Draw the first thing a worn holder carries into an empty active hand.
/obj/item/clothing/accessory/storage/proc/draw_worn_contents(mob/user)
	if (!has_suit || has_suit.loc != user || !hold.contents.len || user.get_active_hand())
		return FALSE
	var/obj/item/I = hold.contents[1]
	hold.remove_from_storage(I, get_turf(user))
	if (!user.put_in_hands(I))
		return FALSE
	user.visible_message(SPAN_WARNING("\The [user] pulls \a [I] from \the [src]!"), SPAN_NOTICE("You pull \the [I] from \the [src]."))
	playsound(user, 'sound/items/unholster_knife.ogg', 50, TRUE)
	return TRUE

/proc/worn_small_knife(obj/item/W)
	return is_tool(W, TOOL_KNIFE) && istype(W, /obj/item/weapon/material/kitchen/utensil) && !worn_fitting_refuses_knife(W)

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

// ---------------------------------------------------------------- Stone Age kits
// Sprites: icons/obj/worn_tools.dmi and icons/mob/worn_tools.dmi (Fable).

// Fire pouch, after the belt pouch of the Tyrolean Iceman (c. 3300 BC): flint
// tools, tinder fungus and a lump of pyrite. A flint or a fire drill inside
// lights a candle, pipe or cigarette held against the worn pouch.
/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch
	name = "fire pouch"
	desc = "A small sewn leather pouch packed with dry tinder fungus and a lump of pyrite. Keep a flint or a fire drill in it, then hold a candle, pipe or cigarette against the pouch to light it."
	icon = 'icons/obj/worn_tools.dmi'
	icon_state = "fire_pouch"
	icon_override = 'icons/mob/worn_tools.dmi'
	slots = 3
	value = 4
	var/tmp/sparking = FALSE // TRUE only while lighting something

/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/New()
	..()
	hold.max_w_class = ITEM_SIZE_SMALL
	hold.max_storage_space = 6

/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	var/fits = istype(W, /obj/item/weapon/flint) || istype(W, /obj/item/weapon/flame/fire_drill) || istype(W, /obj/item/weapon/flame/lighter/striker) || worn_small_knife(W) || istype(W, /obj/item/weapon/material/hide_scraper) || istype(W, /obj/item/weapon/bone_needle)
	if (!fits && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [src] only holds flint, fire-making tools and small flint tools."))
	return fits

/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/is_open_flame()
	return sparking

// What the pouch can strike or drill a light with, and how long it takes.
/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/proc/spark_source()
	for (var/obj/item/weapon/flint/F in hold.contents)
		return F
	for (var/obj/item/weapon/flame/fire_drill/D in hold.contents)
		return D
	return null

/proc/worn_lightable(obj/item/I)
	if (istype(I, /obj/item/weapon/flame/candle))
		var/obj/item/weapon/flame/candle/C = I
		return !C.lit
	if (istype(I, /obj/item/clothing/mask/smokable))
		var/obj/item/clothing/mask/smokable/S = I
		return !S.lit
	return FALSE

/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/attackby(obj/item/I, mob/user)
	if (worn_lightable(I) && ishuman(user))
		light_held(I, user)
		return TRUE
	return ..()

/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/proc/light_held(obj/item/I, mob/living/human/H)
	var/obj/item/source = spark_source()
	if (!source)
		to_chat(H, SPAN_WARNING("There is no flint or fire drill in \the [src] to make a spark with."))
		return FALSE
	var/drilling = istype(source, /obj/item/weapon/flame/fire_drill)
	if (!H.may_do_after)
		return FALSE
	to_chat(H, SPAN_NOTICE(drilling ? "You spin the fire drill in \the [src] until the tinder smoulders..." : "You strike the flint against the pyrite in \the [src]..."))
	playsound(get_turf(H), 'sound/effects/chop.ogg', 30, TRUE)
	if (!do_after(H, drilling ? 4 SECONDS : 1 SECOND, src) || QDELETED(I) || I.loc != H || QDELETED(source) || source.loc != hold)
		return FALSE
	if (!drilling && !prob(70))
		to_chat(H, SPAN_NOTICE("The sparks fail to catch. Try again."))
		return FALSE
	sparking = TRUE
	I.attackby(src, H)
	sparking = FALSE
	return TRUE

// Hand drill: a wooden spindle spun on a notched hearth board until the dust
// smoulders. Use it in hand (about 4 seconds) for a brief ember that lights a
// candle or pipe, or keep it in a fire pouch.
/obj/item/weapon/flame/fire_drill
	name = "fire drill"
	desc = "A straight wooden spindle and a notched hearth board. Spin it in your hands until the dust smoulders, then touch a candle or pipe to the ember."
	icon = 'icons/obj/worn_tools.dmi'
	icon_state = "fire_drill"
	item_state = ""
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT | SLOT_POCKET
	value = 1

/obj/item/weapon/flame/fire_drill/attack_self(mob/living/user)
	if (lit || !ishuman(user))
		return
	var/mob/living/human/H = user
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You spin \the [src] between your palms..."))
	if (!do_after(H, 4 SECONDS, src) || lit || loc != H)
		return
	lit = TRUE
	set_light(1)
	H.visible_message(SPAN_NOTICE("\The [H] works \the [src] until the dust glows."), SPAN_NOTICE("An ember glows in the notch. You have a few seconds to light something."))
	addtimer(CALLBACK(src, PROC_REF(snuff)), 5 SECONDS)

/obj/item/weapon/flame/fire_drill/proc/snuff()
	if (!lit)
		return
	lit = FALSE
	set_light(0)

// Bone needle case on a cord, as Inuit and Norse sewers wore: holds the needle
// and sinew. The bone needle mends with sinew pulled from a worn case.
/obj/item/clothing/accessory/storage/needle_case
	name = "needle case"
	desc = "A hollow bone tube on a cord, worn on the clothes. It keeps a needle and some sinew; the needle mends with sinew pulled straight from the case."
	icon = 'icons/obj/worn_tools.dmi'
	icon_state = "needle_case"
	icon_override = 'icons/mob/worn_tools.dmi'
	slot = "decor"
	slots = 2
	w_class = ITEM_SIZE_TINY
	ripable = FALSE
	value = 2

/obj/item/clothing/accessory/storage/needle_case/New()
	..()
	hold.max_w_class = ITEM_SIZE_SMALL
	hold.max_storage_space = 4

/obj/item/clothing/accessory/storage/needle_case/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	var/fits = istype(W, /obj/item/weapon/bone_needle) || istype(W, /obj/item/stack/sinew)
	if (!fits && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [src] only holds a needle and sinew."))
	return fits

// Sinew in a worn needle case, for the bone needle (stone_age_arms.dm). Only
// the case is searched, so mending never eats leather from a belt pouch.
/mob/living/human/proc/needle_case_thread()
	for (var/obj/item/clothing/accessory/storage/needle_case/N in worn_tool_holders())
		for (var/obj/item/stack/sinew/S in N.hold.contents)
			return S
	return null

// A damaged garment is mended by the needle (its afterattack), not offered to a
// needle case attached to it; an undamaged one stores the needle as before.
// A candle or pipe held against clothes with a fire pouch goes to that pouch,
// never into a plain pouch beside it.
/obj/item/clothing/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/bone_needle) && accessories.len && health < initial(health))
		return FALSE
	if (worn_lightable(I))
		for (var/obj/item/clothing/accessory/storage/belt_pouch/fire_pouch/P in accessories)
			return P.attackby(I, user)
	return ..()

// Neck knife: a small rawhide sheath hung on a thong at the chest, as worn on
// the Plains and in the Arctic. Click the worn clothes with an empty hand to
// draw it when it is the only attachment, or use its strip tile.
/obj/item/clothing/accessory/storage/sheath/neck
	name = "neck sheath"
	desc = "A small rawhide knife sheath hung on a thong around the neck. It holds one small knife."
	icon = 'icons/obj/worn_tools.dmi'
	base_icon = "neck_sheath"
	icon_state = "neck_sheath"
	item_state = ""
	icon_override = 'icons/mob/worn_tools.dmi'
	slot = "decor"
	slots = 1
	w_class = ITEM_SIZE_TINY
	value = 2

/obj/item/clothing/accessory/storage/sheath/neck/New()
	..()
	hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil/knife)
	hold.max_w_class = ITEM_SIZE_SMALL
	hold.max_storage_space = 2

/obj/item/clothing/accessory/storage/sheath/neck/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	var/fits = worn_small_knife(W)
	if (!fits && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [W] is too big for \the [src]; it only takes a small knife."))
	return fits

/obj/item/clothing/accessory/storage/sheath/neck/attack_hand(mob/user)
	if (draw_worn_contents(user))
		return
	..()
