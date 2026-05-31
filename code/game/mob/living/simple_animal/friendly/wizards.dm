/mob/living/simple_animal/wizard
	name = "Llanboarwart Student"
	desc = "They look tired and damp."
	icon = 'icons/mob/npcs.dmi'
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
	speak_chance = FALSE
	speed = 4
	maxHealth = 150
	health = 150
	stop_automated_movement_when_pulled = TRUE
	stop_automated_movement = TRUE
	wander = FALSE
	faction = "Unknown"
	var/image/clothing_colours = null

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
	"My parents are Nuggles. My dad still thinks I go to a highly exclusive boarding school for junior tax attorneys, not a leaky castle in Cwm-Pimple.",
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
	"I told my Nuggle parents that I was learning to manipulate the very fabric of reality. I didn't tell them I was using a stick I found in a parking lot.",
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
		if (faction != "Unknown")
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

/mob/living/simple_animal/wizard/death()
	..()
	src.overlays -= clothing_colours
	update_icons()

/mob/living/simple_animal/wizard/attack_hand(mob/user)
	var/spoken_text = pick(flavour_text)
	src.say(spoken_text)

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
	icon = 'icons/mob/npcs.dmi'
	icon_state = "goblin_healer" // placeholder
	icon_living = "goblin_healer"
	icon_dead = "goblin_healer_dead"
	faction = "Unknown"
	maxHealth = 80
	health = 80
	melee_damage_lower = 2
	melee_damage_upper = 4
	var/heal_cooldown = 0

/mob/living/simple_animal/wizard/goblin_healer/New()
	// Override the base wizard New() so we don't randomly recolour or use the flavour_text speak list.
	clothing_colours = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "magic_boy_robe_decoration")
	icon_living = icon_state
	icon_dead = "goblin_healer_dead"
	speak = list()
	update_icons()

/mob/living/simple_animal/wizard/goblin_healer/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (world.time < heal_cooldown)
		src.say("Grak! Too soon, too soon! Come back when the poultice has set, yes?")
		return
	var/choice = alert(user, "\"Need healing, does yous?\" the goblin rasps, eyeing your wounds.", "Goblin Healer", "Yes please!", "No thanks.")
	if (choice == "Yes please!")
		if (H.health >= H.maxHealth)
			src.say("You looks fine to Grub! No waste the good medicine on the healthy, yes?")
			return
		src.say("Grub fixes! Hold still, yes? Grub's poultice is very old, very strong!")
		playsound(src.loc, 'sound/effects/spells/fixae.ogg', 60, FALSE)
		H.adjustBruteLoss(-40)
		H.adjustBurnLoss(-40)
		H.adjustToxLoss(-20)
		H.adjustOxyLoss(-20)
		if (H.stunned)  H.stunned = 0
		if (H.weakened) H.weakened = 0
		to_chat(H, SPAN_NOTICE("The goblin slaps a foul-smelling poultice on you and mutters a chant. You feel considerably less dead."))
		heal_cooldown = world.time + 1200 // 2 min cooldown
	else
		src.say("Hmph! Grub's time is precious, yes? Go away then!")

// ============================================================
// HEADMASTER TUMBLEDOOR
// ============================================================

/mob/living/simple_animal/wizard/tumbledoor
	name = "Headmaster Tumbledoor"
	desc = "An ancient wizard with a magnificent silver beard, half-moon spectacles, and the unsettling air of someone who already knows what you are about to say."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "tumbledoor"
	icon_living = "tumbledoor"
	icon_dead = "tumbledoor_dead"
	faction = "Unknown"
	maxHealth = 300
	health = 300
	melee_damage_lower = 1
	melee_damage_upper = 2
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
	clothing_colours = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "magic_boy_robe_decoration")
	icon_living = icon_state
	icon_dead = "tumbledoor_dead"
	speak = tumbledoor_lines
	update_icons()

/mob/living/simple_animal/wizard/tumbledoor/attack_hand(mob/user)
	var/spoken_text = pick(tumbledoor_lines)
	src.say(spoken_text)

/mob/living/simple_animal/wizard/tumbledoor/attackby(obj/item/W, mob/living/user)
	// Tumbledoor does not appreciate being struck.
	if (world.time < retaliation_cooldown)
		src.say("I would advise you not to try that again.")
		return
	src.say("LISTEN HERE YOU LITTLE SHIT.")
	playsound(src.loc, 'sound/effects/spells/deadum.ogg', 80, TRUE)
	visible_message(SPAN_DANGER("<b>Headmaster Tumbledoor</b> raises his wand with terrifying calm!"))
	retaliation_cooldown = world.time + 100
	spawn(20) // brief dramatic pause before the bolt fires
		if (src && user && !user.stat)
			for (var/mob/M in player_list)
				if (M.client && (M in view(7, src)))
					M.show_chat_overlay(src, "<i>Floatus!</i>", "#dea30d")
			playsound(src.loc, 'sound/effects/spells/floatus.ogg', 75, FALSE)
			visible_message("<span style=color:'#dea30d'><b>Headmaster Tumbledoor</b> uses <i>Floatus!</i></span>")
			spawn(5)
				playsound(src.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)
			var/obj/item/projectile/magic/floatus/bolt = new(src.loc)
			bolt.firer = src
			bolt.firer_original_dir = src.dir
			bolt.def_zone = "chest"
			bolt.launch(user, src, src, "chest")

// ============================================================
// MOLDY MEN — Moldywart's Followers
// Hostile simple_animal NPCs that cast Floatus, Burnus and Painum at players.
// ============================================================

/mob/living/simple_animal/hostile/moldy_man
	name = "Moldy Man"
	desc = "A grey, damp figure in a dark robe that smells powerfully of mildew and old cheese. One of Lord Moldywart's followers."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "moldyman"
	icon_living = "moldyman"
	icon_dead = "moldyman_dead"
	faction = "Moldywart"
	maxHealth = 80
	health = 80
	melee_damage_lower = 3
	melee_damage_upper = 6
	mob_size = MOB_MEDIUM
	stop_automated_movement = TRUE
	stop_automated_movement_when_pulled = TRUE
	wander = FALSE
	speed = 3
	move_to_delay = 5
	possession_candidate = FALSE
	attacktext = "claws"
	var/spell_cooldown = 0
	var/list/moldy_spells = list(
		/obj/item/projectile/magic/floatus,
		/obj/item/projectile/magic/fire_bolt,
		/obj/item/projectile/magic/painum,
	)
	var/list/moldy_spell_names = list(
		/obj/item/projectile/magic/floatus   = "Floatus!",
		/obj/item/projectile/magic/fire_bolt = "Burnus!",
		/obj/item/projectile/magic/painum    = "Painum!",
	)

/mob/living/simple_animal/hostile/moldy_man/New()
	..(  )
	processing_objects |= src

/mob/living/simple_animal/hostile/moldy_man/Destroy()
	processing_objects -= src
	return ..(  )

/mob/living/simple_animal/hostile/moldy_man/proc/find_nearest_player()
	var/mob/living/closest = null
	var/best_dist = 10 // only attack within 10 tiles
	for (var/mob/living/human/H in view(10, src))
		if (!H || H.stat || H.client == null)
			continue
		var/d = get_dist(src, H)
		if (d < best_dist)
			best_dist = d
			closest = H
	return closest

/mob/living/simple_animal/hostile/moldy_man/proc/cast_at(mob/living/target)
	if (!target || target.stat)
		return
	var/chosen_spell_type = pick(moldy_spells)
	var/spell_name = moldy_spell_names[chosen_spell_type]
	
	for (var/mob/M in player_list)
		if (M.client && (M in view(7, src)))
			M.show_chat_overlay(src, "<i>[spell_name]</i>", "#dea30d")
	
	var/sound_file = null
	switch(spell_name)
		if("Floatus!")
			sound_file = 'sound/effects/spells/floatus.ogg'
		if("Burnus!")
			sound_file = 'sound/effects/spells/burnus.ogg'
		if("Painum!")
			sound_file = 'sound/effects/spells/painum.ogg'
	if(sound_file)
		playsound(src.loc, sound_file, 75, FALSE)

	visible_message("<span style=color:'#dea30d'><b>[src]</b> uses <i>[spell_name]</i></span>")
	
	spawn(5)
		playsound(src.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)

	var/obj/item/projectile/magic/bolt = new chosen_spell_type(src.loc)
	bolt.firer = src
	bolt.firer_original_dir = src.dir
	bolt.def_zone = "chest"
	bolt.launch(target, src, src, "chest")

/mob/living/simple_animal/hostile/moldy_man/proc/process()
	if (stat || !loc)
		return
	// Attack nearby human players periodically.
	if (world.time >= spell_cooldown)
		var/mob/living/target = find_nearest_player()
		if (target)
			cast_at(target)
			spell_cooldown = world.time + rand(60, 120) // 6-12 second cooldown between spells

/mob/living/simple_animal/hostile/moldy_man/attack_hand(mob/user)
	src.say(pick(
		"The mold... it spreads...",
		"Moldywart sees all!",
		"You reek of Nuggle-blood.",
		"Lord Moldywart will reclaim his nose! ...Eventually.",
		"Mold. Damp. Darkness. This is the true magic.",
	))

// Named lieutenant variant — a bit tougher
/mob/living/simple_animal/hostile/moldy_man/lieutenant
	name = "Moldy Lieutenant"
	desc = "A senior follower of Lord Moldywart, more mold than man at this point."
	icon_state = "moldy_lt"
	icon_living = "moldy_lt"
	icon_dead = "moldy_lt"
	maxHealth = 150
	health = 150
	melee_damage_lower = 6
	melee_damage_upper = 12

// ============================================================
// LORD MOLDYWART — Boss NPC
// Casts Painum, Deadum, and Explodus at players.
// Sprites provided: moldywart / moldywart_dead
// ============================================================

/mob/living/simple_animal/hostile/moldywart
	name = "Lord Moldywart"
	desc = "He-Who-Must-Not-Be-Named-For-Legal-Reasons. A massive masked figure, radiating a cold and ancient malice."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "moldywart"
	icon_living = "moldywart"
	icon_dead = "moldywart_dead"
	faction = "Moldywart"
	maxHealth = 500
	health = 500
	melee_damage_lower = 10
	melee_damage_upper = 20
	mob_size = MOB_MEDIUM
	stop_automated_movement = TRUE
	stop_automated_movement_when_pulled = TRUE
	wander = FALSE
	speed = 2
	move_to_delay = 4
	possession_candidate = FALSE
	attacktext = "strikes"
	meat_amount = 0

	// Per-spell cooldowns so he can mix up his attack pattern
	var/cooldown_painum   = 0
	var/cooldown_deadum   = 0
	var/cooldown_explodus = 0

	// Thresholds (deciseconds)
	var/cd_painum_time   = 80  // ~8 sec
	var/cd_deadum_time   = 300 // ~30 sec
	var/cd_explodus_time = 200 // ~20 sec

	var/list/taunt_lines = list(
		"There is no good and evil. There is only power... and those too weak to seek it. Also, my nose.",
		"I have gone further than anybody along the path that leads to immortality. You will not stop me. You are also standing on my robe.",
		"I fashioned myself a new name, a name I knew wizards everywhere would one day fear to speak, when I had become the greatest sorcerer in the world! ...I miss having a nose.",
		"Nyehehehe.",
		"You dare? YOU DARE?! I defeated the greatest wizards of my age! I am the heir of Merlin himself! I am— ...one moment, I appear to have stepped in something.",
		"Kill the spare.",
		"I cannot be killed. I am the Dark Lord. I am eternal. I am—... does anyone have a tissue? I think I have a cold. I cannot tell.",
		"You think you can stand against me? I have horcruxes. Eleven of them. One of them is a sock. Don't ask.",
		"Join me. Or don't. I'll be honest, the Moldy Men could use the numbers, they keep getting Floatus'd into the ceiling.",
		"My followers are utterly loyal! Mostly because I hexed them. Details.",
	)

/mob/living/simple_animal/hostile/moldywart/New()
	..(  )
	processing_objects |= src
	// A booming entrance announcement visible to all nearby
	spawn(5)
		src.say("I have returned.")
		visible_message(SPAN_DANGER("<b>The air grows cold. <b>Lord Moldywart</b> has arrived.</b>"))

/mob/living/simple_animal/hostile/moldywart/Destroy()
	processing_objects -= src
	return ..(  )

/mob/living/simple_animal/hostile/moldywart/proc/find_nearest_player()
	var/mob/living/closest = null
	var/best_dist = 12
	for (var/mob/living/human/H in view(12, src))
		if (!H || H.stat || H.client == null)
			continue
		var/d = get_dist(src, H)
		if (d < best_dist)
			best_dist = d
			closest = H
	return closest

/mob/living/simple_animal/hostile/moldywart/proc/fire_spell(spell_type, spell_call, sound_file, mob/living/target)
	if (!target || target.stat || !src || src.stat)
		return
	
	for (var/mob/M in player_list)
		if (M.client && (M in view(7, src)))
			M.show_chat_overlay(src, "<i>[spell_call]</i>", "#dea30d")
	
	if(sound_file)
		playsound(src.loc, sound_file, 90, TRUE)

	visible_message("<span style=color:'#dea30d'><b>Lord Moldywart</b> uses <i>[spell_call]</i></span>")

	spawn(5)
		playsound(src.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)

	var/obj/item/projectile/magic/bolt = new spell_type(src.loc)
	bolt.firer = src
	bolt.firer_original_dir = src.dir
	bolt.def_zone = "chest"
	bolt.launch(target, src, src, "chest")

/mob/living/simple_animal/hostile/moldywart/proc/process()
	if (stat || !loc)
		return

	var/mob/living/target = find_nearest_player()
	if (!target)
		// No player nearby — taunt occasionally
		if (prob(2))
			src.say(pick(taunt_lines))
		return

	var/now = world.time

	// Priority order: Deadum > Explodus > Painum
	if (now >= cooldown_deadum)
		fire_spell(/obj/item/projectile/magic/deadum, "Deadum!", 'sound/effects/spells/deadum.ogg', target)
		cooldown_deadum = now + cd_deadum_time
		return

	if (now >= cooldown_explodus)
		fire_spell(/obj/item/projectile/magic/explodus, "Explodus!", 'sound/effects/spells/explodus.ogg', target)
		cooldown_explodus = now + cd_explodus_time
		return

	if (now >= cooldown_painum)
		fire_spell(/obj/item/projectile/magic/painum, "Painum!", 'sound/effects/spells/painum.ogg', target)
		cooldown_painum = now + cd_painum_time
		return

/mob/living/simple_animal/hostile/moldywart/attack_hand(mob/user)
	src.say(pick(taunt_lines))

/mob/living/simple_animal/hostile/moldywart/death(gibbed)
	src.visible_message(SPAN_NOTICE("<b>Lord Moldywart</b> lets out a bloodcurdling shriek and collapses."))
	src.say("I... shall return... again... it is... really getting... old...")
	..(gibbed)