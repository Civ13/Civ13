//Food items that are eaten normally and don't leave anything behind.
var/const/debug_snacks = FALSE //if you want to see new food creating logs set it to TRUE
// Test-unit for re-check all snacks by creating call with debug panel via Advanced Proc Call
/*
/obj/item/weapon/reagent_containers/food/snacks/proc/test_unit()
	var/paths = typesof(/obj/item/weapon/reagent_containers/food/snacks)
	for (var/path in paths)
		new path()
*/
//	TODO: Make another way to eat, drink, piss, poo! Run out from crazyness of some UNITS system, with strange bitesizes etc
//		Make a system based on volumes: liters, milliliters, etc.
//	Redesign the smoking system, in which products will move into the body based on the "burning" process.
//	Redesign the rot and decay system, where the reagents in the products will be converted based on the "rot" process.
// 		Some will then go into the atmosphere, some into the earth, saturating it with reagents (chemicals and so on).
//		Some will attract vermins (orderlies), who will consume these substances.
//	Final redesign of drying system, based on reagents and "drying" process, but not only items creation, deletion.
/obj/item/weapon/reagent_containers/food/snacks
	name = "snack" //Name that displays in the UI.
	desc = "yummy" //String, that you see, when examine
	icon = 'icons/obj/food/food.dmi' //Icons file. Don't define it, if you not want to use another file.
	icon_state = null //Icon. By default from icon file, if you don't inherit it with custom file.
	color = null //Additional coloring of icon. Usual as grayscale icon, but you may do rotten icon by adding disguisting color for original icon.
	center_of_mass = list("x"=16, "y"=16) //Used for table placement, by default it is center of icon
	filling_color = "#7F7F7F" //which color it will be in sandwiches or in spoon/fork/chopsticks
	var/nutriment_amt = 0 //By default, the snack does have reagent "nutriment"
	var/list/nutriment_desc = list("food" = 1) //Description, what tastes have reagent "nutriment" and how much does it taste as multiplicator, think about it as flavour component, not ingredient
	var/bitesize = null //As bigger than bigger amount of reagents will transfer to "stomach" per one "bite"; it's will be autocalculated if not set
	var/biteamount = null //Use this for autocalculate bitesize by your own way; it's will be autocalculated if not set
	var/bitecount = 0 //How many times food item was "biten". It will increase when someone "bite" snack.
	var/trash = null //Trash item, that will appear in hand after full consume of snack
	var/slice_path = null //Sliced item, that will appear after "slicing"
	var/slices_num = 0 //Count of slices at item, for example pie, that may sliced at 4 parts must have slices_num = 4 reagents will be transferred to sliced item
	dried_type = null //Item, that will appear after drying (or dehydrating) process
	dry_size = 2 //How many units will a drying item take in a dehydrator or dryer; dehydrator have 4 rows with 3 units each
	var/dry = FALSE //That this must be used for smoking not usual snack... think about it!
	w_class = ITEM_SIZE_SMALL //Size of the object, used in sized storage system
	decay = 15*600 //Decay time limit, in deciseconds. 0 means it doesn't decay. See details at food.dm in food_decay()
	decaytimer = 0 //Timer of decaying. See details at food.dm in food_decay()
	var/non_vegetarian = FALSE //If not edible for vegetarians make it TRUE, don't forget to add it to meat dishes
	value = null //If you think it must cost another sum - correct this; it's will be autocalculated if not set
	roasted = FALSE //Is already roasted or not? See details in oven.dm. Also used meat.dm. And used below in this .dm
	boiled = FALSE //Is boiled or not. See details in pot.dm
	raw = FALSE //Is raw or not. Used in oven.dm, pot.dm and complex_production.dm. Give chance to poisoning from food.
	//			    In fact, it is currently used for meat and fish products that may rot.
	satisfaction = 0 //Mood modificator for whole item. Positive is good, negative is bad. Look at details in procedure On_Consume below
	disgusting = FALSE //Unpleasant food. Used in oven.dm process()
	rots = FALSE //Is it have rot mechanics in food_decay(). See details at food.dm
	rotten = FALSE //Is it rotten or not.
	rotten_icon_state = "" //Icon state for rotten product. Must be at same icons .dmi file!!!
	flags = USEDELAY //see more at predefines.dm and atoms.dm

//Items in the "Snacks" subcategory are food items that people actually eat. The key points are that they are created
//	already filled with reagents and are destroyed when empty. Additionally, they make a "munching" noise when eaten.

//Notes by Darem: Food in the "snacks" subtype can hold a maximum of 50 units Generally speaking, you don't want to go over 40
//	total for the item because you want to leave space for extra condiments. If you want effect besides healing, add a reagent for
//	it. Try to stick to existing reagents when possible (so if you want a stronger healing effect, just use Tricordrazine). On use
//	effect (such as the old officer eating a donut code) requires a unique reagent (unless you can figure out a better way).

//The nutriment reagent and bitesize variable replace the old heal_amt and amount variables. Each unit of nutriment is equal to
//	2 of the old heal_amt variable. Bitesize is the rate at which the reagents are consumed. So if you have 6 nutriment and a
//	bitesize of 2, then it'll take 3 bites to eat. Unlike the old system, the contained reagents are evenly spread among all
//	the bites. No more contained reagents = no more bites.

//It takes 23.3 units of drinks from full thirst to full saturation for standard drinks
//It takes 13.3 units of nutriment from full hunger to full satiety (or 15.2 units from near death starvation to full satiety) for standard nutriment
//Look at Chemistry-Reagents-Food-Drinks.dm for premaded nutriments and drinks

//There is only one way to add "nutriment" reagent correctly. And that are realised at New() procedure below.
//	If you want add another "nutriment" use list("flavour"=flavour strength, ...) as list of all flavours, that adds to "nutriment"
//  By the way you also may add any reagent with additional custom flavour(s)
//  If you want add already premade reagent (ANY), you must use that construction in in the definition of the item:
//	New()
//		..()
//		reagents.add_reagent("reagent_id", amount, custom_description_list)

/obj/item/weapon/reagent_containers/food/snacks/proc/nutriments_value() //return nutrition factor of food
	var/NV = 0
	if (reagents)
		var/datum/reagent/nutriment/thisN
		var/datum/reagent/drink/thisD
		for (var/datum/reagent/R in reagents.reagent_list)
			if (istype(R,/datum/reagent/nutriment))
				thisN = R
				NV += thisN.nutriment_factor*R.volume
				continue
			if (istype(R,/datum/reagent/drink))
				thisD = R
				NV += thisD.nutrition*R.volume
				continue
	return NV

/obj/item/weapon/reagent_containers/food/snacks/proc/water_value(with_water = TRUE) //return watering of all reagents with water reagent or without it
	var/WV = 0
	if (reagents)
		for (var/datum/reagent/R in reagents.reagent_list)
			if (istype(R,/datum/reagent/drink/quinine))
				continue
			if (istype(R,/datum/reagent/drink/health))
				continue
			if (istype(R,/datum/reagent/drink/stamina))
				continue
			if (istype(R,/datum/reagent/water))
				if (with_water)
					WV += R.volume * 15
			if (istype(R,/datum/reagent/drink/milk)) //yes, no continue here, because milk do it in two places of code at this moment
				WV += R.volume * 10
			if (istype(R,/datum/reagent/drink))
				WV += R.volume * 15
				continue
			if (istype(R,/datum/reagent/ethanol/mead)) //mead inherit watering
				continue
			if (istype(R,/datum/reagent/ethanol))
				WV += R.volume * 40
	return WV

/obj/item/weapon/reagent_containers/food/snacks/proc/appraise()
//Calculate value for trading system if not set. If you want to recalculate it, set it to null before calling proc
	if (value == null)
		if (reagents)
			value = max(0, ceil((nutriments_value()*2 + water_value(FALSE)*0.5)/30 + satisfaction/2  - 0.5))

/obj/item/weapon/reagent_containers/food/snacks/proc/AVim()
//Appraise volume in milliliters. This is a very empirical approximation, but we have what we have at this moment
//nutriments have "magical" volume, that not are visible at first look, watering reagents too have this "magic"
	return reagents.total_volume + nutriments_value()*1.5 + water_value()

/obj/item/weapon/reagent_containers/food/snacks/proc/recalculate_bitesize()
//Calculating biteamount if not set and
	if (reagents)
		var/appraise_volume_in_milliliters = AVim()
		switch (appraise_volume_in_milliliters)
			if (0 to 100)	w_class = ITEM_SIZE_TINY
			if (100 to 500)	w_class = ITEM_SIZE_SMALL
			else			w_class = ITEM_SIZE_NORMAL
		if (!biteamount)
			if (bitesize)
				biteamount = ceil(reagents.total_volume/bitesize)
			else
				biteamount = ceil(appraise_volume_in_milliliters/35) //Let's take as the norm a volume equal to 35 milliliters per bite/drink
		if (!biteamount || biteamount<0) //we must have a value for next step calc if happens 0
			biteamount = 1
		if (!bitesize)
			bitesize = ceil(reagents.total_volume*10/biteamount)/10

/obj/item/weapon/reagent_containers/food/snacks/New()
	..()
	if (nutriment_amt>0)
		reagents.add_reagent("nutriment", nutriment_amt, nutriment_desc)
	spawn(1) //because we need to work new() proc of child before this calculations
		recalculate_bitesize()
		appraise()
		if (debug_snacks) //for debugging log of calculated values snacks creating on/off it by set TRUE/FALSE at begining of snacks.dm (this file)
			message_admins("Created snack: [name]. Bite amount: [biteamount], bite size: [bitesize]. Value: [value].")
			if (reagents)
				message_admins("Size: [round((AVim()*100)/100)] milliliters")
			else
				message_admins("SIZE NOT DEFINED! NO REAGENTS!!!")

/obj/item/weapon/reagent_containers/food/snacks/proc/over(var/mob/M) //end of snack
	usr.drop_from_inventory(src)	//so icons update :[
	if (trash)
		if (ispath(trash,/obj/item))
			var/obj/item/TrashItem = new trash(usr)
			usr.put_in_hands(TrashItem)
		else if (istype(trash,/obj/item))
			usr.put_in_hands(trash)
	qdel(src)

//Placeholder for effect that trigger on eating that aren't tied to reagents.
/obj/item/weapon/reagent_containers/food/snacks/proc/On_Consume(var/mob/M)
	if (!usr)
		return
	var/mob/living/human/H = M
	if (ishuman(H))
		if (H.orc || H.crab || H.wolfman)
			H.mood += abs(ceil(satisfaction/biteamount)) //orcs, crabs and wolfmans will be get satisfaction positive anyway from any food
		else
			H.mood += ceil(satisfaction/biteamount) //standard humans and other human-races reactions
		if (raw)
			if (!H.orc && !H.crab && !H.wolfman && !H.lizard)
				H.reagents.add_reagent("food_poisoning", pick(0,0,1)) //1/3 chance to be poisoned if you are not orc, crab, wolfman or lizard
	M.rad_act(radiation) //need be before qdel(src) may happens
	if (!reagents.total_volume)
		M.visible_message("<span class='notice'>[M] finishes eating \the [src].</span>","<span class='notice'>You finish eating \the [src].</span>")
		over(M)

/obj/item/weapon/reagent_containers/food/snacks/attack_self(mob/user as mob)
	return

/obj/item/weapon/reagent_containers/food/snacks/attack(mob/M as mob, mob/user as mob, def_zone)
	if (reagents)
		if (!reagents.total_volume)
			user << "<span class='danger'>None of [src] left!</span>"
			over(user)
			return FALSE
	if (istype(M, /mob/living/human))
		//TODO: replace with standard_feed_mob() call.
		var/mob/living/human/C = M
		var/fullness = C.get_fullness()
		if (C == user)								//If you're eating it yourself
			if (istype(C,/mob/living/human))
				var/mob/living/human/H = M
				if (!H.check_has_mouth())
					user << "Where do you intend to put \the [src]? You don't have a mouth!"
					return
				var/obj/item/blocked = H.check_mouth_coverage()
				if (blocked)
					user << "<span class='warning'>\The [blocked] is in the way!</span>"
					return
				if (H.gorillaman || H.find_trait("Vegan"))
					if (non_vegetarian)
						user << "<span class='warning'>You are a vegan/herbivore! You can't eat this!</span>"
						return
				else if (H.wolfman || H.crab || H.find_trait("Carnivore"))
					if (!non_vegetarian)
						user << "<span class='warning'>You are a carnivore! You can't eat this!</span>"
						return
			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN) //puts a limit on how fast people can eat/drink things
			if (fullness <= 50)
				C << "<span class='danger'>You hungrily chew out a piece of [src] and gobble it!</span>"
			if (fullness > 50 && fullness <= 150)
				C << "<span class='notice'>You hungrily begin to eat [src].</span>"
			if (fullness > 150 && fullness <= 580)
				C << "<span class='notice'>You take a bite of [src].</span>"
			if (fullness > 580)
				C << "<span class='danger'>You cannot force any more of [src] to go down your throat.</span>"
				return FALSE
		else //If you're feeding somebody
			if (!M.can_force_feed(user, src))
				return
			if (istype(M,/mob/living/human))
				var/mob/living/human/H = M
				if (H.gorillaman)
					if (non_vegetarian)
						user << "<span class='warning'>[H] is an herbivore! They can't eat this!</span>"
						return
				else if (H.wolfman || H.crab)
					if (!non_vegetarian)
						user << "<span class='warning'>[H] is a carnivore! They can't eat this!</span>"
						return
			if (fullness <= 580)
				user.visible_message("<span class='danger'>[user] attempts to feed [M] [src].</span>")
			else
				user.visible_message("<span class='danger'>[user] cannot force anymore of [src] down [M]'s throat.</span>")
				return FALSE
			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			if (!do_after(user, 30, M, check_for_repeats = FALSE))
				return FALSE
			M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been fed [name] by [user.name] ([user.ckey]) Reagents: [reagentlist(src)]</font>")
			user.attack_log += text("\[[time_stamp()]\] <font color='red'>Fed [name] by [M.name] ([M.ckey]) Reagents: [reagentlist(src)]</font>")
			msg_admin_attack("[key_name(user)] fed [key_name(M)] with [name] Reagents: [reagentlist(src)] (INTENT: [uppertext(user.a_intent)])")
			user.visible_message("<span class='danger'>[user] feeds [M] [src].</span>")
		//A spoon for mom, a spoon for dad. If we are here, then food is go to mouth to human type species, not others!
		playsound(M.loc,'sound/items/eatfood.ogg', rand(10,50), TRUE)
		if (reagents.total_volume > bitesize)
			reagents.trans_to_mob(M, bitesize, CHEM_INGEST)
		else
			reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
		bitecount++
		On_Consume(M)
		return TRUE
	return FALSE

/obj/item/weapon/reagent_containers/food/snacks/examine(mob/user)
	if (!..(user, TRUE))
		return
	if (bitecount==0)
		return
	else if (bitecount==1)
		user << "<span class='notice'>\The [src] was bitten by someone!</span>"
	else if (bitecount<=3)
		user << "<span class='notice'>\The [src] was bitten [bitecount] time\s!</span>"
	else
		user << "<span class='notice'>\The [src] was bitten multiple times!</span>"

/obj/item/weapon/reagent_containers/food/snacks/proc/is_sliceable()
	if (slice_path)
		if (slices_num > 0)
			return TRUE
	return FALSE

/obj/item/weapon/reagent_containers/food/snacks/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/storage) && user.a_intent != I_HARM)
		..() // -> item/attackby()
		return
	//cutting sliceable items with blades
	if (W.edge)
		if (!is_sliceable())
			..()
			return
		if (istype(W, /obj/item/weapon/reagent_containers/food/drinks))
			..()
			return
		if (istype(W, /obj/item/weapon/reagent_containers/glass))
			..()
			return
		var/slices_lost = 0
		if (W.w_class > 3) //big weapons may damage dishes
			user.visible_message("<span class='notice'>\The [user] crudely slices \the [src] with [W]!</span>", "<span class='notice'>You crudely slice \the [src] with your [W]!</span>")
			slices_lost = rand(1,min(1,round(slices_num/2)))
		else
			user.visible_message("<span class='notice'>\The [user] slices \the [src]!</span>", "<span class='notice'>You slice \the [src]!</span>")
		var/reagents_per_slice = reagents.total_volume/slices_num
		for (var/i=1 to (slices_num - slices_lost))
			var/obj/item/weapon/reagent_containers/food/snacks/slice = new slice_path(loc)
			reagents.trans_to_obj(slice, reagents_per_slice)
			slice.satisfaction = src.satisfaction / slices_num
		qdel(src)
		return
	// Eating with forks, spoons, chopsticks (utensil, but not knives, that have edge and worked above)
	if (istype(W,/obj/item/weapon/material/kitchen/utensil))
		var/obj/item/weapon/material/kitchen/utensil/U = W
		if (U.scoop_food)
			if (!U.reagents)
				U.create_reagents(5)
			if (U.reagents.total_volume > 0)
				user << "<span class='warning'>You already have something on your [U].</span>"
				return
			user.visible_message( \
				"\The [user] scoops up some [src] with \the [U]!", \
				"<span class='notice'>You scoop up some [src] with \the [U]!</span>" \
			)
			bitecount++
			U.overlays.Cut()
			U.loaded = "[src]"
			var/image/I = new(U.icon, "loadedfood")
			I.color = filling_color
			U.overlays += I
			reagents.trans_to_obj(U, min(reagents.total_volume,5))
			if (reagents.total_volume <= 0)
				qdel(src)
			return

/obj/item/weapon/reagent_containers/food/snacks/attack_generic(var/mob/living/M) //Eating food by mobs on "their own"
	if (!isanimal(M))
		return
	M.visible_message("<b>[M]</b> nibbles away at \the [src].")
	bitecount++
	if (reagents && M.reagents)
		reagents.trans_to_mob(M, bitesize, CHEM_INGEST)
	On_Consume(M)
	spawn(5)
		if (!src && !M.client)
			M.custom_emote(1,"[pick("burps", "cries for more", "burps twice", "looks at the area where the food was")]")


/obj/item/weapon/reagent_containers/food/snacks/Destroy()
	if (contents)
		for (var/atom/movable/something in contents)
			something.loc = get_turf(src)
	..()

//////////////////////////////////////////////////
////////////////////////////////////////////Snacks
//////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/hardtack
	name = "hardtack"
	desc = "Looks like it has been in a ship's hull for years."
	icon_state = "hardtack1"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 2
	nutriment_desc = list("biscuits" = 1, "jaw tension" = 2)
	decay = 0
	satisfaction = 1
	biteamount = 4
	New()
		..()
		icon_state = "hardtack[rand(1,2)]"

/obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknale
	name = "hardtack soaked in ale"
	desc = "Looks like it has been in a ship's hull for years. You soaked some ale into it before the battle started, good thinking!"
	nutriment_desc = list("biscuits" = 1)
	biteamount = 2
	New()
		..()
		reagents.add_reagent("ale", 2)

/obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknwine
	name = "hardtack soaked in wine"
	desc = "Looks like it has been in a ship's hull for years. You soaked some ale into it before the battle started, good thinking!"
	nutriment_desc = list("biscuits" = 1,)
	biteamount = 2
	New()
		..()
		reagents.add_reagent("wine", 2)

/obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknbeer
	name = "hardtack soaked in beer"
	desc = "Looks like it has been in a ship's hull for years. You soaked some ale into it before the battle started, good thinking!"
	nutriment_desc = list("biscuits" = 1,)
	biteamount = 2
	New()
		..()
		reagents.add_reagent("beer", 2)

/obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknopium
	name = "hardtack with an opium smear"
	desc = "Looks like it has been in a ship's hull for years. You smeared opium onto it before the battle started, good thinking!"
	nutriment_desc = list("biscuits" = 1,)
	biteamount = 2
	New()
		..()
		reagents.add_reagent("opium", 0.5)

/obj/item/weapon/reagent_containers/food/snacks/hardtack/hardtacknkhat
	name = "hardtack with an opium smear"
	desc = "Looks like it has been in a ship's hull for years. You smeared khat leaves onto it before the battle started, good thinking!"
	nutriment_desc = list("biscuits" = 1,)
	biteamount = 2
	New()
		..()
		reagents.add_reagent("cocaine", 0.5)

/obj/item/weapon/reagent_containers/food/snacks/driedmeat
	name = "dried meat"
	desc = "Dried meat. Probably pork. Or mice."
	icon_state = "driedmeat"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 3
	nutriment_desc = list("meat" = 1, "jaw tension" = 2)
	non_vegetarian = TRUE
	satisfaction = 2
	biteamount = 3
	decay = 250*600

/obj/item/weapon/reagent_containers/food/snacks/driedfish
	name = "dried fish"
	desc = "Some kind of sun dried fish."
	icon_state = "driedfish"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 3
	nutriment_desc = list("fish" = 1, "jaw tension" = 2)
	non_vegetarian = TRUE
	satisfaction = 2
	biteamount = 3
	decay = 180*600

/obj/item/weapon/reagent_containers/food/snacks/driedsalmon
	name = "dried salmon"
	desc = "A dried salmon fillet."
	icon_state = "driedsalmon"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 3
	nutriment_desc = list("salmon" = 1, "jaw tension" = 2)
	satisfaction = 2
	biteamount = 3
	decay = 200*600

/obj/item/weapon/reagent_containers/food/snacks/pickle
	name = "pickle"
	desc = "A pickle. That's it."
	icon_state = "pickle"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 1
	nutriment_desc = list("vinegar" = 5)
	satisfaction = 4
	biteamount = 1
	decay = 250*600

/obj/item/weapon/reagent_containers/food/snacks/pickle/big
	name = "big pickle"
	desc = "Oh boy, that's a big pickle!"
	icon_state = "pickleb"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 5
	nutriment_desc = list("vinegar" = 5)
	satisfaction = 4
	decay = 250*600

/obj/item/weapon/reagent_containers/food/snacks/cookie
	name = "cookie"
	desc = "COOKIE!!!"
	icon_state = "COOKIE!!!"
	center_of_mass = list("x"=17, "y"=18)
	filling_color = "#DBC94F"
	nutriment_amt = 6
	nutriment_desc = list("sweetness" = 3, "cookie" = 2, "nutriment" = 2, "sugar" = 2, "cocoa" = 2)
	decay = 45*600
	biteamount = 5

/obj/item/weapon/reagent_containers/food/snacks/chocolatebar
	name = "Chocolate bar"
	desc = "Such sweet, fattening food. You feel so empowered after tasting it!"
	icon_state = "chocolatebar"
	filling_color = "#7D5F46"
	nutriment_amt = 4
	bitesize = 4
	nutriment_desc = list("nutriment" = 2, "sugar" = 2, "cocoa" = 2)

/obj/item/weapon/reagent_containers/food/snacks/chocolatebar/pervitin
	name = "Panzerschokolade bar"
	desc = "Such sweet, fattening food. You feel so empowered after tasting it!"

	bitesize = 2
	nutriment_desc = list("nutriment" = 2, "sugar" = 2, "cocoa" = 2)
	New()
		..()
		reagents.add_reagent("pervitin", 1)

/obj/item/weapon/reagent_containers/food/snacks/egg
	name = "egg"
	desc = "An egg!"
	icon_state = "egg"
	filling_color = "#FDFFD1"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_amt = 2
	nutriment_desc = list("egg" = 2)
	satisfaction = 4
	non_vegetarian = TRUE
	decay = 90*600
	var/amount_grown = 0
	var/growing = FALSE

/obj/item/weapon/reagent_containers/food/snacks/egg/afterattack(obj/O as obj, mob/user as mob, proximity)
/*	if (istype(O,/obj/structure/microwave))
		return ..()*/
	if (istype(O, /obj/structure/pot))
		return
	if (!(proximity && O.is_open_container()))
		return
	user << "You crack \the [src] into \the [O]."
	reagents.trans_to(O, reagents.total_volume)
	user.drop_from_inventory(src)
	qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/egg/throw_impact(atom/hit_atom)
	..()
	new/obj/effect/decal/cleanable/egg_smudge(loc)
	if (reagents)
		reagents.splash(hit_atom, reagents.total_volume)
	visible_message("<span class='warning'>\The [src] has been squashed!</span>","<span class='warning'>You hear a smack.</span>")
	qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/turkeyegg //TO DO: move to /egg patch
	name = "turkey egg"
	desc = "An egg!"
	icon_state = "egg_turkey"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_amt = 2
	nutriment_desc = list("egg" = 2)
	satisfaction = 2
	non_vegetarian = TRUE
	decay = 90*600
	var/amount_grown = 0
	var/growing = FALSE

/obj/item/weapon/reagent_containers/food/snacks/turkeyegg/afterattack(obj/O as obj, mob/user as mob, proximity)
	if (istype(O, /obj/structure/pot))
		return
	if (!(proximity && O.is_open_container()))
		return
	user << "You crack \the [src] into \the [O]."
	reagents.trans_to(O, reagents.total_volume)
	user.drop_from_inventory(src)
	qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/turkeyegg/throw_impact(atom/hit_atom)
	..()
	new/obj/effect/decal/cleanable/egg_smudge(loc)
	reagents.splash(hit_atom, reagents.total_volume)
	visible_message("<span class='warning'>\The [src] has been squashed!</span>","<span class='warning'>You hear a smack.</span>")
	qdel(src)


/obj/item/weapon/reagent_containers/food/snacks/friedegg
	name = "fried egg"
	desc = "A fried egg, with a touch of salt and pepper."
	icon_state = "friedegg"
	filling_color = "#FFDF78"
	center_of_mass = list("x"=16, "y"=14)
	nutriment_amt = 2
	nutriment_desc = list("fried egg white and egg yolk" = 4)
	satisfaction = 8
	non_vegetarian = TRUE
	decay = 12*600
	New()
		..()
		reagents.add_reagent("sodiumchloride", 1)
		reagents.add_reagent("blackpepper", 1)

/obj/item/weapon/reagent_containers/food/snacks/boiledegg
	name = "boiled egg"
	desc = "A hard boiled egg."
	icon_state = "egg"
	filling_color = "#FFFFFF"
	nutriment_amt = 2
	nutriment_desc = list("egg" = 2)
	satisfaction = 5
	non_vegetarian = TRUE
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/organ
	name = "organ"
	desc = "It's good for you."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "appendix"
	filling_color = "#E00D34"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_amt = 0 //all below in protein
	raw = TRUE
	non_vegetarian = TRUE
	satisfaction = -10
	decay = 7*600
	New()
		..()
		reagents.add_reagent("protein", rand(3,5))

/obj/item/weapon/reagent_containers/food/snacks/tofu
	name = "tofu"
	icon_state = "tofu"
	desc = "We all love tofu."
	filling_color = "#FFFEE0"
	center_of_mass = list("x"=17, "y"=10)
	nutriment_amt = 3
	nutriment_desc = list("tofu" = 3, "goeyness" = 3)
	satisfaction = 2
	decay = 25*600

/obj/item/weapon/reagent_containers/food/snacks/fishfillet
	name = "fish fillet"
	desc = "A fillet of fish."
	icon_state = "fishfillet"
	filling_color = "#FFDEFE"
	center_of_mass = list("x"=17, "y"=13)
	rotten_icon_state = "rottenfillet"
	rots = TRUE
	non_vegetarian = TRUE
	satisfaction = 6
	decay = 12*600
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/driedfish
	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("food_poisoning", pick(0,0,0,0,0,0,0,1,1,2)) //most fish may be eat fresh, ask the japanese about it

/obj/item/weapon/reagent_containers/food/snacks/pink_squid
	name = "squid"
	desc = "A living squid."
	icon_state = "pink_squid"
	center_of_mass = list("x"=17, "y"=13)
	rotten_icon_state = "pink_squid_rotten"
	nutriment_amt = 3
	nutriment_desc = list("slippery" = 2, "seafood" = 2)
	rots = TRUE
	rotten_icon_state = "rotten_squid"
	non_vegetarian = TRUE
	decay = 12*600
	satisfaction = 10
	dry_size = 13
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/pink_squid/dried
	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("food_poisoning", pick(0,0,0,0,0,0,0,1,1,2))

/obj/item/weapon/reagent_containers/food/snacks/pink_squid/dried
	name = "dried squid"
	desc = "A sun dried squid rings. Snack for beer."
	icon = 'icons/obj/food/dryed.dmi'
	icon_state = "squid_rings"
	center_of_mass = list("x"=16, "y"=16)
	non_vegetarian = TRUE
	satisfaction = 12
	biteamount = 4
	decay = 200*600
	rots = FALSE
	raw = FALSE
	dried_type = null
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("nutriment", 3, list("seafood"=2))

/obj/item/weapon/reagent_containers/food/snacks/salmonfillet
	name = "salmon fillet"
	desc = "A fillet of salmon."
	icon_state = "salmonfillet"
	rotten_icon_state = "rottensalmonfillet"
	rots = TRUE
	center_of_mass = list("x"=17, "y"=13)
	decay = 12*600
	satisfaction = 6
	non_vegetarian = TRUE
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/driedsalmon
	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("food_poisoning", pick(0,0,0,0,0,0,0,0,0,1)) //only 10%


/obj/item/weapon/reagent_containers/food/snacks/fishfingers
	name = "Fish fingers"
	desc = "A finger of fish."
	icon_state = "fishfingers"
	filling_color = "#FFDEFE"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_amt = 4
	nutriment_desc = list("seafood" = 1)
	decay = 12*600
	satisfaction = 6
	non_vegetarian = TRUE

/obj/item/weapon/reagent_containers/food/snacks/fishfingers/chickenbucket
	name = "Fried Chicken Bucket"
	desc = "A Fried Chicken Bucket."
	icon_state = "chickenbucket"
	filling_color = "#FFDEFE"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_amt = 4
	nutriment_desc = list("chicken" = 1)
	decay = 12*600
	satisfaction = 6
	non_vegetarian = TRUE

/obj/item/weapon/reagent_containers/food/snacks/bearmeat
	name = "bear meat"
	desc = "A very manly slab of meat."
	icon_state = "bearmeat"
	filling_color = "#DB0000"
	center_of_mass = list("x"=16, "y"=10)
	raw = TRUE
	non_vegetarian = TRUE
	decay = 10*600
	satisfaction = 4
	nutriment_amt = 0
	New()
		..()
		reagents.add_reagent("protein", 12)
		reagents.add_reagent("hyperzine", 5)

/obj/item/weapon/reagent_containers/food/snacks/bearmeat/attackby(obj/item/weapon/W as obj, mob/user as mob) //TODO: REPAIR IT to slicing mechanic!
	if (!roasted && istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		var/atom/A = new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		A.name = "bear meat cutlet"
		A.desc = replacetext(desc, "slab", "cutlet")
		A = new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		A.name = "bear meat cutlet"
		A.desc = replacetext(desc, "slab", "cutlet")
		A = new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		A.name = "bear meat cutlet"
		A.desc = replacetext(desc, "slab", "cutlet")
		user << "You cut the meat into thin strips."
		qdel(src)
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/sausage
	name = "sausage"
	desc = "A piece of mixed, long meat."
	icon_state = "sausage"
	filling_color = "#DB0000"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_amt = 1
	nutriment_desc = list("smoked" = 1)
	decay = 45*600
	satisfaction = 8
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 6)

/obj/item/weapon/reagent_containers/food/snacks/omelette
	name = "Omelette Du Fromage"
	desc = "That's all you can say!"
	icon_state = "omelette"
	center_of_mass = list("x"=16, "y"=13)
	filling_color = "#FFF9A8"
	nutriment_amt = 6
	nutriment_desc = list("fried eggs" = 4, "creamy" = 1)
	satisfaction = 8
	non_vegetarian = TRUE
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/muffin
	name = "muffin"
	desc = "A delicious and spongy little cake"
	icon_state = "muffin"
	filling_color = "#E0CF9B"
	center_of_mass = list("x"=17, "y"=4)
	nutriment_desc = list("sweetness" = 1, "muffin" = 1)
	nutriment_amt = 6
	decay = 25*600

/obj/item/weapon/reagent_containers/food/snacks/waffles
	name = "waffles"
	desc = "Mmm, waffles"
	icon_state = "waffles"
	filling_color = "#E6DEB5"
	center_of_mass = list("x"=15, "y"=11)
	nutriment_amt = 6
	nutriment_desc = list("waffle" = 1)
	decay = 18*600

/obj/item/weapon/reagent_containers/food/snacks/meatpie
	name = "Meat-pie"
	desc = "An old barber recipe, very delicious!"
	icon_state = "meatpie"
	filling_color = "#948051"
	center_of_mass = list("x"=16, "y"=13)
	decay = 20*600
	nutriment_amt = 0 //all are below
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 10)

/obj/item/weapon/reagent_containers/food/snacks/tofupie
	name = "tofu-pie"
	icon_state = "plaincake"
	desc = "A delicious tofu pie."
	filling_color = "#FFFEE0"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("tofu" = 2, "pie" = 8)
	nutriment_amt = 10
	decay = 25*600

/obj/item/weapon/reagent_containers/food/snacks/loadedbakedpotato
	name = "loaded baked potato"
	desc = "Totally baked."
	icon_state = "loadedbakedpotato"
	filling_color = "#9C7A68"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("baked potato" = 3)
	nutriment_amt = 6
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/fries
	name = "fries"
	desc = "AKA: French Fries, Freedom Fries, etc."
	icon_state = "fries"
	filling_color = "#EDDD00"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("fresh fries" = 4)
	nutriment_amt = 4
	decay = 15*600
	satisfaction = 8

/obj/item/weapon/reagent_containers/food/snacks/rice
	name = "rice"
	desc = "A pile of raw rice grains."
	icon_state = "ricepile"
	filling_color = "#dcdcdc"
	nutriment_desc = list("rice" = TRUE)
	nutriment_amt = 2
	satisfaction = 3
	decay = 100*600

/obj/item/weapon/reagent_containers/food/snacks/spaghetti
	name = "spaghetti"
	desc = "A bundle of raw spaghetti."
	icon_state = "spaghetti"
	filling_color = "#EDDD00"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_desc = list("noodles" = 2)
	nutriment_amt = 1
	decay = 60*600
	satisfaction = 3

/obj/item/weapon/reagent_containers/food/snacks/spaghetti/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W.sharp || W.edge)
		user << "You make some noodles from the long spaghetti."
		for (var/v in 1 to pick(1,2))
			new /obj/item/weapon/reagent_containers/food/snacks/noodles(get_turf(src))
		qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/noodles
	name = "noodles"
	desc = "A bundle of raw noodles."
	icon_state = "noodles"
	filling_color = "#EDDD00"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_desc = list("noodles" = 2)
	nutriment_amt = 1
	decay = 60*600
	satisfaction = 3

/obj/item/weapon/reagent_containers/food/snacks/badrecipe
	name = "burned mess"
	desc = "Someone should be demoted from chef for this."
	icon_state = "badrecipe"
	filling_color = "#211F02"
	center_of_mass = list("x"=16, "y"=12)
	decay = 18*600
	satisfaction = -8
	disgusting = TRUE
	nutriment_amt = 0
	value = 0
	New()
		..()
		reagents.add_reagent("toxin", 1)
		reagents.add_reagent("carbon", 3)

/obj/item/weapon/reagent_containers/food/snacks/meatsteak
	name = "meat steak"
	desc = "A piece of hot spicy meat."
	icon_state = "meatstake"
	filling_color = "#7A3D11"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_amt = 0 //all below
	non_vegetarian = TRUE
	decay = 15*600
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("sodiumchloride", 1)
		reagents.add_reagent("blackpepper", 1)

/obj/item/weapon/reagent_containers/food/snacks/poppypretzel
	name = "poppy pretzel"
	desc = "It's all twisted up!"
	icon_state = "poppypretzel"
	filling_color = "#916E36"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("poppy seeds" = 2, "pretzel" = 3)
	nutriment_amt = 5
	decay = 35*600

/obj/item/weapon/reagent_containers/food/snacks/meatballsoup
	name = "meatball soup"
	desc = "You've got balls kid, BALLS!"
	icon_state = "meatballsoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#785210"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_amt = 0 //all below
	decay = 16*600
	New()
		..()
		reagents.add_reagent("protein", 8)
		reagents.add_reagent("water", 16)

/obj/item/weapon/reagent_containers/food/snacks/vegetablesoup
	name = "vegetable soup"
	desc = "A true vegan meal" //TODO
	icon_state = "vegetablesoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#AFC4B5"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_amt = 8
	nutriment_desc = list("carot" = 2, "corn" = 2, "cabbage" = 2, "potato" = 2)
	decay = 20*600
	New()
		..()
		reagents.add_reagent("water", 16)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/baguette
	name = "baguette"
	icon_state = "Bon Appetit!"
	icon_state = "baguette"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/breadslice
	slices_num = 5
	filling_color = "#FFE396"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("stale frenchness" = 1)
	nutriment_amt = 6
	decay = 22*600
	satisfaction = 4

/obj/item/weapon/reagent_containers/food/snacks/sandwich
	name = "sandwich"
	desc = "A grand creation of meat, cheese, bread, and several leaves of lettuce! Arthur Dent would be proud."
	icon_state = "sandwich"
	filling_color = "#D9BE29"
	center_of_mass = list("x"=16, "y"=4)
	nutriment_desc = list("bread" = 3, "cheese" = 3)
	satisfaction = 8
	nutriment_amt = 3
	decay = 18*600
	New()
		..()
		reagents.add_reagent("protein", 3)

/obj/item/weapon/reagent_containers/food/snacks/toastedsandwich
	name = "toasted sandwich"
	desc = "Now if you only had a pepper bar."
	icon_state = "toastedsandwich"
	filling_color = "#D9BE29"
	center_of_mass = list("x"=16, "y"=4)
	nutriment_desc = list("toasted bread" = 3, "cheese" = 3)
	satisfaction = 8
	nutriment_amt = 3
	decay = 18*600
	value = 0
	New()
		..()
		reagents.add_reagent("protein", 3)
		reagents.add_reagent("carbon", 2)

/obj/item/weapon/reagent_containers/food/snacks/grilledcheese
	name = "grilled cheese sandwich"
	desc = "Goes great with Tomato soup!"
	icon_state = "toastedsandwich"
	filling_color = "#D9BE29"
	nutriment_desc = list("toasted bread" = 3, "cheese" = 3)
	satisfaction = 8
	nutriment_amt = 3
	decay = 15*600
	New()
		..()
		reagents.add_reagent("protein", 4)

/obj/item/weapon/reagent_containers/food/snacks/tomatosoup
	name = "tomato soup"
	desc = "Drinking this feels like being a vampire! A tomato vampire..."
	icon_state = "tomatosoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#D92929"
	center_of_mass = list("x"=16, "y"=7)
	nutriment_desc = list("soup" = 2)
	nutriment_amt = 6
	satisfaction = 4
	decay = 15*600
	New()
		..()
		reagents.add_reagent("tomatojuice", 18)

/obj/item/weapon/reagent_containers/food/snacks/stew
	name = "stew"
	desc = "A nice and warm stew. Healthy and strong."
	icon_state = "stew"
	filling_color = "#9E673A"
	center_of_mass = list("x"=16, "y"=5)
	trash = /obj/item/kitchen/snack_bowl
	nutriment_amt = 10
	nutriment_desc = list("tomato" = 2, "potato" = 2, "carrot" = 2, "meat" = 2, "mushroom" = 2)
	satisfaction = 4
	decay = 16*600
	New()
		..()
		reagents.add_reagent("water", 14)

/obj/item/weapon/reagent_containers/food/snacks/stew_wood
	name = "stew"
	desc = "A nice and warm stew. Healthy and strong."
	icon_state = "stew_wood"
	filling_color = "#9E673A"
	center_of_mass = list("x"=16, "y"=5)
	trash = /obj/item/kitchen/wood_bowl
	nutriment_amt = 10
	nutriment_desc = list("tomato" = 2, "potato" = 2, "carrot" = 2, "meat" = 2, "mushroom" = 2)
	satisfaction = 4
	decay = 16*600
	New()
		..()
		reagents.add_reagent("water", 14)

/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast
	name = "Jellied toast"
	desc = "A slice of bread covered with delicious jam."
	icon_state = "jellytoast"
	filling_color = "#B572AB"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_desc = list("toasted bread" = 2, "jam" = 2)
	nutriment_amt = 2
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast/cherry
	New()
		..()
		filling_color = "#af2a52"
		nutriment_amt = 1
		nutriment_desc = list("toasted bread" = 2)
		reagents.add_reagent("cherryjelly", 1)

/obj/item/weapon/reagent_containers/food/snacks/boiledspagetti
	name = "boiled spaghetti"
	desc = "A plain dish of spaghetti, this sucks."
	icon_state = "spagettiboiled"
	filling_color = "#FCEE81"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("noodles" = 2)
	nutriment_amt = 2
	decay = 14*600
	satisfaction = 5

/obj/item/weapon/reagent_containers/food/snacks/boiledspagetti/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meatball))
		visible_message("<span class = 'notice'>[user] combines the spaghetti with the meatball to make spaghetti and meatballs.</span>")
		qdel(I)
		new/obj/item/weapon/reagent_containers/food/snacks/meatballspagetti(get_turf(src))
		qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/ramen
	name = "ramen"
	desc = "A combination of meat, noodles, and egg all in a savoury broth!"
	icon_state = "ramen"
	filling_color = "#DE4545"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("noodles" = 4, "meat" = 2, "egg" = 1)
	satisfaction = 9
	nutriment_amt = 6
	decay = 11*600
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("water", 30)

/obj/item/weapon/reagent_containers/food/snacks/boiledrice
	name = "boiled rice"
	desc = "A boring dish of boring rice."
	icon_state = "boiledrice"
	filling_color = "#FFFBDB"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("rice" = 2)
	nutriment_amt = 3
	decay = 12*600
	satisfaction = 5

/obj/item/weapon/reagent_containers/food/snacks/ricepudding
	name = "rice pudding"
	desc = "Where's the jam?"
	icon_state = "rpudding"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#FFFBDB"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("rice" = 2)
	nutriment_amt = 4
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/pastatomato
	name = "spaghetti"
	desc = "Spaghetti and crushed tomatoes. Just like your abusive father used to make!"
	icon_state = "pastatomato"
	filling_color = "#DE4545"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("tomato" = 3, "noodles" = 3)
	nutriment_amt = 6
	decay = 12*600
	New()
		..()
		reagents.add_reagent("tomatojuice", 10)

/obj/item/weapon/reagent_containers/food/snacks/meatballspagetti
	name = "spaghetti & meatballs"
	desc = "Now thats a nic'e meatball!"
	icon_state = "meatballspagetti"
	filling_color = "#DE4545"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("noodles" = 4)
	satisfaction = 10
	nutriment_amt = 4
	decay = 11*600
	New()
		..()
		reagents.add_reagent("protein", 4)

/obj/item/weapon/reagent_containers/food/snacks/applepie
	name = "apple pie"
	desc = "A pie containing sweet sweet love... or apple."
	icon_state = "applepie"
	filling_color = "#E0EDC5"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("sweetness" = 2, "apple" = 2, "pie" = 2)
	nutriment_amt = 4
	decay = 18*600

/obj/item/weapon/reagent_containers/food/snacks/cherrypie
	name = "cherry Pie"
	desc = "Taste so good, make a grown man cry."
	icon_state = "cherrypie"
	filling_color = "#FF525A"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("sweetness" = 2, "cherry" = 2, "pie" = 2)
	nutriment_amt = 4
	decay = 18*600

/obj/item/weapon/reagent_containers/food/snacks/sweetroll
	name = "sweet roll"
	desc = "A towering donut topped with icing."
	icon_state = "sweetroll"
	filling_color = "#FF525A"
	center_of_mass = list("x"=16, "y"=11)
	nutriment_desc = list("sweetness" = 2, "icing" = 2, "donut" = 2)
	nutriment_amt = 4
	decay = 18*600

/obj/item/weapon/reagent_containers/food/snacks/twobread
	name = "two bread"
	desc = "It is very bitter and winy."
	icon_state = "twobread"
	filling_color = "#DBCC9A"
	center_of_mass = list("x"=15, "y"=12)
	nutriment_desc = list("sourness" = 2, "bread" = 2)
	nutriment_amt = 2
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/jellysandwich
	name = "jelly sandwich"
	desc = "You wish you had some peanut butter to go with this..."
	icon_state = "jellysandwich"
	filling_color = "#9E3A78"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_desc = list("bread" = 2, "jelly" = 1)
	nutriment_amt = 2
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/jellysandwich/cherry
	decay = 12*600
	New()
		..()
		nutriment_amt = 1
		nutriment_desc = list("bread" = 2)
		reagents.add_reagent("cherryjelly", 1)

/obj/item/weapon/reagent_containers/food/snacks/mint
	name = "mint"
	desc = "it is only wafer thin."
	icon_state = "mint"
	filling_color = "#F2F2F2"
	center_of_mass = list("x"=16, "y"=14)
	decay = 20*600
	value = 3
	New()
		..()
		reagents.add_reagent("mint", 1)

/obj/item/weapon/reagent_containers/food/snacks/mushroomsoup
	name = "mushroom soup"
	desc = "A delicious and hearty mushroom soup."
	icon_state = "mushroomsoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#E386BF"
	center_of_mass = list("x"=17, "y"=10)
	nutriment_desc = list("mushroom" = 8, "milk" = 2)
	nutriment_amt = 8
	decay = 15*600
	New()
		..()
		reagents.add_reagent("water", 30)

/obj/item/weapon/reagent_containers/food/snacks/beetsoup
	name = "borshch"
	desc = "Delicious beet and tomato soup."
	icon_state = "beetsoup"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#FAC9FF"
	center_of_mass = list("x"=15, "y"=8)
	nutriment_desc = list("tomato" = 4, "beet" = 4)
	nutriment_amt = 8
	decay = 16*600
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("tomatojuice", 5)
		reagents.add_reagent("imidazoline", 5)
		reagents.add_reagent("water", 15)

/obj/item/weapon/reagent_containers/food/snacks/caldoverde
	name = "caldo verde"
	desc = "A typical Portuguese soup, made with cabbages and potatoes."
	icon_state = "caldoverde"
	trash = /obj/item/kitchen/wood_bowl
	filling_color = "#FAC9FF"
	center_of_mass = list("x"=15, "y"=8)
	nutriment_desc = list("cabbage" = 4, "potato" = 2, "olive oil" = 1)
	nutriment_amt = 4
	decay = 15*600
	satisfaction = 6
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("water", 15)

/obj/item/weapon/reagent_containers/food/snacks/gyro
	name = "gyro"
	desc = "Greek delicacy."
	icon_state = "gyro"
	satisfaction = 10
	nutriment_amt = 6
	nutriment_desc = list("lamb" = 4, "bread" = 2, "tzatziki" = 1)

/obj/item/weapon/reagent_containers/food/snacks/tossedsalad
	name = "tossed salad"
	desc = "A proper salad, basic and simple, with little bits of carrot, tomato and apple intermingled. Vegan!"
	icon_state = "herbsalad"
	trash = /obj/item/kitchen/snack_bowl
	filling_color = "#76B87F"
	center_of_mass = list("x"=17, "y"=11)
	nutriment_desc = list("salad" = 2, "tomato" = 2, "carrot" = 2, "apple" = 2)
	nutriment_amt = 8
	decay = 16*600

/obj/item/weapon/reagent_containers/food/snacks/appletart
	name = "golden apple streusel tart"
	desc = "A tasty dessert that won't make it through a metal detector."
	icon_state = "gappletart"
	filling_color = "#FFFF00"
	center_of_mass = list("x"=16, "y"=18)
	nutriment_desc = list("apple" = 8)
	nutriment_amt = 8
	decay = 16*600
	value = 50
	New()
		..()
		reagents.add_reagent("gold", 5)

/obj/item/weapon/reagent_containers/food/snacks/ssicle
	name = "Strawberry popsicle"
	desc = "A nice refreshing strawberry treat for those hot days."
	icon_state = "ssicle"
	filling_color = "#FFDEFE"
	satisfaction = 10
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 3, "popsicle" = 2)
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/ssicle/gsicle
	name = "Grape popsicle"
	desc = "A nice refreshing grape treat for those hot days."
	icon_state = "gsicle"
	filling_color = "#FFDEFE"
	satisfaction = 10
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 3, "popsicle" = 2)
	decay = 12*600

/obj/item/weapon/reagent_containers/food/snacks/ssicle/osicle
	name = "Orange popsicle"
	desc = "A nice refreshing orange treat for those hot days."
	icon_state = "osicle"
	filling_color = "#FFDEFE"
	satisfaction = 10
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 3, "popsicle" = 2)
	decay = 12*600

/////////////////////////////////////////////////Sliceable////////////////////////////////////////
// All the food items that can be sliced into smaller bits like Meatbread and Cheesewheels
// sliceable is just an organization type path, it doesn't have any additional code or variables tied to it.
/////////////////////////////////////////////////Sliceable////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/sliceable
	w_class = ITEM_SIZE_NORMAL //Whole pizzas and cakes shouldn't fit in a pocket, you can slice them if you want to do that.
	decay = 17*600

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza
	name = "pizza"
	desc = "A large flattened pie with toppings."
	icon_state = "pizza"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_amt = 8 //and 4 are below, total 12
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzaslice
	slices_num = 8
	nutriment_desc = list("baked pastry" = 4, "mushrooms" = 2, "cheese" = 2)
	decay = 15*600
	New()
		..()
		reagents.add_reagent("parsley", 2)
		reagents.add_reagent("tomato", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzaslice
	name = "pizza slice"
	desc = "A slice of delicious classic pizza."
	icon_state = "vegetablepizzaslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = TRUE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzapepperoni
	name = "pepperoni and cheese pizza"
	desc = "A large flattened pie with cheese and pepperoni."
	icon_state = "pizzapepperoni"
	nutriment_amt = 9 //and 3 are below, total 12
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzapepslice
	slices_num = 8
	nutriment_desc = list("baked pastry" = 4, "pepperoni" = 2, "spices" = 1, "cheese" = 2)
	non_vegetarian = TRUE
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 2)
		reagents.add_reagent("capsaicin", 1)

/obj/item/weapon/reagent_containers/food/snacks/pizzapepslice
	name = "pepperoni pizza slice"
	desc = "A slice of delicious pepperoni pizza."
	icon_state = "pizzapepperonislice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = TRUE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza
	name = "spicy vegetable pizza"
	desc = "A large flattened pie with vegetables."
	icon_state = "vegetablepizza"
	nutriment_amt = 8 //and 4 are below, total 12
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzavege
	slices_num = 8
	nutriment_desc = list("baked pastry" = 4, "paprika" = 1, "olives" = 1, "cheese" = 2)
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 2)
		reagents.add_reagent("celery", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzavege
	name = "spicy vegetarian pizza slice"
	desc = "A slice of delicious vege pizza."
	icon_state = "vegetablepizzaslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = FALSE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/meatpizza
	name = "meatball pizza"
	desc = "A large flattened pie with meat balls and tomato sauce."
	icon_state = "meatpizza"
	nutriment_amt = 6 //and 6 are below, total 12
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzameat
	slices_num = 8
	nutriment_desc = list("baked pastry" = 4, "cheese" = 2)
	non_vegetarian = TRUE
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("tomato", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzameat
	name = "meat pizza slice"
	desc = "A slice of delicious meat pizza."
	icon_state = "meatpizzaslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = TRUE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzasauced
	name = "plain pizza"
	desc = "A large flattened pie with tomato sauce."
	icon_state = "pizzasauced"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/saucedsliced
	slices_num = 8
	nutriment_amt = 4 //and 8 are below, total 12
	nutriment_desc = list("baked pastry" = 4)
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 8)

/obj/item/weapon/reagent_containers/food/snacks/saucedsliced
	name = "sauced pizza slice"
	desc = "A slice of delicious sauced pizza."
	icon_state = "pizzasaucedslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = FALSE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzacheesed
	name = "cheese pizza"
	desc = "A large flattened pie with cheese and tomato sauce."
	icon_state = "pizzacheesed"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzacheesesliced
	slices_num = 8
	nutriment_amt = 10 //and 2 are below, total 12
	nutriment_desc = list("baked pastry" = 4, "spices" = 1, "cheese" = 5)
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzacheesesliced
	name = "cheese pizza slice"
	desc = "A slice of delicious cheese pizza."
	icon_state = "pizzacheesedslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = FALSE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzahawaiian
	name = "hawaiian pizza"
	desc = "A large flattened pie with cheese, ham and pineapple"
	icon_state = "hawaiianpizza"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzahawaiiansliced
	slices_num = 8
	nutriment_amt = 12 //and 2 are below, total 12
	nutriment_desc = list("baked pastry" = 4, "spices" = 1, "cheese" = 5)
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzahawaiiansliced
	name = "cheese pizza slice"
	desc = "A slice of delicious hawaiian styled pizza."
	icon_state = "hawaiianpizzaslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = FALSE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzamac
	name = "mac n cheese pizza"
	desc = "A large flattened pie with cheese and macaroni noodles"
	icon_state = "macpizza"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzamacsliced
	slices_num = 8
	nutriment_amt = 12 //and 2 are below, total 12
	nutriment_desc = list("baked pastry" = 4, "cheese" = 8)
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzamacsliced
	name = "mac n cheese pizza slice"
	desc = "A slice of delicious mac n cheese pizza."
	icon_state = "macpizzaslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = FALSE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzamushroom
	name = "mushroom pizza"
	desc = "A large flattened pie with mushrooms and sauce."
	icon_state = "mushroompizza"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pizzamushsliced
	slices_num = 8
	nutriment_amt = 12 //and 2 are below, total 12
	nutriment_desc = list("baked pastry" = 4, "mushroom" = 8)
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("tomato", 2)

/obj/item/weapon/reagent_containers/food/snacks/pizzamushsliced
	name = "mushroom pizza slice"
	desc = "A slice of delicious mushroom pizza."
	icon_state = "mushroompizzaslice"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = FALSE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/meatbread
	name = "meatbread loaf"
	desc = "The culinary base of every self-respecting eloquen/tg/entleman."
	icon_state = "meatbread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/meatbreadslice
	slices_num = 5
	filling_color = "#FF7575"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	non_vegetarian = TRUE
	decay = 17*600
	New()
		..()
		reagents.add_reagent("protein", 20)

/obj/item/weapon/reagent_containers/food/snacks/meatbreadslice
	name = "meatbread slice"
	desc = "A slice of delicious meatbread."
	icon_state = "meatbreadslice"
	filling_color = "#FF7575"
	center_of_mass = list("x"=16, "y"=13)
	decay = 17*600
	non_vegetarian = TRUE

/obj/item/weapon/reagent_containers/food/snacks/sliceable/bananabread
	name = "banana-nut bread"
	desc = "A heavenly and filling treat."
	icon_state = "bananabread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/bananabreadslice
	slices_num = 5
	filling_color = "#EDE5AD"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	decay = 17*600
	New()
		..()
		reagents.add_reagent("banana", 20)

/obj/item/weapon/reagent_containers/food/snacks/bananabreadslice
	name = "banana-nut bread slice"
	desc = "A slice of delicious banana bread."
	icon_state = "bananabreadslice"
	filling_color = "#EDE5AD"
	center_of_mass = list("x"=16, "y"=8)
	decay = 17*600

/obj/item/weapon/reagent_containers/food/snacks/sliceable/carrotcake
	name = "carrot cake"
	desc = "A favorite desert of a certain wascally wabbit. Not a lie."
	icon_state = "carrotcake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/carrotcakeslice
	slices_num = 5
	filling_color = "#FFD675"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "carrot" = 15)
	nutriment_amt = 25
	decay = 17*600
	New()
		..()
		reagents.add_reagent("imidazoline", 10)

/obj/item/weapon/reagent_containers/food/snacks/carrotcakeslice
	name = "carrot cake slice"
	desc = "Carrotty slice of carrot cake, carrots are good for your eyes! Also not a lie."
	icon_state = "carrotcake_slice"
	filling_color = "#FFD675"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesecake
	name = "cheese cake"
	desc = "DANGEROUSLY cheesy."
	icon_state = "cheesecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice
	slices_num = 5
	filling_color = "#FAF7AF"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "cream" = 10, "cheese" = 15)
	nutriment_amt = 10
	New()
		..()
		reagents.add_reagent("protein", 15)

/obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice
	name = "cheese cake slice"
	desc = "Slice of pure cheestisfaction"
	icon_state = "cheesecake_slice"
	filling_color = "#FAF7AF"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/plaincake
	name = "vanilla cake"
	desc = "A plain cake, not a lie."
	icon_state = "plaincake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/plaincakeslice
	slices_num = 5
	filling_color = "#F7EDD5"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "vanilla" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/plaincakeslice
	name = "vanilla cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "plaincake_slice"
	filling_color = "#F7EDD5"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/orangecake
	name = "orange cake"
	desc = "A cake with added orange."
	icon_state = "orangecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/orangecakeslice
	slices_num = 5
	filling_color = "#FADA8E"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "orange" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/orangecakeslice
	name = "orange cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "orangecake_slice"
	filling_color = "#FADA8E"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/limecake
	name = "lime cake"
	desc = "A cake with added lime."
	icon_state = "limecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/limecakeslice
	slices_num = 5
	filling_color = "#CBFA8E"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "lime" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/limecakeslice
	name = "lime cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "limecake_slice"
	filling_color = "#CBFA8E"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/lemoncake
	name = "lemon cake"
	desc = "A cake with added lemon."
	icon_state = "lemoncake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/lemoncakeslice
	slices_num = 5
	filling_color = "#FAFA8E"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "lemon" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/lemoncakeslice
	name = "lemon cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "lemoncake_slice"
	filling_color = "#FAFA8E"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/chocolatecake
	name = "chocolate cake"
	desc = "A cake with added chocolate"
	icon_state = "chocolatecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice
	slices_num = 5
	filling_color = "#805930"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "chocolate" = 15)
	nutriment_amt = 20

/obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice
	name = "chocolate cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "chocolatecake_slice"
	filling_color = "#805930"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel
	name = "cheese wheel"
	desc = "A big wheel of delcious Cheddar."
	icon_state = "cheesewheel"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/cheesewedge
	slices_num = 5
	filling_color = "#FFF700"
	non_vegetarian = TRUE
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cheese" = 10)
	nutriment_amt = 10
	decay = 70*600
	satisfaction = 4
	value = 40
	New()
		..()
		reagents.add_reagent("protein", 10)

/obj/item/weapon/reagent_containers/food/snacks/cheesewedge
	name = "cheese wedge"
	desc = "A wedge of delicious Cheddar. The cheese wheel it was cut from can't have gone far."
	icon_state = "cheesewedge"
	filling_color = "#FFF700"
	center_of_mass = list("x"=16, "y"=10)
	decay = 50*600
	satisfaction = 3

/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread
	name = "bread"
	icon_state = "Some plain old bread."
	icon_state = "bread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/breadslice
	slices_num = 5
	filling_color = "#FFE396"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 6)
	nutriment_amt = 6
	decay = 22*600
	satisfaction = 4

/obj/item/weapon/reagent_containers/food/snacks/breadslice
	name = "bread slice"
	desc = "A slice of home."
	icon_state = "breadslice"
	filling_color = "#D27332"
	center_of_mass = list("x"=16, "y"=4)
	decay = 17*600
	satisfaction = 2

/obj/item/weapon/reagent_containers/food/snacks/sliceable/creamcheesebread
	name = "cream Cheese Bread"
	desc = "Yum yum yum!"
	icon_state = "creamcheesebread"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/creamcheesebreadslice
	slices_num = 5
	filling_color = "#FFF896"
	center_of_mass = list("x"=16, "y"=9)
	nutriment_desc = list("bread" = 6, "cream" = 3, "cheese" = 3)
	nutriment_amt = 5
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 15)

/obj/item/weapon/reagent_containers/food/snacks/creamcheesebreadslice
	name = "cream Cheese Bread slice"
	desc = "A slice of yum!"
	icon_state = "creamcheesebreadslice"
	filling_color = "#FFF896"
	center_of_mass = list("x"=16, "y"=13)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/applecake
	name = "apple cake"
	desc = "A cake centred with Apple"
	icon_state = "applecake"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/applecakeslice
	slices_num = 5
	filling_color = "#EBF5B8"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "apple" = 15)
	nutriment_amt = 15

/obj/item/weapon/reagent_containers/food/snacks/applecakeslice
	name = "apple cake slice"
	desc = "A slice of heavenly cake."
	icon_state = "applecakeslice"
	filling_color = "#EBF5B8"
	center_of_mass = list("x"=16, "y"=14)

/obj/item/weapon/reagent_containers/food/snacks/sliceable/pumpkinpie
	name = "pumpkin pie"
	desc = "A delicious treat for the autumn months."
	icon_state = "pumpkinpie"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pumpkinpieslice
	slices_num = 5
	filling_color = "#F5B951"
	center_of_mass = list("x"=16, "y"=10)
	nutriment_desc = list("pie" = 5, "cream" = 5, "pumpkin" = 5)
	nutriment_amt = 15

/obj/item/weapon/reagent_containers/food/snacks/pumpkinpieslice
	name = "pumpkin pie slice"
	desc = "A slice of pumpkin pie, with whipped cream on top. Perfection."
	icon_state = "pumpkinpieslice"
	filling_color = "#F5B951"
	center_of_mass = list("x"=16, "y"=12)

/obj/item/weapon/reagent_containers/food/snacks/cracker
	name = "cracker"
	desc = "It's a salted cracker."
	icon_state = "cracker"
	filling_color = "#F5DEB8"
	center_of_mass = list("x"=17, "y"=6)
	nutriment_desc = list("salt" = 1, "cracker" = 2)
	nutriment_amt = 1
	decay = 80*600

///////////////////////////////////////////
// new old food stuff from bs12
///////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/dough
	name = "dough"
	desc = "A piece of dough."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "dough"
	center_of_mass = list("x"=16, "y"=13)
	nutriment_desc = list("dough" = 3)
	nutriment_amt = 3
	decay = 25*600
	satisfaction = -4
	New()
		..()
		reagents.add_reagent("protein", 1)

// Dough + rolling pin = flat dough
/obj/item/weapon/reagent_containers/food/snacks/dough/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/material/kitchen/rollingpin))
		new /obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough(get_turf(src))
		user << "You flatten the dough."
		qdel(src)
	else if (W.sharp || W.edge)
		user << "You make some spaghetti from the dough."
		for (var/v in 1 to pick(2,3))
			new /obj/item/weapon/reagent_containers/food/snacks/spaghetti(get_turf(src))
		qdel(src)

// Dough attack self = Bun
/obj/item/weapon/reagent_containers/food/snacks/dough/attack_self(mob/user)
	new /obj/item/weapon/reagent_containers/food/snacks/bun(get_turf(src))
	user << "You form the dough into a bun."
	qdel(src)

// Slicable into 3xdoughslices
/obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough
	name = "flat dough"
	desc = "A flattened dough."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "flat dough"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/doughslice
	slices_num = 3
	center_of_mass = list("x"=16, "y"=16)
	decay = 25*600
	satisfaction = -3
	nutriment_amt = 2
	nutriment_desc = list("flour" = 2)
	New()
		..()
		reagents.add_reagent("protein", 1)

/obj/item/weapon/reagent_containers/food/snacks/doughslice
	name = "dough slice"
	desc = "A building block of an impressive dish."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "doughslice"
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/spaghetti
	slices_num = 1
	satisfaction = -2
	center_of_mass = list("x"=17, "y"=19)
	nutriment_desc = list("dough" = 1)
	nutriment_amt = 1
	decay = 25*600

/obj/item/weapon/reagent_containers/food/snacks/bun
	name = "bun"
	desc = "A base for any self-respecting burger."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "bun"
	center_of_mass = list("x"=16, "y"=12)
	nutriment_desc = list("bun" = 4)
	nutriment_amt = 4
	satisfaction = 3
	decay = 25*600

/obj/item/weapon/reagent_containers/food/snacks/burger
	name = "burger"
	desc = "Does not contain ham, probably."
	icon_state = "hburger"
	satisfaction = 6
	center_of_mass = list("x"=16, "y"=17)
	decay = 17*600
	nutriment_desc = list("bun" = 4)
	New()
		..()
		reagents.add_reagent("protein", 6)

/obj/item/weapon/reagent_containers/food/snacks/cheeseburger
	name = "cheeseburger"
	desc = "Contains cheese, duh."
	icon_state = "cheeseburger"
	satisfaction = 6
	center_of_mass = list("x"=16, "y"=17)
	decay = 17*600
	nutriment_desc = list("bun" = 4, "cheese" = 3)
	New()
		..()
		reagents.add_reagent("protein", 8)

/obj/item/weapon/reagent_containers/food/snacks/bun/attackby(obj/item/weapon/W as obj, mob/user as mob)
	// Bun + meatpatty = burger
	if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/patty))
		new /obj/item/weapon/reagent_containers/food/snacks/burger(src)
		user << "You make a burger."
		qdel(W)
		qdel(src)

	// Bun + cutlet = hamburger
	else if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/cutlet))
		new /obj/item/weapon/reagent_containers/food/snacks/burger(src)
		user << "You make a burger."
		qdel(W)
		qdel(src)

	// Bun + sausage = hotdog
	if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/sausage))
		new /obj/item/weapon/reagent_containers/food/snacks/hotdog(src)
		user << "You make a hotdog."
		qdel(W)
		qdel(src)

	// Bun + cocoa beans = cookie
	if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/grown/cocoa))
		new /obj/item/weapon/reagent_containers/food/snacks/cookie(src)
		user << "You make a cookie!"
		qdel(W)
		qdel(src)

// Burger + cheese wedge = cheeseburger
/obj/item/weapon/reagent_containers/food/snacks/burger/attackby(obj/item/weapon/reagent_containers/food/snacks/cheesewedge/W as obj, mob/user as mob)
	if (istype(W))// && !istype(src,/obj/item/weapon/reagent_containers/food/snacks/cheesewedge))
		new /obj/item/weapon/reagent_containers/food/snacks/cheeseburger(src)
		user << "You make a cheeseburger."
		qdel(W)
		qdel(src)
		return
	else
		..()
/*
// Human Burger + cheese wedge = cheeseburger
/obj/item/weapon/reagent_containers/food/snacks/human/burger/attackby(obj/item/weapon/reagent_containers/food/snacks/cheesewedge/W as obj, mob/user as mob)
	if (istype(W))
		new /obj/item/weapon/reagent_containers/food/snacks/cheeseburger(src)
		user << "You make a cheeseburger."
		qdel(W)
		qdel(src)
		return
	else
		..()
*/

/obj/item/weapon/reagent_containers/food/snacks/rawcutlet
	name = "raw cutlet"
	desc = "A thin piece of raw meat."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "rawcutlet"
	center_of_mass = list("x"=17, "y"=20)
	raw = TRUE
	rotten_icon_state = "rottencutlet"
	rots = TRUE
	decay = 15*600
	satisfaction = -2
	non_vegetarian = TRUE
	nutriment_desc = list("bloody" = 3)
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/driedmeat
	New()
		..()
		reagents.add_reagent("protein", 1)

/obj/item/weapon/reagent_containers/food/snacks/cutlet/attack_self(mob/user)
	if (istype(user.l_hand, /obj/item/weapon/reagent_containers/glass) || istype(user.r_hand, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/G
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers/glass))
			G  = user.l_hand
		else
			G  = user.r_hand
		if (G.reagents.get_reagent_amount("flour") >= 5)
			if (do_after(user, 90))
				visible_message("[user.name] pours the [src.name] onto the [G.name], covering it.")
				G.reagents.remove_reagent("flour", 5)
				new/obj/item/weapon/reagent_containers/food/snacks/rawschnitzel(user.loc)
				qdel(src)
				return
	else
		return ..()

/obj/item/weapon/reagent_containers/food/snacks/rawschnitzel
	name = "uncooked schnitzel"
	desc = "A thin piece of raw meat covered in flour."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "schnitzel-breaded"
	center_of_mass = list("x"=17, "y"=20)
	raw = TRUE
	rotten_icon_state = "schnitzel-breaded-rotten"
	rots = TRUE
	decay = 15*600
	satisfaction = -4
	non_vegetarian = TRUE
	nutriment_desc = list ("flour" = 1)
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/cutlet
	name = "cutlet"
	desc = "A tasty meat slice."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "cutlet"
	center_of_mass = list("x"=17, "y"=20)
	non_vegetarian = TRUE
	decay = 12*600
	satisfaction = 5
	nutriment_desc = list ("crust" = 1)
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/hotdog
	name = "hotdog"
	desc = "Unrelated to dogs, maybe."
	icon_state = "hotdog"
	satisfaction = 6
	center_of_mass = list("x"=16, "y"=17)
	nutriment_desc = list ("bun" = 1)
	decay = 17*600
	New()
		..()
		reagents.add_reagent("protein", 6)

/obj/item/weapon/reagent_containers/food/snacks/flatbread
	name = "flatbread"
	desc = "Bland but filling."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "flatbread"
	satisfaction = 4
	center_of_mass = list("x"=16, "y"=16)
	nutriment_desc = list("bread" = 3)
	nutriment_amt = 3
	decay = 25*600

// potato + knife = raw sticks
/obj/item/weapon/reagent_containers/food/snacks/grown/potato/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		new /obj/item/weapon/reagent_containers/food/snacks/rawsticks(src)
		user << "You cut the potato."
		qdel(src)
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/rawsticks
	name = "raw potato sticks"
	desc = "Raw fries, not very tasty."
	icon = 'icons/obj/food/food_ingredients.dmi'
	icon_state = "rawsticks"
	satisfaction = -2
	center_of_mass = list("x"=16, "y"=12)
	nutriment_desc = list("raw potato" = 3)
	nutriment_amt = 3
	decay = 27*600

/obj/item/weapon/reagent_containers/food/snacks/leaf_salad
	name = "leaf salad"
	desc = "Leaf salad, best selection of leaves straight from the tree and into the mouth."
	icon_state = "leaf_salad"
	satisfaction = 2
	center_of_mass = list("x"=16, "y"=12)
	nutriment_desc = list("leaves" = 3)
	nutriment_amt = 3
	decay = 27*600
