// Defence windows and sieges (docs/provinces.md, "Sieges"). Reviewed by Fable.
// A clear objective for defenders, and offline time zones stay safe.
//
// - Each held province has a daily defence window of SIEGE_WINDOW_HOURS hours
//   (one more when the side holds two or more provinces of this land). Its
//   leader picks the start among the server's SIEGE_BUSY_HOURS busiest hours
//   (Faction > Defence Window); a change waits SIEGE_WINDOW_DELAY_HOURS and
//   none is allowed while a siege is declared. Until one is picked, the
//   busiest hour is the start.
// - Outside the window nothing changes who holds the province: a take or a
//   loss that falls due waits for the window (province_holding.dm).
// - To besiege, a rival faction at least SIEGE_FACTION_DAYS days old, with
//   SIEGE_ACCOUNTS members who have played SIEGE_PLAY_MINUTES on this land,
//   plants a war banner in the province and declares at it. The siege starts
//   with the first window at least SIEGE_NOTICE_HOURS later. It needs
//   SIEGE_DEPOSIT silver in its strongbox: kept if the attackers show up,
//   spent if nobody comes. A province below Town rank on Gaia cannot be
//   besieged.
// - In the window the attackers capture the seat by standing within
//   SIEGE_SEAT_RANGE tiles of it for 10 / 15 / 20 / 30 minutes (Camp to City;
//   10 unranked). The count pauses while a connected defender stands there.
// - Success suspends one rank's benefits for 7 days and makes the province
//   immune to sieges for 3. At Camp or below, or on the same rival's second
//   success within 14 days, it also starts the holder's loss warning. A failed
//   or cancelled siege (the banner destroyed) keeps that attacker from
//   declaring here for 3 days.
//
// State: map.faction_recruitment["province_sieges"]: char -> list("window",
// "next_window", "next_from", "siege", "immune", "suspended", "wins",
// "cooldown"); ["province_hours"]: 24 average player counts by hour.
// Ticks every SIEGE_TICK only while a siege is declared. Nothing sleeps
// except the declaration prompts, which recheck.

#define SIEGE_WINDOW_HOURS 3
#define SIEGE_BUSY_HOURS 8
#define SIEGE_WINDOW_DELAY_HOURS 72
#define SIEGE_FACTION_DAYS 7
#define SIEGE_ACCOUNTS 4
#define SIEGE_PLAY_MINUTES 120
#define SIEGE_NOTICE_HOURS 24
#define SIEGE_DEPOSIT 100
#define SIEGE_SEAT_RANGE 3
#define SIEGE_TICK 100
#define SIEGE_SUSPEND_DAYS 7
#define SIEGE_IMMUNE_DAYS 3
#define SIEGE_REPEAT_DAYS 14
#define SIEGE_COOLDOWN_DAYS 3

var/global/province_siege_timer = null

// --- Hours ----------------------------------------------------------------------

/proc/province_hour_now()
	return round(world.realtime / 36000) % 24

// Called with each activity count: a slow average of players by hour.
/proc/province_hours_record(count)
	var/list/S = map.recruitment_state()
	var/list/H = S["province_hours"]
	if (!islist(H) || H.len != 24)
		H = list()
		for (var/i in 1 to 24)
			H += 0
		S["province_hours"] = H
	var/i = province_hour_now() + 1
	H[i] = round(H[i] * 0.97 + count * 0.03, 0.01)

// The SIEGE_BUSY_HOURS busiest starting hours (0-23), busiest first.
/proc/province_busy_hours()
	var/list/S = map.recruitment_state()
	var/list/H = S["province_hours"]
	H = islist(H) && H.len == 24 ? H.Copy() : null
	var/list/out = list()
	if (!H)
		for (var/h in 18 to 23)
			out += h
		out += 0
		out += 1
		return out
	while (out.len < SIEGE_BUSY_HOURS)
		var/best = 0
		for (var/i in 1 to 24)
			if (!((i - 1) in out) && (!best || H[i] > H[best]))
				best = i
		out += best - 1
	return out

// --- State --------------------------------------------------------------------------

/proc/province_siege_row(c)
	var/list/S = map.recruitment_state()
	if (!islist(S["province_sieges"]))
		S["province_sieges"] = list()
	var/list/all = S["province_sieges"]
	var/list/row = all[c]
	if (!islist(row))
		row = list("window" = null, "next_window" = null, "next_from" = 0, "siege" = null, "immune" = 0, "suspended" = 0, "wins" = list(), "cooldown" = list())
		all[c] = row
	if (!islist(row["wins"]))
		row["wins"] = list()
	if (!islist(row["cooldown"]))
		row["cooldown"] = list()
	return row

/proc/province_window_start(c)
	var/list/row = province_siege_row(c)
	if (isnum(row["next_window"]) && isnum(row["next_from"]) && world.realtime >= row["next_from"])
		row["window"] = row["next_window"]
		row["next_window"] = null
		row["next_from"] = 0
	if (isnum(row["window"]))
		return row["window"]
	var/list/busy = province_busy_hours()
	return busy[1]

/proc/province_window_length(c)
	var/holder = province_holder_of(c)
	return SIEGE_WINDOW_HOURS + (holder && province_holdings_count(holder) >= 2 ? 1 : 0)

/proc/province_in_window(c)
	return (province_hour_now() - province_window_start(c) + 24) % 24 < province_window_length(c)

/proc/province_window_text(c)
	var/start = province_window_start(c)
	var/list/row = province_siege_row(c)
	var/text = "Defence window: [start]:00 to [(start + province_window_length(c)) % 24]:00 server time (UTC) daily[province_in_window(c) ? ", open now" : ""]."
	if (isnum(row["next_window"]))
		text += " It moves to [row["next_window"]]:00 in [max(0, round((row["next_from"] - world.realtime) / 36000))] hours."
	return text

// The rank whose benefits apply now: one lower for SIEGE_SUSPEND_DAYS after a siege.
/proc/province_rank_effective(c)
	var/rank = province_rank_of(c)
	var/list/S = map ? map.recruitment_state()["province_sieges"] : null
	var/list/row = islist(S) ? S[c] : null
	if (rank && islist(row) && isnum(row["suspended"]) && world.realtime < row["suspended"])
		rank--
	return rank

// --- Choosing the window -----------------------------------------------------------

/mob/living/human/proc/province_defence_window()
	set category = "Faction"
	set name = "Defence Window"
	set desc = "Choose the daily hours when your side's provinces can be besieged."
	if (!map || !map.province_map() || !civilization || civilization == "none" || !map.is_faction_leader(src, civilization))
		to_chat(src, SPAN_WARNING("Only a faction leader on a land with provinces can set a defence window."))
		return
	var/datum/province_map/P = map.province_map()
	var/group = province_group_of(civilization)
	var/list/choices = list()
	for (var/c in P.names)
		if (province_holder_of(c) == group)
			choices["[P.names[c]] ([province_window_start(c)]:00)"] = c
	if (!choices.len)
		to_chat(src, SPAN_WARNING("Your side holds no province here."))
		return
	var/pick = WWinput(src, "Which province's defence window?", "Defence Window", choices[1], choices)
	var/c = choices[pick]
	if (!c)
		return
	var/list/hours = list()
	for (var/h in province_busy_hours())
		hours += "[h]:00"
	var/hour = WWinput(src, "Start the daily [province_window_length(c)]-hour window at (server time, UTC; the server's busiest hours):", "Defence Window", hours[1], hours)
	if (!hour || !map.is_faction_leader(src, civilization) || province_holder_of(c) != province_group_of(civilization))
		return
	var/list/row = province_siege_row(c)
	if (islist(row["siege"]))
		to_chat(src, SPAN_WARNING("A siege is declared on the [P.names[c]]; its window cannot change until it ends."))
		return
	var/h = text2num(copytext(hour, 1, findtext(hour, ":")))
	if (!isnum(h) || !(h in province_busy_hours()))
		return
	if (!isnum(row["window"]))
		row["window"] = h
		to_chat(src, SPAN_NOTICE("The [P.names[c]]'s defence window now starts at [h]:00."))
	else
		row["next_window"] = h
		row["next_from"] = world.realtime + SIEGE_WINDOW_DELAY_HOURS * 36000
		to_chat(src, SPAN_NOTICE("The [P.names[c]]'s defence window moves to [h]:00 in [SIEGE_WINDOW_DELAY_HOURS] hours."))
	map.recruitment_audit(civilization, "[real_name] set the [P.names[c]]'s defence window to start at [h]:00.", faction_roster_account(src) || "")

// --- Declaring ------------------------------------------------------------------------

// The faction's age here, from its earliest roster entry.
/proc/province_faction_age_days(faction)
	var/list/roster = map.faction_rosters()[faction]
	if (!islist(roster))
		return 0
	var/first = world.realtime
	for (var/account in roster)
		var/list/row = roster[account]
		if (islist(row) && row.len == 2 && isnum(row[1]))
			first = min(first, row[1])
	return (world.realtime - first) / 864000

// Why faction cannot declare a siege on province c now, or null.
/proc/province_siege_block(faction, c)
	if (!map || !map.province_map() || !c)
		return "The banner must stand in a province."
	var/datum/province_map/P = map.province_map()
	var/holder = province_holder_of(c)
	var/group = province_group_of(faction)
	if (!holder)
		return "Nobody holds the [P.names[c]]: lead it in stake to take it."
	if (holder == group)
		return "Your own side holds the [P.names[c]]."
	var/list/row = province_siege_row(c)
	if (islist(row["siege"]))
		return "A siege is already declared on the [P.names[c]]."
	if (isnum(row["immune"]) && world.realtime < row["immune"])
		return "The [P.names[c]] was besieged lately and cannot be again for [round((row["immune"] - world.realtime) / 36000)] hours."
	var/list/cooldown = row["cooldown"]
	if (isnum(cooldown[group]) && world.realtime < cooldown[group])
		return "Your side's last siege here failed; wait [round((cooldown[group] - world.realtime) / 36000)] hours."
	if (map.ID == MAP_NOMADS_GAIA && province_rank_of(c) < 3)
		return "On Gaia only a Town or City can be besieged."
	if (province_faction_age_days(faction) < SIEGE_FACTION_DAYS)
		return "[faction] must be [SIEGE_FACTION_DAYS] days old to declare a siege."
	var/players = 0
	for (var/account in map.faction_roster(faction))
		var/list/A = province_activity_of(account)
		if (A[1] >= SIEGE_PLAY_MINUTES)
			players++
	if (players < SIEGE_ACCOUNTS)
		return "[faction] needs [SIEGE_ACCOUNTS] members who have played [SIEGE_PLAY_MINUTES / 60] hours on this land (it has [players])."
	var/obj/structure/closet/crate/faction_strongbox/B = map.faction_strongbox(faction)
	if (!B || B.coin_worth() < SIEGE_DEPOSIT)
		return "[faction]'s strongbox must hold [SIEGE_DEPOSIT] silver as the siege deposit."
	return null

/obj/structure/war_banner
	name = "war banner"
	desc = "A banner planted to declare a siege. A faction's leader declares at it against the side holding this province."
	icon = 'icons/obj/banners.dmi'
	icon_state = "banner_b"
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	var/faction = null // the faction that declared here; faction_rename.dm rewrites it

/obj/structure/war_banner/Destroy()
	province_siege_banner_lost(src)
	return ..()

/obj/structure/war_banner/examine(mob/user)
	..()
	var/datum/province_map/P = map ? map.province_map() : null
	var/c = P ? P.char_at(x, y) : null
	if (!c)
		to_chat(user, "It stands in no province.")
		return
	to_chat(user, province_siege_text(c))

/obj/structure/war_banner/attack_hand(mob/living/human/user)
	if (!ishuman(user))
		return ..()
	examine(user)
	var/datum/province_map/P = map ? map.province_map() : null
	var/c = P && isturf(loc) ? P.char_at(x, y) : null
	if (faction || !c || !user.civilization || user.civilization == "none" || !map.is_faction_leader(user, user.civilization))
		return
	var/block = province_siege_block(user.civilization, c)
	if (block)
		to_chat(user, SPAN_WARNING(block))
		return
	if (WWinput(user, "Declare a siege on the [P.names[c]] for [user.civilization]? It starts in its holder's first defence window at least [SIEGE_NOTICE_HOURS] hours from now. [SIEGE_DEPOSIT] silver in your strongbox is spent if nobody comes.", "War Banner", "Cancel", list("Declare the siege", "Cancel")) != "Declare the siege")
		return
	if (faction || QDELETED(src) || get_dist(user, src) > 1 || user.stat || !map.is_faction_leader(user, user.civilization) || province_siege_block(user.civilization, c))
		return
	faction = user.civilization
	name = "[faction] war banner"
	var/list/row = province_siege_row(c)
	var/group = province_group_of(faction)
	row["siege"] = list("group" = group, "faction" = faction, "declared" = world.realtime, "x" = x, "y" = y, "z" = z, "progress" = 0, "shown" = FALSE, "live" = FALSE)
	var/holder = province_holder_of(c)
	province_tell_leaders(holder, "[faction] has declared a siege on the [P.names[c]]. It begins in your first defence window at least [SIEGE_NOTICE_HOURS] hours from now. [province_window_text(c)]")
	province_tell_leaders(group, "[faction] declared a siege on the [P.names[c]]. [province_window_text(c)]")
	map.recruitment_audit(faction, "[user.real_name] declared a siege on the [P.names[c]] at [x],[y].", faction_roster_account(user) || "")
	log_game("Provinces: [key_name(user)] declared a siege on province [c] for [faction].")
	province_siege_start()

// --- The siege ------------------------------------------------------------------------

/proc/province_siege_start()
	if (province_siege_timer)
		return
	province_siege_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(province_siege_tick)), SIEGE_TICK, TIMER_LOOP | TIMER_STOPPABLE)

// Restarts the loop when a declared siege outlived a restart.
/proc/province_siege_resume()
	if (province_siege_timer)
		return
	var/list/S = map.recruitment_state()["province_sieges"]
	if (!islist(S))
		return
	for (var/c in S)
		var/list/row = S[c]
		if (islist(row) && islist(row["siege"]))
			province_siege_start()
			return

/proc/province_siege_capture_minutes(rank)
	switch (rank)
		if (2) return 15
		if (3) return 20
		if (4) return 30
	return 10

/proc/province_siege_end(c, list/row, message_holder, message_attacker)
	var/list/siege = row["siege"]
	row["siege"] = null
	province_tell_leaders(province_holder_of(c), message_holder)
	province_tell_leaders(siege["group"], message_attacker)
	for (var/obj/structure/war_banner/W in range(0, locate(siege["x"], siege["y"], siege["z"])))
		if (W.faction == siege["faction"])
			W.faction = null
			W.name = initial(W.name)

/proc/province_siege_banner_lost(obj/structure/war_banner/W)
	if (!W.faction || !map || !map.province_map())
		return
	var/c = map.province_map().char_at(W.x, W.y)
	var/list/S = c ? map.recruitment_state()["province_sieges"] : null
	var/list/row = islist(S) ? S[c] : null
	var/list/siege = islist(row) ? row["siege"] : null
	if (!islist(siege) || siege["faction"] != W.faction || siege["x"] != W.x || siege["y"] != W.y)
		return
	var/list/cooldown = row["cooldown"]
	cooldown[siege["group"]] = world.realtime + SIEGE_COOLDOWN_DAYS * 864000
	var/name = map.province_map().names[c]
	W.faction = null
	province_siege_end(c, row, "The war banner of [siege["faction"]] in the [name] has fallen; the siege is off.", "Your war banner in the [name] has fallen; the siege is off.")

/proc/province_siege_tick()
	if (!map || !map.province_map())
		return
	var/list/S = map.recruitment_state()["province_sieges"]
	var/active = FALSE
	if (islist(S))
		for (var/c in S)
			var/list/row = S[c]
			if (islist(row) && islist(row["siege"]))
				active = TRUE
				province_siege_step(c, row)
	if (!active && province_siege_timer)
		deltimer(province_siege_timer)
		province_siege_timer = null

/proc/province_siege_step(c, list/row)
	var/list/siege = row["siege"]
	var/holder = province_holder_of(c)
	var/datum/province_map/P = map.province_map()
	var/name = P.names[c]
	if (!holder || holder == siege["group"])
		province_siege_end(c, row, "The siege on the [name] is over.", "The siege on the [name] is over: the province changed hands.")
		return
	var/due = world.realtime >= siege["declared"] + SIEGE_NOTICE_HOURS * 36000
	var/open = due && province_in_window(c)
	if (!open)
		if (!siege["live"])
			return
		// The window closed on a siege that had begun.
		if (siege["shown"])
			var/list/cooldown = row["cooldown"]
			cooldown[siege["group"]] = world.realtime + SIEGE_COOLDOWN_DAYS * 864000
			province_siege_end(c, row, "The siege on the [name] failed: the seat held.", "Your siege on the [name] failed. Your side can declare here again in [SIEGE_COOLDOWN_DAYS] days.")
		else
			var/obj/structure/closet/crate/faction_strongbox/B = map.faction_strongbox(siege["faction"])
			province_upkeep_take(B, SIEGE_DEPOSIT)
			province_siege_end(c, row, "Nobody came to the siege declared on the [name].", "Nobody came to your siege on the [name]: its [SIEGE_DEPOSIT] silver deposit is spent.")
		return
	var/obj/structure/faction_hall/seat = province_seat(c, holder)
	if (!seat)
		province_siege_end(c, row, "The siege on the [name] is off: your side has no standing hall there to hold.", "The siege on the [name] is off: its holder has no standing hall there to take.")
		return
	if (!siege["live"])
		siege["live"] = TRUE
		province_tell_leaders(holder, "The siege on the [name] has begun. Hold the seat until the window closes.")
		province_tell_leaders(siege["group"], "The siege on the [name] has begun: hold the ground beside its seat at [seat.x],[seat.y].")
	var/attackers = 0
	var/defenders = 0
	for (var/mob/living/human/H in range(SIEGE_SEAT_RANGE, seat))
		if (!H.client || H.stat == DEAD || !H.civilization || H.civilization == "none")
			continue
		var/group = province_group_of(H.civilization)
		if (group == siege["group"])
			attackers++
		else if (group == holder)
			defenders++
	if (!attackers)
		return
	siege["shown"] = TRUE
	if (defenders)
		return
	siege["progress"] += SIEGE_TICK
	if (siege["progress"] < province_siege_capture_minutes(province_rank_of(c)) * 600)
		return
	province_siege_won(c, row, holder)

/proc/province_siege_won(c, list/row, holder)
	var/list/siege = row["siege"]
	var/name = map.province_map().names[c]
	var/now = world.realtime
	row["suspended"] = now + SIEGE_SUSPEND_DAYS * 864000
	row["immune"] = now + SIEGE_IMMUNE_DAYS * 864000
	var/list/wins = row["wins"]
	var/list/win = wins[siege["group"]]
	var/count = islist(win) && win.len == 2 && isnum(win[2]) && now - win[2] < SIEGE_REPEAT_DAYS * 864000 ? win[1] + 1 : 1
	wins[siege["group"]] = list(count, now)
	var/warning = province_rank_of(c) <= 1 || count >= 2
	if (warning)
		var/list/H = province_holder_row(c)
		if (!H[3])
			H[3] = now
	province_siege_end(c, row, "[siege["faction"]] has taken the seat of the [name]. Its rank's benefits are suspended for [SIEGE_SUSPEND_DAYS] days[warning ? ", and your hold is slipping: recover it or lose the province" : ""].", "Your side has taken the seat of the [name]. Its holder's rank is suspended for [SIEGE_SUSPEND_DAYS] days[warning ? " and its hold is slipping" : ""].")
	log_game("Provinces: [siege["faction"]] won a siege on province [c].")

/proc/province_siege_text(c)
	var/list/row = province_siege_row(c)
	var/list/parts = list(province_window_text(c))
	var/list/siege = row["siege"]
	if (islist(siege))
		if (siege["live"])
			parts += "Under siege by [siege["faction"]]: [round(siege["progress"] / 600)] of [province_siege_capture_minutes(province_rank_of(c))] minutes held at the seat."
		else
			parts += "[siege["faction"]] has declared a siege; it begins in the first window from [max(0, round((siege["declared"] + SIEGE_NOTICE_HOURS * 36000 - world.realtime) / 36000))] hours from now."
	if (isnum(row["suspended"]) && world.realtime < row["suspended"])
		parts += "A rank's benefits are suspended for [round((row["suspended"] - world.realtime) / 36000)] more hours after a siege."
	if (isnum(row["immune"]) && world.realtime < row["immune"])
		parts += "Immune to sieges for [round((row["immune"] - world.realtime) / 36000)] more hours."
	return jointext(parts, " ")

// --- Renames --------------------------------------------------------------------------

// A renamed faction keeps its provinces, upkeep, ruins and sieges
// (faction_recruitment.dm recruitment_rename_faction).
/proc/province_rename_faction(old_name, new_name)
	if (!map)
		return
	var/old_group = "faction:[old_name]"
	var/new_group = "faction:[new_name]"
	var/list/S = map.recruitment_state()
	var/list/holders = S["province_holders"]
	if (islist(holders))
		for (var/c in holders)
			var/list/row = holders[c]
			if (islist(row) && row.len == 5)
				if (row[1] == old_group)
					row[1] = new_group
				if (row[4] == old_group)
					row[4] = new_group
	var/list/upkeep = S["province_upkeep"]
	if (islist(upkeep))
		for (var/c in upkeep)
			var/list/row = upkeep[c]
			if (islist(row) && row.len && row[1] == old_group)
				row[1] = new_group
	var/list/ruins = S["province_ruins"]
	if (islist(ruins))
		for (var/key in ruins.Copy())
			var/list/parts = splittext(key, "|")
			if (copytext(key, length(parts[1]) + 2) == old_name)
				var/since = ruins[key]
				ruins -= key
				ruins["[parts[1]]|[new_name]"] = since
	var/list/sieges = S["province_sieges"]
	if (islist(sieges))
		for (var/c in sieges)
			var/list/row = sieges[c]
			if (!islist(row))
				continue
			var/list/siege = row["siege"]
			if (islist(siege))
				if (siege["faction"] == old_name)
					siege["faction"] = new_name
				if (siege["group"] == old_group)
					siege["group"] = new_group
			for (var/key in list("wins", "cooldown"))
				var/list/L = row[key]
				if (islist(L) && (old_group in L))
					L[new_group] = L[old_group]
					L -= old_group

#undef SIEGE_WINDOW_HOURS
#undef SIEGE_BUSY_HOURS
#undef SIEGE_WINDOW_DELAY_HOURS
#undef SIEGE_FACTION_DAYS
#undef SIEGE_ACCOUNTS
#undef SIEGE_PLAY_MINUTES
#undef SIEGE_NOTICE_HOURS
#undef SIEGE_DEPOSIT
#undef SIEGE_SEAT_RANGE
#undef SIEGE_TICK
#undef SIEGE_SUSPEND_DAYS
#undef SIEGE_IMMUNE_DAYS
#undef SIEGE_REPEAT_DAYS
#undef SIEGE_COOLDOWN_DAYS
