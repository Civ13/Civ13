// ============================================================
// Depot work (docs/craft-core.md): surveys and lost cargo on land
// ------------------------------------------------------------
// A freight depot (freight_depot.dm) also offers the work the land itself
// has for a crew with a vehicle, the way the harbour office does at sea
// (sea_office.dm):
//
//  - A survey: carry the depot's survey stake to a spot some way off, drive
//    it in there, and report back.
//  - Lost cargo: find a crate that fell off a wagon some way off and bring
//    it back to the depot unopened or not; the depot keeps the crate.
//
// The spot is told as a distance and a bearing from the depot. The stake, or
// the note that comes with a lost cargo job, reads the way from wherever it
// is used. The depot is the poster, so the pay is made when a job is offered
// and lies in its record. A job is a record in the depot like a freight
// contract; its spot is plain numbers, and the board fills its free places
// when somebody reads it, so nothing has to outlast a save.
// ============================================================

#define DEPOT_JOB_OFFERS 3
#define DEPOT_JOB_REFILL 6000
#define DEPOT_JOB_HELD 2          // Jobs one party may hold from one depot.
#define DEPOT_JOB_NEAR 60         // A spot is at least this far off,
#define DEPOT_JOB_FAR 220         // and at most this far.
#define DEPOT_JOB_SPOT 6          // How near the spot a stake counts.
#define DEPOT_JOB_REACH 2         // How near the depot a crate is handed in.

/obj/craft_contract/land
	poster_name = "the depot"
	var/spot_x = 0
	var/spot_y = 0
	var/spot_z = 0
	var/far = 0                   // Tiles from the depot to the spot.
	var/way = ""                  // The bearing from the depot, in words.
	var/done = 0

/obj/craft_contract/land/proc/spot()
	return locate(spot_x, spot_y, spot_z)

/obj/craft_contract/land/proc/job_text()
	return "A job [far] tiles [way]."

/obj/craft_contract/land/describe(turf/from)
	. = "[job_text()] Pay: [reward_text()]."
	if (state == CONTRACT_TAKEN)
		. += " Taken by the [taker_craft] ([taker_name])[done ? ", done and waiting to be reported" : ""]."

// The compass point from one tile towards another, by the angle between
// them, so a spot a long way east and a little north reads as east.
/proc/depot_bearing(turf/from, turf/target)
	var/dx = target.x - from.x
	var/dy = target.y - from.y
	if (!dx && !dy)
		return "here"
	var/ns = dy > 0 ? "north" : "south"
	var/ew = dx > 0 ? "east" : "west"
	if (abs(dy) <= abs(dx) * 0.414)
		return ew
	if (abs(dx) <= abs(dy) * 0.414)
		return ns
	return "[ns][ew]"

// The way to the spot from a tile, in words.
/obj/craft_contract/land/proc/way_from(turf/from)
	var/turf/T = spot()
	if (!from || !T || from.z != T.z)
		return "The spot is not in this land."
	var/d = get_dist(from, T)
	if (d <= DEPOT_JOB_SPOT)
		return "This is the spot."
	return "The spot is about [d] tiles [depot_bearing(from, T)]."

/obj/craft_contract/land/Destroy()
	for (var/obj/item/depot_guide/G in depot_guides)
		if (G.job_id == contract_id)
			qdel(G)
	return ..()

/obj/craft_contract/land/survey
	name = "survey job"
	kind = "survey"

/obj/craft_contract/land/survey/job_text()
	return "Survey the land [far] tiles [way]: drive the stake in there, then report here."

/obj/craft_contract/land/cargo
	name = "lost cargo job"
	kind = "lost cargo"

/obj/craft_contract/land/cargo/job_text()
	return "Lost cargo [far] tiles [way]: find the crate and bring it to this depot."

// The crate, or null when it is gone.
/obj/craft_contract/land/cargo/proc/crate()
	for (var/obj/structure/closet/crate/K in depot_cargo)
		if (K.salvage_of == contract_id && !QDELETED(K))
			return K
	return null

/obj/craft_contract/land/cargo/Destroy()
	var/obj/structure/closet/crate/K = crate()
	if (K)
		qdel(K)
	return ..()

// ---------------------------------------------------------------- the guide

var/global/list/depot_guides = list()
var/global/list/depot_cargo = list()

// What the crew carries: it knows its job and reads the way to the spot.
/obj/item/depot_guide
	name = "cargo note"
	desc = "A depot clerk's note of where a crate was lost. Use it to read the way from where you stand."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	w_class = ITEM_SIZE_TINY
	var/job_id = ""

/obj/item/depot_guide/New()
	..()
	depot_guides += src

/obj/item/depot_guide/Destroy()
	depot_guides -= src
	return ..()

/obj/item/depot_guide/proc/job()
	var/obj/craft_contract/land/J = craft_contract_by_id(job_id)
	return istype(J) ? J : null

/obj/item/depot_guide/examine(mob/user)
	. = ..()
	var/obj/craft_contract/land/J = job()
	to_chat(user, SPAN_NOTICE(J ? J.way_from(get_turf(user)) : "The job it was for is over."))

/obj/item/depot_guide/attack_self(mob/user)
	var/obj/craft_contract/land/J = job()
	if (!J)
		to_chat(user, SPAN_NOTICE("The job it was for is over."))
		qdel(src)
		return
	to_chat(user, SPAN_NOTICE(J.way_from(get_turf(user))))

/obj/item/depot_guide/stake
	name = "survey stake"
	desc = "A depot's marked survey stake. Use it to read the way to the spot, and to drive it in when you are there."
	icon = 'icons/obj/old_weapons.dmi'
	icon_state = "sharpened_stick"
	w_class = ITEM_SIZE_SMALL

/obj/item/depot_guide/stake/attack_self(mob/user)
	var/obj/craft_contract/land/survey/J = job()
	if (!istype(J))
		return ..()
	var/turf/here = get_turf(user)
	var/turf/T = J.spot()
	if (!here || !T || here.z != T.z || get_dist(here, T) > DEPOT_JOB_SPOT)
		return ..()
	J.done = 1
	user.visible_message(SPAN_NOTICE("[user] drives a survey stake into the ground."), SPAN_NOTICE("You drive the stake in. The survey is done: report it at the depot to be paid."))
	qdel(src)

// A crate lost on the road remembers its job after a load.
/obj/structure/closet/crate/after_load()
	..()
	if (length(salvage_of) && findtext(salvage_of, "c") == 1)
		depot_cargo |= src

/obj/structure/closet/crate/Destroy()
	depot_cargo -= src
	return ..()

// ---------------------------------------------------------------- the board

/obj/structure/berth/quay/depot
	var/tmp/next_job_fill = 0
	var/tmp/job_refusal = ""

// The freight board lists freight only; the depot's own work is jobs().
/obj/structure/berth/quay/depot/contracts(with_state = null)
	. = list()
	for (var/obj/craft_contract/freight/C in contents)
		if (isnull(with_state) || C.state == with_state)
			. += C

/obj/structure/berth/quay/depot/proc/jobs(with_state = null, party = null)
	. = list()
	for (var/obj/craft_contract/land/J in contents)
		if (!isnull(with_state) && J.state != with_state)
			continue
		if (party && J.taker_party != party)
			continue
		. += J

/obj/structure/berth/quay/depot/Destroy()
	for (var/obj/craft_contract/land/J in contents)
		qdel(J)
	return ..()

// TRUE when a spot can be surveyed or a crate can lie there: open ground
// under the sky with nothing standing on it.
/proc/depot_job_ground(turf/T)
	if (!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/space))
		return FALSE
	var/area/A = T.loc
	if (!istype(A) || A.location != AREA_OUTSIDE)
		return FALSE
	for (var/atom/movable/M in T)
		if (M.density || istype(M, /obj/covers) || istype(M, /obj/structure))
			return FALSE
	return TRUE

// A spot for a job some way off on this level, or null.
/obj/structure/berth/quay/depot/proc/find_spot()
	for (var/tries = 1, tries <= 60, tries++)
		var/turf/T = locate(rand(4, world.maxx - 3), rand(4, world.maxy - 3), z)
		if (!T)
			continue
		var/d = get_dist(src, T)
		if (d < DEPOT_JOB_NEAR || d > DEPOT_JOB_FAR)
			continue
		if (depot_job_ground(T))
			return T
	return null

// Offers one job. Returns it, or null when no spot could be found.
/obj/structure/berth/quay/depot/proc/offer_job(path, turf/T = null)
	if (!ispath(path, /obj/craft_contract/land))
		return null
	if (!T)
		T = find_spot()
	if (!T)
		return null
	var/obj/craft_contract/land/J = new path(src)
	J.contract_id = craft_contract_new_id()
	J.spot_x = T.x
	J.spot_y = T.y
	J.spot_z = T.z
	J.far = get_dist(src, T)
	J.way = depot_bearing(get_turf(src), T)
	var/obj/item/stack/money/real/coins = new(J)
	coins.amount = istype(J, /obj/craft_contract/land/cargo) ? 8 + round(J.far / 15) : 4 + round(J.far / 20)
	coins.update_icon()
	return J

// Fills the free places on the board. Returns how many jobs were added.
/obj/structure/berth/quay/depot/proc/fill_jobs(force = FALSE)
	. = 0
	if (!npc_jobs_enabled)
		return
	if (!force && world.time < next_job_fill)
		return
	for (var/n = jobs(CONTRACT_OPEN).len, n < DEPOT_JOB_OFFERS, n++)
		if (!offer_job(prob(50) ? /obj/craft_contract/land/survey : /obj/craft_contract/land/cargo))
			break
		.++
	next_job_fill = world.time + DEPOT_JOB_REFILL

/obj/structure/berth/quay/depot/proc/jobs_text()
	var/list/all = jobs()
	if (!all.len)
		return "The depot has no work of its own just now."
	var/list/lines = list("<b>The depot pays for:</b>")
	for (var/obj/craft_contract/land/J in all)
		lines += J.describe(get_turf(src))
	return jointext(lines, "<br>")

// A crew takes a job: the stake or the note is handed over, and a lost
// crate is where the note says. FALSE with job_refusal set when it cannot.
/obj/structure/berth/quay/depot/proc/take_job(mob/living/human/H, obj/craft_contract/land/J)
	job_refusal = ""
	if (!istype(J) || J.loc != src)
		job_refusal = "that job is no longer on the board"
		return FALSE
	var/datum/craft/C = freight_crew_craft(H)
	if (C && jobs(CONTRACT_TAKEN, C.register.party).len >= DEPOT_JOB_HELD)
		job_refusal = "your party already holds [DEPOT_JOB_HELD] jobs from this depot"
		return FALSE
	var/turf/T = J.spot()
	if (istype(J, /obj/craft_contract/land/cargo) && !depot_job_ground(T))
		job_refusal = "the road there is blocked now; that job is struck off"
		qdel(J)
		return FALSE
	if (!J.take(H, C))
		job_refusal = J.last_refusal
		return FALSE
	var/obj/item/depot_guide/G
	if (istype(J, /obj/craft_contract/land/survey))
		G = new /obj/item/depot_guide/stake(get_turf(H))
	else
		G = new /obj/item/depot_guide(get_turf(H))
		var/obj/structure/closet/crate/K = new(T)
		K.name = "lost cargo crate"
		K.salvage_of = J.contract_id
		depot_cargo |= K
	G.job_id = J.contract_id
	H.put_in_hands(G)
	return TRUE

// The party a character answers for at the board: their own, or that of the
// registered vehicle standing by with them on its crew, so a hired driver can
// finish what the vehicle's party took.
/obj/structure/berth/quay/depot/proc/job_party(mob/living/human/H)
	var/party = party_train_party_of(H)
	if (party && jobs(CONTRACT_TAKEN, party).len)
		return party
	var/datum/craft/C = freight_crew_craft(H)
	if (C && C.register && C.register.party)
		return C.register.party
	return party

// Pays every finished survey of this character's party. Returns how many.
/obj/structure/berth/quay/depot/proc/report_jobs(mob/living/human/H)
	. = 0
	var/party = job_party(H)
	job_refusal = "your party has no finished survey to report here"
	if (!party)
		return
	for (var/obj/craft_contract/land/survey/J in jobs(CONTRACT_TAKEN, party))
		if (!J.done)
			job_refusal = "the stake for the survey [J.far] tiles [J.way] has not been driven in yet"
			continue
		log_game("[key_name(H)] reported a depot survey at [J.spot_x],[J.spot_y],[J.spot_z] ([J.reward_text()]).")
		J.pay(H)
		qdel(J)
		.++

// Takes in the crate of each lost cargo job of this character's party.
/obj/structure/berth/quay/depot/proc/hand_in_cargo(mob/living/human/H)
	. = 0
	var/party = job_party(H)
	job_refusal = "your party has no lost cargo job from this depot"
	if (!party)
		return
	for (var/obj/craft_contract/land/cargo/J in jobs(CONTRACT_TAKEN, party))
		var/obj/structure/closet/crate/K = J.crate()
		if (!K || !isturf(K.loc) || K.z != z || get_dist(K, src) > DEPOT_JOB_REACH)
			job_refusal = K ? "the crate must stand within [DEPOT_JOB_REACH] tiles of the depot" : "that crate is gone: give the job up"
			continue
		// What somebody put in it is theirs: it stays where the crate stood.
		var/turf/T = get_turf(K)
		for (var/atom/movable/A in K)
			A.forceMove(T)
		log_game("[key_name(H)] handed in lost cargo from [J.spot_x],[J.spot_y],[J.spot_z] ([J.reward_text()]).")
		J.pay(H)
		qdel(J)
		.++

// A crew gives a job up: it is struck off, with its stake or crate.
/obj/structure/berth/quay/depot/proc/give_up_job(mob/living/human/H, obj/craft_contract/land/J)
	if (!istype(J) || J.loc != src || J.state != CONTRACT_TAKEN || J.taker_party != job_party(H))
		return FALSE
	qdel(J)
	return TRUE

/obj/structure/berth/quay/depot/proc/job_choices(list/from)
	. = list()
	var/n = 0
	for (var/obj/craft_contract/land/J in from)
		n++
		.["[n]. [J.describe(get_turf(src))]"] = J

/obj/structure/berth/quay/depot/proc/jobs_menu(mob/living/human/H)
	fill_jobs()
	var/party = job_party(H)
	var/list/options = list()
	if (jobs(CONTRACT_OPEN).len)
		options += "Take a job"
	if (party && jobs(CONTRACT_TAKEN, party).len)
		options += list("Report a survey", "Hand in lost cargo", "Give up a job")
	var/choice = WWinput(H, jobs_text(), "Depot work", "Cancel", options + list("Cancel"))
	if (!(choice in options) || QDELETED(src) || get_dist(H, src) > 1)
		return
	switch (choice)
		if ("Take a job")
			var/list/found = job_choices(jobs(CONTRACT_OPEN))
			var/pick = WWinput(H, "Take which job? It goes to your vehicle's party, and you are handed what you need to find the spot.", "Depot work", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/land/J = found[pick]
			if (!istype(J) || QDELETED(J) || QDELETED(src) || get_dist(H, src) > 1)
				return
			if (!take_job(H, J))
				to_chat(H, SPAN_WARNING("You cannot take it: [job_refusal]."))
				return
			log_game("[key_name(H)] took a depot [J.kind] job at [J.spot_x],[J.spot_y],[J.spot_z] for the [J.taker_craft].")
			visible_message(SPAN_NOTICE("[H] takes a [J.kind] job for the [J.taker_craft]."))
		if ("Report a survey")
			var/paid = report_jobs(H)
			if (paid)
				visible_message(SPAN_NOTICE("[H] reports [paid] survey\s and is paid by the depot."))
			else
				to_chat(H, SPAN_WARNING("Nothing is paid: [job_refusal]."))
		if ("Hand in lost cargo")
			var/paid = hand_in_cargo(H)
			if (paid)
				visible_message(SPAN_NOTICE("[H] hands in [paid] crate\s of lost cargo and is paid by the depot."))
			else
				to_chat(H, SPAN_WARNING("Nothing is paid: [job_refusal]."))
		if ("Give up a job")
			var/list/found = job_choices(jobs(CONTRACT_TAKEN, party))
			var/pick = WWinput(H, "Give up which job? It is struck off the board.", "Depot work", "Cancel", found + list("Cancel"))
			var/obj/craft_contract/land/J = found[pick]
			if (istype(J) && !QDELETED(src) && get_dist(H, src) <= 1 && give_up_job(H, J))
				to_chat(H, SPAN_NOTICE("You give the job up."))
