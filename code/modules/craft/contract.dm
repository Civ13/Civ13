// ============================================================
// Contracts (docs/craft-core.md): jobs offered to crews
// ------------------------------------------------------------
// A contract is a record object that lives inside the board that offered it
// (a mooring post, later a station board). It is an object, not a datum, so
// the world save keeps it with its board: every field is plain text or a
// number and the reward lies in the record's own contents.
//
// A contract is "open" until a crew takes it, "taken" while they carry it
// out, and "returned" when it ended without the reward being earned: the
// reward then waits at the board for whoever offered it. A contract that was
// carried out pays its reward and is deleted.
//
// This file is the shared part. What the job is (freight between harbours,
// naval/freight.dm) is a subtype.
// ============================================================

var/global/list/craft_contracts = list()

/obj/craft_contract
	name = "contract"
	invisibility = 101
	anchored = TRUE
	density = FALSE
	var/contract_id = ""
	var/kind = "contract"
	var/state = CONTRACT_OPEN
	var/poster_party = ""
	var/poster_name = ""
	var/taker_party = ""
	var/taker_name = ""
	var/taker_craft = ""
	var/returned_why = ""
	var/tmp/last_refusal = ""

/obj/craft_contract/New()
	..()
	craft_contracts += src

/obj/craft_contract/Destroy()
	craft_contracts -= src
	return ..()

/obj/craft_contract/ex_act(severity)
	return

// A new id no other contract in this world has.
/proc/craft_contract_new_id()
	var/id = ""
	var/taken = TRUE
	while (taken)
		id = "c[rand(1, 99999999)]"
		taken = FALSE
		for (var/obj/craft_contract/C in craft_contracts)
			if (C.contract_id == id)
				taken = TRUE
				break
	return id

/proc/craft_contract_by_id(id)
	if (!istext(id) || !length(id))
		return null
	for (var/obj/craft_contract/C in craft_contracts)
		if (C.contract_id == id && !QDELETED(C))
			return C
	return null

// What the reward is made of: everything in the record that is not part of
// the job itself.
/obj/craft_contract/proc/reward_items()
	. = list()
	for (var/obj/item/I in contents)
		. += I

/obj/craft_contract/proc/reward_text()
	var/list/named = list()
	for (var/obj/item/I in reward_items())
		var/obj/item/stack/S = I
		named += (istype(S) && S.amount > 1) ? "[S.amount] [I.name]" : "\a [I]"
	return named.len ? jointext(named, ", ") : "no reward"

// The job in one line, as a board lists it.
/obj/craft_contract/proc/describe(turf/from)
	return "[capitalize(kind)] for [party_train_party_name(poster_party)], reward: [reward_text()]"

// The registered craft this character crews that lies within reach of a
// tile, or null. Contracts are offered to registered crews.
/proc/craft_contract_crew_craft(mob/living/human/H, turf/near, reach)
	if (!istype(H) || !near)
		return null
	for (var/datum/craft/C in crafts)
		if (!C.register || !C.register.party || !C.register.is_crew(H))
			continue
		var/turf/P = C.centre()
		if (P && P.z == near.z && get_dist(P, near) <= reach)
			return C
	return null

// Why this character cannot take the contract, or null.
/obj/craft_contract/proc/take_refusal(mob/living/human/H, datum/craft/C)
	if (state != CONTRACT_OPEN)
		return "that contract is no longer on offer"
	if (!C)
		return "contracts go to registered crews: bring a ship whose papers list you within reach of the board"
	return null

/obj/craft_contract/proc/take(mob/living/human/H, datum/craft/C)
	last_refusal = take_refusal(H, C)
	if (last_refusal)
		return FALSE
	state = CONTRACT_TAKEN
	taker_party = C.register.party
	taker_name = H.real_name
	taker_craft = C.name
	return TRUE

// Hands the reward to this character where they stand.
/obj/craft_contract/proc/pay(mob/living/human/H)
	var/turf/T = get_turf(H)
	if (!T)
		return FALSE
	for (var/obj/item/I in reward_items())
		I.forceMove(T)
		if (istype(H))
			H.put_in_hands(I)
	return TRUE

// The job ended without being done: the reward waits for the poster.
/obj/craft_contract/proc/give_back(why)
	state = CONTRACT_RETURNED
	returned_why = why

// The poster takes back the reward of a returned contract, which ends it.
/obj/craft_contract/proc/collect(mob/living/human/H)
	if (state != CONTRACT_RETURNED || !istype(H) || party_train_party_of(H) != poster_party)
		return FALSE
	pay(H)
	qdel(src)
	return TRUE
