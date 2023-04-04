//spanish money was the world currency in the early 18th century. 1 doubloon = 2 escudos = 4 spanish dollars = 32 reales
/obj/item/stack/money/update_icon()
	if(novariants)
		return ..()
	if(amount >= 2)
		if (map.ordinal_age >= 4)
			if(icon_state != "silvercoin_pile")
				icon_state = "[initial(icon_state)]_2"

	else
		if (map.ordinal_age >= 4)
			icon_state = initial(icon_state)
	..()


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
	singular_name = "real"
	icon_state = "dollar" //Damn jerry rig
	amount = 1
	value = 1
	flags = CONDUCT
/obj/item/stack/money/real/New()
	if (map.ordinal_age >= 4)
		if (map.ID == MAP_BANK_ROBBERY)
			name = "Dollar Bill"
			desc = "Paper bank note valued at 1 dollar."
			singular_name = "Dollar Bill"
			icon_state = "dollar"
			value = 1
			novariants = FALSE
			flags = FALSE
			update_icon()
			return ..()
		else
			name = "Dollar Bill"
			desc = "Paper bank note valued at one dollar."
			singular_name = "Dollar Bill"
			icon_state = "dollar"
			value = 4
			novariants = FALSE
			flags = FALSE
			update_icon()
			return ..()
	else if (map.ordinal_age == 3)
		name = "spanish reales"
		desc = "A small silver coin."
		singular_name = "real"
		icon_state = "silvercoin_pile"
		value = 1
		return ..()
	else
		name = "pfennige"
		desc = "A small silver coin."
		singular_name = "pfennig"
		icon_state = "silvercoin_pile"
		value = 1
		return ..()
/obj/item/stack/money/rubles
	name = "soviet ruble"
	desc = "A Soviet 1 ruble banknote."
	singular_name = "ruble"
	icon_state = "ruble" //Damn jerry rig
	amount = 1
	value = 1
/obj/item/stack/money/yen
	name = "yen"
	desc = "A japanese 1 yen coin."
	singular_name = "yen"
	icon_state = "yen" //Damn jerry rig
	amount = 1
	value = 0.01
	max_amount = 2500
	flags = CONDUCT
/obj/item/stack/money/yen/New()
	if(amount == 2)
		icon_state = "yen_2"
	if(amount == 3)
		icon_state = "yen_3"
	if(amount == 4)
		icon_state = "yen_4"
	if(amount == 5)
		desc = "A japanese 5 yen coin"
		icon_state = "yen_5"
	if(amount == 6)
		icon_state = "yen_6"
	if(amount >= 7)
		icon_state = "yen_7"
	if(amount >= 10)
		desc = "A japanese 10 yen coin"
		icon_state = "yen_10"
	if(amount >= 50)
		desc = "A japanese 50 yen coin"
		icon_state = "yen_50"
	if(amount >= 100)
		desc = "A japanese 100 yen coin"
		icon_state = "yen_100"
	if(amount == 500)
		desc = "A japanese 500 yen coin"
		icon_state = "yen_500"
	if(amount > 500)
		desc = "A japanese 500 yen coin with some other Yen coins."
		icon_state = "yen_500+"
	update_icon()
	return ..()
/obj/item/stack/money/yen/update_icon()
	if(amount == 2)
		icon_state = "yen_2"
	if(amount == 3)
		icon_state = "yen_3"
	if(amount == 4)
		icon_state = "yen_4"
	if(amount == 5)
		desc = "A japanese 5 yen coin"
		icon_state = "yen_5"
	if(amount == 6)
		icon_state = "yen_6"
	if(amount >= 7)
		icon_state = "yen_7"
	if(amount >= 10)
		desc = "A japanese 10 yen coin"
		icon_state = "yen_10"
	if(amount >= 50)
		desc = "A japanese 50 yen coin"
		icon_state = "yen_50"
	if(amount >= 100)
		desc = "A japanese 100 yen coin"
		icon_state = "yen_100"
	if(amount == 500)
		desc = "A japanese 500 yen coin"
		icon_state = "yen_500"
	if(amount > 500)
		desc = "A japanese 500 yen coin with some other Yen coins."
		icon_state = "yen_500+"
	..()
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
		if (map.ID == MAP_SOVAFGHAN)
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

/obj/item/stack/money/escudo
	name = "spanish escudos"
	desc = "A gold coin. Worth 16 reales."
	singular_name = "escudo"
	icon_state = "20dollar"
	amount = 1
	value = 16
	flags = CONDUCT
/obj/item/stack/money/escudo/New()
	if (map.ordinal_age >= 4) //Not being called
		name = "20 Dollar Bill"
		desc = "Paper bank note valued at twenty dollars."
		icon_state = "20dollar"
		value = 80
		novariants = FALSE
		flags = FALSE
		update_icon()
		return ..()
	else if (map.ordinal_age == 3)
		name = "spanish escudos"
		desc = "A gold coin. Worth 16 reales."
		singular_name = "escudo"
		icon_state = "goldcoin_pile"
		value = 16
		return ..()
	else
		name = "gulden"
		desc = "A gold coin, worth 60 kreuzers or 240 pfennige."
		singular_name = "gulden"
		icon_state = "goldcoin_pile"
		value = 60
		return ..()
/obj/item/stack/money/doubloon
	name = "spanish doubloons"
	desc = "A large gold coin, the largest in circulation. Worth 32 reales."
	singular_name = "doubloon"
	icon_state = "50dollar"
	amount = 1
	value = 32
	flags = CONDUCT
/obj/item/stack/money/doubloon/New()
	if (map.ordinal_age >= 4)
		name = "50 Dollar Bill"
		desc = "Paper bank note valued at fifty dollars."
		singular_name = "50 Dollar Bill"
		icon_state = "50dollar"
		flags = FALSE
		value = 200
		novariants = FALSE
		update_icon()
		return ..()
	else if (map.ordinal_age == 3)
		name = "spanish doubloons"
		desc = "A large gold coin, the largest in circulation. Worth 32 reales."
		singular_name = "doubloon"
		icon_state = "goldcoin_pile"
		value = 32
		return ..()
	else
		name = "thaler"
		desc = "A valuable gold coin, worth 2 gulden or 120 kreuzers or 480 pfennige."
		singular_name = "thalers"
		icon_state = "goldcoin_pile"
		value = 120
		return ..()
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
	spawn(600)
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

/obj/structure/carriage
	name = "Stagecoach Load"
	desc = ""
	icon = 'icons/obj/storage.dmi'
	icon_state = "miningcaropen"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	flammable = FALSE
	var/storedvalue = 0
	var/prevent = FALSE
	var/faction1val = 0
	var/faction2val = 0
	not_movable = TRUE
	not_disassemblable = TRUE
/obj/structure/carriage/New()
	..()
	desc = "West Side: [faction1val]. East Side: [faction2val]."
	timer()
/obj/structure/carriage/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack/money) || istype(W,/obj/item/stack/material/gold) || istype(W,/obj/item/stack/material/silver) || istype(W,/obj/item/stack/material/diamond))
		if (ishuman(user))
			var/mob/living/human/H = user
			if (H.original_job_title == "West Side Gang")
				faction1val += (W.value*W.amount)
			else if (H.original_job_title == "East Side Gang")
				faction2val += (W.value*W.amount)
			desc = "West Side: [faction1val]. East Side: [faction2val]."
			user << "You place \the [W] inside \the [src]."
		qdel(W)
		if (faction1val >= 750)
			map.update_win_condition()
		else if (faction2val >= 750)
			map.update_win_condition()
	else
		return
/obj/structure/carriage/proc/timer()
	spawn(4000)
		world << "<big>Current status: West Side Gang: <b>[faction1val]/700</b>. East Side Gang: <b>[faction2val]/700</b>."
		timer()

/obj/structure/carriage_tdm
	name = "Stagecoach Load"
	desc = ""
	icon = 'icons/obj/storage.dmi'
	icon_state = "miningcaropen"
	anchored = TRUE
	opacity = FALSE
	density = TRUE
	flammable = FALSE
	var/storedvalue = 0
	var/prevent = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/carriage_tdm/New()
	..()
	desc = "Stored Value: [storedvalue]."
	timer()
/obj/structure/carriage_tdm/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack/money) || istype(W,/obj/item/stack/material/gold) || istype(W,/obj/item/stack/material/silver) || istype(W,/obj/item/stack/material/diamond))
		storedvalue += (W.value*W.amount)
		desc = "Stored Value: [storedvalue]."
		user << "You place \the [W] inside \the [src]."
		qdel(W)
		if (storedvalue >= 1500)
			map.update_win_condition()
	else
		return
/obj/structure/carriage_tdm/proc/timer()
	spawn(4000)
		world << "<big>Current status: Outlaws: <b>[storedvalue]/1500 Dollars</b></big>."
		timer()

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
	desc = "a bunch of pearls. Looks valuable!"
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
	desc = "A small copper coin. Worth 1/10th of a silver coin."
	singular_name = "copper coin"
	icon_state = "coppercoin_pile"
	amount = 1
	value = 0.1
	flags = CONDUCT

/obj/item/stack/money/coppercoin/twohundred
	amount = 20

/obj/item/stack/money/silvercoin
	name = "silver coins"
	desc = "A small silver coin. Worth 1/4th of a gold coin."
	singular_name = "silver coin"
	icon_state = "silvercoin_pile"
	amount = 1
	value = 1
	flags = CONDUCT

/obj/item/stack/money/silvercoin/twohundred
	amount = 20

/obj/item/stack/money/goldcoin
	name = "gold coins"
	desc = "A small gold coin. Worth 4 silver coins or 40 copper coins."
	singular_name = "gold coin"
	icon_state = "goldcoin_pile"
	amount = 1
	value = 4
	flags = CONDUCT

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
	icon_state = "septim" //Damn jerry rig
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
