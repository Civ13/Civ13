// Weighed money (docs/weighed-money.md): before anyone strikes a coin, metal is
// money by weight. A trader's balance weighs metal sheets and coins in
// shekels and says what they are worth in silver, so two traders can agree a
// price like "twenty shekels of copper for a goat".
//
// One shekel is the weight of one coin; a metal sheet weighs
// WEIGHED_SHEKELS_PER_SHEET shekels. Worth is in silver-equivalent, the same
// scale research benches and the resource forge already use for coins
// (copper 0.1, silver 1, gold 4). Players set their own prices: the balance
// only measures. Nothing here buys, sells or creates money.
//
// Nothing here is saved beyond the balance itself, and nothing sleeps.

#define WEIGHED_SHEKELS_PER_SHEET 10

// Silver-equivalent worth of one shekel of each metal, by material name.
var/global/list/weighed_metal_worth = list(
	"lead" = 0.05,
	"copper" = 0.1,
	"tin" = 0.15,
	"bronze" = 0.15,
	"brass" = 0.2,
	"iron" = 0.2,
	"silver" = 1,
	"gold" = 4)

// list(metal, shekels, silver worth) for something a balance can weigh, or null.
/proc/weighed_money_of(obj/item/I)
	if (istype(I, /obj/item/stack/money/coppercoin))
		var/obj/item/stack/money/C = I
		return list("copper", C.amount, C.amount * C.value)
	if (istype(I, /obj/item/stack/money/silvercoin))
		var/obj/item/stack/money/C = I
		return list("silver", C.amount, C.amount * C.value)
	if (istype(I, /obj/item/stack/money/goldcoin))
		var/obj/item/stack/money/C = I
		return list("gold", C.amount, C.amount * C.value)
	if (istype(I, /obj/item/stack/material))
		var/obj/item/stack/material/S = I
		var/metal = S.material ? S.material.name : null
		if (!istext(metal) || !(metal in weighed_metal_worth))
			return null
		var/shekels = S.amount * WEIGHED_SHEKELS_PER_SHEET
		return list(metal, shekels, shekels * weighed_metal_worth[metal])
	return null

/proc/weighed_silver_text(worth)
	worth = round(worth, 0.1)
	return "[worth] silver"

/proc/weighed_money_line(obj/item/I)
	var/list/W = weighed_money_of(I)
	if (!W)
		return null
	var/metal = W[1]
	var/obj/item/stack/money/C = I
	if (istype(C) && C.fineness < 1)
		metal = "debased [metal] ([round(C.fineness * 100)]% fine)"
	return "[I.name]: [W[2]] shekel[W[2] == 1 ? "" : "s"] of [metal], worth [weighed_silver_text(W[3])]"

// Totals a list of items: list(silver worth, lines, unweighed count).
/proc/weighed_money_total(list/items)
	var/worth = 0
	var/list/lines = list()
	var/unweighed = 0
	for (var/obj/item/I in items)
		var/list/W = weighed_money_of(I)
		if (!W)
			unweighed++
			continue
		worth += W[3]
		lines += weighed_money_line(I)
	return list(worth, lines, unweighed)

/obj/item/weighing_balance
	name = "trading balance"
	desc = "A small balance with two pans and a set of stone weights. Use it on metal or coins to weigh them in shekels and see their worth in silver, or on a barter mat to weigh both offers."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "gem_scale"
	w_class = ITEM_SIZE_SMALL
	value = 2

/obj/item/weighing_balance/afterattack(atom/target, mob/user, proximity, params)
	if (!proximity || !user)
		return ..()
	if (istype(target, /obj/structure/barter_mat))
		var/obj/structure/barter_mat/M = target
		to_chat(user, M.weighed_offers_text())
		return TRUE
	if (istype(target, /obj/item))
		var/line = weighed_money_line(target)
		if (line)
			to_chat(user, SPAN_NOTICE("You weigh it. [line]."))
		else
			to_chat(user, SPAN_NOTICE("\The [target] is not metal or coin; the balance tells you nothing about its worth."))
		return TRUE
	return ..()

/obj/item/weighing_balance/attack_self(mob/user)
	var/obj/item/other = user ? user.get_inactive_hand() : null
	if (!other)
		to_chat(user, SPAN_NOTICE("Hold metal or coins in your other hand, or use the balance on them."))
		return
	var/line = weighed_money_line(other)
	if (line)
		to_chat(user, SPAN_NOTICE("You weigh it. [line]."))
	else
		to_chat(user, SPAN_NOTICE("\The [other] is not metal or coin; the balance tells you nothing about its worth."))

// --- The barter mat ---------------------------------------------------------

/obj/structure/barter_mat/proc/weighed_offers_text()
	tidy()
	if (!traders.len)
		return SPAN_NOTICE("Nothing is offered on \the [src].")
	var/list/lines = list()
	for (var/mob/T in traders)
		var/list/total = weighed_money_total(offers[T])
		var/list/item_lines = total[2]
		var/text = "[T] offers metal worth [weighed_silver_text(total[1])]"
		if (item_lines.len)
			text += " ([jointext(item_lines, "; ")])"
		if (total[3])
			text += ", plus [total[3]] other thing[total[3] == 1 ? "" : "s"] the balance cannot price"
		lines += "[text]."
	return SPAN_NOTICE(jointext(lines, "<br>"))

// Weighing on the mat must not lay the balance down as an offer.
/obj/structure/barter_mat/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weighing_balance))
		to_chat(user, weighed_offers_text())
		return TRUE
	return ..()

#undef WEIGHED_SHEKELS_PER_SHEET
