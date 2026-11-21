// Full-source probe for martial schools: the school list covers every era,
// choosing and leaving a school with its wait, ranks from practice, solo forms,
// practice from punches and hand sets, and the region travel record. Real
// humans; the waits and research knowledge are the test's.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/martial_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/martial_probe/New()
	map = src

/turf/floor/plating/martial_probe

/mob/living/human/martial_probe
var/martial_probe_checks = 0
var/martial_probe_wait = TRUE
var/list/martial_probe_known = list()

/mob/living/human/martial_probe/martial_forms_wait()
	return martial_probe_wait

/mob/living/human/martial_probe/martial_school_known(school_id)
	return school_id in martial_probe_known

/mob/living/human/martial_probe/conditioning_set_wait(atom/target)
	return TRUE

/mob/living/human/martial_probe/conditioning_roll(chance)
	return FALSE

/proc/martial_probe_assert(ok, label)
	martial_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/martial_probe_rest(mob/living/human/H)
	H.exercise_fatigue = 0
	H.nutrition = 400
	H.water = 400

/proc/martial_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/martial_probe
	map.ordinal_age = 0

	// --- every era opens a school, each with its own Military node ------------------
	var/list/eras = list()
	for (var/school_id in martial_schools)
		var/list/S = martial_schools[school_id]
		eras["[S[2]]"] = TRUE
		var/datum/research_node/N = get_research_node(S[3])
		martial_probe_assert(N && N.era_tier == S[2] && N.category == "Military" && ("martial_disciplines" in N.prereqs), "node_[school_id]")
	for (var/era in 0 to 9)
		martial_probe_assert(eras["[era]"], "era_[era]_has_a_school")
	martial_probe_assert(martial_schools.len == 12, "twelve_schools")

	var/mob/living/human/martial_probe/H = new(locate(3, 3, 1))
	H.stat = CONSCIOUS
	H.canmove = TRUE
	H.hand = 0
	martial_probe_rest(H)

	// --- no school, no rank ---------------------------------------------------------
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_NONE && !H.martial_school_choices().len, "starts_without_school")
	martial_probe_assert(!H.practise_martial_forms(), "forms_need_a_school")
	martial_probe_assert(H.martial_practice(5) == 0, "practice_without_school_counts_nothing")

	// --- choosing ----------------------------------------------------------------
	martial_probe_known = list("wing_chun", "grappling")
	martial_probe_assert(H.martial_school_choices().len == 2, "known_schools_are_choices")
	H.set_martial_school("wing_chun")
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_NOVICE && H.martial_rank("grappling") == MARTIAL_RANK_NONE, "joining_makes_a_novice")
	martial_probe_assert(H.martial_school_wait_text(), "change_starts_the_wait")
	H.set_martial_school("not_a_school")
	martial_probe_assert(isnull(H.martial_school), "unknown_school_is_refused")
	H.set_martial_school("wing_chun")

	// --- ranks ----------------------------------------------------------------
	H.martial_practice(39)
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_NOVICE, "39_is_still_novice")
	H.martial_practice(1)
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_STUDENT, "40_is_student")
	H.martial_practice(110)
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_ADEPT, "150_is_adept")
	H.martial_practice(250)
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_MASTER, "400_is_master")
	H.martial_practice(100000)
	martial_probe_assert(H.martial_points("wing_chun") == 1600, "points_are_capped")

	// --- leaving keeps progress ---------------------------------------------------------
	H.set_martial_school(null)
	martial_probe_assert(H.martial_rank("wing_chun") == MARTIAL_RANK_NONE && H.martial_points("wing_chun") == 1600, "leaving_keeps_points")
	H.set_martial_school("grappling")
	martial_probe_assert(H.martial_rank("grappling") == MARTIAL_RANK_NOVICE && H.martial_rank("wing_chun") == MARTIAL_RANK_NONE, "only_followed_school_ranks")

	// --- solo forms ------------------------------------------------------------------
	var/before = H.martial_points("grappling")
	var/unarmed_before = H.stats["unarmed"][1]
	martial_probe_assert(H.practise_martial_forms(), "forms_alone")
	martial_probe_assert(H.martial_points("grappling") > before && H.exercise_fatigue == 2 && H.stats["unarmed"][1] > unarmed_before, "forms_teach_and_tire")
	before = H.martial_points("grappling")
	martial_probe_wait = FALSE
	martial_probe_assert(!H.practise_martial_forms() && H.martial_points("grappling") == before, "interrupted_forms_give_nothing")
	martial_probe_wait = TRUE
	var/obj/item/stack/material/cloth/C = new(H.loc, 1)
	H.put_in_active_hand(C)
	martial_probe_assert(!H.practise_martial_forms(), "forms_need_empty_hands")
	H.drop_from_inventory(C)
	qdel(C)
	H.exercise_fatigue = 6
	martial_probe_assert(!H.practise_martial_forms(), "exhausted_cannot_drill")
	martial_probe_rest(H)

	// --- punches and hand sets count ---------------------------------------------------
	before = H.martial_points("grappling")
	H.practice_unarmed(0.5)
	martial_probe_assert(abs(H.martial_points("grappling") - before - 0.25) < 0.001, "landed_punch_counts")
	before = H.martial_points("grappling")
	H.a_intent = I_HARM
	var/obj/structure/striking_post/M = new(locate(4, 3, 1))
	M.attack_hand(H)
	martial_probe_assert(abs(H.martial_points("grappling") - before - 0.5) < 0.001, "hand_set_counts")
	martial_probe_rest(H)

	// --- region travel ----------------------------------------------------------------
	H.hand_conditioning = 20
	H.hand_conditioning_at = world.realtime
	var/list/R = H.martial_travel_record()
	martial_probe_assert(martial_travel_valid(R), "travel_record_valid")
	var/mob/living/human/martial_probe/T = new(locate(5, 5, 1))
	martial_probe_assert(T.martial_travel_restore(R), "travel_restores")
	martial_probe_assert(T.martial_school == "grappling" && T.martial_points("wing_chun") == 1600 && T.hand_conditioning == 20 && T.martial_school_lock == H.martial_school_lock, "travel_carries_school_points_hands")
	R["school"] = "sleeping_carp"
	martial_probe_assert(!martial_travel_valid(R), "travel_rejects_unknown_school")
	R["school"] = "grappling"
	R["progress"] = list("grappling" = -5)
	martial_probe_assert(!martial_travel_valid(R), "travel_rejects_negative_points")
	var/mob/living/human/martial_probe/fresh = new(locate(6, 6, 1))
	martial_probe_assert(isnull(fresh.martial_travel_record()), "untrained_body_sends_nothing")

/world/New()
	OpenPort("none")
	var/error = null
	try
		martial_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = martial_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
