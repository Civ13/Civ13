// NPC Vendors — Human traders (mob version, Pepelsibirsk-style)
// Setting: The Art of the Deal (1990s organized crime)

/mob/living/simple_animal/npc_vendor
	name = "NPC (Do not use!)"
	icon = 'icons/mob/npcs.dmi'
	faction = "Civilization"
	maxHealth = 200
	health = 200
	speak_chance = 1
	move_to_delay = 4
	wander = FALSE
	stop_automated_movement = FALSE
	response_help = "nudges"
	response_disarm = "shoves"
	response_harm = "hits"
	universal_speak = TRUE
	density = TRUE
	var/list/products = list()
	var/list/prices = list()
	var/cooldown_shop = 0

/mob/living/simple_animal/npc_vendor/bullet_act(var/obj/item/projectile/P)
	if (P && P.invisibility <= 0)
		respond_to_attack(P.firer)
	return ..()

/mob/living/simple_animal/npc_vendor/attackby(obj/item/W, mob/living/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
			respond_to_attack(user)
	return ..()

/mob/living/simple_animal/npc_vendor/proc/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	if (speak && speak.len)
		src.say(pick(speak))

/mob/living/simple_animal/npc_vendor/death()
	..()

/mob/living/simple_animal/npc_vendor/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
		respond_to_attack(user)
		return
	if (world.time < cooldown_shop)
		src.say("Patience, come back later.")
		return
	cooldown_shop = world.time + 50
	if (speak && speak.len)
		src.say(pick(speak))
	show_shop(H)

/mob/living/simple_animal/npc_vendor/proc/show_shop(mob/living/human/H)
	return

/mob/living/simple_animal/npc_vendor/proc/build_shop_html(shop_content, mob/living/human/H)
	var/total_money = 0
	for (var/obj/item/stack/money/M in H.contents)
		total_money += M.value * M.amount

	var/dat = {"<html>
<head><meta charset="UTF-8"><style>
body { font-family: Verdana, Geneva, sans-serif; background: #1a1a1a; color: #ffffff; margin: 0; padding: 20px; font-size: 14px; }
h2 { color: #cc0000; border-bottom: 2px solid #cc0000; padding-bottom: 8px; margin-top: 0; font-size: 18px; letter-spacing: 1px; }
.money { color: #ffd700; text-align: right; margin-bottom: 16px; font-size: 14px; font-weight: bold; }
.btn { background: #cc0000; color: #ffffff; border: 1px solid #aa0000; padding: 6px 14px; cursor: pointer; font-size: 13px; font-family: Verdana, Geneva, sans-serif; display: inline-block; margin: 2px; text-decoration: none; }
.btn:hover { background: #ff3333; }
.btn-sm { padding: 4px 10px; font-size: 12px; }
.message { color: #ffd700; margin-bottom: 12px; font-style: italic; }
</style></head>
<body>
<h2>[name]</h2>
<div class="money">Money: $[total_money]</div>
[shop_content]
<div style="margin-top:16px;"><a class="btn" href="byond://?src=\ref[src];close=1" style="background:#666666;border-color:#444444;">Close</a></div>
</body></html>"}
	return dat

/mob/living/simple_animal/npc_vendor/Topic(href, href_list)
	if (!usr || !usr.client || !ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		to_chat(H, SPAN_WARNING("You're too far away!"))
		return
	if (href_list["close"])
		H << browse(null, "window=npc_vendor")
		return

// ============================================================
// Plastique override — protect NPC vendors and safes on TAOTD
// ============================================================

/obj/item/weapon/plastique/afterattack(atom/movable/target, mob/user, flag)
	if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
		if (istype(target, /mob/living/simple_animal/npc_vendor) || istype(target, /obj/structure/closet/safe))
			return
	..()

// ============================================================
// OMAR THE SMUGGLER — Sells smuggled weapon crates
// ============================================================

/mob/living/simple_animal/npc_vendor/smuggler
	name = "Omar the Smuggler"
	desc = "You've got money? I've got goods."
	icon_state = "afghdrug"
	var/smuggler_cooldown = 0

/mob/living/simple_animal/npc_vendor/smuggler/New()
	..()
	speak = list(
		"Shipment's coming in from the coast. Keep your mouth shut.",
		"I know a guy who knows a guy. That's how this works.",
		"The docks are the safest place. Trust me.",
		"Cash upfront, no returns, no questions.",
		"The feds are getting nosy. Keep it quiet.",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/smuggler/show_shop(mob/living/human/H)
	if (world.time < smuggler_cooldown)
		to_chat(H, SPAN_WARNING("\icon[getFlatIcon(src)] No shipments available, come back later."))
		return
	if (H.civilization == "Sheriff Office" || H.civilization == "Government")
		to_chat(H, "\icon[getFlatIcon(src)] Good day, everything is okay and running smoothly.")
		return
	if (H.civilization == "Paramedics")
		to_chat(H, "\icon[getFlatIcon(src)] Keep up the good work, no one here is injured, see you.")
		return

	var/content = {"<div class="message">"A shipment will arrive at the Docks. Better be ready."</div>
<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:8px;">Smuggler's Package — $500</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy_shipment=1">Buy Shipment</a>
</div>"}
	H << browse(build_shop_html(content, H), "window=npc_vendor;size=500x400")

/mob/living/simple_animal/npc_vendor/smuggler/Topic(href, href_list)
	..()
	if (!usr || !ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		return
	if (href_list["buy_shipment"])
		if (world.time < smuggler_cooldown)
			to_chat(H, SPAN_WARNING("\icon[getFlatIcon(src)] No shipments available, come back later."))
			return
		if (H.civilization == "Sheriff Office" || H.civilization == "Government" || H.civilization == "Paramedics")
			return
		var/obj/item/stack/money/M = null
		if (istype(H.get_active_hand(), /obj/item/stack/money))
			M = H.get_active_hand()
		else if (istype(H.get_inactive_hand(), /obj/item/stack/money))
			M = H.get_inactive_hand()
		if (!M || M.value * M.amount < 500 * 4)
			to_chat(H, SPAN_WARNING("\icon[getFlatIcon(src)] Not enough money! You need at least 500 dollars."))
			return
		M.amount -= 500 / 5
		if (M.amount <= 0)
			qdel(M)
		to_chat(H, "\icon[getFlatIcon(src)] A shipment will arrive soon at the Docks. Better be ready.")
		if (prob(50))
			for (var/mob/living/human/player in player_list)
				if (player.civilization == "Goldstein Solutions" || player.civilization == "Kogama Kraftsmen" || player.civilization == "Rednikov Industries" || player.civilization == "Giovanni Blu Stocks")
					if (player.civilization != H.civilization)
						to_chat(player, "<b>Word of mouth goes that a shipment will arrive soon at the docks. Might be worth intercepting it.</b>")
			if (prob(50))
				spawn(rand(300, 1800))
					global_broadcast(FREQP, "<big>A confidential informant gave away that a suspicious shipment will arrive soon at the docks!</big>")
		smuggler_cooldown = world.time + 1800
		spawn(rand(900, 1800))
			if (prob(90))
				var/crate_group = rand(1, 3)
				var/crate_type = rand(1, 3)
				switch (crate_group)
					if (1)
						switch (crate_type)
							if (1)
								new /obj/structure/largecrate/smuggler/crystals(get_turf(locate(84, 6, 1)))
							if (2)
								new /obj/structure/largecrate/smuggler/disks(get_turf(locate(84, 6, 1)))
							if (3)
								new /obj/structure/largecrate/smuggler/fake_disks(get_turf(locate(84, 6, 1)))
					if (2)
						switch (crate_type)
							if (1)
								new /obj/structure/largecrate/smuggler/makarov(get_turf(locate(84, 6, 1)))
							if (2)
								new /obj/structure/largecrate/smuggler/magnum44(get_turf(locate(84, 6, 1)))
							if (3)
								new /obj/structure/largecrate/smuggler/m1911(get_turf(locate(84, 6, 1)))
					if (3)
						switch (crate_type)
							if (1)
								new /obj/structure/largecrate/smuggler/skorpion(get_turf(locate(84, 6, 1)))
							if (2)
								new /obj/structure/largecrate/smuggler/uzi(get_turf(locate(84, 6, 1)))
							if (3)
								new /obj/structure/largecrate/smuggler/mac10(get_turf(locate(84, 6, 1)))
			else
				if (prob(70))
					new /obj/structure/largecrate/smuggler/cocaine(get_turf(locate(84, 6, 1)))
				else
					new /obj/structure/largecrate/smuggler/ak47(get_turf(locate(84, 6, 1)))

// ============================================================
// BRUCE THE BIKER — Buys drugs, sells weapons
// ============================================================

/mob/living/simple_animal/npc_vendor/biker
	name = "Bruce the Biker"
	desc = "You've got drugs? I've got money."
	icon_state = "bruce"
	var/biker_cooldown = 0
	var/buying_price1 = 50
	var/buying_price2 = 65
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,
	)
	products = list(
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 1,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 1,
	)
	prices = list(
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 350,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 700,
	)

/mob/living/simple_animal/npc_vendor/biker/New()
	..()
	speak = list(
		"Got some good shit? I'll pay top dollar.",
		"My boys on the coast need product. You got product?",
		"The feds are sniffing around. Keep your mouth shut.",
		"Nice weather we're having. Shame about the bodies in the river.",
		"You look like you could use a gun. And a shower.",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/biker/show_shop(mob/living/human/H)
	if (reputation[H.civilization] < 0)
		to_chat(H, "\icon[getFlatIcon(src)] I'm not dealing with you punks anymore, get the fuck out of here.")
		return
	if (H.civilization == "Sheriff Office" || H.civilization == "Paramedics" || H.civilization == "Government")
		if (H.civilization == "Sheriff Office")
			to_chat(H, "\icon[getFlatIcon(src)] Get off my property, pig.")
		else
			to_chat(H, "\icon[getFlatIcon(src)] Sorry, who the fuck are you? Get outta here!")
		return
	if (world.time <= biker_cooldown)
		to_chat(H, "\icon[getFlatIcon(src)] My boys are busy for now. Come back later.")
		return

	// Build sell drug section — check hands for pills
	var/sell_html = ""
	var/obj/item/weapon/reagent_containers/pill/P = null
	var/obj/item/weapon/reagent_containers/cocaineblock/CB = null
	if (istype(H.get_active_hand(), /obj/item/weapon/reagent_containers/pill/))
		P = H.get_active_hand()
	else if (istype(H.get_inactive_hand(), /obj/item/weapon/reagent_containers/pill/))
		P = H.get_inactive_hand()
	if (istype(H.get_active_hand(), /obj/item/weapon/reagent_containers/cocaineblock))
		CB = H.get_active_hand()
	else if (istype(H.get_inactive_hand(), /obj/item/weapon/reagent_containers/cocaineblock))
		CB = H.get_inactive_hand()

	if (P)
		if (P.reagents.has_reagent("methamphetamine") && P.reagents.get_reagent_amount("methamphetamine") >= 10)
			sell_html = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">Methamphetamine Pill</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">Sell for: $[buying_price1 + max(reputation[H.civilization], 0)]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];sell=meth">Sell</a>
</div>"}
		else if (P.reagents.has_reagent("cocaine") && P.reagents.get_reagent_amount("cocaine") >= 25 && !P.reagents.has_reagent("methamphetamine"))
			sell_html = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">Cocaine (10g Bag)</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">Sell for: $[buying_price2 + min(reputation[H.civilization], 15)]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];sell=coke">Sell</a>
</div>"}
		else if (P.reagents.has_reagent("cocaine") && P.reagents.has_reagent("methamphetamine"))
			to_chat(H, "\icon[getFlatIcon(src)] Are you trying to get my clients killed? Tell your cook to separate his shit.")
			return
		else if (P.reagents.has_reagent("crack"))
			to_chat(H, "\icon[getFlatIcon(src)] Fuck off, my boys don't mess with that shit.")
			return
		else
			to_chat(H, "\icon[getFlatIcon(src)] What the hell is this weak shit? Fuck off!")
			return
	else if (CB)
		sell_html = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">Cocaine Brick</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">Sell for: $[(buying_price2 + max(reputation[H.civilization], 0)) * 20]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];sell=brick">Sell</a>
</div>"}
	else
		sell_html = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-size:12px;color:#999999;">Have drugs in your hand to sell them.</div>
</div>"}

	// Build buy weapons section
	var/weapons_html = ""
	for (var/i = 1 to 2)
		var/item_path = products[i]
		var/obj/item/I = new item_path
		if (i == 1)
			weapons_html += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">[I.name]</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">[I.desc]</div>
<div style="color:#ffd700;font-weight:bold;font-size:14px;margin-bottom:4px;">$[prices[item_path]]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy_weapon=[i]">Buy</a>
</div>"}
		else
			weapons_html += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">[I.name]</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">[I.desc]</div>
<div style="color:#ffd700;font-weight:bold;font-size:14px;margin-bottom:4px;">$[prices[item_path]]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy_weapon=[i]">Buy</a>
</div>"}
		qdel(I)

	var/content = {"<h3 style="color:#cc0000;margin:12px 0 8px 0;">Sell Drugs</h3>
[sell_html]
<h3 style="color:#cc0000;margin:12px 0 8px 0;">Buy Weapons</h3>
[weapons_html]"}
	H << browse(build_shop_html(content, H), "window=npc_vendor;size=500x600")

/mob/living/simple_animal/npc_vendor/biker/Topic(href, href_list)
	if (..())
		return
	if (!usr || !ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		return

	if (href_list["sell"])
		if (world.time <= biker_cooldown)
			to_chat(H, "\icon[getFlatIcon(src)] My boys are busy for now. Come back later.")
			return
		switch (href_list["sell"])
			if ("meth")
				var/obj/item/weapon/reagent_containers/pill/P = null
				if (istype(H.get_active_hand(), /obj/item/weapon/reagent_containers/pill/))
					P = H.get_active_hand()
				else if (istype(H.get_inactive_hand(), /obj/item/weapon/reagent_containers/pill/))
					P = H.get_inactive_hand()
				if (P && P.reagents.has_reagent("methamphetamine") && P.reagents.get_reagent_amount("methamphetamine") >= 10)
					qdel(P)
					var/obj/item/stack/money/dollar/D = new /obj/item/stack/money/dollar(null)
					D.amount = (buying_price1 + max(reputation[H.civilization], 0)) / (D.value / 5)
					if (D.amount == 0)
						qdel(D)
					H.put_in_hands(D)
					to_chat(H, "\icon[getFlatIcon(src)] Here, there's more where it came from.")
					reputation[H.civilization] += 2
					if (prob(50))
						if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
							var/obj/map_metadata/art_of_the_deal/AD = map
							AD.heat[H.civilization] += 1
					show_shop(H)
			if ("coke")
				var/obj/item/weapon/reagent_containers/pill/P = null
				if (istype(H.get_active_hand(), /obj/item/weapon/reagent_containers/pill/))
					P = H.get_active_hand()
				else if (istype(H.get_inactive_hand(), /obj/item/weapon/reagent_containers/pill/))
					P = H.get_inactive_hand()
				if (P && P.reagents.has_reagent("cocaine") && P.reagents.get_reagent_amount("cocaine") >= 25 && !P.reagents.has_reagent("methamphetamine"))
					qdel(P)
					var/obj/item/stack/money/dollar/D = new /obj/item/stack/money/dollar(null)
					D.amount = (buying_price2 + min(reputation[H.civilization], 15)) / (D.value / 5)
					if (D.amount == 0)
						qdel(D)
					H.put_in_hands(D)
					to_chat(H, "\icon[getFlatIcon(src)] Here, there's more where it came from.")
					reputation[H.civilization] += 1
					if (prob(50))
						if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
							var/obj/map_metadata/art_of_the_deal/AD = map
							AD.heat[H.civilization] += 1
					show_shop(H)
			if ("brick")
				var/obj/item/weapon/reagent_containers/cocaineblock/CB = null
				if (istype(H.get_active_hand(), /obj/item/weapon/reagent_containers/cocaineblock))
					CB = H.get_active_hand()
				else if (istype(H.get_inactive_hand(), /obj/item/weapon/reagent_containers/cocaineblock))
					CB = H.get_inactive_hand()
				if (CB)
					qdel(CB)
					var/obj/item/stack/money/dollar/D = new /obj/item/stack/money/dollar(null)
					D.amount = ((buying_price2 + max(reputation[H.civilization], 0)) * 20) / (D.value / 5)
					if (D.amount == 0)
						qdel(D)
					H.put_in_hands(D)
					to_chat(H, "\icon[getFlatIcon(src)] Holy shit, now that's some product. I'll need some time to distribute it.")
					biker_cooldown = world.time + 6000
					if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
						var/obj/map_metadata/art_of_the_deal/AD = map
						AD.heat[H.civilization] += 15
					show_shop(H)

	if (href_list["buy_weapon"])
		var/item_id = text2num(href_list["buy_weapon"])
		var/picked_path = null
		var/picked_price = 0
		var/i = 1
		for (var/item_path in products)
			if (i == item_id)
				picked_path = item_path
				picked_price = prices[item_path]
				break
			i++
		if (!picked_path)
			return
		var/obj/item/stack/money/M = null
		if (istype(H.get_active_hand(), /obj/item/stack/money))
			M = H.get_active_hand()
		else if (istype(H.get_inactive_hand(), /obj/item/stack/money))
			M = H.get_inactive_hand()
		if (!M || M.value * M.amount < picked_price * 4)
			to_chat(H, "\icon[getFlatIcon(src)] Not enough money. You need [picked_price] dollars.")
			return
		M.amount -= picked_price / 5
		if (M.amount <= 0)
			qdel(M)
		var/obj/item/new_item = new picked_path(null)
		if (istype(new_item, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/G = new_item
			G.serial = ""
		H.put_in_hands(new_item)
		if (picked_path == /obj/item/weapon/gun/projectile/revolver/smithwesson)
			new /obj/item/ammo_magazine/c32(H.loc)
		else if (picked_path == /obj/item/weapon/gun/projectile/pistol/m1911)
			new /obj/item/ammo_magazine/m1911(H.loc)
			new /obj/item/ammo_magazine/m1911(H.loc)
		if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
			var/obj/map_metadata/art_of_the_deal/AD = map
			AD.heat[H.civilization] += 2
			if (AD.heat[H.civilization] >= 40)
				to_chat(H, "\icon[getFlatIcon(src)] You better run fast before the feds get you.")
				spawn(rand(300, 600))
					global_broadcast(FREQP, "<big>The ATF reports that [H.real_name] may have acquired an illegal firearm. Detain and search the suspect as soon as possible.</big>")
		show_shop(H)

// ============================================================
// DIEGO 'EL DIABLO' MORALES — Cartel cocaine dealer
// ============================================================

/mob/living/simple_animal/npc_vendor/cartel
	name = "Diego 'El Diablo' Morales"
	desc = "Plata or plomo? I've got the product."
	icon_state = "cartel"
	var/cartel_cooldown = 0
	var/heat_message_cooldown = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,
	)
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,
	)
	var/list/buy_list = list("Cancel", "1 gram", "10 grams", "a block")

/mob/living/simple_animal/npc_vendor/cartel/New()
	..()
	speak = list(
		"Plata o plomo? I prefer plata.",
		"The product is pure. My grandmother would vouch for it.",
		"The feds are everywhere, chico. Be careful.",
		"You want the good stuff? I've got the good stuff.",
		"Don't get caught. I can't afford to lose another customer.",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/cartel/show_shop(mob/living/human/H)
	if (reputation[H.civilization] < 0)
		to_chat(H, "\icon[getFlatIcon(src)] Don't waste my time, find another hole to climb into, sapo.")
		return
	if (H.civilization == "Sheriff Office" || H.civilization == "Paramedics" || H.civilization == "Government")
		to_chat(H, "\icon[getFlatIcon(src)] I have nothing to tell you.")
		return
	if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
		var/obj/map_metadata/art_of_the_deal/AD = map
		if (AD.heat[H.civilization] >= 35 && AD.heat[H.civilization] < 40)
			to_chat(H, SPAN_NOTICE("\icon[getFlatIcon(src)] You should start being more careful with the produce. Maybe someone can help you get under the radar."))
		if (AD.heat[H.civilization] >= 40)
			to_chat(H, SPAN_WARNING("\icon[getFlatIcon(src)] Chico, you'll get us busted by the feds. They are watching you close!"))
			if (prob(80) && world.time >= heat_message_cooldown[H.civilization])
				spawn(300)
					if (prob(50))
						global_broadcast(FREQP, "<big> The DEA informs the local authorities that the company [H.civilization] <b>may be</b> involved in drug trafficking. Pay close attention to their activities.</big>")
					else
						global_broadcast(FREQP, "<big> The DEA informs the local authorities that [H.real_name], working for [H.civilization], <b>may be</b> involved in drug trafficking. Surveillance of the individual is required, detain and search if necessary.</big>")
				heat_message_cooldown[H.civilization] = world.time + 1200

	// Determine available products based on reputation
	var/gram_price = 70
	if (reputation[H.civilization] >= 10)
		gram_price = max(50, 70 - Floor(reputation[H.civilization] / 2))
	var/tenner_price = 600
	if (reputation[H.civilization] >= 20)
		tenner_price = max(500, tenner_price - (2 * reputation[H.civilization]))

	var/products_html = ""
	// 1 gram
	products_html += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">1 Gram Cocaine</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">A single gram of pure Colombian cocaine.</div>
<div style="color:#ffd700;font-weight:bold;font-size:14px;margin-bottom:4px;">$[gram_price]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy_coke=1g">Buy</a>
</div>"}
	// 10 grams (reputation 15+)
	if (reputation[H.civilization] >= 15)
		products_html += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">10 Grams Cocaine</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">A briefcase with ten grams of high-quality cocaine.</div>
<div style="color:#ffd700;font-weight:bold;font-size:14px;margin-bottom:4px;">$[tenner_price]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy_coke=10g">Buy</a>
</div>"}
	// a block (reputation 30+)
	if (reputation[H.civilization] >= 30)
		products_html += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">Cocaine Brick</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">A full brick of uncut Colombian product. The real deal.</div>
<div style="color:#ffd700;font-weight:bold;font-size:14px;margin-bottom:4px;">$1,200</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy_coke=block">Buy</a>
</div>"}

	var/content = {"<div class="message">What do you need, jefe?</div>
[products_html]"}
	H << browse(build_shop_html(content, H), "window=npc_vendor;size=500x500")

/mob/living/simple_animal/npc_vendor/cartel/Topic(href, href_list)
	if (..())
		return
	if (!usr || !ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		return

	if (href_list["buy_coke"])
		if (reputation[H.civilization] < 0)
			to_chat(H, "\icon[getFlatIcon(src)] Don't waste my time, sapo.")
			return
		var/obj/item/stack/money/M = null
		if (istype(H.get_active_hand(), /obj/item/stack/money))
			M = H.get_active_hand()
		else if (istype(H.get_inactive_hand(), /obj/item/stack/money))
			M = H.get_inactive_hand()
		if (!M)
			to_chat(H, "\icon[getFlatIcon(src)] You need money in your hand, maricon.")
			return

		switch (href_list["buy_coke"])
			if ("1g")
				var/gram_price = 70
				if (reputation[H.civilization] >= 10)
					gram_price = max(50, 70 - Floor(reputation[H.civilization] / 2))
				if (M.value * M.amount < gram_price * 4)
					to_chat(H, "\icon[getFlatIcon(src)] Not enough money, maricon.")
					return
				M.amount -= gram_price / 5
				if (M.amount <= 0)
					qdel(M)
				var/obj/item/weapon/reagent_containers/pill/cocaine/one_g = new /obj/item/weapon/reagent_containers/pill/cocaine(null)
				H.put_in_hands(one_g)
				if (prob(50))
					reputation[H.civilization] += 1
				if (prob(40))
					if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
						var/obj/map_metadata/art_of_the_deal/AD = map
						AD.heat[H.civilization] += 1
			if ("10g")
				var/tenner_price = 600
				if (reputation[H.civilization] >= 20)
					tenner_price = max(500, tenner_price - (2 * reputation[H.civilization]))
				if (M.value * M.amount < tenner_price * 4)
					to_chat(H, "\icon[getFlatIcon(src)] Not enough money, maricon.")
					return
				M.amount -= tenner_price / 5
				if (M.amount <= 0)
					qdel(M)
				var/obj/item/weapon/storage/briefcase/cocaine_10/briefcase = new /obj/item/weapon/storage/briefcase/cocaine_10(null)
				H.put_in_hands(briefcase)
				reputation[H.civilization] += 1
				if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
					var/obj/map_metadata/art_of_the_deal/AD = map
					AD.heat[H.civilization] += 5
			if ("block")
				if (M.value * M.amount < 1200 * 4)
					to_chat(H, "\icon[getFlatIcon(src)] Not enough money, maricon.")
					return
				M.amount -= 1200 / 5
				if (M.amount <= 0)
					qdel(M)
				var/obj/item/weapon/reagent_containers/cocaineblock/block = new /obj/item/weapon/reagent_containers/cocaineblock(null)
				H.put_in_hands(block)
				if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
					var/obj/map_metadata/art_of_the_deal/AD = map
					AD.heat[H.civilization] += 10
		show_shop(H)

/obj/item/weapon/storage/briefcase/cocaine_10
	name = "briefcase of product"
	desc = "A briefcase. It seems to have a small powdery residue."
	icon_state = "briefcase"

/obj/item/weapon/storage/briefcase/cocaine_10/New()
	..()
	for (var/i = 1; i <= 10; i++)
		new /obj/item/weapon/reagent_containers/pill/cocaine(src)

// ============================================================
// MR. WHITE — Chemicals and explosives
// ============================================================

/mob/living/simple_animal/npc_vendor/walter
	name = "Mr. White"
	desc = "A respectable chemistry teacher."
	icon_state = "waltuh"
	var/walter_cooldown = 0
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,
	)
	products = list(
		/obj/item/weapon/reagent_containers/glass/bottle/diethylamine = 1,
		/obj/item/weapon/reagent_containers/glass/bottle/acetone = 1,
		/obj/item/weapon/reagent_containers/glass/bottle/potassium_chloride = 1,
		/obj/item/weapon/reagent_containers/glass/bottle/carbon = 1,
		/obj/item/weapon/plastique/c4 = 1,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/glass/bottle/diethylamine = 100,
		/obj/item/weapon/reagent_containers/glass/bottle/acetone = 100,
		/obj/item/weapon/reagent_containers/glass/bottle/potassium_chloride = 100,
		/obj/item/weapon/reagent_containers/glass/bottle/carbon = 100,
		/obj/item/weapon/plastique/c4 = 900,
	)

/mob/living/simple_animal/npc_vendor/walter/New()
	..()
	speak = list(
		"Chemistry is a science of precision. My prices are not.",
		"I am the one who knocks... on opportunity.",
		"The lab is quiet today. Too quiet.",
		"Stay out of my territory.",
		"I need more methylamine. You don't happen to have any, do you?",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/walter/show_shop(mob/living/human/H)
	if (reputation[H.civilization] < 0)
		to_chat(H, "\icon[getFlatIcon(src)] Don't waste my time.")
		return
	if (H.civilization == "Sheriff Office" || H.civilization == "Government")
		to_chat(H, "\icon[getFlatIcon(src)] I have nothing to tell you.")
		return
	if (world.time <= walter_cooldown)
		to_chat(H, "\icon[getFlatIcon(src)] I need more time to cook. Come back later.")
		return

	var/products_html = ""
	var/i = 1
	for (var/item_path in products)
		var/obj/item/I = new item_path
		var/price = prices[item_path]
		products_html += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:4px;">[I.name]</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">[I.desc]</div>
<div style="color:#ffd700;font-weight:bold;font-size:14px;margin-bottom:4px;">$[price]</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];buy=[i]">Buy</a>
</div>"}
		qdel(I)
		i++

	var/content = {"<div class="message">What do you need?</div>
[products_html]"}
	H << browse(build_shop_html(content, H), "window=npc_vendor;size=500x600")

/mob/living/simple_animal/npc_vendor/walter/Topic(href, href_list)
	if (..())
		return
	if (!usr || !ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		return

	if (href_list["buy"])
		var/item_id = text2num(href_list["buy"])
		var/picked_path = null
		var/picked_price = 0
		var/i = 1
		for (var/item_path in products)
			if (i == item_id)
				picked_path = item_path
				picked_price = prices[item_path]
				break
			i++
		if (!picked_path)
			return
		if (world.time <= walter_cooldown)
			to_chat(H, "\icon[getFlatIcon(src)] I need more time to cook. Come back later.")
			return
		var/obj/item/stack/money/M = null
		if (istype(H.get_active_hand(), /obj/item/stack/money))
			M = H.get_active_hand()
		else if (istype(H.get_inactive_hand(), /obj/item/stack/money))
			M = H.get_inactive_hand()
		if (!M || M.value * M.amount < picked_price * 4)
			to_chat(H, "\icon[getFlatIcon(src)] You need [picked_price] dollars in one of your hands.")
			return
		M.amount -= picked_price / 5
		if (M.amount <= 0)
			qdel(M)
		var/obj/item/new_item = new picked_path(get_turf(H))
		H.put_in_hands(new_item)
		if (picked_path == /obj/item/weapon/plastique/c4)
			walter_cooldown = world.time + 600
			if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
				var/obj/map_metadata/art_of_the_deal/AD = map
				AD.heat[H.civilization] += 25
				if (AD.heat[H.civilization] >= 40)
					to_chat(H, "\icon[getFlatIcon(src)] You better run fast before the feds get you.")
				spawn(300)
					global_broadcast(FREQP, "<big>The ATF reports that [H.real_name] may have acquired an explosive device.</big>")
		else
			walter_cooldown = world.time + 600
		to_chat(H, SPAN_NOTICE("You bought [new_item.name] for [picked_price] dollars."))
		show_shop(H)

// ============================================================
// AGENT HARRISON YATES — Corrupt federal agent
// ============================================================

/mob/living/simple_animal/npc_vendor/fed
	name = "Agent Harrison Yates"
	desc = "A federal agent with questionable morality."
	icon_state = "narc"
	light_range = 2
	var/list/reputation = list(
		"Rednikov Industries" = 0,
		"Giovanni Blu Stocks" = 0,
		"Kogama Kraftsmen" = 0,
		"Goldstein Solutions" = 0,
	)
	var/intel_cooldown = 0
	var/heat_cooldown = 0

/mob/living/simple_animal/npc_vendor/fed/New()
	..()
	speak = list(
		"I've seen things you wouldn't believe. I've done things you wouldn't believe.",
		"Money talks. Everything else walks.",
		"The Bureau doesn't pay enough for this kind of work.",
		"I could help you... for a price.",
		"Let's just say I'm not a fan of paperwork.",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/fed/show_shop(mob/living/human/H)
	if (H.civilization == "Paramedics" || H.civilization == "none")
		return

	var/content = ""
	if (H.civilization == "Sheriff Office" || H.civilization == "Government")
		if (world.time <= intel_cooldown)
			content = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-size:12px;color:#999999;">I need more time to investigate. Come back later.</div>
</div>"}
		else
			content = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:8px;">Get Intel</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];intel=narc">Narcotics</a>
<a class="btn btn-sm" href="byond://?src=\ref[src];intel=firearms">Illegal Firearms</a>
<a class="btn btn-sm" href="byond://?src=\ref[src];intel=disks">Disks</a>
</div>"}
	else
		if (reputation[H.civilization] < 0)
			content = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-size:12px;color:#999999;">Don't waste my time. I can't do anything for you anymore.</div>
</div>"}
		else
			content = {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:8px;">Bribe — $500</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">Improve your standing with the Agency.</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];bribe=1">Bribe</a>
</div>"}
			if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
				var/obj/map_metadata/art_of_the_deal/AD = map
				if (AD.heat[H.civilization] > 0 && reputation[H.civilization] > 0)
					if (world.time > heat_cooldown)
						var/heat_price = ceil(200 / reputation[H.civilization])
						content += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-weight:bold;margin-bottom:8px;">Reduce Heat</div>
<div style="font-size:11px;color:#999999;margin-bottom:8px;">Current heat: [AD.heat[H.civilization]] evidence files. $[heat_price] per file.</div>
<a class="btn btn-sm" href="byond://?src=\ref[src];reduce=1">Remove 1</a>
<a class="btn btn-sm" href="byond://?src=\ref[src];reduce=5">Remove 5</a>
<a class="btn btn-sm" href="byond://?src=\ref[src];reduce=10">Remove 10</a>
</div>"}
					else
						content += {"<div style="background:#272727;border:1px solid #cc0000;padding:12px;margin-bottom:8px;border-radius:4px;">
<div style="font-size:12px;color:#999999;">I can't tamper with evidence that fast.</div>
</div>"}

	H << browse(build_shop_html(content, H), "window=npc_vendor;size=500x450")

/mob/living/simple_animal/npc_vendor/fed/Topic(href, href_list)
	if (..())
		return
	if (!usr || !ishuman(usr))
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		return

	if (href_list["bribe"])
		if (reputation[H.civilization] < 0)
			to_chat(H, "\icon[getFlatIcon(src)] Don't waste my time. I can't do anything for you anymore.")
			return
		var/obj/item/stack/money/M = null
		if (istype(H.get_active_hand(), /obj/item/stack/money))
			M = H.get_active_hand()
		else if (istype(H.get_inactive_hand(), /obj/item/stack/money))
			M = H.get_inactive_hand()
		if (!M || M.value * M.amount < 500 * 4)
			to_chat(H, "\icon[getFlatIcon(src)] You need at least 500 dollars in one of your hands.")
			return
		M.amount -= 500 / 5
		if (M.amount <= 0)
			qdel(M)
		reputation[H.civilization] += 1
		to_chat(H, "\icon[getFlatIcon(src)] Pleasure doing business with you.")
		show_shop(H)

	if (href_list["reduce"])
		if (reputation[H.civilization] == 0)
			to_chat(H, "\icon[getFlatIcon(src)] I will need a little sign of appreciation for this, if you know what I mean.")
			return
		if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
			var/obj/map_metadata/art_of_the_deal/AD = map
			if (AD.heat[H.civilization] == 0)
				to_chat(H, "\icon[getFlatIcon(src)] You gentlemen are off the radar, for now.")
				return
			if (world.time <= heat_cooldown)
				to_chat(H, "\icon[getFlatIcon(src)] Not so fast, pal. I can't just tamper with evidence that fast.")
				return
			var/amount = text2num(href_list["reduce"])
			var/heat_price = ceil(200 / reputation[H.civilization])
			var/total_price = amount * heat_price
			var/obj/item/stack/money/M = null
			if (istype(H.get_active_hand(), /obj/item/stack/money))
				M = H.get_active_hand()
			else if (istype(H.get_inactive_hand(), /obj/item/stack/money))
				M = H.get_inactive_hand()
			if (!M || M.value * M.amount < total_price * 4)
				to_chat(H, "\icon[getFlatIcon(src)] You need at least [total_price] dollars in one of your hands.")
				return
			M.amount -= total_price / 5
			if (M.amount <= 0)
				qdel(M)
			AD.heat[H.civilization] -= amount
			if (AD.heat[H.civilization] < 0)
				AD.heat[H.civilization] = 0
			if (amount >= 5)
				heat_cooldown = world.time + 600
			if (amount >= 10)
				heat_cooldown = world.time + 1200
			to_chat(H, "\icon[getFlatIcon(src)] Done. Those files had a... accident.")
			show_shop(H)

	if (href_list["intel"])
		if (world.time <= intel_cooldown)
			to_chat(H, "\icon[getFlatIcon(src)] I need more time to investigate. Come back later.")
			return
		switch (href_list["intel"])
			if ("narc")
				var/count_c = 0
				var/count_m = 0
				for (var/obj/item/weapon/reagent_containers/pill/P in world)
					if (P)
						if (P.reagents.has_reagent("cocaine") && P.reagents.get_reagent_amount("cocaine") >= 25)
							count_c++
						if (P.reagents.has_reagent("methamphetamine") && P.reagents.get_reagent_amount("methamphetamine") >= 10)
							count_m++
				to_chat(H, "\icon[getFlatIcon(src)] There's currently [count_c] grams of cocaine and [count_m] grams of methamphetamine in circulation right now.")
				var/count_b = 0
				for (var/obj/item/weapon/reagent_containers/cocaineblock/block in world)
					if (block)
						count_b++
				to_chat(H, "\icon[getFlatIcon(src)] There's currently [count_b] blocks of cocaine in circulation.")
			if ("firearms")
				var/count_f = 0
				var/count_bomb = 0
				for (var/obj/item/weapon/gun/projectile/firearm in world)
					if (firearm.serial == "")
						count_f++
				for (var/obj/item/weapon/plastique/c4/bomb in world)
					if (bomb)
						count_bomb++
				to_chat(H, "\icon[getFlatIcon(src)] There's [count_f] illegal firearms and [count_bomb] explosives in circulation right now.")
			if ("disks")
				var/count_d = 0
				for (var/obj/item/weapon/disk/D in world)
					if (D.faction)
						count_d++
				to_chat(H, "\icon[getFlatIcon(src)] There's [count_d] illegal disks in circulation right now.")
		intel_cooldown = world.time + 4800
		show_shop(H)

// ============================================================
// MARCELLUS — Bouncer (simple flavor NPC)
// ============================================================

/mob/living/simple_animal/npc_vendor/bouncer
	name = "Marcellus"
	desc = "Your \"friendly\" neighborhood bouncer. Your wife loves him."
	icon_state = "bouncer"

/mob/living/simple_animal/npc_vendor/bouncer/New()
	..()
	speak = list(
		"No weapons, no drugs inside the club, else I'll make you drop the soap.",
		"I've seen tougher guys than you cry like babies.",
		"You think you're tough? I eat guys like you for breakfast.",
		"The boss says no trouble. I make sure there's no trouble.",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/bouncer/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
		respond_to_attack(user)
		return
	src.say(pick(speak))

// ============================================================
// BIG LENNY — Barber (simple flavor NPC)
// ============================================================

/mob/living/simple_animal/npc_vendor/big_lenny
	name = "Big Lenny"
	desc = "A barber that likes to relax."
	icon_state = "big_lenny"

/mob/living/simple_animal/npc_vendor/big_lenny/New()
	..()
	speak = list(
		"Shiieeet, come back another time, I'm taking a nap.",
		"Five more minutes...",
		"Come back later, I'm busy. Can't you see I'm busy?",
		"I'll cut your hair tomorrow. Maybe.",
	)
	update_icons()

/mob/living/simple_animal/npc_vendor/big_lenny/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
		respond_to_attack(user)
		return
	src.say(pick(speak))

// ============================================================
// Map placeholder structures — spawn the mob equivalents
// ============================================================

/obj/structure/npc_vendor
	name = "NPC (Do not use!)"
	icon = 'icons/mob/npcs.dmi'
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE
	var/mob_type_to_spawn = null

/obj/structure/npc_vendor/New()
	..()
	if (mob_type_to_spawn)
		var/mob/M = new mob_type_to_spawn(get_turf(src))
		if (M)
			M.name = name
			M.dir = dir
		spawn(1)
			qdel(src)

/obj/structure/npc_vendor/smuggler
	name = "Omar the Smuggler"
	desc = "You've got money? I've got goods."
	icon_state = "afghdrug"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/smuggler

/obj/structure/npc_vendor/biker
	name = "Bruce the Biker"
	desc = "You've got drugs? I've got money."
	icon_state = "bruce"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/biker

/obj/structure/npc_vendor/cartel
	name = "Diego 'El Diablo' Morales"
	desc = "Plata or plomo? I've got the product."
	icon_state = "cartel"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/cartel

/obj/structure/npc_vendor/walter
	name = "Mr. White"
	desc = "A respectable chemistry teacher."
	icon_state = "waltuh"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/walter

/obj/structure/npc_vendor/fed
	name = "Agent Harrison Yates"
	desc = "A federal agent with questionable morality."
	icon_state = "narc"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/fed

/obj/structure/npc_vendor/bouncer
	name = "Marcellus"
	desc = "Your \"friendly\" neighborhood bouncer. Your wife loves him."
	icon_state = "bouncer"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/bouncer

/obj/structure/npc_vendor/big_lenny
	name = "Big Lenny"
	desc = "A barber that likes to relax."
	icon_state = "big_lenny"
	mob_type_to_spawn = /mob/living/simple_animal/npc_vendor/big_lenny
