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

// ------------------------------------------------------------
// Consumables and light
// ------------------------------------------------------------

// Supplies fed to the bench, per discipline (saved as text: "discipline=points;...").
/obj/structure/research_bench/var/research_supplies = ""

/obj/structure/research_bench/proc/supply_map()
	var/list/out = list()
	for (var/entry in splittext(research_supplies, ";"))
		var/list/parts = splittext(entry, "=")
		if (parts.len != 2 || !(parts[1] in scholar_disciplines))
			continue
		var/points = text2num(parts[2])
		if (isnum(points) && points > 0)
			out[parts[1]] = min(SCHOLAR_SUPPLY_CAP, round(points))
	return out

/obj/structure/research_bench/proc/set_supply_map(list/supplies)
	var/list/parts = list()
	for (var/discipline in supplies)
		if (supplies[discipline] > 0)
			parts += "[discipline]=[supplies[discipline]]"
	research_supplies = jointext(parts, ";")

/obj/structure/research_bench/proc/supply_points(discipline)
	var/list/supplies = supply_map()
	return supplies[discipline] || 0

// Supply points one unit of I is worth to research in discipline (0 if none).
/proc/scholar_supply_value(obj/item/I, discipline)
	switch (discipline)
		if ("mathematics")
			if (istype(I, /obj/item/weapon/paper) && blank_writing_sheet(I))
				return 5
		if ("engineering")
			if (istype(I, /obj/item/stack/material))
				return 2
		if ("natural_science")
			if (istype(I, /obj/item/stack/ore))
				return 3
			if (istype(I, /obj/item/stack/material/glass))
				return 2
		if ("medicine")
			if (istype(I, /obj/item/stack/medical))
				return 3
			if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown))
				return 2
		if ("agriculture")
			if (istype(I, /obj/item/stack/farming/seeds))
				return 2
			if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown))
				return 2
		if ("military")
			if (istype(I, /obj/item/ammo_casing))
				return 3
			if (istype(I, /obj/item/stack/ammopart))
				return 2
	return 0

// What feeds research in each discipline, for examine and the bench screen.
/proc/scholar_supply_text(discipline)
	switch (discipline)
		if ("mathematics")
			return "blank paper or parchment"
		if ("engineering")
			return "wood, stone or metal"
		if ("natural_science")
			return "ore or glass"
		if ("medicine")
			return "bandages, medicine or herbs"
		if ("agriculture")
			return "seeds or produce"
		if ("military")
			return "ammunition or ammunition parts"
	return "nothing"

// Feeds W into the bench's supplies for the subject's discipline. TRUE if used.
/obj/structure/research_bench/proc/feed_research_supply(obj/item/W, mob/living/human/user)
	if (!assigned_node)
		return FALSE
	var/discipline = node_discipline(assigned_node)
	var/value = scholar_supply_value(W, discipline)
	if (value <= 0)
		return FALSE
	var/list/supplies = supply_map()
	var/have = supplies[discipline] || 0
	if (have >= SCHOLAR_SUPPLY_CAP)
		to_chat(user, SPAN_WARNING("The bench already holds all the [scholar_disciplines[discipline]] supplies it can."))
		return TRUE
	var/units = 1
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		units = clamp(ceil((SCHOLAR_SUPPLY_CAP - have) / value), 1, S.amount)
		S.use(units)
	else
		if (W.loc == user)
			user.remove_from_mob(W)
		qdel(W)
	supplies[discipline] = min(SCHOLAR_SUPPLY_CAP, have + units * value)
	set_supply_map(supplies)
	to_chat(user, SPAN_NOTICE("You set out supplies for [scholar_disciplines[discipline]] research ([supplies[discipline]]/[SCHOLAR_SUPPLY_CAP])."))
	book_refresh_ui()
	return TRUE

// Uses one supply point per interval of work for node_id's discipline; the
// rate this tick runs at (part supplied, part not when the points run out).
/obj/structure/research_bench/proc/use_research_supply(node_id, intervals = 1)
	var/discipline = node_discipline(node_id)
	var/list/supplies = supply_map()
	var/have = supplies[discipline] || 0
	if (have < 1)
		return SCHOLAR_UNSUPPLIED_RATE
	var/needed = max(1, round(intervals))
	var/used = min(have, needed)
	supplies[discipline] -= used
	set_supply_map(supplies)
	return (used + (needed - used) * SCHOLAR_UNSUPPLIED_RATE) / needed

/obj/structure/research_bench/proc/research_lit()
	var/turf/T = get_turf(src)
	return T && T.get_lumcount() >= SCHOLAR_MIN_LIGHT

// ------------------------------------------------------------
// Instruments
// ------------------------------------------------------------

// From the Imperial Age (SCHOLAR_INSTRUMENT_TIER) a node needs its
// discipline's instrument at the bench: on the bench's tile or next to it, or
// in a researcher's hands. Most are made by other professions.

/obj/item/weapon/abacus
	name = "abacus"
	desc = "A wooden frame of beads on rods for reckoning sums. Advanced Basic Mathematics research needs one at the bench."
	icon = 'icons/obj/scholar_tools.dmi'
	icon_state = "abacus"
	item_state = "paper"
	w_class = ITEM_SIZE_NORMAL
	force = 4
	throwforce = 4

/obj/item/weapon/drafting_set
	name = "drafting set"
	desc = "A set square, dividers and a drawing board for technical drawings. Advanced Engineering research needs one at the bench."
	icon = 'icons/obj/scholar_tools.dmi'
	icon_state = "drafting_set"
	item_state = "paper"
	w_class = ITEM_SIZE_SMALL
	force = 3
	throwforce = 3

// Item types that serve as each discipline's instrument.
/proc/scholar_instrument_types(discipline)
	switch (discipline)
		if ("mathematics")
			return list(/obj/item/weapon/abacus)
		if ("engineering")
			return list(/obj/item/weapon/drafting_set)
		if ("natural_science")
			return list(/obj/item/weapon/reagent_containers/glass/beaker, /obj/item/glass_jar)
		if ("medicine")
			return list(/obj/item/weapon/surgery/scalpel)
		if ("agriculture")
			return list(/obj/item/weapon/plough)
		if ("military")
			return list(/obj/item/weapon/cartography_map)
	return list()

/proc/scholar_instrument_text(discipline)
	switch (discipline)
		if ("mathematics")
			return "an abacus"
		if ("engineering")
			return "a drafting set"
		if ("natural_science")
			return "glassware (a beaker or glass jar)"
		if ("medicine")
			return "a scalpel"
		if ("agriculture")
			return "a plough"
		if ("military")
			return "a map"
	return "nothing"

/proc/node_needs_instrument(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N && N.era_tier >= SCHOLAR_INSTRUMENT_TIER

/proc/is_scholar_instrument(obj/item/I, discipline)
	for (var/path in scholar_instrument_types(discipline))
		if (istype(I, path))
			return TRUE
	return FALSE

// Whether node_id's instrument is at the bench (or held by researcher).
/obj/structure/research_bench/proc/has_research_instrument(node_id, mob/living/human/researcher = null)
	if (!node_needs_instrument(node_id))
		return TRUE
	var/discipline = node_discipline(node_id)
	for (var/obj/item/I in range(1, src))
		if (is_scholar_instrument(I, discipline))
			return TRUE
	if (istype(researcher) && (is_scholar_instrument(researcher.l_hand, discipline) || is_scholar_instrument(researcher.r_hand, discipline)))
		return TRUE
	return FALSE

// ------------------------------------------------------------
// Tutoring
// ------------------------------------------------------------

// Someone next to student who knows node_id and can teach it right now.
/mob/living/human/proc/find_tutor(node_id)
	for (var/mob/living/human/T in range(1, src))
		if (T == src || T.stat != CONSCIOUS || T.incapacitated() || !T.research_presence())
			continue
		if (T.knows_recipe_node(node_id))
			return T
	return null

/mob/living/human/proc/still_tutoring(mob/living/human/student, node_id)
	return student && !QDELETED(src) && stat == CONSCIOUS && !incapacitated() && get_dist(src, student) <= 1 && knows_recipe_node(node_id)

// ------------------------------------------------------------
// Apprentices
// ------------------------------------------------------------

// The master's identity, saved on the apprentice's body. It names a character,
// not an account, and ends when either of them dies.
/mob/living/human/var/scholar_master = null

/mob/living/human/proc/scholar_identity()
	return "[ckey ? ckey : "npc"]:[real_name]"

/mob/living/human/proc/is_apprentice_of(mob/living/human/master)
	return istype(master) && master != src && istext(scholar_master) && scholar_master == master.scholar_identity()

/mob/living/human/proc/scholar_apprentice_count()
	var/count = 0
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat != DEAD && H.is_apprentice_of(src))
			count++
	return count

// Whether this character's master stands close by.
/mob/living/human/proc/master_nearby()
	if (!istext(scholar_master))
		return FALSE
	for (var/mob/living/human/M in range(SCHOLAR_APPRENTICE_REACH, src))
		if (M.stat != DEAD && is_apprentice_of(M))
			return TRUE
	return FALSE

// Binds apprentice to master once both agree. Returns a problem or null.
/mob/living/human/proc/scholar_apprentice_problem(mob/living/human/apprentice)
	if (!istype(apprentice) || apprentice == src || apprentice.stat != CONSCIOUS || stat != CONSCIOUS)
		return "They can't become your apprentice now."
	if (get_dist(src, apprentice) > 1)
		return "Stand next to them first."
	if (apprentice.is_apprentice_of(src))
		return "[apprentice] is already your apprentice."
	if (is_apprentice_of(apprentice))
		return "[apprentice] is your own master."
	if (scholar_apprentice_count() >= SCHOLAR_MAX_APPRENTICES)
		return "You already have [SCHOLAR_MAX_APPRENTICES] apprentices."
	return null

/mob/living/human/verb/take_apprentice()
	set name = "Take an apprentice"
	set category = "IC"
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("Scholars don't take apprentices here."))
		return
	var/list/choices = list()
	for (var/mob/living/human/H in range(1, src))
		if (H != src && H.stat == CONSCIOUS && H.client)
			choices["[H]"] = H
	if (!choices.len)
		to_chat(src, SPAN_WARNING("Stand next to the person you want to teach."))
		return
	var/pick = player_input(src, "Who will you take as your apprentice?", "Take an apprentice", null, "anything", choices, TRUE)
	var/mob/living/human/apprentice = choices[pick]
	var/problem = scholar_apprentice_problem(apprentice)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/answer = player_input(apprentice, "[src] offers to take you as their apprentice. You will learn faster while researching beside them. Accept?", "Apprenticeship", "No", "anything", list("Yes", "No"), TRUE)
	// Both prompts sleep; recheck everything.
	problem = scholar_apprentice_problem(apprentice)
	if (answer != "Yes" || problem)
		to_chat(src, SPAN_WARNING(problem ? problem : "[apprentice] declines."))
		return
	apprentice.scholar_master = scholar_identity()
	to_chat(src, SPAN_NOTICE("[apprentice] is now your apprentice."))
	to_chat(apprentice, SPAN_NOTICE("You are now [src]'s apprentice. Research beside them to learn faster."))

/mob/living/human/verb/leave_apprenticeship()
	set name = "Leave apprenticeship"
	set category = "IC"
	if (!istext(scholar_master))
		to_chat(src, SPAN_WARNING("You aren't anyone's apprentice."))
		return
	scholar_master = null
	to_chat(src, SPAN_NOTICE("You are no longer an apprentice."))

// Research at a bench: the researcher's apprentices nearby learn by watching,
// and a researcher working beside their own master learns faster.
/obj/structure/research_bench/proc/apprentice_research_gain(mob/living/human/researcher, node_id)
	for (var/mob/living/human/A in range(SCHOLAR_APPRENTICE_REACH, src))
		if (A != researcher && A.stat == CONSCIOUS && A.research_presence() && A.is_apprentice_of(researcher))
			A.gain_scholarship(node_id, SCHOLAR_RESEARCH_GAIN / 2)
	return researcher.master_nearby() ? SCHOLAR_APPRENTICE_GAIN_MULT : 1

// ------------------------------------------------------------
// Titles
// ------------------------------------------------------------

// "Scholar of Engineering" from the character's highest discipline, or null.
/mob/living/human/proc/scholar_title()
	var/best = null
	var/best_level = 0
	for (var/discipline in scholar_disciplines)
		var/level = scholar_level(discipline)
		if (level > best_level)
			best = discipline
			best_level = level
	if (!best || best_level < SCHOLAR_TITLE_APPRENTICE)
		return null
	var/rank = "Apprentice"
	if (best_level >= SCHOLAR_TITLE_MASTER)
		rank = "Master"
	else if (best_level >= SCHOLAR_TITLE_SCHOLAR)
		rank = "Scholar"
	return "[rank] of [scholar_disciplines[best]]"

/mob/living/human/examine(mob/user)
	. = ..()
	if (!map || !map.book_research_enabled() || stat == DEAD)
		return
	var/title = scholar_title()
	if (title)
		to_chat(user, SPAN_NOTICE("[src] is known as [copytext(title, 1, 2) == "A" ? "an" : "a"] [title]."))
