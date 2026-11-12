// ============================================================
// Research Tree - field work for late nodes (Val, 2026-11-12)
// ------------------------------------------------------------
// On book-research worlds, late nodes can be advanced by doing things out in
// the world, not only by standing at a bench. A character's practical
// experience (shots fired, time flown, surgery done...) is counted on the
// character. When someone with enough of it stands at a bench working on a
// matching subject, the experience is written into the book as a share of
// the node, once per book. Bench study alone still finishes any node, and
// late bench study is faster than before now that field work exists.
// ============================================================

// Late nodes (this era tier and up) are studied faster at the bench.
#define FIELD_WORK_MIN_TIER 5
#define LATE_BENCH_RATE 1.5

// activity id => what one unit of it is, for messages and the windows.
var/global/list/field_activities = list(
	"shots" = "shots fired from a firearm",
	"flight" = "seconds flown as a pilot",
	"surgery" = "surgery steps completed",
	"diagnosis" = "sick patients diagnosed with a doctor's handbook",
	"reactions" = "syntheses run at a reaction bench",
	"samples" = "survey samples analysed at a mission console",
	"harvests" = "crops harvested",
	"forage" = "finds made foraging",
	"butchering" = "animals butchered")

// experiment id => list(node id, activity, amount needed, share of the node, what to do)
var/global/list/field_experiments = list(
	"emergency_medicine_theatre" = list("emergency_medicine", "surgery", 15, 0.3, "Complete 15 surgery steps"),
	"emergency_medicine_cases" = list("emergency_medicine", "diagnosis", 6, 0.2, "Diagnose 6 sick patients with a doctor's handbook"),
	"soil_science_harvests" = list("soil_science", "harvests", 40, 0.4, "Harvest 40 crops"),
	"crop_breeding_harvests" = list("crop_breeding", "harvests", 80, 0.4, "Harvest 80 crops"),
	"support_weapons_gunnery" = list("support_weapons", "shots", 80, 0.35, "Fire 80 shots from firearms"),
	"guided_weapons_gunnery" = list("guided_weapons", "shots", 120, 0.3, "Fire 120 shots from firearms"),
	"cartridge_ammo_range" = list("cartridge_ammo", "shots", 30, 0.35, "Fire 30 shots from firearms"),
	"pharmacology_bench" = list("pharmacology", "reactions", 5, 0.35, "Run 5 syntheses at a reaction bench"),
	"pharmacology_cases" = list("pharmacology", "diagnosis", 2, 0.2, "Diagnose 2 sick patients with a doctor's handbook"),
	"anesthetic_surgery_theatre" = list("anesthetic_surgery", "surgery", 5, 0.4, "Complete 5 surgery steps"),
	"germ_theory_cases" = list("germ_theory", "diagnosis", 3, 0.4, "Diagnose 3 sick patients with a doctor's handbook"),
	"selfloading_firearms_range" = list("selfloading_firearms", "shots", 60, 0.35, "Fire 60 shots from firearms"),
	"mechanized_war_gunnery" = list("mechanized_war", "shots", 80, 0.25, "Fire 80 shots from firearms"),
	"automatic_weapons_range" = list("automatic_weapons", "shots", 120, 0.35, "Fire 120 shots from firearms"),
	"modern_armor_trials" = list("modern_armor", "shots", 100, 0.3, "Fire 100 shots from firearms"),
	"modern_medicine_theatre" = list("modern_medicine", "surgery", 12, 0.3, "Complete 12 surgery steps"),
	"modern_medicine_bench" = list("modern_medicine", "reactions", 10, 0.25, "Run 10 syntheses at a reaction bench"),
	"public_health_cases" = list("public_health", "diagnosis", 6, 0.4, "Diagnose 6 sick patients with a doctor's handbook"),
	"synthetics_bench" = list("synthetics", "reactions", 8, 0.35, "Run 8 syntheses at a reaction bench"),
	"aviation_rocketry_hours" = list("aviation_rocketry", "flight", 120, 0.4, "Fly an aircraft for 2 minutes"),
	"naval_aviation_hours" = list("naval_aviation", "flight", 180, 0.4, "Fly an aircraft for 3 minutes"),
	"missiles_hours" = list("missiles", "flight", 150, 0.2, "Fly an aircraft for 2 and a half minutes"),
	"missiles_gunnery" = list("missiles", "shots", 100, 0.2, "Fire 100 shots from firearms"),
	"rocketry_hours" = list("rocketry", "flight", 240, 0.3, "Fly an aircraft for 4 minutes"),
	"planetary_survey_samples" = list("planetary_survey", "samples", 2, 0.5, "Analyse 2 survey samples at a mission console"),
	"crewed_flight_samples" = list("crewed_flight", "samples", 4, 0.35, "Analyse 4 survey samples at a mission console"),
	"crewed_flight_hours" = list("crewed_flight", "flight", 300, 0.2, "Fly an aircraft for 5 minutes"),
	"orbital_flight_samples" = list("orbital_flight", "samples", 6, 0.3, "Analyse 6 survey samples at a mission console"),
	"sealed_habitats_samples" = list("sealed_habitats", "samples", 6, 0.3, "Analyse 6 survey samples at a mission console"),
	"life_support_bench" = list("life_support", "reactions", 15, 0.3, "Run 15 syntheses at a reaction bench"),
	"pressure_suits_hours" = list("pressure_suits", "flight", 360, 0.25, "Fly an aircraft for 6 minutes"),
	"off_world_mining_samples" = list("off_world_mining", "samples", 8, 0.3, "Analyse 8 survey samples at a mission console"),
	"surface_vehicles_samples" = list("surface_vehicles", "samples", 8, 0.25, "Analyse 8 survey samples at a mission console"),
	"local_resources_samples" = list("local_resources", "samples", 10, 0.25, "Analyse 10 survey samples at a mission console"),
	"local_resources_bench" = list("local_resources", "reactions", 20, 0.2, "Run 20 syntheses at a reaction bench"),
	"uav_drones_hours" = list("uav_drones", "flight", 300, 0.3, "Fly an aircraft for 5 minutes"),
	// First nodes with nothing before them (practice_work.dm covers the rest).
	"basic_tools_forage" = list("basic_tools", "forage", 8, 0.4, "Forage 8 finds from the ground"),
	"primitive_construction_forage" = list("primitive_construction", "forage", 6, 0.3, "Forage 6 finds from the ground"),
	"pottery_storage_forage" = list("pottery_storage", "forage", 6, 0.3, "Forage 6 finds from the ground"),
	"weaving_forage" = list("weaving", "forage", 8, 0.4, "Forage 8 finds from the ground"),
	"herbalism_forage" = list("herbalism", "forage", 10, 0.4, "Forage 10 finds from the ground"),
	"basic_agriculture_forage" = list("basic_agriculture", "forage", 12, 0.4, "Forage 12 finds from the ground"),
	"stone_arms_butchering" = list("stone_arms", "butchering", 2, 0.4, "Butcher 2 animals"),
	"archery_butchering" = list("archery", "butchering", 3, 0.4, "Butcher 3 animals"),
	"padded_armor_butchering" = list("padded_armor", "butchering", 2, 0.4, "Butcher 2 animals"))

#define FIELD_EXP_NODE 1
#define FIELD_EXP_ACTIVITY 2
#define FIELD_EXP_NEEDED 3
#define FIELD_EXP_SHARE 4
#define FIELD_EXP_TEXT 5

/mob/living/human
	var/list/field_work = null // activity id => amount done, capped at the most any experiment needs
	var/tmp/field_last_patient = null // the same patient twice in a row teaches nothing

/obj/item/weapon/book
	var/research_fieldwork = "" // "experiment_a;experiment_b" already written into this book

// The most of an activity any experiment asks for; counting stops there.
var/global/list/field_activity_caps = null

/proc/field_activity_cap(activity)
	build_practice_experiments()
	if (!field_activity_caps)
		field_activity_caps = list()
		for (var/id in field_experiments)
			var/list/E = field_experiments[id]
			field_activity_caps[E[FIELD_EXP_ACTIVITY]] = max(field_activity_caps[E[FIELD_EXP_ACTIVITY]] || 0, E[FIELD_EXP_NEEDED])
	return field_activity_caps[activity] || 0

// Experiments that advance a node.
/proc/node_field_experiments(node_id)
	build_practice_experiments()
	var/list/result = list()
	for (var/id in field_experiments)
		var/list/E = field_experiments[id]
		if (E[FIELD_EXP_NODE] == node_id)
			result += id
	return result

/mob/living/human/proc/field_work_amount(activity)
	if (!islist(field_work))
		return 0
	var/value = field_work[activity]
	return isnum(value) ? max(0, value) : 0

// Bench study rate for a node: late nodes are quicker on book-research worlds.
/proc/late_bench_rate(datum/research_node/N)
	return (N && N.era_tier >= FIELD_WORK_MIN_TIER) ? LATE_BENCH_RATE : 1

// Called from the systems themselves whenever someone does the activity.
/proc/note_field_work(mob/user, activity, amount = 1)
	var/mob/living/human/H = user
	if (!istype(H) || H.stat == DEAD || amount <= 0 || !map || !map.book_research_enabled())
		return FALSE
	var/cap = field_activity_cap(activity)
	if (!cap)
		return FALSE
	var/before = H.field_work_amount(activity)
	if (before >= cap)
		return FALSE
	var/after = min(cap, before + amount)
	if (!islist(H.field_work))
		H.field_work = list()
	H.field_work[activity] = after
	// Tell the character when their experience becomes worth reporting.
	for (var/id in field_experiments)
		var/list/E = field_experiments[id]
		if (E[FIELD_EXP_ACTIVITY] != activity || E[FIELD_EXP_NEEDED] <= before || E[FIELD_EXP_NEEDED] > after)
			continue
		var/datum/research_node/N = get_research_node(E[FIELD_EXP_NODE])
		// Only nodes this character could research now, so practice does not
		// announce every node further down the tree.
		if (N && !H.knows_recipe_node(N.id) && H.knows_research_prereqs(N.id))
			to_chat(H, SPAN_NOTICE("Your experience would help a scholar researching <b>[N.name]</b>. Stand at their research bench to have it written into the book."))
	return TRUE

// A doctor's diagnosis counts once per patient in a row.
/proc/note_field_diagnosis(mob/user, mob/patient)
	var/mob/living/human/H = user
	if (!istype(H) || !patient || patient == user)
		return FALSE
	var/who = "\ref[patient]"
	if (H.field_last_patient == who)
		return FALSE
	H.field_last_patient = who
	return note_field_work(H, "diagnosis")

/obj/item/weapon/book/proc/field_work_list()
	var/list/result = list()
	if (istext(research_fieldwork) && length(research_fieldwork))
		for (var/id in splittext(research_fieldwork, ";"))
			if (id in field_experiments)
				result |= id
	return result

/obj/item/weapon/book/proc/has_field_work(experiment_id)
	return experiment_id in field_work_list()

// Writes one experiment into the book. Returns the points added, or 0.
/obj/item/weapon/book/proc/record_field_work(experiment_id)
	var/list/E = field_experiments[experiment_id]
	if (!E || has_field_work(experiment_id) || has_research_chapter(E[FIELD_EXP_NODE]))
		return 0
	var/datum/research_node/N = get_research_node(E[FIELD_EXP_NODE])
	if (!N)
		return 0
	var/list/done = field_work_list()
	done += experiment_id
	research_fieldwork = jointext(done, ";")
	var/points = max(1, round(N.cost_ticks * E[FIELD_EXP_SHARE]))
	add_research_work(N.id, points)
	return points

// A finished chapter no longer needs its field work remembered.
/obj/item/weapon/book/proc/clear_field_work(node_id)
	var/list/kept = list()
	for (var/id in field_work_list())
		var/list/E = field_experiments[id]
		if (E[FIELD_EXP_NODE] != node_id)
			kept += id
	research_fieldwork = jointext(kept, ";")

// Each bench tick: anyone standing at the bench with enough experience has it
// written into the book. No scholarship is needed to report what you did.
/obj/structure/research_bench/proc/credit_field_work()
	var/obj/item/weapon/book/B = placed_book()
	if (!B || !assigned_node || B.has_research_chapter(assigned_node))
		return FALSE
	var/list/open = list()
	for (var/id in node_field_experiments(assigned_node))
		if (!B.has_field_work(id))
			open += id
	if (!open.len)
		return FALSE
	var/datum/research_node/N = get_research_node(assigned_node)
	var/credited = FALSE
	for (var/mob/living/human/H in range(BOOK_RESEARCH_REACH, src))
		if (H.stat != CONSCIOUS || !isturf(H.loc) || !H.research_presence())
			continue
		for (var/id in open.Copy())
			var/list/E = field_experiments[id]
			if (H.field_work_amount(E[FIELD_EXP_ACTIVITY]) < E[FIELD_EXP_NEEDED])
				continue
			var/points = B.record_field_work(id)
			if (!points)
				continue
			open -= id
			credited = TRUE
			var/finished = B.has_research_chapter(assigned_node)
			for (var/mob/living/human/V in viewers(world.view, src))
				to_chat(V, SPAN_NOTICE("[V == H ? "Your" : "[H.name]'s"] field work is written into [B]: <b>[N.name]</b> advances by [points] points[finished ? " and the chapter is finished. It can now be studied" : ""]."))
			if (finished)
				B.clear_field_work(assigned_node)
				return TRUE
	return credited

// Rows for the research windows: each experiment, whether the book has it,
// and how far the viewer's own experience goes.
/obj/structure/research_bench/proc/field_work_rows(mob/living/human/H, node_id)
	var/list/rows = list()
	if (!book_mode())
		return rows
	var/obj/item/weapon/book/B = placed_book()
	for (var/id in node_field_experiments(node_id))
		var/list/E = field_experiments[id]
		rows += list(list(
			"label" = E[FIELD_EXP_TEXT],
			"percent" = round(E[FIELD_EXP_SHARE] * 100),
			"done" = (B && B.has_field_work(id)) ? 1 : 0,
			"have" = H ? min(E[FIELD_EXP_NEEDED], H.field_work_amount(E[FIELD_EXP_ACTIVITY])) : 0,
			"needed" = E[FIELD_EXP_NEEDED]))
	return rows

#undef FIELD_EXP_NODE
#undef FIELD_EXP_ACTIVITY
#undef FIELD_EXP_NEEDED
#undef FIELD_EXP_SHARE
#undef FIELD_EXP_TEXT
#undef FIELD_WORK_MIN_TIER
#undef LATE_BENCH_RATE
