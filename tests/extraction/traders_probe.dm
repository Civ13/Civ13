// Extraction currency traders: ECB reference rates, round pinning, notes,
// payment and change, and whole trades through a real private-room account.
/obj/map_metadata/extraction_survival
	var/test_trade_confirmation = TRUE
	confirm_trade(mob/living/human/H, title, text)
		return test_trade_confirmation

/proc/traders_ecb_xml(date, gbp)
	return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><gesmes:Envelope><Cube><Cube time='[date]'><Cube currency='USD' rate='1.0812'/><Cube currency='GBP' rate='[gbp]'/><Cube currency='CHF' rate='0.9421'/></Cube></Cube></gesmes:Envelope>"

/proc/traders_notes_total(list/items, currency)
	. = 0
	for (var/obj/item/I in items)
		var/list/spec = extraction_currency_notes()[I.type]
		if (spec && spec["currency"] == currency) . += extraction_note_face(I)

/proc/extraction_traders_fx_probe()
	var/datum/extraction_fx/fx = new
	fx.fetching = FALSE
	fx.cache_loaded = TRUE
	var/day = fx.date_day("2026-11-06")
	equipment_assert(day == fx.date_day("2026-11-05") + 1 && fx.date_day("2000-01-01") == 0 && fx.date_day("2024-03-01") - fx.date_day("2024-02-28") == 2, "calendar day numbers count leap days")
	var/list/S = fx.parse(traders_ecb_xml("2026-11-06", "0.87710"), "2026-11-06 16:30:00")
	equipment_assert(S && S["base"] == "EUR" && S["rates"]["GBP"] == "0.87710" && S["effective"] == "2026-11-06" && fx.valid(S), "ECB daily reference rates parse with provider, date and exact quote")
	equipment_assert(fx.quote(S, "GBP") == 0.8771 && fx.quote(S, "EUR") == 1, "pounds per euro kept in the provider's direction")
	equipment_assert(!fx.parse(traders_ecb_xml("2026-11-06", "0"), "x") && !fx.parse(traders_ecb_xml("2026-11-06", "-0.8"), "x") && !fx.parse(traders_ecb_xml("2026-11-06", "abc"), "x") && !fx.parse(traders_ecb_xml("2026-13-06", "0.8771"), "x") && !fx.parse(replacetext(traders_ecb_xml("2026-11-06", "0.8771"), "GBP", "XXX"), "x") && !fx.parse("<html>error</html>", "x"), "zero, negative, malformed, misdated and missing rates are refused")
	var/list/tampered = json_decode(json_encode(S))
	tampered["rates"]["GBP"] = "1.00000"
	equipment_assert(!fx.valid(tampered), "an edited cached rate no longer matches its snapshot id")
	equipment_assert(fx.usable(S, day + 3) && !fx.stale(S, day + 3), "rates three days old are fresh")
	equipment_assert(fx.usable(S, day + 6) && fx.stale(S, day + 6) && findtext(fx.describe(S, day + 6), "STALE"), "rates six days old still trade but are labelled stale")
	equipment_assert(!fx.usable(S, day + 8) && !fx.usable(S, day - 3), "rates over a week old, or dated in the future, are refused")
	equipment_assert(fx.accept(S, FALSE) && fx.round_snapshot(day + 1) == S, "the round pins its first usable snapshot")
	var/list/newer = fx.parse(traders_ecb_xml("2026-11-07", "0.90000"), "2026-11-07 16:30:00")
	equipment_assert(fx.accept(newer, FALSE) && fx.latest == newer && fx.round_snapshot(day + 2) == S, "a refreshed snapshot waits for the next round")
	equipment_assert(!fx.accept(S, FALSE) && fx.latest == newer, "an older snapshot never replaces a newer one")
	equipment_assert(isnull(fx.round_snapshot(day + 9)) && findtext(fx.describe(null), "closed"), "once the pinned rates are too old, trading stops instead of silently repricing")

	// Prices: rounded up when you pay, down when you are paid; the fee and spreads
	// keep every loop below its start.
	equipment_assert(-round(-fx.from_base(S, 120, "GBP")) == 106 && round(fx.from_base(S, 30, "GBP")) == 26, "120 euros of value cost £106; 30 euros of value pay £26")
	var/old = extraction_fx
	extraction_fx = fx
	equipment_assert(extraction_exchange_amount(S, 100, "EUR", "GBP") == 83 && extraction_exchange_amount(S, 100, "GBP", "EUR") == 108 && extraction_exchange_amount(S, 100, "CR", "EUR") == 95, "exchange converts at the reference rate less 5%")
	equipment_assert(!extraction_exchange_amount(S, 100, "EUR", "EUR") && !extraction_exchange_amount(S, 0, "EUR", "GBP") && !extraction_exchange_amount(S, 50001, "EUR", "GBP") && !extraction_exchange_amount(S, 2.5, "EUR", "GBP"), "same-currency, empty, oversized and fractional exchanges are refused")
	var/list/currencies = list("EUR", "GBP", "CR")
	for (var/from in currencies)
		for (var/target in currencies)
			if (from == target) continue
			for (var/amount in 1 to 400)
				var/back = extraction_exchange_amount(S, extraction_exchange_amount(S, amount, from, target), target, from)
				if (back >= amount)
					equipment_assert(FALSE, "changing [amount] [from] to [target] and back made no loss ([back])")
	extraction_fx = old

/proc/extraction_traders_money_probe(obj/map_metadata/extraction_survival/M)
	var/list/made = extraction_make_notes("GBP", 87)
	equipment_assert(traders_notes_total(made, "GBP") == 87 && made.len == 5, "£87 is paid out as 50, 20, 10, 5 and two 1s ([made.len] stacks)")
	for (var/obj/item/I in made) qdel(I)
	made = extraction_make_notes("EUR", 1234)
	equipment_assert(traders_notes_total(made, "EUR") == 1234, "large payouts use whole stacks of the largest notes")
	for (var/obj/item/I in made) qdel(I)
	equipment_assert(!extraction_make_notes("EUR", -1) && !extraction_make_notes("EUR", 1.5) && !length(extraction_make_notes("EUR", 0)), "negative and fractional payouts are refused")
	var/obj/item/stack/money/european/euro/ones = new(null, 3, FALSE)
	ones.amount = 3
	var/obj/item/stack/money/european/euro50/fifty = new(null, 1, FALSE)
	var/list/plan = extraction_payment_plan(list(fifty, ones), 10)
	equipment_assert(plan && plan["take"][ones] == 3 && plan["take"][fifty] == 1 && plan["paid"] == 53 && plan["change"] == 43, "smallest notes go first and change is owed")
	equipment_assert(!extraction_payment_plan(list(ones), 10) && !extraction_payment_plan(list(ones, fifty), 0), "short or empty payments are refused")
	var/list/graph = M.codec.encode(fifty)
	equipment_assert(graph && M.codec.validate(graph), "banknotes are stash equipment")
	var/list/bad = json_decode(json_encode(graph))
	bad["nodes"][1]["scalars"]["amount"] = 501
	equipment_assert(!M.codec.validate(bad), "an oversized note stack is refused")
	qdel(ones)
	qdel(fifty)
	// No trader sells anything for less than twice what any trader pays for it.
	var/list/traders = extraction_specialist_traders()
	for (var/seller in traders)
		for (var/list/entry in traders[seller]["stock"])
			var/obj/item/product = extraction_trader_product(entry)
			var/list/product_graph = M.codec.encode(product)
			equipment_assert(product_graph && M.codec.validate(product_graph), "[entry["label"]] is supported stash equipment")
			for (var/buyer in traders)
				var/value = 0
				for (var/list/node in product_graph["nodes"])
					value += extraction_trader_policy.value(node, traders[buyer]["policy"])
				equipment_assert(round(value * traders[buyer]["spread_bps"] / 10000) * 2 <= entry["price"], "[buyer] pays at most half of [seller]'s price for [entry["label"]]")
			qdel(product)

/proc/extraction_traders_session_probe(obj/map_metadata/extraction_survival/M)
	var/old = extraction_fx
	var/datum/extraction_fx/fx = new
	fx.fetching = FALSE
	fx.cache_loaded = TRUE
	fx.accept(fx.parse(traders_ecb_xml(time2text(world.realtime, "YYYY-MM-DD"), "0.87710"), "probe"), FALSE)
	extraction_fx = fx
	var/mob/living/human/H = new(locate(3,3,1))
	H.m_intent = "stealth"
	M.test_owners[H] = "currencytrader"
	equipment_assert(M.admit(H), "trader customer admitted to a private room")
	var/datum/extraction_session/S = H.extraction_session
	H.forceMove(get_turf(S.house))
	var/turf/room = get_turf(S.house)
	new /obj/item/stack/money/european/euro20(room, 2, FALSE)
	new /obj/item/stack/money/european/euro(room, 3, FALSE)
	equipment_assert(M.save_home(S) && M.money_total(S, "EUR") == 43 && M.money_total(S, "GBP") == 0, "loose euros in the room are counted")
	var/list/armourer = extraction_specialist_traders()["armourer"]
	equipment_assert(!M.trader_buy(H, "armourer", 1, "GBP") && !M.trader_buy(H, "quartermaster", 1, "GBP"), "the armourer refuses pounds and nobody takes money you lack")
	M.test_trade_confirmation = FALSE
	equipment_assert(!M.trader_buy(H, "armourer", 1, "EUR") && M.money_total(S, "EUR") == 43, "a declined quote takes nothing")
	M.test_trade_confirmation = TRUE
	var/stash_before = S.profile["stash"].len
	equipment_assert(M.trader_buy(H, "armourer", 1, "EUR"), "[armourer["stock"][1]["label"]] bought for euros")
	equipment_assert(M.money_total(S, "EUR") == 23, "the magazine cost exactly €20 and change came back (left [M.money_total(S, "EUR")])")
	var/obj/item/ammo_magazine/ak47/mag = locate() in room
	equipment_assert(mag && json_encode(M.records(M.home_roots(S))) == json_encode(S.profile["stash"]) && S.profile["stash"].len >= stash_before, "the purchase and the change are in the saved stash")
	equipment_assert(!M.trader_buy(H, "armourer", 5, "EUR"), "house level gates the rifle")

	// Selling wood to the quartermaster pays pounds at the reference rate.
	var/obj/item/stack/material/wood/wood = new(room, 10, FALSE)
	equipment_assert(M.save_home(S), "wood saved to the stash")
	equipment_assert(!M.trader_sell(H, "armourer", wood, "EUR") && !M.trader_sell(H, "quartermaster", wood, "EUR"), "the armourer won't buy wood and the quartermaster won't pay euros")
	equipment_assert(M.trader_sell(H, "quartermaster", wood, "GBP") && QDELETED(wood), "wood sold to the quartermaster")
	equipment_assert(M.money_total(S, "GBP") == 4, "10 wood is worth €5 to him, paid as £4 at 0.8771 (got £[M.money_total(S, "GBP")])")

	// The fence changes the pounds back into euros, less 5%.
	equipment_assert(M.trader_exchange(H, 4, "GBP", "EUR") && M.money_total(S, "GBP") == 0 && M.money_total(S, "EUR") == 27, "£4 changes into €4")
	equipment_assert(!M.trader_exchange(H, 100, "EUR", "GBP") && M.money_total(S, "EUR") == 27, "you cannot change money you do not have")

	// Stale rates close the traders.
	fx.pinned = fx.parse(traders_ecb_xml("2020-01-02", "0.85000"), "old")
	equipment_assert(!M.trader_buy(H, "armourer", 1, "EUR") && M.money_total(S, "EUR") == 27, "pinned rates over a week old stop all trades")
	var/euros = M.money_total(S, "EUR")
	equipment_assert(M.release(S) && M.admit(H), "the money survives release and reload")
	S = H.extraction_session
	equipment_assert(M.money_total(S, "EUR") == euros, "reloaded room holds the same euros")
	equipment_assert(M.release(S), "trader fixture releases its account")
	M.round_participants -= "currencytrader"
	qdel(H)
	extraction_fx = old

/proc/extraction_traders_probe(obj/map_metadata/extraction_survival/M)
	extraction_traders_fx_probe()
	extraction_traders_money_probe(M)
	extraction_traders_session_probe(M)
