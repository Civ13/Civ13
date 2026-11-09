// Extraction specialist traders deal in real pounds and euros. Their relative
// value comes from the European Central Bank euro reference rates, as required by
// docs/extraction-economy-contract.md ("Real-world currency valuation").
//
// Base currency: EUR. Credit mapping civ13.extraction.credit-base.v1: one game
// credit is valued as one euro of base value. Trader spreads and the exchange fee
// are separate from the recorded rate.

#define EXTRACTION_FX_PROVIDER "European Central Bank euro foreign exchange reference rates"
#define EXTRACTION_FX_URL "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"
#define EXTRACTION_FX_CACHE "data/extraction_fx_snapshot.json"
#define EXTRACTION_CREDIT_BASE "civ13.extraction.credit-base.v1"
// The ECB publishes on TARGET working days only, so a weekend plus a holiday
// leaves the newest rate four days old. Older rates are labelled stale, and new
// trades are refused once the round's rates are more than a week old.
#define EXTRACTION_FX_FRESH_DAYS 4
#define EXTRACTION_FX_MAX_STALE_DAYS 7
#define EXTRACTION_FX_REFRESH 216000
#define EXTRACTION_TRADE_QUOTE_LIFETIME 1200
#define EXTRACTION_TRADE_MAX_FACE 50000
#define EXTRACTION_EXCHANGE_FEE_BPS 500

var/datum/extraction_fx/extraction_fx = new
var/datum/extraction_trade_policy/extraction_trader_policy = new

// Explicit allowlist: item type -> ISO 4217 code and face value of one item.
// Stack count multiplies the face value; sprites never do.
/proc/extraction_currency_notes()
	var/static/list/notes = list(
		/obj/item/stack/money/european/britpound = list("currency" = "GBP", "face" = 1),
		/obj/item/stack/money/european/britpound5 = list("currency" = "GBP", "face" = 5),
		/obj/item/stack/money/european/britpound10 = list("currency" = "GBP", "face" = 10),
		/obj/item/stack/money/european/britpound20 = list("currency" = "GBP", "face" = 20),
		/obj/item/stack/money/european/britpound50 = list("currency" = "GBP", "face" = 50),
		/obj/item/stack/money/european/euro = list("currency" = "EUR", "face" = 1),
		/obj/item/stack/money/european/euro2 = list("currency" = "EUR", "face" = 2),
		/obj/item/stack/money/european/euro5 = list("currency" = "EUR", "face" = 5),
		/obj/item/stack/money/european/euro10 = list("currency" = "EUR", "face" = 10),
		/obj/item/stack/money/european/euro20 = list("currency" = "EUR", "face" = 20),
		/obj/item/stack/money/european/euro50 = list("currency" = "EUR", "face" = 50),
		/obj/item/stack/money/european/euro100 = list("currency" = "EUR", "face" = 100),
		/obj/item/stack/money/european/euro200 = list("currency" = "EUR", "face" = 200),
		/obj/item/stack/money/european/euro500 = list("currency" = "EUR", "face" = 500))
	return notes

/proc/extraction_currency_symbol(currency)
	switch (currency)
		if ("EUR") return "€"
		if ("GBP") return "£"
	return ""

/proc/extraction_money_text(currency, amount)
	if (currency == "CR") return "[amount] credits"
	return "[extraction_currency_symbol(currency)][amount]"

/proc/extraction_note_face(obj/item/I)
	if (!istype(I, /obj/item/stack)) return 0
	var/list/spec = extraction_currency_notes()[I.type]
	if (!spec) return 0
	var/obj/item/stack/S = I
	return S.amount * spec["face"]

// New note stacks worth exactly `total`, largest notes first, outside the world.
/proc/extraction_make_notes(currency, total)
	. = list()
	if (!isnum(total) || total < 0 || total > EXTRACTION_TRADE_MAX_FACE || round(total) != total) return null
	var/list/faces = list()
	var/list/notes = extraction_currency_notes()
	for (var/path in notes)
		if (notes[path]["currency"] == currency) faces[path] = notes[path]["face"]
	while (total > 0)
		var/best
		for (var/path in faces)
			if (faces[path] <= total && (!best || faces[path] > faces[best])) best = path
		if (!best) return null
		var/count = min(500, round(total / faces[best]))
		var/obj/item/stack/S = new best(null, count, FALSE)
		S.amount = count
		. += S
		total -= count * faces[best]

// Which notes to hand over for `price`: smallest notes first, whole notes only.
// Returns list("take" = list(note = count), "paid" = face, "change" = face) or null.
/proc/extraction_payment_plan(list/notes, price)
	if (!isnum(price) || price < 1 || price > EXTRACTION_TRADE_MAX_FACE || round(price) != price) return null
	var/list/sorted = list()
	for (var/obj/item/stack/S in notes)
		var/list/spec = extraction_currency_notes()[S.type]
		if (!spec || S.amount < 1) continue
		var/position = sorted.len + 1
		for (var/i in 1 to sorted.len)
			var/obj/item/stack/other = sorted[i]
			if (extraction_currency_notes()[other.type]["face"] > spec["face"])
				position = i
				break
		sorted.Insert(position, S)
	var/list/take = list()
	var/remaining = price
	for (var/obj/item/stack/S in sorted)
		if (remaining <= 0) break
		var/face = extraction_currency_notes()[S.type]["face"]
		var/count = min(S.amount, -round(-remaining / face))
		take[S] = count
		remaining -= count * face
	if (remaining > 0) return null
	return list("take" = take, "paid" = price - remaining, "change" = -remaining)

/proc/extraction_fx_day(year, month, day)
	// Days since 2000-01-01 in the proleptic Gregorian calendar.
	if (month <= 2) year--
	var/era = round(year / 400)
	var/yoe = year - era * 400
	var/doy = round((153 * (month + (month > 2 ? -3 : 9)) + 2) / 5) + day - 1
	var/doe = yoe * 365 + round(yoe / 4) - round(yoe / 100) + doy
	return era * 146097 + doe - 719468 - 10957

/proc/extraction_fx_today()
	return round(world.realtime / 864000)

/datum/extraction_fx
	var/list/latest
	var/list/pinned
	var/datum/http_request/pending
	var/last_attempt
	var/cache_loaded = FALSE
	var/fetching = TRUE
	var/last_error
	var/list/required = list("GBP")

	proc/date_day(effective)
		if (!istext(effective) || length(effective) != 10) return null
		var/regex/R = regex("^(\[0-9]{4})-(\[0-9]{2})-(\[0-9]{2})$")
		if (!R.Find(effective)) return null
		var/year = text2num(R.group[1])
		var/month = text2num(R.group[2])
		var/day = text2num(R.group[3])
		if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) return null
		return extraction_fx_day(year, month, day)

	// Units of currency per one euro, exactly as the provider quotes them.
	proc/quote(list/snapshot, currency)
		if (currency == "EUR" || currency == "CR") return 1
		if (!islist(snapshot) || !islist(snapshot["rates"])) return null
		var/value = text2num(snapshot["rates"][currency])
		if (!isnum(value) || value <= 0 || value != value) return null
		return value

	proc/valid(list/snapshot)
		if (!islist(snapshot) || snapshot["provider"] != EXTRACTION_FX_PROVIDER || snapshot["base"] != "EUR" || !istext(snapshot["fetched"]) || !istext(snapshot["id"])) return FALSE
		if (isnull(date_day(snapshot["effective"])) || !islist(snapshot["rates"])) return FALSE
		for (var/currency in required)
			var/text = snapshot["rates"][currency]
			var/regex/shape = regex("^\[0-9]+\\.\[0-9]+$")
			if (!istext(text) || length(text) > 12 || !shape.Find(text)) return FALSE
			var/value = text2num(text)
			// Sanity band only; the provider's number is never adjusted.
			if (!isnum(value) || value <= 0.2 || value >= 5) return FALSE
		return snapshot["id"] == snapshot_id(snapshot)

	proc/snapshot_id(list/snapshot)
		var/rates = ""
		for (var/currency in required)
			rates += "|[currency]=[snapshot["rates"][currency]]"
		return copytext(md5("[snapshot["provider"]]|[snapshot["effective"]][rates]"), 1, 13)

	// Parses the ECB daily XML. Returns a snapshot or null.
	proc/parse(body, fetched_text)
		if (!istext(body) || length(body) > 65536) return null
		var/regex/when = regex("time=\[\"'](\[0-9]{4}-\[0-9]{2}-\[0-9]{2})\[\"']")
		if (!when.Find(body)) return null
		var/list/snapshot = list("provider" = EXTRACTION_FX_PROVIDER, "source" = EXTRACTION_FX_URL, "base" = "EUR", "effective" = when.group[1], "fetched" = fetched_text, "rates" = list())
		for (var/currency in required)
			var/regex/rate = regex("currency=\[\"'][currency]\[\"']\\s+rate=\[\"'](\[0-9]+\\.\[0-9]+)\[\"']")
			if (!rate.Find(body)) return null
			snapshot["rates"][currency] = rate.group[1]
		snapshot["id"] = snapshot_id(snapshot)
		return valid(snapshot) ? snapshot : null

	proc/age(list/snapshot, today = extraction_fx_today())
		var/day = islist(snapshot) ? date_day(snapshot["effective"]) : null
		return isnull(day) ? null : today - day

	proc/usable(list/snapshot, today = extraction_fx_today())
		if (!valid(snapshot)) return FALSE
		var/days = age(snapshot, today)
		return isnum(days) && days >= -1 && days <= EXTRACTION_FX_MAX_STALE_DAYS

	proc/stale(list/snapshot, today = extraction_fx_today())
		return age(snapshot, today) > EXTRACTION_FX_FRESH_DAYS

	proc/accept(list/snapshot, persist = TRUE)
		if (!valid(snapshot)) return FALSE
		if (latest && date_day(latest["effective"]) > date_day(snapshot["effective"])) return FALSE
		latest = snapshot
		if (persist)
			fdel(EXTRACTION_FX_CACHE)
			text2file(json_encode(snapshot), EXTRACTION_FX_CACHE)
		return TRUE

	proc/load_cache()
		cache_loaded = TRUE
		if (!fexists(EXTRACTION_FX_CACHE)) return FALSE
		var/list/snapshot
		try
			snapshot = json_decode(file2text(EXTRACTION_FX_CACHE))
		catch
			return FALSE
		return accept(snapshot, FALSE)

	// Bounded background refresh, never inside a trade. A refreshed snapshot is
	// kept for the next round; the round keeps the one it pinned.
	proc/poll()
		if (!cache_loaded) load_cache()
		if (pending)
			if (!pending.is_complete()) return
			var/datum/http_response/R = pending.into_response()
			pending = null
			if (R.error || R.status_code != 200)
				last_error = "rate fetch failed ([R.error ? R.error : R.status_code])"
				return
			if (!accept(parse(R.body, time2text(world.realtime, "YYYY-MM-DD hh:mm:ss"))))
				last_error = "rate fetch returned no usable rates"
			return
		if (!fetching || (!isnull(last_attempt) && world.realtime - last_attempt < EXTRACTION_FX_REFRESH)) return
		last_attempt = world.realtime
		pending = new
		pending.prepare(RUSTG_HTTP_METHOD_GET, EXTRACTION_FX_URL)
		pending.begin_async()

	proc/round_snapshot(today = extraction_fx_today())
		if (!pinned)
			if (!cache_loaded) load_cache()
			if (usable(latest, today)) pinned = latest
		return usable(pinned, today) ? pinned : null

	proc/describe(list/snapshot, today = extraction_fx_today())
		if (!snapshot) return "No usable exchange rates are available, so traders are closed. [last_error ? "([last_error])" : ""]"
		var/list/lines = list()
		for (var/currency in required)
			lines += "€1 = [extraction_currency_symbol(currency)][snapshot["rates"][currency]]"
		return "[jointext(lines, ", ")] ([snapshot["provider"]], published [snapshot["effective"]], fetched [snapshot["fetched"]], snapshot [snapshot["id"]][stale(snapshot, today) ? ", STALE" : ""]). Reference rates are not guaranteed market prices."

	// Base value in euros -> exact (unrounded) amount in currency.
	proc/from_base(list/snapshot, euros, currency)
		var/q = quote(snapshot, currency)
		return isnull(q) ? null : euros * q

	proc/to_base(list/snapshot, amount, currency)
		var/q = quote(snapshot, currency)
		return isnull(q) ? null : amount / q

// Trader table. Prices are base values in game credits (= euros of base value);
// the traders charge the converted amount rounded up, and pay rounded down.
/proc/extraction_specialist_traders()
	var/static/list/traders = list(
		"armourer" = list("name" = "Armourer", "policy" = "armorer", "takes" = list("EUR"), "pays" = list("EUR"), "spread_bps" = 5000,
			"about" = "Guns, magazines and armour. Euros only.",
			"stock" = list(
				list("label" = "AKM magazine", "type" = /obj/item/ammo_magazine/ak47, "price" = 20, "level" = 1),
				list("label" = "M9 magazine", "type" = /obj/item/ammo_magazine/m9beretta, "price" = 10, "level" = 1),
				list("label" = "PASGT helmet", "type" = /obj/item/clothing/head/helmet/modern/pasgt, "price" = 50, "level" = 2),
				list("label" = "Carrier vest", "type" = /obj/item/clothing/accessory/armor/nomads/pcarrierblack, "price" = 80, "level" = 2),
				list("label" = "AKM rifle", "type" = /obj/item/weapon/gun/projectile/submachinegun/ak47, "price" = 120, "level" = 2))),
		"quartermaster" = list("name" = "Quartermaster", "policy" = "quartermaster", "takes" = list("GBP"), "pays" = list("GBP"), "spread_bps" = 5000,
			"about" = "Tools, building materials and armour. Pounds only.",
			"stock" = list(
				list("label" = "Wooden handle", "type" = /obj/item/weapon/material/handle, "price" = 10, "level" = 1),
				list("label" = "Iron pickaxe head", "type" = /obj/item/weapon/material/part/pickaxe, "material" = "iron", "price" = 20, "level" = 1),
				list("label" = "Iron shovel head", "type" = /obj/item/weapon/material/part/shovel, "material" = "iron", "price" = 20, "level" = 1),
				list("label" = "Wood bundle", "type" = /obj/item/stack/material/wood, "amount" = 10, "price" = 12, "level" = 1),
				list("label" = "Cloth bundle", "type" = /obj/item/stack/material/cloth, "amount" = 10, "price" = 20, "level" = 1),
				list("label" = "Binding cord", "type" = /obj/item/stack/material/rope, "amount" = 10, "price" = 20, "level" = 1),
				list("label" = "Steel sheets", "type" = /obj/item/stack/material/steel, "amount" = 10, "price" = 30, "level" = 2),
				list("label" = "Kevlar fabric", "type" = /obj/item/stack/material/kevlar, "amount" = 10, "price" = 100, "level" = 3))),
		"medic" = list("name" = "Medic", "policy" = "medic", "takes" = list("EUR", "GBP"), "pays" = list("EUR"), "spread_bps" = 5000,
			"about" = "Bandages and splints. Takes euros or pounds, pays in euros.",
			"stock" = list(
				list("label" = "Cloth bandages", "type" = /obj/item/stack/medical/bruise_pack/bint, "amount" = 5, "price" = 15, "level" = 1),
				list("label" = "Splints", "type" = /obj/item/stack/medical/splint, "amount" = 2, "price" = 20, "level" = 1))),
		"fence" = list("name" = "Fence", "policy" = "fence", "takes" = list("EUR", "GBP"), "pays" = list("EUR", "GBP"), "spread_bps" = 10000, "exchange" = TRUE,
			"about" = "Buys anything cheaply, in euros or pounds, and changes money for a 5% fee.",
			"stock" = list()))
	return traders

// Full-condition base value of one stock entry as the trader policy sees it.
/proc/extraction_trader_product(list/entry)
	var/path = entry["type"]
	var/obj/item/I = new path(null, entry["material"])
	if (istype(I, /obj/item/stack)) I:amount = entry["amount"]
	return I

/obj/map_metadata/extraction_survival/proc/confirm_trade(mob/living/human/H, title, text)
	return WWinput(H, text, title, "Cancel", list("Accept", "Cancel")) == "Accept"

/obj/map_metadata/extraction_survival/proc/money_roots(datum/extraction_session/S, currency)
	. = list()
	for (var/obj/item/stack/I in home_roots(S))
		var/list/spec = extraction_currency_notes()[I.type]
		if (spec && spec["currency"] == currency && !I.extraction_insurance_token && !I.extraction_secure_stored) . += I

/obj/map_metadata/extraction_survival/proc/money_total(datum/extraction_session/S, currency)
	if (currency == "CR") return game_credits(S)
	. = 0
	for (var/obj/item/I in money_roots(S, currency))
		. += extraction_note_face(I)

// What `trader_id` pays for `I`, as base value (euros), or 0 if refused.
/obj/map_metadata/extraction_survival/proc/trader_base_offer(trader_id, obj/item/I, desk = 0)
	var/list/trader = extraction_specialist_traders()[trader_id]
	if (!trader || !I || I.extraction_insurance_token || I.extraction_secure_stored || extraction_currency_notes()[I.type]) return 0
	var/list/graph = codec.encode(I, FALSE, FALSE)
	if (!graph || !codec.validate(graph)) return 0
	var/total = 0
	for (var/list/node in graph["nodes"])
		if (node["insurance_token"]) return 0
		var/value = extraction_trader_policy.value(node, trader["policy"])
		if (!value) return 0
		total += value
	if (total > EXTRACTION_TRADE_MAX_FACE) return 0
	// A safe-house contacts desk adds 5% of the value per level.
	return round(total * (trader["spread_bps"] + desk * 500) / 10000)

// Commits one trade as a single account snapshot, then changes the world to match.
// take: note -> count handed over; sold: items given up; given: new items; credits: delta.
/obj/map_metadata/extraction_survival/proc/trader_commit(datum/extraction_session/S, list/take, list/sold, list/given, credits = 0, list/fields)
	var/list/candidate = S.copy_profile()
	var/list/removed = list()
	var/list/replaced = list()
	for (var/obj/item/stack/note in take)
		if (take[note] >= note.amount)
			removed[note.extraction_item_id] = TRUE
			continue
		var/old = note.amount
		note.amount -= take[note]
		var/list/entry = record_item(note)
		note.amount = old
		if (!entry) return FALSE
		replaced[note.extraction_item_id] = entry
	for (var/obj/item/I in sold)
		removed[I.extraction_item_id] = TRUE
	var/list/stash = list()
	var/list/found = list()
	for (var/list/entry in candidate["stash"])
		if (removed[entry["id"]])
			found[entry["id"]] = TRUE
			continue
		if (replaced[entry["id"]])
			found[entry["id"]] = TRUE
			stash += list(replaced[entry["id"]])
		else stash += list(entry)
	if (found.len != removed.len + replaced.len) return FALSE
	for (var/obj/item/I in given)
		var/list/entry = record_item(I)
		if (!entry || !codec.validate(entry["equipment"])) return FALSE
		stash += list(entry)
	var/balance = game_credits(S) + credits
	if (balance < 0 || balance > 1000000) return FALSE
	candidate["stash"] = stash
	candidate["credits"] = balance
	for (var/key in fields)
		candidate[key] = fields[key]
	if (stash.len > extraction_profile_capacity(candidate)) return FALSE
	S.transitioning = TRUE
	if (!S.commit(candidate))
		S.transitioning = FALSE
		return FALSE
	// The snapshot is durable; now make the room match it.
	var/mob/living/human/H = S.body
	for (var/obj/item/stack/note in take)
		if (take[note] >= note.amount)
			if (note.loc == H) H.unEquip(note, TRUE)
			qdel(note)
		else
			note.amount -= take[note]
			note.update_icon()
	for (var/obj/item/I in sold)
		if (I.loc == H) H.unEquip(I, TRUE)
		qdel(I)
	for (var/obj/item/I in given)
		I.forceMove(get_turf(S.house))
	S.transitioning = FALSE
	return TRUE

/obj/map_metadata/extraction_survival/proc/trade_receipt(datum/extraction_session/S, trader_id, text, list/snapshot)
	log_game("EXTRACTION TRADE: [S.owner] with [trader_id]: [text]; [EXTRACTION_CREDIT_BASE]; FX snapshot [snapshot["id"]] ([snapshot["effective"]])")

/obj/map_metadata/extraction_survival/proc/trader_ready(mob/living/human/H)
	if (!supply_access(H) || !save_home(H.extraction_session)) return null
	return extraction_fx.round_snapshot()

/obj/map_metadata/extraction_survival/proc/trader_still_valid(mob/living/human/H, digest, list/snapshot, expires)
	var/datum/extraction_session/S = H.extraction_session
	return supply_access(H) && world.time <= expires && extraction_fx.round_snapshot() == snapshot && md5(json_encode(S.profile)) == digest && json_encode(records(home_roots(S))) == json_encode(S.profile["stash"])

/obj/map_metadata/extraction_survival/proc/trader_buy(mob/living/human/H, trader_id, index, currency)
	var/list/snapshot = trader_ready(H)
	var/list/trader = extraction_specialist_traders()[trader_id]
	if (!snapshot || !trader || !(currency in trader["takes"]) || !isnum(index) || index < 1 || index > length(trader["stock"])) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	var/list/entry = trader["stock"][index]
	if (S.profile["level"] < entry["level"]) return FALSE
	var/desk = extraction_room_level(S.profile, "contacts")
	var/base_price = entry["price"] * (100 - desk * 5) / 100
	var/exact = extraction_fx.from_base(snapshot, base_price, currency)
	var/price = -round(-exact)
	var/list/plan = extraction_payment_plan(money_roots(S, currency), price)
	if (!plan) return FALSE
	var/digest = md5(json_encode(S.profile))
	var/expires = world.time + EXTRACTION_TRADE_QUOTE_LIFETIME
	var/text = "[entry["label"]] from the [lowertext(trader["name"])]: base value [entry["price"]] credits[desk ? ", less [desk * 5]% for your contacts desk" : ""] = €[base_price]"
	if (currency != "EUR") text += " × [snapshot["rates"][currency]] [currency] per EUR = [extraction_currency_symbol(currency)][round(exact, 0.01)]"
	text += ", rounded up to [extraction_money_text(currency, price)]. You hand over [extraction_money_text(currency, plan["paid"])][plan["change"] ? " and get [extraction_money_text(currency, plan["change"])] change" : ""]. [extraction_fx.describe(snapshot)] This quote holds for two minutes."
	if (!confirm_trade(H, trader["name"], text) || !trader_still_valid(H, digest, snapshot, expires)) return FALSE
	plan = extraction_payment_plan(money_roots(S, currency), price)
	if (!plan) return FALSE
	var/obj/item/product = extraction_trader_product(entry)
	var/list/given = list(product)
	if (plan["change"])
		var/list/change = extraction_make_notes(currency, plan["change"])
		if (!change)
			qdel(product)
			return FALSE
		given += change
	if (!trader_commit(S, plan["take"], list(), given))
		for (var/obj/item/I in given) qdel(I)
		return FALSE
	trade_receipt(S, trader_id, "bought [entry["label"]] for [extraction_money_text(currency, price)]", snapshot)
	to_chat(H, "[entry["label"]] delivered to your room for [extraction_money_text(currency, price)].")
	return TRUE

/obj/map_metadata/extraction_survival/proc/trader_sell(mob/living/human/H, trader_id, obj/item/I, currency)
	var/list/snapshot = trader_ready(H)
	var/list/trader = extraction_specialist_traders()[trader_id]
	var/datum/extraction_session/S = H.extraction_session
	if (!snapshot || !trader || !(currency in trader["pays"]) || !(I in home_roots(S))) return FALSE
	var/desk = extraction_room_level(S.profile, "contacts")
	var/base = trader_base_offer(trader_id, I, desk)
	if (base < 1) return FALSE
	var/exact = extraction_fx.from_base(snapshot, base, currency)
	var/pay = round(exact)
	if (pay < 1) return FALSE
	var/digest = md5(json_encode(S.profile))
	var/expires = world.time + EXTRACTION_TRADE_QUOTE_LIFETIME
	var/text = "The [lowertext(trader["name"])] offers [extraction_money_text(currency, pay)] for [I]: [trader["spread_bps"] < 10000 ? "half of " : ""]its trade value[desk ? " plus [desk * 5]% for your contacts desk" : ""], worth €[base]"
	if (currency != "EUR") text += " × [snapshot["rates"][currency]] [currency] per EUR = [extraction_currency_symbol(currency)][round(exact, 0.01)]"
	text += ", rounded down. [extraction_fx.describe(snapshot)] This offer holds for two minutes."
	if (!confirm_trade(H, trader["name"], text) || !trader_still_valid(H, digest, snapshot, expires) || !(I in home_roots(S)) || trader_base_offer(trader_id, I, desk) != base) return FALSE
	var/list/notes = extraction_make_notes(currency, pay)
	if (!notes) return FALSE
	if (!trader_commit(S, list(), list(I), notes))
		for (var/obj/item/N in notes) qdel(N)
		return FALSE
	trade_receipt(S, trader_id, "sold for [extraction_money_text(currency, pay)]", snapshot)
	to_chat(H, "Sold for [extraction_money_text(currency, pay)]. The money is in your room.")
	return TRUE

// Changes `amount` of `from` (EUR, GBP or game credits CR) into `target`, less the fee.
/proc/extraction_exchange_amount(list/snapshot, amount, from, target)
	if (from == target || !isnum(amount) || amount < 1 || amount > EXTRACTION_TRADE_MAX_FACE || round(amount) != amount) return 0
	var/base = extraction_fx.to_base(snapshot, amount, from)
	var/out = extraction_fx.from_base(snapshot, base, target)
	if (!isnum(out)) return 0
	return round(out * (10000 - EXTRACTION_EXCHANGE_FEE_BPS) / 10000)

/obj/map_metadata/extraction_survival/proc/trader_exchange(mob/living/human/H, amount, from, target)
	var/list/snapshot = trader_ready(H)
	var/list/currencies = list("EUR", "GBP", "CR")
	if (!snapshot || !(from in currencies) || !(target in currencies)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	var/out = extraction_exchange_amount(snapshot, amount, from, target)
	if (out < 1 || money_total(S, from) < amount) return FALSE
	var/digest = md5(json_encode(S.profile))
	var/expires = world.time + EXTRACTION_TRADE_QUOTE_LIFETIME
	var/text = "Change [extraction_money_text(from, amount)] into [extraction_money_text(target, out)]: converted at the reference rate, less the fence's 5% fee, rounded down. Game credits count as one euro each. [extraction_fx.describe(snapshot)] This quote holds for two minutes."
	if (!confirm_trade(H, "Fence", text) || !trader_still_valid(H, digest, snapshot, expires)) return FALSE
	var/list/take = list()
	var/list/given = list()
	var/credits = 0
	if (from == "CR")
		if (game_credits(S) < amount) return FALSE
		credits -= amount
	else
		var/list/plan = extraction_payment_plan(money_roots(S, from), amount)
		if (!plan) return FALSE
		take = plan["take"]
		if (plan["change"]) given += extraction_make_notes(from, plan["change"])
	if (target == "CR") credits += out
	else given += extraction_make_notes(target, out)
	if (!trader_commit(S, take, list(), given, credits))
		for (var/obj/item/I in given) qdel(I)
		return FALSE
	trade_receipt(S, "fence", "changed [extraction_money_text(from, amount)] into [extraction_money_text(target, out)]", snapshot)
	to_chat(H, "Changed [extraction_money_text(from, amount)] into [extraction_money_text(target, out)].")
	return TRUE

/obj/map_metadata/extraction_survival/proc/choose_currency(mob/living/human/H, list/currencies, prompt)
	if (currencies.len == 1) return currencies[1]
	var/list/options = list()
	for (var/currency in currencies)
		options[currency == "EUR" ? "Euros" : (currency == "GBP" ? "Pounds" : "Game credits")] = currency
	return options[WWinput(H, prompt, "Currency", "Cancel", options + list("Cancel"))]

/obj/map_metadata/extraction_survival/proc/manage_traders(mob/living/human/H)
	if (!supply_access(H)) return
	extraction_fx.poll()
	var/list/snapshot = extraction_fx.round_snapshot()
	var/datum/extraction_session/S = H.extraction_session
	var/list/traders = extraction_specialist_traders()
	var/list/names = list()
	for (var/id in traders)
		names["[traders[id]["name"]]: [traders[id]["about"]]"] = id
	var/wallet = "You have [extraction_money_text("EUR", money_total(S, "EUR"))], [extraction_money_text("GBP", money_total(S, "GBP"))] and [game_credits(S)] game credits in your room."
	if (!snapshot)
		to_chat(H, extraction_fx.describe(null))
		return
	var/trader_id = names[WWinput(H, "[wallet] [extraction_fx.describe(snapshot)]", "Traders", "Cancel", names + list("Cancel"))]
	if (!trader_id || !supply_access(H)) return
	var/list/trader = traders[trader_id]
	var/list/actions = list()
	if (length(trader["stock"])) actions += "Buy"
	actions += "Sell"
	if (trader["exchange"]) actions += "Change money"
	var/action = WWinput(H, "[trader["about"]] [wallet]", trader["name"], "Cancel", actions + list("Cancel"))
	if (!supply_access(H)) return
	switch (action)
		if ("Buy")
			var/currency = choose_currency(H, trader["takes"], "Pay in which currency?")
			if (!currency) return
			var/list/options = list()
			var/list/stock = trader["stock"]
			for (var/i in 1 to stock.len)
				var/list/entry = stock[i]
				if (S.profile["level"] < entry["level"]) continue
				options["[entry["label"]] - [extraction_money_text(currency, -round(-extraction_fx.from_base(snapshot, entry["price"] * (100 - extraction_room_level(S.profile, "contacts") * 5) / 100, currency)))]"] = i
			var/index = options[WWinput(H, "Choose what to buy. The price and change are confirmed before payment.", trader["name"], "Cancel", options + list("Cancel"))]
			if (index) trader_buy(H, trader_id, index, currency)
		if ("Sell")
			var/currency = choose_currency(H, trader["pays"], "Be paid in which currency?")
			if (!currency) return
			var/list/options = list()
			for (var/obj/item/I in home_roots(S))
				var/base = trader_base_offer(trader_id, I, extraction_room_level(S.profile, "contacts"))
				var/pay = base ? round(extraction_fx.from_base(snapshot, base, currency)) : 0
				if (pay >= 1) options["[I] - [extraction_money_text(currency, pay)]"] = I
			if (!options.len)
				to_chat(H, "The [lowertext(trader["name"])] wants nothing in your room. Unload guns and empty bags first; insured and secure items are never bought.")
				return
			var/obj/item/I = options[WWinput(H, "Choose what to sell. The offer is confirmed before the sale.", trader["name"], "Cancel", options + list("Cancel"))]
			if (I) trader_sell(H, trader_id, I, currency)
		if ("Change money")
			var/from = choose_currency(H, list("EUR", "GBP", "CR"), "Change from which currency?")
			if (!from) return
			var/list/targets = list("EUR", "GBP", "CR") - from
			var/target = choose_currency(H, targets, "Change into which currency?")
			if (!target) return
			var/amount = input(H, "How much [from == "CR" ? "in game credits" : (from == "EUR" ? "in euros" : "in pounds")]? You have [extraction_money_text(from, money_total(S, from))].", "Change money") as num|null
			if (isnum(amount)) trader_exchange(H, round(amount), from, target)

#undef EXTRACTION_FX_PROVIDER
#undef EXTRACTION_FX_URL
#undef EXTRACTION_FX_CACHE
#undef EXTRACTION_CREDIT_BASE
#undef EXTRACTION_FX_FRESH_DAYS
#undef EXTRACTION_FX_MAX_STALE_DAYS
#undef EXTRACTION_FX_REFRESH
#undef EXTRACTION_TRADE_QUOTE_LIFETIME
#undef EXTRACTION_TRADE_MAX_FACE
#undef EXTRACTION_EXCHANGE_FEE_BPS
