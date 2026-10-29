// SOURCE ONLY. No runner is supplied; native compilation/execution needs review.
// All startup, client, GC, parent movement and non-membership effects below
// are fixture adapters. production.dm contains the extracted production bodies.
var/list/mob_list = list()
var/list/human_mob_list = list()
var/list/dead_mob_list = list()
var/list/living_mob_list = list()
var/list/living_complex_animal_list = list()
var/list/movementMachine_clients = list()
var/list/probe_trace = list()
var/list/probe_events = list()
var/list/probe_cohort = list()
var/list/probe_owned = list()
var/list/probe_results = list()
var/probe_mode = "legacy"
var/probe_kind = "human"
var/probe_case = "plain"
var/probe_depth = 0
var/probe_roll = 100
var/probe_checks = 0
var/probe_failures = 0
var/probe_failure

/world
    maxx = 16
    maxy = 16
    maxz = 2
    visibility = FALSE
    hub = ""
/world/OpenPort(port)
    if (port == "none") return ..()
    return FALSE
/client/New()
    del(src)
    return
/world/Error(exception/E)
    probe_failures++
    probe_failure = "UNEXPECTED [E]"
    world.log << "UNEXPECTED [E]"

/atom/proc/Destroy()
    return
/proc/qdel(datum/D)
    if (D) del(D)
/proc/isnewplayer(mob/M)
    return istype(M, /mob/new_player)
/mob/new_player
/mob/dview
/mob
    var/stat = CONSCIOUS
    var/hud_used
    var/timeofdeath
    var/probe_id = "unassigned"
    var/probe_fired = FALSE
/mob/proc/unset_using_object()
    return
/mob/proc/ghostize()
    return
/mob/proc/remove_screen_obj_references()
    return
/mob/proc/set_stat(value)
    stat = value
/mob/Del()
    // Exercise actual Destroy through an explicit deletion adapter, not game GC.
    Destroy()
    return ..()
/mob/living
    var/health = 1
/mob/living/human/New()
    probe_owned += src
    human_mob_list += src
    return ..()
/mob/living/simple_animal
    var/icon_living = ""
/mob/living/simple_animal/complex_animal
    var/base_type = "dog"
    var/sightrange = 10
    var/hearrange = 10
    var/smellrange = 10
    var/list/knows_about_mobs = list()
/mob/living/simple_animal/complex_animal/deadborn
    stat = DEAD
/mob/living/simple_animal/complex_animal/proc/probe_parent_move()
    return TRUE
/mob/living/simple_animal/complex_animal/proc/onHumanMovement(mob/M)
    probe_callback(src, "human")
/mob/living/simple_animal/complex_animal/proc/onEveryBaseTypeMovement(mob/M)
    probe_callback(src, "base")
/mob/living/simple_animal/complex_animal/proc/onEveryXMovement(path)
    probe_callback(src, "type")

/proc/probe_assert(ok, label)
    probe_checks++
    if (!ok) throw "ASSERT [label]"
/proc/probe_record(value)
    probe_assert(probe_trace.len < 256, "bound.trace")
    probe_trace += value
/proc/probe_prob(mob/living/simple_animal/complex_animal/C, chance)
    probe_record("P[probe_depth]|[C.probe_id]|[chance]|[probe_roll]")
    return probe_roll <= chance
/proc/probe_projection()
    var/list/expected = list()
    var/list/actual = list()
    for (var/mob/living/simple_animal/complex_animal/C in living_mob_list)
        expected += C
    for (var/mob/living/simple_animal/complex_animal/C in living_complex_animal_list)
        actual += C
    probe_assert(expected.len == actual.len, "projection.length")
    for (var/i = 1 to expected.len)
        probe_assert(expected[i] == actual[i], "projection.identity-order")
    return actual
/proc/probe_names()
    var/list/ids = list()
    for (var/mob/living/simple_animal/complex_animal/C in probe_projection())
        ids += C.probe_id
    return jointext(ids, ",")
/proc/probe_expect_names(expected, label)
    // Check named invariant first so controls have a precise failure oracle.
    var/list/ids = list()
    for (var/mob/living/simple_animal/complex_animal/C in living_complex_animal_list)
        ids += C.probe_id
    probe_assert(jointext(ids, ",") == expected, label)
    probe_projection()
/proc/probe_reset()
    for (var/mob/M in probe_owned.Copy())
        del(M)
    probe_owned = list()
    mob_list = list()
    human_mob_list = list()
    dead_mob_list = list()
    living_mob_list = list()
    living_complex_animal_list = list()
    probe_trace = list()
    probe_events = list()
    probe_cohort = list()
    probe_depth = 0
    probe_roll = 100
/proc/probe_animal(id, level = 1)
    var/mob/living/simple_animal/complex_animal/C = new(locate(2, 2, level))
    probe_owned += C
    C.probe_id = id
    return C
/proc/probe_lifecycle()
    probe_reset()
    var/mob/living/human/H = new(locate(2, 2, 1))
    H.probe_id = "human"
    probe_expect_names("", "lifecycle.constructor-human")
    var/mob/living/simple_animal/complex_animal/A = probe_animal("a")
    probe_expect_names("a", "lifecycle.constructor-complex")
    var/mob/living/simple_animal/complex_animal/B = probe_animal("b")
    probe_expect_names("a,b", "lifecycle.constructor-second")
    var/mob/living/simple_animal/complex_animal/deadborn/D = new
    probe_owned += D
    probe_assert((D in dead_mob_list) && !(D in living_complex_animal_list), "lifecycle.constructor-dead")
    var/mob/dview/V = new
    probe_owned += V
    probe_assert(!(V in living_mob_list), "lifecycle.dview-removal")
    var/mob/living/human/announcer/N = new
    probe_assert(!(N in living_mob_list), "lifecycle.announcer-removal")
    probe_assert(!A.add_to_living_mob_list(), "lifecycle.guard-duplicate")
    probe_assert(A.remove_from_living_mob_list(), "lifecycle.remove-return")
    probe_expect_names("b", "lifecycle.guard-remove")
    probe_assert(!A.remove_from_living_mob_list(), "lifecycle.absent-return")
    probe_assert(A.add_to_living_mob_list(), "lifecycle.readmit-return")
    probe_expect_names("b,a", "lifecycle.readmit-tail")
    A.stat = DEAD
    A.probe_death_fragment()
    probe_expect_names("b", "lifecycle.death-fragment")
    A.probe_rejuvenate_fragment()
    probe_expect_names("b,a", "lifecycle.rejuvenate-fragment")
    probe_assert(A.stat == CONSCIOUS, "lifecycle.rejuvenate-stat")
    A.stat = DEAD
    A.probe_death_fragment()
    A.health = 1
    A.probe_life_fragment()
    probe_expect_names("b,a", "lifecycle.life-revival-fragment")
    probe_admin_fragment(A, DEAD)
    probe_expect_names("b", "lifecycle.admin-death-fragment")
    probe_admin_fragment(A, CONSCIOUS)
    probe_expect_names("b,a", "lifecycle.admin-revival-fragment")
    A.switch_from_living_to_dead_mob_list()
    probe_expect_names("b", "lifecycle.switch-dead")
    A.switch_from_dead_to_living_mob_list()
    probe_expect_names("b,a", "lifecycle.switch-living")
    H.stat = DEAD
    H.probe_after_load_fragment()
    probe_assert(!(H in living_mob_list) && (H in dead_mob_list), "lifecycle.restored-human")
    register_living_mob(A)
    probe_expect_names("b,a,a", "lifecycle.duplicate-append")
    unregister_living_mob(A)
    probe_expect_names("b,a", "lifecycle.duplicate-last-remove")
    probe_cleanup_one(B)
    probe_expect_names("a", "lifecycle.cleanup-one")
    probe_cleanup_two(A)
    probe_expect_names("", "lifecycle.cleanup-two")
    register_living_mob(A)
    register_living_mob(A)
    del(A)
    probe_expect_names("", "lifecycle.native-nulling")
    probe_assert(living_complex_animal_list.len == 1 && isnull(living_complex_animal_list[1]), "lifecycle.native-null-slot")
    probe_cleanup_two(null)
    probe_expect_names("", "lifecycle.null-cleanup")
    probe_results += list(list("case" = "lifecycle", "passed" = TRUE))

/proc/probe_dispatch(mob/M)
    probe_assert(probe_depth <= 1, "bound.reentry")
    if (probe_kind == "human")
        if (probe_mode == "legacy") M.probe_legacy_human()
        else M.probe_candidate_human()
    else
        var/mob/living/simple_animal/complex_animal/C = M
        if (probe_mode == "legacy") C.probe_legacy_animal()
        else C.probe_candidate_animal()
/proc/probe_callback(mob/living/simple_animal/complex_animal/C, kind)
    probe_events += "[probe_depth]|[C.probe_id]|[kind]"
    probe_record("E[probe_depth]|[C.probe_id]|[kind]")
    if (C.probe_id != "a" || C.probe_fired) return
    C.probe_fired = TRUE
    switch (probe_case)
        if ("remove-unrelated") unregister_living_mob(probe_cohort["u"])
        if ("remove-self") unregister_living_mob(C)
        if ("remove-next") unregister_living_mob(probe_cohort["b"])
        if ("append") probe_animal("d")
        if ("delete-self") del(C)
        if ("delete-next", "delete-duplicate")
            var/mob/target = probe_cohort["b"]
            del(target)
        if ("reentry")
            probe_depth++
            probe_dispatch(probe_cohort["mover"])
            probe_depth--
        if ("yield-remove-next")
            spawn (0)
                unregister_living_mob(probe_cohort["b"])
            sleep(1)
        if ("yield-append")
            spawn (0)
                probe_animal("d")
            sleep(1)
    probe_projection()
/proc/probe_iteration(mode, kind, case_name)
    probe_reset()
    probe_mode = mode
    probe_kind = kind
    probe_case = case_name
    var/mob/living/human/U = new(locate(2, 2, 1))
    var/mob/M
    if (kind == "human") M = new /mob/living/human(locate(2, 2, 1))
    else M = probe_animal("mover")
    M.probe_id = "mover"
    var/mob/living/simple_animal/complex_animal/A = probe_animal("a")
    var/mob/living/human/H = new(locate(2, 2, 1))
    var/mob/living/simple_animal/complex_animal/B = probe_animal("b")
    var/mob/living/simple_animal/complex_animal/C = probe_animal("c", 2)
    probe_cohort = list("mover" = M, "u" = U, "a" = A, "h" = H, "b" = B, "c" = C)
    if (case_name == "duplicate") register_living_mob(A)
    if (case_name == "delete-duplicate") register_living_mob(B)
    if (case_name == "different-base") C.base_type = "wolf"
    if (case_name == "far") C.loc = locate(15, 15, 2)
    if (case_name == "coordinate-policy") M.loc = locate(2, 15, 1)
    if (case_name == "knowledge") probe_roll = 1
    probe_projection()
    probe_dispatch(M)
    var/list/knowledge = list()
    for (var/mob/living/simple_animal/complex_animal/observer in living_mob_list)
        if (observer == M) continue
        var/list/known = list()
        for (var/mob/subject in observer.knows_about_mobs)
            known += subject.probe_id
        knowledge += list(list("id" = observer.probe_id, "known" = known))
    return list("trace" = probe_trace.Copy(), "events" = probe_events.Copy(), "members" = probe_names(), "knowledge" = knowledge)

/proc/probe_main()
    probe_lifecycle()
    var/list/contract = json_decode(file2text("expectations.json"))
    probe_assert(contract["cases"].len == 16, "contract.case-count")
    for (var/kind in list("human", "animal"))
        for (var/list/case_info in contract["cases"])
            var/id = case_info["id"]
            var/list/legacy = probe_iteration("legacy", kind, id)
            var/list/candidate = probe_iteration("candidate", kind, id)
            probe_assert(json_encode(legacy) == json_encode(candidate), "parity.[kind].[id]")
            if (!isnull(case_info["events"][kind]))
                probe_assert(json_encode(candidate["events"]) == json_encode(case_info["events"][kind]), "events.[kind].[id]")
            var/prefix = kind == "animal" ? "mover," : ""
            probe_assert(candidate["members"] == "[prefix][case_info["members"]]", "members.[kind].[id]")
            probe_results += list(list("kind" = kind, "case" = id, "legacy" = legacy, "candidate" = candidate))
    probe_assert(probe_results.len == 33, "results.complete")
    probe_reset()
/world/New()
    OpenPort("none")
    try
        probe_assert(!world.port && !OpenPort(12345), "closed-port-state")
        probe_main()
    catch (var/exception/fixture_error)
        probe_failures++
        probe_failure = "[fixture_error]"
        world.log << "FAIL [fixture_error]"
    text2file(json_encode(list("checks" = probe_checks, "failures" = probe_failures, "failure" = probe_failure, "results" = probe_results)), "result.json")
    world.log << "RESULT checks=[probe_checks] failures=[probe_failures]"
    del(world)
    return
