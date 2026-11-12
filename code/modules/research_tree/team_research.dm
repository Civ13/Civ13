// ============================================================
// Research Tree - research teams and rushed work (Val, 2026-11-12)
// ------------------------------------------------------------
// On book-research worlds:
//  - Big science: a few of the largest late subjects need a second scholar of
//    another discipline at the bench and a facility nearby. A lone scholar,
//    or one without the facility, can still finish, at a heavy penalty.
//  - On any other late subject a second scholar who could research it too
//    speeds the work up a little.
//  - A bench can be told to rush a late subject: faster, with a chance of an
//    accident that fits the subject. Careful work stays the default.
// ============================================================

#define TEAM_MIN_TIER 5
// Big science without its second scholar / without its facility.
#define BIG_SCIENCE_SOLO_RATE 0.25
#define BIG_SCIENCE_NO_FACILITY_RATE 0.5
// A second able scholar on an ordinary late subject.
#define TEAM_SECOND_SCHOLAR_RATE 1.25
#define FACILITY_REACH 3
// Rushed work: speed, accident chance per bench interval (percent) at the
// bare skill requirement, and the share of the subject an accident undoes.
#define RUSH_RATE 1.5
#define RUSH_ACCIDENT_CHANCE 1
#define RUSH_PROGRESS_LOSS 0.05

// node id => list(second discipline, facility id)
var/global/list/big_science_nodes = list(
	"nuclear_power" = list("engineering", "laboratory"),
	"digital_computing" = list("engineering", "machine_shop"),
	"rocketry" = list("engineering", "machine_shop"),
	"orbital_flight" = list("natural_science", "launch_range"),
	"modern_medicine" = list("natural_science", "operating_theatre"))

// facility id => list(what to call it, the structure that makes one)
var/global/list/research_facilities = list(
	"laboratory" = list("A laboratory (a reaction bench)", /obj/structure/reaction_bench),
	"machine_shop" = list("A machine shop (a foundry workbench)", /obj/structure/component_workbench/toolsmith/foundry),
	"launch_range" = list("A launch range (a launch rail)", /obj/structure/launch_rail),
	"operating_theatre" = list("An operating theatre (an operating table)", /obj/structure/optable))

/obj/structure/research_bench
	var/rushed = FALSE // rushing late subjects: faster, with accidents

/proc/is_big_science(node_id)
	return node_id in big_science_nodes

// The level the second scholar needs in the second discipline: half of what
// leading a subject of that era in it would take.
/proc/big_science_assistant_level(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	var/list/B = big_science_nodes[node_id]
	if (!N || !B)
		return 0
	var/steps = max(0, N.era_tier - scholar_entry_tier(B[1]))
	return round(min(SCHOLAR_MAX_LEVEL, steps * SCHOLAR_LEVEL_PER_TIER) / 2)

/mob/living/human/proc/can_assist_research_at(obj/structure/research_bench/B)
	return stat == CONSCIOUS && !incapacitated() && research_presence() && isturf(loc) && loc.z == B.z && get_dist(src, B) <= BOOK_RESEARCH_REACH

// The second scholar for a big science subject, if one is at the bench.
/obj/structure/research_bench/proc/big_science_assistant(node_id, mob/living/human/lead)
	var/list/B = big_science_nodes[node_id]
	if (!B)
		return null
	var/need = big_science_assistant_level(node_id)
	for (var/mob/living/human/H in range(BOOK_RESEARCH_REACH, src))
		if (H != lead && H.can_assist_research_at(src) && H.scholar_level(B[1]) >= need)
			return H
	return null

/obj/structure/research_bench/proc/has_research_facility(node_id)
	var/list/B = big_science_nodes[node_id]
	if (!B)
		return TRUE
	var/list/F = research_facilities[B[2]]
	return F && !!(locate(F[2]) in range(FACILITY_REACH, src))

// Another scholar at the bench who could research this subject alone.
/obj/structure/research_bench/proc/second_scholar(node_id, mob/living/human/lead)
	for (var/mob/living/human/H in range(BOOK_RESEARCH_REACH, src))
		if (H != lead && H.can_research_node_at(src, node_id))
			return H
	return null

// Speed multiplier from who and what is around the bench.
/obj/structure/research_bench/proc/team_rate(node_id, mob/living/human/lead)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !lead || N.era_tier < TEAM_MIN_TIER)
		return 1
	if (is_big_science(node_id))
		var/rate = 1
		if (!big_science_assistant(node_id, lead))
			rate *= BIG_SCIENCE_SOLO_RATE
		if (!has_research_facility(node_id))
			rate *= BIG_SCIENCE_NO_FACILITY_RATE
		return rate
	return second_scholar(node_id, lead) ? TEAM_SECOND_SCHOLAR_RATE : 1

// Checklist rows for the research windows. lead may be null (nobody working).
/obj/structure/research_bench/proc/team_rows(node_id, mob/living/human/lead)
	var/list/rows = list()
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !book_mode() || N.era_tier < TEAM_MIN_TIER)
		return rows
	var/list/B = big_science_nodes[node_id]
	if (B)
		var/list/F = research_facilities[B[2]]
		rows += list(list("label" = "A second scholar at the bench with [scholar_disciplines[B[1]]] [big_science_assistant_level(node_id)] (a quarter speed without one)", "ok" = big_science_assistant(node_id, lead) ? 1 : 0))
		rows += list(list("label" = "[F[1]] within [FACILITY_REACH] tiles (half speed without one)", "ok" = has_research_facility(node_id) ? 1 : 0))
	else if (lead && second_scholar(node_id, lead))
		rows += list(list("label" = "A second scholar is helping: research is [round((TEAM_SECOND_SCHOLAR_RATE - 1) * 100)]% faster", "ok" = 1))
	return rows

// ------------------------------------------------------------
// Rushed research
// ------------------------------------------------------------

/proc/node_can_be_rushed(datum/research_node/N)
	return N && N.era_tier >= TEAM_MIN_TIER

/obj/structure/research_bench/proc/rush_rate(datum/research_node/N)
	return (rushed && node_can_be_rushed(N)) ? RUSH_RATE : 1

/obj/structure/research_bench/proc/book_toggle_rush(mob/living/human/H)
	if (!book_mode() || !H || H.stat != CONSCIOUS || get_dist(H, src) > BOOK_RESEARCH_REACH)
		return FALSE
	rushed = !rushed
	if (rushed)
		to_chat(H, SPAN_WARNING("The bench will rush late subjects: half again as fast, but accidents can hurt the researcher and undo some of the work. Skill well above the subject's level makes them rarer."))
	else
		to_chat(H, SPAN_NOTICE("The bench goes back to careful work."))
	return TRUE

// Percent chance of an accident for one bench interval of rushed work.
/proc/rush_accident_chance(mob/living/human/researcher, node_id)
	if (!researcher)
		return 0
	var/margin = researcher.scholar_level(node_discipline(node_id)) - node_scholar_requirement(node_id)
	return RUSH_ACCIDENT_CHANCE * clamp(1 - margin / 40, 0.2, 1)

// What goes wrong, by subject: "radiation", "blast", "poison", "injury" or "error".
/proc/rush_accident_kind(node_id)
	if (node_id == "nuclear_power")
		return "radiation"
	switch (node_discipline(node_id))
		if ("natural_science", "military")
			return "blast"
		if ("medicine", "agriculture")
			return "poison"
		if ("engineering")
			return "injury"
	return "error"

// Takes points back out of a book's unfinished work. Returns the points lost.
/obj/item/weapon/book/proc/lose_research_work(node_id, amount)
	var/list/progress = research_progress_map()
	var/list/entry = progress[node_id]
	if (!entry || amount <= 0)
		return 0
	var/lost = min(entry[1], amount)
	entry[1] -= lost
	progress[node_id] = entry
	set_research_progress_map(progress)
	return lost

// One accident: hurts whoever it should and undoes some of the work.
/obj/structure/research_bench/proc/research_accident(mob/living/human/researcher, datum/research_node/N, obj/item/weapon/book/B)
	if (!researcher || !N || !B)
		return null
	var/kind = rush_accident_kind(N.id)
	var/loss = RUSH_PROGRESS_LOSS
	switch (kind)
		if ("radiation")
			for (var/mob/living/human/H in range(2, src))
				H.apply_effect(25, IRRADIATE, blocked = 0)
				to_chat(H, SPAN_DANGER("The rushed experiment at [src] floods the room with radiation!"))
		if ("blast")
			for (var/mob/living/human/H in range(1, src))
				H.apply_damage(H == researcher ? rand(10, 20) : rand(5, 10), BURN)
				to_chat(H, SPAN_DANGER("The rushed experiment at [src] goes up in a flash and a bang!"))
		if ("poison")
			researcher.apply_damage(rand(8, 15), TOX)
			to_chat(researcher, SPAN_DANGER("The rushed trial goes wrong and you feel sick."))
		if ("injury")
			researcher.apply_damage(rand(8, 15), BRUTE, pick("l_hand", "r_hand"))
			to_chat(researcher, SPAN_DANGER("The rushed build slips and crushes your hand."))
		else
			loss *= 2
			to_chat(researcher, SPAN_DANGER("You find a mistake in the rushed work and have to throw part of it out."))
	var/lost = B.lose_research_work(N.id, round(N.cost_ticks * loss))
	if (lost)
		to_chat(researcher, SPAN_WARNING("[lost] points of work on <b>[N.name]</b> are lost."))
	return kind

// Called from the bench tick after rushed work was written.
/obj/structure/research_bench/proc/roll_rush_accident(mob/living/human/researcher, datum/research_node/N, obj/item/weapon/book/B, intervals = 1)
	if (!rushed || !node_can_be_rushed(N) || !researcher)
		return null
	if (!prob(min(100, rush_accident_chance(researcher, N.id) * max(1, intervals))))
		return null
	return research_accident(researcher, N, B)

#undef TEAM_MIN_TIER
#undef BIG_SCIENCE_SOLO_RATE
#undef BIG_SCIENCE_NO_FACILITY_RATE
#undef TEAM_SECOND_SCHOLAR_RATE
#undef FACILITY_REACH
#undef RUSH_RATE
#undef RUSH_ACCIDENT_CHANCE
#undef RUSH_PROGRESS_LOSS
