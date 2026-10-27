// ============================================================
// Research Tree - research bench structure
// ------------------------------------------------------------
// Each bench is locked to ONE node and is a parallel research
// slot: a faction with N benches can progress N nodes at once.
// Benches generate analysis ticks passively (driven by
// /process/research_tree). Higher-tier benches are required for
// higher-tier nodes.
//
// Registered in a global list (no world scans). assigned_node,
// tier, faction and tier_progress persist automatically via the map
// object saver.
//
// Phase 0: placement, node assignment, passive ANALYSIS ticks.
// Phase 3: tier upgrades (feed any valuable item to the bench),
// the faction bench cap (see research_forge.dm to raise it), and
// the BOOK/PROTOTYPE completion paths (feed a matching research
// book or prototype item instead of raw value).
// ============================================================

var/global/list/research_benches = list()

/obj/structure/research_bench
	name = "research bench"
	desc = "A workbench for studying and developing new inventions. Assign it a subject and it will slowly make progress."
	icon = 'icons/obj/structures.dmi'
	icon_state = "researchdesk"
	density = TRUE
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/assigned_node = null   // node id this bench researches (persists)
	var/tier = 0               // bench tier; gates high min_bench_tier nodes (persists)
	var/faction = null         // owning faction, set on assignment (persists)
	var/base_tick_rate = 1     // analysis ticks contributed per process fire
	var/tier_progress = 0      // value fed toward the next tier (persists)
	// Queue of node ids to auto-advance to as the current subject completes,
	// stored as a ";"-delimited string so it persists via the map object saver
	// like the other string vars (a list var wouldn't survive the save).
	var/research_queue = ""
	var/tmp/writing = FALSE    // transcription in progress (tmp: never persists)
	// Item types already studied as samples toward the CURRENT assignment; each
	// type only teaches something once. tmp: resets on reboot, no need to persist.
	var/tmp/list/studied_samples = null

/obj/structure/research_bench/New()
	..()
	research_benches += src

/obj/structure/research_bench/Destroy()
	research_benches -= src
	..()

// Called by /process/research_tree once per analysis interval.
/obj/structure/research_bench/proc/analysis_tick()
	if (!faction || !map)
		return
	// If the current subject is finished (or empty), roll on to the next node
	// in the queue before doing anything else this tick.
	try_advance_queue()
	if (!assigned_node)
		return
	var/datum/research_node/N = get_research_node(assigned_node)
	if (!N)
		return
	// PROTOTYPE nodes still accumulate passive ticks like ANALYSIS ones --
	// submitting the matching prototype is a faster shortcut to completion,
	// not the only path, and this keeps notes/books written on prototype
	// techs meaningful trade goods (see attackby()'s notes/book handling).
	// BOOK-mode nodes are the one mode that stays tick-free by design: they
	// represent knowledge that can only be imported, never independently
	// discovered by a bench (no node currently uses this mode).
	if (N.mode == RESEARCH_MODE_BOOK)
		return
	if (tier < N.min_bench_tier)
		return
	if (map.is_node_done(faction, assigned_node))
		return
	if (!map.node_prereqs_met(faction, assigned_node))
		return
	// A faction can't research in absentia: passive study only happens while at
	// least one of its research-authorised members (Leader / Research Director /
	// Researcher) is actually connected. Stops the "queue everything then log off
	// to drag the whole server forward" exploit.
	if (!map.faction_has_active_researcher(faction))
		return
	map.add_research_ticks(faction, assigned_node, base_tick_rate)
	// Push a refresh to anyone currently viewing this bench. There's no
	// blind polling (see ui_interact()) -- this is the only thing that
	// changes this bench's own data outside of a player's own Topic() call
	// (which already triggers its own update), so it's also the only thing
	// that needs to trigger one here.
	GLOB.nanomanager.update_uis(src)

/obj/structure/research_bench/attack_hand(mob/user as mob)
	if (!ishuman(user))
		return ..()
	// Anyone can OPEN the bench to view the tree; acting on it is gated per
	// action (see can_manage_faction_research / try_claim below).
	ui_interact(user)

// Whether node_id is a valid research target for THIS bench's OWNING faction
// right now (tier + prereq/status). Permission to actually pick it is a
// separate check (can_manage_faction_research).
/obj/structure/research_bench/proc/can_assign_node(node_id)
	if (!map || !faction || faction == "none")
		return FALSE
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || N.min_bench_tier > tier)
		return FALSE
	var/status = map.node_status(faction, node_id)
	return status == RNODE_AVAILABLE || status == RNODE_IN_PROGRESS

/obj/structure/research_bench/proc/try_assign_node(mob/living/human/H, node_id)
	if (!map)
		return
	if (!map.can_manage_faction_research(H, faction))
		to_chat(H, SPAN_WARNING("Only your faction's Leader, [map.get_director_title(faction)], or a Researcher may change what this bench studies."))
		return
	if (!can_assign_node(node_id))
		to_chat(H, SPAN_WARNING("This bench can't research that right now."))
		return
	assigned_node = node_id
	studied_samples = null // a new subject: samples studied for the old one no longer apply
	var/datum/research_node/N = get_research_node(node_id)
	to_chat(H, SPAN_NOTICE("The bench is now researching <b>[N.name]</b> for the [faction]."))

// --- Research queue -------------------------------------------------------
// A ";"-delimited node-id string (persists) that the bench auto-advances
// through as subjects complete, so staff don't have to babysit every finish.

/obj/structure/research_bench/proc/queue_list()
	return research_queue ? splittext(research_queue, ";") : list()

/obj/structure/research_bench/proc/set_queue(list/L)
	research_queue = (L && L.len) ? jointext(L, ";") : ""

// If the current subject is done (or there is none), pull the next still-valid
// node off the queue and start it. Drops queued nodes that are already done;
// waits on ones that aren't assignable yet (locked prereqs / tier) rather than
// discarding them, so a researcher can queue ahead of prerequisites.
/obj/structure/research_bench/proc/try_advance_queue()
	if (!faction || !map)
		return
	if (assigned_node && !map.is_node_done(faction, assigned_node))
		return
	var/list/q = queue_list()
	while (q.len)
		var/next = q[1]
		if (map.is_node_done(faction, next))
			q.Cut(1, 2)
			continue
		if (!can_assign_node(next))
			break
		q.Cut(1, 2)
		assigned_node = next
		studied_samples = null
		set_queue(q)
		return
	set_queue(q)

/obj/structure/research_bench/proc/try_queue_node(mob/living/human/H, node_id)
	if (!map || !map.can_manage_faction_research(H, faction))
		to_chat(H, SPAN_WARNING("Only your faction's research staff may queue research here."))
		return
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return
	if (map.is_node_done(faction, node_id))
		to_chat(H, SPAN_WARNING("Your faction has already researched <b>[N.name]</b>."))
		return
	if (node_id == assigned_node)
		to_chat(H, SPAN_WARNING("This bench is already researching <b>[N.name]</b>."))
		return
	var/list/q = queue_list()
	if (node_id in q)
		to_chat(H, SPAN_WARNING("<b>[N.name]</b> is already in this bench's queue."))
		return
	q += node_id
	set_queue(q)
	// If the bench is idle (nothing assigned, or current already done), start now.
	try_advance_queue()
	to_chat(H, SPAN_NOTICE("Queued <b>[N.name]</b> on this bench."))

/obj/structure/research_bench/proc/clear_queue(mob/living/human/H)
	if (!map || !map.can_manage_faction_research(H, faction))
		return
	set_queue(null)
	to_chat(H, SPAN_NOTICE("Cleared this bench's research queue."))

// Claiming an abandoned bench: only if its owning faction no longer has any
// living members, and the claimer's faction is under its own bench cap.
/obj/structure/research_bench/proc/try_claim(mob/living/human/H)
	if (!map || !H.civilization || H.civilization == "none")
		to_chat(H, SPAN_WARNING("You must belong to a faction to claim a research bench."))
		return
	if (faction == H.civilization)
		return
	if (faction_is_extant(faction))
		to_chat(H, SPAN_WARNING("This bench still belongs to the [faction], who are still around."))
		return
	if (map.count_faction_benches(H.civilization) >= map.get_bench_cap(H.civilization))
		to_chat(H, SPAN_WARNING("Your faction already has as many research benches as it can support ([map.get_bench_cap(H.civilization)]). Build a resource forge to raise the cap."))
		return
	faction = H.civilization
	assigned_node = null // was another faction's research subject
	to_chat(H, SPAN_NOTICE("Your faction claims the abandoned research bench."))

// ------------------------------------------------------------
// Appointments (leader appoints director; leader/director appoint researchers)
// ------------------------------------------------------------
/obj/structure/research_bench/proc/pick_faction_member(mob/living/human/H, prompt, require_researcher = FALSE)
	var/list/choices = list("Cancel")
	for (var/mob/living/human/M in living_mob_list)
		if (M == H || M.civilization != faction)
			continue
		if (require_researcher && M.research_role != "researcher")
			continue
		choices += M
	if (choices.len <= 1)
		to_chat(H, SPAN_WARNING("There is nobody eligible for that."))
		return null
	var/choice = WWinput(H, prompt, "Research Staff", "Cancel", choices)
	if (!choice || choice == "Cancel")
		return null
	return choice

/obj/structure/research_bench/proc/appoint_director(mob/living/human/H)
	if (!map)
		return
	if (!map.is_faction_leader(H, faction))
		return
	var/mob/living/human/target = pick_faction_member(H, "Who will be your faction's Research Director?")
	if (!target)
		return
	var/newtitle = WWinput(H, "Choose a title for this role:", "Research Director", "Research Director")
	if (!newtitle || newtitle == "")
		newtitle = "Research Director"
	map.faction_research_director[faction] = target
	map.faction_director_title[faction] = newtitle
	to_chat(target, SPAN_NOTICE("You have been appointed <b>[newtitle]</b> of the [faction]!"))
	to_chat(H, SPAN_NOTICE("[target] is now your [newtitle]."))

/obj/structure/research_bench/proc/dismiss_director(mob/living/human/H)
	if (!map)
		return
	if (!map.is_faction_leader(H, faction))
		return
	var/mob/living/human/D = map.faction_research_director[faction]
	map.faction_research_director[faction] = null
	if (D)
		to_chat(D, SPAN_WARNING("You have been removed as [map.get_director_title(faction)] of the [faction]."))
	to_chat(H, SPAN_NOTICE("You dismiss your faction's [map.get_director_title(faction)]."))

/obj/structure/research_bench/proc/set_director_title(mob/living/human/H)
	if (!map)
		return
	if (!map.is_faction_leader(H, faction))
		return
	var/newtitle = WWinput(H, "New title for your Research Director role:", "Research Director", map.get_director_title(faction))
	if (!newtitle || newtitle == "")
		return
	map.faction_director_title[faction] = newtitle
	to_chat(H, SPAN_NOTICE("The role is now titled [newtitle]."))

/obj/structure/research_bench/proc/appoint_researcher(mob/living/human/H)
	if (!map)
		return
	if (!map.is_faction_leader(H, faction) && !map.is_research_director(H, faction))
		return
	var/mob/living/human/target = pick_faction_member(H, "Who will you appoint as a Researcher?")
	if (!target)
		return
	target.research_role = "researcher"
	to_chat(target, SPAN_NOTICE("You have been appointed a Researcher of the [faction]!"))
	to_chat(H, SPAN_NOTICE("[target] is now a Researcher."))

/obj/structure/research_bench/proc/dismiss_researcher(mob/living/human/H)
	if (!map)
		return
	if (!map.is_faction_leader(H, faction) && !map.is_research_director(H, faction))
		return
	var/mob/living/human/target = pick_faction_member(H, "Dismiss which Researcher?", require_researcher = TRUE)
	if (!target)
		return
	target.research_role = null
	to_chat(target, SPAN_WARNING("You are no longer a Researcher of the [faction]."))
	to_chat(H, SPAN_NOTICE("[target] is no longer a Researcher."))

// ------------------------------------------------------------
// NanoUI frontend (Phase 4): the whole tree, grouped by layer, with
// per-node status/progress for the viewing player's faction and
// clickable Assign links wherever the viewer's role + node status allow it.
// ------------------------------------------------------------
/obj/structure/research_bench/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	var/list/data = list()
	data["bench_tier"] = tier
	data["max_tier"] = MAX_BENCH_TIER
	// Upgrades are also capped at the current global era (see era_max_tier).
	var/emax = era_max_tier()
	data["era_max_tier"] = emax
	data["era_capped"] = tier >= emax && tier < MAX_BENCH_TIER
	data["tier_progress"] = tier_progress
	data["tier_upgrade_cost"] = tier < emax ? BENCH_TIER_UPGRADE_COST(tier) : 0
	data["bench_faction"] = faction

	var/viewer_faction = H.civilization
	data["viewer_faction"] = viewer_faction
	var/has_faction = viewer_faction && viewer_faction != "none"
	data["has_faction"] = has_faction
	if (has_faction && map)
		data["viewer_cap"] = map.get_bench_cap(viewer_faction)
		data["viewer_bench_count"] = map.count_faction_benches(viewer_faction)

	// Ownership / roles / permissions for the viewer relative to THIS bench.
	var/owns_bench = has_faction && faction == viewer_faction
	var/is_leader = map && map.is_faction_leader(H, faction)
	var/is_director = map && map.is_research_director(H, faction)
	var/can_manage = map && map.can_manage_faction_research(H, faction)
	data["owns_bench"] = owns_bench
	data["can_manage"] = can_manage
	data["is_leader"] = is_leader
	data["is_director"] = is_director
	data["director_title"] = map ? map.get_director_title(faction) : "Research Director"
	data["has_director"] = map && map.faction_research_director[faction] ? TRUE : FALSE
	var/viewer_role = "Member"
	if (is_leader)
		viewer_role = "Leader"
	else if (is_director)
		viewer_role = data["director_title"]
	else if (H.research_role == "researcher" && owns_bench)
		viewer_role = "Researcher"
	else if (!has_faction)
		viewer_role = "Factionless"
	data["viewer_role"] = viewer_role
	// Reclaim: a foreign bench whose owning faction has died out, if the
	// viewer's own faction still has room.
	data["can_claim"] = has_faction && !owns_bench && map && !faction_is_extant(faction) && \
		map.count_faction_benches(viewer_faction) < map.get_bench_cap(viewer_faction)

	if (assigned_node)
		var/datum/research_node/AN = get_research_node(assigned_node)
		if (AN)
			data["assigned_name"] = AN.name
			var/done = map && map.is_node_done(faction, assigned_node)
			data["assigned_done"] = done
			// Writing notes/books is offered per-node from each completed node's
			// detail popup (see the per-node can_write_* flags below), not from
			// this "currently researching" panel -- so a faction can document ANY
			// tech it has finished, not just whatever a bench is parked on.
			if (!done)
				var/list/entry = map ? map.get_node_entry(faction, assigned_node) : null
				var/ticks = entry ? entry[RNODE_ENTRY_TICKS] : 0
				switch (AN.mode)
					if (RESEARCH_MODE_PROTOTYPE)
						var/pname = AN.prototype_display_name()
						var/proto_in = map.node_prototype_submitted(faction, assigned_node)
						data["assigned_status_text"] = "Needs BOTH full study ([round((ticks / AN.cost_ticks) * 100)]% -- [ticks]/[AN.cost_ticks]) AND a working [pname ? pname : "prototype"] fed to the bench[proto_in ? " (prototype installed -- awaiting study)" : ""]."
					if (RESEARCH_MODE_BOOK)
						data["assigned_status_text"] = "Can only be learned from another faction's research book."
					else
						data["assigned_status_text"] = "Passive study: [round((ticks / AN.cost_ticks) * 100)]% ([ticks]/[AN.cost_ticks])."
	// Queue display: the node names lined up after the current subject.
	var/list/qnames = list()
	for (var/qid in queue_list())
		var/datum/research_node/QN = get_research_node(qid)
		qnames += QN ? QN.name : qid
	data["queue_names"] = qnames
	data["can_queue"] = can_manage

	// Nodes are grouped into standalone TREES (Main first, then specialized
	// trees like Agriculture), each rendered as its own switchable tab; within
	// a tree they're grouped into layers (categories) as before.
	var/list/trees = list()
	var/list/tree_index = list()        // tree name => tree entry (sent to UI)
	var/list/tree_layer_index = list()  // tree name => (category => layer entry)
	if (!map)
		return
	for (var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		var/list/tree_entry = tree_index[N.tree]
		if (!tree_entry)
			// idx is the 0-based tab position (Main = 0). Carried as a data field
			// rather than relying on the template engine's loop-index alias.
			tree_entry = list("tree_name" = N.tree, "idx" = trees.len, "layers" = list())
			tree_index[N.tree] = tree_entry
			tree_layer_index[N.tree] = list()
			trees += list(tree_entry)
		var/list/layer_index = tree_layer_index[N.tree]
		var/list/layer_entry = layer_index[N.category]
		if (!layer_entry)
			layer_entry = list("layer_name" = N.category, "nodes" = list())
			layer_index[N.category] = layer_entry
			tree_entry["layers"] += list(layer_entry)
		// node_status()/is_node_done() handle a "none"/null faction fine on
		// their own (baseline-era grants don't depend on faction), so every
		// viewer -- factionless included -- sees their era's freebies as Done.
		var/status = map.node_status(viewer_faction, node_id)
		var/status_text
		var/status_class
		var/detail
		var/progress_percent = 0
		switch (status)
			if (RNODE_DONE)
				status_text = "Done"
				status_class = "linkOn"
				progress_percent = 100
				var/list/entry = map.get_node_entry(viewer_faction, node_id)
				detail = (entry && entry[RNODE_ENTRY_TICKS] > 0) ? "Completed" : "Baseline (free at this era)"
			if (RNODE_IN_PROGRESS)
				status_text = "In Progress"
				status_class = "linkOff"
				var/list/entry = map.get_node_entry(viewer_faction, node_id)
				var/ticks = entry ? entry[RNODE_ENTRY_TICKS] : 0
				progress_percent = round((ticks / N.cost_ticks) * 100)
				detail = "[progress_percent]% ([ticks]/[N.cost_ticks])"
			if (RNODE_AVAILABLE)
				status_text = "Available"
				status_class = "linkOff"
				detail = "Min bench tier: [N.min_bench_tier]"
			else
				status_text = "Locked"
				status_class = "disabled"
				var/list/missing = list()
				for (var/req in N.prereqs)
					if (!map.is_node_done(viewer_faction, req))
						var/datum/research_node/RN = get_research_node(req)
						missing += RN ? RN.name : req
				detail = missing.len ? "Requires: [jointext(missing, ", ")]" : "Requires an earlier era"
		var/mode_text = "Passive study"
		if (N.mode == RESEARCH_MODE_PROTOTYPE)
			mode_text = "Prototype"
		else if (N.mode == RESEARCH_MODE_BOOK)
			mode_text = "Book only"
		var/list/prereq_ids = list()
		var/list/prereq_names = list()
		for (var/req in N.prereqs)
			prereq_ids += req
			var/datum/research_node/RN = get_research_node(req)
			prereq_names += RN ? RN.name : req
		layer_entry["nodes"] += list(list(
			"id" = node_id,
			"name" = N.name,
			"era_tier" = N.era_tier,
			// Grid column: one block of columns per era (in era order), with
			// each era-changing capstone given its own column between the
			// block it graduates from and the one it starts. See
			// build_tree_grid_columns() in research_node.dm.
			"grid_col" = get_node_grid_col(node_id),
			"is_era_changing" = (N.mode == RESEARCH_MODE_PROTOTYPE),
			"cost_ticks" = N.cost_ticks,
			"min_bench_tier" = N.min_bench_tier,
			"mode_text" = mode_text,
			"prereq_ids" = jointext(prereq_ids, ","),
			"prereq_names" = prereq_names.len ? jointext(prereq_names, ", ") : "None",
			"recipe_names" = get_node_recipe_names(node_id),
			"status_text" = status_text,
			"status_class" = status_class,
			"detail" = detail,
			"progress_percent" = progress_percent,
			"assignable" = can_manage && can_assign_node(node_id),
			// Research staff of the OWNING faction can document any DONE node from
			// its detail popup. can_manage already implies the viewer is in this
			// bench's faction, so status (computed for viewer_faction) == the
			// bench faction's status. Books work on any mode; notes need a
			// tick-accumulating subject (every mode except the unused BOOK mode).
			"can_write_book" = can_manage && status == RNODE_DONE,
			"can_write_notes" = can_manage && status == RNODE_DONE && N.mode != RESEARCH_MODE_BOOK,
			// Name of the item a PROTOTYPE node needs built, so the modal can tell
			// the researcher what to make instead of leaving them guessing.
			"prototype_name" = (N.mode == RESEARCH_MODE_PROTOTYPE) ? N.prototype_display_name() : null,
			// Queueable: staff can line up any not-done node that isn't the current
			// subject (the queue handler rejects duplicates / already-queued).
			"queueable" = can_manage && status != RNODE_DONE && node_id != assigned_node))
	data["trees"] = trees

	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "research_bench.tmpl", name, 900, 680)
		// "basic" layout: just the content region, none of the stock SS13
		// NanoUI chrome (title bar/status icon) that the default layout wraps
		// around every UI -- this window is all parchment, edge to edge.
		ui.set_layout_key("basic")
		ui.add_stylesheet("research_tree.css")
		ui.add_script("research_tree.js")
		ui.set_initial_data(data)
		ui.open()
		// No auto_update: that polls and fully re-renders every ~1s regardless
		// of whether anything changed, which is what was causing the whole
		// window to visibly flash/reset constantly. Ticks land every 10s at
		// most (see analysis_tick()), and every player action already pushes
		// its own refresh via Topic() -- so updates now only fire when this
		// bench's data actually changes, not on a blind fixed heartbeat.

/obj/structure/research_bench/Topic(href, href_list)
	if (!istype(usr, /mob/living/human))
		return
	var/mob/living/human/H = usr
	if (H.stat) // no acting on the bench while dead or unconscious
		return
	if (!H.civilization || H.civilization == "none")
		return
	if (!(in_range(src, usr) && istype(loc, /turf)) && !usr.contents.Find(src))
		return
	if (href_list["assign"])
		try_assign_node(H, href_list["assign"])
	else if (href_list["queue"])
		try_queue_node(H, href_list["queue"])
	else if (href_list["clear_queue"])
		clear_queue(H)
	else if (href_list["write_book"] || href_list["write_notes"])
		// The href value is the node id being documented (each completed node's
		// detail popup carries its own write links), not the bench's assignment.
		var/is_book = href_list["write_book"] ? TRUE : FALSE
		var/subject = is_book ? href_list["write_book"] : href_list["write_notes"]
		if (map && map.can_manage_faction_research(H, faction))
			write_research_item(H, is_book, subject)
		else
			to_chat(H, SPAN_WARNING("Only your faction's research staff may document research here."))
	else if (href_list["claim"])
		try_claim(H)
	else if (href_list["appoint_director"])
		appoint_director(H)
	else if (href_list["dismiss_director"])
		dismiss_director(H)
	else if (href_list["set_director_title"])
		set_director_title(H)
	else if (href_list["appoint_researcher"])
		appoint_researcher(H)
	else if (href_list["dismiss_researcher"])
		dismiss_researcher(H)
	GLOB.nanomanager.update_uis(src)

// Writing a trade good requires the SUBJECT node to be DONE for the faction (you
// can only document what you already know). The subject is any completed node the
// research staff picks from its detail popup -- it doesn't have to be whatever
// this bench is currently researching. Notes are quick jottings that give a buyer
// a boost of ticks; a full book is a long transcription that lets a buyer
// complete the node outright. The effort gap (do_after time) is what keeps the
// weaker notes worth trading.
/obj/structure/research_bench/proc/write_research_item(mob/living/human/H, is_book, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return
	// One transcription at a time: without this, spam-clicking (or two users
	// clicking in parallel) starts overlapping do_after loops that each
	// produce a book/note, bypassing the writing time as a limiter.
	if (writing)
		to_chat(H, SPAN_WARNING("This bench is already busy transcribing research."))
		return
	if (!map || !map.is_node_done(faction, node_id))
		to_chat(H, SPAN_WARNING("You can only document research your faction has completed."))
		return
	var/wtime = is_book ? RESEARCH_BOOK_WRITE_TIME : RESEARCH_NOTES_WRITE_TIME
	to_chat(H, SPAN_NOTICE("You begin [is_book ? "transcribing a full research book" : "jotting down research notes"] on [N.name]..."))
	writing = TRUE
	if (!do_after(H, wtime, src))
		writing = FALSE
		return
	writing = FALSE
	// Re-check ownership/permission after the wait, in case the bench changed hands.
	if (!map || !map.can_manage_faction_research(H, faction) || !map.is_node_done(faction, node_id))
		return
	var/obj/item/weapon/book/research/tree_book/book = new(get_turf(H))
	book.subject = node_id
	book.written_by_faction = faction
	book.written_by = H.real_name
	book.transfer_type = is_book ? "book" : "notes"
	if (is_book)
		book.name = "research book: [N.name]"
		book.title = "On the Subject of [N.name], by [H.real_name]"
		book.desc = "A [book.styleb] fully documenting the [faction] research into [N.name], set down by [H.real_name]. Another faction's research bench can study it to learn the subject outright."
	else
		book.name = "research notes: [N.name]"
		book.title = "Notes on [N.name], by [H.real_name]"
		book.desc = "Hastily-written [faction] notes on [N.name] by [H.real_name]. Another faction's research bench can study them to speed up research on that subject."
	to_chat(H, SPAN_NOTICE("You finish your [is_book ? "research book" : "research notes"] on <b>[N.name]</b>."))

// Consuming items: research books (teach the matching node), matching
// prototypes (complete a PROTOTYPE-mode node outright), or copper/silver/
// gold coins (their value feeds this bench's tier-upgrade progress).
/obj/structure/research_bench/attackby(obj/item/W as obj, mob/living/human/user as mob)
	if (!istype(W) || !ishuman(user))
		return ..()
	if (!map)
		return
	// You can only interact with a bench your own faction owns.
	if (!user.civilization || user.civilization != faction)
		to_chat(user, SPAN_WARNING("This research bench belongs to the [faction || "no-one"], not your faction."))
		return
	if (!assigned_node || !faction)
		to_chat(user, SPAN_WARNING("Assign this bench a research subject first."))
		return
	var/datum/research_node/N = get_research_node(assigned_node)
	if (!N)
		return

	if (istype(W, /obj/item/weapon/book/research/tree_book))
		if (!map.can_manage_faction_research(user, faction))
			to_chat(user, SPAN_WARNING("Only your faction's research staff may study research trade goods here."))
			return
		var/obj/item/weapon/book/research/tree_book/book = W
		if (book.subject != assigned_node)
			to_chat(user, SPAN_WARNING("This [book.transfer_type == "notes" ? "notes are" : "book is"] not on the subject this bench is researching."))
			return
		if (map.is_node_done(faction, assigned_node))
			to_chat(user, SPAN_WARNING("Your faction has already completed <b>[N.name]</b>."))
			return
		if (!map.node_prereqs_met(faction, assigned_node))
			to_chat(user, SPAN_WARNING("Your faction hasn't researched the prerequisites for <b>[N.name]</b> yet."))
			return
		if (book.transfer_type == "book")
			// Full book: complete the node outright.
			if (map.complete_node(faction, assigned_node))
				to_chat(user, SPAN_NOTICE("You study the book. The [faction] now understand <b>[N.name]</b>!"))
				qdel(W)
				try_advance_queue()
			return
		// Notes: grant a boost of ticks. Meaningful for any tick-accumulating
		// node -- ANALYSIS and PROTOTYPE both progress this way now; BOOK-only
		// nodes are the sole mode that never ticks.
		if (N.mode == RESEARCH_MODE_BOOK)
			to_chat(user, SPAN_WARNING("Notes only speed up ongoing study; <b>[N.name]</b> can't be advanced that way."))
			return
		var/boost = max(1, round(N.cost_ticks * RESEARCH_NOTE_BOOST_FRACTION))
		var/completed = map.add_research_ticks(faction, assigned_node, boost)
		qdel(W)
		if (completed)
			to_chat(user, SPAN_NOTICE("The notes tip your research over the line -- the [faction] have researched <b>[N.name]</b>!"))
		else
			to_chat(user, SPAN_NOTICE("You study the notes, advancing your research on <b>[N.name]</b> by [boost] points."))
		try_advance_queue()
		return

	if (N.mode == RESEARCH_MODE_PROTOTYPE && N.prototype_type && istype(W, N.prototype_type))
		if (!map.can_manage_faction_research(user, faction))
			to_chat(user, SPAN_WARNING("Only your faction's research staff may submit a prototype here."))
			return
		if (tier < N.min_bench_tier)
			to_chat(user, SPAN_WARNING("This bench isn't upgraded enough to complete this prototype."))
			return
		if (map.is_node_done(faction, assigned_node))
			to_chat(user, SPAN_WARNING("Already researched."))
			return
		if (!map.node_prereqs_met(faction, assigned_node))
			to_chat(user, SPAN_WARNING("The prerequisites for this aren't researched yet."))
			return
		if (map.node_prototype_submitted(faction, assigned_node))
			to_chat(user, SPAN_WARNING("A working prototype has already been installed for <b>[N.name]</b>; it just needs the study to finish."))
			return
		// The prototype is a REQUIREMENT alongside the full study, not a shortcut:
		// record it as submitted. If the passive study is already complete, that
		// finishes the node now; otherwise it completes once the ticks catch up.
		qdel(W)
		map.set_prototype_submitted(faction, assigned_node)
		var/list/pentry = map.get_node_entry(faction, assigned_node)
		if (pentry && pentry[RNODE_ENTRY_TICKS] >= N.cost_ticks)
			map.complete_node(faction, assigned_node)
			to_chat(user, SPAN_NOTICE("Your prototype works and completes the research! The [faction] have researched <b>[N.name]</b>."))
			try_advance_queue()
		else
			to_chat(user, SPAN_NOTICE("You install the working prototype for <b>[N.name]</b>. The research will complete once your researchers finish their study."))
		return

	// Study a SAMPLE: an existing example of something the assigned tech will
	// unlock (reverse-engineering). You can't craft the locked item yet, so a
	// sample has to be looted / traded / found. Studying it advances the CURRENT
	// subject only, and each distinct item TYPE teaches something just once.
	for (var/stype in get_node_recipe_paths(assigned_node))
		if (!istype(W, stype))
			continue
		if (!map.can_manage_faction_research(user, faction))
			to_chat(user, SPAN_WARNING("Only your faction's research staff may study samples here."))
			return
		if (map.is_node_done(faction, assigned_node))
			to_chat(user, SPAN_WARNING("Your faction has already completed <b>[N.name]</b>."))
			return
		if (!map.node_prereqs_met(faction, assigned_node))
			to_chat(user, SPAN_WARNING("The prerequisites for <b>[N.name]</b> aren't researched yet."))
			return
		if (N.mode == RESEARCH_MODE_BOOK)
			to_chat(user, SPAN_WARNING("Samples only speed up ongoing study; <b>[N.name]</b> can't be advanced that way."))
			return
		if (!studied_samples)
			studied_samples = list()
		if (W.type in studied_samples)
			to_chat(user, SPAN_WARNING("Your researchers have already learned all they can from studying \a [W]."))
			return
		studied_samples += W.type
		var/sboost = max(1, round(N.cost_ticks * RESEARCH_SAMPLE_BOOST_FRACTION))
		var/scompleted = map.add_research_ticks(faction, assigned_node, sboost)
		to_chat(user, SPAN_NOTICE("Your researchers dismantle and study \the [W], advancing <b>[N.name]</b> by [sboost] points[scompleted ? " -- completing it!" : ""]."))
		qdel(W)
		try_advance_queue()
		return

	// Fallback: feeding coins counts toward the bench's tier upgrade. Only
	// the three metal coin types (and their subtypes) -- NOT the money base,
	// which also covers rubles/francs/euros/pounds/etc -- matching the
	// resource forge's own coin check.
	if (tier >= MAX_BENCH_TIER)
		to_chat(user, SPAN_WARNING("This bench is already at maximum tier."))
		return
	if (tier >= era_max_tier())
		to_chat(user, SPAN_WARNING("This bench can't be upgraded past tier [era_max_tier()] until your civilization advances to the next era."))
		return
	if (!istype(W, /obj/item/stack/money/coppercoin) && !istype(W, /obj/item/stack/money/silvercoin) && !istype(W, /obj/item/stack/money/goldcoin))
		to_chat(user, SPAN_WARNING("This bench only accepts copper, silver or gold coins to upgrade."))
		return
	var/obj/item/stack/money/coins = W
	// Let the player choose how much to melt, same as the resource forge:
	// consuming the whole stack on one click turns a misclick into a wasted
	// purse.
	var/count = input(user, "How many coins do you want to feed the bench? (You are holding [coins.amount])", "Research Bench", coins.amount) as num|null
	if (!count || count <= 0)
		return
	// Re-validate after the input pause: the stack may have been spent,
	// dropped or deleted while the dialog was open.
	if (QDELETED(coins) || !in_range(src, user))
		return
	count = min(round(count), coins.amount)
	if (count <= 0)
		return
	var/coinname = coins.name
	var/value = coins.value * count
	coins.use(count)
	if (!value)
		to_chat(user, SPAN_WARNING("This has no value to contribute toward upgrading the bench."))
		return
	tier_progress += value
	var/needed = BENCH_TIER_UPGRADE_COST(tier)
	if (tier_progress >= needed)
		tier_progress -= needed
		tier++
		to_chat(user, SPAN_NOTICE("You melt down [count] [coinname]. The bench has been upgraded to tier [tier]!"))
	else
		to_chat(user, SPAN_NOTICE("You melt down [count] [coinname]. Upgrade progress: [tier_progress]/[needed]."))

// A bench can only be upgraded up to the current GLOBAL era: Stone Age (era 0)
// caps at tier 0, Bronze Age (era 1) at tier 1, and so on -- never above the
// absolute ceiling. As the world advances an era, the cap rises with it.
/obj/structure/research_bench/proc/era_max_tier()
	return min(MAX_BENCH_TIER, map ? map.ordinal_age : 0)

/obj/structure/research_bench/examine(mob/user, distance = -1)
	..()
	if (tier >= MAX_BENCH_TIER)
		to_chat(user, "It is tier [tier] (maximum).")
	else if (tier >= era_max_tier())
		to_chat(user, "It is tier [tier], capped at the current era -- your civilization must reach the next era to upgrade it further.")
	else
		to_chat(user, "It is tier [tier] (upgrade progress: [tier_progress]/[BENCH_TIER_UPGRADE_COST(tier)]).")
	if (!assigned_node)
		to_chat(user, "It has no research subject assigned.")
		return
	var/datum/research_node/N = get_research_node(assigned_node)
	if (!N)
		return
	to_chat(user, "It is researching <b>[N.name]</b> for the [faction || "no faction"].")
	if (map)
		if (map.is_node_done(faction, assigned_node))
			to_chat(user, "This subject has already been completed.")
			return
		if (N.mode == RESEARCH_MODE_BOOK)
			to_chat(user, "This can only be learned from another faction's research book.")
		else
			var/list/entry = map.get_node_entry(faction, assigned_node)
			var/ticks = entry ? entry[RNODE_ENTRY_TICKS] : 0
			to_chat(user, "Progress: [round((ticks / N.cost_ticks) * 100)]% ([ticks]/[N.cost_ticks]).")
			if (N.mode == RESEARCH_MODE_PROTOTYPE)
				to_chat(user, "A working prototype would also complete this outright.")
