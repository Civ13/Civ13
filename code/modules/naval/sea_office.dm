// ============================================================
// The harbour office (docs/craft-core.md): contracts of the open sea
// ------------------------------------------------------------
// On the home island of an open-sea world stands a harbour office board. It
// offers the contracts (craft/contract.dm) the world itself has for crews:
//
//  - A survey: sail to a named island and anchor off it, then report back.
//    The office pays, and puts the island on every ship's chart for good.
//  - Salvage: bring one crate out of a named wreck back to the board. The
//    office keeps the crate as proof; what was in it is the crew's.
//
// The board is the poster, so the rewards are made when a contract is
// offered and lie in its record like any other. Nothing is a timer that has
// to outlast a save: the board fills its free places when somebody reads it.
// ============================================================

#define SEA_OFFICE_OFFERS 4
#define SEA_OFFICE_REFILL 6000
#define SEA_OFFICE_REACH 2

/obj/structure/sea_office
	name = "harbour office board"
	desc = "The board of the harbour office. It lists the surveys and salvage the office pays crews for."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard05"
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/next_fill = 0
	var/tmp/last_refusal = ""

/obj/structure/sea_office/ex_act(severity)
	return

/obj/structure/sea_office/Destroy()
	for (var/obj/craft_contract/C in contents)
		qdel(C)
	return ..()

// The office board of this open-sea world, or null.
/proc/sea_office()
	if (!open_sea_world())
		return null
	var/turf/middle = sea_cell_centre(sea_home_cell())
	if (!middle)
		return null
	for (var/turf/T in range(6, middle))
		var/obj/structure/sea_office/O = locate(/obj/structure/sea_office) in T
		if (O && !QDELETED(O))
			return O
	return null

// Stands the board on the home island when it has none. Returns the board.
/proc/sea_office_place()
	var/obj/structure/sea_office/O = sea_office()
	if (O)
		return O
	var/turf/middle = sea_cell_centre(sea_home_cell())
	if (!middle)
		return null
	var/list/tries = list(locate(middle.x + 3, middle.y + 3, middle.z))
	for (var/turf/T in range(5, middle))
		tries += T
	for (var/turf/T in tries)
		if (!T || T.density || istype(T, /turf/floor/beach/water))
			continue
		if (get_dist(T, middle) <= 1)
			continue
		var/blocked = FALSE
		for (var/atom/movable/M in T)
			if (M.density)
				blocked = TRUE
				break
		if (!blocked)
			return new /obj/structure/sea_office(T)
	return null

// ---------------------------------------------------------------- contracts

/obj/craft_contract/sea
	poster_name = "the harbour office"
	var/site_id = ""
	var/site_name = ""
	var/done = 0

/obj/craft_contract/sea/proc/site()
	return open_sea_site(site_id)

/obj/craft_contract/sea/proc/job_text()
	return "A job at [site_name]."

/obj/craft_contract/sea/describe(turf/from)
	. = "[job_text()] Reward: [reward_text()]."
	if (state == CONTRACT_TAKEN)
		. += " Taken by the [taker_craft] ([taker_name])[done ? ", done and waiting to be reported" : ""]."

/obj/craft_contract/sea/take_refusal(mob/living/human/H, datum/craft/C)
	. = ..()
	if (!. && !site())
		return "[site_name] is no longer on the chart"

/obj/craft_contract/sea/survey
	name = "survey contract"
	kind = "survey"

/obj/craft_contract/sea/survey/job_text()
	return "Survey [site_name]: anchor off it, then report here."

/obj/craft_contract/sea/salvage
	name = "salvage contract"
	kind = "salvage"

/obj/craft_contract/sea/salvage/job_text()
	return "Salvage from [site_name]: bring one of her crates to this board."

// A crate out of a wreck remembers which.
/obj/structure/closet/crate
	var/salvage_of = ""

/obj/structure/closet/crate/examine(mob/user)
	. = ..()
	if (length(salvage_of))
		var/datum/chart_site/sea/S = open_sea_site(salvage_of)
		if (S)
			to_chat(user, SPAN_NOTICE("It is branded as cargo of [S.name]."))

// ---------------------------------------------------------------- the board

/obj/structure/sea_office/proc/contracts(with_state = null, party = null)
	. = list()
	for (var/obj/craft_contract/sea/C in contents)
		if (!isnull(with_state) && C.state != with_state)
			continue
		if (party && C.taker_party != party)
			continue
		. += C

/obj/structure/sea_office/proc/contract_for(site_id)
	for (var/obj/craft_contract/sea/C in contents)
		if (C.site_id == site_id)
			return C
	return null

// Offers one contract for a site. Returns it, or null when the site has one.
/obj/structure/sea_office/proc/offer(datum/chart_site/sea/S)
	var/datum/chart/open_sea/chart = open_sea_chart()
	if (!S || !chart || !chart.home || contract_for(S.id))
		return null
	var/far = round(chart_distance(S.x, S.y, chart.home.x, chart.home.y))
	var/obj/craft_contract/sea/C = null
	var/pay = 0
	if (istype(S, /datum/chart_site/sea/wreck))
		C = new /obj/craft_contract/sea/salvage(src)
		pay = 20 + far
	else if (istype(S, /datum/chart_site/sea/island))
		if (S.charted)
			return null
		C = new /obj/craft_contract/sea/survey(src)
		pay = 10 + far
	else
		return null
	C.contract_id = craft_contract_new_id()
	C.site_id = S.id
	C.site_name = S.name
	var/obj/item/stack/money/real/coins = new(C)
	coins.amount = pay
	coins.update_icon()
	return C

// Fills the free places on the board. Returns how many contracts were added.
/obj/structure/sea_office/proc/fill(force = FALSE)
	. = 0
	if (!npc_jobs_enabled)
		return
	if (!force && world.time < next_fill)
		return
	var/datum/chart/open_sea/chart = open_sea_chart()
	if (!chart)
		return
	var/list/free = list()
	for (var/datum/chart_site/sea/S in chart.sites)
		if (!contract_for(S.id) && !S.charted)
			free += S
	while (contracts(CONTRACT_OPEN).len < SEA_OFFICE_OFFERS && free.len)
		if (offer(pick_n_take(free)))
			.++
	if (.)
		next_fill = world.time + SEA_OFFICE_REFILL

// The registered ship this character crews that lies in the home waters.
/proc/sea_office_crew_craft(mob/living/human/H)
	if (!istype(H))
		return null
	for (var/datum/craft/C in crafts)
		if (!C.register || !C.register.party || !C.register.is_crew(H))
			continue
		var/turf/P = C.centre()
		if (P && sea_cell_of(P) == sea_home_cell())
			return C
	return null

/obj/structure/sea_office/proc/board_text()
	var/list/all = contracts()
	if (!all.len)
		return "The harbour office has no work on the board just now."
	var/list/lines = list("<b>The harbour office pays for:</b>")
	for (var/obj/craft_contract/sea/C in all)
		lines += C.describe(get_turf(src))
	return jointext(lines, "<br>")

// A ship has anchored off a site: her party's survey of it is done.
/proc/sea_office_arrived(datum/craft/C, datum/chart_site/sea/S)
	var/obj/structure/sea_office/O = sea_office()
	if (!O || !C || !S || !C.register || !C.register.party)
		return FALSE
	for (var/obj/craft_contract/sea/survey/V in O.contracts(CONTRACT_TAKEN, C.register.party))
		if (V.site_id == S.id && !V.done)
			V.done = 1
			C.crew_message(SPAN_NOTICE("The survey of [S.name] is done. Report it at the harbour office in the home waters to be paid."))
			return TRUE
	return FALSE

// Pays every finished survey of this character's party. Returns how many.
/obj/structure/sea_office/proc/report(mob/living/human/H)
	. = 0
	var/party = party_train_party_of(H)
	last_refusal = "your party has no finished survey to report"
	if (!party)
		return
	for (var/obj/craft_contract/sea/survey/V in contracts(CONTRACT_TAKEN, party))
		if (!V.done)
			last_refusal = "the [V.taker_craft] has not anchored off [V.site_name] yet"
			continue
		var/datum/chart_site/sea/S = V.site()
		if (S)
			S.charted = 1
		log_game("[key_name(H)] reported the survey of [V.site_name] ([V.reward_text()]).")
		V.pay(H)
		qdel(V)
		.++

// Takes in one crate for each salvage contract of this character's party.
/obj/structure/sea_office/proc/hand_in(mob/living/human/H)
	. = 0
	var/party = party_train_party_of(H)
	last_refusal = "your party has no salvage contract"
	if (!party)
		return
	for (var/obj/craft_contract/sea/salvage/V in contracts(CONTRACT_TAKEN, party))
		var/obj/structure/closet/crate/found = null
		for (var/obj/structure/closet/crate/K in range(SEA_OFFICE_REACH, src))
			if (K.salvage_of == V.site_id && isturf(K.loc))
				found = K
				break
		if (!found)
			last_refusal = "no crate out of [V.site_name] stands within [SEA_OFFICE_REACH] tiles of the board"
			continue
		// What is in her is the crew's: it stays where the crate stood.
		var/turf/T = get_turf(found)
		for (var/atom/movable/A in found)
			A.forceMove(T)
		qdel(found)
		log_game("[key_name(H)] handed in salvage from [V.site_name] ([V.reward_text()]).")
		V.pay(H)
		qdel(V)
		.++

// A crew gives a contract up: it goes back on offer.
/obj/structure/sea_office/proc/give_up(mob/living/human/H, obj/craft_contract/sea/V)
	if (!istype(V) || V.loc != src || V.state != CONTRACT_TAKEN || V.taker_party != party_train_party_of(H))
		return FALSE
	V.state = CONTRACT_OPEN
	V.taker_party = ""
	V.taker_name = ""
	V.taker_craft = ""
	V.done = 0
	return TRUE

/obj/structure/sea_office/proc/choices(list/from)
	. = list()
	var/n = 0
	for (var/obj/craft_contract/sea/C in from)
		n++
		.["[n]. [C.describe(get_turf(src))]"] = C

/obj/structure/sea_office/examine(mob/user)
	. = ..()
	fill()
	to_chat(user, SPAN_NOTICE(board_text()))

/obj/structure/sea_office/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
		return
	fill()
	var/party = party_train_party_of(H)
	var/list/options = list()
	if (contracts(CONTRACT_OPEN).len)
		options += "Take a contract"
	if (party && contracts(CONTRACT_TAKEN, party).len)
		options += "Report a survey"
		options += "Hand in salvage"
		options += "Give up a contract"
	var/choice = WWinput(H, board_text(), "Harbour office", "Cancel", options + list("Cancel"))
	if (!(choice in options) || QDELETED(src) || get_dist(H, src) > 1)
		return
	switch (choice)
		if ("Take a contract")
			var/list/found = choices(contracts(CONTRACT_OPEN))
			var/pick = WWinput(H, "Take which contract? It goes to your ship's party.", "Harbour office", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/sea/C = found[pick]
			if (!istype(C) || QDELETED(C) || QDELETED(src) || get_dist(H, src) > 1)
				return
			if (!C.take(H, sea_office_crew_craft(H)))
				to_chat(H, SPAN_WARNING("You cannot take it: [C.last_refusal]."))
				return
			log_game("[key_name(H)] took the [C.kind] contract for [C.site_name] for the [C.taker_craft].")
			visible_message(SPAN_NOTICE("[H] takes the [C.kind] contract for [C.site_name] for the [C.taker_craft]."))
		if ("Report a survey")
			var/paid = report(H)
			if (paid)
				visible_message(SPAN_NOTICE("[H] reports [paid] survey\s and is paid by the harbour office."))
			else
				to_chat(H, SPAN_WARNING("Nothing is paid: [last_refusal]."))
		if ("Hand in salvage")
			var/paid = hand_in(H)
			if (paid)
				visible_message(SPAN_NOTICE("[H] hands in [paid] crate\s of salvage and is paid by the harbour office."))
			else
				to_chat(H, SPAN_WARNING("Nothing is paid: [last_refusal]."))
		if ("Give up a contract")
			var/list/found = choices(contracts(CONTRACT_TAKEN, party))
			var/pick = WWinput(H, "Give up which contract? It goes back on the board for any crew.", "Harbour office", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/sea/C = found[pick]
			if (istype(C) && !QDELETED(C) && !QDELETED(src) && get_dist(H, src) <= 1 && give_up(H, C))
				to_chat(H, SPAN_NOTICE("The contract goes back on the board."))
