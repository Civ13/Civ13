// Synthetic engine observation only. This file is not Civ13 production code.
world
    name = "native_group_probe"
    turf = /turf/group_probe
    maxx = 8
    maxy = 6
    maxz = 1
    icon_size = 32
    fps = 20
    movement_mode = LEGACY_MOVEMENT_MODE

var/global/mob/group_probe/probe_a
var/global/mob/group_probe/probe_b
var/global/list/probe_events = list()
var/global/list/probe_cases = list()
var/global/probe_active = FALSE
var/global/probe_overflow = FALSE
var/global/probe_case = "setup"
var/global/probe_bump_depth = 0

/proc/probe_actor(mob/group_probe/M)
    if (!M)
        return null
    return list("lifetime" = M.probe_lifetime, "x" = M.x, "y" = M.y, "z" = M.z,
        "sx" = M.step_x, "sy" = M.step_y, "step_size" = M.step_size,
        "bound_x" = M.bound_x, "bound_y" = M.bound_y,
        "bound_width" = M.bound_width, "bound_height" = M.bound_height,
        "appearance_flags" = M.appearance_flags, "tile_mover" = !!(M.appearance_flags & TILE_MOVER), "density" = M.density,
        "anchored" = M.anchored)

/proc/probe_record(kind, atom/receiver = null, atom/subject = null, var/result = null)
    if (!probe_active)
        return
    if (probe_events.len >= 256)
        probe_overflow = TRUE
        return
    var/rid = receiver == probe_a ? "a" : receiver == probe_b ? "b" : isturf(receiver) ? "turf" : "other"
    var/sid = subject == probe_a ? "a" : subject == probe_b ? "b" : isnull(subject) ? "none" : "other"
    var/list/receiver_turf = isturf(receiver) ? list("x" = receiver.x, "y" = receiver.y, "z" = receiver.z) : null
    probe_events += list(list("ordinal" = probe_events.len + 1, "time" = world.time,
        "case" = probe_case, "kind" = kind, "receiver" = rid, "receiver_turf" = receiver_turf, "subject" = sid,
        "bump_depth" = probe_bump_depth, "result" = result,
        "a" = probe_actor(probe_a), "b" = probe_actor(probe_b),
        "a_in_b_group" = probe_b && probe_a ? (probe_a in probe_b.group) : FALSE,
        "b_in_a_group" = probe_a && probe_b ? (probe_b in probe_a.group) : FALSE))

/turf/group_probe/Enter(atom/movable/M, atom/oldloc)
    probe_record("enter_before", src, M)
    . = ..()
    probe_record("enter_after", src, M, .)

/turf/group_probe/Exit(atom/movable/M, atom/newloc)
    probe_record("exit_before", src, M)
    . = ..()
    probe_record("exit_after", src, M, .)

/turf/group_probe/Entered(atom/movable/M, atom/oldloc)
    probe_record("entered_before", src, M)
    . = ..()
    probe_record("entered_after", src, M, .)

/turf/group_probe/Exited(atom/movable/M, atom/newloc)
    probe_record("exited_before", src, M)
    . = ..()
    probe_record("exited_after", src, M, .)

/mob/group_probe
    density = TRUE
    anchored = FALSE
    step_size = 32
    bound_x = 0
    bound_y = 0
    bound_width = 32
    bound_height = 32
    var/probe_lifetime

/mob/group_probe/Move()
    probe_record("move_enter", src, src)
    . = ..()
    probe_record("move_exit", src, src, .)

/mob/group_probe/Bump(atom/obstacle)
    probe_bump_depth++
    probe_record("bump_enter", src, obstacle)
    . = ..()
    probe_record("bump_exit", src, obstacle, .)
    probe_bump_depth--

/mob/group_probe/Cross(atom/movable/M)
    probe_record("cross_before", src, M)
    . = ..()
    probe_record("cross_after", src, M, .)

/mob/group_probe/Crossed(atom/movable/M)
    probe_record("crossed_before", src, M)
    . = ..()
    probe_record("crossed_after", src, M, .)

/mob/group_probe/Uncross(atom/movable/M)
    probe_record("uncross_before", src, M)
    . = ..()
    probe_record("uncross_after", src, M, .)

/mob/group_probe/Uncrossed(atom/movable/M)
    probe_record("uncrossed_before", src, M)
    . = ..()
    probe_record("uncrossed_after", src, M, .)

/proc/probe_one(which, index)
    probe_case = which
    probe_events = list()
    probe_active = FALSE
    probe_overflow = FALSE
    probe_bump_depth = 0
    var/mob/group_probe/A = new(locate(2, 3, 1))
    var/mob/group_probe/B = new(locate(which == "reach" ? 6 : 3, 3, 1))
    probe_a = A; probe_b = B
    A.probe_lifetime = "[index]:a"; B.probe_lifetime = "[index]:b"
    A.step_size = 32; B.step_size = 32
    A.step_x = 0; A.step_y = 0; B.step_x = 0; B.step_y = 0
    if (which == "group" || which == "pixel")
        B.group += A
    if (which == "pixel")
        A.step_size = 2
    var/list/start_a = probe_actor(A)
    var/list/start_b = probe_actor(B)
    var/forward_group = (A in B.group)
    var/reverse_group = (B in A.group)
    probe_active = TRUE
    probe_record("attempt_begin", A, B)
    var/move_return = step(A, EAST, which == "pixel" ? 2 : 32)
    probe_record("attempt_return", A, B, move_return)
    sleep(world.tick_lag)
    probe_record("settled", A, B)
    probe_active = FALSE
    var/list/row = list("case" = which, "lifetime" = index,
        "start_a" = start_a, "start_b" = start_b,
        "a_in_b_group" = forward_group, "b_in_a_group" = reverse_group,
        "move_return" = move_return, "end_a" = probe_actor(A), "end_b" = probe_actor(B),
        "overflow" = probe_overflow, "final_bump_depth" = probe_bump_depth,
        "events" = probe_events.Copy())
    probe_cases += list(row)
    probe_a = null; probe_b = null
    del(A); del(B)

/proc/probe_run()
    var/list/receipt = list("schema" = 1, "kind" = "native_group_bump_observation",
        "version" = world.byond_version, "build" = world.byond_build,
        "movement_mode" = world.movement_mode, "legacy_mode" = LEGACY_MOVEMENT_MODE,
        "tick_lag" = world.tick_lag, "icon_size" = world.icon_size,
        "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz)
    var/failure = null
    try
        if (world.byond_version != 516 || world.byond_build != 1688)
            throw EXCEPTION("wrong_byond_toolchain")
        if (world.movement_mode != LEGACY_MOVEMENT_MODE || world.icon_size != 32)
            throw EXCEPTION("wrong_world_geometry")
        var/startup_time = world.time
        sleep(world.tick_lag)
        if (world.time <= startup_time)
            throw EXCEPTION("readiness_no_advance")
        probe_one("reach", 1)
        probe_one("no_group", 2)
        probe_one("group", 3)
        probe_one("pixel", 4)
    catch (var/exception/E)
        failure = E.name
    receipt["failure"] = failure
    receipt["cases"] = probe_cases
    receipt["partial_case"] = probe_case
    receipt["partial_events"] = probe_events
    if (fexists("native-group-receipt.json"))
        world.log << "native-group receipt path unexpectedly exists"
    else
        text2file(json_encode(receipt), "native-group-receipt.json")
    world.log << "native-group fixture finished"
    shutdown()

/world/New()
    ..()
    spawn(0)
        probe_run()
