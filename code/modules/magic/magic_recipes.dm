
// ============================================================
// PROFESSOR SNIP'S CAULDRON-STIRRING SYLLABUS
// Bootleg potion recipes for the Llanboarwart (Wizard Boy) map.
//
// Recipes 1–5, 6: Mix-and-drink potions (locked to MAP_WIZARD_BOY).
// Recipe 2 (Welsh Instant Darkness Powder) and
// Recipe 7 (The Exploding Toad) are THROW-ACTIVATED:
//   - They produce stable intermediate reagents when mixed.
//   - Throwing the container causes the effect on impact.
// ============================================================


// ============================================================
// BASE REACTION TYPE: wizard_boy_recipe
// All map-locked reactions inherit from this.
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe
/datum/chemical_reaction/wizard_boy_recipe/can_happen(var/datum/reagents/holder)
	if (!map || map.ID != MAP_WIZARD_BOY)
		return FALSE
	return ..()


// ============================================================
// SHARED PROC: check_and_trigger_throw_reagents
// Called from throw_impact overrides below.
// Fires darkness_powder and/or toad_mixture effects at location.
// ============================================================

/obj/item/weapon/reagent_containers/proc/wizard_throw_trigger(atom/hit_atom)
	if (!reagents)
		return

	var/location = get_turf(src)

	// 2. Welsh Instant Darkness Powder → smoke cloud on impact
	if (reagents.get_reagent_amount("darkness_powder") >= 1)
		var/vol = reagents.get_reagent_amount("darkness_powder")
		reagents.remove_reagent("darkness_powder", vol)
		visible_message("<span class='warning'>The container shatters and releases a billowing cloud of absolute darkness!</span>")
		var/datum/effect/effect/system/smoke_spread/chem/S = new /datum/effect/effect/system/smoke_spread/chem
		S.attach(location)
		S.set_up(reagents, vol * 0.4, FALSE, location)
		playsound(location, 'sound/effects/smoke.ogg', 75, TRUE, -3)
		spawn(0)
			S.start()

	// 7. The Exploding Toad → explosion on impact
	if (reagents.get_reagent_amount("toad_mixture") >= 1)
		var/vol = reagents.get_reagent_amount("toad_mixture")
		reagents.remove_reagent("toad_mixture", vol)
		visible_message("<span class='danger'>The container shatters and detonates with a thunderous BOOM!</span>")
		playsound(location, 'sound/effects/explosion1.ogg', 100, FALSE, -3)
		spawn(5)
			explosion(location, max(0, round(vol/30) - 1), round(vol/20), round(vol/10), round(vol/5))


// ============================================================
// THROW_IMPACT HOOKS: glass beaker and clay containers
// ============================================================

// Glass beakers, vials, buckets, etc.
/obj/item/weapon/reagent_containers/glass/throw_impact(atom/hit_atom, var/speed)
	..(hit_atom, speed)
	wizard_throw_trigger(hit_atom)

// Clay pots, jugs, bowls
/obj/item/weapon/reagent_containers/food/drinks/clay/throw_impact(atom/hit_atom, var/speed)
	..(hit_atom, speed)
	wizard_throw_trigger(hit_atom)

// Drink bottles (glass)
/obj/item/weapon/reagent_containers/food/drinks/bottle/throw_impact(atom/hit_atom, var/speed)
	..(hit_atom, speed)
	wizard_throw_trigger(hit_atom)


// ============================================================
// REAGENT DEFINITIONS
// ============================================================

// ---- 1. Skele-Bones Broth ----
// A highly effective painkiller and bone-healer.
// Tastes like chalk and despair.

/datum/reagent/skele_bones
	name = "Skele-Bones Broth"
	id = "skele_bones"
	description = "A chalky, slightly sweet concoction that smells faintly of warm milk and acetaminophen. Tastes exactly as bad as it sounds. Knits bones back together."
	taste_description = "chalk, despair, and a hint of sugar"
	reagent_state = LIQUID
	color = "#F0EAD6"
	metabolism = REM * 0.1
	overdose = 40
	scannable = TRUE

/datum/reagent/skele_bones/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 60)
	M.adjustBruteLoss(-1.5 * removed)
	M.SetParalysis(0)
	M.SetWeakened(0)

/datum/reagent/skele_bones/overdose(var/mob/living/human/M, var/alien)
	..()
	M.hallucination = max(M.hallucination, 2)
	M.make_jittery(5)


// ---- 2. Welsh Instant Darkness Powder ----
// Stable when mixed. Produces a massive smoke cloud when thrown.
// (Inert in a beaker — must be thrown to activate.)

/datum/reagent/darkness_powder
	name = "Welsh Instant Darkness Powder"
	id = "darkness_powder"
	description = "A dense black powder mixture that smells of sulphur and Swansea. Absolutely nothing happens if you drink it except a mildly unpleasant taste. Throw the container at something for the intended effect."
	taste_description = "sulphur, soot, and a distant rugby stadium"
	reagent_state = LIQUID
	color = "#1A1A2E"
	metabolism = REM * 0.5
	scannable = TRUE

/datum/reagent/darkness_powder/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	// Drinking it is just unpleasant, no actual effect.
	M.make_dizzy(3)
	if (prob(20))
		to_chat(M, "<span class='warning'>Your mouth fills with the taste of coal dust and disappointing evenings.</span>")


// ---- 7. Toad Mixture (The Exploding Toad) ----
// Stable when mixed in a beaker (unlike raw water+potassium).
// Detonates violently when the container is thrown and shatters.

/datum/reagent/toad_mixture
	name = "Toad Mixture"
	id = "toad_mixture"
	description = "A suspiciously stable silvery liquid that smells faintly metallic. Anyone who has studied basic alchemy would immediately flee. Do NOT drink this. Do NOT put it down gently."
	taste_description = "metallic doom and the smell of singed eyebrows"
	reagent_state = LIQUID
	color = "#C0C0C0"
	metabolism = REM * 0.5
	scannable = TRUE

/datum/reagent/toad_mixture/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	// If somehow drunk, it's immediately and catastrophically bad.
	M.adjustBruteLoss(15 * removed)
	M.adjustBurnLoss(10 * removed)
	to_chat(M, "<span class='danger'>Something reacts violently inside you. You made a terrible mistake.</span>")
	M.emote("scream")


// ---- 3. Liquid Gamble ----

/datum/reagent/liquid_gamble
	name = "Liquid Gamble"
	id = "liquid_gamble"
	description = "A shimmering golden liquid that smells of anxiety. Banned before exams. Side effects include running at terrifying speed while being chased by imaginary spiders."
	taste_description = "burning golden lightning and existential dread"
	reagent_state = LIQUID
	color = "#FFD700"
	metabolism = REM * 0.25
	overdose = 25
	scannable = TRUE

/datum/reagent/liquid_gamble/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.add_chemical_effect(CE_SPEEDBOOST, 4)
	M.add_chemical_effect(CE_PAINKILLER, 100)
	M.SetParalysis(0)
	M.SetStunned(0)
	M.SetWeakened(0)
	M.hallucination = max(M.hallucination, 5)
	M.make_jittery(10)
	M.make_dizzy(5)

/datum/reagent/liquid_gamble/overdose(var/mob/living/human/M, var/alien)
	..()
	M.hallucination = max(M.hallucination, 10)
	M.add_chemical_effect(CE_PULSE, 4)
	M.make_jittery(20)


// ---- 4. Heart-Throb Syrup ----

/datum/reagent/heartthrob_syrup
	name = "Heart-Throb Syrup"
	id = "heartthrob_syrup"
	description = "A sweet-smelling rose-red syrup. Rumoured to induce love. Actually induces unconsciousness. Great for kidnapping rival house members."
	taste_description = "roses, wine, and sweet oblivion"
	reagent_state = LIQUID
	color = "#C0392B"
	metabolism = REM * 0.3
	overdose = 30
	scannable = TRUE

/datum/reagent/heartthrob_syrup/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.drowsyness += 6 * removed
	if (M.drowsyness > 40)
		M.sleeping = max(M.sleeping, 80)


// ---- 5. Polysoup Paste ----

/datum/reagent/polysoup_paste
	name = "Polysoup Paste"
	id = "polysoup_paste"
	description = "A vile grey-green paste that smells of ammonia and old meat. Does not change your appearance. Does cause massive toxin damage, vomiting, and leaves a terrible slippery mess on the floor."
	taste_description = "ammonia, regret, and something biological"
	reagent_state = LIQUID
	color = "#5D6B3A"
	metabolism = REM * 0.4
	overdose = 15
	scannable = TRUE

/datum/reagent/polysoup_paste/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(4 * removed)
	if (prob(40))
		M.emote("vomit")
	M.make_dizzy(5)
	M.make_jittery(3)

/datum/reagent/polysoup_paste/affect_touch(var/mob/living/human/M, var/alien, var/removed)
	var/turf/T = get_turf(M)
	if (T)
		new /obj/effect/decal/cleanable/vomit(T)


// ---- 6. Pep-Up Juice ----

/datum/reagent/pepup_juice
	name = "Pep-Up Juice"
	id = "pepup_juice"
	description = "A scorched orange-red liquid that smells like a bonfire inside a coffee shop. Warms you up instantly. Also burns your throat out."
	taste_description = "fire, coffee, and poor life choices"
	reagent_state = LIQUID
	color = "#E25822"
	metabolism = REM * 0.3
	overdose = 30
	scannable = TRUE

/datum/reagent/pepup_juice/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.bodytemperature += 15 * removed
	M.heal_organ_damage(0, 10 * removed)
	M.add_chemical_effect(CE_PAINKILLER, 10)
	if (prob(30))
		M.emote("cough")
	if (M.bodytemperature > 360)
		M.adjustBurnLoss(1 * removed)


// ============================================================
// CHEMICAL REACTION DEFINITIONS
// ============================================================

// ============================================================
// 1. SKELE-BONES BROTH
//    2u Milk + 2u Paracetamol + 1u Sugar → 5u skele_bones
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/skele_bones_broth
	name = "Skele-Bones Broth"
	id = "skele_bones_broth"
	result = "skele_bones"
	required_reagents = list("milk" = 2, "paracetamol" = 2, "sugar" = 1)
	result_amount = 5
	mix_message = "The mixture foams with a chalky white froth and smells powerfully of warm milk."
	reaction_sound = 'sound/effects/bubbles.ogg'


// ============================================================
// 2. WELSH INSTANT DARKNESS POWDER
//    1u Potassium + 1u Phosphorus + 1u Sugar → 3u darkness_powder
//    (Stable in beaker; smoke cloud releases on throw-impact)
//
//    IMPORTANT: This reaction MUST have a higher priority than
//    the base chemsmoke reaction so it fires instead on WIZARD_BOY.
//    The base chemsmoke fires on ALL maps; this one only fires on
//    WIZARD_BOY and produces a stable throwable instead.
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/darkness_powder
	name = "Welsh Instant Darkness Powder"
	id = "darkness_powder"
	result = "darkness_powder"
	required_reagents = list("potassium" = 1, "sugar" = 1, "phosphorus" = 1)
	result_amount = 3
	mix_message = "The mixture fizzes ominously and settles into a dense, oily black powder. You could swear it absorbed some of the ambient light."
	reaction_sound = 'sound/effects/bubbles.ogg'


// ============================================================
// 3. LIQUID GAMBLE
//    2u Adrenaline + 1u Mindbreaker + 2u Goldschlager → 5u liquid_gamble
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/liquid_gamble
	name = "Liquid Gamble"
	id = "liquid_gamble"
	result = "liquid_gamble"
	required_reagents = list("adrenaline" = 2, "mindbreaker" = 1, "goldschlager" = 2)
	result_amount = 5
	mix_message = "The mixture crackles with a faint golden shimmer and smells vaguely of anxiety and expensive cologne."
	reaction_sound = 'sound/effects/bubbles.ogg'
	log_is_important = TRUE


// ============================================================
// 4. HEART-THROB SYRUP
//    1u Chloral Hydrate + 1u Sugar + 1u Wine → 3u heartthrob_syrup
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/heartthrob_syrup
	name = "Heart-Throb Syrup"
	id = "heartthrob_syrup"
	result = "heartthrob_syrup"
	required_reagents = list("chloralhydrate" = 1, "sugar" = 1, "wine" = 1)
	result_amount = 3
	mix_message = "The mixture turns a deep rose-red and smells sweetly of wine and something else you can't quite place."
	reaction_sound = 'sound/effects/bubbles.ogg'
	log_is_important = TRUE


// ============================================================
// 5. POLYSOUP PASTE
//    1u Blood + 1u Ammonia + 1u Protein → 3u polysoup_paste
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/polysoup_paste
	name = "Polysoup Paste"
	id = "polysoup_paste"
	result = "polysoup_paste"
	required_reagents = list("blood" = 1, "ammonia" = 1, "protein" = 1)
	result_amount = 3
	mix_message = "The mixture lets out a revolting belch of steam and turns a horrible grey-green colour. It smells exactly as bad as it looks."
	reaction_sound = 'sound/effects/bubbles.ogg'
	log_is_important = TRUE


// ============================================================
// 6. PEP-UP JUICE
//    3u Coffee + 1u Condensed Capsaicin + 1u Ethanol → 5u pepup_juice
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/pepup_juice
	name = "Pep-Up Juice"
	id = "pepup_juice"
	result = "pepup_juice"
	required_reagents = list("coffee" = 3, "condensedcapsaicin" = 1, "ethanol" = 1)
	result_amount = 5
	mix_message = "The mixture hisses aggressively and turns a scorched orange-red. You can smell the heat from here."
	reaction_sound = 'sound/effects/bubbles.ogg'


// ============================================================
// 7. THE EXPLODING TOAD
//    2u Water + 2u Potassium → 4u toad_mixture
//    (Stable in beaker; detonates on throw-impact)
//
//    IMPORTANT: On WIZARD_BOY, this fires INSTEAD of the normal
//    explosion_potassium reaction, producing a safe intermediate
//    that only explodes when physically thrown.
// ============================================================

/datum/chemical_reaction/wizard_boy_recipe/toad_mixture
	name = "Toad Mixture"
	id = "toad_mixture"
	result = "toad_mixture"
	required_reagents = list("water" = 2, "potassium" = 2)
	result_amount = 4
	mix_message = "The mixture hisses softly and turns an eerie metallic silver. Professor Snip's voice echoes in your head: 'Do NOT put that down on my desk.'"
	reaction_sound = 'sound/effects/bubbles.ogg'
	log_is_important = TRUE
