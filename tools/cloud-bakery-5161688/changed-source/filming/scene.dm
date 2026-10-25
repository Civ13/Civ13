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
	name = "Civ13 tanning process showcase"
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
		list(7, 7, /turf/floor/dirt/ploughed/fertile, null),
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
	filming_assert_tanning_initial()
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
	filming_check(tan_worker && !tan_worker.client && !tan_worker.ckey && tan_worker.loc == locate(6, 7, 1), "exact unconnected worker before guest binding")
	mob = tan_worker
	filming_check(mob == tan_worker && tan_worker.client == src && tan_worker.key == key && !mob.verbs.len && !verbs.len, "same real guest bound to exact zero-verb worker")
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
	filming_check(src == tan_worker && client && client == filming_observer_client && client.mob == src && copytext(client.key, 1, 7) == "Guest-", "native guest worker Login identity")
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
	var/ok = !QDELETED(I) && I.loc == tan_worker && (I in C.screen) && I.screen_loc == expected_slot && I.plane == HUD_PLANE && I.layer == 20 && length(type_name) <= 96 && length(slot_text) <= 16
	return list(copytext(type_name, 1, 97), copytext(slot_text, 1, 17), I.plane, I.layer, !!(I in C.screen), !!ok)

/proc/filming_viewport(phase)
	var/client/C = filming_observer_client
	if (!C || !tan_worker)
		throw EXCEPTION("Fixture viewport identity missing")
	var/list/L = filming_hand_view(tan_worker.l_hand, "1,5")
	var/list/R = filming_hand_view(tan_worker.r_hand, "5,5")
	var/atom/actual_eye = C.eye
	var/eye_ok = actual_eye == locate(7, 7, 1)
	var/identity_ok = tan_worker.client == C && C.mob == tan_worker
	var/ok = identity_ok && eye_ok && C.view == 2 && C.perspective == EYE_PERSPECTIVE && !C.pixel_x && !C.pixel_y && !tan_worker.step_x && !tan_worker.step_y && !tan_worker.HUDinventory.len && C.screen.len == L[5] + R[5] && C.screen.len <= 2 && L[6] && R[6]
	// Fixed schema: elapsed ds, phase, identity, expected eye, view, perspective,
	// client px/py, actor xyz/stepxy, screen count, HUD count, left/right hand.
	var/row = json_encode(list(filming_started ? world.time - filming_viewport_started : 0, copytext(phase, 1, 25), !!identity_ok, list(!!eye_ok, actual_eye ? actual_eye.x : null, actual_eye ? actual_eye.y : null, actual_eye ? actual_eye.z : null), C.view, C.perspective, C.pixel_x, C.pixel_y, tan_worker.x, tan_worker.y, tan_worker.z, tan_worker.step_x, tan_worker.step_y, C.screen.len, tan_worker.HUDinventory.len, L, R))
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

/proc/filming_drop_tanner(atom/target = null)
	filming_viewport("before normal drop")
	var/result
	if (target)
		result = tan_worker.drop_item(target)
	else
		result = tan_worker.drop_item()
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
	if (H == tan_worker && H.client)
		filming_viewport("before normal pickup")
	I.attack_hand(H)
	if (H == tan_worker && H.client)
		filming_viewport("after normal pickup")
	filming_check(H.get_active_hand() == I, "normal pickup completed")

var/mob/living/human/filming_worker/tan_worker
var/mob/living/human/tan_receiver
var/obj/item/stack/material/rawhide/tan_raw
var/obj/item/stack/bark/tan_bark
var/obj/item/weapon/reagent_containers/glass/bucket/tan_bucket
var/obj/item/weapon/material/kitchen/utensil/knife/tan_knife
var/obj/structure/converter/tanning/tan_rack
var/turf/floor/dirt/ploughed/fertile/tan_plot

/proc/filming_assert_tanning_initial()
	filming_check(tan_plot && tan_plot.type == /turf/floor/dirt/ploughed/fertile, "authored tanning worksite")
	for (var/turf/T in list(locate(7, 6, 1), locate(6, 7, 1), locate(7, 7, 1), locate(6, 6, 1), locate(7, 5, 1), locate(8, 5, 1), locate(6, 8, 1), locate(7, 8, 1)))
		filming_check(!(locate(/obj/item/stack/material/hairlesshide) in T) && !(locate(/obj/item/stack/material/wethide) in T) && !(locate(/obj/item/stack/material/dryhide) in T) && !(locate(/obj/item/stack/material/leather) in T), "fixed tanning tiles have no prepared or finished output")
	filming_check(tan_raw && tan_raw.loc == locate(7, 6, 1) && tan_raw.amount == 1 && tan_bark && tan_bark.loc == locate(7, 8, 1) && tan_bark.amount == 1, "one supplied raw hide and one supplied bark")
	filming_check(tan_bucket && tan_bucket.loc == locate(6, 8, 1) && tan_bucket.is_open_container() && tan_bucket.reagents.total_volume == 15 && tan_bucket.reagents.get_reagent_amount("water") == 15, "supplied open bucket contains exactly fifteen water")
	filming_check(tan_raw.Adjacent(tan_worker) && tan_worker.Adjacent(tan_raw), "visible raw hide is within normal diagonal reach")
	filming_check(tan_knife && tan_knife.loc == locate(5, 7, 1) && tan_knife.sharp, "supplied ordinary sharp kitchen knife")
	filming_check(tan_rack && tan_rack.loc == tan_plot && !tan_rack.contents.len && !tan_rack.filled && tan_rack.icon_state == "drying_rack_empty" && tan_rack.delay == 30, "empty rack with disclosed fixture drying duration")
	filming_check(tan_worker && tan_worker.loc == locate(6, 7, 1) && !tan_worker.get_active_hand() && tan_receiver && tan_receiver.loc == locate(7, 5, 1) && !tan_receiver.client && !tan_receiver.get_active_hand(), "exact initial fixture actors and free hands")

/proc/tanning_beat(label, take_start)
	filming_viewport(label)
	text2file(json_encode(list("beat" = label, "elapsed_ds" = world.time - take_start)), "filming-checks.txt")

/proc/filming_prepare_scene()
	// PRE-ROLL ONLY: supplied tools, water, raw hide, bark and constructed rack.
	// These inputs are not claimed to have been hunted, foraged or crafted in this take.
	tan_plot = locate(7, 7, 1)
	filming_check(tan_plot && tan_plot.type == /turf/floor/dirt/ploughed/fertile, "authored tanning plot unchanged")
	season = "SUMMER"
	map.heat_wave = FALSE
	tan_worker = filming_actor(6, 7, "Tanner", /obj/item/clothing/under/civ4, /mob/living/human/filming_worker)
	tan_receiver = filming_actor(7, 5, "Leatherworker", /obj/item/clothing/under/civ1)
	tan_worker.dir = EAST
	tan_receiver.dir = NORTH
	tan_raw = new(locate(7, 6, 1), 1)
	tan_bark = new(locate(7, 8, 1), 1)
	tan_bucket = new(locate(6, 8, 1))
	tan_bucket.reagents.add_reagent("water", 15)
	tan_knife = new(locate(5, 7, 1))
	tan_rack = new(tan_plot)
	filming_check(tan_rack.delay == 300, "production rack default is thirty seconds")
	// Explicitly disclosed fixture-only drying compression; normal attackby,
	// spawn(delay), guarded payment and production completion remain unchanged.
	tan_rack.delay = 30
	filming_assert_tanning_initial()
	text2file("ready; supplied raw hide bark water knife and rack; only rack drying compressed thirty seconds to three seconds; real five-second scraping", "filming-ready.txt")

/proc/filming_take()
	var/take_start = world.time
	filming_viewport_started = take_start
	spawn(0)
		try
			filming_viewport_loop()
		catch (var/exception/E)
			filming_stop("viewport observation failed: [E.name]")
	filming_check(filming_observer_client && tan_worker.client == filming_observer_client && filming_observer_client.mob == tan_worker && tan_worker.hide_worker_connected() && !tan_receiver.client, "tanner uses the actual isolated admitted guest client")
	filming_check(tan_worker.stat == CONSCIOUS && !tan_worker.verbs.len && !filming_observer_client.verbs.len && tan_worker.may_do_after, "connected worker is conscious with no permitted verbs")
	tanning_beat("supplied raw hide bark water knife and empty rack", take_start)
	sleep(15)
	filming_pickup(tan_worker, tan_knife)
	var/scrape_start = world.time
	tanning_beat("normal five-second scraping begins", take_start)
	tan_raw.attackby(tan_knife, tan_worker)
	var/turf/preparation_site = locate(7, 6, 1)
	var/obj/item/stack/material/hairlesshide/prepared = locate() in preparation_site
	filming_check(world.time - scrape_start >= 50 && QDELETED(tan_raw) && prepared && prepared.amount == 1 && !prepared.preparing_hide, "real timed scrape paid one raw hide and produced one scraped hide")
	filming_drop_tanner()
	tanning_beat("scraped hide ready for washing", take_start)
	sleep(10)
	filming_pickup(tan_worker, tan_bucket)
	prepared.attackby(tan_bucket, tan_worker)
	var/obj/item/stack/material/wethide/wet = locate() in preparation_site
	filming_check(QDELETED(prepared) && wet && wet.amount == 1 && tan_bucket.reagents.get_reagent_amount("water") == 10 && tan_bucket.reagents.total_volume == 10, "real washing consumes scraped hide and five water")
	tanning_beat("washed wet hide", take_start)
	sleep(10)
	tan_bark.attackby(tan_bucket, tan_worker)
	filming_check(QDELETED(tan_bark) && tan_bucket.reagents.get_reagent_amount("water") == 0 && tan_bucket.reagents.get_reagent_amount("tannin") == 10 && tan_bucket.reagents.total_volume == 10, "one bark and ten water produce ten tannin through production handler")
	filming_drop_tanner()
	tanning_beat("bark tannin prepared in the same bucket", take_start)
	sleep(10)
	filming_pickup(tan_worker, wet)
	var/dry_start = world.time
	filming_viewport("before rack transfer")
	tan_rack.attackby(wet, tan_worker)
	filming_viewport("after rack transfer")
	filming_check(wet.loc == tan_rack && wet.amount == 1 && tan_rack.contents.len == 1 && tan_rack.filled && tan_rack.icon_state == "drying_rack_full" && !tan_worker.get_active_hand(), "normal held-item transfer loads the same wet hide on rack")
	tanning_beat("loaded rack drying thirty-second process compressed to three seconds", take_start)
	// Thirty ticks for the normal scheduled conversion, plus a half-second hold.
	sleep(35)
	filming_check(tan_worker.client == filming_observer_client && filming_observer_client.mob == tan_worker, "same real guest remains attached after drying")
	var/obj/item/stack/material/dryhide/dried = locate() in tan_rack
	filming_check(world.time - dry_start >= 30 && QDELETED(wet) && dried && dried.amount == 1 && tan_rack.contents.len == 1 && !tan_rack.filled, "scheduled production drying paid wet hide and produced exactly one dry hide")
	tan_rack.attack_hand(tan_worker)
	filming_check(dried.loc == tan_plot && !tan_rack.contents.len && tan_rack.icon_state == "drying_rack_empty", "normal rack removal exposes the actual dried hide")
	filming_pickup(tan_worker, dried)
	filming_check(preparation_site.Adjacent(tan_worker), "clear display tile within ordinary drop reach")
	filming_drop_tanner(preparation_site)
	filming_check(dried.loc == preparation_site && dried.amount == 1 && !tan_worker.get_active_hand(), "same dry hide visibly placed clear of rack")
	tanning_beat("dry hide removed from rack", take_start)
	sleep(10)
	filming_pickup(tan_worker, tan_bucket)
	dried.attackby(tan_bucket, tan_worker)
	var/obj/item/stack/material/leather/leather = locate() in preparation_site
	filming_check(QDELETED(dried) && leather && leather.amount == 1 && tan_bucket.reagents.get_reagent_amount("tannin") == 5 && tan_bucket.reagents.total_volume == 5, "real tanning pays dry hide and five tannin for one leather")
	filming_drop_tanner()
	tanning_beat("finished leather sheet", take_start)
	sleep(20)
	filming_pickup(tan_worker, leather)
	var/mob/living/human/worker_identity = tan_worker
	var/obj/item/stack/material/leather/worker_item = leather
	filming_check(worker_identity.loc == locate(6, 7, 1) && !worker_identity.step_x && !worker_identity.step_y && leather.loc == worker_identity && leather.amount == 1, "tanner transfer starts at exact tile carrying produced leather")
	var/list/worker_start = list(worker_identity.x, worker_identity.y, worker_identity.z, worker_identity.step_x, worker_identity.step_y)
	var/worker_step_return = step(tan_worker, SOUTH)
	text2file(json_encode(list("movement" = "tanner", "start" = worker_start, "step_return_numeric" = isnum(worker_step_return) ? worker_step_return : null, "step_return_null" = isnull(worker_step_return), "x" = worker_identity.x, "y" = worker_identity.y, "z" = worker_identity.z, "step_x" = worker_identity.step_x, "step_y" = worker_identity.step_y, "actor_same" = tan_worker == worker_identity, "item_same" = leather == worker_item, "carried" = leather.loc == worker_identity, "amount" = leather.amount)), "filming-checks.txt")
	filming_check(tan_worker == worker_identity && leather == worker_item && worker_identity.loc == locate(6, 6, 1) && !worker_identity.step_x && !worker_identity.step_y && leather.loc == worker_identity && leather.amount == 1, "same tanner carries same produced leather to exact handoff tile")
	filming_drop_tanner()
	filming_check(leather.loc == locate(6, 6, 1) && leather.amount == 1, "same finished leather visibly placed for next process")
	sleep(10)
	filming_pickup(tan_receiver, leather)
	var/mob/living/human/receiver_identity = tan_receiver
	var/obj/item/stack/material/leather/receiver_item = leather
	filming_check(receiver_identity.loc == locate(7, 5, 1) && !receiver_identity.step_x && !receiver_identity.step_y && leather.loc == receiver_identity && leather.amount == 1, "leatherworker transfer starts at exact tile carrying same leather")
	var/list/receiver_start = list(receiver_identity.x, receiver_identity.y, receiver_identity.z, receiver_identity.step_x, receiver_identity.step_y)
	var/receiver_step_return = step(tan_receiver, EAST)
	text2file(json_encode(list("movement" = "leatherworker", "start" = receiver_start, "step_return_numeric" = isnum(receiver_step_return) ? receiver_step_return : null, "step_return_null" = isnull(receiver_step_return), "x" = receiver_identity.x, "y" = receiver_identity.y, "z" = receiver_identity.z, "step_x" = receiver_identity.step_x, "step_y" = receiver_identity.step_y, "actor_same" = tan_receiver == receiver_identity, "item_same" = leather == receiver_item, "carried" = leather.loc == receiver_identity, "amount" = leather.amount)), "filming-checks.txt")
	filming_check(tan_receiver == receiver_identity && leather == receiver_item && receiver_identity.loc == locate(8, 5, 1) && !receiver_identity.step_x && !receiver_identity.step_y && leather.loc == receiver_identity && leather.amount == 1, "same produced leather delivered to leatherworker at exact work-area tile")
	tanning_beat("leather handed to the next craftsperson", take_start)
	sleep(15)
	filming_check(tan_worker.client == filming_observer_client && filming_observer_client.mob == tan_worker, "same real guest remains attached through tanning completion")
	filming_check(filming_observer_client.eye == locate(7, 7, 1) && filming_observer_client.perspective == EYE_PERSPECTIVE && filming_observer_client.view == 2 && !tan_worker.verbs.len && !filming_observer_client.verbs.len, "fixed camera and zero verbs preserved through tanning completion")
	filming_check(world.time - take_start <= 195, "tanning sequence completed inside unchanged recording interval")
	filming_viewport("take complete")
	filming_viewport_done = TRUE
	text2file(json_encode(list("elapsed_deciseconds" = world.time - take_start, "engine" = "516.1688", "source" = "9683866a89d2bdc12f8dc7d25444e350583c5483", "scope" = "scripted isolated guest-controlled tanner; supplied raw hide bark water knife and rack; normal five-second scraping; rack drying compressed from thirty seconds to three seconds; real washing bark extraction drying tanning and same-leather handoff")), "filming-take.json")

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
		filming_assert_tanning_initial()
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
