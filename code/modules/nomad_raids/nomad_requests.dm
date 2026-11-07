// Calling a caravan by telegraph (docs/nomad-raids.md#calling-a-caravan).
//
// On a nomads map, a player at a telegraph wired to a line can send one of the
// words in nomad_request_words(): CARAVAN or TRADERS for any goods, or a kind
// of goods such as MEDICINE or SEEDS. The clans answer COMING on the same
// telegraph, and a few minutes later a caravan walks in toward the telegraph
// with at least half its stall of the kind asked for. The wire is not private:
// sometimes raiders answer instead, with the same reply. Each player may call
// once an hour, and only while no other visit is running or on its way.

#define NOMAD_REQUEST_COOLDOWN 36000 // world.realtime, one hour per caller
#define NOMAD_REQUEST_RAID_CHANCE 20 // percent; halved for friends of the clans
#define NOMAD_REQUEST_DELAY_MIN (1 MINUTE)
#define NOMAD_REQUEST_DELAY_MAX (3 MINUTES)

var/global/list/nomad_request_last = list() // ckey = world.realtime of their last call
var/global/nomad_request_pending = FALSE // a called visit is on its way

// Telegraph word = what is wanted ("any" for a general caravan).
/proc/nomad_request_words()
	return list(
		"CARAVAN" = "any", "TRADERS" = "any", "TRADER" = "any", "TRADE" = "any",
		"MEDICINE" = "medicine", "MEDS" = "medicine",
		"SEEDS" = "seeds",
		"FOOD" = "food",
		"METAL" = "metal",
		"CLOTH" = "cloth",
		"TOOLS" = "tools",
	)

// Goods of a requested kind for the age; empty for "any".
/proc/nomad_request_goods(want, age)
	var/list/out = list()
	switch (want)
		if ("medicine")
			out += /obj/item/stack/medical/bruise_pack/bint
			if (age >= 6)
				out += list(/obj/item/weapon/reagent_containers/pill/penicillin, /obj/item/weapon/reagent_containers/pill/paracetamol)
		if ("seeds")
			out += list(/obj/item/stack/farming/seeds/tea, /obj/item/stack/farming/seeds/potato, /obj/item/stack/farming/seeds/cabbage, /obj/item/stack/farming/seeds/carrot, /obj/item/stack/farming/seeds/beans, /obj/item/stack/farming/seeds/herbs, /obj/item/stack/farming/seeds/flax, /obj/item/stack/farming/seeds/cotton)
		if ("food")
			out += list(/obj/item/weapon/reagent_containers/food/snacks/meat, /obj/item/stack/farming/seeds/potato)
		if ("metal")
			out += /obj/item/stack/material/bronze
			if (age >= 2)
				out += /obj/item/stack/material/iron
		if ("cloth")
			out += list(/obj/item/stack/material/cloth, /obj/item/stack/material/leather, /obj/item/stack/material/pelt)
		if ("tools")
			out += /obj/item/stack/material/rope
			if (age >= 2)
				out += /obj/item/weapon/material/kitchen/utensil/knife/iron
	return out

// Whether a call is answered by raiders: more likely the less the clans trust the caller.
/proc/nomad_request_raid_roll(ckey)
	var/score = nomad_rep_score(ckey)
	if (score <= NOMAD_REP_WANTED)
		return TRUE // traders will not deal with them; raiders will come
	var/chance = NOMAD_REQUEST_RAID_CHANCE
	if (score >= NOMAD_REP_FRIEND)
		chance = round(chance / 2)
	return prob(chance)

// A call from a telegraph. Returns the word wired back, or null when the word
// is not a request. Never sleeps; the visit starts after a delay.
/proc/nomad_caravan_request(turf/T, ckey, word)
	if (!map || !map.nomads || !T || !istext(word))
		return null
	var/want = nomad_request_words()[uppertext(word)]
	if (!want)
		return null
	if (!istext(ckey) || !length(ckey))
		return null
	if (nomad_raid || nomad_request_pending)
		return "BUSY"
	var/last = nomad_request_last[ckey]
	if (isnum(last) && world.realtime - last < NOMAD_REQUEST_COOLDOWN)
		return "LATER"
	nomad_request_last[ckey] = world.realtime
	nomad_request_pending = TRUE
	var/raid = nomad_request_raid_roll(ckey)
	log_game("Nomad request: [ckey] asked for a [want] caravan by telegraph at [T.x],[T.y],[T.z]; [raid ? "raiders" : "traders"] will answer.")
	message_admins("Nomad request: [ckey] asked for a [want] caravan by telegraph at [T.x],[T.y],[T.z]; [raid ? "raiders" : "traders"] will answer.")
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(nomad_request_arrive), T, ckey, want, raid), rand(NOMAD_REQUEST_DELAY_MIN, NOMAD_REQUEST_DELAY_MAX))
	return "COMING"

// The called visit sets off toward the telegraph. Returns null or why not.
/proc/nomad_request_arrive(turf/T, ckey, want, raid)
	nomad_request_pending = FALSE
	var/list/ckeys = list()
	for (var/mob/living/human/H in nomad_raid_defenders_near(T))
		ckeys += H.ckey
	if (!(ckey in ckeys))
		ckeys += ckey // the caller is expected, even if they stepped away
	var/error = start_nomad_raid(T, ckeys, raid ? 4 : 2, "a telegraph call by [ckey] for [want]", raid ? "raid" : "trade", want == "any" ? null : want)
	if (error)
		log_game("Nomad request by [ckey] could not start: [error].")
	return error

// The telegraph hook: wired telegraphs only, and the reply comes back down the wire.
/obj/structure/telegraph/proc/nomad_request(mob/user, word)
	if (!user || !user.ckey || !(locate(/obj/structure/phoneline) in range(2, src)))
		return
	var/reply = nomad_caravan_request(get_turf(src), user.ckey, word)
	if (!reply)
		return
	addtimer(CALLBACK(src, PROC_REF(nomad_reply), reply), 3 SECONDS)

/obj/structure/telegraph/proc/nomad_reply(reply)
	receive("<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] Nomad clans:</b></font> \"...[reply]...\"", reply)

#undef NOMAD_REQUEST_DELAY_MIN
#undef NOMAD_REQUEST_DELAY_MAX
