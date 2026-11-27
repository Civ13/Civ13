// Faction mints (docs/coin-mint.md). Coins are no longer crafted from a sheet
// anywhere: they are struck at an anvil with a coin die that a faction leader
// cut for the faction. Each coin stack carries its issuer and its fineness
// (how much of each coin is the named metal), and stacks only merge with
// stacks of the same issuer and fineness.
//
// A coin weighs one shekel (weighed_money.dm), so a full-weight sheet strikes
// MINT_COINS_PER_SHEET coins. A silver or gold coin may be debased: at
// fineness f, each sheet of precious metal strikes 10/f coins and the rest of
// every coin is copper, which the minter must supply. A coin's value (what
// benches, forges and the trading balance count) is its metal content, so a
// debased coin is worth less than it claims; the trading balance shows it.
// The issuer keeps the difference, which is the only profit in money making,
// made from players' own metal. Nothing here creates metal or money.
//
// Saved: issuer and fineness on each stack (plain vars), issuer on each die.
// Nothing sleeps except the striking prompts and do_after, which recheck.

#define MINT_COINS_PER_SHEET 10
#define MINT_STRIKE_TIME 20 // deciseconds per sheet
#define MINT_ISSUER_MAX 40

/obj/item/stack/money
	var/issuer = "" // faction whose die struck it; "" for unmarked coin
	var/fineness = 1 // share of each coin that is the named metal

// Metal coins only; other money types keep the old behaviour.
/obj/item/stack/money/proc/is_metal_coin()
	return !isnull(coin_metal())

/obj/item/stack/money/proc/coin_metal()
	if (istype(src, /obj/item/stack/money/coppercoin))
		return "copper"
	if (istype(src, /obj/item/stack/money/silvercoin))
		return "silver"
	if (istype(src, /obj/item/stack/money/goldcoin))
		return "gold"
	return null

/proc/mint_fineness_clean(value)
	if (!isnum(value) || value <= 0 || value > 1)
		return 1
	return round(value, 0.01)

// Value follows metal content: the named metal for its share, copper for the rest.
/obj/item/stack/money/proc/apply_coin_mark(new_issuer, new_fineness)
	var/metal = coin_metal()
	if (isnull(metal))
		return
	issuer = istext(new_issuer) ? copytext(new_issuer, 1, MINT_ISSUER_MAX + 1) : ""
	fineness = metal == "copper" ? 1 : mint_fineness_clean(new_fineness)
	var/base = initial(value)
	value = base * fineness + 0.1 * (1 - fineness)
	if (length(issuer))
		name = "[issuer] [metal] coins"
		singular_name = "[issuer] [metal] coin"
		desc = "[capitalize(metal)] coins struck with the mark of [issuer]."
	else
		name = initial(name)
		singular_name = initial(singular_name)
		desc = "Unmarked [metal] coins."

/obj/item/stack/money/after_load()
	..()
	if (is_metal_coin())
		apply_coin_mark(issuer, fineness)

/obj/item/stack/proc/stack_compatible(obj/item/stack/S)
	return arcane_same_virtue(src, S)

/obj/item/stack/money/stack_compatible(obj/item/stack/S)
	var/obj/item/stack/money/M = S
	if (!istype(M) || M.type != type)
		return FALSE
	if (is_metal_coin())
		return M.issuer == issuer && M.fineness == fineness
	return TRUE

// Different currencies never merge either.
/obj/item/stack/money/fiat/stack_compatible(obj/item/stack/S)
	var/obj/item/stack/money/fiat/F = S
	return istype(F) && F.fiat_id == fiat_id

/obj/item/stack/merge(obj/item/stack/S)
	if (!S || !stack_compatible(S) || !S.stack_compatible(src))
		return 0
	return ..()

/obj/item/stack/transfer_to(obj/item/stack/S, var/_amount=null)
	if (!S || !stack_compatible(S) || !S.stack_compatible(src))
		return FALSE
	return ..()

/obj/item/stack/money/split(var/_amount)
	var/obj/item/stack/money/S = ..()
	if (istype(S) && is_metal_coin())
		S.apply_coin_mark(issuer, fineness)
	return S

// --- The die ----------------------------------------------------------------

/obj/item/coin_die
	name = "coin die"
	desc = "A bronze die for striking coins at an anvil. A faction leader can cut it with the faction's mark."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "stamp-blank"
	w_class = ITEM_SIZE_TINY
	var/issuer = ""

/obj/item/coin_die/proc/update_die_name()
	if (length(issuer))
		name = "coin die of [issuer]"
		desc = "A bronze die cut with the mark of [issuer]. Use it on copper, silver or gold sheets beside an anvil to strike coins."
	else
		name = initial(name)
		desc = initial(desc)

/obj/item/coin_die/after_load()
	..()
	update_die_name()

/obj/item/coin_die/attack_self(mob/living/human/user)
	if (!istype(user) || !map)
		return
	if (length(issuer))
		to_chat(user, SPAN_NOTICE("This die strikes coins of [issuer]. Use it on copper, silver or gold sheets beside an anvil."))
		return
	var/faction = user.civilization
	if (!faction || faction == "none" || !map.faction_power(user, faction, "mint"))
		to_chat(user, SPAN_NOTICE("Only a faction's leader, or an officer it trusts with the mint, can cut this die with the faction's mark."))
		return
	var/choice = WWinput(user, "Cut this die with the mark of [faction]? Anyone holding it can then strike [faction]'s coins.", "Coin die", "Cancel", list("Cut it", "Cancel"))
	if (choice != "Cut it" || length(issuer) || user.get_active_hand() != src || user.civilization != faction || !map.faction_power(user, faction, "mint"))
		return
	issuer = faction
	update_die_name()
	to_chat(user, SPAN_NOTICE("You cut the die with the mark of [faction]."))
	log_game("[key_name(user)] cut a coin die for [faction].")

// Rename the faction's dies and coins with it.
/obj/map_metadata/proc/coin_issuer_rename(old_name, new_name)
	for (var/obj/item/coin_die/D in coin_dies)
		if (D.issuer == old_name)
			D.issuer = new_name
			D.update_die_name()

var/global/list/coin_dies = list()

/obj/item/coin_die/New()
	..()
	coin_dies |= src

/obj/item/coin_die/Destroy()
	coin_dies -= src
	return ..()

// --- Striking ---------------------------------------------------------------

/proc/mint_coin_type(metal)
	switch (metal)
		if ("copper")
			return /obj/item/stack/money/coppercoin
		if ("silver")
			return /obj/item/stack/money/silvercoin
		if ("gold")
			return /obj/item/stack/money/goldcoin
	return null

// Coins struck from sheets at fineness, and the copper sheets they need.
/proc/mint_yield(sheets, fineness)
	fineness = mint_fineness_clean(fineness)
	var/coins = round(sheets * MINT_COINS_PER_SHEET / fineness)
	var/copper = coins > 0 ? -round(-(coins * (1 - fineness)) / MINT_COINS_PER_SHEET) : 0
	return list(coins, copper)

/proc/mint_anvil_near(mob/user)
	for (var/obj/structure/anvil/A in range(1, user))
		return A
	return null

// Copper sheets the minter can use: in their hands or at their feet.
/proc/mint_copper_supply(mob/user, obj/item/stack/exclude)
	var/list/found = list()
	var/turf/feet = get_turf(user)
	var/list/places = list(user.get_active_hand(), user.get_inactive_hand())
	if (feet)
		places += feet.contents
	for (var/obj/item/stack/material/copper/C in places)
		if (C != exclude && !QDELETED(C) && C.amount > 0)
			found |= C
	return found

/proc/mint_copper_count(list/supply)
	var/total = 0
	for (var/obj/item/stack/material/copper/C in supply)
		total += C.amount
	return total

/obj/item/coin_die/afterattack(atom/target, mob/user, proximity, params)
	if (!proximity || !istype(target, /obj/item/stack/material))
		return ..()
	strike(target, user)
	return TRUE

/obj/item/coin_die/proc/strike(obj/item/stack/material/S, mob/living/human/user)
	if (!istype(user) || !S || !S.material)
		return FALSE
	var/metal = S.material.name
	var/coin_type = mint_coin_type(metal)
	if (!coin_type)
		to_chat(user, SPAN_WARNING("Coins are struck from copper, silver or gold."))
		return FALSE
	if (!length(issuer))
		to_chat(user, SPAN_WARNING("The die has no mark yet. A faction leader must cut it first."))
		return FALSE
	var/obj/structure/anvil/A = mint_anvil_near(user)
	if (!A)
		to_chat(user, SPAN_WARNING("You need an anvil beside you to strike coins."))
		return FALSE
	var/sheets = S.amount
	if (sheets > 1)
		var/asked = player_input(user, "Strike how many sheets of [metal]? (You have [S.amount])", "Strike coins", S.amount, "num", null, TRUE)
		if (!isnum(asked) || asked < 1)
			return FALSE
		sheets = min(round(asked), S.amount)
	var/fineness = 1
	if (metal != "copper")
		var/list/options = list("Full weight (100%)" = 1, "90% fine" = 0.9, "75% fine" = 0.75, "Half silver, half copper (50%)" = 0.5)
		if (metal == "gold")
			options = list("Full weight (100%)" = 1, "90% fine" = 0.9, "75% fine" = 0.75, "Half gold, half copper (50%)" = 0.5)
		var/pick = WWinput(user, "How fine should the coins be? Anything less than full weight needs copper sheets in your hands or at your feet for the rest.", "Strike coins", "Full weight (100%)", options + "Cancel")
		if (!pick || pick == "Cancel" || !(pick in options))
			return FALSE
		fineness = options[pick]
	var/list/yield = mint_yield(sheets, fineness)
	var/coins = yield[1]
	var/copper_needed = yield[2]
	if (copper_needed && mint_copper_count(mint_copper_supply(user, S)) < copper_needed)
		to_chat(user, SPAN_WARNING("Those coins need [copper_needed] copper sheet[copper_needed == 1 ? "" : "s"] as well, in your hands or at your feet."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts striking coins at \the [A]."), SPAN_NOTICE("You start striking [coins] coins of [issuer]."))
	if (!do_after(user, min(MINT_STRIKE_TIME * sheets, 200), A))
		return FALSE
	// Everything may have changed during the wait.
	if (QDELETED(S) || S.amount < sheets || user.get_active_hand() != src || !mint_anvil_near(user) || get_dist(user, S) > 1)
		to_chat(user, SPAN_WARNING("You stop striking."))
		return FALSE
	var/list/supply = mint_copper_supply(user, S)
	if (copper_needed && mint_copper_count(supply) < copper_needed)
		to_chat(user, SPAN_WARNING("You no longer have the copper for those coins."))
		return FALSE
	var/left = copper_needed
	for (var/obj/item/stack/material/copper/C in supply)
		if (left <= 0)
			break
		var/take = min(left, C.amount)
		C.use(take)
		left -= take
	var/turf/T = get_turf(A)
	S.use(sheets)
	var/remaining = coins
	while (remaining > 0)
		var/obj/item/stack/money/M = new coin_type(T)
		var/batch = min(remaining, M.max_amount)
		M.amount = batch
		M.apply_coin_mark(issuer, fineness)
		M.update_icon()
		remaining -= batch
	to_chat(user, SPAN_NOTICE("You strike [coins] [metal] coins of [issuer][fineness < 1 ? ", [fineness * 100]% fine" : ""]."))
	log_game("[key_name(user)] struck [coins] [metal] coins of [issuer] at [fineness * 100]% fine from [sheets] sheet(s) and [copper_needed] copper sheet(s) at ([A.x],[A.y],[A.z]).")
	return TRUE

#undef MINT_COINS_PER_SHEET
#undef MINT_STRIKE_TIME
#undef MINT_ISSUER_MAX
