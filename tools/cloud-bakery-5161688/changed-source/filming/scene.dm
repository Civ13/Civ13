// Derived cloud fixture, source review required before execution.
// Genuine engine guest camera; not a user account or ordinary-player acceptance.
#define FILMING_NATIVE_RELEASED TRUE

var/filming_ready = FALSE
var/filming_started = FALSE
var/filming_stopping = FALSE
var/client/filming_observer_client
var/filming_expected_observer
var/filming_allowed_port
var/filming_startup_phase = "pre-world initialization"

/world
	name = "Civ13 flax chapter A showcase"
	hub = ""
	hub_password = ""
	visibility = 0
	mob = /mob/filming_observer
	// The authored DMM supplies dimensions; exact runtime size is asserted below.
	view = 2
	fps = 20

/world/OpenPort(requested)
	if (requested == "none")
		return ..("none")
	if (FILMING_NATIVE_RELEASED && filming_ready && filming_allowed_port && requested == filming_allowed_port)
		return ..(requested)
	return FALSE

/world/Topic()
	return null

/world/Reboot()
	filming_stop("reboot requested: fixture stops instead")

/world/Error(exception/E)
	filming_stop("native runtime error: [filming_exception_detail(E)]")

/proc/filming_exception_detail(exception/E)
	// Bound each original field; the existing stop receipt has a 64 KiB cap.
	if (!istype(E))
		return json_encode(list("phase" = copytext(filming_startup_phase, 1, 257), "exception_available" = FALSE))
	var/name_text = "[E.name]"
	var/file_text = "[E.file]"
	var/desc_text = "[E.desc]"
	return json_encode(list("phase" = copytext(filming_startup_phase, 1, 257), "exception_name" = copytext(name_text, 1, 257), "exception_file" = copytext(file_text, 1, 257), "exception_line" = E.line, "exception_desc" = copytext(desc_text, 1, 2049), "phase_truncated" = length(filming_startup_phase) > 256, "name_truncated" = length(name_text) > 256, "file_truncated" = length(file_text) > 256, "desc_available" = !!length(desc_text), "desc_truncated" = length(desc_text) > 2048))

/proc/filming_denied_shell()
	throw EXCEPTION("Filming profile: OS shell disabled")

/proc/filming_denied_export()
	throw EXCEPTION("Filming profile: production outbound export disabled")

/proc/filming_check(ok, label)
	if (!ok)
		throw EXCEPTION("Filming check failed: [label]")
	text2file("[world.time] [label]", "filming-checks.txt")

/proc/filming_stop(reason)
	if (filming_stopping)
		return
	filming_stopping = TRUE
	world.OpenPort("none")
	text2file(reason, "filming-stop.txt")
	del(world)

// Keep the Little Creek era/rules, omit scenario timers, jobs and round logic.
/obj/map_metadata/little_creek/filming/New()
	map = src

/proc/filming_initialize()
	if (!FILMING_NATIVE_RELEASED)
		return
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	map = new /obj/map_metadata/little_creek/filming
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	populate_material_list()

// Fixed authored DMM witnesses only; never reconstruct or paint over a missing map.
/proc/filming_assert_authored_map(phase)
	var/list/witnesses = list(
		list(7, 7, /turf/floor/beach/water, null),
		list(6, 7, /turf/floor/dirt, null),
		list(6, 8, /turf/floor/dirt, null),
		list(5, 7, /turf/floor/dirt, null),
		list(6, 6, /turf/floor/dirt, null),
		list(9, 5, /turf/floor/grass, /obj/structure/table/wood))
	var/list/observed = list()
	var/ok = (world.maxx == 15 && world.maxy == 13 && world.maxz == 1)
	for (var/list/row in witnesses)
		var/turf/T = locate(row[1], row[2], 1)
		var/area/A = T ? get_area(T) : null
		var/expected_turf = row[3]
		var/expected_object = row[4]
		var/obj/O = expected_object && T ? (locate(expected_object) in T) : null
		var/turf_ok = T && T.type == expected_turf
		var/area_ok = A && A.type == /area/caribbean/forest
		var/object_ok = !expected_object || (O && O.loc == T)
		var/actual_turf = T ? "[T.type]" : "missing"
		var/actual_area = A ? "[A.type]" : "missing"
		observed += list(list("x" = row[1], "y" = row[2], "z" = 1, "turf" = copytext(actual_turf, 1, 129), "area" = copytext(actual_area, 1, 129), "turf_ok" = !!turf_ok, "area_ok" = !!area_ok, "object_ok" = !!object_ok))
		if (!turf_ok || !area_ok || !object_ok)
			ok = FALSE
	// Observe only the same six coordinates on z2; never use them for admission.
	var/list/z2_observed = list()
	if (phase == "world New before fixture initialization")
		for (var/list/row in witnesses)
			var/turf/T = locate(row[1], row[2], 2)
			var/area/A = T ? get_area(T) : null
			var/expected_turf = row[3]
			var/expected_object = row[4]
			var/obj/O = expected_object && T ? (locate(expected_object) in T) : null
			var/actual_turf = T ? "[T.type]" : "missing"
			var/actual_area = A ? "[A.type]" : "missing"
			z2_observed += list(list("x" = row[1], "y" = row[2], "z" = 2, "turf" = copytext(actual_turf, 1, 129), "area" = copytext(actual_area, 1, 129), "turf_ok" = !!(T && T.type == expected_turf), "area_ok" = !!(A && A.type == /area/caribbean/forest), "object_ok" = !!(!expected_object || (O && O.loc == T))))
	var/evidence = json_encode(list("phase" = copytext(phase, 1, 65), "dimensions" = list(world.maxx, world.maxy, world.maxz), "witnesses" = observed, "z2_diagnostic" = z2_observed))
	text2file("authored-map [evidence]", "filming-checks.txt")
	filming_check(ok, "authored map witnesses [phase]")

/client/New()
	if (!FILMING_NATIVE_RELEASED || !filming_ready || filming_observer_client || copytext(key, 1, 7) != "Guest-" || byond_version != 516 || byond_build != 1688 || address != "127.0.0.1")
		del(src)
		return
	filming_assert_authored_map("client admission")
	filming_assert_flax_initial()
	filming_observer_client = src
	// Special verb lists support subtraction, not Cut; iterate a stable copy.
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "client verbs empty before native New")
	..()
	filming_check(!verbs.len, "client verbs empty after native New")
	filming_check(istype(mob, /mob/filming_observer) && !mob.verbs.len, "observer verbs empty before capture")
	// No preferences, admin holder, production host file, login webhook or bridge.
	// Native client.mob binding: one genuine admitted guest, never a fabricated client.
	filming_check(flax_worker && !flax_worker.client && !flax_worker.ckey && flax_worker.loc == locate(6, 7, 1), "exact unconnected worker before guest binding")
	mob = flax_worker
	filming_check(mob == flax_worker && flax_worker.client == src && flax_worker.key == key && !mob.verbs.len && !verbs.len, "same real guest bound to exact zero-verb worker")
	text2file("guest-worker;native-client-mob=1;zero-verbs:1;fixed-eye=7,7,1", "filming-checks.txt")
	eye = locate(7, 7, 1)
	perspective = EYE_PERSPECTIVE
	view = 2
	filming_viewport("client camera ready")
	var/is_guest = (copytext(key, 1, 7) == "Guest-")
	text2file("guest=[is_guest];version=[byond_version];build=[byond_build]", "cloud-client.txt")
	spawn(20)
		try
			while (!fexists("cloud-stage-captured.txt"))
				sleep(1)
			filming_started = TRUE
			filming_take()
		catch (var/exception/E)
			filming_stop("cloud sequence failed: [E.name]")

/client/Del()
	if (src == filming_observer_client)
		filming_stop("observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE

// No arbitrary clicks, topics, keyboard movement or verbs enter production gameplay.
/client/Click()
	return null

/client/DblClick()
	return null

/client/MouseDown()
	return null

/client/MouseUp()
	return null

/client/MouseDrop()
	return null

/client/MouseDrag()
	return null

/client/MouseMove()
	return null

/client/MouseEntered()
	return null

/client/MouseExited()
	return null

/client/North()
	return null

/client/South()
	return null

/client/East()
	return null

/client/West()
	return null

/client/Northeast()
	return null

/client/Northwest()
	return null

/client/Southeast()
	return null

/client/Southwest()
	return null

/client/Center()
	return null

// Production human mechanics remain inherited; only session entry/input is isolated.
/mob/living/human/filming_worker/Login()
	filming_check(src == flax_worker && client && client == filming_observer_client && client.mob == src && copytext(client.key, 1, 7) == "Guest-", "native guest worker Login identity")
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "worker verbs empty after Login")
	// Deliberately no production Login: no preference/account/host/bridge startup.

/mob/living/human/filming_worker/Logout()
	if (!filming_stopping)
		filming_stop("guest worker disconnected or reassigned")

/mob/living/human/filming_worker/ClickOn()
	return


// Fixture display only. Production equip/drop and paid transformations stay inherited.
/mob/living/human/filming_worker/find_inv_position(slot_id)
	if (slot_id == slot_l_hand)
		return "1,5"
	if (slot_id == slot_r_hand)
		return "5,5"
	return ..()

var/filming_viewport_rows = 0
var/filming_viewport_bytes = 0
var/filming_viewport_started = 0
var/filming_viewport_done = FALSE

/proc/filming_hand_view(obj/item/I, expected_slot)
	if (!I)
		return list(null, null, null, null, FALSE, TRUE)
	var/client/C = filming_observer_client
	var/type_name = "[I.type]"
	var/slot_text = "[I.screen_loc]"
	var/ok = !QDELETED(I) && I.loc == flax_worker && (I in C.screen) && I.screen_loc == expected_slot && I.plane == HUD_PLANE && I.layer == 20 && length(type_name) <= 96 && length(slot_text) <= 16
	return list(copytext(type_name, 1, 97), copytext(slot_text, 1, 17), I.plane, I.layer, !!(I in C.screen), !!ok)

/proc/filming_viewport(phase)
	var/client/C = filming_observer_client
	if (!C || !flax_worker)
		throw EXCEPTION("Fixture viewport identity missing")
	var/list/L = filming_hand_view(flax_worker.l_hand, "1,5")
	var/list/R = filming_hand_view(flax_worker.r_hand, "5,5")
	var/atom/actual_eye = C.eye
	var/eye_ok = actual_eye == locate(7, 7, 1)
	var/identity_ok = flax_worker.client == C && C.mob == flax_worker
	var/ok = identity_ok && eye_ok && C.view == 2 && C.perspective == EYE_PERSPECTIVE && !C.pixel_x && !C.pixel_y && !flax_worker.step_x && !flax_worker.step_y && !flax_worker.HUDinventory.len && C.screen.len == L[5] + R[5] && C.screen.len <= 2 && L[6] && R[6]
	// Fixed schema: elapsed ds, phase, identity, expected eye, view, perspective,
	// client px/py, actor xyz/stepxy, screen count, HUD count, left/right hand.
	var/row = json_encode(list(filming_started ? world.time - filming_viewport_started : 0, copytext(phase, 1, 25), !!identity_ok, list(!!eye_ok, actual_eye ? actual_eye.x : null, actual_eye ? actual_eye.y : null, actual_eye ? actual_eye.z : null), C.view, C.perspective, C.pixel_x, C.pixel_y, flax_worker.x, flax_worker.y, flax_worker.z, flax_worker.step_x, flax_worker.step_y, C.screen.len, flax_worker.HUDinventory.len, L, R))
	if (filming_viewport_rows >= 96 || length(row) > 384 || filming_viewport_bytes + length(row) + 2 > 16000)
		throw EXCEPTION("Fixture viewport diagnostic cap")
	text2file(row, "filming-viewport.txt")
	filming_viewport_rows++
	filming_viewport_bytes += length(row) + 2
	if (!ok)
		throw EXCEPTION("Fixture viewport contract rejected")

/proc/filming_viewport_loop()
	while (!filming_stopping && !filming_viewport_done && world.time - filming_viewport_started <= 195)
		filming_viewport("timed observation")
		sleep(5)
	if (!filming_stopping && !filming_viewport_done)
		filming_stop("Fixture viewport monitor deadline")

/proc/filming_drop_flax_worker(atom/target = null)
	filming_viewport("before normal drop")
	var/result
	if (target)
		result = flax_worker.drop_item(target)
	else
		result = flax_worker.drop_item()
	filming_viewport("after normal drop")
	return result

/mob/filming_observer
	name = "Filming observer"
	density = FALSE
	invisibility = 101

/mob/filming_observer/Login()
	loc = locate(7, 7, 1)
	// Fixed cloud sequence only; mutate the special list, never assign it.
	for (var/fixture_verb in verbs.Copy())
		verbs -= fixture_verb
	filming_check(!verbs.len, "observer verbs empty after Login")

/mob/filming_observer/Move()
	return FALSE

/mob/filming_observer/Logout()
	return

/mob/filming_observer/ClickOn()
	return

/mob/filming_observer/verb/Abort_scene()
	set category = "Filming"
	filming_stop("observer abort")

/proc/filming_actor(tx, ty, actor_name, uniform_type, actor_type = /mob/living/human)
	var/mob/living/human/H = new actor_type(locate(tx, ty, 1))
	H.real_name = actor_name
	H.name = actor_name
	H.lastarea = get_area(H)
	H.m_intent = "walk"
	H.equip_to_slot(new uniform_type(H), slot_w_uniform)
	H.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	filming_check(!H.client && !H.ckey && H.stat == CONSCIOUS, "fixture-owned human, no client impersonation")
	return H

/proc/filming_pickup(mob/living/human/H, obj/item/I)
	filming_check(I && I.Adjacent(H) && !H.get_active_hand(), "pickup reach and free hand")
	if (H == flax_worker && H.client)
		filming_viewport("before normal pickup")
	I.attack_hand(H)
	if (H == flax_worker && H.client)
		filming_viewport("after normal pickup")
	filming_check(H.get_active_hand() == I, "normal pickup completed")

var/mob/living/human/filming_worker/flax_worker
var/obj/item/stack/material/flax/flax_raw
var/turf/floor/beach/water/flax_water
var/flax_interruption_done = FALSE

/proc/filming_assert_flax_initial()
	filming_check(flax_water && flax_water.type == /turf/floor/beach/water && flax_water == locate(7, 7, 1) && !flax_water.salty && flax_water.radiation <= 0, "authored fixed fresh non-irradiated shallow water")
	filming_check(flax_worker && flax_worker.loc == locate(6, 7, 1) && !flax_worker.step_x && !flax_worker.step_y && !flax_worker.get_active_hand(), "exact initial flax worker and free hand")
	filming_check(flax_raw && flax_raw.loc == locate(7, 6, 1) && flax_raw.amount == 2 && flax_raw.Adjacent(flax_worker), "two supplied raw flax portions visibly beside shore worker")
	for (var/turf/T in list(locate(7, 6, 1), locate(7, 7, 1), locate(6, 7, 1), locate(5, 7, 1)))
		filming_check(!(locate(/obj/item/flax_bundle) in T) && !(locate(/obj/item/stack/rotten_flax) in T) && !(locate(/obj/item/flax_work) in T) && !(locate(/obj/item/stack/flax_tow) in T) && !(locate(/obj/item/stack/textile_lint) in T), "fixed chapter A tiles contain no prepared flax outputs")
	filming_check(!flax_interruption_done, "no previous chapter action")

/proc/flax_beat(label, take_start)
	filming_viewport(label)
	text2file(json_encode(list("beat" = label, "elapsed_ds" = world.time - take_start)), "filming-checks.txt")

/proc/filming_prepare_scene()
	// PRE-ROLL: supplied harvested flax and authored freshwater; not filmed cultivation.
	flax_water = locate(7, 7, 1)
	season = "SUMMER"
	map.heat_wave = FALSE
	flax_worker = filming_actor(6, 7, "Flax worker", /obj/item/clothing/under/civ4, /mob/living/human/filming_worker)
	flax_worker.dir = EAST
	flax_raw = new(locate(7, 6, 1), 2)
	filming_assert_flax_initial()
	text2file("ready; chapter A supplied two raw flax portions; actual binding and first ten-second freshwater stage; remaining retting deliberately interrupted by ordinary movement", "filming-ready.txt")

// Every poll still evaluates every original predicate. Only repeated success
// text is replaced by bounded counters; the first failure retains its exact label.
/proc/flax_poll_assert(ok, label, list/counts, index, polls)
	if (!ok)
		text2file(json_encode(list("poll_failure" = label, "polls" = polls, "passed" = counts)), "filming-checks.txt")
		filming_check(ok, label)
	counts[index]++

/proc/flax_interrupt_after_first_stage(obj/item/flax_bundle/bundle, mob/living/human/worker, turf/floor/beach/water/site, deadline)
	var/placement_observed = FALSE
	var/polls = 0
	var/list/passed = list(0, 0, 0)
	// This observer never advances a stage or completes work. It waits for the
	// production loop's first completed stage, then uses normal actor movement.
	// The second production do_after sees the changed actor position and cancels.
	while (!filming_stopping && world.time < deadline)
		polls++
		if (polls > 300)
			text2file(json_encode(list("poll_failure" = "bounded observation poll cap", "polls" = polls, "passed" = passed)), "filming-checks.txt")
			filming_stop("bounded observation poll cap")
			return
		flax_poll_assert(worker == flax_worker && worker.client == filming_observer_client && filming_observer_client.mob == worker, "same real guest during bounded soak-stage observation", passed, 1, polls)
		flax_poll_assert(!QDELETED(bundle) && site == flax_water && bundle.soak_stage >= 0 && bundle.soak_stage <= 1, "same unfinished bundle and exact authored water during observation", passed, 2, polls)
		if (bundle.loc != site)
			// Permit only the initial still-held state if spawn runs before transfer.
			flax_poll_assert(bundle.loc == worker && bundle.soak_stage == 0 && !bundle.soaking && worker.loc == locate(6, 7, 1), "only original held bundle may await normal water placement", passed, 3, polls)
			sleep(0.5)
			continue
		if (!placement_observed)
			filming_viewport("after water placement")
			filming_check(!worker.l_hand && !worker.r_hand && !(bundle in filming_observer_client.screen) && isnull(bundle.screen_loc) && bundle.plane == GAME_PLANE && bundle.layer == initial(bundle.layer), "normal production water placement cleared both hands and exact bundle screen membership")
			text2file(json_encode(list("poll_transition" = "water placement observed", "polls" = polls, "passed" = passed, "soak_stage" = bundle.soak_stage)), "filming-checks.txt")
			placement_observed = TRUE
		if (bundle.soak_stage == 1)
			filming_check(bundle.soaking && worker.loc == locate(6, 7, 1) && !worker.step_x && !worker.step_y, "production first soak stage completed before ordinary interruption")
			var/list/start = list(worker.x, worker.y, worker.z, worker.step_x, worker.step_y)
			filming_viewport("before ordinary step")
			var/step_return = step(worker, WEST)
			filming_viewport("after ordinary step")
			text2file(json_encode(list("movement" = "ordinary soak interruption", "start" = start, "step_return_numeric" = isnum(step_return) ? step_return : null, "step_return_null" = isnull(step_return), "x" = worker.x, "y" = worker.y, "z" = worker.z, "step_x" = worker.step_x, "step_y" = worker.step_y, "actor_same" = worker == flax_worker, "bundle_same_water" = bundle.loc == site, "soak_stage" = bundle.soak_stage)), "filming-checks.txt")
			filming_check(worker == flax_worker && worker.loc == locate(5, 7, 1) && !worker.step_x && !worker.step_y && bundle.loc == site && bundle.soak_stage == 1, "same worker actually moved out of reach without moving or advancing bundle")
			text2file(json_encode(list("poll_transition" = "first stage completed and ordinary movement applied", "polls" = polls, "passed" = passed, "soak_stage" = bundle.soak_stage)), "filming-checks.txt")
			flax_interruption_done = TRUE
			return
		sleep(0.5)
	text2file(json_encode(list("poll_failure" = "chapter A observation deadline", "polls" = polls, "passed" = passed)), "filming-checks.txt")
	filming_stop("chapter A timed out observing first production soak stage")

// Wrappers observe normal production transitions; they do not replace payment,
// inventory placement or the unchanged production do_after wait.
/proc/filming_bind_flax(obj/item/stack/material/flax/raw)
	filming_viewport("before normal binding")
	filming_check(raw == flax_raw && raw.loc == flax_worker && flax_worker.item_is_in_hands(raw) && raw.amount == 2, "exact paid raw input held before binding")
	var/result = raw.tie_bundle(flax_worker)
	filming_viewport("after normal binding")
	return result

/proc/filming_place_flax(obj/item/flax_bundle/bundle)
	filming_viewport("before water placement")
	filming_check(bundle && bundle.loc == flax_worker && flax_worker.item_is_in_hands(bundle), "same actual bundle held before production water placement")
	// V46 showed normal transfer but no auto-start in this pinned human path.
	// Preserve that production handler; inspect state, never invent its return.
	bundle.afterattack(flax_water, flax_worker, TRUE)
	filming_viewport("after water placement")
	filming_check(!QDELETED(bundle) && bundle.loc == flax_water && bundle.soak_stage == 0 && !bundle.soaking && flax_worker_can_reach(flax_worker, bundle), "same unsoaked bundle placed in exact fresh water")
	filming_check(!flax_worker.l_hand && !flax_worker.r_hand && !(bundle in filming_observer_client.screen) && isnull(bundle.screen_loc) && bundle.plane == GAME_PLANE && bundle.layer == initial(bundle.layer), "actual water placement restored hands and exact bundle screen state")

/proc/filming_interact_flax(obj/item/flax_bundle/bundle)
	filming_viewport("before normal interact")
	filming_check(bundle && bundle.loc == flax_water && bundle.soak_stage == 0 && !bundle.soaking && flax_worker_can_reach(flax_worker, bundle) && !flax_worker.get_active_hand(), "same placed bundle reachable with free active hand before ordinary interaction")
	// Ordinary player interaction with a placed bundle starts/resumes soaking.
	bundle.attack_hand(flax_worker)
	filming_viewport("after soak cancellation")

/proc/filming_take()
	var/take_start = world.time
	filming_viewport_started = take_start
	spawn(0)
		try
			filming_viewport_loop()
		catch (var/exception/E)
			filming_stop("viewport observation failed: [E.name]")
	filming_check(filming_observer_client && flax_worker.client == filming_observer_client && filming_observer_client.mob == flax_worker, "flax worker is the actual isolated admitted guest")
	filming_check(flax_worker.stat == CONSCIOUS && !flax_worker.verbs.len && !filming_observer_client.verbs.len && flax_worker.may_do_after, "conscious zero-verb worker ready for normal timed production")
	flax_beat("chapter A supplied two raw flax portions", take_start)
	sleep(20)
	filming_pickup(flax_worker, flax_raw)
	filming_check(filming_bind_flax(flax_raw), "production binding paid two raw flax portions")
	var/obj/item/flax_bundle/bundle = locate() in flax_worker
	filming_check(QDELETED(flax_raw) && bundle && bundle.loc == flax_worker && flax_worker.item_is_in_hands(bundle) && bundle.soak_stage == 0 && !bundle.soaking, "actual newly tied bundle has no completed soaking")
	// All soaking stages use the same bundle art; no animation or progress UI is promised.
	flax_beat("bound bundle before freshwater soaking", take_start)
	sleep(20)
	filming_check(flax_worker_can_reach(flax_worker, flax_water) && bundle.loc == flax_worker && !flax_water.salty && flax_water.radiation <= 0, "held bundle genuinely reaches exact permitted freshwater")
	filming_place_flax(bundle)
	flax_beat("bundle placed in fresh water; interact next", take_start)
	sleep(5)
	var/soak_start = world.time
	var/deadline = take_start + 150
	spawn(0)
		try
			flax_interrupt_after_first_stage(bundle, flax_worker, flax_water, deadline)
		catch (var/exception/E)
			filming_stop("chapter A bounded interruption failed: [E.name]")
	flax_beat("interact to begin first ten-second soaking stage", take_start)
	filming_interact_flax(bundle)
	// Ordinary hand interaction returns through the unchanged do_after cancellation path.
	filming_check(flax_interruption_done && world.time - soak_start >= 100 && world.time <= deadline, "ordinary movement interrupted subsequent waiting after full first stage")
	filming_check(!QDELETED(bundle) && bundle.loc == flax_water && bundle.soak_stage == 1 && !bundle.soaking && flax_worker.loc == locate(5, 7, 1) && !flax_worker_can_reach(flax_worker, bundle), "actual same bundle retains exactly one completed stage and is not finished")
	filming_check(!(locate(/obj/item/stack/rotten_flax) in flax_water), "chapter A has not fabricated or claimed finished retted flax")
	flax_beat("retting paused after one of three full stages; not yet finished", take_start)
	sleep(40)
	filming_check(flax_worker.client == filming_observer_client && filming_observer_client.mob == flax_worker && bundle.loc == flax_water && bundle.soak_stage == 1 && !bundle.soaking, "same guest and genuinely paused bundle remain through chapter end")
	filming_check(!flax_worker.verbs.len && !filming_observer_client.verbs.len, "zero worker and client verbs preserved through chapter completion")
	filming_check(world.time - take_start <= 195, "chapter A completed inside unchanged recording interval")
	filming_viewport("take complete")
	filming_viewport_done = TRUE
	text2file(json_encode(list("elapsed_deciseconds" = world.time - take_start, "engine" = "516.1688", "source" = "9683866a89d2bdc12f8dc7d25444e350583c5483", "scope" = "flax chapter A; independently produced batch; supplied two raw flax portions; actual binding, normal water placement then hand interaction and first full ten-second freshwater stage; normal movement pauses remaining work; not completed retting and no continuous-batch claim with later chapters")), "filming-take.json")


/proc/filming_lighting_loop()
	// Only these two native visual processes; no general production scheduler.
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	S.setup()
	O.setup()
	while (!filming_stopping)
		S.run_time_tick_usage = world.tick_usage
		S.run_time_tick_usage_allowance = 5
		S.fire()
		O.run_time_tick_usage = world.tick_usage
		O.run_time_tick_usage_allowance = 5
		O.fire()
		sleep(2)

/world/New()
	filming_startup_phase = "close initial port"
	OpenPort("none")
	if (!FILMING_NATIVE_RELEASED)
		filming_stop("NATIVE HOLD: review only")
		return
	try
		filming_startup_phase = "validate engine and parameters"
		filming_check(!port && byond_version == 516 && byond_build == 1688, "closed port and accepted engine")
		filming_allowed_port = text2num(params["filming_port"])
		filming_check(params["observer_mode"] == "engine_guest_camera" && filming_allowed_port >= 1024 && filming_allowed_port <= 65535, "explicit guest camera and isolated port")
		filming_assert_authored_map("world New before fixture initialization")
		filming_startup_phase = "movementMachine.New"
		movementMachine = new
		filming_startup_phase = "init_sticker_registry"
		filming_check(!!GLOB, "global controller published")
		filming_check(islist(GLOB.sticker_registry), "sticker registry is a list")
		filming_check(!length(GLOB.sticker_registry), "sticker registry initially empty")
		init_sticker_registry()
		filming_startup_phase = "movable initialization loop"
		for (var/atom/movable/A in world)
			if (!A.gcDestroyed)
				filming_startup_phase = "movable.initialize [A.type] ([A.x],[A.y],[A.z])"
				A.initialize()
		filming_startup_phase = "area initialization loop"
		for (var/area/A in area_list)
			filming_startup_phase = "area.initialize [A.type]"
			A.initialize()
		filming_startup_phase = "time_of_day_change.New"
		var/process/time_of_day_change/T = new
		filming_startup_phase = "time_of_day_change.setup"
		T.setup()
		filming_startup_phase = "create_lighting Midday"
		create_lighting("Midday")
		filming_startup_phase = "apply_restored_lighting"
		filming_check(apply_restored_lighting(), "native daylight initialized")
		spawn(0)
			filming_lighting_loop()
		filming_assert_authored_map("after fixture initialization before listener")
		filming_startup_phase = "prepare visible starting materials"
		filming_prepare_scene()
		filming_assert_flax_initial()
		filming_startup_phase = "open isolated listener"
		filming_ready = TRUE
		OpenPort(filming_allowed_port)
		filming_check(port == filming_allowed_port, "isolated observer listener")
		text2file("port=[port];version=[byond_version];build=[byond_build]", "cloud-listening.txt")
		filming_startup_phase = "startup complete"
		spawn(1800)
			filming_stop("three minute world timeout")
	catch (var/exception/E)
		filming_stop("startup failed: [filming_exception_detail(E)]")
