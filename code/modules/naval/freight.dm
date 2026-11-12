// ============================================================
// Freight contracts (docs/craft-core.md): crates carried between harbours
// ------------------------------------------------------------
// The first kind of contract (craft/contract.dm). At a mooring post a player
// offers a closed crate for carriage to another harbour, with whatever they
// hold in their hand as the reward. The post takes both in. A registered
// crew whose ship lies within reach of the post takes the contract: the
// crate comes out sealed, set down beside them. Whoever hands the sealed crate in at the
// destination post is paid the reward there by the harbour.
//
// Opening a sealed crate breaks the seal. A crate handed in with a broken
// seal earns nothing: the reward goes back to wait for whoever offered it,
// as it does when the crate was lost and they write it off.
//
// The record and its reward lie in the post, the crate remembers its
// contract by id, and nothing is a timer, so all of it is kept by the world
// save.
// ============================================================

#define FREIGHT_REACH 2
#define FREIGHT_BOARD_MAX 6

var/global/list/freight_crates = list()    // contract id = sealed crate

/obj/craft_contract/freight
	name = "freight contract"
	kind = "freight"
	var/origin_name = ""
	var/dest_name = ""
	var/dest_x = 0
	var/dest_y = 0
	var/dest_z = 0
	var/crate_name = ""        // What the crate was called before it was sealed.
	var/seal_broken = 0

// The mooring post the crate is bound for, or null when it is gone.
/obj/craft_contract/freight/proc/destination()
	var/turf/T = locate(dest_x, dest_y, dest_z)
	return T ? (locate(/obj/structure/berth/quay) in T) : null

// The crate: in the record while the contract is on offer, out in the world
// once it is taken, null when it has been destroyed.
/obj/craft_contract/freight/proc/crate()
	var/obj/structure/closet/crate/C = locate(/obj/structure/closet/crate) in contents
	if (C)
		return C
	C = freight_crates[contract_id]
	if (C && !QDELETED(C) && C.freight_id == contract_id)
		return C
	return null

/obj/craft_contract/freight/describe(turf/from)
	var/turf/T = locate(dest_x, dest_y, dest_z)
	var/where = ""
	if (from && T && from.z == T.z)
		where = ", [get_dist(from, T)] tiles [submarine_bearing(from, T)]"
	. = "A crate for [dest_name][where], offered by [party_train_party_name(poster_party)]. Reward: [reward_text()]."
	switch (state)
		if (CONTRACT_TAKEN)
			. += " Carried by the [taker_craft] ([taker_name])."
		if (CONTRACT_RETURNED)
			. += " Ended: [returned_why]. The reward waits here for [party_train_party_name(poster_party)]."

/obj/craft_contract/freight/take(mob/living/human/H, datum/craft/C)
	var/obj/structure/closet/crate/box = locate(/obj/structure/closet/crate) in contents
	if (!box)
		last_refusal = "the crate is gone"
		return FALSE
	if (!..())
		return FALSE
	box.forceMove(freight_set_down(H))
	return TRUE

// Where a crate handed to this character is set down: a clear tile beside
// them, or the one they stand on when there is none.
/proc/freight_set_down(mob/H)
	var/turf/here = get_turf(H)
	for (var/d in cardinal)
		var/turf/T = get_step(here, d)
		if (!T || T.density || istype(T, /turf/floor/beach/water))
			continue
		var/blocked = FALSE
		for (var/atom/movable/M in T)
			if (M.density)
				blocked = TRUE
				break
		if (!blocked)
			return T
	return here

// Takes the seal off the crate and forgets it.
/obj/craft_contract/freight/proc/unseal(obj/structure/closet/crate/box)
	if (!box)
		return
	freight_crates -= contract_id
	if (box.freight_id == contract_id)
		box.freight_id = ""
		if (length(crate_name))
			box.name = crate_name

// The sealed crate arrives at its harbour. Returns TRUE when the reward was
// paid; FALSE with last_refusal set when it was not.
/obj/craft_contract/freight/proc/deliver(mob/living/human/H, obj/structure/berth/quay/at)
	var/obj/structure/closet/crate/box = crate()
	if (state != CONTRACT_TAKEN || !box || !at || at != destination())
		last_refusal = "that crate is not due here"
		return FALSE
	unseal(box)
	if (seal_broken)
		give_back("the crate reached [dest_name] with its seal broken")
		last_refusal = "the seal is broken, so the harbour pays nothing"
		return FALSE
	log_game("[key_name(H)] delivered freight [contract_id] from [origin_name] to [dest_name] ([reward_text()]).")
	pay(H)
	qdel(src)
	return TRUE

// The poster takes an offer down: crate and reward come back out.
/obj/craft_contract/freight/proc/withdraw(mob/living/human/H)
	if (state != CONTRACT_OPEN || !istype(H) || party_train_party_of(H) != poster_party)
		return FALSE
	var/obj/structure/closet/crate/box = crate()
	if (box)
		unseal(box)
		box.forceMove(freight_set_down(H))
	pay(H)
	qdel(src)
	return TRUE

// The poster writes off a crate that no longer exists.
/obj/craft_contract/freight/proc/write_off(mob/living/human/H)
	if (state != CONTRACT_TAKEN || crate() || !istype(H) || party_train_party_of(H) != poster_party)
		return FALSE
	give_back("the crate was lost")
	return TRUE

// Everything comes out where the board stood.
/obj/craft_contract/freight/proc/spill(turf/T)
	var/obj/structure/closet/crate/box = crate()
	unseal(box)
	if (box && box.loc == src && T)
		box.forceMove(T)
	for (var/obj/item/I in reward_items())
		if (T)
			I.forceMove(T)
	qdel(src)

// ---------------------------------------------------------------- the crate

/obj/structure/closet/crate
	// The id of the freight contract whose seal this crate carries, or "".
	var/freight_id = ""

/obj/structure/closet/crate/after_load()
	..()
	if (length(freight_id))
		freight_crates[freight_id] = src

/obj/structure/closet/crate/Destroy()
	if (length(freight_id) && freight_crates[freight_id] == src)
		freight_crates -= freight_id
	return ..()

/obj/structure/closet/crate/open()
	var/was_shut = !opened
	. = ..()
	if (was_shut && opened && length(freight_id))
		var/obj/craft_contract/freight/F = craft_contract_by_id(freight_id)
		if (istype(F) && !F.seal_broken)
			F.seal_broken = 1
			visible_message(SPAN_WARNING("The freight seal on [src] breaks."))

/obj/structure/closet/crate/examine(mob/user)
	. = ..()
	if (!length(freight_id))
		return
	var/obj/craft_contract/freight/F = craft_contract_by_id(freight_id)
	if (istype(F))
		to_chat(user, SPAN_NOTICE("It carries a freight seal: bound for [F.dest_name] from [F.origin_name]. The seal is [F.seal_broken ? "broken" : "whole"]."))

// ---------------------------------------------------------------- the board

/obj/structure/berth/quay
	var/tmp/freight_refusal = ""

/obj/structure/berth/quay/proc/contracts(with_state = null)
	. = list()
	for (var/obj/craft_contract/C in contents)
		if (isnull(with_state) || C.state == with_state)
			. += C

// Whether this party may offer contracts here: anyone at an unclaimed post,
// otherwise whoever the post welcomes.
/obj/structure/berth/quay/proc/may_post(party)
	if (!party)
		return FALSE
	if (!owner_party || party == owner_party || welcome == BERTH_WELCOME_EVERYONE)
		return TRUE
	return welcome == BERTH_WELCOME_GUESTS && (party in guests)

// A closed crate by the post that is not freight already: the one being
// pulled, else the nearest.
/obj/structure/berth/quay/proc/crate_to_send(mob/living/human/H)
	var/obj/structure/closet/crate/best = null
	for (var/obj/structure/closet/crate/C in range(FREIGHT_REACH, src))
		if (C.opened || length(C.freight_id) || !isturf(C.loc))
			continue
		if (H && H.pulling == C)
			return C
		if (!best || get_dist(C, src) < get_dist(best, src))
			best = C
	return best

// Offers a crate for carriage to another harbour. Returns the contract, or
// null with freight_refusal set.
/obj/structure/berth/quay/proc/offer_freight(mob/living/human/H, obj/structure/closet/crate/box, obj/structure/berth/quay/dest, obj/item/reward)
	freight_refusal = ""
	var/party = party_train_party_of(H)
	if (!may_post(party))
		freight_refusal = "this harbour does not take contracts from your party"
	else if (contracts().len >= FREIGHT_BOARD_MAX)
		freight_refusal = "the board is full"
	else if (!istype(box) || QDELETED(box) || box.opened || length(box.freight_id) || get_dist(box, src) > FREIGHT_REACH)
		freight_refusal = "a closed crate must stand within [FREIGHT_REACH] tiles of the post"
	else if (!istype(dest) || QDELETED(dest) || dest == src || !(dest in sea_harbours))
		freight_refusal = "it must be bound for another harbour"
	else if (reward && (!istype(reward) || reward.loc != H))
		freight_refusal = "the reward must be in your hand"
	if (freight_refusal)
		return null
	if (reward)
		H.remove_from_mob(reward)
		if (reward.loc == H)
			freight_refusal = "you cannot let go of [reward]"
			return null
	var/obj/craft_contract/freight/F = new(src)
	F.contract_id = craft_contract_new_id()
	F.poster_party = party
	F.poster_name = H.real_name
	F.origin_name = berth_name()
	F.dest_name = dest.berth_name()
	F.dest_x = dest.x
	F.dest_y = dest.y
	F.dest_z = dest.z
	F.crate_name = box.name
	if (H.pulling == box)
		H.stop_pulling()
	box.freight_id = F.contract_id
	box.name = "freight crate for [F.dest_name]"
	freight_crates[F.contract_id] = box
	box.forceMove(F)
	if (reward)
		reward.forceMove(F)
	log_game("[key_name(H)] offered freight [F.contract_id] at [x],[y],[z] for [F.dest_name] ([F.reward_text()]).")
	return F

// Hands in every sealed crate by the post that is due here. Returns how many
// were paid for; freight_refusal says why the last one was not.
/obj/structure/berth/quay/proc/hand_in(mob/living/human/H)
	. = 0
	freight_refusal = "no sealed crate bound for this harbour stands within [FREIGHT_REACH] tiles of the post"
	for (var/obj/structure/closet/crate/C in range(FREIGHT_REACH, src))
		if (!length(C.freight_id) || !isturf(C.loc))
			continue
		var/obj/craft_contract/freight/F = craft_contract_by_id(C.freight_id)
		if (!istype(F) || F.state != CONTRACT_TAKEN || F.destination() != src)
			continue
		if (C.opened)
			freight_refusal = "close the crate first"
			continue
		if (F.deliver(H, src))
			.++
		else
			freight_refusal = F.last_refusal

/obj/structure/berth/quay/proc/freight_text(turf/from)
	var/list/all = contracts()
	if (!all.len)
		return "No freight is on the board."
	var/list/lines = list("<b>Freight at [berth_name()]:</b>")
	for (var/obj/craft_contract/C in all)
		lines += C.describe(from)
	return jointext(lines, "<br>")

/obj/structure/berth/quay/Destroy()
	var/turf/T = get_turf(src)
	for (var/obj/craft_contract/freight/F in contents)
		F.spill(T)
	return ..()

// Contracts of this party on the board in a state, by a line to pick from.
/obj/structure/berth/quay/proc/contract_choices(with_state, party = null, lost_only = FALSE)
	. = list()
	var/n = 0
	for (var/obj/craft_contract/freight/F in contracts(with_state))
		if (party && F.poster_party != party)
			continue
		if (lost_only && F.crate())
			continue
		n++
		.["[n]. [F.describe(get_turf(src))]"] = F

/obj/structure/berth/quay/proc/freight_menu(mob/living/human/H)
	var/party = party_train_party_of(H)
	var/list/options = list()
	if (may_post(party))
		options += "Offer a contract"
	if (contracts(CONTRACT_OPEN).len)
		options += "Take a contract"
	options += "Hand in freight"
	if (party && contract_choices(CONTRACT_OPEN, party).len)
		options += "Withdraw a contract"
	if (party && contract_choices(CONTRACT_TAKEN, party, TRUE).len)
		options += "Write off lost freight"
	if (party && contract_choices(CONTRACT_RETURNED, party).len)
		options += "Collect a returned reward"
	var/choice = WWinput(H, freight_text(get_turf(src)), "Freight", "Cancel", options + list("Cancel"))
	if (!(choice in options) || QDELETED(src) || get_dist(H, src) > 1)
		return
	switch (choice)
		if ("Offer a contract")
			var/obj/structure/closet/crate/box = crate_to_send(H)
			if (!box)
				to_chat(H, SPAN_WARNING("Stand a closed crate within [FREIGHT_REACH] tiles of the post first. Whatever is in it is the freight."))
				return
			var/list/ports = list()
			for (var/obj/structure/berth/quay/Q in sea_harbours)
				if (Q == src || QDELETED(Q))
					continue
				ports["[capitalize(Q.berth_name())][Q.z == z ? ", [get_dist(src, Q)] tiles [submarine_bearing(get_turf(src), get_turf(Q))]" : ", on another sea"]"] = Q
			if (!ports.len)
				to_chat(H, SPAN_WARNING("There is no other harbour to send it to."))
				return
			var/port = WWinput(H, "Send [box] to which harbour?", "Freight", "Cancel", ports + list("Cancel"))
			var/obj/structure/berth/quay/dest = ports[port]
			if (!dest || QDELETED(src) || get_dist(H, src) > 1)
				return
			var/obj/item/reward = H.get_active_hand()
			var/terms = reward ? "The reward is [reward] in your hand: the harbour holds it and pays whoever hands the sealed crate in at [dest.berth_name()]." : "Your hand is empty, so there is no reward. Hold the reward in your active hand to offer one."
			if (WWinput(H, "[terms] The post takes the crate in until a crew takes the contract. Offer it?", "Freight", "No", list("Yes", "No")) != "Yes" || QDELETED(src) || get_dist(H, src) > 1)
				return
			if (reward && H.get_active_hand() != reward)
				return
			var/obj/craft_contract/freight/F = offer_freight(H, box, dest, reward)
			if (!F)
				to_chat(H, SPAN_WARNING("The contract is not posted: [freight_refusal]."))
				return
			visible_message(SPAN_NOTICE("[H] posts a freight contract for [F.dest_name] at the mooring post."))
		if ("Take a contract")
			var/list/found = contract_choices(CONTRACT_OPEN)
			var/pick = WWinput(H, "Take which contract? The sealed crate is set down beside you. Hand it in unopened at its harbour to be paid.", "Freight", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/freight/F = found[pick]
			if (!istype(F) || QDELETED(F) || QDELETED(src) || get_dist(H, src) > 1)
				return
			if (!F.take(H, craft_contract_crew_craft(H, get_turf(src), QUAY_DOCK_RANGE)))
				to_chat(H, SPAN_WARNING("You cannot take it: [F.last_refusal]."))
				return
			log_game("[key_name(H)] took freight [F.contract_id] at [x],[y],[z] for the [F.taker_craft].")
			visible_message(SPAN_NOTICE("[H] takes the freight for [F.dest_name] aboard the [F.taker_craft]."))
		if ("Hand in freight")
			var/paid = hand_in(H)
			if (paid)
				visible_message(SPAN_NOTICE("[H] hands in [paid] crate\s of freight and is paid by the harbour."))
			else
				to_chat(H, SPAN_WARNING("Nothing is paid: [freight_refusal]."))
		if ("Withdraw a contract")
			var/list/found = contract_choices(CONTRACT_OPEN, party)
			var/pick = WWinput(H, "Withdraw which contract? The crate and the reward come back to you.", "Freight", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/freight/F = found[pick]
			if (istype(F) && !QDELETED(F) && !QDELETED(src) && get_dist(H, src) <= 1 && F.withdraw(H))
				to_chat(H, SPAN_NOTICE("You take the contract down."))
		if ("Write off lost freight")
			var/list/found = contract_choices(CONTRACT_TAKEN, party, TRUE)
			var/pick = WWinput(H, "Write off which contract? Its crate no longer exists. The reward comes back to the board for you.", "Freight", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/freight/F = found[pick]
			if (istype(F) && !QDELETED(F) && !QDELETED(src) && get_dist(H, src) <= 1 && F.write_off(H))
				to_chat(H, SPAN_NOTICE("The freight is written off. Collect the reward from the board."))
		if ("Collect a returned reward")
			var/list/found = contract_choices(CONTRACT_RETURNED, party)
			var/pick = WWinput(H, "Collect which reward?", "Freight", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/freight/F = found[pick]
			if (istype(F) && !QDELETED(F) && !QDELETED(src) && get_dist(H, src) <= 1 && F.collect(H))
				to_chat(H, SPAN_NOTICE("The harbour hands the reward back."))
