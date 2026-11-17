// Faction offices and elections (docs/faction-offices.md). A faction's leader
// defines offices (Treasurer, Registrar, Judge, ...), gives each a set of
// powers, and appoints members to them, for a term or until dismissed. A
// member acts for an office while appointed, or while holding an in-force seal
// cut for it (faction_seals.dm), so an office can be lent by handing over its
// seal. The leader holds every power.
//
// Powers: "treasury" (open the strongbox and collect taxes), "registry"
// (register land and manage plots), "seals" (cut and revoke seals), "mint"
// (cut coin dies), "justice" (courts), "papers" (citizenship papers, travel
// passes and border doors), "diplomacy" (treaties) and "works" (unfasten and
// move the hall, stations, charter and strongbox, faction_fixtures.dm). A
// faction that has defined no offices has a Treasurer (treasury) and a
// Registrar (registry).
//
// Elections: the leader can call an election for the leadership or for an
// office. A leader may also set a term; when it has run out, the leadership
// is vacant, or the leader has been away for OFFICE_LEADER_AWAY_DAYS (Val,
// 2026-11-17: an absent leader must not lock the faction out of its mint,
// offices and elections), any member may call a leader election. For ELECTION_TIME members
// may stand as candidates and vote, one vote per account. The most votes wins
// (a tie goes to whoever stood first); an elected leader takes the leadership
// through change_faction_leader(), an elected officer is appointed for the
// faction's term. Elections close on a timer and, after a restart, the next
// time anyone opens the offices.
//
// State in map.faction_recruitment["offices"] (durable, renamed with the
// faction):
//   faction -> list("offices" = list(name = list(power, ...)),
//                   "holders" = list(name = list(account, character name, until or 0)),
//                   "term" = days (0 = none), "leader" = list(account, since),
//                   "election" = null or list(office, closes, list(account = name), list(voter = account)))
// Nothing sleeps except the prompts, which recheck after.

#define OFFICE_NAME_MAX 32
#define OFFICES_PER_FACTION 12
#define OFFICE_TERM_MAX 60 // days
#define OFFICE_DAY 864000
#define ELECTION_TIME 18000 // 30 minutes
#define ELECTION_LEADER "Leader"
#define OFFICE_LEADER_AWAY_DAYS 3

var/global/list/faction_power_labels = list(
	"treasury" = "keep the treasury",
	"registry" = "keep the land register",
	"seals" = "cut and revoke seals",
	"mint" = "cut coin dies",
	"justice" = "hold court",
	"papers" = "issue papers and keep the border",
	"diplomacy" = "make and sign treaties",
	"works" = "move the faction's hall and fixtures")

// --- State -------------------------------------------------------------------

/obj/map_metadata/proc/office_state()
	var/list/S = recruitment_state()
	if (!islist(S["offices"]))
		S["offices"] = list()
	return S["offices"]

/obj/map_metadata/proc/office_record(faction)
	var/list/S = office_state()
	var/list/R = S[faction]
	if (!islist(R))
		R = list()
		S[faction] = R
	if (!islist(R["offices"]))
		R["offices"] = list("Treasurer" = list("treasury"), "Registrar" = list("registry"))
	if (!islist(R["holders"]))
		R["holders"] = list()
	if (!isnum(R["term"]) || R["term"] < 0)
		R["term"] = 0
	return R

/obj/map_metadata/proc/office_normalize()
	var/list/S = office_state()
	for (var/faction in S.Copy())
		if (!istext(faction) || !islist(S[faction]))
			S -= faction
			continue
		var/list/R = office_record(faction)
		R["term"] = min(round(R["term"]), OFFICE_TERM_MAX)
		var/list/offices = R["offices"]
		for (var/name in offices.Copy())
			var/list/powers = offices[name]
			if (!istext(name) || !islist(powers))
				offices -= name
				continue
			for (var/p in powers.Copy())
				if (!(p in faction_power_labels))
					powers -= p
		var/list/holders = R["holders"]
		for (var/name in holders.Copy())
			var/list/row = holders[name]
			if (!(name in offices) || !islist(row) || row.len != 3 || !istext(row[1]) || !istext(row[2]) || !isnum(row[3]))
				holders -= name
		var/list/leader = R["leader"]
		if (!isnull(leader) && (!islist(leader) || leader.len != 2 || !istext(leader[1]) || !isnum(leader[2])))
			R -= "leader"
		var/list/E = R["election"]
		if (!isnull(E) && !office_election_valid(E, offices))
			R -= "election"

/proc/office_election_valid(list/E, list/offices)
	if (!islist(E) || E.len != 4 || !istext(E[1]) || !isnum(E[2]) || !islist(E[3]) || !islist(E[4]))
		return FALSE
	return E[1] == ELECTION_LEADER || (E[1] in offices)

/obj/map_metadata/proc/office_rename(old_name, new_name)
	faction_rename_assoc_key(office_state(), old_name, new_name)

/proc/office_name_clean(value)
	if (!istext(value))
		return ""
	var/clean = faction_seal_office_clean(value)
	if (!length(clean) || length(clean) > OFFICE_NAME_MAX || lowertext(clean) == lowertext(ELECTION_LEADER))
		return ""
	return clean

// The office's real name in the record, matched without regard to case.
/obj/map_metadata/proc/office_find(faction, name)
	if (!istext(name))
		return null
	var/list/R = office_record(faction)
	var/list/offices = R["offices"]
	for (var/office in offices)
		if (lowertext(office) == lowertext(name))
			return office
	return null

/obj/map_metadata/proc/office_has_power(faction, office, power)
	office = office_find(faction, office)
	if (!office)
		return FALSE
	var/list/R = office_record(faction)
	var/list/powers = R["offices"][office]
	return islist(powers) && (power in powers)

// The office's holder row if the appointment is still in force, else null.
/obj/map_metadata/proc/office_holder_row(faction, office)
	var/list/R = office_record(faction)
	var/list/row = R["holders"][office]
	if (!islist(row) || row.len != 3)
		return null
	if (row[3] && recruitment_now() > row[3])
		return null
	return row

// --- Powers ------------------------------------------------------------------------

// Whether H may act for faction with power: the leader; a member appointed to
// an office with the power; or anyone holding an in-force seal of the faction
// cut for such an office.
/obj/map_metadata/proc/faction_power(mob/living/human/H, faction, power)
	if (!istype(H) || H.stat != CONSCIOUS || !istext(faction) || !length(faction) || faction == "none")
		return FALSE
	if (H.civilization == faction && is_faction_leader(H, faction))
		return TRUE
	var/list/R = office_record(faction)
	var/list/offices = R["offices"]
	if (H.civilization == faction)
		var/account = faction_roster_account(H)
		if (account)
			for (var/office in offices)
				if (!(power in offices[office]))
					continue
				var/list/row = office_holder_row(faction, office)
				if (row && row[1] == account)
					return TRUE
	for (var/obj/item/weapon/stamp/faction_seal/S in list(H.get_active_hand(), H.get_inactive_hand()))
		if (S.seal_faction != faction || !office_has_power(faction, S.seal_office, power))
			continue
		var/list/row = faction_seal_row(faction, S.seal_serial)
		if (row && !row[3])
			return TRUE
	return FALSE

// The offices H holds by appointment, for display.
/obj/map_metadata/proc/offices_held(mob/living/human/H)
	var/list/held = list()
	if (!istype(H) || !H.civilization || H.civilization == "none")
		return held
	var/account = faction_roster_account(H)
	var/list/R = office_record(H.civilization)
	for (var/office in R["offices"])
		var/list/row = office_holder_row(H.civilization, office)
		if (row && row[1] == account)
			held += office
	return held

/obj/map_metadata/proc/office_appoint(faction, office, account, name, days)
	office = office_find(faction, office)
	if (!office || !istext(account) || !length(account))
		return FALSE
	var/list/R = office_record(faction)
	days = clamp(round(days), 0, OFFICE_TERM_MAX)
	R["holders"][office] = list(account, istext(name) ? name : "", days ? recruitment_now() + days * OFFICE_DAY : 0)
	return TRUE

// --- Leader terms ---------------------------------------------------------------------

/proc/office_leader_mob(faction)
	if (!map)
		return null
	var/list/civ = map.faction_leader_record(faction)
	var/mob/living/human/L = civ ? civ[4] : null
	if (!istype(L) || QDELETED(L) || L.stat == DEAD || L.civilization != faction)
		return null
	return L

// Notes when the leadership changes hands and returns when it began.
/obj/map_metadata/proc/office_leader_since(faction)
	var/list/R = office_record(faction)
	var/mob/living/human/L = office_leader_mob(faction)
	var/account = L ? faction_roster_account(L) : ""
	var/list/row = R["leader"]
	if (!islist(row) || row[1] != account)
		row = list(account || "", recruitment_now())
		R["leader"] = row
	return row[2]

// TRUE when any member may call a leader election: the seat is empty, the
// leader's term has run out, or the leader has been away too long.
/obj/map_metadata/proc/office_leader_open(faction)
	if (!office_leader_mob(faction))
		return TRUE
	if (office_leader_away(faction))
		return TRUE
	var/list/R = office_record(faction)
	return R["term"] > 0 && recruitment_now() - office_leader_since(faction) > R["term"] * OFFICE_DAY

// TRUE when the leader is not playing and has not played for
// OFFICE_LEADER_AWAY_DAYS. Last played is the account's roster row
// (faction_roster.dm, touched on every login); without one, it is when the
// leadership began. A leader who is connected is never away.
/obj/map_metadata/proc/office_leader_away(faction)
	var/mob/living/human/L = office_leader_mob(faction)
	if (!L || L.client)
		return FALSE
	var/seen = 0
	var/account = faction_roster_account(L)
	var/list/rosters = faction_rosters()
	var/list/roster = rosters[faction]
	if (account && islist(roster))
		var/list/row = roster[account]
		if (islist(row) && row.len == 2 && isnum(row[2]))
			seen = row[2]
	if (!seen)
		seen = office_leader_since(faction)
	return recruitment_now() - seen > OFFICE_LEADER_AWAY_DAYS * OFFICE_DAY

// --- Elections -------------------------------------------------------------------------

/obj/map_metadata/proc/office_election(faction)
	var/list/R = office_record(faction)
	var/list/E = R["election"]
	if (!office_election_valid(E, R["offices"]))
		return null
	if (recruitment_now() >= E[2])
		office_election_close(faction)
		return null
	return E

/obj/map_metadata/proc/office_election_open(faction, office)
	var/list/R = office_record(faction)
	if (office_election(faction))
		return FALSE
	if (office != ELECTION_LEADER)
		office = office_find(faction, office)
		if (!office)
			return FALSE
	var/list/E = list(office, recruitment_now() + ELECTION_TIME, list(), list())
	R["election"] = E
	addtimer(CALLBACK(src, PROC_REF(office_election_due), faction, E[2]), ELECTION_TIME + 10)
	office_announce(faction, "An election for [office == ELECTION_LEADER ? "the leadership" : "the office of [office]"] of [faction] is open for 30 minutes. Use Faction Offices to stand or vote.")
	return TRUE

/obj/map_metadata/proc/office_election_due(faction, closes)
	var/list/R = office_record(faction)
	var/list/E = R["election"]
	if (office_election_valid(E, R["offices"]) && E[2] == closes)
		office_election_close(faction)

/obj/map_metadata/proc/office_stand(faction, account, name)
	var/list/E = office_election(faction)
	if (!E || !istext(account) || (account in E[3]))
		return FALSE
	E[3][account] = name
	return TRUE

/obj/map_metadata/proc/office_vote(faction, voter, candidate)
	var/list/E = office_election(faction)
	if (!E || !istext(voter) || (voter in E[4]) || !(candidate in E[3]))
		return FALSE
	E[4][voter] = candidate
	return TRUE

// Candidate account -> votes, in the order they stood.
/proc/office_election_count(list/E)
	var/list/count = list()
	for (var/account in E[3])
		count[account] = 0
	for (var/voter in E[4])
		var/choice = E[4][voter]
		if (choice in count)
			count[choice]++
	return count

/proc/office_find_member(faction, account)
	for (var/mob/living/human/M in human_mob_list)
		if (!QDELETED(M) && M.stat != DEAD && M.civilization == faction && faction_roster_account(M) == account)
			return M
	return null

/obj/map_metadata/proc/office_election_close(faction)
	var/list/R = office_record(faction)
	var/list/E = R["election"]
	R -= "election"
	if (!office_election_valid(E, R["offices"]))
		return null
	var/list/count = office_election_count(E)
	var/winner = null
	var/best = 0
	for (var/account in count)
		if (count[account] > best)
			best = count[account]
			winner = account
	var/what = E[1] == ELECTION_LEADER ? "the leadership" : "the office of [E[1]]"
	if (!winner)
		office_announce(faction, "The election for [what] of [faction] closed without a vote cast for anyone.")
		return null
	var/winner_name = E[3][winner]
	if (E[1] == ELECTION_LEADER)
		var/mob/living/human/W = office_find_member(faction, winner)
		if (!W)
			office_announce(faction, "[winner_name] won the election for [what] of [faction], but is no longer a living member. Nothing changes.")
			return null
		var/mob/living/human/previous = office_leader_mob(faction)
		if (!previous)
			var/list/civ = faction_leader_record(faction)
			if (civ && civ[4])
				clear_faction_leader(civ[4], faction)
		if (W != previous && !change_faction_leader(faction, previous, W))
			office_announce(faction, "[winner_name] won the election for [what] of [faction], but the leadership could not change hands.")
			return null
		R["leader"] = list(winner, recruitment_now())
	else
		office_appoint(faction, E[1], winner, winner_name, R["term"])
	office_announce(faction, "[winner_name] won the election for [what] of [faction] with [best] vote[best == 1 ? "" : "s"].")
	log_game("[faction] elected [winner_name] ([winner]) to [what] with [best] votes.")
	return winner

/obj/map_metadata/proc/office_announce(faction, text)
	for (var/mob/living/human/M in human_mob_list)
		if (M.client && M.civilization == faction)
			to_chat(M, SPAN_NOTICE("<b>[text]</b>"))

// --- Faction Offices verb ------------------------------------------------------------------

/proc/office_list_text(faction)
	var/list/R = map.office_record(faction)
	var/list/lines = list("<b>Offices of [faction]</b>")
	var/mob/living/human/L = office_leader_mob(faction)
	lines += "Leader: [L ? L.real_name : "vacant"][R["term"] ? ", elected for [R["term"]] days at a time" : ""][map.office_leader_away(faction) ? ", away for over [OFFICE_LEADER_AWAY_DAYS] days, so any member may call a leader election" : ""]."
	for (var/office in R["offices"])
		var/list/powers = list()
		for (var/p in R["offices"][office])
			powers += faction_power_labels[p]
		var/list/row = map.office_holder_row(faction, office)
		var/holder = row ? "[row[2]][row[3] ? " (until [faction_seal_date(row[3])])" : ""]" : "vacant"
		lines += "[office]: [holder]. May [powers.len ? jointext(powers, ", ") : "do nothing yet"]."
	var/list/E = map.office_election(faction)
	if (E)
		var/list/count = office_election_count(E)
		var/list/standing = list()
		for (var/account in count)
			standing += "[E[3][account]] ([count[account]])"
		lines += "Election for [E[1] == ELECTION_LEADER ? "the leadership" : E[1]], closing [faction_seal_date(E[2])]: [standing.len ? jointext(standing, ", ") : "no candidates yet"]."
	return SPAN_NOTICE(jointext(lines, "<br>"))

/mob/living/human/proc/faction_offices()
	set name = "Faction Offices"
	set category = "Faction"
	var/faction = civilization
	if (!map || !faction || faction == "none")
		to_chat(src, SPAN_NOTICE("You belong to no faction."))
		return
	var/leader = map.is_faction_leader(src, faction)
	var/account = faction_roster_account(src)
	var/list/E = map.office_election(faction)
	var/list/choices = list("List the offices")
	if (E && account)
		if (!(account in E[3]))
			choices += "Stand as a candidate"
		if (!(account in E[4]) && length(E[3]))
			choices += "Vote"
	if (!E && (leader || map.office_leader_open(faction)))
		choices += "Call an election"
	if (leader)
		choices += list("Create an office", "Change an office's powers", "Abolish an office", "Appoint to an office", "Dismiss from an office", "Set the term")
	choices += "Cancel"
	var/choice = WWinput(src, "Offices of [faction]", "Faction offices", "List the offices", choices)
	if (!choice || choice == "Cancel" || !(choice in choices) || civilization != faction || stat == DEAD)
		return
	if (choice in list("Create an office", "Change an office's powers", "Abolish an office", "Appoint to an office", "Dismiss from an office", "Set the term"))
		if (!map.is_faction_leader(src, faction))
			return
	switch (choice)
		if ("List the offices")
			to_chat(src, office_list_text(faction))
		if ("Stand as a candidate")
			if (map.office_stand(faction, account, real_name))
				map.office_announce(faction, "[real_name] stands in the election.")
		if ("Vote")
			E = map.office_election(faction)
			if (!E)
				return
			var/list/options = list()
			for (var/candidate in E[3])
				options[E[3][candidate]] = candidate
			var/pick = WWinput(src, "Vote for whom? You have one vote.", "Vote", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options) || civilization != faction)
				return
			if (map.office_vote(faction, account, options[pick]))
				to_chat(src, SPAN_NOTICE("You vote for [pick]."))
		if ("Call an election")
			var/list/options = list()
			if (map.is_faction_leader(src, faction) || map.office_leader_open(faction))
				options += ELECTION_LEADER
			if (map.is_faction_leader(src, faction))
				var/list/R = map.office_record(faction)
				for (var/office in R["offices"])
					options += office
			var/pick = WWinput(src, "Elect whom?", "Election", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options))
				return
			if (!(map.is_faction_leader(src, faction) || (pick == ELECTION_LEADER && map.office_leader_open(faction))))
				return
			if (map.office_election_open(faction, pick))
				log_game("[key_name(src)] called an election for [pick] in [faction].")
		if ("Create an office")
			var/list/R = map.office_record(faction)
			if (length(R["offices"]) >= OFFICES_PER_FACTION)
				to_chat(src, SPAN_WARNING("[faction] already has [OFFICES_PER_FACTION] offices."))
				return
			var/name = office_name_clean(player_input(src, "Name the office (for example Treasurer, Registrar, Judge, Herald):", "New office", "", "text", null, TRUE))
			if (!length(name) || !map.is_faction_leader(src, faction))
				return
			if (map.office_find(faction, name))
				to_chat(src, SPAN_WARNING("There is already an office of [name]."))
				return
			R["offices"][name] = list()
			office_pick_powers(faction, name)
		if ("Change an office's powers")
			var/office = office_pick(faction, "Which office?")
			if (office)
				office_pick_powers(faction, office)
		if ("Abolish an office")
			var/office = office_pick(faction, "Abolish which office? Its holder loses it, and its seals lose their powers.")
			if (!office || !map.is_faction_leader(src, faction))
				return
			var/list/R = map.office_record(faction)
			R["offices"] -= office
			R["holders"] -= office
			to_chat(src, SPAN_NOTICE("The office of [office] is abolished."))
		if ("Appoint to an office")
			var/office = office_pick(faction, "Appoint to which office?")
			if (!office)
				return
			var/list/members = list()
			for (var/mob/living/human/M in human_mob_list)
				if (M.civilization == faction && M.stat != DEAD && M.client && faction_roster_account(M))
					members[M.real_name] = M
			var/pick = WWinput(src, "Appoint whom as [office]?", "Appoint", "Cancel", members + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in members))
				return
			var/days = player_input(src, "For how many days (0 for no term, up to [OFFICE_TERM_MAX])?", "Appoint", 0, "num", null, TRUE)
			var/mob/living/human/M = members[pick]
			if (!isnum(days) || QDELETED(M) || M.civilization != faction || !map.is_faction_leader(src, faction))
				return
			if (map.office_appoint(faction, office, faction_roster_account(M), M.real_name, days))
				map.office_announce(faction, "[M.real_name] is appointed [office].")
		if ("Dismiss from an office")
			var/office = office_pick(faction, "Dismiss the holder of which office?")
			if (!office || !map.is_faction_leader(src, faction))
				return
			var/list/R = map.office_record(faction)
			var/list/row = R["holders"][office]
			R["holders"] -= office
			if (islist(row))
				map.office_announce(faction, "[row[2]] is dismissed as [office].")
		if ("Set the term")
			var/list/R = map.office_record(faction)
			var/days = player_input(src, "How many days should the leader and elected officers serve before members may call a new election? (0 for no term, up to [OFFICE_TERM_MAX])", "Term", R["term"], "num", null, TRUE)
			if (!isnum(days) || !map.is_faction_leader(src, faction))
				return
			R["term"] = clamp(round(days), 0, OFFICE_TERM_MAX)
			map.office_leader_since(faction)
			to_chat(src, SPAN_NOTICE(R["term"] ? "Terms now last [R["term"]] days." : "Terms no longer run out."))

/mob/living/human/proc/office_pick(faction, question)
	var/list/R = map.office_record(faction)
	var/list/offices = list()
	for (var/office in R["offices"])
		offices += office
	if (!offices.len)
		to_chat(src, SPAN_NOTICE("[faction] has no offices."))
		return null
	var/pick = WWinput(src, question, "Offices", "Cancel", offices + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in offices) || !map.is_faction_leader(src, faction) || !map.office_find(faction, pick))
		return null
	return pick

// Toggles powers on an office until the leader picks Done.
/mob/living/human/proc/office_pick_powers(faction, office)
	for (var/i in 1 to faction_power_labels.len + 1)
		var/list/R = map.office_record(faction)
		var/list/powers = R["offices"][office]
		if (!islist(powers) || !map.is_faction_leader(src, faction))
			return
		var/list/options = list()
		for (var/p in faction_power_labels)
			options["[(p in powers) ? "Remove" : "Add"]: [faction_power_labels[p]]"] = p
		var/pick = WWinput(src, "Powers of [office]: [powers.len ? jointext(powers, ", ") : "none"].", "Office powers", "Done", options + "Done")
		if (!pick || pick == "Done" || !(pick in options))
			return
		powers = R["offices"][office]
		if (!islist(powers) || !map.is_faction_leader(src, faction))
			return
		var/p = options[pick]
		if (p in powers)
			powers -= p
		else
			powers += p

#undef OFFICE_NAME_MAX
#undef OFFICES_PER_FACTION
#undef OFFICE_TERM_MAX
#undef OFFICE_DAY
#undef ELECTION_TIME
#undef ELECTION_LEADER
#undef OFFICE_LEADER_AWAY_DAYS
