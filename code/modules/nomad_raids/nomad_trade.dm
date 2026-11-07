// Trader caravans. The trader lays goods on the tiles around them. A player
// pays by dropping items at the trader's feet, which credits whoever last
// handled them; picking up a good spends that credit. Taking a good without
// enough credit gets a warning, and keeping it past the grace time turns the
// caravan on the thief. Unspent credit is handed back when the caravan
// packs up.

/proc/nomad_trade_goods(age)
	var/list/goods = list(
		/obj/item/stack/material/leather,
		/obj/item/stack/material/pelt,
		/obj/item/stack/material/bone,
		/obj/item/stack/material/rope,
		/obj/item/stack/medical/bruise_pack/bint,
		/obj/item/weapon/reagent_containers/food/snacks/meat,
	)
	if (age >= 1)
		goods += list(/obj/item/stack/material/bronze, /obj/item/stack/material/cloth)
	if (age >= 2)
		goods += list(/obj/item/stack/material/iron, /obj/item/weapon/material/kitchen/utensil/knife/iron)
	// Seeds travel with every caravan; pills once there is chemistry to make them.
	goods += /obj/item/stack/farming/seeds/tea
	if (age >= 6)
		goods += list(/obj/item/weapon/reagent_containers/pill/penicillin, /obj/item/weapon/reagent_containers/pill/paracetamol)
	return goods

/proc/nomad_trade_price(obj/item/I)
	var/base = I.value
	if (istype(I, /obj/item/stack))
		var/obj/item/stack/S = I
		base = I.value * max(1, S.amount)
	return max(3, round(base) + 2)

// Who paid with an item: the last key that handled it when that player is at
// the stall, else the nearest player there. Gloves leave no prints, so an item
// a gloved player drops still carries whoever touched it before; on Gaia that
// credited a dead player instead of the one standing at the stall.
/datum/nomad_raid/proc/payer_of(obj/item/I)
	var/list/near = nomad_raid_defenders_near(get_turf(leader), 3)
	var/printed = I.fingerprintslast ? ckey(I.fingerprintslast) : null
	if (printed)
		for (var/mob/living/human/H in near)
			if (H.ckey == printed)
				return printed
	var/mob/living/human/nearest = null
	for (var/mob/living/human/H in near)
		if (!nearest || get_dist(H, leader) < get_dist(nearest, leader))
			nearest = H
	if (nearest)
		return nearest.ckey
	return printed

/datum/nomad_raid/proc/begin_trade()
	set_state("trade", "customers in sight")
	set_hostile(FALSE)
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive_members())
		order_halt(M)
	stall = list()
	for (var/turf/T in orange(1, leader))
		if (!T.density && !nomad_raid_ground_error(T))
			stall += T
	var/list/table = nomad_trade_goods(map ? map.ordinal_age : 0)
	// A caravan called for a kind of goods lays out at least half of that kind.
	var/list/asked = wants ? nomad_request_goods(wants, map ? map.ordinal_age : 0) : list()
	var/count = min(NOMAD_TRADE_GOODS, stall.len)
	for (var/i = 1, i <= count, i++)
		var/path = (asked.len && i % 2 == 1) ? pick(asked) : pick(table)
		var/obj/item/I
		if (ispath(path, /obj/item/stack))
			I = new path(stall[i], rand(2, 5), FALSE)
		else
			I = new path(stall[i])
		I.should_save = FALSE // laid out goods vanish if the server restarts mid-visit
		goods[I] = nomad_trade_price(I)
		base_price[I] = goods[I]
	// As with tribute: loose gear already lying near the stall is not payment,
	// even if the trader shuffles onto it; each item is keyed to its turf.
	payment_ignore = list()
	for (var/obj/item/I in range(NOMAD_RAID_PARLEY_RANGE, leader))
		payment_ignore[I] = I.loc
	cue("Traders of the [clan]! Lay payment at my feet, then take what you paid for. Fair prices, no thieves.", "spreads their wares on the ground and gestures at them.")

// Price list for the coordinator and status.
/datum/nomad_raid/proc/goods_list()
	var/list/out = list()
	for (var/obj/item/I in goods)
		out += list(list("ref" = "\ref[I]", "name" = "[I.name]", "price" = goods[I], "base" = base_price[I]))
	return out

/datum/nomad_raid/proc/tick_trade(list/alive, hurt, decide)
	if (hurt)
		cue("Bandits! Guards, to me!")
		pack_up()
		start_assault("attacked at the stall")
		return
	follow_leader(alive, 1)
	if (!decide)
		return
	var/turf/feet = get_turf(leader)
	// Payments.
	for (var/obj/item/I in feet)
		if (payment_ignore[I] == I.loc || (I in goods))
			continue
		var/worth = nomad_raid_worth(I)
		if (!worth)
			continue
		var/who = payer_of(I)
		if (who && nomad_rep_score(who) <= NOMAD_REP_WANTED)
			payment_ignore[I] = I.loc
			event("refused", "[who] is wanted; refused [I.name]")
			cue("I do not deal with thieves. Take that back.", "pushes the offering away with their foot.")
			continue
		if (!who || !leader.take_item(I))
			payment_ignore[I] = I.loc
			continue
		credit[who] = (credit[who] || 0) + worth
		if (!islist(payments[who]))
			payments[who] = list()
		var/list/paid = payments[who]
		paid += I
		event("paid", "[who] paid [I.name] worth [worth]; credit [credit[who]]")
	// Goods leaving the stall.
	for (var/obj/item/I in goods.Copy())
		if (QDELETED(I))
			goods -= I
			continue
		if (isturf(I.loc) && (I.loc in stall))
			for (var/who in thieves.Copy())
				var/list/T = thieves[who]
				if (T[2] == I)
					thieves -= who
					event("returned", "[who] put back [I.name]")
			continue
		var/mob/holder = nomad_raid_holder(I)
		var/who = holder ? holder.ckey : (I.fingerprintslast ? ckey(I.fingerprintslast) : null)
		var/price = nomad_rep_price(goods[I], who)
		if (who && (credit[who] || 0) >= price)
			credit[who] -= price
			goods -= I
			I.should_save = TRUE
			sold++
			spend_payments(who, price)
			event("sold", "[who] bought [I.name] for [price]")
			nomad_rep_record(who, "trade")
			if (world.time >= next_speech)
				cue("A fair trade.")
		else if (who && !thieves[who])
			thieves[who] = list(world.time, I)
			event("theft", "[who] took [I.name] without paying [price]")
			cue("That costs [price]. Pay, or put it back!", "points sharply at [holder ? holder : "the thief"].")
	// Thieves past their grace time.
	for (var/who in thieves.Copy())
		var/list/T = thieves[who]
		if (world.time - T[1] < NOMAD_TRADE_THEFT_GRACE)
			continue
		var/mob/living/thief = nomad_raid_holder(T[2])
		focus = istype(thief, /mob/living) ? thief : null
		nomad_rep_record(who, "theft")
		cue("Thief! Guards, take it back!")
		pack_up()
		start_assault("[who] stole from the stall")
		return
	for (var/mob/living/human/H in nomad_raid_defenders_near(feet, 3))
		visited |= H.ckey
	if (!goods.len || (world.time - state_at > NOMAD_TRADE_TIME && !waiting_for_guests()))
		var/unsold = goods.len // pack_up() empties the stall
		cue(unsold ? "The road calls. Farewell." : "Sold out. Farewell, friends.")
		pack_up()
		set_state("leave", unsold ? "trading time over" : "sold out")

// A caravan aimed at players waits for one of them to come to the stall,
// up to NOMAD_TRADE_WAIT, before packing up unsold goods.
/datum/nomad_raid/proc/waiting_for_guests()
	if (!target_ckeys.len || world.time - state_at > NOMAD_TRADE_WAIT)
		return FALSE
	for (var/ckey in target_ckeys)
		if (ckey in visited)
			return FALSE
	return TRUE

// Payments a sale spent stay with the trader; the rest can be handed back.
/datum/nomad_raid/proc/spend_payments(who, price)
	var/list/paid = payments[who]
	if (!islist(paid))
		return
	var/remaining = credit[who] || 0
	// Keep the newest payments that cover the remaining credit; the rest is spent.
	var/list/keep = list()
	for (var/i = paid.len, i >= 1, i--)
		var/obj/item/I = paid[i]
		if (QDELETED(I))
			continue
		var/worth = nomad_raid_worth(I, TRUE)
		if (worth <= remaining)
			keep.Insert(1, I)
			remaining -= worth
	payments[who] = keep

// Unsold goods are packed away, and unspent payments are handed back.
/datum/nomad_raid/proc/pack_up()
	if (kind != "trade")
		return
	for (var/obj/item/I in goods)
		if (!QDELETED(I) && isturf(I.loc))
			qdel(I)
	goods = list()
	var/turf/feet = leader_ok() ? get_turf(leader) : null
	for (var/who in payments)
		if (!feet || (credit[who] || 0) <= 0)
			continue
		for (var/obj/item/I in payments[who])
			if (!QDELETED(I) && I.loc == leader)
				leader.carried -= I
				I.forceMove(feet)
				event("refund", "handed back [I.name] to [who]")
	payments = list()
	credit = list()
	thieves = list()
	if (feet)
		leader.visible_message(SPAN_NOTICE("[leader] packs up their wares."))
