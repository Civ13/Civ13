// Faction treasuries (docs/faction-treasury.md). A faction's money is coin in
// a strongbox that stands somewhere in the world, not a number in a menu. Its
// leader designates one strongbox for the faction. Sales and business taxes
// still gather in the faction's tax ledger (custom_civs[f][5] and the fiat
// treasury [11]) as players trade; someone with the key of office collects
// them into the strongbox as coin. From there the leader sets wages, which
// members collect from the coin that is actually in the box, and dues, which
// members pay into it. A box with no coin pays no wages. Outsiders can pry a
// strongbox open with a crowbar or hammer, which takes a minute and warns the
// faction.
//
// Who holds the key: the faction leader, and anyone with the faction's
// treasury power (faction_offices.dm): an appointed Treasurer, or whoever
// carries an in-force seal of such an office.
//
// The box keeps its faction in its own var (saved with the world). The rest
// lives in map.faction_recruitment["treasury"] (durable, renamed with the
// faction):
//   faction -> list("dues" = silver a week,
//                   "wages" = list(account = list(silver a day, owed, last time, name, sub-tenth carry)),
//                   "paid" = list(account = list(silver this week, week start, name)),
//                   "ledger" = list(text, newest last))
// Worth is in silver, the scale of the trading balance (weighed_money.dm).
// Nothing here creates money: wages are paid only from coin in the box.
// Nothing sleeps except the prompts and the prying do_after, which recheck.

#define TREASURY_TAX_MAX 30
#define TREASURY_WAGE_MAX 50 // silver a day
#define TREASURY_WAGE_CAP_DAYS 7 // unpaid wages stop growing after this
#define TREASURY_DUES_MAX 200 // silver a week
#define TREASURY_LEDGER_MAX 40
#define TREASURY_PRY_TIME 600
#define TREASURY_DAY 864000 // deciseconds of real time
#define TREASURY_WEEK 6048000

var/global/list/faction_strongboxes = list() // every treasury strongbox

// --- State -------------------------------------------------------------------

/obj/map_metadata/proc/treasury_state()
	var/list/S = recruitment_state()
	if (!islist(S["treasury"]))
		S["treasury"] = list()
	return S["treasury"]

// The faction's treasury record, made when first needed.
/obj/map_metadata/proc/treasury_record(faction)
	var/list/T = treasury_state()
	var/list/R = T[faction]
	if (!islist(R))
		R = list()
		T[faction] = R
	if (!isnum(R["dues"]) || R["dues"] < 0)
		R["dues"] = 0
	for (var/key in list("wages", "paid", "ledger"))
		if (!islist(R[key]))
			R[key] = list()
	return R

// Drops malformed parts (a damaged save is never trusted).
/obj/map_metadata/proc/treasury_normalize()
	var/list/T = treasury_state()
	for (var/faction in T.Copy())
		if (!istext(faction) || !islist(T[faction]))
			T -= faction
			continue
		var/list/R = treasury_record(faction)
		R["dues"] = min(round(R["dues"]), TREASURY_DUES_MAX)
		var/list/wages = R["wages"]
		for (var/account in wages.Copy())
			var/list/row = wages[account]
			if (!istext(account) || !islist(row) || (row.len != 4 && row.len != 5) || !isnum(row[1]) || !isnum(row[2]) || !isnum(row[3]) || !istext(row[4]) || row[1] < 0 || row[2] < 0)
				wages -= account
				continue
			if (row.len == 4)
				row += 0 // legacy balance was already stored in tenths of silver
			else if (!isnum(row[5]) || row[5] < 0 || row[5] >= TREASURY_DAY || row[5] != round(row[5]))
				row[5] = 0 // bad carry cannot invalidate already-earned coin
		var/list/paid = R["paid"]
		for (var/account in paid.Copy())
			var/list/row = paid[account]
			if (!istext(account) || !islist(row) || row.len != 3 || !isnum(row[1]) || !isnum(row[2]) || !istext(row[3]))
				paid -= account
		var/list/ledger = R["ledger"]
		for (var/line in ledger.Copy())
			if (!istext(line))
				ledger -= line

/obj/map_metadata/proc/treasury_rename(old_name, new_name)
	faction_rename_assoc_key(treasury_state(), old_name, new_name)
	for (var/obj/structure/closet/crate/faction_strongbox/B in faction_strongboxes)
		if (B.faction == old_name)
			B.faction = new_name
			B.update_box_name()

// A character's legal rename updates existing wage labels without changing ownership or earnings.
/obj/map_metadata/proc/treasury_refresh_wage_name(account, old_name, new_name)
	var/list/T = treasury_state()
	for (var/faction in T)
		var/list/R = T[faction]
		if (!islist(R))
			continue
		var/list/wages = R["wages"]
		var/list/row = islist(wages) ? wages[account] : null
		if (islist(row) && row.len >= 4 && row[4] == old_name)
			row[4] = new_name

/obj/map_metadata/proc/treasury_log(faction, text)
	var/list/R = treasury_record(faction)
	var/list/ledger = R["ledger"]
	ledger += "[faction_seal_date(recruitment_now())]: [text]"
	while (ledger.len > TREASURY_LEDGER_MAX)
		ledger.Cut(1, 2)

// The faction's standing strongbox, or null.
/obj/map_metadata/proc/faction_strongbox(faction)
	if (!istext(faction) || !length(faction))
		return null
	for (var/obj/structure/closet/crate/faction_strongbox/B in faction_strongboxes)
		if (!QDELETED(B) && B.faction == faction && isturf(B.loc))
			return B
	return null

// --- Wages and dues ------------------------------------------------------------

// Brings a wage row up to now and returns the payable balance in silver.
// Row 5 tracks the numerator of the unpayable fraction of one tenth of silver
// (denominator TREASURY_DAY). Legacy rows simply start with no such fraction.
/proc/treasury_wage_accrue(list/row, now)
	if (!islist(row) || (row.len != 4 && row.len != 5))
		return 0
	if (row.len == 4)
		row += 0
	var/elapsed = now - row[3]
	row[3] = max(row[3], now)
	var/rate_tenths = round(row[1] * 10 + 0.5)
	var/owed_tenths = round(row[2] * 10 + 0.5)
	var/room = rate_tenths * TREASURY_WAGE_CAP_DAYS - owed_tenths
	// A rate cut only limits NEW earnings. Even an over-cap balance is still owed.
	if (elapsed <= 0 || room <= 0)
		return row[2]

	// Split the sub-day product into 128-decisecond blocks. Both intermediate
	// products stay exactly representable in DM at any valid wage rate.
	elapsed = min(elapsed, TREASURY_WAGE_CAP_DAYS * TREASURY_DAY)
	var/days = round(elapsed / TREASURY_DAY)
	var/within_day = elapsed - days * TREASURY_DAY
	var/blocks = round(within_day / 128)
	var/packed = blocks * rate_tenths
	var/block_divisor = TREASURY_DAY / 128
	var/block_tenths = round(packed / block_divisor)
	var/carry = (packed - block_tenths * block_divisor) * 128 + (within_day - blocks * 128) * rate_tenths + row[5]
	var/extra_tenths = round(carry / TREASURY_DAY)
	var/earned = days * rate_tenths + block_tenths + extra_tenths
	if (earned >= room)
		row[2] = (owed_tenths + room) / 10
		row[5] = 0
	else
		row[2] = (owed_tenths + earned) / 10
		row[5] = carry - extra_tenths * TREASURY_DAY
	return row[2]

/obj/map_metadata/proc/treasury_set_wage(faction, account, name, rate)
	var/list/R = treasury_record(faction)
	var/list/wages = R["wages"]
	rate = round(clamp(rate, 0, TREASURY_WAGE_MAX), 0.1)
	var/list/row = wages[account]
	if (islist(row))
		treasury_wage_accrue(row, recruitment_now())
	if (rate <= 0)
		if (islist(row) && (row[2] > 0 || row[5] > 0))
			row[1] = 0 // keep what is already owed
		else
			wages -= account
		return 0
	if (!islist(row))
		row = list(rate, 0, recruitment_now(), name, 0)
		wages[account] = row
	row[1] = rate
	row[4] = name
	return rate

// Silver paid toward this week's dues.
/obj/map_metadata/proc/treasury_dues_paid(faction, account)
	var/list/R = treasury_record(faction)
	var/list/paid = R["paid"]
	var/list/row = paid[account]
	if (!islist(row) || recruitment_now() - row[2] >= TREASURY_WEEK)
		return 0
	return row[1]

/obj/map_metadata/proc/treasury_record_payment(faction, account, name, worth)
	var/list/R = treasury_record(faction)
	var/list/paid = R["paid"]
	var/list/row = paid[account]
	var/now = recruitment_now()
	if (!islist(row) || now - row[2] >= TREASURY_WEEK)
		row = list(0, now, name)
		paid[account] = row
	row[1] = round(row[1] + worth, 0.1)
	row[3] = name

// --- Coin in the box -----------------------------------------------------------

/obj/structure/closet/crate/faction_strongbox/proc/coin_stacks()
	var/list/stacks = list()
	var/atom/holder = opened ? loc : src
	for (var/obj/item/stack/money/M in holder)
		if (M.is_metal_coin() && M.amount > 0 && M.value > 0)
			stacks += M
	return stacks

/obj/structure/closet/crate/faction_strongbox/proc/coin_worth()
	var/worth = 0
	for (var/obj/item/stack/money/M in coin_stacks())
		worth += M.amount * M.value
	return round(worth, 0.1)

// Pays up to worth in whole coins from the box, never more, largest coins
// first. Returns the worth paid.
/obj/structure/closet/crate/faction_strongbox/proc/pay_out(worth, mob/living/human/to_user)
	return coin_pay_from(coin_stacks(), worth, to_user)

// --- The strongbox ---------------------------------------------------------------

/obj/structure/closet/crate/faction_strongbox
	name = "strongbox"
	desc = "A heavy banded chest. A faction leader can make it the faction's treasury."
	icon_state = "treasure_chest"
	icon_opened = "treasure_chest_opened"
	icon_closed = "treasure_chest"
	health = 3000
	storage_capacity = 5 * MOB_MEDIUM
	var/faction = "" // the faction whose treasury this is; "" when plain

/obj/structure/closet/crate/faction_strongbox/New()
	..()
	faction_strongboxes |= src

/obj/structure/closet/crate/faction_strongbox/Destroy()
	faction_strongboxes -= src
	return ..()

/obj/structure/closet/crate/faction_strongbox/after_load()
	..()
	update_box_name()

/obj/structure/closet/crate/faction_strongbox/proc/update_box_name()
	if (length(faction))
		name = "strongbox of [faction]"
		desc = "The treasury of [faction]. It opens for the leader and the faction's treasurers."
		anchored = TRUE
		locked = TRUE
	else
		name = initial(name)
		desc = initial(desc)
		locked = FALSE

/obj/structure/closet/crate/faction_strongbox/examine(mob/user, distance = -1)
	..()
	if (length(faction) && ishuman(user))
		var/mob/living/human/H = user
		if (H.civilization == faction)
			to_chat(user, SPAN_NOTICE("It holds coin worth [weighed_silver_text(coin_worth())]."))

// The leader, or anyone with the faction's treasury power.
/obj/structure/closet/crate/faction_strongbox/proc/holds_key(mob/living/human/H)
	if (!map || !length(faction))
		return FALSE
	return map.faction_power(H, faction, "treasury")

/obj/structure/closet/crate/faction_strongbox/attack_hand(mob/living/human/user)
	if (!istype(user) || !map)
		return ..()
	add_fingerprint(user)
	if (!length(faction))
		var/civ = user.civilization
		if (civ && civ != "none" && map.is_faction_leader(user, civ) && !opened)
			var/choice = WWinput(user, "Make this the strongbox of [civ]?", "Strongbox", "Open it", list("Make it the treasury", "Open it", "Cancel"))
			if (choice == "Make it the treasury")
				designate(user, civ)
				return
			if (choice != "Open it" || !user.Adjacent(src))
				return
		return ..()
	if (user.civilization != faction && !holds_key(user))
		to_chat(user, SPAN_NOTICE("\The [src] is locked."))
		return
	treasury_menu(user)

/obj/structure/closet/crate/faction_strongbox/proc/designate(mob/living/human/user, civ)
	if (length(faction) || !user.Adjacent(src) || user.civilization != civ || !map.is_faction_leader(user, civ) || !isturf(loc))
		return FALSE
	var/obj/structure/closet/crate/faction_strongbox/old = map.faction_strongbox(civ)
	if (old)
		var/choice = WWinput(user, "[civ] already keeps its treasury in \the [old]. Move the treasury here? The old box becomes a plain chest with whatever is in it.", "Strongbox", "Cancel", list("Move it here", "Cancel"))
		if (choice != "Move it here" || length(faction) || !user.Adjacent(src) || !map.is_faction_leader(user, civ))
			return FALSE
		old = map.faction_strongbox(civ)
		if (old)
			old.faction = ""
			old.update_box_name()
	faction = civ
	update_box_name()
	map.treasury_log(civ, "[user.real_name] made a new strongbox the treasury.")
	to_chat(user, SPAN_NOTICE("\The [src] is now the treasury of [civ]. It locks, and only you and the faction's treasurers can open it."))
	log_game("[key_name(user)] designated a strongbox for [civ] at ([x],[y],[z]).")
	return TRUE

/obj/structure/closet/crate/faction_strongbox/proc/treasury_menu(mob/living/human/user)
	var/key = holds_key(user)
	var/leader = map.is_faction_leader(user, faction)
	var/list/choices = list()
	if (key)
		choices += opened ? "Close and lock it" : "Unlock and open it"
		choices += "Collect taxes into the box"
		choices += "Draw bills or notes"
	choices += list("Collect my wages", "Pay dues from my hand", "Pay land tax from my hand", "Pay a fine from my hand", "Read the ledger")
	if (leader)
		choices += list("Set wages", "Set dues", "Set taxes", "Release the box")
	choices += "Cancel"
	var/choice = WWinput(user, "Treasury of [faction]. It holds coin worth [weighed_silver_text(coin_worth())].", "Strongbox", "Cancel", choices)
	if (!choice || choice == "Cancel" || !(choice in choices) || QDELETED(src) || !user.Adjacent(src) || user.stat != CONSCIOUS)
		return
	// Powers are checked again: the prompt may have waited.
	if ((choice in list("Close and lock it", "Unlock and open it", "Collect taxes into the box", "Draw bills or notes")) && !holds_key(user))
		return
	if ((choice in list("Set wages", "Set dues", "Set taxes", "Release the box")) && !map.is_faction_leader(user, faction))
		return
	if (user.civilization != faction && !(choice in list("Close and lock it", "Unlock and open it", "Collect taxes into the box", "Draw bills or notes")))
		return
	switch (choice)
		if ("Unlock and open it")
			locked = FALSE
			open()
			locked = TRUE
		if ("Close and lock it")
			close()
			locked = TRUE
		if ("Collect taxes into the box")
			collect_taxes(user)
		if ("Draw bills or notes")
			draw_bills(user)
		if ("Collect my wages")
			collect_wages(user)
		if ("Pay dues from my hand")
			pay_dues(user)
		if ("Pay land tax from my hand")
			pay_land_tax(user)
		if ("Pay a fine from my hand")
			pay_fine(user)
		if ("Read the ledger")
			to_chat(user, ledger_text())
		if ("Set wages")
			set_wages(user)
		if ("Set dues")
			var/list/R = map.treasury_record(faction)
			var/value = player_input(user, "Dues each member should pay a week, in silver (0 to [TREASURY_DUES_MAX]). The box does not force anyone to pay; the ledger shows who has.", "Dues", R["dues"], "num", null, TRUE)
			if (!isnum(value) || !map.is_faction_leader(user, faction))
				return
			R["dues"] = clamp(round(value), 0, TREASURY_DUES_MAX)
			map.treasury_log(faction, "[user.real_name] set dues at [R["dues"]] silver a week.")
			to_chat(user, SPAN_NOTICE("Dues are now [R["dues"]] silver a week."))
		if ("Set taxes")
			set_taxes(user)
		if ("Release the box")
			if (!opened)
				to_chat(user, SPAN_WARNING("Open the box first, so nothing is locked inside a plain chest by mistake."))
				return
			map.treasury_log(faction, "[user.real_name] released the strongbox; the faction has no treasury box.")
			faction = ""
			update_box_name()
			to_chat(user, SPAN_NOTICE("\The [src] is a plain chest again."))

/obj/structure/closet/crate/faction_strongbox/proc/collect_taxes(mob/living/human/user)
	if (!(faction in map.custom_civs))
		return
	var/list/civ = map.custom_civs[faction]
	var/atom/holder = opened ? loc : src
	var/collected = 0
	var/list/parts = list()
	if (isnum(civ[5]) && civ[5] >= 1)
		var/paid = company_pay_coins(holder, civ[5])
		civ[5] = max(0, civ[5] - paid)
		if (paid)
			collected = TRUE
			parts += "[paid] silver in coin"
	if (civ.len >= 11 && islist(civ[11]))
		var/list/fiat_treasury = civ[11]
		for (var/fid in fiat_treasury)
			var/amount = fiat_treasury[fid]
			if (!isnum(amount) || amount < 1 || !fiat || !islist(fiat.currency_list[fid]))
				continue
			var/paid = round(amount)
			new /obj/item/stack/money/fiat(holder, paid, fid)
			fiat_treasury[fid] = amount - paid // whole notes only; the fraction waits
			collected = TRUE
			parts += "[paid] [fiat.currency_list[fid][1]]"
	if (!collected)
		to_chat(user, SPAN_NOTICE("No taxes are waiting to be collected."))
		return
	var/text = jointext(parts, ", ")
	map.treasury_log(faction, "[user.real_name] collected taxes: [text].")
	to_chat(user, SPAN_NOTICE("You collect the faction's taxes into \the [src]: [text]."))

/obj/structure/closet/crate/faction_strongbox/proc/set_taxes(mob/living/human/user)
	if (!(faction in map.custom_civs))
		return
	var/list/civ = map.custom_civs[faction]
	var/which = WWinput(user, "Sales tax is taken from players' vending sales; business tax from company profits. Both gather for collection into the box.", "Taxes", "Cancel", list("Sales tax ([civ[9]]%)", "Business tax ([civ[10]]%)", "Cancel"))
	if (!which || which == "Cancel")
		return
	var/index = findtext(which, "Sales") ? 9 : 10
	var/value = player_input(user, "New rate, 0 to [TREASURY_TAX_MAX]%:", "Taxes", civ[index], "num", null, TRUE)
	if (!isnum(value) || !map.is_faction_leader(user, faction) || !(faction in map.custom_civs))
		return
	civ = map.custom_civs[faction]
	civ[index] = clamp(round(value), 0, TREASURY_TAX_MAX)
	var/label = index == 9 ? "Sales tax" : "Business tax"
	map.treasury_log(faction, "[user.real_name] set [lowertext(label)] at [civ[index]]%.")
	to_chat(user, SPAN_NOTICE("[label] is now [civ[index]]%."))

// Prompt labels are unique even for legacy wage records with the same name.
// Do not expose account keys or store the prompt label as the character's name.
/proc/treasury_wage_choices(list/online_names, list/wages)
	var/list/options = list()
	for (var/account in online_names)
		var/name = online_names[account]
		options["[options.len + 1]. [name] (online)"] = list(account, name)
	for (var/account in wages)
		if (account in online_names)
			continue
		var/list/row = wages[account]
		if (!islist(row) || row.len < 4 || !istext(row[4]))
			continue
		var/name = row[4]
		options["[options.len + 1]. [name] (saved wage)"] = list(account, name)
	return options

/obj/structure/closet/crate/faction_strongbox/proc/set_wages(mob/living/human/user)
	var/selected_faction = faction
	var/list/online_names = list()
	var/list/online_members = list()
	for (var/mob/living/human/M in human_mob_list)
		if (M.civilization == selected_faction && M.stat != DEAD && M.client)
			var/account = faction_roster_account(M)
			if (account)
				online_names[account] = M.real_name
				online_members[account] = M
	var/list/R = map.treasury_record(selected_faction)
	var/list/wages = R["wages"]
	var/list/choices = treasury_wage_choices(online_names, wages)
	if (!choices.len)
		to_chat(user, SPAN_NOTICE("No members are available to pay."))
		return
	var/pick = WWinput(user, "Whose wage? Members collect wages from the coin in the box; unpaid wages stop growing after [TREASURY_WAGE_CAP_DAYS] days.", "Wages", "Cancel", choices + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in choices) || faction != selected_faction || !map.is_faction_leader(user, faction))
		return
	var/list/selection = choices[pick]
	var/account = selection[1]
	var/name = selection[2]
	var/list/row = wages[account]
	var/value = player_input(user, "[name]'s wage in silver a day (0 to [TREASURY_WAGE_MAX]; 0 stops it):", "Wages", islist(row) ? row[1] : 0, "num", null, TRUE)
	if (!isnum(value) || faction != selected_faction || !map.is_faction_leader(user, faction))
		return
	// The prompts can sleep. Prefer the current name if the character was renamed while either was open.
	R = map.treasury_record(selected_faction)
	wages = R["wages"]
	row = wages[account]
	var/mob/living/human/online = online_members[account]
	if (!QDELETED(online) && faction_roster_account(online) == account)
		name = online.real_name
	else if (islist(row) && row.len >= 4 && istext(row[4]))
		name = row[4]
	var/rate = map.treasury_set_wage(faction, account, name, value)
	map.treasury_log(faction, "[user.real_name] set [name]'s wage at [rate] silver a day.")
	to_chat(user, SPAN_NOTICE("[name]'s wage is now [rate] silver a day."))

/obj/structure/closet/crate/faction_strongbox/proc/collect_wages(mob/living/human/user)
	var/account = faction_roster_account(user)
	var/list/R = map.treasury_record(faction)
	var/list/wages = R["wages"]
	var/list/row = account ? wages[account] : null
	if (!islist(row))
		to_chat(user, SPAN_NOTICE("You are owed no wages by [faction]."))
		return
	var/owed = treasury_wage_accrue(row, recruitment_now())
	if (owed < 0.1)
		to_chat(user, SPAN_NOTICE("You are owed nothing yet. Your wage is [row[1]] silver a day."))
		return
	var/paid = pay_out(owed, user)
	if (paid <= 0)
		to_chat(user, SPAN_WARNING("You are owed [weighed_silver_text(owed)], but the box has no coin small enough to pay you."))
		return
	row[2] = max(0, round(row[2] * 10 + 0.5) - round(paid * 10 + 0.5)) / 10
	if (row[1] <= 0 && row[2] <= 0 && row[5] <= 0)
		wages -= account
	map.treasury_log(faction, "[user.real_name] collected wages worth [weighed_silver_text(paid)].")
	to_chat(user, SPAN_NOTICE("You collect wages worth [weighed_silver_text(paid)][row[2] > 0 ? "; the box still owes you [weighed_silver_text(row[2])]" : ""]."))

/obj/structure/closet/crate/faction_strongbox/proc/pay_dues(mob/living/human/user)
	var/obj/item/stack/money/M = user.get_active_hand()
	if (!istype(M) || !M.is_metal_coin() || M.amount < 1)
		to_chat(user, SPAN_NOTICE("Hold the coins you want to pay in your hand."))
		return
	var/account = faction_roster_account(user)
	if (!account)
		return
	var/worth = round(M.amount * M.value, 0.1)
	user.drop_from_inventory(M)
	M.forceMove(opened ? loc : src)
	map.treasury_record_payment(faction, account, user.real_name, worth)
	var/list/R = map.treasury_record(faction)
	map.treasury_log(faction, "[user.real_name] paid dues worth [weighed_silver_text(worth)].")
	to_chat(user, SPAN_NOTICE("You pay [weighed_silver_text(worth)] into \the [src]. This week you have paid [weighed_silver_text(map.treasury_dues_paid(faction, account))] of [R["dues"]] silver in dues."))

/obj/structure/closet/crate/faction_strongbox/proc/ledger_text()
	var/list/R = map.treasury_record(faction)
	var/list/lines = list("<b>Ledger of [faction]</b>")
	lines += "Coin in the box: [weighed_silver_text(coin_worth())]. Promised on open bills and notes: [map.bills_outstanding(faction)] silver."
	if (faction in map.custom_civs)
		var/list/civ = map.custom_civs[faction]
		lines += "Taxes waiting: [isnum(civ[5]) ? round(civ[5], 0.1) : 0] silver. Sales tax [civ[9]]%, business tax [civ[10]]%."
	lines += "Dues: [R["dues"]] silver a week."
	var/list/wages = R["wages"]
	var/now = recruitment_now()
	for (var/account in wages)
		var/list/row = wages[account]
		lines += "Wage: [row[4]], [row[1]] silver a day, owed [weighed_silver_text(treasury_wage_accrue(row.Copy(), now))]."
	var/list/paid = R["paid"]
	for (var/account in paid)
		var/list/row = paid[account]
		if (now - row[2] < TREASURY_WEEK)
			lines += "Dues paid this week: [row[3]], [weighed_silver_text(row[1])]."
	var/list/ledger = R["ledger"]
	if (ledger.len)
		lines += "<i>Recent entries:</i>"
		lines += ledger
	return SPAN_NOTICE(jointext(lines, "<br>"))

// The box is locked to everyone but its keepers: keys do not fit it, it
// cannot be unbolted, and outsiders can only pry it open.
/obj/structure/closet/crate/faction_strongbox/attackby(obj/item/W, mob/user)
	if (!length(faction) || opened)
		return ..()
	if (istype(W, /obj/item/weapon/key) || is_tool(W, TOOL_WRENCH))
		to_chat(user, SPAN_WARNING("\The [src] has no keyhole for that; it answers only to its keepers."))
		return TRUE
	if (is_tool(W, TOOL_CROWBAR) || is_tool(W, TOOL_HAMMER))
		pry(user)
		return TRUE
	to_chat(user, SPAN_NOTICE("\The [src] is locked."))
	return TRUE

/obj/structure/closet/crate/faction_strongbox/proc/pry(mob/living/human/user)
	if (!istype(user))
		return
	user.visible_message(SPAN_DANGER("[user] starts prying at \the [src]!"), SPAN_WARNING("You start prying at \the [src]. This will take a while."))
	for (var/mob/living/human/M in human_mob_list)
		if (M.civilization == faction && M.client && M != user && M.stat != DEAD)
			to_chat(M, SPAN_DANGER("Someone is breaking into the strongbox of [faction]!"))
	if (!do_after(user, TREASURY_PRY_TIME, src))
		return
	if (QDELETED(src) || opened || !user.Adjacent(src))
		return
	locked = FALSE
	open()
	locked = TRUE
	map.treasury_log(faction, "The strongbox was pried open.")
	user.visible_message(SPAN_DANGER("[user] pries \the [src] open!"))
	log_game("[key_name(user)] pried open the strongbox of [faction] at ([x],[y],[z]).")

#undef TREASURY_TAX_MAX
#undef TREASURY_WAGE_MAX
#undef TREASURY_WAGE_CAP_DAYS
#undef TREASURY_DUES_MAX
#undef TREASURY_LEDGER_MAX
#undef TREASURY_PRY_TIME
#undef TREASURY_DAY
#undef TREASURY_WEEK
