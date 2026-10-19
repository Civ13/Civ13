// Actual accessory/subtype removal, clothing caller, overlays and human hands.
// Presentation, human startup and DNA fingerprint generation are explicit seams.
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 6
	maxz = 1
	turf = /turf
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed accessory fixture"

var/global/list/accessory_actor_checks = list()
var/global/list/accessory_actor_failed = list()
var/global/accessory_actor_runtime_error = FALSE
var/global/accessory_actor_cases = 0
var/global/list/accessory_actor_witnesses = list()

/world/Error(exception/E)
	accessory_actor_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/mob/living/human/accessory_actor_probe/New()
	return
/mob/living/human/accessory_actor_probe/update_inv_l_hand(update_icons=1)
	return
/mob/living/human/accessory_actor_probe/update_inv_r_hand(update_icons=1)
	return

/obj/item/clothing/under/accessory_actor_probe
	var/probe_icon_updates = 0
/obj/item/clothing/under/accessory_actor_probe/update_clothing_icon()
	probe_icon_updates++
/obj/item/clothing/under/accessory_actor_probe/verb/probe_marker()
	return

/obj/item/clothing/accessory
	var/list/probe_print_actors = list()
	var/probe_print_calls = 0
	var/probe_body_marker
	var/mob/probe_body_user
	var/mob/probe_body_usr
/obj/item/clothing/accessory/add_fingerprint(mob/living/M, ignoregloves=FALSE)
	probe_print_calls++
	if (M)
		probe_print_actors += M

/proc/accessory_actor_observe(obj/item/clothing/accessory/A, mob/user, mob/ambient, marker)
	A.probe_body_marker = marker
	A.probe_body_user = user
	A.probe_body_usr = ambient

/proc/accessory_actor_role(mob/M, mob/actor, mob/other)
	if (!M)
		return "null"
	if (M == actor)
		return "actor"
	if (M == other)
		return "other"
	return "unexpected"

/proc/accessory_actor_check(condition, label)
	accessory_actor_checks += list(list("label"=label, "passed"=!!condition))
	if (!condition)
		accessory_actor_failed += label

/proc/accessory_actor_case(path, kind, mode)
	accessory_actor_cases++
	var/turf/site = locate(3,3,1)
	var/mob/living/human/accessory_actor_probe/actor = new(locate(2,2,1))
	var/mob/living/human/accessory_actor_probe/other = new(locate(5,5,1))
	var/mob/living/human/accessory_actor_probe/wearer = new(site)
	actor.hand = TRUE
	other.hand = TRUE
	var/obj/item/clothing/under/accessory_actor_probe/S = new(wearer)
	S.verbs += /obj/item/clothing/under/accessory_actor_probe/verb/probe_marker
	var/image/unrelated = image(icon = 'icons/obj/clothing/ties.dmi', icon_state = "bluetie")
	unrelated.alpha = 123
	S.overlays += unrelated
	var/obj/item/clothing/accessory/A = new path(S)
	S.accessories += A
	A.on_attached(S, actor)
	A.probe_print_actors = list()
	A.probe_print_calls = 0
	var/obj/item/payload
	var/obj/item/weapon/storage/internal/original_hold
	if (istype(A, /obj/item/clothing/accessory/holster))
		var/obj/item/clothing/accessory/holster/H = A
		payload = new(H)
		H.holstered = payload
	else if (istype(A, /obj/item/clothing/accessory/storage/sheath))
		var/obj/item/clothing/accessory/storage/sheath/H = A
		original_hold = H.hold
		payload = new(H.hold)
	else
		payload = new(A)
	if (mode == "full_hands")
		actor.l_hand = new /obj/item(actor)
		actor.r_hand = new /obj/item(actor)
	if (mode == "lying")
		actor.lying = TRUE
	var/no_actor = mode in list("null_user", "null_user_other_usr", "no_argument", "no_argument_null_usr")
	var/no_argument = mode in list("no_argument", "no_argument_null_usr")
	usr = null
	if (mode in list("different_usr", "null_user_other_usr", "no_argument"))
		usr = other
	if (mode == "same_usr")
		usr = actor
	var/requested_usr = accessory_actor_role(usr, actor, other)
	var/completed = TRUE
	try
		if (no_argument)
			A.on_removed()
		else
			S.remove_accessory(no_actor ? null : actor, A)
	catch
		completed = FALSE
	usr = null
	var/id = "[kind]/[mode]"
	accessory_actor_witnesses += list(list("case"=id, "body_marker"=A.probe_body_marker, "requested_usr"=requested_usr, "body_usr"=accessory_actor_role(A.probe_body_usr, actor, other), "body_user"=accessory_actor_role(A.probe_body_user, actor, other)))
	accessory_actor_check(completed, "[id]/completed")
	accessory_actor_check(!A.has_suit, "[id]/suit_backlink")
	var/overlay_ok = S.overlays.len == 1
	for (var/image/I in S.overlays)
		if (I.alpha != 123)
			overlay_ok = FALSE
	accessory_actor_check(overlay_ok, "[id]/overlay")
	var/expected_floor = no_actor ? site : get_turf(actor)
	var/expect_hand = !no_actor && !(mode in list("full_hands", "lying"))
	accessory_actor_check((expect_hand ? (A.loc == actor && (actor.l_hand == A || actor.r_hand == A)) : A.loc == expected_floor) && other.l_hand != A && other.r_hand != A, "[id]/actor_custody")
	var/prints_ok = no_actor ? A.probe_print_calls == 0 : A.probe_print_calls > 0
	for (var/mob/M in A.probe_print_actors)
		if (M != actor)
			prints_ok = FALSE
	accessory_actor_check(prints_ok, "[id]/fingerprint_actor")
	accessory_actor_check(no_argument ? (A in S.accessories) : !(A in S.accessories), "[id]/caller_membership")
	var/payload_ok = payload && payload.loc == A
	if (istype(A, /obj/item/clothing/accessory/holster))
		var/obj/item/clothing/accessory/holster/H = A
		payload_ok = H.holstered == payload && payload.loc == H
	else if (istype(A, /obj/item/clothing/accessory/storage/sheath))
		var/obj/item/clothing/accessory/storage/sheath/H = A
		payload_ok = H.hold == original_hold && H.hold.loc == H && H.hold.master_item == H && payload.loc == original_hold
	accessory_actor_check(payload_ok, "[id]/payload_identity")
	accessory_actor_check((/obj/item/clothing/under/accessory_actor_probe/verb/probe_marker in S.verbs) && !(/obj/item/clothing/accessory/holster/verb/holster_verb in S.verbs) && !(/obj/item/clothing/accessory/storage/sheath/verb/sheathe_verb in S.verbs), "[id]/subtype_verbs")
	var/custody_count = 0
	for (var/atom/container in list(S, actor, other, site, get_turf(actor), get_turf(other)))
		for (var/obj/item/clothing/accessory/candidate in container)
			if (candidate == A)
				custody_count++
	accessory_actor_check(custody_count == 1, "[id]/one_item")
	accessory_actor_check(S.probe_icon_updates == (no_argument ? 0 : 1), "[id]/caller_icon_update")
	// Keep actors until bounded world shutdown; no synthetic player destructor.
	A.has_suit = null
	S.accessories.Cut()
	A.loc = null
	S.loc = null
	actor.l_hand = null
	actor.r_hand = null
	other.l_hand = null
	other.r_hand = null

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	var/list/types = list("tie"=/obj/item/clothing/accessory, "holster"=/obj/item/clothing/accessory/holster, "sheath"=/obj/item/clothing/accessory/storage/sheath)
	for (var/kind in types)
		for (var/mode in list("null_usr", "different_usr", "same_usr", "null_user", "null_user_other_usr", "full_hands", "lying", "no_argument", "no_argument_null_usr"))
			accessory_actor_case(types[kind], kind, mode)
	text2file(json_encode(list("commit"=world.params["tested_commit"], "case_count"=accessory_actor_cases, "check_count"=accessory_actor_checks.len, "failed_labels"=accessory_actor_failed, "runtime_error"=accessory_actor_runtime_error, "checks"=accessory_actor_checks, "body_witnesses"=accessory_actor_witnesses)), "result.json")
	world.log << "COMPLETE accessory actor fixture"
	del(world)
