// ============================================================
// Research Tree - book research interface helpers
// ------------------------------------------------------------
// Data and one-click actions for the research bench screen and the book
// window in book research. Nothing here changes what research costs or who
// may do it: every action runs the same procs as the older menus.
// ============================================================

#define BOOK_QUEUE_MAX 12

/proc/ui_minutes(deciseconds)
	return max(0.5, round(deciseconds / 600, 0.5))

// ------------------------------------------------------------
// Blank sheets
// ------------------------------------------------------------

/mob/living/human/proc/blank_sheet_count()
	var/count = 0
	for (var/obj/item/weapon/paper/P in get_contents())
		if (blank_writing_sheet(P))
			count++
	for (var/obj/item/weapon/paper_bundle/B in get_contents())
		count += length(bundle_blank_sheets(B))
	return count

// Check the hands without touching inventory; the write menu uses this too.
/mob/living/human/proc/held_blank_sheet()
	for (var/obj/item/weapon/paper/P in list(l_hand, r_hand))
		if (blank_writing_sheet(P))
			return P
	return null

// A blank sheet in hand for writing or copying. With none in hand and a hand
// free, one is taken out of the writer's pockets or bags.
/mob/living/human/proc/ready_blank_sheet()
	var/obj/item/weapon/paper/held = held_blank_sheet()
	if (held)
		return held
	if (l_hand && r_hand)
		return null
	for (var/obj/item/weapon/paper/P in get_contents())
		if (!blank_writing_sheet(P))
			continue
		var/obj/item/weapon/storage/S = P.loc
		if (istype(S))
			if (!S.remove_from_storage(P, get_turf(src)))
				continue
		else if (P.loc == src)
			remove_from_mob(P)
		else
			continue
		put_in_hands(P)
		if (recipe_held(src, P))
			to_chat(src, SPAN_NOTICE("You take out a blank sheet."))
			return P
		return null
	// Bundles in hand or carried loose; a free hand takes one sheet off.
	for (var/obj/item/weapon/paper_bundle/B in get_contents())
		var/list/sheets = bundle_blank_sheets(B)
		if (!sheets.len)
			continue
		var/obj/item/weapon/paper/P = sheets[1]
		var/bundle_name = B.name
		if (!bundle_unclip_sheet(B, P))
			continue
		put_in_hands(P)
		if (recipe_held(src, P))
			to_chat(src, SPAN_NOTICE("You take a blank sheet off the [bundle_name]."))
			return P
		return null
	return null

// ------------------------------------------------------------
// What a reader can do with one chapter
// ------------------------------------------------------------

// "known", "study" (can be studied now) or "locked" (needs groundwork).
/proc/chapter_reader_state(mob/living/human/H, node_id)
	if (H.knows_recipe_node(node_id))
		return "known"
	return H.knows_research_prereqs(node_id) ? "study" : "locked"

// The groundwork of a node: list(list("id", "name", "known")).
/proc/node_groundwork_rows(mob/living/human/H, datum/research_node/N)
	var/list/rows = list()
	for (var/req in N.prereqs)
		var/datum/research_node/RN = get_research_node(req)
		rows += list(list("id" = req, "name" = RN ? RN.name : req, "known" = H.knows_recipe_node(req) ? 1 : 0))
	return rows

// Scholarship a node needs to be researched: list(list("label", "ok")).
/proc/node_scholar_rows(mob/living/human/H, node_id)
	var/list/rows = list()
	var/req = node_scholar_requirement(node_id)
	if (!req)
		return rows
	var/discipline = node_discipline(node_id)
	var/level = round(H.scholar_level(discipline))
	rows += list(list("label" = "[scholar_disciplines[discipline]] [req] (you have [level])", "ok" = H.scholar_level(discipline) >= req ? 1 : 0))
	if (discipline != "mathematics")
		var/math = round(H.scholar_level("mathematics"))
		rows += list(list("label" = "Basic Mathematics [round(req / 2)] (you have [math])", "ok" = H.scholar_level("mathematics") >= req / 2 ? 1 : 0))
	return rows

// ------------------------------------------------------------
// Bench screen data
// ------------------------------------------------------------

// Extra fields for one node on the bench screen in book mode. cache carries
// values that are the same for every node of one refresh.
/obj/structure/research_bench/proc/book_node_ui(mob/living/human/H, node_id, list/cache)
	var/list/out = list()
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return out
	var/list/books = cache["books"]
	var/obj/item/weapon/book/target = books.len ? books[1] : null
	var/known = H.knows_recipe_node(node_id)
	var/groundwork = H.knows_research_prereqs(node_id)
	var/skilled = H.meets_scholar_requirement(node_id)
	var/tier_ok = N.min_bench_tier <= bench_tier()
	var/holder = 0
	var/lacking = 0
	for (var/i = 1, i <= books.len, i++)
		var/obj/item/weapon/book/B = books[i]
		if (B.has_research_chapter(node_id))
			if (!holder)
				holder = i
		else if (!lacking)
			lacking = i
	var/ticks = target ? target.research_ticks(node_id) : 0
	var/percent = N.cost_ticks ? round(ticks / N.cost_ticks * 100) : 0
	var/state
	var/label
	if (known)
		state = "known"
		label = "Known"
	else if (holder)
		state = groundwork ? "study" : "study_locked"
		label = groundwork ? (H.study_fraction(node_id) > 0 ? "Chapter here, [H.study_percent(node_id)]% read" : "Chapter ready to study") : "Chapter here, needs groundwork"
	else if (ticks > 0)
		state = "progress"
		label = "[percent]% written"
	else if (!groundwork)
		state = "locked"
		label = "Needs groundwork"
	else if (N.mode == RESEARCH_MODE_BOOK)
		state = "blocked"
		label = "Only found in books"
	else if (!tier_ok)
		state = "blocked"
		label = "Needs a later era"
	else if (!skilled)
		state = "blocked"
		label = "Needs more scholarship"
	else
		state = "ready"
		label = "Can be researched"
	out["state"] = state
	out["state_label"] = label
	out["era_name"] = research_era_label(N)
	var/discipline = node_discipline(node_id)
	out["discipline"] = scholar_disciplines[discipline]
	out["groundwork"] = node_groundwork_rows(H, N)
	var/list/needs = node_scholar_rows(H, node_id)
	if (N.min_bench_tier > 0)
		needs += list(list("label" = "Bench tier [N.min_bench_tier] (this bench is tier [bench_tier()])", "ok" = tier_ok ? 1 : 0))
	if (node_needs_instrument(node_id))
		var/list/instruments = cache["instruments"]
		if (isnull(instruments[discipline]))
			instruments[discipline] = has_research_instrument(node_id, H) ? 1 : 0
		needs += list(list("label" = "[capitalize(scholar_instrument_text(discipline))] on or next to the bench", "ok" = instruments[discipline]))
	if (N.mode == RESEARCH_MODE_PROTOTYPE)
		needs += list(list("label" = prototype_need_label(N), "ok" = target && target.research_prototype_installed(node_id) ? 1 : 0))
	needs += bill_rows(target, node_id)
	if (is_big_science(node_id))
		needs += team_rows(node_id, null)
	out["research_needs"] = needs
	var/desk = cache["desk_rate"]
	out["study_minutes"] = ui_minutes(H.study_time_left(node_id, BOOK_STUDY_TIME(N.era_tier) * knowledge_study_mult(node_id) / desk))
	out["read_percent"] = state == "study" ? H.study_percent(node_id) : 0
	var/list/supplies = cache["supplies"]
	var/supplied = islist(supplies) ? (supplies[discipline] || 0) >= 1 : TRUE
	var/pace = base_tick_rate * H.scholar_research_rate(node_id) * max(cache["tool_rate"], 1) * late_bench_rate(N) * knowledge_rediscovery_rate(node_id) * (supplied ? 1 : SCHOLAR_UNSUPPLIED_RATE)
	out["field_work"] = field_work_rows(H, node_id)
	out["research_minutes"] = pace > 0 ? ui_minutes((N.cost_ticks - ticks) / pace * RESEARCH_TICK_INTERVAL) : 0
	out["write_minutes"] = ui_minutes(BOOK_WRITE_TIME(N.era_tier) / max(cache["pen_rate"], 1) / desk)
	out["holder"] = holder
	out["can_study"] = state == "study" ? 1 : 0
	out["can_copy"] = holder && lacking && books.len >= 2 ? 1 : 0
	out["can_write"] = known && lacking ? 1 : 0
	var/list/queue = cache["queue"]
	out["queue_pos"] = queue.Find(node_id)
	out["queueable"] = N.mode != RESEARCH_MODE_BOOK && node_id != assigned_node && !(node_id in queue) && queue.len < BOOK_QUEUE_MAX && !(target && target.has_research_chapter(node_id)) ? 1 : 0
	return out

// Whoever would push node_id forward at this bench right now, and how fast:
// list(researcher, rate), or null. The same choice the research tick makes.
/obj/structure/research_bench/proc/book_working_researcher(node_id)
	var/mob/living/human/researcher = null
	var/best_rate = 0
	for (var/mob/living/human/H in range(BOOK_RESEARCH_NEAR, src))
		if (!H.can_research_node_at(src, node_id, TRUE))
			continue
		var/rate = lead_pace(H, node_id)
		if (rate > best_rate)
			researcher = H
			best_rate = rate
	return researcher ? list(researcher, best_rate) : null

// What sets the pace right now, one line each, for the bench window. Each is
// list(label, effect, 1 good / 0 holding the work back).
/obj/structure/research_bench/proc/book_pace_factors(datum/research_node/N, mob/living/human/researcher, lead_rate, supply, library)
	var/list/factors = list()
	var/tool = lead_tool_rate(researcher)
	var/skill = researcher.scholar_research_rate(N.id)
	factors += list(list("label" = "[researcher.name]'s scholarship", "effect" = "x[round(skill, 0.01)]", "ok" = skill >= 1 ? 1 : 0))
	factors += list(list("label" = researcher.research_tool_rate() >= tool ? "Writing tool in hand" : "Writing tool resting on the bench", "effect" = "x[round(tool, 0.01)]", "ok" = 1))
	factors += list(list("label" = "Supplies on the bench", "effect" = supply >= 1 ? "full speed" : "half speed until some are set out", "ok" = supply >= 1 ? 1 : 0))
	factors += list(list("label" = "Related chapters shelved within 3 tiles", "effect" = library > 1 ? "[round((library - 1) * 100)]% faster" : "none, no change", "ok" = 1))
	var/away = get_dist(researcher, src) > BOOK_RESEARCH_REACH
	factors += list(list("label" = away ? "Working near the bench, not at it" : "Standing at the bench", "effect" = away ? "x[BOOK_RESEARCH_AWAY_RATE]" : "full speed; x[BOOK_RESEARCH_AWAY_RATE] up to [BOOK_RESEARCH_NEAR] tiles off", "ok" = 1))
	var/team = team_rate(N.id, researcher)
	if (team != 1)
		factors += list(list("label" = team > 1 ? "Other scholars helping" : "Too few hands or no facility", "effect" = "x[round(team, 0.01)]", "ok" = team > 1 ? 1 : 0))
	else if (!is_big_science(N.id))
		factors += list(list("label" = "Other scholars helping", "effect" = "none; each one who could research this adds up to half, 2 at most", "ok" = 1))
	var/late = late_bench_rate(N)
	if (late != 1)
		factors += list(list("label" = "Late subject", "effect" = "x[late]", "ok" = 1))
	var/rediscovery = knowledge_rediscovery_rate(N.id)
	if (rediscovery != 1)
		factors += list(list("label" = "Spreading knowledge, already known in the world", "effect" = "x[rediscovery]", "ok" = 1))
	if (rush_rate(N) != 1)
		factors += list(list("label" = "Rushed", "effect" = "x[rush_rate(N)]", "ok" = 1))
	return factors

// The "Currently researching" panel: progress, pace and a checklist of what
// the work needs, each line marked met or not.
/obj/structure/research_bench/proc/book_assigned_ui(mob/living/human/H)
	var/datum/research_node/N = assigned_node ? get_research_node(assigned_node) : null
	if (!N)
		return null
	var/obj/item/weapon/book/B = placed_book()
	var/list/out = list("id" = assigned_node, "name" = N.name)
	if (B && B.has_research_chapter(assigned_node))
		out["done"] = 1
		out["percent"] = 100
		out["can_study"] = chapter_reader_state(H, assigned_node) == "study"
		return out
	var/ticks = B ? B.research_ticks(assigned_node) : 0
	out["ticks"] = ticks
	out["cost"] = N.cost_ticks
	out["percent"] = N.cost_ticks ? round(ticks / N.cost_ticks * 100) : 0
	var/discipline = node_discipline(assigned_node)
	var/supply = supply_points(discipline)
	var/list/worker = book_working_researcher(assigned_node)
	var/mob/living/human/researcher = worker ? worker[1] : null
	var/instrument_ok = has_research_instrument(assigned_node, researcher ? researcher : H)
	var/lit = research_lit()
	var/list/checks = list()
	checks += list(list("label" = "A book on the bench to write in", "ok" = B ? 1 : 0))
	if (researcher)
		checks += list(list("label" = "[researcher == H ? "You are" : "[researcher.name] is"] working on it", "ok" = 1))
	else
		checks += list(list("label" = "A scholar within [BOOK_RESEARCH_NEAR] tiles and in sight of the bench", "ok" = 0))
		checks += list(list("label" = "You know its groundwork", "ok" = H.knows_research_prereqs(assigned_node) ? 1 : 0))
		checks += node_scholar_rows(H, assigned_node)
		checks += list(list("label" = "A pencil, pen or writing slate in your hand or resting on the bench", "ok" = lead_tool_rate(H) > 0 ? 1 : 0))
	if (N.min_bench_tier > 0)
		checks += list(list("label" = "Bench tier [N.min_bench_tier] (this bench is tier [bench_tier()])", "ok" = bench_tier() >= N.min_bench_tier ? 1 : 0))
	checks += list(list("label" = "Light to work by", "ok" = lit ? 1 : 0))
	if (node_needs_instrument(assigned_node))
		checks += list(list("label" = "[capitalize(scholar_instrument_text(discipline))] on or next to the bench", "ok" = instrument_ok ? 1 : 0))
	if (N.mode == RESEARCH_MODE_PROTOTYPE)
		checks += list(list("label" = prototype_need_label(N), "ok" = B && B.research_prototype_installed(assigned_node) ? 1 : 0))
	checks += bill_rows(B, assigned_node)
	checks += team_rows(assigned_node, researcher)
	out["checks"] = checks
	out["rushed"] = rushed ? 1 : 0
	out["can_rush"] = node_can_be_rushed(N) ? 1 : 0
	out["field_work"] = field_work_rows(H, assigned_node)
	out["supply"] = supply
	out["supply_cap"] = SCHOLAR_SUPPLY_CAP
	out["supply_text"] = "[scholar_disciplines[discipline]] supplies ([scholar_supply_text(discipline)])"
	var/library = library_rate(assigned_node)
	if (library > 1)
		out["library_bonus"] = round((library - 1) * 100)
	var/working = researcher && B && lit && instrument_ok && bench_tier() >= N.min_bench_tier
	out["working"] = working ? 1 : 0
	if (working)
		out["factors"] = book_pace_factors(N, researcher, worker[2], supply, library)
		var/per_tick = round(base_tick_rate * worker[2] * late_bench_rate(N) * team_rate(assigned_node, researcher) * rush_rate(N) * library * (supply >= 1 ? 1 : SCHOLAR_UNSUPPLIED_RATE), 0.1)
		out["pace"] = per_tick
		if (per_tick > 0 && ticks < N.cost_ticks)
			out["eta_minutes"] = ui_minutes((N.cost_ticks - ticks) / per_tick * RESEARCH_TICK_INTERVAL)
	return out

// One book on the bench: its chapters marked for the viewer, its unfinished
// work, and how many of its chapters the other book lacks.
/obj/structure/research_bench/proc/book_row_ui(mob/living/human/H, list/books, index)
	var/obj/item/weapon/book/B = books[index]
	var/obj/item/weapon/book/other = books.len >= 2 ? books[index == 1 ? 2 : 1] : null
	var/list/chapters = list()
	var/missing = 0
	var/list/names = list()
	for (var/node_id in B.research_chapter_list())
		names[get_research_node(node_id).name] = node_id
	names = sortAssoc(names)
	for (var/name in names)
		var/node_id = names[name]
		var/other_lacks = other && !other.has_research_chapter(node_id)
		if (other_lacks)
			missing++
		chapters += list(list("id" = node_id, "name" = name, "state" = chapter_reader_state(H, node_id), "can_copy" = other_lacks ? 1 : 0))
	var/list/unfinished = list()
	var/list/progress = B.research_progress_map()
	for (var/node_id in progress)
		var/datum/research_node/N = get_research_node(node_id)
		var/list/entry = progress[node_id]
		if (!N || entry[1] <= 0)
			continue
		unfinished += list(list("id" = node_id, "name" = N.name, "percent" = round(entry[1] / N.cost_ticks * 100)))
	return list("name" = "[B.name]", "idx" = index, "is_target" = index == 1 ? 1 : 0, "chapters" = chapters, "unfinished" = unfinished, "copy_missing" = missing, "other_name" = other ? "[other.name]" : null)

// What the viewer brings to the bench.
/proc/book_viewer_ui(mob/living/human/H)
	var/list/skills = list()
	for (var/discipline in scholar_disciplines)
		skills += list(list("name" = scholar_disciplines[discipline], "level" = round(H.scholar_level(discipline))))
	var/obj/item/tool = scholar_tool_rate(H.l_hand) >= scholar_tool_rate(H.r_hand) ? H.l_hand : H.r_hand
	if (scholar_tool_rate(tool) <= 0)
		tool = null
	var/obj/item/weapon/pen/pen = H.held_writing_pen()
	return list(
		"tool" = tool ? "[tool.name]" : null,
		"pen" = pen ? "[pen.name]" : null,
		"sheets" = H.blank_sheet_count(),
		"desk" = H.at_writing_desk() ? 1 : 0,
		"skills" = skills)

// ------------------------------------------------------------
// Queue in book mode
// ------------------------------------------------------------

// When the bench is idle (no subject, or its chapter is finished), start the
// next queued subject this bench can work on. Subjects the research book
// already holds are dropped; ones needing a better bench wait their turn.
/obj/structure/research_bench/proc/book_advance_queue()
	if (!length(research_queue))
		return FALSE
	var/obj/item/weapon/book/B = placed_book()
	if (!B)
		return FALSE
	if (assigned_node && get_research_node(assigned_node) && !B.has_research_chapter(assigned_node))
		return FALSE
	var/list/q = queue_list()
	var/list/keep = list()
	var/started = null
	for (var/node_id in q)
		if (!valid_recipe_node_id(node_id) || B.has_research_chapter(node_id))
			continue
		if (!started && book_can_assign_node(node_id))
			started = node_id
			continue
		keep += node_id
	set_queue(keep)
	if (!started)
		return FALSE
	assigned_node = started
	studied_samples = null
	return TRUE

/obj/structure/research_bench/proc/book_queue_node(mob/living/human/H, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || N.mode == RESEARCH_MODE_BOOK)
		return
	var/obj/item/weapon/book/B = placed_book()
	if (B && B.has_research_chapter(node_id))
		to_chat(H, SPAN_WARNING("[B] already holds the chapter on <b>[N.name]</b>."))
		return
	if (node_id == assigned_node)
		to_chat(H, SPAN_WARNING("This bench is already researching <b>[N.name]</b>."))
		return
	var/list/q = queue_list()
	if (node_id in q)
		to_chat(H, SPAN_WARNING("<b>[N.name]</b> is already queued here."))
		return
	if (q.len >= BOOK_QUEUE_MAX)
		to_chat(H, SPAN_WARNING("The queue is full."))
		return
	q += node_id
	set_queue(q)
	to_chat(H, SPAN_NOTICE("Queued <b>[N.name]</b>. The bench moves on to it when the current chapter is finished."))
	book_advance_queue()

/obj/structure/research_bench/proc/book_unqueue_node(mob/living/human/H, node_id)
	var/list/q = queue_list()
	if (!(node_id in q))
		return
	q -= node_id
	set_queue(q)

/obj/structure/research_bench/proc/book_stop_research(mob/living/human/H)
	if (!assigned_node)
		return
	var/datum/research_node/N = get_research_node(assigned_node)
	assigned_node = null
	studied_samples = null
	to_chat(H, SPAN_NOTICE("The bench stops researching[N ? " <b>[N.name]</b>" : ""]. Work already written stays in the book."))

// ------------------------------------------------------------
// One-click chapter actions at the bench
// ------------------------------------------------------------

/obj/structure/research_bench/proc/book_study_node(mob/living/human/H, node_id)
	for (var/obj/item/weapon/book/B in placed_books())
		if (B.has_research_chapter(node_id))
			return study_research_source(H, B, node_id)
	to_chat(H, SPAN_WARNING("No book on the bench holds that chapter."))
	return FALSE

// The pair of books to copy node_id between: list(source, dest), or null.
/obj/structure/research_bench/proc/book_copy_pair(node_id)
	var/list/books = placed_books()
	if (books.len < 2)
		return null
	var/obj/item/weapon/book/A = books[1]
	var/obj/item/weapon/book/B = books[2]
	if (A.has_research_chapter(node_id) && !B.has_research_chapter(node_id))
		return list(A, B)
	if (B.has_research_chapter(node_id) && !A.has_research_chapter(node_id))
		return list(B, A)
	return null

/obj/structure/research_bench/proc/book_copy_node(mob/living/human/H, node_id)
	var/list/pair = book_copy_pair(node_id)
	if (!pair)
		to_chat(H, SPAN_WARNING("That chapter can't be copied between the books on the bench."))
		return FALSE
	return book_copy_job(H, pair[1], pair[2], node_id)

// Copy every chapter the other book lacks, one after another, for as long as
// the scribe has blank sheets and stamina. Moving away stops it.
/obj/structure/research_bench/proc/book_copy_all(mob/living/human/H, source_index)
	var/list/books = placed_books()
	if (books.len < 2 || (source_index != 1 && source_index != 2))
		to_chat(H, SPAN_WARNING("Place two books on the bench to copy between them."))
		return 0
	var/obj/item/weapon/book/source = books[source_index]
	var/obj/item/weapon/book/dest = books[source_index == 1 ? 2 : 1]
	var/copied = 0
	for (var/node_id in source.research_chapter_list())
		if (dest.has_research_chapter(node_id))
			continue
		if (source.loc != src || dest.loc != src || !in_range(src, H) || H.incapacitated())
			break
		if (!book_copy_job(H, source, dest, node_id))
			break
		copied++
	if (copied)
		to_chat(H, SPAN_NOTICE("You copied [copied] chapter\s into [dest]."))
	return copied

// Write a chapter the scholar knows straight into a book on the bench.
/obj/structure/research_bench/proc/book_write_node(mob/living/human/H, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !H.knows_recipe_node(node_id))
		to_chat(H, SPAN_WARNING("You can only write down what you know."))
		return FALSE
	var/obj/item/weapon/book/dest = null
	for (var/obj/item/weapon/book/B in placed_books())
		if (!B.has_research_chapter(node_id))
			dest = B
			break
	if (!dest)
		to_chat(H, SPAN_WARNING("The books on the bench already hold that chapter."))
		return FALSE
	var/obj/item/weapon/pen/pen = H.held_writing_pen()
	if (!pen)
		to_chat(H, SPAN_WARNING("Hold a pencil or pen to write with."))
		return FALSE
	var/done = dest.write_research_chapter(H, pen, node_id, src)
	book_refresh_ui()
	return done

// ------------------------------------------------------------
// The book window
// ------------------------------------------------------------
// Using a book that holds research (or Alt-clicking one within reach) opens
// a window listing its chapters for the reader, with what each one needs and
// teaches, and buttons to study, write or tear out a chapter.

/datum/topic_state/research_book/can_use_topic(var/src_object, var/mob/user)
	var/obj/item/weapon/book/B = src_object
	if (!istype(B) || !ishuman(user) || !map || !map.book_research_enabled() || !B.can_hold_research())
		return STATUS_CLOSE
	. = user.shared_nano_interaction()
	if (. == STATUS_CLOSE)
		return
	if (B.loc == user || (isturf(B.loc) && user.Adjacent(B)))
		return
	return STATUS_CLOSE

/var/global/datum/topic_state/research_book/research_book_state = new()

// The menu and its action share these non-mutating hand checks.
/obj/item/weapon/book/proc/research_book_write_hands_problem(mob/living/human/H)
	if (!H.l_hand || !H.r_hand)
		return null
	if (loc == H)
		return "Put [src] down beside you first: writing needs the pen in one hand and a blank sheet in the other."
	if (!H.held_blank_sheet())
		return "Free the hand opposite your pen, or hold a blank sheet in it."
	return null

/obj/item/weapon/book/proc/research_book_ui_data(mob/living/human/H)
	var/list/data = list()
	data["name"] = "[name]"
	data["author"] = author ? "[author]" : null
	data["has_text"] = dat ? 1 : 0
	data["held"] = loc == H ? 1 : 0
	// Reading notes shown at the top of the book: its cipher and the
	// languages its chapters are written in (book_language.dm).
	var/list/reading_notes = list()
	if (is_enciphered())
		reading_notes += can_read_cipher(H) ? "Written in cipher (strength [cipher_strength]). You can read it." : "Written in cipher (strength [cipher_strength]). You cannot study, copy or tear out its chapters until you enter its key word or break the cipher: write in it with a pen and choose Cipher."
	var/language_note = chapter_language_note(H)
	if (language_note)
		reading_notes += language_note
	if (reading_notes.len)
		data["cipher_note"] = jointext(reading_notes, " ")
	var/desk = H.scholar_desk_rate()
	var/obj/item/weapon/pen/pen = H.held_writing_pen()
	var/pen_rate = pen ? scholar_pen_rate(pen) : 1
	// Parse the saved language table once, not once per chapter row.
	var/list/written_languages = chapter_language_map()
	var/cipher_blocks_reader = cipher_blocks(H)
	var/list/names = list()
	for (var/node_id in research_chapter_list())
		names[get_research_node(node_id).name] = node_id
	names = sortAssoc(names)
	var/list/chapters = list()
	for (var/name in names)
		var/node_id = names[name]
		var/datum/research_node/N = get_research_node(node_id)
		var/state = chapter_reader_state(H, node_id)
		var/datum/language/written_in = written_languages[node_id] ? all_languages[written_languages[node_id]] : null
		var/read_problem
		if (state != "known")
			read_problem = cipher_blocks_reader ? "Decipher this book before studying its chapters." : language_reading_problem(H, written_in, LANGUAGE_BROKEN)
			if (state == "study" && read_problem)
				state = "blocked"
		var/list/row = list(
			"id" = node_id,
			"name" = name,
			"state" = state,
			"category" = N.category,
			"era_name" = research_era_label(N),
			"discipline" = scholar_disciplines[node_discipline(node_id)],
			"groundwork" = node_groundwork_rows(H, N),
			"read_problem" = read_problem,
			"read_percent" = state == "study" ? H.study_percent(node_id) : 0,
			"recipe_names" = get_node_recipe_names(node_id),
			"effect" = research_node_effect_text(node_id))
		if (state == "study")
			var/mob/living/human/tutor = H.find_tutor(node_id)
			var/time = research_chapter_study_time(H, N, written_in, tutor)
			row["study_minutes"] = H.study_minutes_estimate(H.study_time_left(node_id, time))
			if (tutor)
				row["tutor"] = "[tutor.name]"
		chapters += list(row)
	data["chapters"] = chapters
	var/list/unfinished = list()
	var/list/progress = research_progress_map()
	for (var/node_id in progress)
		var/datum/research_node/N = get_research_node(node_id)
		var/list/entry = progress[node_id]
		if (!N)
			continue
		unfinished += list(list("id" = node_id, "name" = N.name, "percent" = round(entry[1] / N.cost_ticks * 100), "ticks" = entry[1], "cost" = N.cost_ticks, "prototype" = N.mode == RESEARCH_MODE_PROTOTYPE ? (node_needs_demonstration(node_id) ? "demonstration" : N.prototype_display_name()) : null, "prototype_done" = entry[2] ? 1 : 0, "protos_made" = prototype_progress(node_id)[1], "protos_max" = prototype_progress(node_id)[2]))
	data["unfinished"] = unfinished
	var/list/writable = list()
	if (!H.recipe_knowledge_exempt())
		var/list/known = list()
		for (var/node_id in clean_recipe_node_ids(H.known_recipe_nodes))
			if (!has_research_chapter(node_id))
				known[get_research_node(node_id).name] = node_id
		known = sortAssoc(known)
		for (var/name in known)
			var/datum/research_node/N = get_research_node(known[name])
			writable += list(list("id" = known[name], "name" = name, "era_name" = research_era_label(N), "write_minutes" = ui_minutes(BOOK_WRITE_TIME(N.era_tier) / pen_rate / desk), "stamina" = BOOK_WRITE_STAMINA(N.era_tier)))
	data["writable"] = writable
	var/list/viewer = book_viewer_ui(H)
	viewer["stamina"] = round(H.stats["stamina"][1])
	viewer["write_hands_problem"] = research_book_write_hands_problem(H)
	data["viewer"] = viewer
	data["busy"] = page_busy ? 1 : 0
	return data

/obj/item/weapon/book/ui_actions(ui_key)
	if (ui_key == "research_book")
		return list("study", "write", "rip", "read", "aloud")
	return ..()

/obj/item/weapon/book/ui_interact(mob/user, ui_key = "research_book", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = default_state)
	var/mob/living/human/H = user
	if (!istype(H) || ui_key != "research_book" || !map || !map.book_research_enabled() || !can_hold_research())
		return
	var/list/data = research_book_ui_data(H)
	// Closing the book window must not unset an unrelated machine interaction.
	open_tgui(user, ui_key, "research_book.tmpl", "Book", 620, 660, data, ui, force_open, research_book_state, keep_interaction = TRUE)

/obj/item/weapon/book/Topic(href, href_list, var/datum/topic_state/state = default_state)
	if (!href_list["study"] && !href_list["write"] && !href_list["rip"] && !href_list["read"] && !href_list["aloud"])
		return ..()
	var/mob/living/human/H = usr
	if (!istype(H) || research_book_state.can_use_topic(src, H) != STATUS_INTERACTIVE)
		return FALSE
	if (href_list["read"])
		if (dat)
			H.examinate(src)
		return FALSE
	if (href_list["aloud"])
		read_chapter_aloud(H, href_list["aloud"])
	else if (href_list["study"])
		study_research_source(H, src, href_list["study"])
	else if (href_list["write"])
		var/obj/item/weapon/pen/pen = H.held_writing_pen()
		var/hands_problem = research_book_write_hands_problem(H)
		if (!pen)
			to_chat(H, SPAN_WARNING("Hold a pencil or pen to write with."))
		else if (hands_problem)
			to_chat(H, SPAN_WARNING(hands_problem))
		else
			write_research_chapter(H, pen, href_list["write"])
	else if (href_list["rip"])
		if (!page_busy && can_hold_notes() && has_research_chapter(href_list["rip"]))
			rip_page(H, href_list["rip"])
	return TRUE

// Alt-click a book within reach to open its window without picking it up, so
// a chapter can be written with a pen in one hand and a sheet in the other.
/obj/item/weapon/book/AltClick(mob/user)
	if (ishuman(user) && user.client && research_book_state.can_use_topic(src, user) == STATUS_INTERACTIVE)
		ui_interact(user)
		return
	return ..()
