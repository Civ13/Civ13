// Money changers (docs/money-changers.md). A player builds a money changer's
// table and takes it as their own. They stock it with coin and set, for each
// issuer's coin they will buy, a rate as a share of the coin's weighed worth
// (weighed_money.dm). Anyone may then hand the table coin of an issuer it buys
// and be paid at that rate in coin from its stock, in the issuer of their
// choice. The coins they hand over stay in the table. Owners earn by setting
// rates under full worth; nothing is paid that the owner did not put in or
// take in trade. Like a strongbox, an open table lies open to anyone.
//
// A nation's common money (nation.dm) is shown beside its issuer's rate.
// Nothing here is saved beyond the table and its coin, and nothing sleeps
// except the prompts, which recheck after.

#define CHANGER_RATE_MAX 200 // percent of weighed worth
#define CHANGER_RATES_MAX 20

// Pays up to worth in whole coins from stacks, never more, largest coins first.
// With dry_run nothing moves. Returns the worth paid (or that would be).
/proc/coin_pay_from(list/stacks, worth, mob/living/human/to_user, dry_run = FALSE)
	var/list/sorted = list()
	stacks = stacks.Copy()
	while (stacks.len)
		var/obj/item/stack/money/best = stacks[1]
		for (var/obj/item/stack/money/M in stacks)
			if (M.value > best.value)
				best = M
		stacks -= best
		sorted += best
	var/paid = 0
	for (var/obj/item/stack/money/M in sorted)
		var/remaining = worth - paid
		var/count = min(M.amount, round((remaining + 0.001) / M.value))
		if (count <= 0)
			continue
		if (dry_run)
			paid += count * M.value
			continue
		var/obj/item/stack/money/out = M
		if (count < M.amount)
			out = M.split(count)
		if (!out)
			continue
		M.update_icon()
		out.update_icon()
		out.forceMove(get_turf(to_user))
		to_user.put_in_hands(out)
		paid += count * out.value
	return round(paid, 0.1)

/proc/changer_issuer_label(issuer)
	return length(issuer) ? "[issuer] coin" : "unmarked coin"

// A nation's common money (nation.dm keeps the vote menu entry).
// Member factions adopt one member's coin as the nation's common money by majority.
/mob/living/human/proc/nation_currency_vote(faction, id, nid)
	var/list/N = nation_registry[nid]
	var/list/options = list()
	for (var/f in N["members"])
		options["Coin of [nation_faction_label(f)]"] = f
	options["No common money"] = ""
	var/current = istext(N["currency"]) && length(N["currency"]) ? "coin of [nation_faction_label(N["currency"])]" : "none"
	var/pick = WWinput(src, "A nation may adopt one member faction's coin as its common money; a majority decides. Now: [current]. Vote for which?", "Common money", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options) || civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "currency", "faction" = id, "issuer" = options[pick]), faction)

// The nations whose common money is the coin of the faction named issuer here,
// as text, or null.
/proc/nation_currency_names(issuer)
	if (!istext(issuer) || !length(issuer))
		return null
	var/list/names = list()
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		if (istext(N["currency"]) && length(N["currency"]) && party_train_party_name(N["currency"]) == issuer)
			names += N["name"]
	return names.len ? english_list(names) : null

/obj/structure/closet/crate/money_changer
	name = "money changer's table"
	desc = "A counting table with a locked till. Its keeper changes one issuer's coin for another's at rates they set."
	icon = 'icons/obj/structures.dmi'
	icon_state = "pokertable"
	icon_opened = "pokertable"
	icon_closed = "pokertable"
	anchored = TRUE
	health = 1500
	storage_capacity = 5 * MOB_MEDIUM
	var/owner_account = ""
	var/owner_name = ""
	var/list/rates = list() // issuer ("" for unmarked) -> percent of weighed worth

// A kept table opens only through its keeper's menu.
/obj/structure/closet/crate/money_changer/can_open()
	return !locked

/obj/structure/closet/crate/money_changer/after_load()
	..()
	if (!islist(rates))
		rates = list()
	for (var/issuer in rates.Copy())
		if (!istext(issuer) || !isnum(rates[issuer]) || rates[issuer] < 1 || rates[issuer] > CHANGER_RATE_MAX)
			rates -= issuer
	locked = length(owner_account) ? TRUE : FALSE

/obj/structure/closet/crate/money_changer/proc/stock(issuer = null)
	var/list/stacks = list()
	var/atom/holder = opened ? loc : src
	for (var/obj/item/stack/money/M in holder)
		if (M.is_metal_coin() && M.amount > 0 && M.value > 0 && (isnull(issuer) || M.issuer == issuer))
			stacks += M
	return stacks

/obj/structure/closet/crate/money_changer/proc/stock_worth(issuer = null)
	var/worth = 0
	for (var/obj/item/stack/money/M in stock(issuer))
		worth += M.amount * M.value
	return round(worth, 0.1)

/obj/structure/closet/crate/money_changer/proc/is_keeper(mob/living/human/H)
	return istype(H) && length(owner_account) && faction_roster_account(H) == owner_account

/obj/structure/closet/crate/money_changer/proc/rates_text()
	var/list/lines = list("<b>[name]</b>[length(owner_name) ? ", kept by [owner_name]" : ""]")
	if (!rates.len)
		lines += "It buys no coin yet."
	for (var/issuer in rates)
		var/common = length(issuer) ? nation_currency_names(issuer) : null
		lines += "Buys [changer_issuer_label(issuer)] at [rates[issuer]]% of its weighed worth[common ? " (common money of [common])" : ""]."
	var/list/held = list()
	for (var/obj/item/stack/money/M in stock())
		held[M.issuer] = TRUE
	var/list/labels = list()
	for (var/issuer in held)
		labels += "[changer_issuer_label(issuer)] ([weighed_silver_text(stock_worth(issuer))])"
	lines += labels.len ? "Pays out in: [english_list(labels)]." : "Its till is empty."
	return jointext(lines, "<br>")

/obj/structure/closet/crate/money_changer/examine(mob/user, distance = -1)
	..()
	if (get_dist(user, src) <= 2)
		to_chat(user, SPAN_NOTICE(rates_text()))

/obj/structure/closet/crate/money_changer/attack_hand(mob/living/human/user)
	if (!istype(user))
		return ..()
	add_fingerprint(user)
	if (!length(owner_account))
		var/account = faction_roster_account(user)
		if (!account)
			return ..()
		var/choice = WWinput(user, "Keep this table as your money changer's table? It locks, and only you can open it or set its rates.", "Money changer", "Cancel", list("Keep it", "Cancel"))
		if (choice != "Keep it" || length(owner_account) || !user.Adjacent(src))
			return
		owner_account = account
		owner_name = user.real_name
		if (opened)
			close()
		locked = TRUE
		to_chat(user, SPAN_NOTICE("The table is yours. Put coin in it, set rates, and others can change their coin here."))
		return
	if (!is_keeper(user))
		to_chat(user, SPAN_NOTICE(rates_text()))
		to_chat(user, SPAN_NOTICE("Use coins on the table to change them."))
		return
	keeper_menu(user)

/obj/structure/closet/crate/money_changer/proc/keeper_menu(mob/living/human/user)
	var/list/choices = list(opened ? "Close and lock the till" : "Open the till", "Set a rate", "Stop buying a coin", "Read the rates", "Give up the table", "Cancel")
	var/choice = WWinput(user, "Your money changer's table holds coin worth [weighed_silver_text(stock_worth())].", "Money changer", "Read the rates", choices)
	if (!choice || choice == "Cancel" || !user.Adjacent(src) || !is_keeper(user))
		return
	switch (choice)
		if ("Open the till")
			locked = FALSE
			open()
		if ("Close and lock the till")
			close()
			locked = TRUE
		if ("Read the rates")
			to_chat(user, SPAN_NOTICE(rates_text()))
		if ("Set a rate")
			var/list/issuers = list("unmarked coin" = "")
			for (var/civ in map ? map.custom_civs : list())
				if (civ != "none")
					issuers[changer_issuer_label(civ)] = civ
			for (var/obj/item/stack/money/M in stock() + list(user.get_active_hand(), user.get_inactive_hand()))
				if (istype(M) && M.is_metal_coin())
					issuers[changer_issuer_label(M.issuer)] = M.issuer
			var/pick = WWinput(user, "Buy which coin?", "Set a rate", "Cancel", issuers + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in issuers))
				return
			var/issuer = issuers[pick]
			if (!(issuer in rates) && rates.len >= CHANGER_RATES_MAX)
				to_chat(user, SPAN_WARNING("The table can't keep more than [CHANGER_RATES_MAX] rates."))
				return
			var/percent = player_input(user, "Pay what share of its weighed worth, in percent (1 to [CHANGER_RATE_MAX])? Under 100 keeps a margin for you.", "Set a rate", rates[issuer] || 90, "num", null, TRUE)
			if (!isnum(percent) || percent < 1 || !user.Adjacent(src) || !is_keeper(user))
				return
			rates[issuer] = clamp(round(percent), 1, CHANGER_RATE_MAX)
			to_chat(user, SPAN_NOTICE("The table buys [pick] at [rates[issuer]]% of its weighed worth."))
		if ("Stop buying a coin")
			if (!rates.len)
				to_chat(user, SPAN_NOTICE("The table buys no coin."))
				return
			var/list/options = list()
			for (var/issuer in rates)
				options[changer_issuer_label(issuer)] = issuer
			var/pick = WWinput(user, "Stop buying which coin?", "Rates", "Cancel", options + "Cancel")
			if (pick && (pick in options) && is_keeper(user))
				rates -= options[pick]
		if ("Give up the table")
			if (WWinput(user, "Give up the table? Its coin stays in it, and the next to claim it gets it.", "Money changer", "Cancel", list("Give it up", "Cancel")) != "Give it up" || !is_keeper(user))
				return
			owner_account = ""
			owner_name = ""
			rates = list()
			locked = FALSE

/obj/structure/closet/crate/money_changer/attackby(obj/item/W, mob/living/human/user)
	if (!istype(W, /obj/item/stack/money) || !istype(user) || !length(owner_account))
		return ..()
	var/obj/item/stack/money/M = W
	if (!M.is_metal_coin())
		to_chat(user, SPAN_WARNING("The table changes struck metal coin only."))
		return TRUE
	if (is_keeper(user))
		if (opened)
			return ..()
		user.drop_from_inventory(M)
		M.forceMove(src)
		to_chat(user, SPAN_NOTICE("You put [M.amount] [M.name] in the till."))
		return TRUE
	return change_coins(M, user)

// The table buys coins from user at its rate and pays in the issuer they pick.
/obj/structure/closet/crate/money_changer/proc/change_coins(obj/item/stack/money/M, mob/living/human/user)
	var/issuer = M.issuer
	if (!(issuer in rates))
		to_chat(user, SPAN_WARNING("The table doesn't buy [changer_issuer_label(issuer)]."))
		return TRUE
	var/amount = M.amount
	var/worth = round(amount * M.value, 0.1)
	var/percent = rates[issuer]
	var/owed = round(worth * percent / 100, 0.1)
	var/list/options = list()
	var/list/held = list()
	for (var/obj/item/stack/money/S in stock())
		held[S.issuer] = TRUE
	for (var/out in held)
		var/can = coin_pay_from(stock(out), owed, null, TRUE)
		if (can >= owed - 0.05)
			options["[changer_issuer_label(out)]"] = out
	if (!options.len || owed <= 0)
		to_chat(user, SPAN_WARNING("The table can't make up [weighed_silver_text(owed)] for your [M.name] from its till."))
		return TRUE
	var/pick = WWinput(user, "Your [amount] [M.name] weigh in at [weighed_silver_text(worth)]. The table pays [percent]% of that: [weighed_silver_text(owed)]. Paid in which coin?", "Change coins", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options))
		return TRUE
	// The coins, the rate and the till are checked again after the prompt.
	if (QDELETED(M) || QDELETED(src) || M.amount != amount || M.issuer != issuer || rates[issuer] != percent || !user.Adjacent(src) || !(M in list(user.get_active_hand(), user.get_inactive_hand())))
		return TRUE
	var/out_issuer = options[pick]
	if (coin_pay_from(stock(out_issuer), owed, null, TRUE) < owed - 0.05)
		to_chat(user, SPAN_WARNING("The till no longer holds enough [pick]."))
		return TRUE
	user.drop_from_inventory(M)
	M.forceMove(src)
	var/paid = coin_pay_from(stock(out_issuer), owed, user)
	visible_message(SPAN_NOTICE("[user] changes [amount] [M.name] for [weighed_silver_text(paid)] in [pick] at \the [src]."))
	log_game("[key_name(user)] changed [amount] [M.name] for [paid] silver in [pick] at a money changer kept by [owner_name] ([x],[y],[z]).")
	return TRUE

#undef CHANGER_RATE_MAX
#undef CHANGER_RATES_MAX
