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

// Writing or copying time for a chapter of era tier, with pen P, by writer
// (a writing desk beside them speeds it up too).
/proc/scholar_write_time(tier, obj/item/P, mob/living/human/writer = null)
	var/rate = scholar_pen_rate(P)
	if (rate <= 0)
		rate = 1
	if (istype(writer))
		rate *= writer.scholar_desk_rate()
	return round(BOOK_WRITE_TIME(tier) / rate)

// ------------------------------------------------------------
// Workplaces: the writing desk and the library
// ------------------------------------------------------------

// Studying, writing and copying beside a fastened writing desk go faster.
#define SCHOLAR_DESK_RATE 1.25
// Bookcases this close to a research bench make a library.
#define LIBRARY_REACH 3
// Each relevant chapter shelved nearby speeds research, up to the cap.
#define LIBRARY_CHAPTER_BONUS 0.1
#define LIBRARY_MAX_BONUS 0.5

/obj/structure/writing_desk
	name = "writing desk"
	desc = "A sturdy desk for reading and writing. Studying, writing and copying chapters go faster beside it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "good_desk"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/writing_desk/attackby(obj/item/W, mob/living/human/user)
	if (istype(W, /obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		to_chat(user, SPAN_NOTICE(anchored ? "You unfasten \the [src] from the floor." : "You fasten \the [src] to the floor."))
		anchored = !anchored
		return
	if (istype(W, /obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		to_chat(user, SPAN_NOTICE("You begin dismantling \the [src]."))
		if (do_after(user, 25, src) && !QDELETED(src))
			to_chat(user, SPAN_NOTICE("You dismantle \the [src]."))
			new /obj/item/stack/material/woodplank(get_turf(src))
			qdel(src)
		return
	return ..()

/mob/living/human/proc/at_writing_desk()
	for (var/obj/structure/writing_desk/D in range(1, src))
		if (D.anchored)
			return TRUE
	return FALSE

/mob/living/human/proc/scholar_desk_rate()
	return at_writing_desk() ? SCHOLAR_DESK_RATE : 1

// Studying a chapter of era tier, at a desk or not.
/mob/living/human/proc/scholar_study_time(tier)
	return round(BOOK_STUDY_TIME(tier) / scholar_desk_rate())

// Research speed from a library: distinct chapters on the node's groundwork or
// in its discipline, in books on bookcases near the bench.
/obj/structure/research_bench/proc/library_chapters(node_id)
	var/list/relevant = list()
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return relevant
	var/discipline = node_discipline(node_id)
	for (var/obj/structure/bookcase/C in range(LIBRARY_REACH, src))
		for (var/obj/item/weapon/book/B in C.contents)
			for (var/chapter in B.research_chapter_list())
				if (chapter != node_id && ((N.prereqs && (chapter in N.prereqs)) || node_discipline(chapter) == discipline))
					relevant |= chapter
	return relevant

/obj/structure/research_bench/proc/library_rate(node_id)
	var/list/relevant = library_chapters(node_id)
	return 1 + min(LIBRARY_MAX_BONUS, relevant.len * LIBRARY_CHAPTER_BONUS)
