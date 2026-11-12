// ============================================================
// Research Tree - working demonstrations for late capstones (Val, 2026-11-12)
// ------------------------------------------------------------
// On book-research worlds the late era capstones are no longer finished by
// handing a part to the bench (a tool handle for Steam Power, a cable coil for
// Electricity...). The chapter needs a demonstration instead: the machine
// running in the world, watched for a while by someone who knows the
// groundwork and writes down what they see.
// - Record it with "Record a Demonstration" on a sheet of paper or parchment
//   (it becomes demonstration notes; use them on the bench) or straight into
//   an ordinary book.
// - The machine usually needs the very chapter it proves, so once a book holds
//   half of the chapter, whoever carries it can build a crude experimental
//   version. It is unreliable, can fail during a demonstration, and falls
//   apart after a while.
// Bench study is still needed; the demonstration replaces only the prototype.
// ============================================================

#define DEMO_TEXT 1
#define DEMO_SECONDS 2
#define DEMO_KIT 3
// How near the recorder must stay to the machine.
#define DEMO_RANGE 3
// One check of the machine every this many deciseconds.
#define DEMO_STEP 50
// Share of the chapter a carried book needs before experimental builds.
#define DEMO_KIT_SHARE 0.5
// Experimental machines fall apart after this long (deciseconds, real time).
#define EXPERIMENTAL_LIFETIME 12000
// Chance per check that an experimental machine fails during a demonstration.
#define EXPERIMENTAL_MISHAP_CHANCE 4

// node id => list(what to do, seconds to watch, types the experimental kit allows)
var/global/list/capstone_demonstrations = list(
	"steam_power" = list("Keep a steam engine running for a minute", 60, list(/obj/structure/engine/external/steam)),
	"electricity" = list("Keep an electric lamp lit from an engine or generator for a minute", 60, list(/obj/structure/lamp/lamp_small, /obj/structure/lamp/lamppost_small)),
	"nuclear_power" = list("Keep a reactor producing power, below overheating, for three minutes", 180, list(/obj/structure/civ_generator/nuclear, /obj/structure/reactor_fuel_processor)),
	"digital_computing" = list("Keep a computerized fabricator running for a minute", 60, list(/obj/structure/factory_fabricator/computerized)),
	"digital_networks" = list("Keep a mobile phone call connected through a cell tower for a minute", 60, list()))

/proc/node_demonstration(node_id)
	if (!map || !map.book_research_enabled() || !istext(node_id))
		return null
	return capstone_demonstrations[node_id]

/proc/node_needs_demonstration(node_id)
	return node_demonstration(node_id) ? TRUE : FALSE

// What a capstone still needs besides study, for the research windows.
/proc/prototype_need_label(datum/research_node/N)
	if (!N)
		return "A working prototype"
	if (node_needs_demonstration(N.id))
		return "A demonstration: [demonstration_text(N.id)] (record it with Record a Demonstration on paper or parchment and use the notes on the bench, or record it straight into the book)"
	var/pname = N.prototype_display_name()
	return "A working [pname ? pname : "prototype"] used on the bench"

/proc/demonstration_text(node_id)
	var/list/D = capstone_demonstrations[node_id]
	return D ? D[DEMO_TEXT] : null

/obj/structure
	var/experimental_node = null // capstone this crude experimental build was made for
	var/experimental_expires = 0 // world.realtime it falls apart at

/obj/item/weapon/paper
	var/demonstration_node = null // capstone these notes record a demonstration of

// ---------- Is the machine running? ----------

// Phones near the recorder, on the ground or in someone's hands.
/proc/demonstration_nearby_phones(mob/living/human/H)
	var/list/phones = list()
	for (var/obj/item/weapon/telephone/mobile/P in range(DEMO_RANGE, H))
		phones |= P
	for (var/mob/living/human/M in range(DEMO_RANGE, H))
		for (var/obj/item/weapon/telephone/mobile/P in list(M.l_hand, M.r_hand))
			phones |= P
	return phones

/proc/demonstration_machine_running(node_id, atom/A)
	if (!A || QDELETED(A))
		return FALSE
	switch (node_id)
		if ("steam_power")
			var/obj/structure/engine/external/steam/E = A
			return istype(E) && E.on && !E.broken
		if ("electricity")
			var/obj/structure/lamp/L = A
			return istype(L) && L.on && L.powerneeded && L.powersource && !L.lamp_broken
		if ("nuclear_power")
			var/obj/structure/civ_generator/nuclear/R = A
			return istype(R) && R.enabled && R.output_power > 0 && R.heat < 80
		if ("digital_computing")
			var/obj/structure/factory_fabricator/computerized/F = A
			return istype(F) && F.fab_status == "running"
		if ("digital_networks")
			var/obj/item/weapon/telephone/mobile/P = A
			return istype(P) && P.connected && P.wireless
	return FALSE

// A machine near H that is demonstrating node_id right now, or null.
/proc/find_demonstration_machine(mob/living/human/H, node_id)
	if (!istype(H) || !capstone_demonstrations[node_id])
		return null
	var/list/candidates
	switch (node_id)
		if ("steam_power")
			candidates = typesof_in_range(H, /obj/structure/engine/external/steam)
		if ("electricity")
			candidates = typesof_in_range(H, /obj/structure/lamp)
		if ("nuclear_power")
			candidates = typesof_in_range(H, /obj/structure/civ_generator/nuclear)
		if ("digital_computing")
			candidates = typesof_in_range(H, /obj/structure/factory_fabricator/computerized)
		if ("digital_networks")
			candidates = demonstration_nearby_phones(H)
	for (var/atom/A in candidates)
		if (demonstration_machine_running(node_id, A))
			return A
	return null

/proc/typesof_in_range(mob/living/human/H, path)
	var/list/found = list()
	for (var/atom/movable/A in range(DEMO_RANGE, H))
		if (istype(A, path))
			found += A
	return found

// ---------- Experimental builds ----------

// A book on H (hands or worn) holding at least half of node_id, unfinished.
/mob/living/human/proc/demonstration_book(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return null
	for (var/obj/item/weapon/book/B in get_demonstration_carried())
		if (istype(B, /obj/item/weapon/book/research/tree_book) || B.has_research_chapter(node_id))
			continue
		if (B.research_ticks(node_id) >= N.cost_ticks * DEMO_KIT_SHARE)
			return B
	return null

/mob/living/human/proc/get_demonstration_carried()
	var/list/items = list(l_hand, r_hand)
	for (var/obj/item/I in contents)
		items |= I
	return items

// The capstone an experimental build of result_path_string would be for, if
// H may make one (they know the groundwork and carry a half-written chapter).
/proc/demonstration_kit_node(mob/living/human/H, result_path_string)
	if (!istype(H) || !istext(result_path_string) || !map || !map.book_research_enabled())
		return null
	var/path = text2path(result_path_string)
	if (!path)
		return null
	for (var/node_id in capstone_demonstrations)
		var/list/D = capstone_demonstrations[node_id]
		if (!(path in D[DEMO_KIT]))
			continue
		if (H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id))
			continue
		if (H.demonstration_book(node_id))
			return node_id
	return null

/proc/demonstration_kit_allowed(mob/living/human/H, result_path_string)
	return demonstration_kit_node(H, result_path_string) ? TRUE : FALSE

// Called when something is built: a build only the kit allowed is experimental.
/proc/mark_experimental_build(mob/living/human/H, obj/structure/O, result_path_string)
	if (!istype(O) || !istype(H))
		return FALSE
	var/node_id = get_recipe_node_req(result_path_string)
	if (istext(node_id) && crafting_node_allowed(H, node_id))
		return FALSE
	var/kit_node = demonstration_kit_node(H, result_path_string)
	if (!kit_node)
		return FALSE
	O.make_experimental(kit_node)
	return TRUE

/obj/structure/proc/make_experimental(node_id)
	experimental_node = node_id
	experimental_expires = world.realtime + EXPERIMENTAL_LIFETIME
	name = "experimental [initial(name)]"
	desc = "[initial(desc)] It is a crude experimental build, held together for a demonstration. It won't last."
	// Generators wait for their age; an experimental one runs now.
	var/obj/structure/civ_generator/G = src
	if (istype(G))
		G.min_age = 0
	schedule_experimental_decay()

/obj/structure/proc/schedule_experimental_decay()
	addtimer(CALLBACK(src, PROC_REF(experimental_decay_check)), max(10, experimental_expires - world.realtime))

/obj/structure/proc/experimental_decay_check()
	if (QDELETED(src) || !experimental_node)
		return
	if (world.realtime < experimental_expires - 10)
		schedule_experimental_decay()
		return
	experimental_fall_apart("falls apart")

/obj/structure/proc/experimental_fall_apart(how)
	visible_message(SPAN_WARNING("\The [src] [how]."))
	qdel(src)

/obj/structure/after_load()
	..()
	if (experimental_node)
		schedule_experimental_decay()

// One check during a demonstration: an experimental machine may fail. Returns
// TRUE when it did, which ends the demonstration.
/proc/demonstration_mishap(atom/machine, node_id)
	var/obj/structure/O = machine
	if (!istype(O) || !O.experimental_node || !prob(EXPERIMENTAL_MISHAP_CHANCE))
		return FALSE
	switch (node_id)
		if ("steam_power")
			for (var/mob/living/human/M in range(1, O))
				M.take_overall_damage(0, 8)
			O.experimental_fall_apart("bursts in a cloud of scalding steam")
		if ("electricity")
			var/obj/structure/lamp/L = O
			L.lamp_broken = TRUE
			L.visible_message(SPAN_WARNING("\The [L] flashes and shorts out."))
		if ("nuclear_power")
			var/obj/structure/civ_generator/nuclear/R = O
			R.heat = min(100, R.heat + 30)
			R.visible_message(SPAN_WARNING("\The [R] lurches hot. Its heat is climbing fast."))
		if ("digital_computing")
			O.experimental_fall_apart("sparks, smokes and dies")
		else
			return FALSE
	return TRUE

// ---------- Recording ----------

// Demonstrations H could record right now, node id => machine.
/proc/demonstrations_in_view(mob/living/human/H)
	var/list/found = list()
	if (!istype(H) || !map || !map.book_research_enabled())
		return found
	for (var/node_id in capstone_demonstrations)
		if (!H.knows_research_prereqs(node_id))
			continue
		var/atom/A = find_demonstration_machine(H, node_id)
		if (A)
			found[node_id] = A
	return found

// Whether carrier can take a demonstration of node_id.
/proc/demonstration_carrier_ok(obj/item/carrier, node_id)
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		return !istype(P, /obj/item/weapon/paper/research_page) && !P.demonstration_node
	if (istype(carrier, /obj/item/weapon/book) && !istype(carrier, /obj/item/weapon/book/research/tree_book))
		var/obj/item/weapon/book/B = carrier
		var/datum/research_node/N = get_research_node(node_id)
		return N && !B.has_research_chapter(node_id) && !B.research_prototype_installed(node_id)
	return FALSE

// Writes a finished demonstration down. No waiting here.
/proc/commit_demonstration(mob/living/human/H, obj/item/carrier, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!istype(H) || !N || !demonstration_carrier_ok(carrier, node_id))
		return FALSE
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		P.demonstration_node = node_id
		P.name = "demonstration notes ([N.name])"
		P.desc = "Notes taken by [H.real_name] while watching a working demonstration of [N.name]. Use them on a research bench working on [N.name], with its book on the bench."
		P.update_icon()
		return TRUE
	var/obj/item/weapon/book/B = carrier
	B.add_research_work(node_id, 0, TRUE)
	return TRUE

/mob/living/human/proc/record_demonstration(obj/item/carrier)
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("There is nothing here to record."))
		return FALSE
	if (!(carrier in list(l_hand, r_hand)))
		to_chat(src, SPAN_WARNING("Hold \the [carrier] in your hand first."))
		return FALSE
	if (!held_writing_pen())
		to_chat(src, SPAN_WARNING("You need a pen or pencil in your other hand to take notes."))
		return FALSE
	var/list/found = demonstrations_in_view(src)
	if (!found.len)
		var/list/lines = list()
		for (var/node_id in capstone_demonstrations)
			var/datum/research_node/N = get_research_node(node_id)
			if (N && knows_research_prereqs(node_id) && !knows_recipe_node(node_id))
				lines += "<b>[N.name]</b>: [demonstration_text(node_id)]"
		if (lines.len)
			to_chat(src, SPAN_WARNING("Nothing running nearby demonstrates anything you could record. Within [DEMO_RANGE] tiles of you:<br>[jointext(lines, "<br>")]"))
		else
			to_chat(src, SPAN_WARNING("You don't know enough to make sense of any demonstration yet."))
		return FALSE
	var/node_id = found[1]
	if (found.len > 1)
		var/list/names = list()
		for (var/id in found)
			var/datum/research_node/FN = get_research_node(id)
			names[FN.name] = id
		var/choice = player_input(src, "Which demonstration do you record?", "Record a Demonstration", null, "anything", names, TRUE)
		if (!choice)
			return FALSE
		node_id = names[choice]
	var/datum/research_node/N = get_research_node(node_id)
	if (!demonstration_carrier_ok(carrier, node_id))
		to_chat(src, SPAN_WARNING("\The [carrier] can't take a demonstration of [N.name]."))
		return FALSE
	var/atom/machine = found[node_id]
	var/list/D = capstone_demonstrations[node_id]
	var/steps = max(1, round(D[DEMO_SECONDS] * 10 / DEMO_STEP))
	visible_message(SPAN_NOTICE("[src] starts watching \the [machine] and taking notes."), SPAN_NOTICE("You start recording the demonstration of <b>[N.name]</b>. Stay within [DEMO_RANGE] tiles and keep it running for [D[DEMO_SECONDS]] seconds."))
	for (var/i = 1 to steps)
		if (!do_reading(src, DEMO_STEP, src))
			to_chat(src, SPAN_WARNING("You stop recording. The notes are no use unfinished."))
			return FALSE
		if (get_dist(src, machine) > DEMO_RANGE || !demonstration_machine_running(node_id, machine) || !(carrier in list(l_hand, r_hand)))
			to_chat(src, SPAN_WARNING("The demonstration stopped before you could finish your notes."))
			return FALSE
		if (demonstration_mishap(machine, node_id))
			to_chat(src, SPAN_WARNING("The experiment failed. You'll have to try again."))
			return FALSE
	if (!commit_demonstration(src, carrier, node_id))
		return FALSE
	if (istype(carrier, /obj/item/weapon/paper))
		to_chat(src, SPAN_NOTICE("You finish your notes on the demonstration of <b>[N.name]</b>. Use them on a research bench working on it."))
	else
		var/obj/item/weapon/book/B = carrier
		if (B.has_research_chapter(node_id))
			to_chat(src, SPAN_NOTICE("The demonstration is written into [B]. The chapter on <b>[N.name]</b> is finished."))
		else
			to_chat(src, SPAN_NOTICE("The demonstration is written into [B]. The chapter on <b>[N.name]</b> is finished once the study is done."))
	return TRUE

/obj/item/weapon/paper/verb/record_demonstration_paper()
	set name = "Record a Demonstration"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.record_demonstration(src)

/obj/item/weapon/book/verb/record_demonstration_book()
	set name = "Record a Demonstration"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.record_demonstration(src)

// Demonstration notes used on a bench working on the same subject.
/obj/structure/research_bench/proc/take_demonstration_notes(obj/item/weapon/paper/P, mob/living/human/user)
	var/obj/item/weapon/book/B = placed_book()
	if (!istype(P) || !P.demonstration_node)
		return FALSE
	var/datum/research_node/N = get_research_node(P.demonstration_node)
	if (!B || assigned_node != P.demonstration_node || !N)
		to_chat(user, SPAN_WARNING("These notes are about [N ? N.name : "something else"]. Put a book on the bench and research that subject first."))
		return TRUE
	if (B.has_research_chapter(N.id) || B.research_prototype_installed(N.id))
		to_chat(user, SPAN_WARNING("[B] already holds a demonstration of <b>[N.name]</b>."))
		return TRUE
	if (!user.remove_from_mob(P))
		return TRUE
	qdel(P)
	if (B.add_research_work(N.id, 0, TRUE))
		to_chat(user, SPAN_NOTICE("You copy the demonstration notes into [B]. The chapter on <b>[N.name]</b> is finished."))
	else
		to_chat(user, SPAN_NOTICE("You copy the demonstration notes into [B]. The chapter on <b>[N.name]</b> is finished once the study is done."))
	book_refresh_ui()
	return TRUE

#undef DEMO_TEXT
#undef DEMO_SECONDS
#undef DEMO_KIT
#undef DEMO_RANGE
#undef DEMO_STEP
#undef DEMO_KIT_SHARE
#undef EXPERIMENTAL_LIFETIME
#undef EXPERIMENTAL_MISHAP_CHANCE
