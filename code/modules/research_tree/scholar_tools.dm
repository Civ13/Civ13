// Scholar profession: era writing tools (book research).
//
// A researcher must hold a writing tool for the bench to progress, and
// writing or copying a chapter needs a pencil or pen. Better tools work
// faster: the rate multiplies research progress and divides writing time.
//
//   writing slate and chalk  1.0   research only (it can't write into books)
//   pencil                   1.0
//   crayon                   0.5
//   quill / pen              1.25
//   expensive pen            1.5

/obj/item/weapon/writing_slate
	name = "writing slate"
	desc = "A slab of slate in a wooden frame, with a stick of chalk. Scholars work out their sums on it at a research bench. It can't write into books."
	icon = 'icons/obj/scholar_tools.dmi'
	icon_state = "writing_slate"
	item_state = "paper"
	w_class = ITEM_SIZE_SMALL
	force = 3
	throwforce = 3

// How quickly I lets its holder research (0 if it isn't a writing tool).
/proc/scholar_tool_rate(obj/item/I)
	if (istype(I, /obj/item/weapon/writing_slate))
		return 1
	if (!istype(I, /obj/item/weapon/pen))
		return 0
	if (istype(I, /obj/item/weapon/pen/crayon))
		return 0.5
	if (istype(I, /obj/item/weapon/pen/fancy))
		return 1.5
	if (istype(I, /obj/item/weapon/pen/pencil))
		return 1
	return 1.25

// How quickly P writes chapters into books (0 if it can't).
/proc/scholar_pen_rate(obj/item/P)
	return istype(P, /obj/item/weapon/pen) ? scholar_tool_rate(P) : 0

// The best research tool in either hand.
/mob/living/human/proc/research_tool_rate()
	return max(scholar_tool_rate(l_hand), scholar_tool_rate(r_hand))

// The best pen or pencil in either hand, or null.
/mob/living/human/proc/held_writing_pen()
	var/obj/item/weapon/pen/best = null
	for (var/obj/item/weapon/pen/P in list(l_hand, r_hand))
		if (!best || scholar_pen_rate(P) > scholar_pen_rate(best))
			best = P
	return best

// Writing or copying time for a chapter of era tier, with pen P.
/proc/scholar_write_time(tier, obj/item/P)
	var/rate = scholar_pen_rate(P)
	return round(BOOK_WRITE_TIME(tier) / (rate > 0 ? rate : 1))
