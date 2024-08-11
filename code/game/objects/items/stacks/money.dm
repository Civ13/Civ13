// Spanish money was the world currency in the early 18th century. 1 doubloon = 2 escudos = 4 spanish dollars = 32 reales
/obj/item/stack/money/update_icon()
	if (novariants)
		return // TO-DO: Check if the parent proc is actually needed here as a "return ..()"
	if (map.ordinal_age >= 4 && icon_state != "silvercoin_pile")
		var/icon_suffix = ""
		switch(amount)
			if (0 to 49)
				icon_suffix = ""
			if (50 to 99)
				icon_suffix = "_2"
			if (100 to 249)
				icon_suffix = "_3"
			if (250 to 499)
				icon_suffix = "_4"
			if (500 to INFINITY)
				icon_suffix = "_5"
		icon_state = "[initial(icon_state)][icon_suffix]"
	else
		icon_state = initial(icon_state)
	..()
	//TO-DO: Check what the parent proc actually does

/obj/item/stack/money
	name = "gold coins"
	desc = "Shiny gold coins."
	singular_name = "coin"
	icon_state = "goldcoin_pile"
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 8
	throw_range = 10
	amount = 10
	max_amount = 500
	attack_verb = list("hit")
	w_class = ITEM_SIZE_SMALL // fits in pockets
	value = 1
	real_value = 1
	var/novariants = TRUE

/obj/item/stack/money/cents
	name = "Dollar Cents"
	desc = "Small coins that represent fractions of a dollar"
	singular_name = "cent"
	icon_state = "silvercoin_pile"
	amount = 1
	value = 0.04

/obj/item/stack/money/real
	name = "spanish reales"
	desc = "A small silver coin."
	singular_name = "coin"
	icon_state = "real"
	amount = 1
	value = 1

/obj/item/stack/money/real/New()
	update_icon()
	return ..()

/obj/item/stack/money/real/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "real[icon_suffix]"

/obj/item/stack/money/rubles
	name = "Soviet Ruble"
	desc = "A Soviet 1 ruble banknote."
	singular_name = "ruble"
	icon_state = "ruble"
	amount = 1
	value = 1

/obj/item/stack/money/rubles/New()
	update_icon()
	return ..()

/obj/item/stack/money/rubles/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "50"
		if (100 to 299)
			icon_suffix = "100"
		if (300 to 499)
			icon_suffix = "300"
		if (500 to INFINITY)
			icon_suffix = "500"
	icon_state = "ruble[icon_suffix]"
	// TO-DO: Check if the parent update_icon proc has to be called

/obj/item/stack/money/rubles/fivehundred
	amount = 500

/obj/item/stack/money/european
	name = ""
	desc = ""
	singular_name = ""
	icon_state = ""
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 8
	throw_range = 10
	amount = 1
	max_amount = 500
	attack_verb = list("hit")
	w_class = ITEM_SIZE_SMALL // fits in pockets
	value = 1
	real_value = 1
	novariants = TRUE

/obj/item/stack/money/asian
	name = ""
	desc = ""
	singular_name = ""
	icon_state = ""
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 8
	throw_range = 10
	amount = 1
	max_amount = 500
	attack_verb = list("hit")
	w_class = ITEM_SIZE_SMALL // fits in pockets
	value = 1
	real_value = 1
	novariants = TRUE

/obj/item/stack/money/fictional
	name = ""
	desc = ""
	singular_name = ""
	icon_state = ""
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 8
	throw_range = 10
	amount = 1
	max_amount = 500
	attack_verb = list("hit")
	w_class = ITEM_SIZE_SMALL // fits in pockets
	value = 1
	real_value = 1
	novariants = TRUE

// -------------------------------------------------
// FICTIONAL:
// Art and code - goldenfreddycl
// -------------------------------------------------

/obj/item/stack/money/fictional/arstotzkacredit
	name = "Arstotzka Credit"
	desc = "The singular banknote of the official Arstotzka Credit, minted and printed by the Ministry of Trade, and seen as the only legal tender within the borders of Arstotzka. Glory to Arstotzka."
	singular_name = "Arstotzka Credit"
	icon_state = "arstotzkacredit"
	amount = 1
	value = 1

// -------------------------------------------------
// CHINESE FENG SHUI
// Art and code - goldenfreddycl
// -------------------------------------------------

/obj/item/stack/money/asian/fengshui
	name = "Feng Shui Coin"
	desc = "An ancient chinese currency, adopting a unique design as it is quite larger than more conventional currency and features a square-shaped hole in the middle, as well as chinese writing embedded in its design. Typically made of copper alloys."
	singular_name = "coin"
	icon_state = "fengshui"
	amount = 1
	value = 1

// -------------------------------------------------
// BRITISH POUND
// Art and code - goldenfreddycl
// -------------------------------------------------

/obj/item/stack/money/european/britpound
	name = "1 British Pound"
	desc = "A coin representing the 1 British Pound Sterling, its outer ring made of gold coloured nickel-brass, and its inner ring a silver coloured nickel-plated alloy. Engraved upon it is a side-view of the British monarch."
	singular_name = "coin"
	icon_state = "britpound"
	amount = 1
	value = 1

/obj/item/stack/money/european/britpound5
	name = "5 British Pound"
	desc = "A 5 British Pound Sterling banknote, with the British monarch's face imprinted upon it, and coined by the Bank of England."
	singular_name = "5 Pound note"
	icon_state = "5britpound"
	amount = 1
	value = 5

/obj/item/stack/money/european/britpound10
	name = "10 British Pound"
	desc = "A 10 British Pound Sterling banknote, with the British monarch's face imprinted upon it, and coined by the Bank of England."
	singular_name = "10 Pound note"
	icon_state = "10britpound"
	amount = 1
	value = 10

/obj/item/stack/money/european/britpound20
	name = "20 British Pound"
	desc = "A 20 British Pound Sterling banknote, with the British monarch's face imprinted upon it, and coined by the Bank of England."
	singular_name = "20 Pound note"
	icon_state = "20britpound"
	amount = 1
	value = 20

/obj/item/stack/money/european/britpound50
	name = "50 British Pound"
	desc = "A 50 British Pound Sterling banknote, with the British monarch's face imprinted upon it, and coined by the Bank of England."
	singular_name = "50 Pound note"
	icon_state = "50britpound"
	amount = 1
	value = 50

// -------------------------------------------------
// EURO
// Art and code - goldenfreddycl
// -------------------------------------------------

/obj/item/stack/money/european/euro
	name = "1 Euro Coin"
	desc = "A 1 Euro coin, with a symbol of one of the member states engraved upon it, its silver-coloured inner ring made of a cooper-nickel alloy, and its gold-coloured outer ring made of a copper-zinc-nickel alloy"
	singular_name = "coin"
	icon_state = "euro"
	amount = 1
	value = 1

/obj/item/stack/money/european/euro2
	name = "2 Euro Coin"
	desc = "A 2 Euro coin, with a symbol of one of the member states engraved upon it, its gold-coloured inner ring made of a copper-zinc-nickel alloy, and its silver-coloured outer ring made of a cooper-nickel alloy"
	singular_name = "coin"
	icon_state = "2euro"
	amount = 1
	value = 2

/obj/item/stack/money/european/euro5
	name = "5 Euro Note"
	desc = "A 5 Euro banknote, depicting bridges and arches/doorways in Classical architecture with a mixture of green, blue and a touch of yellow. Imprinted upon it is the flag of the European Union"
	singular_name = "5 Euro note"
	icon_state = "5euro"
	amount = 1
	value = 5

/obj/item/stack/money/european/euro10
	name = "10 Euro Note"
	desc = "A 10 Euro banknote, depicting bridges and arches/doorways in Romanesque architecture with a mixture of various shades of red. Imprinted upon it is the flag of the European Union"
	singular_name = "10 Euro note"
	icon_state = "10euro"
	amount = 1
	value = 10

/obj/item/stack/money/european/euro20
	name = "20 Euro Note"
	desc = "A 20 Euro banknote, depicting bridges and arches/doorways in Gothic architecture with a mixture of shades of blue, some red and a touch of green. Imprinted upon it is the flag of the European Union"
	singular_name = "20 Euro note"
	icon_state = "20euro"
	amount = 1
	value = 20

/obj/item/stack/money/european/euro50
	name = "50 Euro Note"
	desc = "A 50 Euro banknote, depicting bridges and arches/doorways in the Rennaissance era with a mixture of yellow, orange and a touch of brown. Imprinted upon it is the flag of the European Union"
	singular_name = "50 Euro note"
	icon_state = "50euro"
	amount = 1
	value = 50

/obj/item/stack/money/european/euro100
	name = "100 Euro Note"
	desc = "A 100 Euro banknote, depicting bridges and arches/doorways in the Baroque and Rococo style with a mixture of green and yellow. Imprinted upon it is the flag of the European Union"
	singular_name = "100 Euro note"
	icon_state = "100euro"
	amount = 1
	value = 100

/obj/item/stack/money/european/euro200
	name = "200 Euro Note"
	desc = "A 200 Euro banknote, depicting bridges and arches/doorways in Art Noveau style with a mixture of ywllow, some blue and some brown. Imprinted upon it is the flag of the European Union"
	singular_name = "200 Euro note"
	icon_state = "200euro"
	amount = 1
	value = 200

/obj/item/stack/money/european/euro500
	name = "500 Euro Note"
	desc = "A 500 Euro banknote, depicting bridges and arches/doorways in Modern architecture with a mixture of purple and a touch of gold. Imprinted upon it is the flag of the European Union"
	singular_name = "500 Euro note"
	icon_state = "500euro"
	amount = 1
	value = 500

/obj/item/stack/money/european/New()
	update_icon()
	return ..()

/obj/item/stack/money/european/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "[initial(icon_state)][icon_suffix]"

/obj/item/stack/money/asian/New()
	update_icon()
	return ..()

/obj/item/stack/money/asian/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "[initial(icon_state)][icon_suffix]"

/obj/item/stack/money/fictional/New()
	update_icon()
	return ..()

/obj/item/stack/money/fictional/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "[initial(icon_state)][icon_suffix]"

/obj/item/stack/money/yen
	name = "yen"
	desc = "A japanese 1 yen coin."
	singular_name = "yen"
	icon_state = "yen"
	amount = 1
	value = 0.01
	max_amount = 2500
	flags = CONDUCT

/obj/item/stack/money/yen/New()
	update_icon()
	return ..()

/obj/item/stack/money/yen/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (2)
			icon_suffix = "_2"
		if (3)
			icon_suffix = "_3"
		if (4)
			icon_suffix = "_4"
		if (5)
			desc = "A japanese 5 yen coin"
			icon_suffix = "_5"
		if (6)
			icon_suffix = "_6"
		if (7 to 9)
			icon_suffix = "_7"
		if (10 to 49)
			desc = "A japanese 10 yen coin"
			icon_suffix = "_10"
		if (50 to 99)
			desc = "A japanese 50 yen coin"
			icon_suffix = "_50"
		if (100 to 499)
			desc = "A japanese 100 yen coin"
			icon_suffix = "_100"
		if (500)
			desc = "A japanese 500 yen coin"
			icon_suffix = "_500"
		if (501 to INFINITY)
			desc = "A japanese 500 yen coin with some other Yen coins."
			icon_suffix = "_500+"
	icon_state = "yen[icon_suffix]"

/obj/item/stack/money/dollar
	name = "spanish dollars"
	desc = "A silver coin, also called piece of eight, worth 8 reales."
	singular_name = "dollar"
	icon_state = "5dollar"
	amount = 1
	value = 8
	flags = CONDUCT

/obj/item/stack/money/dollar/New()
	if (map && map.ordinal_age >= 4)
		if (map.ID == MAP_KANDAHAR)
			name = "1 Dollar Bill"
			desc = "Paper bank note valued at 1 dollar."
			singular_name = "1 Dollar Bill"
			icon_state = "dollar"
			value = 1
			novariants = FALSE
			flags = FALSE
			update_icon()
			return ..()
		else
			name = "5 Dollar Bills"
			desc = "Paper bank note valued at five dollars."
			singular_name = "5 Dollar Bill"
			icon_state = "5dollar"
			value = 20
			novariants = FALSE
			flags = FALSE
			update_icon()
			return ..()
	else if (map.ordinal_age == 3)
		name = "spanish dollars"
		desc = "A silver coin, also called piece of eight, worth 8 reales."
		singular_name = "dollar"
		icon_state = "silvercoin_pile"
		value = 8
		return ..()
	else
		name = "kreuzers"
		desc = "A silver coin, worth 4 pfennig."
		singular_name = "kreuzer"
		icon_state = "silvercoin_pile"
		value = 4
		return ..()

/obj/item/stack/money/dollar100
	name = "100 Dollar Bill"
	desc = "Paper bank note valued at one-hundred dollars"
	singular_name = "100 Dollar note"
	icon_state = "100dollar"
	value = 100
	amount = 1

/obj/item/stack/money/dollar100/New()
	update_icon()
	return ..()

/obj/item/stack/money/dollar100/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "50"
		if (100 to 299)
			icon_suffix = "100"
		if (300 to 499)
			icon_suffix = "300"
		if (500 to INFINITY)
			icon_suffix = "500"
	icon_state = "100dollar[icon_suffix]"
	//TO-DO: Check if the parent update_icon proc has to be called

/obj/item/stack/money/escudo
	name = "spanish escudos"
	desc = "A gold coin. Worth 16 reales."
	singular_name = "coin"
	icon_state = "escudo"
	amount = 1
	value = 16

	flags = CONDUCT
/obj/item/stack/money/escudo/New()
	update_icon()
	return ..()

/obj/item/stack/money/escudo/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "escudo[icon_suffix]"

/obj/item/stack/money/doubloon
	name = "spanish doubloons"
	desc = "A large gold coin, the largest in circulation. Worth 32 reales."
	singular_name = "coin"
	icon_state = "dobloon"
	amount = 1
	value = 32
	flags = CONDUCT

/obj/item/stack/money/doubloon/New()
	update_icon()
	return ..()

/obj/item/stack/money/doubloon/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "dobloon[icon_suffix]"

/obj/item/stack/money/goldnugget
	name = "gold nuggets"
	desc = "A shiny gold nugget."
	singular_name = "nugget"
	icon_state = "goldnugget"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 7
	amount = 1
	max_amount = 3
	value = 96
	flags = CONDUCT

/obj/item/cursedtreasure
	name = "cursed treasure"
	desc = "A piece of native jewelry, with a strange glow..."
	icon_state = "goldstuff1"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 7
	value = 0
	flags = CONDUCT
/obj/item/cursedtreasure/New()
	..()
	icon_state = "goldstuff[rand(1,3)]"

/obj/structure/oil_deposits
	name = "oil deposit"
	desc = "This deposit doesn't have a owner yet."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard_oil"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	flammable = FALSE
	var/storedvalue = 0
	var/faction = null
	var/health = 200
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/oil_deposits/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * TRUE
		if ("brute")
			health -= W.force * 0.5
	playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/oil_deposits/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		qdel(src)
		return

/obj/structure/oil_deposits/New()
	..()
	check_value()

/obj/structure/oil_deposits/proc/check_value()
	storedvalue = 0
	for (var/obj/item/weapon/reagent_containers/glass/barrel/BB in range(1, src))
		storedvalue += BB.reagents.get_reagent_amount("petroleum")
	if (faction)
		desc = "Belongs to the [faction]. Stored oil: [storedvalue]."
	spawn(600) // 1 minute
		check_value()

/obj/structure/oil_deposits/attack_hand(mob/living/human/user as mob)
	if (user.civilization == "none")
		user << "You are not part of a faction!"
		return
	else if (faction == null)
		faction = user.civilization
		desc = "Belongs to the [faction]. Stored oil: [storedvalue]."
		user << "You set the oil deposit faction as [faction]."
		return
	else
		..()

/obj/item/stack/money/goldvaluables
	name = "gold valuables"
	desc = "A bunch of valuables."
	singular_name = "gold valuable"
	icon_state = "goldstuff1"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 7
	amount = 1
	max_amount = 5
	value = 48
	flags = CONDUCT

/obj/item/stack/money/goldvaluables/New()
	..()
	icon_state = "goldstuff[rand(1,3)]"

/obj/item/stack/money/gems
	name = "gems"
	desc = "Assorted precious gems."
	singular_name = "gem"
	icon_state = "gem1"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 5
	throw_range = 7
	amount = 1
	max_amount = 8
	value = 35

/obj/item/stack/money/gems/New()
	..()
	icon_state = "gem[rand(1,2)]"

/obj/item/stack/money/pearls
	name = "pearls"
	desc = "A bunch of pearls. Looks valuable!"
	singular_name = "nugget"
	icon_state = "pearls1"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 4
	throw_range = 8
	amount = 1
	max_amount = 8
	value = 45

/obj/item/stack/money/pearls/New()
	..()
	icon_state = "pearls[rand(1,2)]"

/obj/item/stack/money/coppercoin
	name = "copper coins"
	desc = "A small copper coin. Worth 1/10th of a silver coin or 1/40th of a gold coin."
	singular_name = "copper coin"
	icon_state = "coppercoin_pile"
	amount = 1
	value = 0.1
	flags = CONDUCT

/obj/item/stack/money/coppercoin/New()
	update_icon()
	return ..()

/obj/item/stack/money/coppercoin/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "coppercoin_pile[icon_suffix]"

/obj/item/stack/money/coppercoin/twohundred
	amount = 20

/obj/item/stack/money/silvercoin
	name = "silver coins"
	desc = "A small silver coin. Worth 1/4th of a gold coin or 10 copper coins."
	singular_name = "silver coin"
	icon_state = "silvercoin_pile"
	amount = 1
	value = 1
	flags = CONDUCT

/obj/item/stack/money/silvercoin/New()
	update_icon()
	return ..()

/obj/item/stack/money/silvercoin/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 49)
			icon_suffix = ""
		if (50 to 99)
			icon_suffix = "_2"
		if (100 to 299)
			icon_suffix = "_3"
		if (300 to 499)
			icon_suffix = "_4"
		if (500 to INFINITY)
			icon_suffix = "_5"
	icon_state = "silvercoin_pile[icon_suffix]"

/obj/item/stack/money/silvercoin/twohundred
	amount = 200

/obj/item/stack/money/goldcoin
	name = "gold coins"
	desc = "A small gold coin. Worth 4 silver coins or 40 copper coins."
	singular_name = "gold coin"
	icon_state = "goldcoin_pile"
	amount = 1
	value = 4
	flags = CONDUCT

/obj/item/stack/money/goldcoin/New()
	update_icon()
	return ..()

/obj/item/stack/money/goldcoin/update_icon()
	var/icon_suffix = ""
	switch(amount)
		if (1 to 124)
			icon_suffix = ""
		if (125 to 249)
			icon_suffix = "_2"
		if (250 to 374)
			icon_suffix = "_3"
		if (375 to INFINITY)
			icon_suffix = "_4"
	icon_state = "goldcoin_pile[icon_suffix]"

/obj/item/stack/money/bitcoin
	name = "bitcoin"
	desc = "A physical bitcoin."
	singular_name = "bitcoin"
	icon_state = "bitcoin"
	amount = 1
	value = 5000

/obj/item/stack/money/real/five
	amount = 5
/obj/item/stack/money/real/ten
	amount = 10
/obj/item/stack/money/real/fifteen
	amount = 15
/obj/item/stack/money/real/twenty
	amount = 20
/obj/item/stack/money/real/fifty
	amount = 50

/obj/item/stack/money/dollar/twenty
	amount = 20
/obj/item/stack/money/dollar/ten
	amount = 10
/obj/item/stack/money/escudo/ten
	amount = 10
/obj/item/stack/money/doubloon/ten
	amount = 10
/obj/item/stack/money/dollar/onehundy
	amount = 100
/obj/item/stack/money/dollar/five
	amount = 5

/////////////////////////SKYRIM/////////////////////////////

/obj/item/stack/money/septim
	name = "septim"
	desc = "A single septim coin."
	singular_name = "septim"
	icon_state = "septim"
	amount = 1
	value = 1
	max_amount = 500
	flags = CONDUCT

/obj/item/stack/money/septim/New()
	if(amount == 2)
		icon_state = "septim_2"
	if(amount == 3)
		icon_state = "septim_3"
	if(amount == 4)
		icon_state = "septim_4"
	if(amount == 5)
		icon_state = "septim_5"
	if(amount == 6)
		icon_state = "septim_6"
	if(amount >= 7)
		icon_state = "septim_7"
	if(amount >= 10)
		icon_state = "septim_10"
	if(amount >= 50)
		icon_state = "septim_50"
	if(amount >= 100)
		icon_state = "septim_100"
	if(amount == 500)
		icon_state = "septim_500"
	if(amount > 500)
		icon_state = "septim_500+"
	update_icon()
	return ..()

/obj/item/stack/money/septim/update_icon()
	if(amount == 2)
		icon_state = "septim_2"
	if(amount == 3)
		icon_state = "septim_3"
	if(amount == 4)
		icon_state = "septim_4"
	if(amount == 5)
		icon_state = "septim_5"
	if(amount == 6)
		icon_state = "septim_6"
	if(amount >= 7)
		icon_state = "septim_7"
	if(amount >= 10)
		icon_state = "septim_10"
	if(amount >= 50)
		icon_state = "septim_50"
	if(amount >= 100)
		icon_state = "septim_100"
	if(amount == 500)
		icon_state = "septim_500"
	if(amount > 500)
		icon_state = "septim_500+"
	..()
