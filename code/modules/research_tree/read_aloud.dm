// ------------------------------------------------------------
// Research Tree - reading a chapter aloud (Val, 2026-11-17)
// ------------------------------------------------------------
// Someone who knows a chapter reads it from a book. Everyone within hearing
// range of the reader (normal speech range; walls and rooms do not matter)
// who could study the chapter gains study progress at half the pace of
// reading it themselves, and can keep working while they listen. It is the
// same progress record as reading (study_progress.dm), so a listener can
// finish the chapter from a book later, or the other way round.
//
// It also carries over radio and television: when the reader is presenting
// at a broadcast station, everyone beside a set tuned to it hears the
// reading too (the receiver rules of node_broadcast.dm). Other lands hear it
// only through player relay stations, as with all radio.

#define READ_ALOUD_RANGE 7
#define READ_ALOUD_RATE 0.5
#define READ_ALOUD_STEP 50 // deciseconds between credits
#define READ_ALOUD_MAX_LISTENERS 32
#define READ_ALOUD_IDLE_STEPS 6 // the reader stops after this many steps with nobody learning

/mob/living/human/var/tmp/reading_aloud = FALSE

/mob/living/human/proc/can_hear_reading()
	return stat == CONSCIOUS && !sleeping && !(sdisabilities & DEAF) && !ear_deaf && !find_trait("Deaf")

// Whether L gains anything from hearing node_id read by reader.
/proc/read_aloud_listener(mob/living/human/L, mob/living/human/reader, node_id)
	return istype(L) && L != reader && !QDELETED(L) && L.can_hear_reading() && !L.knows_recipe_node(node_id) && L.knows_research_prereqs(node_id)

// Everyone who hears this reader and could learn node_id from it.
/mob/living/human/proc/read_aloud_audience(node_id)
	var/list/audience = list()
	for (var/mob/living/human/L in range(READ_ALOUD_RANGE, src))
		if (audience.len >= READ_ALOUD_MAX_LISTENERS)
			return audience
		if (read_aloud_listener(L, src, node_id))
			audience += L
	// On the air: the sets tuned to a station this reader is presenting at.
	for (var/obj/structure/telecom/station/S in range(1, src))
		if (S.presenter != src || !S.can_present(src) || !S.operational() || !S.has_antenna())
			continue
		for (var/obj/structure/telecom/R in civ_telecom_devices)
			if (!S.node_receiver_available(R))
				continue
			for (var/mob/living/human/L in view(3, R))
				if (audience.len >= READ_ALOUD_MAX_LISTENERS)
					return audience
				if (!(L in audience) && read_aloud_listener(L, src, node_id))
					audience += L
	return audience

// One step of listening. Returns TRUE when it finished the chapter.
/mob/living/human/proc/hear_chapter_read(node_id, heard_time, mob/living/human/reader)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || heard_time <= 0)
		return FALSE
	var/total = scholar_study_time(N.era_tier, node_id)
	if (total <= 0)
		return FALSE
	var/before = study_fraction(node_id)
	var/after = before + heard_time * READ_ALOUD_RATE / total
	// Fraction arithmetic uses single precision. A full sequence of credits
	// may land slightly below 1. Treat less than half a decisecond remaining
	// as complete, below the resolution of the study timer.
	if ((1 - after) * total < 0.5)
		if (learn_recipe_node(node_id))
			gain_scholarship(node_id, SCHOLAR_STUDY_GAIN)
			philosophy_from_study(node_id)
			to_chat(src, SPAN_NOTICE("You have learned <b>[N.name]</b> from listening to [reader]."))
			return TRUE
		return FALSE
	note_study_progress(node_id, after)
	last_study_discipline = node_discipline(node_id)
	if (before <= 0)
		to_chat(src, SPAN_NOTICE("[reader] is reading the chapter on <b>[N.name]</b> aloud. You take it in at half the pace of reading it yourself, and can keep working while you listen."))
	return FALSE

// Shared by admission and the credit loop so going silent mid-read stops teaching.
/obj/item/weapon/book/proc/read_aloud_speaker_problem(mob/living/human/H)
	if (H.stat != CONSCIOUS || H.incapacitated() || H.sleeping)
		return "You are in no state to read aloud."
	// Match normal human speech restrictions (human/say.dm), plus muzzle/choke.
	if (H.is_muzzled() || H.choked_by || H.silent || (H.sdisabilities & MUTE) || H.find_trait("Mute"))
		return "You can't speak."
	return null

// Why H can't read node_id aloud from this book right now, or null.
/obj/item/weapon/book/proc/read_aloud_problem(mob/living/human/H, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !holds_research_chapter(node_id))
		return "That chapter is not in this book."
	if (!H.knows_recipe_node(node_id))
		return "You can only read aloud a chapter you already know. Study it first."
	if (loc != H)
		return "Hold the book to read from it."
	var/speaker_problem = read_aloud_speaker_problem(H)
	if (speaker_problem)
		return speaker_problem
	if (H.reading_aloud)
		return "You are already reading aloud."
	return H.reading_light_problem()

// Reads node_id aloud until the reader stops, the light fails or nobody
// within hearing has anything left to learn. Returns how many finished it.
/obj/item/weapon/book/proc/read_chapter_aloud(mob/living/human/H, node_id)
	if (!istype(H) || !map || !map.book_research_enabled())
		return 0
	if (cipher_refuses(H))
		return 0
	var/problem = read_aloud_problem(H, node_id)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return 0
	var/datum/research_node/N = get_research_node(node_id)
	if (!H.read_aloud_audience(node_id).len)
		to_chat(H, SPAN_WARNING("Nobody within hearing could learn [N.name] right now. Listeners must know its groundwork and not know the chapter yet."))
		return 0
	H.reading_aloud = TRUE
	H.visible_message(SPAN_NOTICE("[H] opens [src] and begins reading the chapter on [N.name] aloud."), SPAN_NOTICE("You begin reading the chapter on [N.name] aloud. Stay put and keep the book in hand; move to stop."))
	var/finished = 0
	var/idle = 0
	var/list/taught = list()
	while (idle < READ_ALOUD_IDLE_STEPS)
		if (!do_reading(H, READ_ALOUD_STEP, src))
			break
		if (QDELETED(src) || loc != H || !holds_research_chapter(node_id) || read_aloud_speaker_problem(H))
			break
		var/list/audience = H.read_aloud_audience(node_id)
		if (!audience.len)
			idle++
			continue
		idle = 0
		for (var/mob/living/human/L in audience)
			if (L.hear_chapter_read(node_id, READ_ALOUD_STEP, H))
				finished++
				taught += L
				H.gain_scholarship(node_id, SCHOLAR_STUDY_GAIN * 0.25)
				H.philosophy_from_tutoring(node_id, L)
				to_chat(H, SPAN_NOTICE("[L] has learned [N.name] from your reading."))
	H.reading_aloud = FALSE
	to_chat(H, SPAN_NOTICE(finished ? "You stop reading. [finished] listener\s learned [N.name]; anyone else keeps the part they heard." : "You stop reading. Your listeners keep the part they heard and can finish it later, from you or from any copy."))
	return finished

/obj/item/weapon/book/verb/read_aloud_verb()
	set name = "Read Chapter Aloud"
	set category = null
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || !map || !map.book_research_enabled())
		return
	var/list/choices = list()
	for (var/node_id in research_chapter_list())
		if (H.knows_recipe_node(node_id))
			choices[get_research_node(node_id).name] = node_id
	if (!choices.len)
		to_chat(H, SPAN_WARNING("You don't know any chapter in [src] well enough to read it aloud."))
		return
	var/pick = player_input(H, "Which chapter will you read aloud? Everyone within hearing who could study it learns it at half pace while they work.", "Read aloud", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices) || loc != H)
		return
	read_chapter_aloud(H, choices[pick])

#undef READ_ALOUD_RANGE
#undef READ_ALOUD_RATE
#undef READ_ALOUD_STEP
#undef READ_ALOUD_MAX_LISTENERS
#undef READ_ALOUD_IDLE_STEPS
