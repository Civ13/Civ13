// Specialist traders. An outside dealer keeps a trading post. Each dealer takes
// only some kinds of coin and buys and sells only their own kinds of goods:
//
// - the armourer: weapons, ammunition and armour, for silver or gold coins
// - the apothecary: medicine and drugs, for copper or silver coins
// - the scrap dealer: ores, metal and tools, for copper coins only
// - the provisioner: food, seeds, cloth, hides and clothing, for copper or silver
// - the jeweller: gems, pearls and precious metal, for gold; also changes coins
//
// Prices are counted in copper coins (1 silver = 10 copper, 1 gold = 40 copper).
// A dealer sells at a fixed price and buys back at half an item's value, scaled
// by its condition and never above half of what any dealer sells it for, so
// goods cannot be traded round in circles for profit. Every dealer of a kind is
// the same person: all posts of a kind share one stock and one purse, refilled
// every SPECIALIST_TRADER_RESTOCK. Stock follows the age, and a dealer will not
// sell what the buyer's faction has not researched.

#define SPECIALIST_TRADER_RESTOCK 36000 // one hour
#define SPECIALIST_TRADER_BUY_RATE 0.5

var/global/list/specialist_traders = null
// type path => lowest price per unit any dealer sells it at
var/global/list/specialist_trader_sell_floor = null

/proc/specialist_trader_get(id)
	if (!specialist_traders)
		specialist_traders = list()
		specialist_trader_sell_floor = list()
		for (var/path in subtypesof(/datum/specialist_trader))
			var/datum/specialist_trader/T = new path
			specialist_traders[T.id] = T
			T.prices = list()
			for (var/list/entry in T.catalogue)
				T.prices += T.sale_price(entry)
			for (var/i = 1, i <= T.catalogue.len, i++)
				var/list/entry = T.catalogue[i]
				var/item_path = entry[1]
				var/unit_price = T.prices[i] / max(1, entry[2])
				if (isnull(specialist_trader_sell_floor[item_path]) || unit_price < specialist_trader_sell_floor[item_path])
					specialist_trader_sell_floor[item_path] = unit_price
	return specialist_traders[id]

// Copper coins one coin is worth, or 0 for anything a dealer does not count as coin.
/proc/specialist_trader_coin_units(path)
	if (ispath(path, /obj/item/stack/money/coppercoin))
		return 1
	if (ispath(path, /obj/item/stack/money/silvercoin))
		return 10
	if (ispath(path, /obj/item/stack/money/goldcoin))
		return 40
	return 0

/proc/specialist_trader_coin_root(path)
	if (ispath(path, /obj/item/stack/money/coppercoin))
		return /obj/item/stack/money/coppercoin
	if (ispath(path, /obj/item/stack/money/silvercoin))
		return /obj/item/stack/money/silvercoin
	if (ispath(path, /obj/item/stack/money/goldcoin))
		return /obj/item/stack/money/goldcoin
	return null

/proc/specialist_trader_coin_name(path)
	switch (specialist_trader_coin_units(path))
		if (1)
			return "copper"
		if (10)
			return "silver"
		if (40)
			return "gold"
	return "?"

// Writes an amount out in the given coins, largest first ("2 gold, 5 silver").
/proc/specialist_trader_price_text(units, list/coins)
	var/list/sorted = specialist_trader_sort_coins(coins)
	var/list/parts = list()
	for (var/path in sorted)
		var/each = specialist_trader_coin_units(path)
		var/count = round(units / each)
		if (count > 0)
			parts += "[count] [specialist_trader_coin_name(path)]"
			units -= count * each
	if (units > 0)
		parts += "[units] copper"
	if (!parts.len)
		return "nothing"
	return jointext(parts, ", ")

// Largest coin first.
/proc/specialist_trader_sort_coins(list/coins)
	var/list/left = coins.Copy()
	. = list()
	while (left.len)
		var/best = left[1]
		for (var/path in left)
			if (specialist_trader_coin_units(path) > specialist_trader_coin_units(best))
				best = path
		. += best
		left -= best

// Makes coins worth `units` at `where`, largest first. Returns what could not
// be paid in these coins (always less than the smallest of them).
/proc/specialist_trader_make_coins(atom/where, units, list/coins, list/made = null)
	for (var/path in specialist_trader_sort_coins(coins))
		var/each = specialist_trader_coin_units(path)
		var/count = round(units / each)
		units -= count * each
		while (count > 0)
			var/obj/item/stack/money/proto = path
			var/batch = min(count, initial(proto.max_amount))
			// Not merged into coins already lying there, so each new stack holds
			// exactly what it was made with.
			var/obj/item/stack/money/M = new path(where, batch, FALSE)
			M.update_icon()
			count -= batch
			if (made)
				made += M
	return units

// Coins a buyer can pay with: those held and those in pockets.
/proc/specialist_trader_purse_of(mob/living/human/H, list/coins)
	. = list()
	for (var/obj/item/stack/money/M in list(H.l_hand, H.r_hand, H.l_store, H.r_store))
		var/root = specialist_trader_coin_root(M.type)
		if (root && (root in coins) && M.amount > 0)
			. += M

/proc/specialist_trader_purse_total(list/stacks)
	. = 0
	for (var/obj/item/stack/money/M in stacks)
		. += M.amount * specialist_trader_coin_units(M.type)

// -- the dealers -----------------------------------------------------------------

/datum/specialist_trader
	var/id = null
	var/title = "dealer"
	var/dealer = "someone"
	var/greeting = "What'll it be?"
	var/deals_in_text = ""
	// Coins the dealer takes as payment.
	var/list/accepts = list()
	// Coins the dealer pays out with.
	var/list/pays = list()
	// Goods the dealer buys (type roots) and those roots' exceptions.
	var/list/buys = list()
	var/list/refuses = list()
	// Copper a kind of goods is worth when an item has no value of its own;
	// the most specific matching type wins.
	var/list/usual_worth = list()
	// Lowest condition (health / maxhealth) the dealer buys at.
	var/min_condition = 0.5
	// list(type path, amount, first age, last age, price in copper, stock per restock)
	var/list/catalogue = list()
	var/purse_per_restock = 3000
	var/primary_color = "#7a5230"
	var/secondary_color = "#d9c48f"

	// What each catalogue entry sells for: its listed price, or half again its
	// worth when that is more.
	var/list/prices = null

	var/tmp/purse = 0
	var/tmp/next_restock = 0
	var/tmp/list/stock_left = null

/datum/specialist_trader/proc/restock_if_due()
	if (stock_left && world.time < next_restock)
		return
	purse = purse_per_restock
	stock_left = list()
	for (var/i = 1, i <= catalogue.len, i++)
		var/list/entry = catalogue[i]
		stock_left += entry[6]
	next_restock = world.time + SPECIALIST_TRADER_RESTOCK

/datum/specialist_trader/proc/smallest_unit(list/coins)
	. = 0
	for (var/path in coins)
		var/each = specialist_trader_coin_units(path)
		if (!. || each < .)
			. = each

/datum/specialist_trader/proc/deals_in(obj/item/I)
	if (!I)
		return FALSE
	for (var/path in refuses)
		if (istype(I, path))
			return FALSE
	for (var/path in buys)
		if (istype(I, path))
			return TRUE
	return FALSE

// Whether an entry is on sale now (age), and to this buyer (research).
/datum/specialist_trader/proc/entry_in_season(list/entry)
	var/age = map ? map.ordinal_age : 0
	return age >= entry[3] && age <= entry[4]

/datum/specialist_trader/proc/entry_researched(list/entry, mob/living/human/H)
	if (!map)
		return TRUE
	var/node = get_recipe_node_req("[entry[1]]")
	if (!node)
		return TRUE
	return map.is_node_done(H ? H.civilization : null, node)

// Better terms from the buyer's own standing with the dealer; nothing yet.
/datum/specialist_trader/proc/rate_bonus(mob/living/human/H)
	return 0

// Whether anything is packed inside an item. Empty pockets and plain
// accessories do not count; a holster with a gun in it does.
/proc/specialist_trader_holds_goods(atom/A)
	for (var/obj/item/inner in A.contents)
		if (istype(inner, /obj/item/weapon/storage))
			if (inner.contents.len)
				return TRUE
		else if (istype(inner, /obj/item/clothing/accessory))
			if (specialist_trader_holds_goods(inner))
				return TRUE
		else
			return TRUE
	return FALSE

// Full worth of one item (one unit of a stack) in copper: its own value, else
// what the dealer reckons that kind of goods is worth.
/datum/specialist_trader/proc/worth_of(obj/item/I)
	if (I.value > 0)
		return I.value * 10
	return usual_worth_of(I.type)

/datum/specialist_trader/proc/usual_worth_of(item_path)
	var/best_path = null
	for (var/path in usual_worth)
		if (ispath(item_path, path) && (!best_path || ispath(path, best_path)))
			best_path = path
	return best_path ? usual_worth[best_path] : 0

/datum/specialist_trader/proc/sale_price(list/entry)
	var/obj/item/proto = entry[1]
	var/each = initial(proto.value) > 0 ? initial(proto.value) * 10 : usual_worth_of(entry[1])
	var/unit = smallest_unit(accepts)
	var/least = -round(-(each * entry[2] * 1.5) / unit) * unit
	return max(entry[5], least)

/proc/specialist_trader_condition(obj/item/I)
	if (isnum(I.health) && isnum(I.maxhealth) && I.maxhealth > 0)
		return clamp(I.health / I.maxhealth, 0, 1)
	return 1

// What the dealer pays for an item, in copper; a text reason when refused.
/datum/specialist_trader/proc/offer_for(obj/item/I, mob/living/human/H)
	if (!deals_in(I))
		return "I don't deal in that."
	if (istype(I, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = I
		if (!G.configuration_unloaded())
			return "Unload it first."
	else if (specialist_trader_holds_goods(I))
		return "Empty it first."
	var/condition = specialist_trader_condition(I)
	if (condition < min_condition)
		return "That's too worn for me."
	var/amount = 1
	if (istype(I, /obj/item/stack))
		var/obj/item/stack/S = I
		amount = max(1, S.amount)
	var/rate = SPECIALIST_TRADER_BUY_RATE + rate_bonus(H)
	var/price = worth_of(I) * amount * rate * condition
	specialist_trader_get(id) // the sell floor is built with the dealers
	var/floor_price = specialist_trader_sell_floor[I.type]
	if (!isnull(floor_price))
		price = min(price, floor_price * amount * SPECIALIST_TRADER_BUY_RATE)
	var/unit = smallest_unit(pays)
	price = round(price / unit) * unit
	if (price <= 0)
		return "That's not worth my coin."
	return price

// -- the post ----------------------------------------------------------------------

/obj/structure/specialist_trader
	name = "trading post"
	desc = "A trading post kept by an outside dealer."
	icon = 'icons/obj/vending.dmi'
	icon_state = "market_stall"
	layer = 2.9
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/trader_id = null
	var/tmp/busy = FALSE

/obj/structure/specialist_trader/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/specialist_trader/New()
	..()
	var/datum/specialist_trader/T = trader()
	if (T)
		name = "[T.title]'s post"
		desc = "[T.dealer], [T.title], trades here in [T.deals_in_text]. Pays for goods in [specialist_trader_coin_list_text(T.pays)]; takes [specialist_trader_coin_list_text(T.accepts)]."
		var/image/primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		primary.color = T.primary_color
		var/image/secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		secondary.color = T.secondary_color
		overlays += primary
		overlays += secondary

/obj/structure/specialist_trader/after_load()
	..()
	busy = FALSE

/proc/specialist_trader_coin_list_text(list/coins)
	var/list/names = list()
	for (var/path in specialist_trader_sort_coins(coins))
		names += specialist_trader_coin_name(path)
	return "[english_list(names, and_text = " or ")] coins"

/obj/structure/specialist_trader/proc/trader()
	return trader_id ? specialist_trader_get(trader_id) : null

/obj/structure/specialist_trader/proc/can_deal(mob/living/human/H)
	return istype(H) && H.stat == CONSCIOUS && !H.restrained() && Adjacent(H)

/obj/structure/specialist_trader/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	show_stock(H)

/obj/structure/specialist_trader/proc/show_stock(mob/living/human/H)
	var/datum/specialist_trader/T = trader()
	if (!T || !can_deal(H))
		return
	T.restock_if_due()
	var/held = specialist_trader_purse_total(specialist_trader_purse_of(H, T.accepts))
	var/minutes = max(1, round((T.next_restock - world.time) / 600))
	var/list/rows = list()
	rows += "<b>[T.dealer]</b>, [T.title]: <i>\"[T.greeting]\"</i><br>"
	rows += "Deals in [T.deals_in_text]. Takes [specialist_trader_coin_list_text(T.accepts)] held in your hands or pockets; you have [specialist_trader_price_text(held, T.accepts)].<br>"
	rows += "To sell, hit the post with the goods. Buying money left: [specialist_trader_price_text(T.purse, T.pays)]. New stock in [minutes] minute\s.<hr>"
	var/shown = 0
	for (var/i = 1, i <= T.catalogue.len, i++)
		var/list/entry = T.catalogue[i]
		if (!T.entry_in_season(entry))
			continue
		shown++
		var/path = entry[1]
		var/atom/proto = path
		var/item_name = initial(proto.name)
		var/label = entry[2] > 1 ? "[entry[2]] x [item_name]" : "[item_name]"
		var/price = specialist_trader_price_text(T.prices[i], T.accepts)
		if (T.stock_left[i] <= 0)
			rows += "[label]: [price] <i>(sold out)</i><br>"
		else if (!T.entry_researched(entry, H))
			rows += "[label]: [price] <i>(your people have not researched it)</i><br>"
		else
			rows += "[label]: [price], [T.stock_left[i]] left <a href='?src=\ref[src];buy=[i]'>Buy</a><br>"
	if (!shown)
		rows += "<i>Nothing for sale in this age.</i><br>"
	if (istype(T, /datum/specialist_trader/jeweller))
		rows += "<hr>Hit the post with copper, silver or gold coins to change them (5% fee).<br>"
	H << browse(jointext(rows, ""), "window=specialist_trader;size=520x480")

/obj/structure/specialist_trader/Topic(href, href_list)
	..()
	var/mob/living/human/H = usr
	if (!href_list["buy"] || !can_deal(H))
		return
	var/datum/specialist_trader/T = trader()
	if (!T || busy)
		return
	busy = TRUE
	buy(H, text2num(href_list["buy"]))
	busy = FALSE
	show_stock(H)

/obj/structure/specialist_trader/proc/buy(mob/living/human/H, index)
	var/datum/specialist_trader/T = trader()
	T.restock_if_due()
	if (!isnum(index) || index < 1 || index > T.catalogue.len)
		return FALSE
	var/list/entry = T.catalogue[index]
	if (!T.entry_in_season(entry) || T.stock_left[index] <= 0)
		to_chat(H, "<span class='warning'>[T.dealer] has none of that to sell.</span>")
		return FALSE
	if (!T.entry_researched(entry, H))
		to_chat(H, "<span class='warning'>Your people would not know what to do with that yet.</span>")
		return FALSE
	var/price = T.prices[index]
	if (!specialist_trader_take_payment(H, price, T.accepts, get_turf(H)))
		to_chat(H, "<span class='warning'>That costs [specialist_trader_price_text(price, T.accepts)], in [specialist_trader_coin_list_text(T.accepts)]. Hold them or keep them in your pockets.</span>")
		return FALSE
	T.stock_left[index]--
	var/path = entry[1]
	var/atom/proto = path
	var/list/goods = list()
	if (ispath(path, /obj/item/stack))
		var/obj/item/stack/S = new path(get_turf(H), entry[2], FALSE)
		S.update_icon()
		goods += S
	else
		for (var/n = 1, n <= entry[2], n++)
			goods += new path(get_turf(H))
	for (var/obj/item/I in goods)
		H.put_in_hands(I)
	log_game("Specialist trader: [key_name(H)] bought [entry[2]] x [path] from the [T.title] for [price] copper at [x],[y],[z]")
	to_chat(H, "<span class='notice'>You buy [entry[2] > 1 ? "[entry[2]] x " : ""][initial(proto.name)] from [T.dealer] for [specialist_trader_price_text(price, T.accepts)].</span>")
	return TRUE

// Takes `price` copper's worth of the buyer's accepted coins, smallest coins
// first, and hands back change. Nothing is taken when they cannot pay.
/proc/specialist_trader_take_payment(mob/living/human/H, price, list/coins, atom/change_to)
	var/list/stacks = specialist_trader_purse_of(H, coins)
	if (specialist_trader_purse_total(stacks) < price)
		return FALSE
	// Smallest coins first, so change is rarely needed.
	var/list/ordered = list()
	for (var/path in specialist_trader_sort_coins(coins))
		for (var/obj/item/stack/money/M in stacks)
			if (specialist_trader_coin_root(M.type) == path)
				ordered.Insert(1, M)
	var/taken = 0
	for (var/obj/item/stack/money/M in ordered)
		if (taken >= price)
			break
		var/each = specialist_trader_coin_units(M.type)
		var/count = min(M.amount, -round(-(price - taken) / each))
		taken += count * each
		if (count >= M.amount)
			H.drop_from_inventory(M)
			qdel(M)
		else
			M.use(count)
			M.update_icon()
	var/change = taken - price
	if (change > 0)
		var/list/made = list()
		var/left = specialist_trader_make_coins(change_to, change, coins, made)
		if (left > 0)
			specialist_trader_make_coins(change_to, left, list(/obj/item/stack/money/coppercoin), made)
		for (var/obj/item/stack/money/M in made)
			H.put_in_hands(M)
	return TRUE

/obj/structure/specialist_trader/attackby(obj/item/W, mob/living/human/H)
	var/datum/specialist_trader/T = trader()
	if (!T || !istype(H) || H.a_intent == I_HARM)
		return ..()
	if (busy)
		return
	busy = TRUE
	if (istype(T, /datum/specialist_trader/jeweller) && specialist_trader_coin_root(W.type))
		change_coins(H, W)
	else if (istype(W, /obj/item/stack/money) && specialist_trader_coin_root(W.type))
		to_chat(H, "<span class='notice'>[T.dealer] waves the coins away: \"Pick what you want from the stock, and pay then.\"</span>")
	else
		sell(H, W)
	busy = FALSE

/obj/structure/specialist_trader/proc/sell(mob/living/human/H, obj/item/I, confirm = TRUE)
	var/datum/specialist_trader/T = trader()
	T.restock_if_due()
	var/offer = T.offer_for(I, H)
	if (!isnum(offer))
		to_chat(H, "<span class='warning'>[T.dealer]: \"[offer]\"</span>")
		return FALSE
	if (offer > T.purse)
		to_chat(H, "<span class='warning'>[T.dealer]: \"I'd give you [specialist_trader_price_text(offer, T.pays)], but I'm short until my next delivery.\"</span>")
		return FALSE
	if (confirm)
		var/choice = alert(H, "[T.dealer] offers [specialist_trader_price_text(offer, T.pays)] for [I].", T.title, "Sell", "Keep")
		if (choice != "Sell" || !can_deal(H) || I.loc != H)
			return FALSE
		T.restock_if_due()
		if (T.offer_for(I, H) != offer || offer > T.purse)
			to_chat(H, "<span class='warning'>The price has changed; try again.</span>")
			return FALSE
	T.purse -= offer
	log_game("Specialist trader: [key_name(H)] sold [I] ([I.type]) to the [T.title] for [offer] copper at [x],[y],[z]")
	H.drop_from_inventory(I)
	qdel(I)
	var/list/made = list()
	specialist_trader_make_coins(get_turf(H), offer, T.pays, made)
	for (var/obj/item/stack/money/M in made)
		H.put_in_hands(M)
	to_chat(H, "<span class='notice'>[T.dealer] pays you [specialist_trader_price_text(offer, T.pays)].</span>")
	return TRUE

// The jeweller changes coins into another kind, keeping a twentieth.
/obj/structure/specialist_trader/proc/change_coins(mob/living/human/H, obj/item/stack/money/M, target = null)
	var/root = specialist_trader_coin_root(M.type)
	var/list/options = list()
	for (var/path in list(/obj/item/stack/money/coppercoin, /obj/item/stack/money/silvercoin, /obj/item/stack/money/goldcoin))
		if (path != root)
			options[specialist_trader_coin_name(path)] = path
	if (!target)
		var/choice = input(H, "Change your [M] into which coins? The jeweller keeps a twentieth.", "Jeweller") as null|anything in options
		if (!choice || !can_deal(H) || M.loc != H)
			return FALSE
		target = options[choice]
	var/units = M.amount * specialist_trader_coin_units(M.type)
	var/fee = -round(-units / 20)
	var/left = units - fee
	var/each = specialist_trader_coin_units(target)
	if (left < each)
		to_chat(H, "<span class='warning'>That isn't enough for a single [specialist_trader_coin_name(target)] coin.</span>")
		return FALSE
	H.drop_from_inventory(M)
	qdel(M)
	var/list/made = list()
	var/rest = specialist_trader_make_coins(get_turf(H), left, list(target), made)
	specialist_trader_make_coins(get_turf(H), rest, list(/obj/item/stack/money/silvercoin, /obj/item/stack/money/coppercoin), made)
	for (var/obj/item/stack/money/C in made)
		H.put_in_hands(C)
	log_game("Specialist trader: [key_name(H)] changed [units] copper's worth of coin into [target] at [x],[y],[z]")
	to_chat(H, "<span class='notice'>The jeweller counts out your change, keeping [specialist_trader_price_text(fee, list(/obj/item/stack/money/coppercoin, /obj/item/stack/money/silvercoin))].</span>")
	return TRUE

/obj/structure/specialist_trader/armourer
	trader_id = "armourer"
/obj/structure/specialist_trader/apothecary
	trader_id = "apothecary"
/obj/structure/specialist_trader/scrap_dealer
	trader_id = "scrap_dealer"
/obj/structure/specialist_trader/provisioner
	trader_id = "provisioner"
/obj/structure/specialist_trader/jeweller
	trader_id = "jeweller"

// -- catalogues ---------------------------------------------------------------------
// list(type path, amount, first age, last age, least price in copper, stock per restock)

/datum/specialist_trader/armourer
	id = "armourer"
	title = "armourer"
	dealer = "Brannoc Vell"
	greeting = "Steel, shot and shell. Silver or gold, nothing smaller."
	deals_in_text = "weapons, ammunition and armour"
	accepts = list(/obj/item/stack/money/silvercoin, /obj/item/stack/money/goldcoin)
	pays = list(/obj/item/stack/money/goldcoin, /obj/item/stack/money/silvercoin)
	buys = list(/obj/item/weapon/gun, /obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/stack/ammopart, /obj/item/clothing/suit/armor, /obj/item/clothing/head/helmet, /obj/item/weapon/shield, /obj/item/weapon/material/sword, /obj/item/weapon/material/spear)
	refuses = list(/obj/item/clothing/head/helmet/gold_crown, /obj/item/clothing/head/helmet/silver_crown)
	usual_worth = list(/obj/item/weapon/gun = 300, /obj/item/ammo_magazine = 20, /obj/item/ammo_casing = 2, /obj/item/stack/ammopart = 1, /obj/item/clothing/suit/armor = 150, /obj/item/clothing/head/helmet = 60, /obj/item/weapon/shield = 60, /obj/item/weapon/material/sword = 100, /obj/item/weapon/material/spear = 30)
	min_condition = 0.5
	purse_per_restock = 3000
	primary_color = "#5b5f66"
	secondary_color = "#9c2a22"
	catalogue = list(
		list(/obj/item/ammo_casing/arrow, 10, 0, 4, 20, 6),
		list(/obj/item/weapon/material/spear, 1, 0, 3, 40, 3),
		list(/obj/item/clothing/head/helmet/leather, 1, 0, 3, 40, 3),
		list(/obj/item/clothing/head/helmet/medieval, 1, 2, 4, 120, 2),
		list(/obj/item/ammo_casing/musketball, 10, 3, 4, 30, 5),
		list(/obj/item/stack/ammopart/bullet, 20, 4, 9, 40, 6),
		list(/obj/item/stack/ammopart/casing/rifle, 20, 4, 9, 40, 6),
		list(/obj/item/stack/ammopart/casing/pistol, 20, 4, 9, 30, 6),
		list(/obj/item/clothing/head/helmet/ww2, 1, 5, 7, 150, 2),
		list(/obj/item/clothing/head/helmet/kevlarhelmet, 1, 8, 9, 300, 2),
	)

/datum/specialist_trader/apothecary
	id = "apothecary"
	title = "apothecary"
	dealer = "Ysolde Marrow"
	greeting = "Mind the jars. Copper or silver, dear."
	deals_in_text = "medicine and drugs"
	accepts = list(/obj/item/stack/money/coppercoin, /obj/item/stack/money/silvercoin)
	pays = list(/obj/item/stack/money/silvercoin, /obj/item/stack/money/coppercoin)
	buys = list(/obj/item/stack/medical, /obj/item/weapon/reagent_containers/pill, /obj/item/weapon/reagent_containers/syringe)
	usual_worth = list(/obj/item/stack/medical = 4, /obj/item/weapon/reagent_containers/pill = 8, /obj/item/weapon/reagent_containers/syringe = 10)
	min_condition = 0.25
	purse_per_restock = 1500
	primary_color = "#3f6b4a"
	secondary_color = "#e8e2c8"
	catalogue = list(
		list(/obj/item/stack/medical/bruise_pack/bint, 5, 0, 5, 15, 8),
		list(/obj/item/stack/medical/splint, 2, 3, 9, 30, 4),
		list(/obj/item/stack/medical/bruise_pack/gauze, 5, 5, 9, 25, 8),
		list(/obj/item/weapon/reagent_containers/pill/paracetamol, 1, 6, 9, 20, 6),
		list(/obj/item/weapon/reagent_containers/pill/penicillin, 1, 6, 9, 50, 4),
		list(/obj/item/stack/medical/advanced/bruise_pack, 1, 7, 9, 80, 3),
	)

/datum/specialist_trader/scrap_dealer
	id = "scrap_dealer"
	title = "scrap dealer"
	dealer = "Old Tobin Rusk"
	greeting = "Copper only. I don't trust anything shinier."
	deals_in_text = "ores, metal, rope, glass and tools"
	accepts = list(/obj/item/stack/money/coppercoin)
	pays = list(/obj/item/stack/money/coppercoin)
	buys = list(/obj/item/stack/ore, /obj/item/stack/material, /obj/item/weapon/hammer, /obj/item/weapon/wrench, /obj/item/weapon/wirecutters, /obj/item/weapon/screwdriver, /obj/item/weapon/crowbar)
	refuses = list(/obj/item/stack/material/cloth, /obj/item/stack/material/leather, /obj/item/stack/material/pelt, /obj/item/stack/material/gold, /obj/item/stack/material/silver)
	usual_worth = list(/obj/item/stack/ore = 2, /obj/item/stack/material = 2, /obj/item/weapon/hammer = 15, /obj/item/weapon/wrench = 15, /obj/item/weapon/wirecutters = 15, /obj/item/weapon/screwdriver = 15, /obj/item/weapon/crowbar = 15)
	min_condition = 0
	purse_per_restock = 1500
	primary_color = "#6e4b2a"
	secondary_color = "#b07a3c"
	catalogue = list(
		list(/obj/item/stack/material/rope, 5, 0, 9, 10, 5),
		list(/obj/item/stack/material/copper, 5, 1, 9, 25, 6),
		list(/obj/item/stack/material/tin, 5, 1, 9, 25, 4),
		list(/obj/item/stack/material/iron, 5, 2, 9, 30, 6),
		list(/obj/item/stack/material/lead, 5, 3, 9, 25, 4),
		list(/obj/item/stack/material/glass, 5, 3, 9, 20, 4),
		list(/obj/item/stack/ore/coal, 10, 3, 9, 20, 5),
		list(/obj/item/stack/material/steel, 5, 4, 9, 60, 6),
		list(/obj/item/weapon/wrench, 1, 4, 9, 30, 2),
		list(/obj/item/weapon/crowbar, 1, 4, 9, 30, 2),
	)

/datum/specialist_trader/provisioner
	id = "provisioner"
	title = "provisioner"
	dealer = "Hesk Dunmore"
	greeting = "Fresh as it comes out here. Copper or silver."
	deals_in_text = "food, drink, seeds, cloth, hides and clothing"
	accepts = list(/obj/item/stack/money/coppercoin, /obj/item/stack/money/silvercoin)
	pays = list(/obj/item/stack/money/silvercoin, /obj/item/stack/money/coppercoin)
	buys = list(/obj/item/weapon/reagent_containers/food/snacks, /obj/item/weapon/reagent_containers/food/drinks, /obj/item/stack/farming/seeds, /obj/item/stack/material/cloth, /obj/item/stack/material/leather, /obj/item/stack/material/pelt, /obj/item/clothing)
	refuses = list(/obj/item/clothing/suit/armor, /obj/item/clothing/head/helmet)
	usual_worth = list(/obj/item/weapon/reagent_containers/food/snacks = 6, /obj/item/weapon/reagent_containers/food/drinks = 6, /obj/item/stack/farming/seeds = 1, /obj/item/stack/material/cloth = 2, /obj/item/stack/material/leather = 3, /obj/item/stack/material/pelt = 4, /obj/item/clothing = 20)
	min_condition = 0.25
	purse_per_restock = 1500
	primary_color = "#8a6d1f"
	secondary_color = "#4e7a2e"
	catalogue = list(
		list(/obj/item/weapon/reagent_containers/food/snacks/meat, 1, 0, 9, 8, 6),
		list(/obj/item/stack/farming/seeds/wheat, 5, 0, 9, 10, 5),
		list(/obj/item/stack/farming/seeds/potato, 5, 0, 9, 10, 5),
		list(/obj/item/stack/farming/seeds/tea, 3, 0, 9, 15, 3),
		list(/obj/item/stack/material/leather, 5, 0, 9, 20, 5),
		list(/obj/item/stack/material/cloth, 5, 1, 9, 15, 6),
		list(/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread, 1, 3, 9, 12, 4),
		list(/obj/item/weapon/reagent_containers/food/snacks/MRE, 1, 6, 9, 60, 4),
	)

/datum/specialist_trader/jeweller
	id = "jeweller"
	title = "jeweller"
	dealer = "Corvina Ashgrove"
	greeting = "Gold for gold, darling. Everything else, I'll change for you."
	deals_in_text = "gems, pearls, gold valuables and precious metal"
	accepts = list(/obj/item/stack/money/goldcoin)
	pays = list(/obj/item/stack/money/goldcoin)
	buys = list(/obj/item/stack/money/gems, /obj/item/stack/money/pearls, /obj/item/stack/money/goldvaluables, /obj/item/stack/money/goldnugget, /obj/item/stack/material/gold, /obj/item/stack/material/silver, /obj/item/clothing/head/helmet/gold_crown, /obj/item/clothing/head/helmet/silver_crown)
	usual_worth = list(/obj/item/stack/material/gold = 60, /obj/item/stack/material/silver = 15, /obj/item/clothing/head/helmet/gold_crown = 800, /obj/item/clothing/head/helmet/silver_crown = 400)
	min_condition = 0
	purse_per_restock = 4000
	primary_color = "#2b2350"
	secondary_color = "#d4af37"
	catalogue = list(
		list(/obj/item/stack/money/gems, 1, 0, 9, 560, 2),
		list(/obj/item/stack/money/pearls, 1, 0, 9, 720, 2),
	)

#undef SPECIALIST_TRADER_RESTOCK
#undef SPECIALIST_TRADER_BUY_RATE
