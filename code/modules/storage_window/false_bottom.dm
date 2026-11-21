// ============================================================
// False bottoms: a hidden compartment fitted into an ordinary box, briefcase,
// toolbox or backpack. Anyone can fit one with a wooden plank. It holds two
// small things that ordinary looks never show: the inventory grid, the storage
// window, searching someone's bag, stripping and emptying the container all
// skip it. Holding the container and searching it thoroughly finds it.
//
// The compartment is a plain /obj (never an /obj/item) inside the container,
// so every "for (var/obj/item/I in contents)" loop passes over it and it saves
// with the container like any other content. Whoever fitted or found it knows
// it; only they can use it.
// ============================================================

#define FALSE_BOTTOM_ITEMS 2           // things the compartment holds
#define FALSE_BOTTOM_MAX_W_CLASS ITEM_SIZE_SMALL
#define FALSE_BOTTOM_SPACE_LOST 2      // the container's own space it takes
#define FALSE_BOTTOM_MIN_SPACE 8       // smallest container that can take one
#define FALSE_BOTTOM_FIT_TIME 150      // deciseconds to fit one
#define FALSE_BOTTOM_SEARCH_TIME 100   // deciseconds to search a container thoroughly

/obj/item/weapon/storage
	var/false_bottom_ok = FALSE // can be fitted with a false bottom

/obj/item/weapon/storage/box
	false_bottom_ok = TRUE
/obj/item/weapon/storage/box/flare // its sprite counts what is inside
	false_bottom_ok = FALSE
/obj/item/weapon/storage/briefcase
	false_bottom_ok = TRUE
/obj/item/weapon/storage/toolbox
	false_bottom_ok = TRUE
/obj/item/weapon/storage/backpack
	false_bottom_ok = TRUE

/obj/false_bottom
	name = "hidden compartment"
	invisibility = 101
	mouse_opacity = 0
	anchored = TRUE
	var/list/known_by = list() // ckeys of whoever fitted or found it

// Anything that border searches should not look inside. Nothing ordinary is.
/atom/movable/proc/hidden_from_wards()
	return FALSE

/obj/item/weapon/storage/proc/false_bottom()
	for (var/obj/false_bottom/F in contents)
		return F
	return null

// What the container shows as holding: everything but its compartment.
/obj/item/weapon/storage/proc/shown_contents_count()
	. = contents.len
	if (false_bottom())
		.--

/proc/false_bottom_knows(obj/false_bottom/F, mob/M)
	return F && M && M.ckey && (M.ckey in F.known_by)

// The storage container held in either hand, active hand first.
/mob/living/human/proc/false_bottom_held_container()
	var/obj/item/weapon/storage/S = get_active_hand()
	if (istype(S))
		return S
	S = get_inactive_hand()
	if (istype(S))
		return S
	return null

/mob/living/human/proc/false_bottom_can_act()
	return !stat && !restrained() && !incapacitated()

/mob/living/human/verb/fit_false_bottom()
	set name = "Fit False Bottom"
	set category = "IC"
	set desc = "Fit a hidden compartment into the bottom of a box, case or pack you are holding, using a wooden plank in your other hand."

	if (!false_bottom_can_act())
		return
	var/obj/item/weapon/storage/S = null
	var/obj/item/stack/material/wood/W = null
	for (var/obj/item/I in list(get_active_hand(), get_inactive_hand()))
		if (istype(I, /obj/item/weapon/storage))
			S = I
		else if (istype(I, /obj/item/stack/material/wood))
			W = I
	if (!S || !W)
		to_chat(src, SPAN_WARNING("Hold the container in one hand and a wooden plank in the other."))
		return
	if (!S.false_bottom_ok || S.max_storage_space < FALSE_BOTTOM_MIN_SPACE)
		to_chat(src, SPAN_WARNING("[S] has no room for a false bottom."))
		return
	if (S.false_bottom())
		to_chat(src, SPAN_WARNING("[S] already has a false bottom."))
		return
	if (S.shown_contents_count())
		to_chat(src, SPAN_WARNING("Empty [S] first."))
		return
	to_chat(src, SPAN_NOTICE("You start fitting a false bottom into [S]."))
	if (!do_after(src, FALSE_BOTTOM_FIT_TIME, S))
		return
	if (QDELETED(S) || QDELETED(W) || S.false_bottom() || S.shown_contents_count() || !(S in list(get_active_hand(), get_inactive_hand())) || !(W in list(get_active_hand(), get_inactive_hand())))
		return
	if (!W.use(1))
		return
	var/obj/false_bottom/F = new(S)
	F.known_by += ckey
	S.max_storage_space = max(1, S.max_storage_space - FALSE_BOTTOM_SPACE_LOST)
	to_chat(src, SPAN_NOTICE("You fit a false bottom into [S]. Use Hidden Compartment while holding it to use it."))

/mob/living/human/verb/search_thoroughly()
	set name = "Search Thoroughly"
	set category = "IC"
	set desc = "Take your time feeling over a box, case or pack you are holding for anything hidden."

	if (!false_bottom_can_act())
		return
	var/obj/item/weapon/storage/S = false_bottom_held_container()
	if (!S)
		to_chat(src, SPAN_WARNING("Hold the container you want to search."))
		return
	to_chat(src, SPAN_NOTICE("You start going over [S] carefully."))
	if (!do_after(src, FALSE_BOTTOM_SEARCH_TIME, S))
		return
	if (QDELETED(S) || !(S in list(get_active_hand(), get_inactive_hand())))
		return
	var/obj/false_bottom/F = S.false_bottom()
	if (!F)
		to_chat(src, SPAN_NOTICE("You find nothing hidden in [S]."))
		return
	F.known_by |= ckey
	var/list/names = list()
	for (var/obj/item/I in F.contents)
		names += I.name
	to_chat(src, SPAN_NOTICE("You find a false bottom in [S][names.len ? ", holding [english_list(names)]" : ", empty"]."))

/mob/living/human/verb/use_hidden_compartment()
	set name = "Hidden Compartment"
	set category = "IC"
	set desc = "Use the false bottom of a container you are holding."

	if (!false_bottom_can_act())
		return
	var/obj/item/weapon/storage/S = false_bottom_held_container()
	var/obj/false_bottom/F = S ? S.false_bottom() : null
	if (!F || !false_bottom_knows(F, src))
		to_chat(src, SPAN_WARNING("You don't know of a hidden compartment in anything you are holding."))
		return
	var/obj/item/other = get_active_hand() == S ? get_inactive_hand() : get_active_hand()
	var/list/choices = list()
	if (other)
		choices["Hide [other.name]"] = other
	for (var/obj/item/I in F.contents)
		choices["Take out [I.name]"] = I
	choices["Take out the false bottom"] = F
	var/picked = player_input(src, "The false bottom of [S].", "Hidden Compartment", null, "anything", choices, TRUE)
	if (!picked || !(picked in choices))
		return
	if (QDELETED(S) || QDELETED(F) || F.loc != S || S != false_bottom_held_container() || !false_bottom_can_act())
		return
	var/atom/movable/A = choices[picked]
	if (A == F)
		if (F.contents.len)
			to_chat(src, SPAN_WARNING("Empty the false bottom first."))
			return
		qdel(F)
		S.max_storage_space += FALSE_BOTTOM_SPACE_LOST
		new /obj/item/stack/material/wood(get_turf(src))
		to_chat(src, SPAN_NOTICE("You pull the false bottom out of [S]."))
		return
	var/obj/item/I = A
	if (I.loc == F)
		if (!put_in_hands(I))
			I.forceMove(get_turf(src))
		to_chat(src, SPAN_NOTICE("You take [I] out of the false bottom."))
		return
	if (I != other || I.loc != src)
		return
	if (I.w_class > FALSE_BOTTOM_MAX_W_CLASS || istype(I, /obj/item/weapon/storage))
		to_chat(src, SPAN_WARNING("[I] is too big to hide under the false bottom."))
		return
	if (F.contents.len >= FALSE_BOTTOM_ITEMS)
		to_chat(src, SPAN_WARNING("The false bottom is full."))
		return
	if (!unEquip(I, Target = F))
		return
	to_chat(src, SPAN_NOTICE("You slip [I] under the false bottom of [S]."))

#undef FALSE_BOTTOM_ITEMS
#undef FALSE_BOTTOM_MAX_W_CLASS
#undef FALSE_BOTTOM_SPACE_LOST
#undef FALSE_BOTTOM_MIN_SPACE
#undef FALSE_BOTTOM_FIT_TIME
#undef FALSE_BOTTOM_SEARCH_TIME
