// Freight contracts (code/modules/naval/freight.dm, craft/contract.dm,
// docs/craft-core.md): a crate offered at one mooring post for another with
// a reward, taken by a registered crew, handed in and paid; a broken seal, a
// lost crate, a withdrawn offer, a load and a post that is destroyed.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/datum/craft_drive/probe_push
	thrust = 1000

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// The fixture's people have no body to redraw: hands are plain fields.
/mob/living/human/naval_probe/remove_from_mob(var/obj/O)
	if (l_hand == O)
		l_hand = null
	if (r_hand == O)
		r_hand = null
	O.forceMove(loc)
	return TRUE
/mob/living/human/naval_probe/put_in_hands(var/obj/item/W)
	W.forceMove(src)
	return TRUE

/proc/freight_person(char_name, faction, turf/T)
	var/mob/living/human/naval_probe/H = new(T)
	H.real_name = char_name
	H.name = char_name
	H.civilization = faction
	return H

// A closed crate with a wrench in it.
/proc/freight_crate(x, y)
	var/obj/structure/closet/crate/C = new(locate(x, y, 2))
	new /obj/item/weapon/wrench(C)
	return C

// Puts a fresh hammer in a character's active hand, as a reward to offer.
/proc/freight_reward(mob/living/human/H)
	var/obj/item/weapon/hammer/I = new(H)
	if (H.hand)
		H.l_hand = I
	else
		H.r_hand = I
	return I

/proc/naval_checks()
	naval_fixture()
	var/obj/structure/berth/quay/A = new(locate(20, 20, 2))
	A.harbour = "Port Ann"
	var/obj/structure/berth/quay/B = new(locate(20, 45, 2))
	B.harbour = "Bay Town"
	for (var/x = 30, x <= 34, x++)
		hull_lay(x, 20)
		hull_lay(x, 21)
	var/obj/structure/hull_tiller/tiller = new(locate(32, 20, 2))
	naval_check(isnull(tiller.commission("Wren", EAST)), "the Wren is commissioned near Port Ann")
	var/datum/craft/W = tiller.craft
	var/mob/living/human/naval_probe/ann = freight_person("Ann", "Reds", locate(19, 21, 2))
	var/mob/living/human/naval_probe/bob = freight_person("Bob", "Blues", locate(20, 19, 2))
	var/mob/living/human/naval_probe/cat = freight_person("Cat", "Greens", locate(19, 19, 2))
	var/reds = party_train_party_of(ann)

	// ---- Who may offer ----
	naval_check(A.may_post(reds) && !A.may_post(null) && findtext(A.freight_text(get_turf(A)), "No freight"), "an unclaimed post takes contracts from any party and its board is empty")
	A.owner_party = party_train_party_of(cat)
	A.welcome = BERTH_WELCOME_OWNERS
	naval_check(!A.may_post(reds) && A.may_post(party_train_party_of(cat)), "a claimed post takes them only from those it welcomes")
	A.guests = list(reds)
	A.welcome = BERTH_WELCOME_GUESTS
	naval_check(A.may_post(reds) && !A.may_post(party_train_party_of(bob)), "its guests among them")
	A.welcome = BERTH_WELCOME_EVERYONE

	// ---- Offering ----
	var/obj/structure/closet/crate/open_one = freight_crate(20, 21)
	open_one.open()
	naval_check(open_one.opened && isnull(A.crate_to_send(ann)), "an open crate is not freight")
	qdel(open_one)
	for (var/obj/item/I in locate(20, 21, 2))
		qdel(I)
	var/obj/structure/closet/crate/box = freight_crate(19, 20)
	var/was_called = box.name
	naval_check(A.crate_to_send(ann) == box, "a closed crate by the post is found")
	naval_check(!A.offer_freight(ann, box, A, null) && findtext(A.freight_refusal, "another harbour"), "it cannot be sent to the harbour it stands in")
	var/obj/item/pay = freight_reward(ann)
	var/obj/craft_contract/freight/F = A.offer_freight(ann, box, B, pay)
	naval_check(F && F.loc == A && box.loc == F && pay.loc == F && ann.get_active_hand() != pay, "offered, the post takes in the crate and the reward ([A.freight_refusal])")
	naval_check(F.state == CONTRACT_OPEN && F.poster_party == reds && F.dest_name == "Bay Town" && F.destination() == B && box.freight_id == F.contract_id && box.name == "freight crate for Bay Town", "the contract names its harbour and the crate carries its seal")
	var/line = F.describe(get_turf(A))
	naval_check(findtext(line, "A crate for Bay Town, 25 tiles north, offered by Reds. Reward: a hammer."), "the board reads it ([line])")
	naval_check(findtext(A.status_text(), "1 freight contract on offer") && findtext(W.sea_chart_text(), "1 freight contract on offer") && findtext(A.freight_text(get_turf(A)), "Freight at Port Ann"), "the post and the sea chart say freight is waiting")
	naval_check(!A.offer_freight(ann, box, B, null) && findtext(A.freight_refusal, "closed crate must stand"), "a crate already taken in cannot be offered again")

	// ---- Taking ----
	naval_check(isnull(craft_contract_crew_craft(bob, get_turf(A), QUAY_DOCK_RANGE)) && !F.take(bob, null) && findtext(F.last_refusal, "registered crews"), "with no registered ship in reach nobody can take it")
	W.register = new /datum/craft_register
	W.register.party = party_train_party_of(bob)
	naval_check(craft_contract_crew_craft(bob, get_turf(A), QUAY_DOCK_RANGE) == W && isnull(craft_contract_crew_craft(cat, get_turf(A), QUAY_DOCK_RANGE)) && isnull(craft_contract_crew_craft(bob, get_turf(B), QUAY_DOCK_RANGE)), "the Wren, registered to the Blues and lying within reach, makes Bob a crew who can")
	naval_check(F.take(bob, W) && F.state == CONTRACT_TAKEN && F.taker_craft == "Wren" && F.taker_name == "Bob" && isturf(box.loc) && get_dist(box, bob) == 1 && !box.opened && pay.loc == F, "Bob takes it: the sealed crate is set down beside him and the reward stays with the harbour")
	naval_check(!F.take(bob, W) && !A.contracts(CONTRACT_OPEN).len && !findtext(A.status_text(), "freight contract"), "a taken contract is no longer on offer")
	naval_check(findtext(F.describe(null), "Carried by the Wren (Bob)"), "and the board says who carries it")

	// ---- Handing in ----
	naval_check(A.hand_in(bob) == 0 && findtext(A.freight_refusal, "no sealed crate bound for this harbour"), "it is not due at the harbour it left")
	box.forceMove(locate(21, 45, 2))
	bob.forceMove(locate(21, 44, 2))
	naval_check(B.hand_in(bob) == 1 && QDELETED(F) && !craft_contracts.len, "handed in at Bay Town the contract is done")
	naval_check((pay.loc == bob || pay.loc == get_turf(bob)) && box.freight_id == "" && box.name == was_called && !freight_crates.len && (locate(/obj/item/weapon/wrench) in box), "Bob is paid, and the crate is an ordinary crate again with its goods inside")

	// ---- A broken seal ----
	bob.forceMove(locate(20, 19, 2))
	box.forceMove(locate(19, 20, 2))
	pay = freight_reward(ann)
	F = A.offer_freight(ann, box, B, pay)
	naval_check(F && F.take(bob, W), "a second crate is offered and taken")
	box.open()
	naval_check(F.seal_broken && box.opened, "opening it breaks the seal")
	box.forceMove(locate(21, 45, 2))
	naval_check(B.hand_in(bob) == 0 && findtext(B.freight_refusal, "close the crate"), "an open crate is not accepted")
	box.close()
	naval_check(B.hand_in(bob) == 0 && findtext(B.freight_refusal, "seal is broken") && F.state == CONTRACT_RETURNED && pay.loc == F && box.freight_id == "", "handed in with a broken seal it earns nothing and the reward goes back to wait")
	naval_check(findtext(F.describe(null), "seal broken") && !F.collect(bob) && F.collect(ann) && QDELETED(F) && (pay.loc == ann || pay.loc == get_turf(ann)), "only the party that offered it collects the returned reward")

	// ---- A lost crate ----
	box.forceMove(locate(19, 20, 2))
	pay = freight_reward(ann)
	F = A.offer_freight(ann, box, B, pay)
	naval_check(F && F.take(bob, W) && !F.write_off(ann), "a third is taken; while the crate exists it cannot be written off")
	qdel(box)
	naval_check(isnull(F.crate()) && !F.write_off(bob) && F.write_off(ann) && F.state == CONTRACT_RETURNED && A.contract_choices(CONTRACT_RETURNED, reds).len == 1, "once the crate is destroyed its poster writes it off and the reward waits at the board")
	naval_check(F.collect(ann) && !craft_contracts.len, "and collects it")

	// ---- Withdrawing ----
	box = freight_crate(19, 20)
	pay = freight_reward(ann)
	F = A.offer_freight(ann, box, B, pay)
	naval_check(F && !F.withdraw(bob) && F.withdraw(ann) && QDELETED(F) && isturf(box.loc) && get_dist(box, ann) == 1 && box.freight_id == "" && (pay.loc == ann || pay.loc == get_turf(ann)), "an offer nobody took can be withdrawn by its poster, crate and reward returned")

	// ---- A load ----
	box.forceMove(locate(19, 20, 2))
	F = A.offer_freight(ann, box, B, null)
	naval_check(F && findtext(F.describe(null), "Reward: no reward") && F.take(bob, W), "a contract may carry no reward")
	freight_crates.Cut()
	naval_check(isnull(F.crate()), "a crate the world has forgotten is not found")
	box.after_load()
	naval_check(F.crate() == box && craft_contract_by_id(box.freight_id) == F, "after a load the crate finds its contract again by its id")
	box.forceMove(locate(21, 45, 2))
	naval_check(B.hand_in(bob) == 1 && QDELETED(F), "and is handed in as before")

	// ---- A full board, a vanished harbour and a destroyed post ----
	var/list/boxes = list()
	for (var/n = 1, n <= 7, n++)
		var/obj/structure/closet/crate/extra = freight_crate(19, 20)
		boxes += extra
		A.offer_freight(ann, extra, B, null)
	naval_check(A.contracts().len == 6 && findtext(A.freight_refusal, "board is full"), "a board holds six contracts")
	var/obj/structure/closet/crate/last = boxes[7]
	qdel(last)
	var/obj/craft_contract/freight/first = A.contracts()[1]
	first.take(bob, W)
	var/obj/structure/closet/crate/out = first.crate()
	qdel(B)
	naval_check(isnull(first.destination()) && out && isturf(out.loc), "with its harbour gone a crate has nowhere to be handed in")
	var/turf/stood = get_turf(A)
	qdel(A)
	var/spilled = 0
	for (var/obj/structure/closet/crate/C in stood)
		if (!length(C.freight_id))
			spilled++
	naval_check(spilled == 5 && !craft_contracts.len && out.freight_id == "", "a destroyed post spills its crates and ends its contracts ([spilled])")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
