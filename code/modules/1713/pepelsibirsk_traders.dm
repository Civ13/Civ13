// Pepelsibirsk Traveling Merchants - mob version
// Setting: alt-hist Cold War Siberia, 1975-1976

/mob/living/simple_animal/pepelsibirsk_trader
	name = "trader"
	desc = "A traveling merchant from beyond the taiga."
	icon = 'icons/mob/npcs.dmi'
	faction = "Pepelsibirsk"
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
	var/faction_relations
	var/faction_name = "Unknown"
	var/list/products = list()
	var/list/prices = list()
	var/cooldown_shop = 0

/mob/living/simple_animal/pepelsibirsk_trader/New()
	..()
	if (type == /mob/living/simple_animal/pepelsibirsk_trader)
		CRASH("Abstract type used for /mob/living/simple_animal/pepelsibirsk_trader")
	speak = list()
	update_icons()

/mob/living/simple_animal/pepelsibirsk_trader/bullet_act(var/obj/item/projectile/P)
	if (P && P.invisibility <= 0)
		respond_to_attack(P.firer)
	return ..()

/mob/living/simple_animal/pepelsibirsk_trader/attackby(obj/item/W, mob/living/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
			respond_to_attack(user)
	return ..()

/mob/living/simple_animal/pepelsibirsk_trader/proc/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	if (speak && speak.len)
		src.say(pick(speak))

/mob/living/simple_animal/pepelsibirsk_trader/death()
	for(var/product_key in products)
		for(var/i in 1 to products[product_key])
			if (prob(25))
				new product_key(get_turf(src))
	if (faction_relations)
		external_relations.npc_faction_relations[faction_relations] -= rand(10, 25)
		to_chat(world, "<font size = 3><span class = 'notice'><b>A [name] has died unexpectedly. Relations with [faction_name] have dropped!</b></font></span>")
	..()

/mob/living/simple_animal/pepelsibirsk_trader/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
		respond_to_attack(user)
		return
	if (world.time < cooldown_shop)
		src.say(pick("Patience, comrade.", "One moment, please.", "I am but one merchant!"))
		return
	cooldown_shop = world.time + 50
	if (speak && speak.len)
		src.say(pick(speak))
	show_shop(H)

/mob/living/simple_animal/pepelsibirsk_trader/proc/show_shop(mob/living/human/H)
	if (!H || !H.client)
		return
	var/total_rubles = 0
	for (var/obj/item/stack/money/rubles/R in H.contents)
		total_rubles += R.amount

	var/dat = {"<html>
<head><style>
body { font-family: Verdana, Geneva, sans-serif; background: #1a1a1a; color: #ffffff; margin: 0; padding: 20px; font-size: 14px; line-height: 170%; }
h2 { color: #cc0000; border-bottom: 2px solid #cc0000; padding-bottom: 8px; margin-top: 0; font-size: 18px; letter-spacing: 1px; }
.item { background: #272727; border: 1px solid #cc0000; padding: 8px 12px; margin-bottom: 8px; overflow: auto; }
.item .info { float: left; width: 65%; }
.item .name { font-weight: bold; color: #ffffff; }
.item .desc { font-size: 11px; color: #999999; }
.item .actions { float: right; text-align: right; margin-left: 10px; }
.item .price { color: #ffd700; font-weight: bold; font-size: 14px; margin-bottom: 4px; }
.buy-btn { background: #cc0000; color: #ffffff; border: 1px solid #aa0000; padding: 4px 12px; cursor: pointer; font-size: 12px; font-family: Verdana, Geneva, sans-serif; display: block; }
.buy-btn:hover { background: #ff3333; }
.rubles { color: #ffd700; text-align: right; margin-bottom: 16px; font-size: 14px; font-weight: bold; }
.link { float: left; min-width: 15px; height: 16px; text-align: center; color: #ffffff; text-decoration: none; background: #40628a; border: 1px solid #161616; padding: 0px 4px 4px 4px; margin: 0 2px 2px 0; cursor: default; white-space: nowrap; }
</style></head>
<body>
<h2>[name]</h2>
<div class="rubles">Rubles: [total_rubles]</div>
"}
	var/i = 1
	for(var/item_path in products)
		var/obj/item/I = new item_path
		var/item_name = I.name
		var/price = prices[item_path]
		dat += {"<div class=\"item\">
	<div class=\"info\"><span class=\"name\">[item_name]</span><br><span class=\"desc\">[I.desc]</span></div>
	<div class=\"actions\"><div class=\"price\">[price] R</div><button class=\"buy-btn\" onclick=\"window.location='byond://?src=\ref[src];buy=[i]'\">Buy</button></div>
</div>
"}
		qdel(I)
		i++
	dat += {"</body></html>"}
	H << browse(dat, "window=pepelsibirsk_trader;size=540x500")

/mob/living/simple_animal/pepelsibirsk_trader/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		to_chat(H, SPAN_WARNING("You're too far away from the trader!"))
		return
	if (href_list["buy"])
		var/item_id = text2num(href_list["buy"])
		var/i = 1
		var/picked_path = null
		var/picked_price = 0
		for(var/item_path in products)
			if (i == item_id)
				picked_path = item_path
				picked_price = prices[item_path]
				break
			i++
		if (!picked_path)
			src.say("I don't have that anymore, comrade.")
			return
		var/total_rubles = 0
		var/list/stack_list = list()
		for (var/obj/item/stack/money/rubles/S in H.contents)
			total_rubles += S.amount
			stack_list += S
		if (total_rubles < picked_price)
			src.say("Not enough rubles! Come back when you have [picked_price].")
			return
		var/to_deduct = picked_price
		for (var/obj/item/stack/money/rubles/S in stack_list)
			if (to_deduct <= 0)
				break
			if (S.amount <= to_deduct)
				to_deduct -= S.amount
				qdel(S)
			else
				S.amount -= to_deduct
				to_deduct = 0
				S.update_icon()
				break
		var/obj/item/new_item = new picked_path(get_turf(H))
		H.put_in_hands(new_item)
		if (faction_relations)
			external_relations.npc_faction_relations[faction_relations] += picked_price * 0.02
			to_chat(H, SPAN_NOTICE("Relations with [faction_name] have increased by [picked_price * 0.02]."))
		src.say(pick("A fine choice, comrade.", "Enjoy your purchase!", "The best goods in Siberia!"))
		to_chat(H, SPAN_NOTICE("You bought [new_item.name] for [picked_price] rubles."))

// ============================================================
// PACIFIC TRADER (United States of the Pacific)
// ============================================================

/mob/living/simple_animal/pepelsibirsk_trader/pacific_trader
	name = "U.S.P Trader"
	desc = "The United States of the Pacific has come to trade. He flashes a grin that says he's definitely selling things he probably shouldn't."
	icon_state = "usptrader"
	icon_living = "usptrader"
	icon_dead = "usptrader_dead"
	faction_relations = "faction_3_relations"
	faction_name = "United States of the Pacific"
	products = list(
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando = 2,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 5,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 2,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 2,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 1,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 2,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog = 2,
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 2,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 2,
		/obj/item/weapon/attachment/under/foregrip = 2,
		/obj/item/weapon/attachment/silencer/pistol = 2,
		/obj/item/weapon/attachment/silencer/rifle = 2,
		/obj/item/weapon/attachment/silencer/shotgun = 2,
		/obj/item/weapon/attachment/silencer/smg = 2,
		/obj/item/weapon/foldable/atgm/bgm_tow = 1,
		/obj/item/ammo_magazine/m16 = 8,
		/obj/item/ammo_magazine/m14 = 3,
		/obj/item/ammo_casing/rocket/bazooka = 4,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 3,
		/obj/item/weapon/plastique/c4 = 2,
		/obj/item/ammo_casing/rocket/atgm = 4,
		/obj/item/ammo_casing/rocket/atgm/he = 4,
		/obj/item/clothing/under/us_uni/us_camo_woodland = 8,
		/obj/item/clothing/accessory/storage/webbing/us_vest = 8,
		/obj/item/clothing/suit/storage/coat/ww2/us_coat = 8,
		/obj/item/clothing/shoes/jackboots/modern = 8,
		/obj/item/clothing/accessory/armor/coldwar/pasgt = 2,
		/obj/item/clothing/head/helmet/modern/pasgt = 2,
		/obj/item/weapon/reagent_containers/food/snacks/burger = 4,
		/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 4,
		/obj/item/weapon/reagent_containers/food/snacks/hotdog = 4,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 3,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie = 1,
		/obj/item/weapon/reagent_containers/food/snacks/applepie = 1,
		/obj/item/weapon/telephone/mobile = 2,
		/obj/structure/anti_air_crate = 1,
	)
	prices = list(
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando = 200,
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a2 = 160,
		/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 150,
		/obj/item/weapon/gun/launcher/rocket/bazooka = 150,
		/obj/item/weapon/gun/projectile/submachinegun/m14/sniper = 200,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 100,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog = 100,
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 100,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 100,
		/obj/item/weapon/attachment/under/foregrip = 100,
		/obj/item/weapon/attachment/silencer/pistol = 100,
		/obj/item/weapon/attachment/silencer/rifle = 100,
		/obj/item/weapon/attachment/silencer/shotgun = 100,
		/obj/item/weapon/attachment/silencer/smg = 100,
		/obj/item/weapon/foldable/atgm/bgm_tow = 1000,
		/obj/item/ammo_magazine/m16 = 20,
		/obj/item/ammo_magazine/m14 = 30,
		/obj/item/ammo_casing/rocket/bazooka = 200,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 80,
		/obj/item/weapon/plastique/c4 = 100,
		/obj/item/ammo_casing/rocket/atgm = 150,
		/obj/item/ammo_casing/rocket/atgm/he = 150,
		/obj/item/clothing/under/us_uni/us_camo_woodland = 20,
		/obj/item/clothing/accessory/storage/webbing/us_vest = 20,
		/obj/item/clothing/suit/storage/coat/ww2/us_coat = 30,
		/obj/item/clothing/shoes/jackboots/modern = 20,
		/obj/item/clothing/accessory/armor/coldwar/pasgt = 100,
		/obj/item/clothing/head/helmet/modern/pasgt = 100,
		/obj/item/weapon/reagent_containers/food/snacks/burger = 5,
		/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 5,
		/obj/item/weapon/reagent_containers/food/snacks/hotdog = 5,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 10,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie = 20,
		/obj/item/weapon/reagent_containers/food/snacks/applepie = 20,
		/obj/item/weapon/telephone/mobile = 500,
		/obj/structure/anti_air_crate = 1000,
	)

/mob/living/simple_animal/pepelsibirsk_trader/pacific_trader/New()
	..()
	icon_state = "usptrader"
	icon_living = "usptrader"
	icon_dead = "usptrader_dead"
	speak = list(
		"Traveling across the Pacific, across the wastes of Siberia, and what for? To trade with some backwater Russian town in the middle of nowhere? Hell yeah.",
		"Did you know our President is from Austria? I can't believe it either, but he does good work.",
		"You got the money, I got the guns.",
		"Vietnam may have been a mistake...",
		"I would sell tanks, but they didn't fit on the boat.",
	)
	update_icons()

// ============================================================
// CHINESE TRADER (People's Republic of China)
// ============================================================

/mob/living/simple_animal/pepelsibirsk_trader/chinese_trader
	name = "PRC Trader"
	desc = "A representative of the People's Republic of China, here to conduct socialist trade."
	icon_state = "chinese_trader"
	icon_living = "chinese_trader"
	icon_dead = "chinese_trader_dead"
	faction_relations = "faction_1_relations"
	faction_name = "People's Republic of China"
	products = list(
		/obj/item/weapon/gun/projectile/submachinegun/ak47/chinese = 3,
		/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese = 3,
		/obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese = 3,
		/obj/item/clothing/suit/storage/coat/chinese/officer = 2,
		/obj/item/clothing/suit/storage/coat/chinese = 8,
		/obj/item/clothing/under/chinaguard = 8,
		/obj/item/clothing/head/chinaguardcap = 8,
		/obj/item/clothing/head/chinese_ushanka = 8,
		/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized = 8,
		/obj/item/weapon/reagent_containers/food/snacks/ssicle/osicle = 8,
	)
	prices = list(
		/obj/item/weapon/gun/projectile/submachinegun/ak47/chinese = 50,
		/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese = 30,
		/obj/item/weapon/gun/projectile/submachinegun/ppsh/chinese = 30,
		/obj/item/clothing/suit/storage/coat/chinese/officer = 30,
		/obj/item/clothing/suit/storage/coat/chinese = 25,
		/obj/item/clothing/under/chinaguard = 25,
		/obj/item/clothing/head/chinaguardcap = 15,
		/obj/item/clothing/head/chinese_ushanka = 15,
		/obj/item/clothing/head/helmet/modern/chi_korea_helmet/modernized = 35,
		/obj/item/weapon/reagent_containers/food/snacks/ssicle/osicle = 5,
	)

/mob/living/simple_animal/pepelsibirsk_trader/chinese_trader/New()
	..()
	icon_state = "chinese_trader"
	icon_living = "chinese_trader"
	icon_dead = "chinese_trader_dead"
	speak = list(
		"At least I'm not in China. It's not worth it.",
		"Down with Liu Shaoqi, down with Liu Shaoqi...",
		"Mao is dead, but his legacy lives on!",
		"If you have mangoes, I'll buy them. They're in high demand right now.",
		"I'm heading to Japan after this. Word says that some people there might want our guns.",
	)
	update_icons()

// ============================================================
// SOVIET TRADER (Union of Soviet Socialist Republics)
// ============================================================

/mob/living/simple_animal/pepelsibirsk_trader/soviet_trader
	name = "Soviet Trader"
	desc = "A representative of the Union of Soviet Socialist Republics, here to serve the Motherland."
	icon_state = "soviet_trader"
	icon_living = "soviet_trader"
	icon_dead = "soviet_trader_dead"
	faction_relations = "faction_2_relations"
	faction_name = "Union of Soviet Socialist Republics"
	products = list(
		/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso = 1,
		/obj/item/weapon/gun/projectile/shotgun/pump/ks23 = 1,
		/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22 = 2,
		/obj/item/weapon/gun/launcher/grenade/underslung/gp25 = 2,
		/obj/item/weapon/gun/launcher/rocket/rpg7 = 1,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 3,
		/obj/item/ammo_casing/rocket/pg7v = 2,
		/obj/item/ammo_casing/rocket/og7v = 2,
		/obj/item/weapon/plastique/russian = 1,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 5,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel = 5,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 5,
		/obj/item/weapon/reagent_containers/food/drinks/flask/barflask = 3,
		/obj/item/weapon/reagent_containers/food/drinks/flask/officer = 3,
		/obj/item/weapon/reagent_containers/food/drinks/teapot/filled = 3,
		/obj/item/weapon/reagent_containers/food/drinks/golden_cup = 1,
		/obj/item/weapon/storage/pill_bottle/tramadol = 4,
		/obj/item/weapon/storage/pill_bottle/penicillin = 4,
		/obj/item/weapon/storage/pill_bottle/paracetamol = 4,
		/obj/item/weapon/storage/pill_bottle/citalopram = 4,
		/obj/item/weapon/storage/pill_bottle/potassium_iodide = 4,
	)
	prices = list(
		/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso = 200,
		/obj/item/weapon/gun/projectile/shotgun/pump/ks23 = 150,
		/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22 = 250,
		/obj/item/weapon/gun/launcher/grenade/underslung/gp25 = 100,
		/obj/item/weapon/gun/launcher/rocket/rpg7 = 100,
		/obj/item/weapon/grenade/frag/ugl/shell40mm = 40,
		/obj/item/ammo_casing/rocket/pg7v = 100,
		/obj/item/ammo_casing/rocket/og7v = 100,
		/obj/item/weapon/plastique/russian = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 10,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 10,
		/obj/item/weapon/reagent_containers/food/drinks/flask/barflask = 25,
		/obj/item/weapon/reagent_containers/food/drinks/flask/officer = 50,
		/obj/item/weapon/reagent_containers/food/drinks/teapot/filled = 25,
		/obj/item/weapon/reagent_containers/food/drinks/golden_cup = 500,
		/obj/item/weapon/storage/pill_bottle/tramadol = 150,
		/obj/item/weapon/storage/pill_bottle/penicillin = 150,
		/obj/item/weapon/storage/pill_bottle/paracetamol = 150,
		/obj/item/weapon/storage/pill_bottle/citalopram = 150,
		/obj/item/weapon/storage/pill_bottle/potassium_iodide = 150,
	)

/mob/living/simple_animal/pepelsibirsk_trader/soviet_trader/New()
	..()
	icon_state = "soviet_trader"
	icon_living = "soviet_trader"
	icon_dead = "soviet_trader_dead"
	speak = list(
		"What is done is done. History does not tolerate the subjunctive mood.",
		"Comrades, you ask and we deliver!",
		"Communism in 20 years? Somehow, I doubt it.",
		"Communism in 20 years? This slogan will last centuries.",
		"Surprising how much a currency rises in value once the central bank has been wiped off the map...",
	)
	update_icons()
