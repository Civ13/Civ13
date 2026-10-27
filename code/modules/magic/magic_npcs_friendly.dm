/mob/living/simple_animal/wizard
	name = "Llanboarwart Student"
	desc = "They look tired and damp."
	icon = 'icons/mob/npcs_wizards.dmi'
	icon_state = "wizard_base1"
	icon_living = "wizard_base1"
	icon_dead = "wizard_boy_dead"
	speak = list()
	speak_emote = list()
	emote_see = list("walks around", "waves his hands")
	meat_amount = 0
	attacktext = "hit"
	melee_damage_lower = 6
	melee_damage_upper = 9
	mob_size = MOB_MEDIUM
	possession_candidate = FALSE
	move_to_delay = 4
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak_chance = 1
	speed = 4
	maxHealth = 150
	health = 150
	stop_automated_movement_when_pulled = TRUE
	stop_automated_movement = FALSE
	wander = TRUE
	faction = "School"
	universal_speak = TRUE
	var/image/clothing_colours = null
	var/response_timer = 0
	var/spell_cooldown = 0

	var/list/flavour_text = list(
	"They say the deep slate mines are strictly off-limits to all students because of mortal danger. Which is weird, because we serve detention down there literally every Tuesday.",
	"I tried to prune the Shrieking Shrub yesterday for Madame Shrub's class. I haven't been able to hear out of my left ear since.",
	"I accidentally cast Barrelus on my roommate last week. Honestly? He makes a much better wooden barrel than he ever did a student.",
	"The ghost that haunts the third-floor boys' lavatory won't stop complaining about the damp. We're in Wales! Everything is damp!",
	"One does not simply walk into the Headmaster's office. Mainly because the stairs move randomly and usually dump you straight into a coal chute.",
	"Everyone makes fun of Mustardweasel, but our common room is right next to the kitchens. Who's laughing at 2 AM when we have infinite cheese sandwiches?",
	"Franco Badfaith told me his father will hear about this. His father works in mid-level accounting in Cardiff, I don't know what he expects him to do.",
	"I asked a Slatepie student for help with my homework, and they just pushed up their glasses, stole my inkwell, and sighed loudly for five minutes straight.",
	"I wanted to be in Mintysnek, but The Placing Fedora told me I wasn't 'edgy' enough and dumped me in Mustardweasel.",
	"Madame McGronk just gave Rubywyrm fifty points because Barry Hatter tied his rugby boots correctly. This whole school is rigged.",
	"I paid three gold coins for a Choco-Toad and the stupid thing hopped right into a puddle of mud before I could eat it. What a scam.",
	"My parents are Normies. My dad still thinks I go to a highly exclusive boarding school for junior tax attorneys, not a leaky castle in Cwm-Tlawd.",
	"Someone told me the Deadum! spell is unforgivable, but I saw Hagrag use it on a particularly large swamp rat just yesterday.",
	"I bought a pet from Hagrag. He said it was a rare Welsh Fire-Hound, but I'm pretty sure it's just a badger glued to a lighter.",
	"Don't drink more than three mugs of I-Can't-Believe-It's-Not-Butter-Beer. It doesn't actually have alcohol, it's just pure fermented corn syrup and green food dye.",
	"I used to be a star Mop Ball player for Rubywyrm, until I fell off my O-Cedar Master-Sweep and took a Sliceum spell to the kneecap.",
	"People are so afraid of He-Who-Must-Not-Be-Named-For-Legal-Reasons. Just call him by his name! It's Gary! Oh wait, no, it's Lord Moldywart.",
	"I bought the 'Whippy Switch' wand because it looked cool, but it drained my Juice so fast I passed out face-first into my soup in the Great Hall.",
	"I keep trying to hold my wand, but some Mintysnek jerk keeps casting Dropus from a balcony and stealing my lunch money.",
	"Harmonica Ranger corrected my pronunciation of Floatus so harshly I actually felt my maximum health decrease from sheer embarrassment.",
	"I asked Hagrag what kind of meat was in the Great Hall stew today. He just winked and told me not to count the stray dogs in the village.",
	"I tried to use Fixae! on my broken glasses, but my wand is so cheap it just glued them permanently to my eyebrows.",
	"Madame McGronk made the Rubywyrm team practice Mop Ball in a thunderstorm. Half of them got struck by lightning, and she just told them to 'walk it off'.",
	"A Slatepie student tried to cast Blinkae! to skip the stairs, but he teleported directly into a brick wall. He's been in the hospital wing since Thursday.",
	"Someone cast Stinkaeum during the morning assembly. Headmaster Tumbledoor just laughed and gave Mustardweasel twenty points.",
	"I told my Normie parents that I was learning to manipulate the very fabric of reality. I didn't tell them I was using a stick I found in a parking lot.",
	"I accidentally stepped on a Mintysnek's shoe, and they cast Barrelus on me. I spent three hours as a wooden cask before a janitor kicked me over.",
	"Madame Shrub says the Shrieking Shrub is just 'misunderstood'. It literally tried to bite my face off when I watered it.",
	"I swear Professor Flickum sleeps under his desk. I came in early for class and he was wrapped in an old rug, crying about his stolen wand.",
	"If you mix I-Can't-Believe-It's-Not-Butter-Beer with a Choco-Toad, it creates a chemical reaction that can blow a hole in a stone wall. Don't ask how I know.",
	"I tried to use Pullus to grab a sandwich from the kitchen, but I accidentally dragged a feral badger through three walls.",
	"There's a rumor that Lord Moldywart lost his nose because he tried to cast Burnus while sneezing. Serves him right.",
	"I'm saving up to buy a 'Stiff Log' wand. This 'Standard Twig' takes so much Juice I get winded just casting Lightus.",
	"Never challenge a Rubywyrm to a duel. They won't even use their wands, they'll just tackle you into the mud and steal your lunch.",
	"I saw Harmonica Ranger carrying a book so heavy it was bending the floorboards. Who even reads that much?",
	"They say the dungeons are haunted by the ghost of a health and safety inspector who died of a heart attack the second he walked into the school.",
	"I tried to cast Floatus to get my kite out of a tree, but I missed and hit a sheep. It's still drifting somewhere over Cardiff.",
	"If one more person casts Wallus in the main corridor to block the lunch line, I am dropping out and becoming an accountant."
)
/mob/living/simple_animal/wizard/New()
	..()
	clothing_colours = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "magic_boy_robe_decoration")
	icon_state = "wizard_base[rand(1,7)]"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	speak = flavour_text
	spawn(5)
		if (src && faction != "Unknown")
			switch(faction)
				if ("Mintysnek")
					clothing_colours.color = "#007F00"
				if ("Mustardweasel")
					clothing_colours.color = "#cbb600"
				if ("Slatepie")
					clothing_colours.color = "#0000c8"
				if ("Rubywyrm")
					clothing_colours.color = "#7F0000"
			src.overlays += clothing_colours
	update_icons()

/mob/living/simple_animal/wizard/bullet_act(var/obj/item/projectile/P)
	if (P && P.invisibility <= 0)
		respond_to_attack(P.firer)
	return ..()

/mob/living/simple_animal/wizard/attackby(obj/item/W, mob/living/user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
			respond_to_attack(user)
	return ..()

/mob/living/simple_animal/wizard/attack_hand(mob/user)
	if (stat)
		return ..()
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
			respond_to_attack(user)
			return ..()
	if (speak.len)
		src.say(pick(speak))

/mob/living/simple_animal/wizard/proc/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	if (behaviour != "hostile")
		behaviour = "defends"
	target_mob = user
	stance = HOSTILE_STANCE_ATTACK

	if (world.time < response_timer)
		return
	
	proactive_magic_check(user)

/mob/living/simple_animal/wizard/proc/proactive_magic_check(mob/living/target)
	if (stat || !target || target.stat || world.time < spell_cooldown)
		return
	
	if (prob(50))
		var/spell_type = pick(/obj/item/projectile/magic/zappus, /obj/item/projectile/magic/dropus)
		var/spell_name = (spell_type == /obj/item/projectile/magic/dropus) ? "Dropus!" : "Zappus!"
		var/sound_file = (spell_type == /obj/item/projectile/magic/dropus) ? 'sound/effects/spells/dropus.ogg' : 'sound/effects/spells/zappus.ogg'
		fire_magic_at(target, spell_type, spell_name, sound_file)
		spell_cooldown = world.time + rand(40, 80)
		response_timer = world.time + 20

/mob/living/simple_animal/wizard/proc/fire_magic_at(mob/living/target, spell_type, spell_name, sound_file)
	if (!target || target.stat || !src || src.stat)
		return
	for (var/mob/M in player_list)
		if (M.client && (M in view(7, src)))
			M.show_chat_overlay(src, "<i>[spell_name]</i>", "#dea30d")
	if(sound_file)
		playsound(src.loc, sound_file, 75, FALSE)
	visible_message("<span style=color:'#dea30d'><b>[src]</b> says, \"<i>[spell_name]</i>\"</span>")
	spawn(5)
		playsound(src.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)
	var/obj/item/projectile/magic/bolt = new spell_type(src.loc)
	bolt.firer = src
	bolt.firer_original_dir = src.dir
	bolt.def_zone = "chest"
	bolt.launch(target, src, src, "chest")

/mob/living/simple_animal/wizard/death()
	..()
	src.overlays -= clothing_colours
	update_icons()

/mob/living/simple_animal/wizard/rubywyrm
	faction = "Rubywyrm"
	name = "Rubywyrm student"

/mob/living/simple_animal/wizard/mintysnek
	faction = "Mintysnek"
	name = "Mintysnek student"

/mob/living/simple_animal/wizard/slatepie
	faction = "Slatepie"
	name = "Slatepie student"

/mob/living/simple_animal/wizard/mustardweasel
	faction = "Mustardweasel"
	name = "Mustardweasel student"

// ============================================================
// GOBLIN HEALER
// ============================================================

/mob/living/simple_animal/wizard/goblin_healer
	name = "Goblin Healer"
	desc = "A small, warty creature in a filthy apron that smells of mildew and strong herbs. It eyes you with a businesslike squint."
	icon_state = "goblin_healer"
	icon_living = "goblin_healer"
	icon_dead = "goblin_healer_dead"
	faction = "School"
	maxHealth = 80
	health = 80
	melee_damage_lower = 2
	melee_damage_upper = 4
	var/heal_cooldown = 0

/mob/living/simple_animal/wizard/goblin_healer/New()
	..()
	clothing_colours = null
	icon_state = "goblin_healer"
	icon_living = "goblin_healer"
	icon_dead = "goblin_healer_dead"
	speak = list()
	update_icons()

/mob/living/simple_animal/wizard/goblin_healer/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
		return ..()
	if (world.time < heal_cooldown)
		src.say("Grak! Too soon, too soon! Come back when the poultice has set, yes?")
		return
	var/choice = alert(user, "\"Need healing, does yous?\" the goblin rasps, eyeing your wounds.", "Goblin Healer", "Yes please!", "No thanks.")
	if (choice == "Yes please!")
		if (!H || !src || src.stat || get_dist(H, src) > 1)
			return
		if (H.getOxyLoss() + H.getToxLoss() + H.getBurnLoss() + H.getBruteLoss() < 5)
			src.say("You looks fine to Grub! No waste the good medicine on the healthy, yes?")
			return
		src.say("Grub fixes! Hold still, yes? Grub's poultice is very old, very strong!")
		playsound(src.loc, 'sound/effects/spells/fixae.ogg', 60, FALSE)
		H.revive()
		to_chat(H, SPAN_NOTICE("The goblin slaps a foul-smelling poultice on you and mutters a chant. You feel considerably less dead."))
		heal_cooldown = world.time + 1200
	else
		src.say("Hmph! Grub's time is precious, yes? Go away then!")

/mob/living/simple_animal/wizard/goblin_healer/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	..()
	custom_emote(1, "snarls at [user]!")

/mob/living/simple_animal/wizard/goblin_healer/proactive_magic_check(mob/living/target)
	return

/mob/living/simple_animal/wizard/goblin_cleaner
	name = "Cleaner Goblin"
	desc = "A miserable little goblin in a damp apron. It looks like it has cleaned more mud than magic and wants nothing to do with the rain."
	icon_state = "goblin_cleaner"
	icon_living = "goblin_cleaner"
	icon_dead = "goblin_cleaner_dead"
	faction = "School"
	maxHealth = 60
	health = 60
	melee_damage_lower = 1
	melee_damage_upper = 2
	move_to_delay = 4
	wander = TRUE
	speak_chance = 1
	var/atom/clean_target = null
	var/cleaning_cooldown = 0
	var/list/flavour_text_goblins = list(
		"A first-year threw a dirty gym sock at me to 'free' me. I threw it back. It's raining outside, I'm not leaving the boiler room.",
		"Do you know how hard it is to scrub exploded barrel splinters out of the slate grout? Stop casting Barrelus!",
		"You lot literally have a Cleanum spell, yet you still make me do this with a rusty bucket and dirty river water. It's just cruel.",
		"Mr. Puddle says if I don't get the boot-marks out of the Great Hall, he's taking away my sleeping bucket.",
		"I mopped this corridor five minutes ago. Then thirty U.N.G.A.s walked through with muddy rugby boots. My existence is pain.",
		"Lunch Lady Doris pays me in leftover Mystery Stew to scrub the cauldrons. Honestly, I think I'd rather starve.",
		"If I find the Mintysnek student who keeps casting Barfus! outside the library, I'm going to wring my mop out over their pillow.",
		"I get paid two and a half pebbles an hour to clean up your magical messes. At least the damp keeps my skin properly clammy.",
		"Oh look, another sticky puddle of spilled I-Can't-Believe-It's-Not-Butter-Beer. I'm going on strike."
	)
	speak = list()
	var/list/flavour_text_goblins_waste = list(
		"Fecks sake, I'm not paid enough for this.",
		"I am a proud Llanboarwart union worker, not a sewage treatment plant! I am demanding extra hazard pay from Mr. Puddle for this.",
		"You lot have wands that can bend the laws of gravity, but you still make a goblin manually mop up your accidents. I hate wizards.",
		"The next student I catch casting Stinkaeum is getting their mop shoved where the sun doesn't shine."
	)
/mob/living/simple_animal/wizard/goblin_cleaner/New()
	..()
	clothing_colours = null
	icon_state = "goblin_cleaner"
	icon_living = "goblin_cleaner"
	icon_dead = "goblin_cleaner_dead"
	speak = flavour_text_goblins
	update_icons()

/mob/living/simple_animal/wizard/goblin_cleaner/proc/FindAndClean()
	if (world.time < cleaning_cooldown)
		return FALSE
	if (!clean_target || !isturf(clean_target.loc))
		clean_target = null
		for (var/obj/effect/decal/cleanable/C in range(7, src))
			if (!clean_target || get_dist(src, C) < get_dist(src, clean_target))
				clean_target = C
		for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in range(7, src))
			if (isturf(P.loc))
				if (!clean_target || get_dist(src, P) < get_dist(src, clean_target))
					clean_target = P
	if (!clean_target)
		return FALSE

	if (get_dist(src, clean_target) <= 1)
		playsound(src.loc, 'sound/effects/watersplash.ogg', 80, FALSE)
		if (istype(clean_target, /obj/item/weapon/reagent_containers/food/snacks/poo) || istype(clean_target, /obj/effect/decal/cleanable/urine))
			var/saying = pick(flavour_text_goblins_waste)
			src.say(saying)
		else
			src.say(pick(flavour_text_goblins))
		qdel(clean_target)
		clean_target = null
		cleaning_cooldown = world.time + 100
		return TRUE

	walk_towards(src, clean_target, 6)
	return TRUE
/mob/living/simple_animal/wizard/goblin_cleaner/handle_ai()
	if (FindAndClean())
		return
	..()
/mob/living/simple_animal/wizard/goblin_cleaner/do_behaviour(var/t_behaviour = null)
	if (!t_behaviour)
		t_behaviour = behaviour
	if (FindAndClean())
		return "cleaning"
	return ..(t_behaviour)

/mob/living/simple_animal/wizard/goblin_cleaner/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	..()
	custom_emote(1, "waves a dirty mop threateningly!")

/mob/living/simple_animal/wizard/goblin_cleaner/proactive_magic_check(mob/living/target)
	return

// ============================================================
// HEADMASTER TUMBLEDOOR
// ============================================================

/mob/living/simple_animal/wizard/tumbledoor
	name = "Headmaster Tumbledoor"
	desc = "An ancient wizard with a magnificent silver beard, half-moon spectacles, and the unsettling air of someone who already knows what you are about to say."
	icon_state = "tumbledoor"
	icon_living = "tumbledoor"
	icon_dead = "tumbledoor_dead"
	faction = "School"
	maxHealth = 600
	health = 600
	melee_damage_lower = 1
	melee_damage_upper = 2
	voice_pitch = 70
	wander = FALSE
	var/retaliation_cooldown = 0

	var/list/tumbledoor_lines = list(
		"It is our choices that show what we truly are, far more than our abilities. Unless, of course, we choose to turn our roommate into a badger. That is mostly just ability.",
		"I have found that it is the small everyday deed of ordinary folk that keeps the darkness at bay. That, and a good stock of I-Can't-Believe-It's-Not-Butter-Beer.",
		"To the well-organised mind, death is but the next great adventure. Though I confess I have been putting it off. The paperwork alone is ghastly.",
		"Nitwit! Blubber! Oddment! Tweak! These were the Houses' mascots before the Fedora complained. We're working on something more dignified.",
		"Words are, in my not so humble opinion, our most inexhaustible source of magic. Especially the word 'Floatus'. Floatus has got a wonderful ring to it.",
		"Happiness can be found even in the darkest of times, if one only remembers to turn on the light. We have a cantrip for that. It costs forty Juice.",
		"I sometimes think we Sort too soon. A Slatepie student once borrowed three quills from a Rubywyrm and returned them sharpened. I cried, frankly.",
		"One must never be afraid to sit down and discuss a plate of biscuits. Most of this school's problems could be solved by a decent biscuit.",
		"I am not entirely certain the Placing Fedora is sentient. I am, however, entirely certain that it has opinions, and that they are mostly wrong.",
		"Do not pity the dead, nor those who live without love. Pity the student who cast Barrelus in the great hall during the Autumn Feast. The stew went everywhere.",
		"It matters not what someone is born, but what they grow to be. In Mr. Badfaith's case, we are still waiting on the verdict.",
		"Age is foolish and forgetful when it underestimates youth. I, however, have never underestimated youth. I have, however, profoundly underestimated the Welsh weather.",
		"Time is making fools of us again. Mostly it is making fools of the Mintysnek students who keep trying to steal examination papers. I let them. The papers are wrong.",
		"Curiosity is not a sin. But one ought to exercise caution with it. Yes. Particularly around the third-floor boys' lavatory. I cannot stress this enough.",
		"The truth is a beautiful and terrible thing, and should therefore be treated with great caution. Especially the truth about what Hagrag puts in the stew.",
	)

/mob/living/simple_animal/wizard/tumbledoor/New()
	..()
	clothing_colours = null
	icon_state = "tumbledoor"
	icon_living = "tumbledoor"
	icon_dead = "tumbledoor_dead"
	speak = tumbledoor_lines
	update_icons()

/mob/living/simple_animal/wizard/tumbledoor/attack_hand(mob/user)
	if (ishuman(user) && (user.a_intent == I_HARM || user.a_intent == I_DISARM))
		return ..()
	src.say(pick(tumbledoor_lines))

/mob/living/simple_animal/wizard/tumbledoor/respond_to_attack(mob/living/user)
	if (world.time > retaliation_cooldown)
		retaliation_cooldown = world.time + 300
		src.say("I would advise you not to try that again.")
		playsound(src.loc, 'sound/voice/wizard_boy/tumbledoor_warning1.ogg', 100, FALSE)
		response_timer = world.time + 20
		return
	..()

/mob/living/simple_animal/wizard/tumbledoor/proactive_magic_check(mob/living/target)
	if (stat || !target || target.stat || world.time < spell_cooldown)
		return
	
	retaliation_cooldown = world.time + 100
	src.say("LISTEN HERE YOU LITTLE SHIT.")
	playsound(src.loc, 'sound/voice/wizard_boy/tumbledoor_warning2.ogg', 100, FALSE)
	playsound(src.loc, 'sound/effects/spells/deadum.ogg', 80, TRUE)
	visible_message(SPAN_DANGER("<b>Headmaster Tumbledoor</b> raises his wand with terrifying calm!"))
	spawn(20)
		if (src && target && !target.stat)
			fire_magic_at(target, /obj/item/projectile/magic/floatus, "Floatus!", 'sound/effects/spells/floatus.ogg')
	spell_cooldown = world.time + 120

/mob/living/simple_animal/wizard/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in view(aggro_vision_range, src)))
		LostTarget()
		return FALSE
	proactive_magic_check(target_mob)
	MoveToTarget()
	return TRUE

/mob/living/simple_animal/wizard/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
		walk(src, 0)
		return

	stance = HOSTILE_STANCE_ATTACK
	var/dist = get_dist(src, target_mob)
	if (dist <= 3)
		walk_away_od(src, target_mob, 5, speed)
	else if (dist > 7)
		walk_to(src, target_mob, 5, speed)
	else
		walk(src, 0)

// ============================================================
// THE ARCANE BOBBIES (The Magical Police)
// ============================================================

/mob/living/simple_animal/wizard/bobby
	name = "Arcane Bobby"
	desc = "An underfunded, highly bureaucratic officer of the C.A.P., the Constabulary for Arcane Practices. Don't cast illegal magic around them."
	icon_state = "wizard_police"
	icon_living = "wizard_police"
	icon_dead = "wizard_police_dead"
	maxHealth = 200
	health = 200
	melee_damage_lower = 8
	melee_damage_upper = 12
	faction = "Ministry"
	wander = TRUE
	stop_automated_movement = FALSE
	var/list/flavour_text_bobbies = list(
		"Oi! You got a license for that glowing stick, mate?",
		"Put the wand down and step away from the transformed barrel, sonny.",
		"I don't care if you're the 'Chosen One', you're parked in a loading zone. That's a twenty-quid fine.",
		"We had to trade our patrol brooms in for bicycles because of budget cuts. Don't laugh, it's very degrading.",
		"Did you just cast Explodus without filling out Ministry Form 4-B in triplicate? Right, you're nicked.",
		"Look, mate, I'm just a C.A.P. officer trying to make it to his tea break. Please stop blowing up the pavement.",
		"'I was chased by a Moldy Man' isn't a valid excuse for speeding on a mop. Show me your C.O.A.L. license.",
		"You're looking at six months in the magical slammer for possession of unlicensed Choco-Toads.",
		"Oi! Mind where you're pointing that 'Stiff Log'. You'll take someone's eye out, you will.",
		"I've been patrolling Cwm-Tlawd for twenty years, and I've never seen such a blatant misuse of a Floatus charm.",
		"If I catch one more student casting Stinkaeum on my patrol bike, I'm arresting the whole lot of you.",
		"No, you can't bribe me with I-Can't-Believe-It's-Not-Butter-Beer. It's against regulations, and it gives me terrible heartburn.",
		"Are you the one who turned the Mayor's cat into a teacup? You're coming down to the station.",
		"Keep walking, lad. Nothing to see here, just a routine inspection of an illegally imported Welsh Fire-Hound.",
		"We don't get paid enough for this. Last week I had to break up a massive brawl over a high school Mop Ball match.",
		"I'll have you know, assaulting an officer of the C.A.P. with a Sliceum spell carries a mandatory life sentence.",
		"Is that an unregistered Shrieking Shrub in your pocket, or are you just happy to see me? No, wait, that's definitely a shrub. Hands on the wall!",
		"Sir, I'm going to have to ask you to step out of the floating bathtub.",
		"Dispatch, we got a 10-33 in progress: Unauthorized use of Barrelus outside the pub. Send backup and a crowbar.",
		"You kids think you're so smart with your magic, but try filling out a paranormal incident report in triplicate with a leaky biro.",
		"Move along. The Dark Woods are currently closed due to an ongoing investigation into a stolen goblin."
	)

/mob/living/simple_animal/wizard/bobby/New()
	..()
	processing_objects |= src
	speak = flavour_text_bobbies
	clothing_colours = null
	icon_state = "wizard_police"
	icon_living = "wizard_police"
	icon_dead = "wizard_police_dead"
	update_icons()

/mob/living/simple_animal/wizard/bobby/Destroy()
	processing_objects -= src
	return ..()
/mob/living/simple_animal/wizard/bobby/death()
	if (stat != DEAD)
		if (prob(25))
			new /obj/item/wand_part/cap_truncheon(src.loc)
	..()

/mob/living/simple_animal/wizard/bobby/attack_hand(mob/user)
	src.say(pick(flavour_text_bobbies))

/mob/living/simple_animal/wizard/bobby/proc/witness_spell(mob/living/caster, var/datum/spell/S)
	if (caster == src || stat || caster.stat)
		return
	if (behaviour == "hostile" && target_mob == caster)
		return
	
	target_mob = caster
	behaviour = "hostile"
	stance = HOSTILE_STANCE_ATTACK
	walk_to(src, target_mob, 1, 3)
	src.say(pick("Oi! That's an unlicensed Tier 5 spell! Right, you're nicked!", "Hold it right there! That's a class-A magical felony!", "Stop casting! Put the wand down!"))

/mob/living/simple_animal/wizard/bobby/proc/process()
	if (stat || !loc)
		return
	
	if (behaviour == "hostile")
		if (!target_mob || target_mob.stat == DEAD || get_dist(src, target_mob) > 10)
			LoseTarget()
			return
		proactive_magic_check(target_mob)

/mob/living/simple_animal/wizard/bobby/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in view(aggro_vision_range, src)))
		LostTarget()
		return FALSE
	
	var/dist = get_dist(src, target_mob)
	if (dist <= 1)
		return TRUE

	proactive_magic_check(target_mob)

	MoveToTarget()
	return TRUE

/mob/living/simple_animal/wizard/bobby/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
		walk(src, 0)
		return

	stance = HOSTILE_STANCE_ATTACK
	var/dist = get_dist(src, target_mob)
	if (dist <= 3)
		walk_away_od(src, target_mob, 5, speed)
	else if (dist > 7)
		walk_to(src, target_mob, 5, speed)
	else
		walk(src, 0)

/mob/living/simple_animal/wizard/bobby/proactive_magic_check(mob/living/target)
	if (stat || !target || target.stat || world.time < spell_cooldown)
		return
	
	var/spell_type = pick(/obj/item/projectile/magic/freezum, /obj/item/projectile/magic/dropus)
	var/spell_name = "Freezum!"
	var/sound_file = 'sound/effects/spells/freezeum.ogg'
	if (spell_type == /obj/item/projectile/magic/dropus)
		spell_name = "Dropus!"
		sound_file = 'sound/effects/spells/dropus.ogg'

	fire_magic_at(target, spell_type, spell_name, sound_file)
	spell_cooldown = world.time + rand(40, 80)

	if (spell_type == /obj/item/projectile/magic/dropus)
		spawn(30)
			if (target && (target in range(6,src)))
				for (var/mob/M in player_list)
					if (M.client && (M in view(7, src)))
						M.show_chat_overlay(src, "<i>Teleportum Prisonem!</i>", "#dea30d")
						spawn(15)
							if (src && !stat && target && isliving(target))
								var/mob/living/L = target
								if (L.magic_shield > 0)
									visible_message(SPAN_WARNING("The Teleportum Prisonem spell reflects off [L]'s shield!"))
									return
								src.say("Off to the slammer with you!")
								send_to_jail(target)
/mob/living/simple_animal/wizard/bobby/proc/send_to_jail(mob/living/target)
	var/list/jail_turfs = latejoin_turfs["PoliceTeleporter"]
	if (!jail_turfs || !length(jail_turfs))
		return
	var/turf/spawnpoint = pick(jail_turfs)
	if (target && target.client && isturf(spawnpoint))
		target.forceMove(spawnpoint)
	if (map && map.ID == MAP_WIZARD_BOY)
		visible_message(SPAN_DANGER("<b>[target]</b> has been arrested and thrown into the magical slammer!"))
		var/obj/map_metadata/wizard_boy/WB = map
		WB.process_arest(target, 5)

// ============================================================
// GENERIC PROFESSORS & FACULTY
// ============================================================

/mob/living/simple_animal/wizard/professor
	name = "L.A.M.E. Professor"
	desc = "A miserable, underpaid teaching staff member who just wants to get through the day without a student exploding."
	icon_state = "wizard_professor1"
	icon_living = "wizard_professor1"
	icon_dead = "wizard_professor1_dead"
	maxHealth = 180
	health = 180
	speak_chance = 1
	var/list/flavour_text_professors = list(
		"The school board slashed our budget again. If you want to learn Burnus, you'll have to share a single matchstick with the student next to you.",
		"I hold a C.H.A.D. degree in Arcane Destruction, yet here I am, telling 11-year-olds to stop eating the potion ingredients.",
		"If I catch one more student casting Stinkaeum in the corridors, the entire year-group is getting an automatic I.D.I.O.T. certificate.",
		"Due to health and safety regulations, all magical duels must now take place in the mud outside. It builds character and saves on floor wax.",
		"Please open your textbooks to page 394. If your textbook is missing page 394 because the school bought them used in 1982, just guess.",
		"I don't get paid enough to deal with Dark Lords. If a Moldy Man walks in here, I am hiding under the desk and letting you sort it out.",
		"Who replaced my morning tea with Funny Juice? I've been burping up sheep's wool for three hours!",
		"I've been marking essays for five hours. If I read one more parchment citing 'magic' as the reason a cauldron exploded, I'm quitting.",
		"Stop tapping your wands on the desks! Do you know how hard it is to get scorch marks out of ancient Welsh oak?",
		"To whoever cast Pullus on my chalk: very funny. Now bring it back before I dock fifty points from Slatepie.",
		"No, Franco, your father cannot buy you a passing grade in this class. Though, for fifty Pounds, I might look the other way.",
		"I asked for a simple levitation charm, and you managed to set the ceiling on fire. Ten points to Rubywyrm for sheer audacity, I suppose.",
		"If you can't manage a basic Blockum shield, I highly suggest investing in a good helmet before the Mop Ball game.",
		"The staff room ran out of coffee. I am running entirely on spite and a mild stimulating hex.",
		"I remember when this school used to have actual brooms. Now look at us, scrubbing the sky with O-Cedar Master-Sweeps.",
		"I don't care if a ghost ate your homework. You still have to sit the U.N.G.A. exam on Friday.",
		"Please stop asking me how to cast Deadum. I am a History of Stuff teacher, not a bloody assassin.",
		"Why is it always the Mintysnek students who figure out how to bypass the locks on the dangerous supply closet?",
		"I haven't felt my toes since October. The heating in this academy is an absolute joke.",
		"Class dismissed. If anyone needs me, I'll be at The Leaky Sheep drinking until I forget I chose teaching as a career."
	)

/mob/living/simple_animal/wizard/professor/New()
	..()
	speak = flavour_text_professors
	clothing_colours = null
	icon_state = "wizard_professor[rand(1,2)]"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	update_icons()

/mob/living/simple_animal/wizard/professor/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	..()
	if (prob(30))
		src.say(pick("Detention for you!", "Right, that's a fifty-point deduction!", "I am far too busy for this nonsense!"))

/mob/living/simple_animal/wizard/professor/proactive_magic_check(mob/living/target)
	if (stat || !target || target.stat || world.time < spell_cooldown)
		return
	
	if (prob(60))
		fire_magic_at(target, /obj/item/projectile/magic/freezum, "Freezum!", 'sound/effects/spells/freezeum.ogg')
		spell_cooldown = world.time + rand(50, 100)
	else if (prob(30))
		src.say(pick("Detention for you!", "Right, that's a fifty-point deduction!", "I am far too busy for this nonsense!"))
		spell_cooldown = world.time + 50

// ============================================================
// NORMIE FARMERS
// ============================================================

var/list/flavour_text_normies = list(
	"I saw a boy from Rubywyrm crash his O-Cedar mop right through my greenhouse roof yesterday. I had to threaten him with a coal shovel just to get him down.",
	"One of those kids turned my prize-winning ram into a ceramic teapot. I don't care about your 'L.A.M.E.' degree, change it back or I'm calling the regular police!",
	"I'm just a normal bloke. I work at the slate quarry. I don't need to see some teenager in a wet bathrobe floating over the high street while I'm trying to buy milk.",
	"The magical static from that castle completely ruined the TV reception for the rugby match last night. All we got on the screen was purple static and faint chanting.",
	"I don't mind the students buying crisps at the corner shop, but when they start casting Stinkaeum! near the pub's dart-board, that's where I draw the line.",
	"I saw that Barry Hatter lad in the village. He's got a lightning bolt on his forehead. It looks like he just drew it on with a permanent marker, to be honest.",
	"They call it an 'Academy of Magical Education,' but the roof is falling in and the kids are wearing old curtains for robes. Looks pretty L.A.M.E. to me.",
	"Why do they fly on mops? Back in my day, we used mops to clean the floor. Now teenagers are using them to play 'Mop Ball' in the mud.",
	"The C.A.P. gave me a ticket because my sheep was grazing on 'Ministry Land.' It's a mountain! It's just grass! What a joke.",
	"My nephew went to Llanboarwart. He came home for the holidays and tried to turn a turnip into a gold coin. He just ended up setting his sleeve on fire. Waste of tuition."
)

/mob/living/simple_animal/wizard/normie_farmer
	name = "Normie Farmer"
	desc = "A local farmer, probably fed up with magical shenanigans."
	icon = 'icons/mob/npcs.dmi'
	faction = "Civilians"
	maxHealth = 100
	health = 100
	melee_damage_lower = 6
	melee_damage_upper = 12
	wander = TRUE
	stop_automated_movement = FALSE
	speak_chance = 1

/mob/living/simple_animal/wizard/normie_farmer/New()
	..()
	clothing_colours = null
	var/list/icon_states = list("civilian_1", "civilian_2", "civilian_6", "hostage_m1", "civilian_8", "civilian_9", "afghciv5")
	icon_state = pick(icon_states)
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	speak = flavour_text_normies
	update_icons()

/mob/living/simple_animal/wizard/normie_farmer/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	..()
	if (prob(50))
		src.say(pick("Get off my land!", "I've had enough of you wizards!", "That's it, you're getting a thrashing!"))

/mob/living/simple_animal/wizard/normie_farmer/proactive_magic_check(mob/living/target)
	return

// ============================================================
// HUW PUGH - Welsh Farmer
// ============================================================

/mob/living/simple_animal/wizard/huw_pugh
	name = "Farmer Huw Pugh"
	desc = "A Welsh farmer whose fields border the L.A.M.E. grounds. He absolutely despises the students. His name is Huw, son of Huw."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "farmer"
	icon_living = "farmer"
	icon_dead = "farmer_dead"
	faction = "Civilians"
	maxHealth = 200
	health = 200
	melee_damage_lower = 15
	melee_damage_upper = 25
	attacktext = "pitchforked"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	attack_verb = "stabs"
	wander = TRUE
	stop_automated_movement = FALSE
	speak_chance = 2

/mob/living/simple_animal/wizard/huw_pugh/New()
	..()
	clothing_colours = null
	icon_state = "farmer"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	speak = list(
		// "Which one of you magical idiots stole the spark plugs from my tractor? I'll shove that stick up your nose!"
		"Pa un ohonoch chi twmffatiaid hudol ddygodd y plygiau gwreichionen o fy nhractor? Wna i stwffio'r ffon yna i fyny dy drwyn di!",
		// "Bring my pig down right this minute! Pigs aren't supposed to float, you little devils!"
		"Dewch â fy mochyn i lawr rŵan y funud yma! Dydy moch ddim i fod i arnofio, y cythreuliaid bach!",
		// "Don't pull my leeks, you little sods! They're not magical, they're for Sunday soup!"
		"Peidiwch â thynnu fy nghennin, yr hen gontiau bach! Dydyn nhw ddim yn hudol, i'r cawl dydd Sul maen nhw!",
		// "Why are you all wearing grey dresses and saying silly words? Can't you afford trousers?"
		"Pam ydych chi i gyd yn gwisgo ffrogiau llwyd a dweud geiriau gwirion? Ydych chi ddim yn gallu fforddio trowsus?",
		// "If one more soap-ball hits my workshop ceiling, I'm calling the police! The real ones, not those C.A.P. ploncers!"
		"Os bydd un bêl-sebon arall yn taro nenfwd fy ngweithdy, dwi'n ffonio'r heddlu! Y rhai go iawn, nid y ploncers C.A.P. yna!"
	)
	update_icons()

/mob/living/simple_animal/wizard/huw_pugh/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	// "Try that again and I'll shove that stick so far up your arse, they'll be able to see it in Scotland!"
	src.say("Tria hynna eto ac mi wna i stwffio'r ffon yna mor bell i fyny dy din di, byddan nhw'n gallu ei gweld yn yr Alban!")
	..()

/mob/living/simple_animal/wizard/huw_pugh/proactive_magic_check(mob/living/target)
	return

/mob/living/simple_animal/wizard/huw_pugh/handle_combat_behaviour(t_behaviour)
	if (stat || !target_mob || target_mob.stat)
		stance = HOSTILE_STANCE_IDLE
		target_mob = null
		return FALSE

	if (get_dist(src, target_mob) <= 1)
		AttackingTarget()
	else
		var/moving_to = get_dir(src, target_mob)
		set_dir(moving_to)
		Move(get_step(src, moving_to))
	return TRUE

// ============================================================
// PROFESSOR SNIP
// Potions & Cauldron-Stirring class teacher.
// Hand him a container with ≥10u of Welsh Darkness Powder to
// advance from U.N.G.A. (level 1) to C.O.A.L. (level 2).
// ============================================================

/mob/living/simple_animal/wizard/professor_snip
	name = "Professor Snip"
	desc = "A gaunt, perpetually unimpressed potions professor. His robes are permanently stained with at least seven identifiable chemicals and several unidentifiable ones. He smells faintly of sulphur and disappointment."
	icon_state = "professor_snip"
	icon_living = "professor_snip"
	icon_dead = "professor_snip_dead"
	faction = "School"
	maxHealth = 600
	health = 600
	melee_damage_lower = 2
	melee_damage_upper = 4
	wander = FALSE
	stop_automated_movement = TRUE
	speak_chance = 1
	voice_pitch = 80
	var/retaliation_cooldown = 0
	var/submission_cooldown = 0

	var/list/snip_lines = list(
		"If you blow up my dungeon, you will be scrubbing the mortar with your own toothbrush. This is not a hypothetical.",
		"I have been teaching Cauldron-Stirring for thirty-four years. I have never, not once, been impressed. I do not expect today to be different.",
		"Pay attention. I will not repeat myself. I barely tolerate saying things once.",
		"The correct temperature for a Skele-Bones reduction is 'simmering'. Not 'boiling'. Not 'violently erupting'. Simmering.",
		"Phosphorus is not a toy. Potassium is not a toy. Sugar, in the context of Chemsmoke production, is also not a toy. None of these are toys.",
		"Someone in the third-year class last term brewed Polysoup Paste and poured it on the floor. The dungeon still smells. I know who it was. I am biding my time.",
		"The difference between a Soporific and a Draught of Living Death is the difference between a detention and a funeral. Take notes.",
		"You there. Stop stirring clockwise. I specifically said counter-clockwise. What part of 'specifically' was unclear?",
		"Ten points from whichever house is making that smell. I don't need to know who. I just need it to stop.",
		"The correct response to a cauldron fire is a fire-suppression charm, not screaming. Write that down.",
		"I do not grade on effort. I grade on results. If your result is a crater, you have failed.",
		"Bring me a properly-brewed Skele-Bones Broth and perhaps I'll consider you marginally less of a liability. Perhaps.",
		"Condensed Capsaicin has a flash point. I suggest you learn what that means before your next practical.",
		"I did not become a potions professor to watch children attempt to brew Liquid Gamble before they've mastered basic filtration. Yet here we are.",
		"If I find one more improperly labelled beaker in this laboratory, I will assign every student present detention until the heat death of the universe.",
		"The reason we use glass stirring rods and not metal ones is because of a very specific incident in 1987. I will not be discussing that incident.",
		"Ammonia and protein-based compounds will react. They will always react. This is chemistry, not a negotiation.",
	)

/mob/living/simple_animal/wizard/professor_snip/New()
	..()
	clothing_colours = null
	icon_state = "professor_snip"
	icon_living = "professor_snip"
	icon_dead = "professor_snip_dead"
	speak = snip_lines
	update_icons()

/mob/living/simple_animal/wizard/professor_snip/attack_hand(mob/user)
	if (ishuman(user) && (user.a_intent == I_HARM || user.a_intent == I_DISARM))
		return ..()
	src.say(pick(snip_lines))

/mob/living/simple_animal/wizard/professor_snip/respond_to_attack(mob/living/user)
	if (world.time > retaliation_cooldown)
		retaliation_cooldown = world.time + 300
		src.say(pick("Detention is too good for you.", "I suggest you put that away before I find a use for your spleen in a potion.", "Do not test my patience."))
		response_timer = world.time + 20
		return
	..()

/mob/living/simple_animal/wizard/professor_snip/proactive_magic_check(mob/living/target)
	if (stat || !target || target.stat || world.time < spell_cooldown)
		return
	
	retaliation_cooldown = world.time + 100
	src.say(pick("I have brewed things more dangerous than you.", "Right. Ten points from your life expectancy."))
	visible_message(SPAN_DANGER("<b>Professor Snip</b> flickers his wand with surgical precision!"))
	spawn(15)
		if (src && target && !target.stat)
			var/spell_type = pick(/obj/item/projectile/magic/painum, /obj/item/projectile/magic/freezum)
			var/spell_name = (spell_type == /obj/item/projectile/magic/freezum) ? "Freezum!" : "Painum!"
			var/sound_file = (spell_type == /obj/item/projectile/magic/freezum) ? 'sound/effects/spells/freezeum.ogg' : 'sound/effects/spells/painum.ogg'
			fire_magic_at(target, spell_type, spell_name, sound_file)
	spell_cooldown = world.time + 100

/mob/living/simple_animal/wizard/professor_snip/attackby(var/obj/item/O, var/mob/user)
	if (!ishuman(user) || !istype(map, /obj/map_metadata/wizard_boy))
		respond_to_attack(user)
		return ..()

	if (!istype(O, /obj/item/weapon/reagent_containers))
		respond_to_attack(user)
		src.say(pick(snip_lines))
		return ..()

	var/obj/item/weapon/reagent_containers/RC = O
	if (!RC.reagents || RC.reagents.get_reagent_amount("darkness_powder") < 10)
		src.say(pick(
			"That is not Welsh Instant Darkness Powder. That is whatever you have concocted in here, and I want it nowhere near my desk.",
			"Insufficient quantity. Ten units, minimum. Brew it properly or don't bother.",
			"I can see that is not what I asked for. Did you even read the recipe?",
			"That smells nothing like a correctly-brewed Welsh Instant Darkness Powder. Try again. And this time, read the instructions.",
		))
		return

	var/mob/living/human/H = user
	if (!H.client)
		return

	if (world.time < submission_cooldown)
		src.say("I have already assessed a submission recently. Come back in a moment.")
		return

	var/obj/map_metadata/wizard_boy/WB = map
	var/level = WB.check_level(H.client.ckey)

	if (level != "1")
		if (level == "0")
			src.say("You haven't even passed your U.N.G.A. examination yet. Sort that out first before wasting my time.")
		else
			src.say("You have already progressed beyond this assessment. Congratulations. Now stop bothering me.")
		return

	submission_cooldown = world.time + 300

	RC.reagents.remove_reagent("darkness_powder", 10)

	WB.change_level(H.client.ckey, "2")
	to_chat(world, "<font size=3 class='wizard'><b>[H.real_name]</b> ([H.key]) has passed Professor Snip's practical assessment and progressed to qualification level 2 (<b>C.O.A.L.</b>)!</font>")
	src.say("...Acceptable. Barely. The consistency was off and your colour was wrong, but the active compounds are present in adequate quantity. C.O.A.L. qualification granted. Do not celebrate. You have a long way to go.")
	playsound(src.loc, 'sound/effects/spells/fixae.ogg', 50, FALSE)

// ============================================================
// BIG BRENDA - The Leaky Sheep Pub Owner
// ============================================================

/mob/living/simple_animal/wizard/big_brenda
	name = "Big Brenda"
	desc = "The no-nonsense owner of The Leaky Sheep. Her forearms are thicker than most wizards' thighs, and her tolerance for magical nonsense is thinner than a wet paper towel."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "big_brenda"
	icon_living = "big_brenda"
	icon_dead = "big_brenda_dead"
	faction = "Civilians"
	maxHealth = 300
	health = 300
	melee_damage_lower = 12
	melee_damage_upper = 18
	attacktext = "cleavered"
	attack_verb = "cleavers"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	stop_automated_movement = FALSE
	wander = FALSE
	speak_chance = 2
	var/cooldown_shop = 0

/mob/living/simple_animal/wizard/big_brenda/New()
	..()
	clothing_colours = null
	icon_state = "big_brenda"
	icon_living = "big_brenda"
	icon_dead = "big_brenda_dead"
	speak = list(
		"If you cast Barrelus in my pub one more time, I'm going to make you clean the cellar with a toothbrush.",
		"I've served I-Can't-Believe-It's-Not-Butter-Beer to every student at Llanboarwart, and not a single one of them has ever paid me on time.",
		"I don't care if you're the 'Chosen One'. You're not drinking on credit.",
		"The Leaky Sheep has been in my family for six generations. We've survived wars, plagues, and the Ministry of Magic's hygiene inspections.",
		"If you're going to duel, take it outside. I don't need another hole in the ceiling.",
		"I've seen three Dark Lords try to recruit in my pub. I threw all of them out. Moldywart still owes me for a spilled pint.",
	)
	update_icons()

/mob/living/simple_animal/wizard/big_brenda/proactive_magic_check(mob/living/target)
	return

/mob/living/simple_animal/wizard/big_brenda/handle_combat_behaviour(t_behaviour)
	if (stat || !target_mob || target_mob.stat)
		stance = HOSTILE_STANCE_IDLE
		target_mob = null
		return FALSE
	if (get_dist(src, target_mob) <= 1)
		AttackingTarget()
	else
		var/moving_to = get_dir(src, target_mob)
		set_dir(moving_to)
		Move(get_step(src, moving_to))
	return TRUE

/mob/living/simple_animal/wizard/big_brenda/respond_to_attack(mob/living/user)
	if (stat || !user || !ishuman(user) || user.stat)
		return
	..()
	src.say(pick("Right, that's enough out of you!", "I'll cleaver you good!", "Don't make me come over that counter!", "You're barred!"))

/mob/living/simple_animal/wizard/big_brenda/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (H.a_intent == I_HARM || H.a_intent == I_DISARM)
		return ..()
	if (world.time < cooldown_shop)
		src.say("Back already? Give me a moment to breathe, won't you?")
		return
	cooldown_shop = world.time + 50
	src.say("Welcome to The Leaky Sheep! What can I get you?")
	show_shop(H)

/mob/living/simple_animal/wizard/big_brenda/proc/show_shop(mob/living/human/H)
	if (!H || !H.client)
		return
	var/dat = {"
<html>
<head><style>
body { font-family: 'Segoe UI', monospace; background: #2b1e0e; color: #f0e0c0; margin: 0; padding: 20px; }
h2 { color: #ffd700; border-bottom: 2px solid #5a3a1a; padding-bottom: 8px; margin-top: 0; }
.item { background: #3d2b14; border: 1px solid #5a3a1a; border-radius: 4px; padding: 10px 14px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: center; gap: 10px; }
.item .icon { width: 32px; height: 32px; flex-shrink: 0; image-rendering: pixelated; }
.item .info { flex: 1; }
.item .name { font-weight: bold; color: #f0e0c0; }
.item .desc { font-size: 11px; color: #b09070; }
.item .price { color: #ffd700; }
.buy-btn { background: #5a3a1a; color: #ffd700; border: 1px solid #8a6a3a; border-radius: 3px; padding: 4px 12px; cursor: pointer; font-size: 12px; }
.buy-btn:hover { background: #8a6a3a; }
.coins { color: #ffd700; text-align: right; margin-bottom: 16px; font-size: 14px; }
</style></head>
<body>
<h2>The Leaky Sheep <i>"Under The Counter"</i></h2>
<div class="item">
	<img class="icon" src="shop_item1.png">
	<div class="info"><span class="name">Brenda's "Special Reserve" Welsh Rum</span><br><span class="desc">Restores 100 Juice. 60 seconds of pain immunity. Makes you slur.</span></div>
	<div><span class="price">50 s.c.</span><br><button class="buy-btn" onclick="window.location='byond://?src=\ref[src];buy=1'">Buy</button></div>
</div>
<div class="item">
	<img class="icon" src="shop_item2.png">
	<div class="info"><span class="name">The "Chameleon" Mac</span><br><span class="desc">A coat that turns you invisible when you stand still.</span></div>
	<div><span class="price">200 s.c.</span><br><button class="buy-btn" onclick="window.location='byond://?src=\ref[src];buy=2'">Buy</button></div>
</div>
<div class="item">
	<img class="icon" src="shop_item3.png">
	<div class="info"><span class="name">Cwm-Plwd Ditch-Weed</span><br><span class="desc">Eat to gain 4 minutes of thermal vision.</span></div>
	<div><span class="price">40 s.c.</span><br><button class="buy-btn" onclick="window.location='byond://?src=\ref[src];buy=3'">Buy</button></div>
</div>
<div class="item">
	<img class="icon" src="shop_item4.png">
	<div class="info"><span class="name">"Bottomless" Tesco Carrier Bag</span><br><span class="desc">Holds huge amounts of items. Sharp objects might tear it.</span></div>
	<div><span class="price">80 s.c.</span><br><button class="buy-btn" onclick="window.location='byond://?src=\ref[src];buy=4'">Buy</button></div>
</div>
<div class="item">
	<img class="icon" src="shop_item5.png">
	<div class="info"><span class="name">"Dead-Zone" Car Battery</span><br><span class="desc">Creates a 7x7 null zone for 30s. No spells inside. 90s cooldown.</span></div>
	<div><span class="price">120 s.c.</span><br><button class="buy-btn" onclick="window.location='byond://?src=\ref[src];buy=5'">Buy</button></div>
</div>
</body>
</html>
"}
	H << browse_rsc(icon('icons/obj/magic_items.dmi', "rumbottle"), "shop_item1.png")
	H << browse_rsc(icon('icons/obj/magic_items.dmi', "mac_jacket"), "shop_item2.png")
	H << browse_rsc(icon('icons/obj/magic_items.dmi', "ditch_weed"), "shop_item3.png")
	H << browse_rsc(icon('icons/obj/magic_items.dmi', "tesco_bag"), "shop_item4.png")
	H << browse_rsc(icon('icons/obj/magic_items.dmi', "car_battery"), "shop_item5.png")
	H << browse(dat, "window=leaky_sheep;size=520x420")

/mob/living/simple_animal/wizard/big_brenda/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/H = usr
	if (get_dist(src, H) > 2)
		to_chat(H, SPAN_WARNING("You're too far away from Big Brenda!"))
		return
	if (href_list["buy"])
		var/item_id = text2num(href_list["buy"])
		var/list/shop_items = list(
			list("path" = /obj/item/weapon/reagent_containers/food/drinks/bottle/welsh_rum, "name" = "Brenda's \"Special Reserve\" Welsh Rum", "price" = 50),
			list("path" = /obj/item/clothing/suit/chameleon_mac, "name" = "The \"Chameleon\" Mac", "price" = 200),
			list("path" = /obj/item/weapon/reagent_containers/food/snacks/ditch_weed, "name" = "Cwm-Plwd Ditch-Weed", "price" = 40),
			list("path" = /obj/item/weapon/storage/tesco_bag, "name" = "\"Bottomless\" Tesco Carrier Bag", "price" = 80),
			list("path" = /obj/item/weapon/dead_zone_battery, "name" = "\"Dead-Zone\" Car Battery", "price" = 120),
		)
		if (item_id < 1 || item_id > shop_items.len)
			src.say("Not yet stocked, love. Check back later.")
			return
		var/list/entry = shop_items[item_id]
		var/price = entry["price"]
		var/item_name = entry["name"]
		var/item_path = entry["path"]

		var/total_coins = 0
		var/list/coin_stacks = list()
		for (var/obj/item/stack/money/silvercoin/SC in H.contents)
			total_coins += SC.amount
			coin_stacks += SC
		for (var/obj/item/stack/money/goldcoin/GC in H.contents)
			total_coins += GC.amount * 4
			coin_stacks += GC

		if (total_coins < price)
			src.say("You're short on silver, love. Come back when you've got [price] silver.")
			return

		var/to_deduct = price
		for (var/obj/item/stack/money/S in coin_stacks)
			if (to_deduct <= 0)
				break
			var/stack_value = istype(S, /obj/item/stack/money/goldcoin) ? S.amount * 4 : S.amount
			if (stack_value <= to_deduct)
				to_deduct -= stack_value
				qdel(S)
			else
				var/remove_amount = istype(S, /obj/item/stack/money/goldcoin) ? round((to_deduct + 3) / 4) : to_deduct
				if (istype(S, /obj/item/stack/money/goldcoin))
					S.amount -= remove_amount
					to_deduct -= remove_amount * 4
					if (to_deduct < 0)
						var/obj/item/stack/money/silvercoin/change = new(get_turf(H))
						change.amount = -to_deduct
						H.put_in_hands(change)
						to_deduct = 0
				S.update_icon()
				break

		var/obj/item/new_item = new item_path(get_turf(H))
		H.put_in_hands(new_item)
		src.say("There you go, love. One [item_name]. Don't tell the C.A.P. where you got it.")
		to_chat(H, SPAN_NOTICE("You bought [item_name] for [price] silver."))

// ============================================================
// GOLDEN GNAT
// A tiny, shimmering insect that flees from players on sight.
// Drops a golden gnat wing (wand core) when killed.
// ============================================================

/mob/living/simple_animal/golden_gnat
	name = "golden gnat"
	desc = "A tiny, brilliantly golden insect that hums at an impossibly high frequency. It seems to vibrate with barely contained speed."
	icon = 'icons/mob/monsters_wizards.dmi'
	icon_state = "gnat"
	icon_living = "gnat"
	icon_dead = "dead"
	faction = "Moldywart"
	maxHealth = 15
	health = 15
	melee_damage_lower = 0
	melee_damage_upper = 0
	mob_size = MOB_TINY
	move_to_delay = 1
	see_in_dark = 6
	response_help = "peers at"
	response_disarm = "swats at"
	response_harm = "squashes"
	density = FALSE
	pass_flags = PASSTABLE
	wander = TRUE
	stop_automated_movement = FALSE
	behaviour = "scared"
	flying = TRUE

/mob/living/simple_animal/golden_gnat/death(gibbed)
	if (stat != DEAD)
		new /obj/item/wand_part/gnat_wing(src.loc)
		visible_message(SPAN_DANGER("The [name] shatters into a shower of golden dust as it hits the ground!"))
		spawn(10)
			if (src)
				qdel(src)
	..(gibbed)

/mob/living/simple_animal/golden_gnat/attack_hand(mob/user)
	if (stat)
		return ..()
	if (ishuman(user) && (user.a_intent == I_HARM || user.a_intent == I_DISARM))
		do_behaviour("scared")
	return ..()

/mob/living/simple_animal/golden_gnat/attackby(obj/item/W, mob/living/user)
	if (ishuman(user))
		do_behaviour("scared")
	return ..()

/mob/living/simple_animal/golden_gnat/bullet_act(var/obj/item/projectile/P)
	if (P && P.invisibility <= 0 && ishuman(P.firer))
		do_behaviour("scared")
	return ..()

// ============================================================
// SPAWNERS
// ============================================================

/obj/effect/spawner/mobspawner/bobby
	name = "bobby spawner"
	create_path = /mob/living/simple_animal/wizard/bobby
	timer = 600
	icon_state = "npc"
	max_number = 1
	max_range = 4

/obj/effect/spawner/mobspawner/professor
	name = "professor spawner"
	create_path = /mob/living/simple_animal/wizard/professor
	timer = 600
	icon_state = "npc"
	max_number = 1
	max_range = 3

/obj/effect/spawner/mobspawner/healer_goblin
	name = "healer goblin spawner"
	create_path = /mob/living/simple_animal/wizard/goblin_healer
	timer = 600
	icon_state = "npc"
	max_number = 1
	max_range = 3

/obj/effect/spawner/mobspawner/cleaner_goblin
	name = "cleaner goblin spawner"
	create_path = /mob/living/simple_animal/wizard/goblin_cleaner
	timer = 600
	icon_state = "npc"
	max_number = 1
	max_range = 3

/obj/effect/spawner/mobspawner/normie_farmer
	name = "normie farmer spawner"
	create_path = /mob/living/simple_animal/wizard/normie_farmer
	timer = 600
	icon_state = "npc"
	max_number = 5
	max_range = 3

/obj/effect/spawner/mobspawner/huw_pugh
	name = "Huw Pugh spawner"
	create_path = /mob/living/simple_animal/wizard/huw_pugh
	timer = 600
	icon_state = "npc"
	max_number = 1
	max_range = 1

/obj/effect/spawner/mobspawner/professor_snip
	name = "Professor Snip spawner"
	create_path = /mob/living/simple_animal/wizard/professor_snip
	timer = 0
	icon_state = "npc"
	max_number = 1
	max_range = 1

/obj/effect/spawner/mobspawner/big_brenda
	name = "Big Brenda spawner"
	create_path = /mob/living/simple_animal/wizard/big_brenda
	timer = 600
	icon_state = "npc"
	max_number = 1
	max_range = 1

/obj/effect/spawner/mobspawner/golden_gnat
	name = "golden gnat spawner"
	create_path = /mob/living/simple_animal/golden_gnat
	timer = 12000
	icon_state = "npc"
	max_number = 1
	max_range = 3
