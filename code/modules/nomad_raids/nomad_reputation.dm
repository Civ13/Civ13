// What the nomad clans think of each player, by ckey. Word travels between
// clans, so one score covers raiders and traders alike. Trading and paying
// tribute raise it; theft, striking first and killing traders lower it. It
// fades toward zero by one point per real day. Stored with world.realtime in
// data/nomad_reputation.json, never in the world save.
//
// Effects: trusted players get better prices; distrusted ones pay more;
// wanted players are refused trade, and raiders who meet them attack on sight.

#define NOMAD_REP_FILE "data/nomad_reputation.json"
#define NOMAD_REP_LIMIT 30
#define NOMAD_REP_DAY 864000 // world.realtime deciseconds per day
#define NOMAD_REP_FRIEND 15
#define NOMAD_REP_TRUSTED 5
#define NOMAD_REP_DISTRUSTED -4
#define NOMAD_REP_WANTED -8

var/global/list/nomad_reputation // ckey = list("score", "at", "trades", "tributes", "thefts", "attacks", "kills")

/proc/nomad_rep_weights()
	return list("trade" = 1, "tribute" = 2, "theft" = -4, "attack" = -3, "kill" = -6)

/proc/nomad_rep_load()
	if (islist(nomad_reputation))
		return
	nomad_reputation = list()
	if (!fexists(NOMAD_REP_FILE))
		return
	var/list/data = json_decode(file2text(NOMAD_REP_FILE))
	if (!islist(data))
		return
	for (var/ckey in data)
		var/list/row = data[ckey]
		if (istext(ckey) && islist(row) && isnum(row["score"]) && isnum(row["at"]))
			nomad_reputation[ckey] = row

/proc/nomad_rep_save()
	if (!islist(nomad_reputation))
		return
	var/list/keep = list()
	for (var/ckey in nomad_reputation)
		if (nomad_rep_score(ckey) != 0)
			keep[ckey] = nomad_reputation[ckey]
	nomad_reputation = keep
	fdel(NOMAD_REP_FILE)
	text2file(json_encode(keep), NOMAD_REP_FILE)

// The score after fading toward zero since it last changed.
/proc/nomad_rep_score(ckey)
	nomad_rep_load()
	var/list/row = ckey ? nomad_reputation[ckey] : null
	if (!islist(row))
		return 0
	var/score = row["score"]
	// world.realtime is a float near 1e10, so allow a minute of rounding slack.
	var/faded = max(0, round((world.realtime - row["at"] + 600) / NOMAD_REP_DAY))
	if (score > 0)
		return max(0, score - faded)
	return min(0, score + faded)

/proc/nomad_rep_standing(score)
	if (score >= NOMAD_REP_FRIEND)
		return "friend"
	if (score >= NOMAD_REP_TRUSTED)
		return "trusted"
	if (score <= NOMAD_REP_WANTED)
		return "wanted"
	if (score <= NOMAD_REP_DISTRUSTED)
		return "distrusted"
	return "stranger"

/proc/nomad_rep_record(ckey, what)
	var/list/weights = nomad_rep_weights()
	if (!ckey || !(what in weights))
		return 0
	var/score = clamp(nomad_rep_score(ckey) + weights[what], -NOMAD_REP_LIMIT, NOMAD_REP_LIMIT)
	var/list/row = nomad_reputation[ckey]
	if (!islist(row))
		row = list()
	row["score"] = score
	row["at"] = world.realtime
	row["[what]s"] = (row["[what]s"] || 0) + 1
	nomad_reputation[ckey] = row
	nomad_rep_save()
	return score

// A trader's price for this buyer.
/proc/nomad_rep_price(price, ckey)
	var/score = nomad_rep_score(ckey)
	var/factor = 1
	if (score >= NOMAD_REP_FRIEND)
		factor = 0.75
	else if (score >= NOMAD_REP_TRUSTED)
		factor = 0.9
	else if (score <= NOMAD_REP_DISTRUSTED)
		factor = 1.25
	return max(1, round(price * factor))

// Wanted players near a turf, nearest first.
/proc/nomad_rep_wanted_near(turf/T, radius)
	var/list/out = list()
	for (var/mob/living/human/H in nomad_raid_defenders_near(T, radius))
		if (nomad_rep_score(H.ckey) <= NOMAD_REP_WANTED)
			out += H
	return out

/client/proc/nomad_reputation_verb()
	set category = "Fun"
	set name = "Nomad Reputation"
	if (!check_rights(R_FUN))
		return
	nomad_rep_load()
	var/list/lines = list()
	for (var/ckey in nomad_reputation)
		var/score = nomad_rep_score(ckey)
		if (score)
			lines += "[ckey]: [score] ([nomad_rep_standing(score)])"
	to_chat(src, SPAN_NOTICE(lines.len ? "Nomad reputation:<br>[jointext(lines, "<br>")]" : "No player has a nomad reputation."))
	var/who = player_input(src, "Clear a player's reputation? Enter their ckey, or leave blank.", "Nomad reputation", null, "text", null, TRUE)
	who = ckey(who)
	if (who && nomad_reputation[who])
		nomad_reputation -= who
		nomad_rep_save()
		log_admin("[key_name(src)] cleared the nomad reputation of [who].")
		message_admins("[key_name(src)] cleared the nomad reputation of [who].")
