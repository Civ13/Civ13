/* Food */

/datum/reagent/nutriment
	name = "Nutriment"
	id = "nutriment"
	description = "All the vitamins, minerals, and carbohydrates the body needs in pure form."
	taste_mult = 4
	reagent_state = SOLID
	metabolism = REM * 4
	var/nutriment_factor = 30 // Per unit
	var/injectable = FALSE
	color = "#664330"

/datum/reagent/nutriment/New()
	..()
	data = list()
	data.len = 10

/datum/reagent/nutriment/mix_data(var/list/newdata, var/newamount)
	if (!islist(newdata) || !newdata.len)
		return
	for (var/i in 1 to newdata.len)
		if (!(newdata[i] in data))
			data.Add(newdata[i])
			data[newdata[i]] = FALSE
		data[newdata[i]] += newdata[newdata[i]]
	var/totalFlavor = FALSE
	for (var/i in 1 to data.len)
		if (data[i])
			totalFlavor += data[data[i]]
	for (var/i in 1 to data.len) //cull the tasteless
		if (i <= data.len && data[i])
			if (data[data[i]]/totalFlavor * 100 < 10)
				data[data[i]] = null
				data -= data[i]
				data -= null

/datum/reagent/nutriment/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (!injectable)
		M.adjustToxLoss(0.1 * removed)
		return
	affect_ingest(M, alien, removed)

/datum/reagent/nutriment/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	if (issmall(M)) removed *= 2 // Small bodymass, more effect from lower volume.
	M.heal_organ_damage(0.5 * removed, FALSE)
	M.nutrition += nutriment_factor * removed // For hunger and fatness
	M.bowels += (nutriment_factor * removed)/6
	M.add_chemical_effect(CE_BLOODRESTORE, 4 * removed)

/datum/reagent/nutriment/glucose
	name = "Glucose"
	id = "glucose"
	color = "#FFFFFF"

	injectable = TRUE

/datum/reagent/nutriment/protein
	name = "animal protein"
	taste_description = "some sort of protein"
	id = "protein"
	color = "#440000"


/datum/reagent/nutriment/protein/egg
	name = "egg yolk"
	taste_description = "egg"
	id = "egg"
	color = "#FFFFAA"

/datum/reagent/nutriment/honey
	name = "Honey"
	id = "honey"
	description = "A golden yellow syrup, loaded with sugary sweetness."
	taste_description = "sweetness"
	nutriment_factor = 10
	color = "#eb9605"

/datum/reagent/nutriment/flour
	name = "flour"
	id = "flour"
	description = "This is what you rub all over yourself to pretend to be a ghost."
	taste_description = "chalky wheat"
	reagent_state = SOLID
	nutriment_factor = TRUE
	color = "#FFFFFF"

/datum/reagent/nutriment/barleyflour
	name = "barleyflour"
	id = "barleyflour"
	description = "You can eat it, but the main use is to make beer."
	taste_description = "toasted barley"
	reagent_state = SOLID
	nutriment_factor = TRUE
	color = "#666666"

/datum/reagent/nutriment/oatflour
	name = "oatflour"
	id = "oatflour"
	description = "Grounded oats."
	taste_description = "oats"
	reagent_state = SOLID
	nutriment_factor = TRUE
	color = "#666666"

/datum/reagent/nutriment/flour/touch_turf(var/turf/T)
	new /obj/effect/decal/cleanable/flour(T)
/datum/reagent/nutriment/barleyflour/touch_turf(var/turf/T)
	new /obj/effect/decal/cleanable/flour(T)
/datum/reagent/nutriment/cocoa
	name = "Cocoa Powder"
	id = "cocoa"
	description = "A fatty, bitter paste made from cocoa beans."
	taste_description = "bitterness"
	taste_mult = 1.3
	reagent_state = SOLID
	nutriment_factor = 5
	color = "#302000"

/datum/reagent/nutriment/soysauce
	name = "Soysauce"
	id = "soysauce"
	description = "A salty sauce made from the soy plant."
	taste_description = "umami"
	taste_mult = 1.1
	reagent_state = LIQUID
	nutriment_factor = 2
	color = "#792300"

/datum/reagent/nutriment/tomato
	name = "Tomato sauce"
	id = "tomato"
	description = "A thick sauce made from the tomatoes."
	taste_description = "sweet, acidity with a hint of umami"
	taste_mult = 1.4
	reagent_state = LIQUID
	nutriment_factor = 2.3
	color = "#B21807"

/datum/reagent/nutriment/paprika
	name = "Paprika"
	id = "paprika"
	description = "A mildly spicy spice from red peppers."
	taste_description = "mildly spicy"
	taste_mult = 1.1
	reagent_state = SOLID
	nutriment_factor = 1.5
	color = "#792300"

/datum/reagent/nutriment/parsley
	name = "Parsley"
	id = "parsley"
	description = "A clean and peppery taste with a touch of earthiness."
	taste_description = "peppery and earthy"
	taste_mult = 1.3
	reagent_state = SOLID
	nutriment_factor = 1.2

/datum/reagent/nutriment/juniper
	name = "Juniper"
	id = "juniper"
	description = "A very tart and sharp tasting berry"
	taste_description = "sharp"
	taste_mult = 1.3
	reagent_state = SOLID
	nutriment_factor = 0.6

/datum/reagent/nutriment/juniper_juice
	name = "Juniper juice"
	id = "juniper_juice"
	description = "A very tart and sharp tasting berry"
	taste_description = "extremely tarty and sharp"
	taste_mult = 1.3
	reagent_state = LIQUID
	nutriment_factor = 0.9

/datum/reagent/nutriment/cola
	name = "cola"
	id = "cola"
	description = "A sweet taste of sugar."
	taste_description = "sweet"
	taste_mult = 1.1
	reagent_state = LIQUID
	nutriment_factor = 3
	color = "#120b02"

/datum/reagent/nutriment/ketchup
	name = "Ketchup"
	id = "ketchup"
	description = "Ketchup, catsup, whatever. It's tomato paste."
	taste_description = "ketchup"
	reagent_state = LIQUID
	nutriment_factor = 5
	color = "#731008"

/datum/reagent/nutriment/rice
	name = "Rice"
	id = "rice"
	description = "Enjoy the great taste of nothing."
	taste_description = "rice"
	taste_mult = 0.4
	reagent_state = SOLID
	nutriment_factor = TRUE
	color = "#FFFFFF"

/datum/reagent/nutriment/coconutmilk //Added new reagent for coconuts
	name = "Coconut milk"
	id = "coconutmilk"
	description = "A white, milky liquid, loaded with sugary sweetness."
	taste_description = "sweetness"
	nutriment_factor = 25
	color = "#FFFFFF"

/datum/reagent/nutriment/apricotjuice //Added new reagent for apricots
	name = "Apricot juice"
	id = "apricotjuice"
	description = "An orange, transparant liquid, tasting of apricots."
	taste_description = "sweetness"
	nutriment_factor = 25
	color = "#FFFFFF"

/datum/reagent/nutriment/cherryjelly
	name = "Cherry Jelly"
	id = "cherryjelly"
	description = "Totally the best. Only to be spread on foods with excellent lateral symmetry."
	taste_description = "cherry"
	taste_mult = 1.3
	reagent_state = LIQUID
	nutriment_factor = TRUE
	color = "#801E28"

/datum/reagent/nutriment/cornoil
	name = "Corn Oil"
	id = "cornoil"
	description = "An oil derived from various types of corn."
	taste_description = "slime"
	taste_mult = 0.1
	reagent_state = LIQUID
	nutriment_factor = 1
	color = "#302000"

/datum/reagent/nutriment/cornoil/touch_turf(var/turf/T)
	if (!istype(T))
		return


/datum/reagent/nutriment/mint
	name = "Mint"
	id = "mint"
	description = "Also known as Mentha."
	taste_description = "mint"
	reagent_state = LIQUID
	color = "#CF3600"

/datum/reagent/nutriment/sprinkles
	name = "Sprinkles"
	id = "sprinkles"
	description = "Multi-colored little bits of sugar, commonly found on donuts. Loved by cops."
	taste_description = "sweetness"
	reagent_state = SOLID
	color = "#FFBAFF"

/datum/reagent/nutriment/caramel
	name = "Caramel"
	id = "caramel"
	description = "Who would have guessed that heated sugar could be so delicious?"
	taste_description = "caramel"
	reagent_state = SOLID
	color = "#824D27"

/* Non-food stuff like condiments */

/datum/reagent/sodiumchloride
	name = "Table Salt"
	id = "sodiumchloride"
	description = "A salt made of sodium chloride. Commonly used to season food."
	taste_description = "salt"
	reagent_state = SOLID
	color = "#FFFFFF"
	taste_mult = 2
	overdose = REAGENTS_OVERDOSE
//salt will make you thirsty
/datum/reagent/sodiumchloride/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.water -= (removed * 360 * 1.5) //basically, it removes the saltwater you drink plus dehydrates you in the same amount

/datum/reagent/blackpepper
	name = "Black Pepper"
	id = "blackpepper"
	description = "A powder ground from peppercorns. *AAAACHOOO*"
	taste_description = "pepper"
	reagent_state = SOLID
	color = "#000000"

/datum/reagent/enzyme
	name = "Yeast"
	id = "enzyme"
	description = "A type of fungus used in the preperation of certain chemicals and foods."
	taste_description = "sweetness"
	taste_mult = 0.7
	reagent_state = LIQUID
	color = "#365E30"
	overdose = REAGENTS_OVERDOSE

/datum/reagent/hops
	name = "Hops"
	id = "hops"
	description = "A plant used to give beer its bitter taste."
	taste_description = "bittery hops"
	taste_mult = 1.2
	reagent_state = LIQUID
	color = "#709B40"
	overdose = REAGENTS_OVERDOSE

/datum/reagent/agave
	name = "Agave"
	id = "agave"
	description = "A plant used to make mezcal."
	taste_description = "sappy"
	taste_mult = 1.2
	reagent_state = LIQUID
	color = "#709B40"

/datum/reagent/fish
	name = "Fish"
	id = "fish"
	description = "tastes like fish."
	taste_description = "Fishy"
	taste_mult = 1.2
	reagent_state = SOLID
	color = "#8E1600"

/datum/reagent/capsaicin
	name = "Capsaicin Oil"
	id = "capsaicin"
	description = "This is what makes chilis hot."
	taste_description = "hot peppers"
	taste_mult = 1.5
	reagent_state = LIQUID
	color = "#B31008"
	var/agony_dose = 5
	var/agony_amount = 2
	var/discomfort_message = "<span class='danger'>Your insides feel uncomfortably hot!</span>"
	var/slime_temp_adj = 10

/datum/reagent/capsaicin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(0.5 * removed)

/datum/reagent/capsaicin/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.species && (H.species.flags & (NO_PAIN)))
			return
	if (dose < agony_dose)
		if (prob(5) || dose == metabolism) //dose == metabolism is a very hacky way of forcing the message the first time this procs
			M << discomfort_message
	else
		M.apply_effect(agony_amount, AGONY, FALSE)
		if (prob(5))
			M.custom_emote(2, "[pick("dry heaves!","coughs!","splutters!")]")
			M << "<span class='danger'>You feel like your insides are burning!</span>"
	holder.remove_reagent("frostoil", 5)

/datum/reagent/capsaicin/condensed
	name = "Condensed Capsaicin"
	id = "condensedcapsaicin"
	description = "A chemical agent used for self-defense and in police work."
	taste_description = "satan's piss"
	taste_mult = 10
	reagent_state = LIQUID
	touch_met = 50 // Get rid of it quickly
	color = "#B31008"
	agony_dose = 0.5
	agony_amount = 4
	discomfort_message = "<span class='danger'>You feel like your insides are burning!</span>"
	slime_temp_adj = 15

/datum/reagent/capsaicin/condensed/affect_touch(var/mob/living/human/M, var/alien, var/removed)
	var/eyes_covered = FALSE
	var/mouth_covered = FALSE
	var/no_pain = FALSE
	var/obj/item/eye_protection = null
	var/obj/item/face_protection = null

	var/list/protection
	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		protection = list(H.head, H.wear_mask)
		if (H.species && (H.species.flags & NO_PAIN))
			no_pain = TRUE //TODO: living-level can_feel_pain() proc
	else
		protection = list(M.wear_mask)

	for (var/obj/item/I in protection)
		if (I)
			if (I.body_parts_covered & EYES)
				eyes_covered = TRUE
				eye_protection = I.name
			if ((I.body_parts_covered & FACE) && !(I.item_flags & FLEXIBLEMATERIAL))
				mouth_covered = TRUE
				face_protection = I.name

	var/message = null
	if (eyes_covered)
		if (!mouth_covered)
			message = "<span class='warning'>Your [eye_protection] protects your eyes from the pepperspray!</span>"
	else
		message = "<span class='warning'>The pepperspray gets in your eyes!</span>"
		if (mouth_covered)
			M.eye_blurry = max(M.eye_blurry, 15)
			M.eye_blind = max(M.eye_blind, 5)
		else
			M.eye_blurry = max(M.eye_blurry, 25)
			M.eye_blind = max(M.eye_blind, 10)

	if (mouth_covered)
		if (!message)
			message = "<span class='warning'>Your [face_protection] protects you from the pepperspray!</span>"
	else if (!no_pain)
		message = "<span class='danger'>Your face and throat burn!</span>"
		if (prob(25))
			M.custom_emote(2, "[pick("coughs!","coughs hysterically!","splutters!")]")
		M.Stun(5)
		M.Weaken(5)

/datum/reagent/condensedcapsaicin/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.species && (H.species.flags & NO_PAIN))
			return
	if (dose == metabolism)
		M << "<span class='danger'>You feel like your insides are burning!</span>"
	else
		M.apply_effect(4, AGONY, FALSE)
		if (prob(5))
			M.visible_message("<span class='warning'>[M] [pick("dry heaves!","coughs!","splutters!")]</span>", "<span class='danger'>You feel like your insides are burning!</span>")
	holder.remove_reagent("frostoil", 5)

/* Drinks */

/datum/reagent/drink
	name = "Drink"
	id = "drink"
	description = "Uh, some kind of drink."
	reagent_state = LIQUID
	color = "#E78108"
	var/nutrition = FALSE // Per unit
	var/adj_dizzy = FALSE // Per tick
	var/adj_drowsy = FALSE
	var/adj_sleepy = FALSE
	var/adj_temp = FALSE

// apparently this never happens - Kachnov
/datum/reagent/drink/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(removed) // Probably not a good idea; not very deadly though
	return

/datum/reagent/drink/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	M.nutrition += nutrition * removed
	M.bladder += removed
	M.bowels += (nutrition * removed)/6

	M.dizziness = max(0, M.dizziness + adj_dizzy)
	M.drowsyness = max(0, M.drowsyness + adj_drowsy)
	M.sleeping = max(0, M.sleeping + adj_sleepy)
	if (adj_temp > 0 && M.bodytemperature < 310) // 310 is the normal bodytemp. 310.055
		M.bodytemperature = min(310, M.bodytemperature + (adj_temp * TEMPERATURE_DAMAGE_COEFFICIENT))
	if (adj_temp < 0 && M.bodytemperature > 310)
		M.bodytemperature = min(310, M.bodytemperature - (adj_temp * TEMPERATURE_DAMAGE_COEFFICIENT))

	if (M.water < 0)
		M.water += rand(40,50)
	M.water += removed * 15

// Juices

/datum/reagent/drink/banana
	name = "Banana Juice"
	id = "banana"
	description = "The raw essence of a banana."
	taste_description = "banana"
	color = "#C3AF00"

/datum/reagent/drink/berryjuice
	name = "Berry Juice"
	id = "berryjuice"
	description = "A delicious blend of several different kinds of berries."
	taste_description = "berries"
	color = "#990066"

/datum/reagent/drink/carrotjuice
	name = "Carrot juice"
	id = "carrotjuice"
	description = "It is just like a carrot but without crunching."
	taste_description = "carrots"
	color = "#FF8C00" // rgb: 255, 140, FALSE

/datum/reagent/drink/carrotjuice/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.reagents.add_reagent("imidazoline", removed * 0.2)

/datum/reagent/drink/olive_oil
	name = "Olive Oil"
	id = "olive_oil"
	description = "A thick oil. Good for seasoning and lamps."
	taste_description = "olives"
	color = "#343400"

/datum/reagent/drink/olive_oil/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (prob(10))
		M << "<span class = 'warning'>You feel sick...</span>"
		M.vomit()

/datum/reagent/drink/lard
	name = "lard"
	id = "lard"
	description = "A thick and smelling lard, with meat and bones fragments. Doesnt looks good."
	taste_description = "greasy"
	color = "#F6EFE2"

/datum/reagent/drink/lard/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (prob(10))
		M << "<span class = 'warning'>You feel disgusted and sick...</span>"
		M.vomit()

/datum/reagent/drink/fat_oil
	name = "Fat Oil"
	id = "fat_oil"
	description = "A thick and smelling oil. Good for seasoning and lamps."
	taste_description = "greasy"
	color = "#9B7653"

/datum/reagent/drink/fat_oil/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (prob(10))
		M << "<span class = 'warning'>You feel sick...</span>"
		M.vomit()

/datum/reagent/drink/grapejuice
	name = "Grape Juice"
	id = "grapejuice"
	description = "It's grapejuice!"
	taste_description = "grapes"
	color = "#863333"

/datum/reagent/drink/sapodillajuice
	name = "Sapodilla Juice"
	id = "sapodillajuice"
	description = "It's sweet, malty!"
	taste_description = "sweet and malty"
	color = "#f3bc5f"

/datum/reagent/drink/zucchinijuice
	name = "Zucchini Juice"
	id = "zucchinijuice"
	description = "a strange green juice!"
	taste_description = " slightly sweet and slightly bitter"
	color = "#365E30"

/datum/reagent/drink/lemonjuice
	name = "Lemon Juice"
	id = "lemonjuice"
	description = "This juice is VERY sour."
	taste_description = "sourness"
	taste_mult = 1.1
	color = "#AFAF00"

/datum/reagent/drink/limejuice
	name = "Lime Juice"
	id = "limejuice"
	description = "The sweet-sour juice of limes."
	taste_description = "unbearable sourness"
	taste_mult = 1.1
	color = "#365E30"

/datum/reagent/drink/limejuice/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustToxLoss(-0.5 * removed)

/datum/reagent/drink/orangejuice
	name = "Orange juice"
	id = "orangejuice"
	description = "Both delicious AND rich in Vitamin C, what more do you need?"
	taste_description = "oranges"
	color = "#E78108"

/datum/reagent/drink/orangejuice/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustOxyLoss(-2 * removed)

/datum/reagent/toxin/poisonberryjuice // It has more in common with toxins than drinks... but it's a juice
	name = "Poison Berry Juice"
	id = "poisonberryjuice"
	description = "A tasty juice blended from various kinds of very deadly and toxic berries."
	taste_description = "berries"
	color = "#863353"
	strength = 5

/datum/reagent/drink/potato_juice
	name = "Potato Juice"
	id = "potato"
	description = "Juice of the potato. Bleh."
	taste_description = "irish sadness"
	color = "#302000"

/datum/reagent/drink/apple_juice
	name = "Apple Juice"
	id = "applejuice"
	description = "Juice of the old green apple."
	taste_description = "sweet"
	color = "#ff6249"

/datum/reagent/drink/sapote_juice
	name = "Sapote Juice"
	id = "sapotejuice"
	description = "Juice of the Sapote Fruit."
	taste_description = "slighty sweet yet nutty"
	color = "#ff6249"

/datum/reagent/drink/tomatojuice
	name = "Tomato Juice"
	id = "tomatojuice"
	description = "Tomatoes made into juice. What a waste of big, juicy tomatoes, huh?"
	taste_description = "tomatoes"
	color = "#731008"

/datum/reagent/drink/liquorice
	name = "Liquorice"
	id = "liquorice"
	description = "liquorice taste?"
	taste_description = "sweet, bitter, salty and sour"
	color = "#191919"

/datum/reagent/drink/celery
	name = "Celery"
	id = "celery"
	description = "green taste?"
	taste_description = "sweet, bitter, salty and sour"
	color = "#c38452"

/datum/reagent/drink/tomatojuice/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.heal_organ_damage(0, 0.5 * removed)

/datum/reagent/drink/watermelonjuice
	name = "Watermelon Juice"
	id = "watermelonjuice"
	description = "Delicious juice made from watermelon."
	taste_description = "sweet watermelon"
	color = "#B83333"

// Everything else

/datum/reagent/drink/milk
	name = "Milk"
	id = "milk"
	description = "An opaque white liquid produced by the mammary glands of mammals."
	taste_description = "milk"
	color = "#DFDFDF"

/datum/reagent/drink/milk/blue
	name = "Blue Milk"
	id = "bmilk"
	description = "An opaque light blue liquid produced by the mammary glands of banthas."
	taste_description = "extremely sweet and rich "
	color = "#bfe6ff"

/datum/reagent/drink/milk/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.heal_organ_damage(0.5 * removed, FALSE)
	holder.remove_reagent("capsaicin", 10 * removed)

	if (M.water < 0)
		M.water += rand(20,30)
	M.water += removed * 10

/datum/reagent/drink/milk/cream
	name = "Cream"
	id = "cream"
	description = "The fatty, still liquid part of milk. Why don't you mix this with sum scotch, eh?"
	taste_description = "creamy milk"
	color = "#DFD7AF"

/datum/reagent/drink/kiraspecial
	name = "Kira Special"
	description = "Long live the guy who everyone had mistaken for a girl. Baka!"
	taste_description = "fruity sweetness"
	color = "#cccc99"
	adj_temp = -5

/datum/reagent/drink/tea
	name = "Tea"
	id = "tea"
	description = "Tasty black tea, it has antioxidants, it's good for you!"
	taste_description = "tart black tea"
	color = "#101000"
	adj_dizzy = -2
	adj_drowsy = -1
	adj_sleepy = -3
	adj_temp = 20

/datum/reagent/drink/tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustToxLoss(-1.5 * removed)
	M.drowsyness = max(0, M.drowsyness - 4 * removed)
	M.hallucination = max(0, M.hallucination - 6 * removed)
	if (M.bodytemperature > 310.7)
		M.bodytemperature = (M.bodytemperature-0.1)
	if (istype(M, /mob/living/human))
		var/mob/living/human/HH = M
		if (HH.disease == 1 && HH.disease_type == "flu")
			HH.disease_treatment = TRUE

/datum/reagent/drink/quinine
	name = "Quinine"
	id = "quinine"
	description = "Bitter, from the chinchona plant."
	taste_description = "very strong bitterness"
	color = "#f4f4f4"

/datum/reagent/drink/quinine/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.drowsyness = max(0, M.drowsyness - 2 * removed)
	if (M.bodytemperature > 310.055)
		M.bodytemperature = (M.bodytemperature-0.15)
	if (istype(M, /mob/living/human))
		var/mob/living/human/HH = M
		if (HH.disease == 1 && HH.disease_type == "malaria")
			HH.disease_treatment = TRUE

/datum/reagent/drink/coffee
	name = "Coffee"
	id = "coffee"
	description = "Coffee is a brewed drink prepared from roasted seeds, commonly called coffee beans, of the coffee plant."
	taste_description = "bitterness"
	taste_mult = 1.3
	color = "#482000"
	adj_dizzy = -5
	adj_drowsy = -3
	adj_sleepy = -2
	adj_temp = 25
	overdose = 45

/datum/reagent/drink/coffee/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (adj_temp > 0)
		holder.remove_reagent("frostoil", 10 * removed)
	M.add_chemical_effect(CE_PULSE, TRUE)
	M.add_chemical_effect(CE_SPEEDBOOST, TRUE)

/datum/reagent/drink/coffee/overdose(var/mob/living/human/M, var/alien)
	M.make_jittery(5)
	M.add_chemical_effect(CE_PULSE, 2)

/datum/reagent/drink/coffee/cafe_latte
	name = "Cafe Latte"
	description = "A nice, strong and tasty beverage while you are reading."
	taste_description = "bitter creamy coffee"
	color = "#c65905"
	adj_temp = 5

/datum/reagent/drink/hot_coco
	name = "Hot Chocolate"
	id = "hot_coco"
	description = "Made with love! And cocoa beans."
	taste_description = "creamy chocolate"
	reagent_state = LIQUID
	color = "#403010"
	nutrition = 2
	adj_temp = 5

/datum/reagent/drink/tonic
	name = "Tonic Water"
	id = "tonic"
	description = "It tastes strange but at least the quinine keeps the Malaria at bay."
	taste_description = "tart and fresh"
	color = "#ffffff80"
	adj_dizzy = -5
	adj_drowsy = -3
	adj_sleepy = -2
	adj_temp = -5

/datum/reagent/drink/lemonade
	name = "Lemonade"
	description = "Oh the nostalgia..."
	taste_description = "tartness"
	id = "lemonade"
	color = "#FFFF00"
	adj_temp = -5

/datum/reagent/drink/milkshake
	name = "Milkshake"
	description = "Glorious brainfreezing mixture."
	taste_description = "creamy vanilla"
	id = "milkshake"
	color = "#AEE5E4"
	adj_temp = -9

/datum/reagent/drink/grenadine
	name = "Grenadine Syrup"
	id = "grenadine"
	description = "Made in the modern day with proper pomegranate substitute. Who uses real fruit, anyways?"
	taste_description = "100% pure pomegranate"
	color = "#FF004F"

/datum/reagent/drink/dry_ramen
	name = "Dry Ramen"
	id = "dry_ramen"
	description = "Space age food, since August 25, 1958. Contains dried noodles, vegetables, and chemicals that boil in contact with water."
	taste_description = "dry and cheap noodles"
	reagent_state = SOLID
	nutrition = TRUE
	color = "#302000"

/datum/reagent/drink/hot_ramen
	name = "Hot Ramen"
	id = "hot_ramen"
	description = "The noodles are boiled, the flavors are artificial, just like being back in school."
	taste_description = "wet and cheap noodles"
	reagent_state = LIQUID
	color = "#302000"
	nutrition = 5
	adj_temp = 5

/datum/reagent/drink/ice
	name = "Ice"
	id = "ice"
	description = "Frozen water, your dentist wouldn't like you chewing this."
	taste_description = "ice"
	taste_mult = 1.5
	reagent_state = SOLID
	color = "#619494"
	adj_temp = -5

/datum/reagent/drink/nothing
	name = "Nothing"
	id = "nothing"
	description = "Absolutely nothing."
	taste_description = "nothing"

/datum/reagent/drink/health
/datum/reagent/drink/health/minor
	name = "Minor Healing"
	id = "minor"
	description = "A weak healing concotion."
	taste_description = "slightly rejuvenating."
	color = "#440000"
	adj_dizzy = -20
/datum/reagent/drink/health/minor/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.adjustBruteLoss(-4 * removed)
		M.adjustFireLoss(-4 * removed)
		M.adjustBrainLoss(-4 * removed)
		M.adjustToxLoss(-4 * removed)
		M.adjustOxyLoss(-4 * removed)
		M.eye_blurry = max(M.eye_blurry - 5, FALSE)
		M.add_chemical_effect(CE_PAINKILLER, 5)
		M.drowsyness = max(M.drowsyness - 5, FALSE)
		M.AdjustParalysis(-1)
		M.AdjustStunned(-1)
		M.AdjustWeakened(-1)
		M.restore_blood()
		M.updatehealth()
/datum/reagent/drink/health/healing
	name = "Healing"
	id = "healing"
	description = "A healing concotion."
	taste_description = "more or less rejuvenating."
	color = "#440000"
	adj_dizzy = -50
/datum/reagent/drink/health/healing/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.adjustBruteLoss(-6 * removed)
		M.adjustFireLoss(-6 * removed)
		M.adjustBrainLoss(-6 * removed)
		M.adjustToxLoss(-6 * removed)
		M.adjustOxyLoss(-6 * removed)
		M.eye_blurry = max(M.eye_blurry - 5, FALSE)
		M.add_chemical_effect(CE_PAINKILLER, 10)
		M.drowsyness = max(M.drowsyness - 6, FALSE)
		M.AdjustParalysis(-1)
		M.AdjustStunned(-1)
		M.AdjustWeakened(-1)
		M.restore_blood()
		M.updatehealth()
/datum/reagent/drink/health/plentiful
	name = "Plentiful Healing"
	id = "plentiful"
	description = "A stronger healing concotion."
	taste_description = "quite rejuvenating."
	color = "#440000"
	adj_dizzy = -100
/datum/reagent/drink/health/plentiful/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.adjustBruteLoss(-10 * removed)
		M.adjustFireLoss(-10 * removed)
		M.adjustBrainLoss(-10 * removed)
		M.adjustToxLoss(-10 * removed)
		M.adjustOxyLoss(-10 * removed)
		M.eye_blurry = max(M.eye_blurry - 5, FALSE)
		M.add_chemical_effect(CE_PAINKILLER, 20)
		M.drowsyness = max(M.drowsyness - 10, FALSE)
		M.AdjustParalysis(-1)
		M.AdjustStunned(-1)
		M.AdjustWeakened(-1)
		M.restore_blood()
		M.updatehealth()
/datum/reagent/drink/health/vigorous
	name = "Vigorous Healing"
	id = "vigor"
	description = "a very strong healing concotion."
	taste_description = "extremely rejuvenating."
	color = "#440000"
	adj_dizzy = -200
/datum/reagent/drink/health/vigorous/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.adjustBruteLoss(-25 * removed)
		M.adjustFireLoss(-25 * removed)
		M.adjustBrainLoss(-25 * removed)
		M.adjustToxLoss(-25 * removed)
		M.adjustOxyLoss(-25 * removed)
		M.heal_organ_damage(25 * removed, 25 * removed)
		M.eye_blurry = max(M.eye_blurry - 5, FALSE)
		M.add_chemical_effect(CE_PAINKILLER, 40)
		M.drowsyness = max(M.drowsyness - 15, FALSE)
		M.AdjustParalysis(-1)
		M.AdjustStunned(-1)
		M.AdjustWeakened(-1)
		M.restore_blood()
		M.updatehealth()
/datum/reagent/drink/health/draught
	name = "Draught"
	id = "draught"
	description = "a rejuvenating healing concotion."
	taste_description = "extremely rejuvenating."
	color = "#440000"
/datum/reagent/drink/health/draught/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.rejuvenate()
		M.updatehealth()

/datum/reagent/drink/stamina
/datum/reagent/drink/stamina/minor
	name = "Minor Stamina"
	id = "minor_stamina"
	description = "A weak stamina concotion."
	taste_description = "slightly reinvigorating."
	color = "#440000"
	adj_dizzy = -20
/datum/reagent/drink/stamina/minor/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.stats["stamina"][1] = max(M.stats["stamina"][1] + 20, 0)
		M.updatehealth()

/datum/reagent/drink/stamina/plentiful
	name = "Stamina Potion"
	id = "plentiful_stamina"
	description = "A good stamina concotion."
	taste_description = "fairly reinvigorating."
	color = "#667164"
	adj_dizzy = -20
/datum/reagent/drink/stamina/plentiful/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.stats["stamina"][1] = max(M.stats["stamina"][1] + 50, 0)
		M.updatehealth()

/datum/reagent/drink/stamina/vigorous
	name = "Vigorous Stamina Potion"
	id = "stamina_vigor"
	description = "A good stamina concotion."
	taste_description = "fairly reinvigorating."
	color = "#667164"
	adj_dizzy = -20
/datum/reagent/drink/stamina/vigorous/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
		M.stats["stamina"][1] = max(M.stats["stamina"][1] + 150, 0)
		M.updatehealth()
/* Alcohol */

// Basic

/datum/reagent/ethanol/absinthe
	name = "Absinthe"
	id = "absinthe"
	description = "Watch out that the Green Fairy doesn't come for you!"
	taste_description = "licorice and herbs"
	taste_mult = 1.5
	color = "#33EE00"
	strength = 40

/datum/reagent/ethanol/mezcal
	name = "Mezcal"
	id = "mezcal"
	description = "Good old honey sap water!"
	taste_description = "savory and smoky"
	taste_mult = 1.5
	color = "#9b870c"
	strength = 24

/datum/reagent/ethanol/ale
	name = "Ale"
	id = "ale"
	description = "A dark alchoholic beverage made by malted barley and yeast."
	taste_description = "hearty barley ale"
	color = "#53150AE6"
	strength = 90
	nutriment_factor = 2

/datum/reagent/ethanol/mead
	name = "Mead"
	id = "mead"
	description = "A dark alchoholic beverage made by malted barley and yeast."
	taste_description = "a drink to put some hair on your chest"
	color = "#53150AE6"
	strength = 40
	nutriment_factor = 4
/datum/reagent/ethanol/mead/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	if (strength)
		if (issmall(M)) removed *= 2 // Small bodymass, more effect from lower volume.
		M.adjustBruteLoss(-(strength/8 * removed))

/datum/reagent/ethanol/beer
	name = "Beer"
	id = "beer"
	description = "An alcoholic beverage made from malted barley, hops, yeast, and water."
	taste_description = "beer"
	color = "#E68500E6"
	strength = 50
	nutriment_factor = 1

/datum/reagent/ethanol/wheatbeer
	name = "Wheat Beer"
	id = "wheatbeer"
	description = "An alcoholic beverage made from malted wheat, hops, yeast, and water."
	taste_description = "wheat beer"
	color = "#E68500E6"
	strength = 50
	nutriment_factor = 1

/datum/reagent/ethanol/bluecuracao
	name = "Blue Curacao"
	id = "bluecuracao"
	description = "Exotically blue, fruity drink, distilled from oranges."
	taste_description = "oranges"
	taste_mult = 1.1
	color = "#0000CD"
	strength = 30

/datum/reagent/ethanol/cognac
	name = "Cognac"
	id = "cognac"
	description = "A sweet and strongly alchoholic drink, made after numerous distillations and years of maturing. Classy as fornication."
	taste_description = "rich and smooth alcohol"
	taste_mult = 1.1
	color = "#AB3C05"
	strength = 80

/datum/reagent/ethanol/deadrum
	name = "Deadrum"
	id = "deadrum"
	description = "Popular with the sailors. Not very popular with everyone else."
	taste_description = "salty sea water"
	color = "#664300"
	strength = 80

/datum/reagent/ethanol/deadrum/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.dizziness +=5

/datum/reagent/ethanol/gin
	name = "Gin"
	id = "gin"
	description = "It's gin. I say, good sir."
	taste_description = "grain alcohol and a hint of a christmas tree"
	color = "#ffffff80"
	strength = 60

//Base type for alchoholic drinks containing coffee
/datum/reagent/ethanol/coffee
	overdose = 45

/datum/reagent/ethanol/coffee/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.dizziness = max(0, M.dizziness - 5)
	M.drowsyness = max(0, M.drowsyness - 3)
	M.sleeping = max(0, M.sleeping - 2)
	if (M.bodytemperature > 310)
		M.bodytemperature = max(310, M.bodytemperature - (5 * TEMPERATURE_DAMAGE_COEFFICIENT))

/datum/reagent/ethanol/coffee/overdose(var/mob/living/human/M, var/alien)
	M.make_jittery(5)

/datum/reagent/ethanol/coffee/kahlua
	name = "Kahlua"
	id = "kahlua"
	description = "A widely known, Mexican coffee-flavoured liqueur. In production since 1936!"
	taste_description = "richness, bitterness and a hint of creaminess"
	taste_mult = 1.1
	color = "#562E00D9"
	strength = 30

/datum/reagent/ethanol/watermelonliquor
	name = "Watermelon Liquor"
	id = "watermelonliquor"
	description = "A relatively sweet and fruity 46 proof liquor."
	taste_description = "fruity alcohol"
	color = "#138808" // rgb: 19, 136, 8
	strength = 50

/datum/reagent/ethanol/rum
	name = "Rum"
	id = "rum"
	description = "Yohoho and all that."
	taste_description = "smooth alcohol, richness and sweetness"
	taste_mult = 1.1
	color = "#E832008C"
	strength = 70

/datum/reagent/ethanol/sake
	name = "Sake"
	id = "sake"
	description = "Japan's favorite drink."
	taste_description = "dry alcohol"
	color = "#664300"
	strength = 35

/datum/reagent/ethanol/tequilla
	name = "Tequila"
	id = "tequilla"
	description = "A strong and mildly flavoured, mexican produced spirit. Feeling thirsty hombre?"
	taste_description = "paint stripper"
	color = "#FFFF91"
	strength = 25

/datum/reagent/ethanol/thirteenloko
	name = "Thirteen Loko"
	id = "thirteenloko"
	description = "A potent mixture of caffeine and alcohol."
	taste_description = "jitters and death"
	color = "#102000"
	strength = 25
	nutriment_factor = TRUE

/datum/reagent/ethanol/thirteenloko/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.drowsyness = max(0, M.drowsyness - 7)
	if (M.bodytemperature > 310)
		M.bodytemperature = max(310, M.bodytemperature - (5 * TEMPERATURE_DAMAGE_COEFFICIENT))
	M.make_jittery(5)
	M.add_chemical_effect(CE_PULSE, 2)

/datum/reagent/ethanol/vermouth
	name = "Vermouth"
	id = "vermouth"
	description = "You suddenly feel a craving for a martini..."
	taste_description = "dry alcohol"
	taste_mult = 1.3
	color = "#91FF91" // rgb: 145, 255, 145
	strength = 40

/datum/reagent/ethanol/vodka
	name = "Vodka"
	id = "vodka"
	description = "Number one drink AND fueling choice for Russians worldwide."
	taste_description = "grain alcohol"
	color = "#ffffff80" // rgb: FALSE, 100, 200
	strength = 90

/datum/reagent/ethanol/whiskey
	name = "Whiskey"
	id = "whiskey"
	description = "A superb and well-aged single-malt whiskey. Damn."
	taste_description = "richness, molasses and a hint of smoke"
	color = "#AB3C05D9"
	strength = 70

/datum/reagent/ethanol/wine
	name = "Wine"
	id = "wine"
	description = "An alchoholic beverage made from distilled grape juice."
	taste_description = "bitter sweetness"
	color = "#6C0F1CD9"
	strength = 45
	nutriment_factor = 1

/datum/reagent/ethanol/palmwine
	name = "Palmwine"
	id = "palmwine"
	description = "Made from fermented palm sap."
	taste_description = "acidity"
	color = "#E0E0E0" // rgb: 126, 64, 67
	strength = 30
	nutriment_factor = 1
// Cocktails

/datum/reagent/ethanol/acid_spit
	name = "Acid Spit"
	id = "acidspit"
	description = "A drink for the daring, can be deadly if incorrectly prepared!"
	taste_description = "stomach acid"
	reagent_state = LIQUID
	color = "#365000"
	strength = 30

/datum/reagent/ethanol/alliescocktail
	name = "Allies Cocktail"
	id = "alliescocktail"
	description = "A drink made from your allies, not as sweet as when made from your enemies."
	taste_description = "bitter yet free"
	color = "#664300"
	strength = 25

/datum/reagent/ethanol/aloe
	name = "Aloe"
	id = "aloe"
	description = "So very, very, very good."
	taste_description = "sweet 'n creamy"
	color = "#664300"
	strength = 15

/datum/reagent/ethanol/garum
	name = "Garum"
	id = "garum"
	description = "Horrid smell but very unami."
	taste_description = "oceany"
	color = "#F7C652"
	strength = 3

/datum/reagent/ethanol/amasec
	name = "Amasec"
	id = "amasec"
	description = "Official drink of the Gun Club!"
	taste_description = "dark and metallic"
	reagent_state = LIQUID
	color = "#664300"
	strength = 25

/datum/reagent/ethanol/andalusia
	name = "Andalusia"
	id = "andalusia"
	description = "A nice, strangely named drink."
	taste_description = "lemons"
	color = "#664300"
	strength = 15

/datum/reagent/ethanol/antifreeze
	name = "Anti-freeze"
	id = "antifreeze"
	description = "Ultimate refreshment."
	taste_description = "Jack Frost's piss"
	color = "#664300"
	strength = 12
	adj_temp = 20
	targ_temp = 330

/datum/reagent/ethanol/atomicbomb
	name = "Atomic Bomb"
	id = "atomicbomb"
	description = "Nuclear proliferation never tasted so good."
	taste_description = "da bomb"
	reagent_state = LIQUID
	color = "#666300"
	strength = 10
	druggy = 50

/datum/reagent/ethanol/coffee/b52
	name = "B-52"
	id = "b52"
	description = "Coffee, Irish Cream, and cognac. You will get bombed."
	taste_description = "angry and irish"
	taste_mult = 1.3
	color = "#664300"
	strength = 12

/datum/reagent/ethanol/bahama_mama
	name = "Bahama mama"
	id = "bahama_mama"
	description = "Tropical cocktail."
	taste_description = "lime and orange"
	color = "#FF7F3B"
	strength = 25

/datum/reagent/ethanol/bananahonk
	name = "Banana Mama"
	id = "bananahonk"
	description = "A drink from Clown Heaven."
	taste_description = "a bad joke"
	nutriment_factor = TRUE
	color = "#FFFF91"
	strength = 12

/datum/reagent/ethanol/barefoot
	name = "Barefoot"
	id = "barefoot"
	description = "Barefoot and pregnant"
	taste_description = "creamy berries"
	color = "#664300"
	strength = 30

/datum/reagent/ethanol/beepsky_smash
	name = "Beepsky Smash"
	id = "beepskysmash"
	description = "Deny drinking this and prepare for THE LAW."
	taste_description = "JUSTICE"
	taste_mult = 2
	reagent_state = LIQUID
	color = "#664300"
	strength = 12

/datum/reagent/ethanol/beepsky_smash/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.Stun(2)

/datum/reagent/ethanol/bilk
	name = "Bilk"
	id = "bilk"
	description = "This appears to be beer mixed with milk. Disgusting."
	taste_description = "desperation and lactate"
	color = "#895C4C"
	strength = 50
	nutriment_factor = 2

/datum/reagent/ethanol/black_russian
	name = "Black Russian"
	id = "blackrussian"
	description = "For the lactose-intolerant. Still as classy as a White Russian."
	taste_description = "bitterness"
	color = "#360000"
	strength = 35

/datum/reagent/ethanol/bloody_mary
	name = "Bloody Mary"
	id = "bloodymary"
	description = "A strange yet pleasurable mixture made of vodka, tomato and lime juice. Or at least you THINK the red stuff is tomato juice."
	taste_description = "tomatoes with a hint of lime"
	color = "#664300"
	strength = 35

/datum/reagent/ethanol/coca_wine
	name = "Coca Wine"
	id = "coca_wine"
	description = "A strange yet pleasurable mixture made of wine, and coca leaves."
	taste_description = "A sweet taste with a hint of something strange"
	color = "#7E4043" // rgb: 126, 64, 67
	strength = 55

/datum/reagent/ethanol/booger
	name = "Booger"
	id = "booger"
	description = "Ewww..."
	taste_description = "sweet 'n creamy"
	color = "#8CFF8C"
	strength = 30

/datum/reagent/ethanol/coffee/brave_bull
	name = "Brave Bull"
	id = "bravebull"
	description = "It's just as effective as Dutch-Courage!"
	taste_description = "alcoholic bravery"
	taste_mult = 1.1
	color = "#664300"
	strength = 15

/datum/reagent/ethanol/changelingsting
	name = "Changeling Sting"
	id = "changelingsting"
	description = "You take a tiny sip and feel a burning sensation..."
	taste_description = "your brain coming out your nose"
	color = "#2E6671"
	strength = 10

/datum/reagent/ethanol/martini
	name = "Classic Martini"
	id = "martini"
	description = "Vermouth with Gin. Not quite how FALSE07 enjoyed it, but still delicious."
	taste_description = "dryness and juniper"
	color = "#ffffff80"
	strength = 25


/datum/reagent/ethanol/demonsblood
	name = "Demons Blood"
	id = "demonsblood"
	description = "AHHHH!!!!"
	taste_description = "sweet tasting iron"
	taste_mult = 1.5
	color = "#820000"
	strength = 50

/datum/reagent/ethanol/devilskiss
	name = "Devils Kiss"
	id = "devilskiss"
	description = "Creepy time!"
	taste_description = "bitter iron"
	color = "#A68310"
	strength = 50

/datum/reagent/ethanol/driestmartini
	name = "Driest Martini"
	id = "driestmartini"
	description = "Only for the experienced. You think you see sand floating in the glass."
	taste_description = "a beach"
	nutriment_factor = TRUE
	color = "#2E6671"
	strength = 12

/datum/reagent/ethanol/ginfizz
	name = "Gin Fizz"
	id = "ginfizz"
	description = "Refreshingly lemony, deliciously dry."
	taste_description = "dry, tart lemons"
	color = "#ffffff80"
	strength = 30

/datum/reagent/ethanol/erikasurprise
	name = "Erika Surprise"
	id = "erikasurprise"
	description = "The surprise is, it's green!"
	taste_description = "tartness and bananas"
	color = "#2E6671"
	strength = 50

/datum/reagent/ethanol/gargle_blaster
	name = "Pan-Galactic Gargle Blaster"
	id = "gargleblaster"
	description = "Whoah, this stuff looks volatile!"
	taste_description = "your brains smashed out by a lemon wrapped around a gold brick"
	taste_mult = 5
	reagent_state = LIQUID
	color = "#664300"
	strength = 10

/datum/reagent/ethanol/gintonic
	name = "Gin and Tonic"
	id = "gintonic"
	description = "An all time classic, mild cocktail."
	taste_description = "gin, tartness and bitterness"
	color = "#ffffff80"
	strength = 50

/datum/reagent/ethanol/goldschlager
	name = "Goldschlager"
	id = "goldschlager"
	description = "100 proof cinnamon schnapps, made for alcoholic teen girls on spring break."
	taste_description = "burning cinnamon"
	taste_mult = 1.3
	color = "#ffffff80"
	strength = 50

/datum/reagent/ethanol/hippies_delight
	name = "Hippies' Delight"
	id = "hippiesdelight"
	description = "You just don't get it maaaan."
	taste_description = "giving peace a chance"
	reagent_state = LIQUID
	color = "#664300"
	strength = 50
	druggy = 50

/datum/reagent/ethanol/hooch
	name = "Hooch"
	id = "hooch"
	description = "Either someone's failure at cocktail making or attempt in alchohol production. In any case, do you really want to drink that?"
	taste_description = "pure resignation"
	color = "#664300"
	strength = 25
	toxicity = 2

/datum/reagent/ethanol/iced_beer
	name = "Iced Beer"
	id = "iced_beer"
	description = "A beer which is so cold the air around it freezes."
	taste_description = "refreshingly cold"
	color = "#E68500E6"
	strength = 50
	adj_temp = -20
	targ_temp = 270

/datum/reagent/ethanol/irishcarbomb
	name = "Irish Car Bomb"
	id = "irishcarbomb"
	description = "Mmm, tastes like chocolate cake..."
	taste_description = "delicious anger"
	color = "#2E6671"
	strength = 50

/datum/reagent/ethanol/coffee/irishcoffee
	name = "Irish Coffee"
	id = "irishcoffee"
	description = "Coffee, and alcohol. More fun than a Mimosa to drink in the morning."
	taste_description = "giving up on the day"
	color = "#664300"
	strength = 15

/datum/reagent/ethanol/irish_cream
	name = "Irish Cream"
	id = "irishcream"
	description = "Whiskey-imbued cream, what else would you expect from the Irish."
	taste_description = "creamy alcohol"
	color = "#664300"
	strength = 25

/datum/reagent/ethanol/longislandicedtea
	name = "Long Island Iced Tea"
	id = "longislandicedtea"
	description = "The liquor cabinet, brought together in a delicious mix. Intended for middle-aged alcoholic women only."
	taste_description = "a mixture of cola and alcohol"
	color = "#664300"
	strength = 12

/datum/reagent/ethanol/manhattan
	name = "Manhattan"
	id = "manhattan"
	description = "The Detective's undercover drink of choice. He never could stomach gin..."
	taste_description = "mild dryness"
	color = "#664300"
	strength = 15

/datum/reagent/ethanol/manhattan_proj
	name = "Manhattan Project"
	id = "manhattan_proj"
	description = "A scientist's drink of choice, for pondering ways to blow up the station."
	taste_description = "death, the destroyer of worlds"
	color = "#664300"
	strength = 10
	druggy = 30

/datum/reagent/ethanol/manly_dorf
	name = "The Manly Dorf"
	id = "manlydorf"
	description = "Beer and Ale, brought together in a delicious mix. Intended for true men only."
	taste_description = "hair on your chest and your chin"
	color = "#664300"
	strength = 25

/datum/reagent/ethanol/margarita
	name = "Margarita"
	id = "margarita"
	description = "On the rocks with salt on the rim. Arriba~!"
	taste_description = "dry and salty"
	color = "#8CFF8C"
	strength = 15

/datum/reagent/ethanol/mead
	name = "Mead"
	id = "mead"
	description = "A Viking's drink, though a cheap one."
	taste_description = "sweet, sweet alcohol"
	reagent_state = LIQUID
	color = "#eb9605d9"
	strength = 30
	nutriment_factor = TRUE

/datum/reagent/ethanol/moonshine
	name = "Moonshine"
	id = "moonshine"
	description = "You've really hit rock bottom now... your liver packed its bags and left last night."
	taste_description = "bitterness"
	taste_mult = 2.5
	color = "#ffffff80"
	strength = 45

/datum/reagent/ethanol/cider
	name = "Cider"
	id = "cider"
	description = "You've really just some hotshot."
	taste_description = "sweet and elegant"
	taste_mult = 2.5
	color = "#ffffff80"
	strength = 10

/datum/reagent/ethanol/neurotoxin
	name = "Neurotoxin"
	id = "neurotoxin"
	description = "A strong neurotoxin that puts the subject into a death-like state."
	taste_description = "a numbing sensation"
	reagent_state = LIQUID
	color = "#2E2E61"
	strength = 10

/datum/reagent/ethanol/neurotoxin/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.Weaken(3)
	M.add_chemical_effect(CE_PULSE, -1)

/datum/reagent/ethanol/patron
	name = "Patron"
	id = "patron"
	description = "Tequila with silver in it, a favorite of alcoholic women in the club scene."
	taste_description = "metallic and expensive"
	color = "#585840"
	strength = 30

/datum/reagent/ethanol/pwine
	name = "Poison Wine"
	id = "pwine"
	description = "Is this even wine? Toxic! Hallucinogenic! Probably consumed in boatloads by your superiors!"
	taste_description = "purified alcoholic death"
	color = "#000000"
	strength = 10
	druggy = 50
	halluci = 10

/datum/reagent/ethanol/pwine/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (dose > 30)
		M.adjustToxLoss(2 * removed)
	if (dose > 60 && ishuman(M) && prob(5))
		var/mob/living/human/H = M
		var/obj/item/organ/heart/L = H.internal_organs_by_name["heart"]
		if (L && istype(L))
			if (dose < 120)
				L.take_damage(10 * removed, FALSE)
			else
				L.take_damage(100, FALSE)

/datum/reagent/ethanol/red_mead
	name = "Red Mead"
	id = "red_mead"
	description = "The true Viking's drink! Even though it has a strange red color."
	taste_description = "sweet and salty alcohol"
	color = "#C73C00"
	strength = 30
