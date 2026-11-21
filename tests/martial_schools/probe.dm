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
var/list/martial_probe_known

/mob/living/human/martial_probe/martial_forms_wait()
	return martial_probe_wait

/mob/living/human/martial_probe/martial_school_known(school_id)
	return school_id in martial_probe_known

var/list/martial_probe_present
var/list/martial_probe_verified

/mob/living/human/martial_probe/martial_company_present(mob/living/human/other)
	return other in martial_probe_present

/mob/living/human/martial_probe/martial_master_verified(mob/living/human/other)
	return other in martial_probe_verified

/mob/living/human/martial_probe/martial_drill_wait(atom/target)
	return martial_probe_wait

/mob/living/human/martial_probe/conditioning_set_wait(atom/target)
	return TRUE

/mob/living/human/martial_probe/conditioning_roll(chance)
	return FALSE

var/martial_probe_day = 100
var/martial_probe_scholarly = FALSE

/mob/living/human/martial_probe/martial_today()
	return martial_probe_day

/obj/map_metadata/martial_probe/book_research_enabled()
	return martial_probe_scholarly

/proc/martial_probe_assert(ok, label)
	martial_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/martial_probe_rest(mob/living/human/H)
	H.exercise_fatigue = 0
	H.nutrition = 400
	H.water = 400

/proc/martial_probe_run()
	// Set here, not in the global initialiser, which is at the compiler size limit.
	martial_probe_known = list()
	martial_probe_present = list()
	martial_probe_verified = list()
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
	build_research_tree()
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

	// --- training company -------------------------------------------------------------
	var/mob/living/human/martial_probe/P = new(locate(4, 4, 1))
	P.stat = CONSCIOUS
	P.martial_school = "grappling"
	martial_probe_assert(H.martial_training_mult() == 1, "absent_partner_does_not_count")
	martial_probe_present += P
	martial_probe_assert(H.martial_training_mult() == 1.5, "partner_of_same_school_x1_5")
	P.martial_school = "wing_chun"
	martial_probe_assert(H.martial_training_mult() == 1, "partner_of_other_school_does_not_count")
	P.martial_school = "grappling"
	P.martial_progress = list("grappling" = 400)
	martial_probe_assert(H.martial_training_mult() == 1.5, "unverified_master_is_only_a_partner")
	martial_probe_verified += P
	martial_probe_assert(H.martial_training_mult() == 2, "verified_master_nearby_x2")
	martial_probe_assert(H.martial_training_mult(P) == 2.5, "sparring_a_verified_master_x2_5")
	before = H.martial_points("grappling")
	H.practice_unarmed(0.5, P)
	martial_probe_assert(abs(H.martial_points("grappling") - before - 0.625) < 0.001, "sparring_punch_counts_x2_5")
	P.forceMove(locate(8, 8, 1))
	martial_probe_assert(H.martial_training_mult() == 1, "company_must_be_within_2_tiles")
	P.forceMove(locate(4, 4, 1))
	P.stat = UNCONSCIOUS
	martial_probe_assert(H.martial_training_mult() == 1, "sleeping_company_does_not_count")
	P.stat = CONSCIOUS
	martial_probe_present += H
	martial_probe_assert(P.martial_training_mult() == 1.5, "master_training_beside_a_student_gets_partner_bonus")
	martial_probe_present -= list(P, H)
	martial_probe_verified -= P

	// --- training gear ------------------------------------------------------------------
	martial_probe_rest(H)
	var/obj/structure/martial_gear/heavy_bag/B = new(locate(2, 3, 1))
	var/obj/structure/martial_gear/wooden_dummy/D = new(locate(3, 2, 1))
	before = H.martial_points("grappling")
	var/hands_before = H.hand_conditioning
	B.attack_hand(H)
	martial_probe_assert(abs(H.martial_points("grappling") - before - 1.5) < 0.001 && H.exercise_fatigue == 2, "heavy_bag_drill_pays_1_5")
	martial_probe_assert(H.hand_conditioning == hands_before, "gear_builds_no_conditioning")
	martial_probe_rest(H)
	before = H.martial_points("grappling")
	D.attack_hand(H)
	martial_probe_assert(abs(H.martial_points("grappling") - before - 2) < 0.001, "wooden_dummy_drill_pays_2")
	martial_probe_rest(H)
	martial_probe_wait = FALSE
	before = H.martial_points("grappling")
	D.attack_hand(H)
	martial_probe_assert(H.martial_points("grappling") == before, "interrupted_drill_gives_nothing")
	martial_probe_wait = TRUE
	H.a_intent = I_HELP
	B.attack_hand(H)
	martial_probe_assert(H.martial_points("grappling") == before, "help_intent_does_not_drill")
	H.a_intent = I_HARM
	martial_probe_assert(("heavy_bag" in icon_states(B.icon)) && ("wooden_dummy" in icon_states(D.icon)), "gear_icon_states")
	martial_probe_rest(H)

	// --- wrestling mat: full drill for grappling schools, half for the rest ------------
	var/obj/structure/martial_gear/wrestling_mat/W = new(locate(4, 2, 1))
	martial_probe_assert(!W.density && ("wrestling_mat" in icon_states(W.icon)), "wrestling_mat_lies_flat")
	before = H.martial_points("grappling")
	W.attack_hand(H)
	martial_probe_assert(abs(H.martial_points("grappling") - before - 2) < 0.001, "wrestling_mat_pays_grapplers_2")
	martial_probe_rest(H)
	var/mob/living/human/martial_probe/S = new(locate(5, 2, 1))
	S.stat = CONSCIOUS
	S.canmove = TRUE
	S.hand = 0
	martial_probe_rest(S)
	S.martial_school = "pugilism"
	S.a_intent = I_HARM
	W.attack_hand(S)
	martial_probe_assert(abs(S.martial_points("pugilism") - 1.25) < 0.001, "wrestling_mat_pays_strikers_half")

	// --- fights count toward a daily cap; a verified Master does not ------------------
	var/mob/living/human/martial_probe/F = new(locate(6, 3, 1))
	F.stat = CONSCIOUS
	F.canmove = TRUE
	F.hand = 0
	martial_probe_rest(F)
	F.martial_school = "grappling"
	var/mob/living/human/martial_probe/Q = new(locate(6, 4, 1))
	Q.stat = CONSCIOUS
	for (var/i in 1 to 60)
		F.practice_unarmed(0.5, Q)
	martial_probe_assert(abs(F.martial_points("grappling") - 10) < 0.001, "fight_gains_capped_at_10_a_day")
	F.practise_martial_forms()
	martial_probe_assert(F.martial_points("grappling") > 10, "forms_are_not_capped")
	before = F.martial_points("grappling")
	Q.martial_school = "grappling"
	Q.martial_progress = list("grappling" = 400)
	martial_probe_present += Q
	martial_probe_verified += Q
	F.practice_unarmed(0.5, Q)
	martial_probe_assert(abs(F.martial_points("grappling") - before - 0.625) < 0.001, "verified_master_sparring_is_not_capped")
	martial_probe_present -= Q
	martial_probe_verified -= Q
	before = F.martial_points("grappling")
	F.practice_unarmed(0.5, Q)
	martial_probe_assert(F.martial_points("grappling") == before, "cap_holds_for_the_rest_of_the_day")
	martial_probe_day++
	F.practice_unarmed(0.5, Q)
	martial_probe_assert(abs(F.martial_points("grappling") - before - 0.25) < 0.001, "cap_resets_next_day")
	martial_probe_assert(F.martial_travel_record()["fight"] == 0.25, "fight_count_travels")

	// --- first Master pays Military Science once --------------------------------------
	martial_probe_scholarly = TRUE
	var/mob/living/human/martial_probe/G = new(locate(7, 3, 1))
	G.stat = CONSCIOUS
	G.martial_school = "judo"
	G.martial_practice(399)
	martial_probe_assert(G.scholar_level("military") == 0, "adept_gets_no_scholarship")
	G.martial_practice(5)
	martial_probe_assert(G.scholar_level("military") == 8 && (skill_mastery_key("military", "school") in G.skill_mastery), "master_gains_8_military_levels")
	G.martial_school = "bjj"
	G.martial_practice(400)
	martial_probe_assert(G.scholar_level("military") == 8, "second_master_pays_nothing")
	martial_probe_scholarly = FALSE

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

	// --- school moves --------------------------------------------------------------------
	var/mob/living/human/martial_probe/K = new(locate(7, 7, 1))
	martial_probe_assert(K.martial_punch_mult("head") == 1 && K.martial_grapple_power() == 1, "no_school_no_moves")
	K.set_martial_school("pugilism")
	martial_probe_assert(K.martial_punch_mult("head") == 1, "novice_has_no_moves")
	K.martial_progress["pugilism"] = 400
	martial_probe_assert(abs(K.martial_punch_mult("chest") - 1.15) < 0.001, "master_pugilist_hits_harder")
	martial_probe_assert(abs(K.martial_punch_mult("head") - 1.3) < 0.001, "pugilist_focus_on_the_head")
	martial_probe_assert(K.martial_grapple_power() == 1, "pugilism_does_not_grapple")
	K.set_martial_school("hard_hand")
	K.martial_progress["hard_hand"] = 150
	K.hand_conditioning = 50
	K.hand_conditioning_at = world.realtime
	martial_probe_assert(abs(K.martial_punch_mult("chest") - 1.2) < 0.001, "hard_hand_turns_conditioning_into_damage")
	K.set_martial_school("judo")
	K.martial_progress["judo"] = 400
	martial_probe_assert(abs(K.martial_grapple_power() - 1.3) < 0.001, "master_judoka_grapples_better")
	martial_probe_assert(abs(martial_grapple_edge(K, fresh) - 1.3) < 0.001 && abs(martial_grapple_edge(fresh, K) - 1 / 1.3) < 0.001, "grapple_edge_both_ways")
	martial_probe_assert(martial_grapple_edge(fresh, null) == 1, "grapple_edge_without_human_is_even")
	for (var/school_id in martial_schools)
		martial_probe_assert(islist(martial_school_moves(school_id)), "moves_[school_id]")

	// --- the old SS13 arts are gone -----------------------------------------------------------
	martial_probe_assert(!text2path("/datum/martial_art"), "old_martial_art_datum_removed")

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
