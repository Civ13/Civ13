// ============================================================
// Research Tree - prototypes and field study (Val, 2026-11-13)
// ------------------------------------------------------------
// Two more ways to research away from the bench, from a player's suggestions:
// - Prototypes: once a carried book holds a third of a chapter, its carrier
//   can make that subject's own things before knowing it. Each one made
//   writes a share of the chapter into that book, up to a limit per book, and
//   no more can be made early once the book has had its fill.
// - Field study: take paper, parchment or a book to something that already
//   exists and that the subject makes (a building, a machine, a tool...) and
//   study it. Each kind of thing counts once per book.
// Only on book-research worlds. Capstones still need their demonstration or
// prototype part (demonstrations.dm).
// ============================================================

// Share of a chapter a carried book needs before prototypes can be made.
#define SUBJECT_PROTO_SHARE 0.34
// Share of the chapter each prototype writes, and how many count per book.
#define SUBJECT_PROTO_POINTS 0.08
#define SUBJECT_PROTO_MAX 5
// Share of the chapter each kind of thing studied writes, and how many kinds count.
#define FIELD_STUDY_POINTS 0.1
#define FIELD_STUDY_MAX 3
#define FIELD_STUDY_RANGE 1
#define FIELD_STUDY_TIME 300

/obj/item/weapon/book
	var/research_prototypes = "" // "node=count;node=count" prototypes made from this book
	var/research_fieldstudies = "" // "node>/type/path;..." kinds of things studied into this book

/obj/item/weapon/paper
	var/field_study_node = null // subject these field notes are about
	var/field_study_type = null // the kind of thing studied

// ---------- Prototypes ----------

/obj/item/weapon/book/proc/prototype_counts()
	var/list/counts = list()
	if (istext(research_prototypes) && length(research_prototypes))
		for (var/part in splittext(research_prototypes, ";"))
			var/list/pair = splittext(part, "=")
			if (pair.len == 2 && valid_recipe_node_id(pair[1]))
				counts[pair[1]] = max(0, text2num(pair[2]) || 0)
	return counts

/obj/item/weapon/book/proc/prototypes_made(node_id)
	return prototype_counts()[node_id] || 0

/obj/item/weapon/book/proc/add_prototype_made(node_id)
	var/list/counts = prototype_counts()
	counts[node_id] = (counts[node_id] || 0) + 1
	var/list/parts = list()
	for (var/id in counts)
		parts += "[id]=[counts[id]]"
	research_prototypes = jointext(parts, ";")

// A carried book that can still take a prototype of node_id, or null.
/mob/living/human/proc/prototype_book(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return null
	for (var/obj/item/weapon/book/B in get_demonstration_carried())
		if (istype(B, /obj/item/weapon/book/research/tree_book) || B.has_research_chapter(node_id))
			continue
		if (B.research_ticks(node_id) >= N.cost_ticks * SUBJECT_PROTO_SHARE && B.prototypes_made(node_id) < SUBJECT_PROTO_MAX)
			return B
	return null

// The subject a prototype of result_path_string would be for, if H may make one.
/proc/subject_prototype_node(mob/living/human/H, result_path_string)
	if (!istype(H) || !istext(result_path_string) || !map || !map.book_research_enabled())
		return null
	var/node_id = get_recipe_node_req(result_path_string)
	if (!istext(node_id) || !get_research_node(node_id))
		return null
	if (H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id))
		return null
	return H.prototype_book(node_id) ? node_id : null

/proc/subject_prototype_allowed(mob/living/human/H, result_path_string)
	return subject_prototype_node(H, result_path_string) ? TRUE : FALSE

// Called when something is made (from note_craft_practice): a prototype writes
// its share into the carried book.
/proc/record_subject_prototype(mob/living/human/H, result_path_string)
	var/node_id = subject_prototype_node(H, result_path_string)
	if (!node_id)
		return 0
	var/datum/research_node/N = get_research_node(node_id)
	var/obj/item/weapon/book/B = H.prototype_book(node_id)
	B.add_prototype_made(node_id)
	var/points = max(1, round(N.cost_ticks * SUBJECT_PROTO_POINTS))
	var/finished = B.add_research_work(node_id, points)
	to_chat(H, SPAN_NOTICE("You note how the prototype came out in [B]: <b>[N.name]</b> advances by [points] points[finished ? " and the chapter is finished" : ""]. ([B.prototypes_made(node_id)] of [SUBJECT_PROTO_MAX] prototypes for this book.)"))
	return points

// ---------- Field study ----------

/obj/item/weapon/book/proc/field_study_list()
	var/list/result = list()
	if (istext(research_fieldstudies) && length(research_fieldstudies))
		for (var/part in splittext(research_fieldstudies, ";"))
			if (length(part))
				result |= part
	return result

/obj/item/weapon/book/proc/field_study_count(node_id)
	. = 0
	for (var/entry in field_study_list())
		if (findtext(entry, "[node_id]>") == 1)
			.++

/obj/item/weapon/book/proc/has_field_study(node_id, kind)
	return "[node_id]>[kind]" in field_study_list()

/obj/item/weapon/book/proc/can_take_field_study(node_id, kind)
	return valid_recipe_node_id(node_id) && !has_research_chapter(node_id) && !has_field_study(node_id, kind) && field_study_count(node_id) < FIELD_STUDY_MAX

// Writes one study into the book. Returns the points added, or 0.
/obj/item/weapon/book/proc/record_field_study(node_id, kind)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !can_take_field_study(node_id, kind))
		return 0
	var/list/done = field_study_list()
	done += "[node_id]>[kind]"
	research_fieldstudies = jointext(done, ";")
	var/points = max(1, round(N.cost_ticks * FIELD_STUDY_POINTS))
	add_research_work(node_id, points)
	return points

// The subject a thing teaches about, for someone who could research it now.
/proc/field_study_node(mob/living/human/H, atom/movable/A)
	if (!istype(H) || !istype(A) || !map || !map.book_research_enabled())
		return null
	var/node_id = get_recipe_node_req("[A.type]")
	if (!istext(node_id) || !get_research_node(node_id))
		return null
	if (H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id))
		return null
	return node_id

// Things near H worth studying, thing => subject.
/proc/field_study_targets(mob/living/human/H)
	var/list/found = list()
	if (!istype(H))
		return found
	for (var/atom/movable/A in range(FIELD_STUDY_RANGE, H))
		if (A == H || isturf(A) || ismob(A) || (A in list(H.l_hand, H.r_hand)))
			continue
		var/node_id = field_study_node(H, A)
		if (node_id)
			found[A] = node_id
	return found

/proc/field_study_carrier_ok(obj/item/carrier, node_id, kind)
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		return !istype(P, /obj/item/weapon/paper/research_page) && !P.demonstration_node && !P.field_study_node
	if (istype(carrier, /obj/item/weapon/book) && !istype(carrier, /obj/item/weapon/book/research/tree_book))
		var/obj/item/weapon/book/B = carrier
		return B.can_take_field_study(node_id, kind)
	return FALSE

// Writes a finished study down. No waiting here.
/proc/commit_field_study(mob/living/human/H, obj/item/carrier, node_id, kind, thing_name)
	var/datum/research_node/N = get_research_node(node_id)
	if (!istype(H) || !N || !field_study_carrier_ok(carrier, node_id, kind))
		return 0
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		P.field_study_node = node_id
		P.field_study_type = kind
		P.name = "field notes ([N.name])"
		P.desc = "Notes taken by [H.real_name] while studying \a [thing_name] for [N.name]. Use them on a research bench working on [N.name], with its book on the bench."
		P.update_icon()
		return 1
	var/obj/item/weapon/book/B = carrier
	return B.record_field_study(node_id, kind)

/mob/living/human/proc/study_in_field(obj/item/carrier)
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("There is nothing here to study."))
		return FALSE
	if (!(carrier in list(l_hand, r_hand)))
		to_chat(src, SPAN_WARNING("Hold \the [carrier] in your hand first."))
		return FALSE
	if (!held_writing_pen())
		to_chat(src, SPAN_WARNING("You need a pen or pencil in your other hand to take notes."))
		return FALSE
	var/list/found = field_study_targets(src)
	if (!found.len)
		to_chat(src, SPAN_WARNING("Nothing next to you belongs to a subject you could research now. Stand beside a building, machine or tool made with a subject whose groundwork you know."))
		return FALSE
	var/atom/movable/thing = null
	if (found.len == 1)
		thing = found[1]
	else
		var/list/names = list()
		for (var/atom/movable/A in found)
			var/datum/research_node/FN = get_research_node(found[A])
			names["[A.name] ([FN.name])"] = A
		var/choice = player_input(src, "What do you study?", "Study in the Field", null, "anything", names, TRUE)
		if (!choice)
			return FALSE
		thing = names[choice]
	var/node_id = found[thing]
	var/datum/research_node/N = get_research_node(node_id)
	var/kind = "[thing.type]"
	if (!field_study_carrier_ok(carrier, node_id, kind))
		to_chat(src, SPAN_WARNING("\The [carrier] can't take a study of \the [thing] for [N.name]. A book takes [FIELD_STUDY_MAX] different kinds of thing per subject, each once."))
		return FALSE
	visible_message(SPAN_NOTICE("[src] starts studying \the [thing] and taking notes."), SPAN_NOTICE("You start studying \the [thing] for <b>[N.name]</b>."))
	if (!do_reading(src, FIELD_STUDY_TIME, thing))
		to_chat(src, SPAN_WARNING("You stop before your notes are done."))
		return FALSE
	if (QDELETED(thing) || get_dist(src, thing) > FIELD_STUDY_RANGE || !(carrier in list(l_hand, r_hand)))
		to_chat(src, SPAN_WARNING("You lost sight of what you were studying."))
		return FALSE
	var/points = commit_field_study(src, carrier, node_id, kind, thing.name)
	if (!points)
		return FALSE
	if (istype(carrier, /obj/item/weapon/paper))
		to_chat(src, SPAN_NOTICE("You finish your field notes on \the [thing]. Use them on a research bench working on <b>[N.name]</b>."))
	else
		to_chat(src, SPAN_NOTICE("You write your study of \the [thing] into [carrier]: <b>[N.name]</b> advances by [points] points."))
	return TRUE

/obj/item/weapon/paper/verb/study_in_field_paper()
	set name = "Study in the Field"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.study_in_field(src)

/obj/item/weapon/book/verb/study_in_field_book()
	set name = "Study in the Field"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.study_in_field(src)

// Field notes used on a bench working on the same subject.
/obj/structure/research_bench/proc/take_field_notes(obj/item/weapon/paper/P, mob/living/human/user)
	if (!istype(P) || !P.field_study_node)
		return FALSE
	var/obj/item/weapon/book/B = placed_book()
	var/datum/research_node/N = get_research_node(P.field_study_node)
	if (!B || assigned_node != P.field_study_node || !N)
		to_chat(user, SPAN_WARNING("These notes are about [N ? N.name : "something else"]. Put a book on the bench and research that subject first."))
		return TRUE
	if (!B.can_take_field_study(N.id, P.field_study_type))
		to_chat(user, SPAN_WARNING("[B] already holds this study, or as many as it takes for <b>[N.name]</b>."))
		return TRUE
	if (!user.remove_from_mob(P))
		return TRUE
	var/kind = P.field_study_type
	qdel(P)
	var/points = B.record_field_study(N.id, kind)
	to_chat(user, SPAN_NOTICE("You copy the field notes into [B]: <b>[N.name]</b> advances by [points] points[B.has_research_chapter(N.id) ? " and the chapter is finished" : ""]."))
	book_refresh_ui()
	return TRUE

#undef SUBJECT_PROTO_SHARE
#undef SUBJECT_PROTO_POINTS
#undef SUBJECT_PROTO_MAX
#undef FIELD_STUDY_POINTS
#undef FIELD_STUDY_MAX
#undef FIELD_STUDY_RANGE
#undef FIELD_STUDY_TIME
