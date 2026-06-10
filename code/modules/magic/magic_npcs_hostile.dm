// ============================================================
// MOLDY MEN - Moldywart's Followers
// Hostile simple_animal NPCs that cast Floatus, Burnus and Painum at players.
// ============================================================

/mob/living/simple_animal/hostile/wizard
	name = "DO NOT USE"
	icon = 'icons/mob/npcs_wizards.dmi'
	stop_automated_movement_when_pulled = FALSE
	var/house_point_value = 0

/mob/living/simple_animal/hostile/wizard/death(gibbed)
	if (stat != DEAD)
		if (map && istype(map, /obj/map_metadata/wizard_boy) && house_point_value > 0)
			var/obj/map_metadata/wizard_boy/WB = map
			var/mob/living/human/killer = lastattacker
			if (!killer && lastattacker && ishuman(lastattacker))
				killer = lastattacker
			if (killer && ishuman(killer) && killer.client)
				var/house = WB.check_house(killer.client.ckey)
				if (house != "Unknown" && house != "LOSER")
					WB.house_points[house] += house_point_value
					to_chat(killer, SPAN_NOTICE("Your house gains [house_point_value] points for defeating [name]!"))
	..(gibbed)
/mob/living/simple_animal/hostile/wizard/moldy_man
	name = "Moldy Man"
	desc = "A grey, damp figure in a dark robe that smells powerfully of mildew and old cheese. One of Lord Moldywart's followers."
	icon_state = "moldyman"
	icon_living = "moldyman"
	icon_dead = "moldyman_dead"
	faction = "Moldywart"
	maxHealth = 80
	health = 80
	melee_damage_lower = 3
	melee_damage_upper = 6
	mob_size = MOB_MEDIUM
	stop_automated_movement = FALSE
	wander = TRUE
	speed = 3
	move_to_delay = 5
	possession_candidate = FALSE
	universal_speak = TRUE
	attacktext = "claws"
	house_point_value = 10
	var/spell_cooldown = 0
	var/cooldown_blockum = 0
	var/cd_blockum_time = 200
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

/mob/living/simple_animal/hostile/wizard/moldy_man/attacker
	targeting = TRUE

/mob/living/simple_animal/hostile/wizard/moldy_man/New()
	..()
	processing_objects |= src

/mob/living/simple_animal/hostile/wizard/moldy_man/Destroy()
	processing_objects -= src
	return ..()

/mob/living/simple_animal/hostile/wizard/moldy_man/death()
	if (stat != DEAD)
		var/obj/item/stack/money/silvercoin/SC = new /obj/item/stack/money/silvercoin(src.loc)
		SC.amount = rand(28,38)
		if (prob(15))
			new /obj/item/weapon/material/magic/wand/crafted/henchman_twig(src.loc)
	..()

/mob/living/simple_animal/hostile/wizard/moldy_man/proc/find_nearest_player()
	var/mob/living/closest = null
	var/best_dist = 10
	for (var/mob/living/human/H in view(10, src))
		if (!H || H.stat || H.client == null)
			continue
		var/d = get_dist(src, H)
		if (d < best_dist)
			best_dist = d
			closest = H
	return closest

/mob/living/simple_animal/hostile/wizard/moldy_man/proc/fire_blockum()
	if (stat || !src)
		return
	for (var/mob/M in player_list)
		if (M.client && (M in view(7, src)))
			M.show_chat_overlay(src, "<i>Blockum!</i>", "#dea30d")
	
	playsound(src.loc, 'sound/effects/spells/blockum.ogg', 75, FALSE)
	visible_message("<span style=color:'#dea30d'><b>[src]</b> uses <i>Blockum!</i></span>")

	spawn(5)
		playsound(src.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)

	var/obj/item/projectile/magic/blockum/bolt = new(src.loc)
	bolt.firer = src
	bolt.launch(src, src, src, "chest")

/mob/living/simple_animal/hostile/wizard/moldy_man/proc/cast_at(mob/living/target)
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

/mob/living/simple_animal/hostile/wizard/moldy_man/proc/process()
	if (stat || !loc)
		return

	var/mob/living/target = find_nearest_player()
	if (!target)
		return

	if (world.time >= cooldown_blockum && prob(15))
		fire_blockum()
		cooldown_blockum = world.time + cd_blockum_time
		return

	if (world.time >= spell_cooldown)
		cast_at(target)
		spell_cooldown = world.time + rand(60, 120)

/mob/living/simple_animal/hostile/wizard/moldy_man/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in view(aggro_vision_range, src)))
		LostTarget()
		return FALSE
	
	var/dist = get_dist(src, target_mob)
	if (dist <= 1)
		return TRUE

	if (world.time >= cooldown_blockum && prob(20))
		fire_blockum()
		cooldown_blockum = world.time + cd_blockum_time
		return TRUE

	if (world.time >= spell_cooldown)
		cast_at(target_mob)
		spell_cooldown = world.time + rand(60, 120)

	MoveToTarget()
	return TRUE

/mob/living/simple_animal/hostile/wizard/moldy_man/MoveToTarget()
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

/mob/living/simple_animal/hostile/wizard/moldy_man/attack_hand(mob/user)
	src.say(pick(
		"The mold... it spreads...",
		"Moldywart sees all!",
		"You reek of Normie-blood.",
		"Lord Moldywart will reclaim his nose! ...Eventually.",
		"Mold. Damp. Darkness. This is the true magic.",
	))

/mob/living/simple_animal/hostile/wizard/moldy_man/lieutenant
	name = "Moldy Lieutenant"
	desc = "A senior follower of Lord Moldywart, more mold than man at this point."
	icon_state = "moldy_lt"
	icon_living = "moldy_lt"
	icon_dead = "moldy_lt"
	maxHealth = 150
	health = 150
	melee_damage_lower = 6
	melee_damage_upper = 12
	cd_blockum_time = 150

mob/living/simple_animal/hostile/wizard/moldy_man/lieutenant/death()
	if (stat != DEAD)
		var/loot_path = pick(/obj/item/wand_part/spark_plug,/obj/item/wand_part/cassette_tape,/obj/item/wand_part/chewing_gum)
		new loot_path(src.loc)
	..()

// ============================================================
// LORD MOLDYWART - Boss NPC
// Casts Painum, Deadum, and Explodus at players.
// Sprites provided: moldywart / moldywart_dead
// ============================================================

/mob/living/simple_animal/hostile/wizard/moldywart
	name = "Lord Moldywart"
	desc = "He-Who-Must-Not-Be-Named-For-Legal-Reasons. A massive masked figure, radiating a cold and ancient malice."
	icon_state = "moldywart"
	icon_living = "moldywart"
	icon_dead = "moldywart_dead"
	faction = "Moldywart"
	voice_pitch = 60
	maxHealth = 500
	health = 500
	melee_damage_lower = 10
	melee_damage_upper = 20
	mob_size = MOB_MEDIUM
	stop_automated_movement = FALSE
	stop_automated_movement_when_pulled = TRUE
	wander = TRUE
	speed = 2
	move_to_delay = 4
	possession_candidate = FALSE
	universal_speak = TRUE
	attacktext = "strikes"
	meat_amount = 0
	house_point_value = 250

	// Per-spell cooldowns so he can mix up his attack pattern
	var/cooldown_painum   = 0
	var/cooldown_deadum   = 0
	var/cooldown_explodus = 0
	var/cooldown_blockum  = 0

	var/cd_painum_time   = 80
	var/cd_deadum_time   = 300
	var/cd_explodus_time = 200
	var/cd_blockum_time  = 200

	var/list/taunt_lines = list(
		"There is no good and evil. There is only power... and those too weak to seek it. Also, my nose.",
		"I have gone further than anybody along the path that leads to immortality. You will not stop me. You are also standing on my robe.",
		"I fashioned myself a new name, a name I knew wizards everywhere would one day fear to speak, when I had become the greatest sorcerer in the world! ...I miss having a nose.",
		"Nyehehehe.",
		"You dare? YOU DARE?! I defeated the greatest wizards of my age! I am the heir of Merlin himself! I am- ...one moment, I appear to have stepped in something.",
		"Kill the spare.",
		"I cannot be killed. I am the Dark Lord. I am eternal. I am-... does anyone have a tissue? I think I have a cold. I cannot tell.",
		"You think you can stand against me? I have horcruxes. Eleven of them. One of them is a sock. Don't ask.",
		"Join me. Or don't. I'll be honest, the Moldy Men could use the numbers, they keep getting Floatus'd into the ceiling.",
		"My followers are utterly loyal! Mostly because I hexed them. Details.",
	)

/mob/living/simple_animal/hostile/wizard/moldywart/New()
	..()
	processing_objects |= src
	spawn(5)
		if(src)
			src.say("I have returned.")
			playsound(src.loc, 'sound/voice/wizard_boy/moldywart_entrance.ogg', 75, FALSE)
			visible_message(SPAN_DANGER("<b>The air grows cold. <b>Lord Moldywart</b> has arrived.</b>"))

/mob/living/simple_animal/hostile/wizard/moldywart/Destroy()
	processing_objects -= src
	return ..()

/mob/living/simple_animal/hostile/wizard/moldywart/proc/find_nearest_player()
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

/mob/living/simple_animal/hostile/wizard/moldywart/proc/fire_blockum()
	if (stat || !src)
		return
	for (var/mob/M in player_list)
		if (M.client && (M in view(7, src)))
			M.show_chat_overlay(src, "<i>Blockum!</i>", "#dea30d")
	
	playsound(src.loc, 'sound/effects/spells/blockum.ogg', 75, FALSE)
	visible_message("<span style=color:'#dea30d'><b>[src]</b> uses <i>Blockum!</i></span>")

	spawn(5)
		playsound(src.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)

	var/obj/item/projectile/magic/blockum/bolt = new(src.loc)
	bolt.firer = src
	bolt.launch(src, src, src, "chest")

/mob/living/simple_animal/hostile/wizard/moldywart/proc/fire_spell(spell_type, spell_call, sound_file, mob/living/target)
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

/mob/living/simple_animal/hostile/wizard/moldywart/proc/process()
	if (stat || !loc)
		return

	var/mob/living/target = find_nearest_player()
	if (!target)
		if (prob(2))
			src.say(pick(taunt_lines))
		return

	var/now = world.time

	if (now >= cooldown_blockum && prob(15))
		fire_blockum()
		cooldown_blockum = now + cd_blockum_time
		return

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

/mob/living/simple_animal/hostile/wizard/moldywart/AttackTarget()
	if (!target_mob || !SA_attackable(target_mob))
		LoseTarget()
		return FALSE
	if (!(target_mob in view(aggro_vision_range, src)))
		LostTarget()
		return FALSE
	
	var/dist = get_dist(src, target_mob)
	if (dist <= 1)
		return TRUE

	var/now = world.time

	if (now >= cooldown_blockum && prob(20))
		fire_blockum()
		cooldown_blockum = now + cd_blockum_time
		return TRUE

	if (now >= cooldown_deadum)
		fire_spell(/obj/item/projectile/magic/deadum, "Deadum!", 'sound/effects/spells/deadum.ogg', target_mob)
		cooldown_deadum = now + cd_deadum_time
	else if (now >= cooldown_explodus)
		fire_spell(/obj/item/projectile/magic/explodus, "Explodus!", 'sound/effects/spells/explodus.ogg', target_mob)
		cooldown_explodus = now + cd_explodus_time
	else if (now >= cooldown_painum)
		fire_spell(/obj/item/projectile/magic/painum, "Painum!", 'sound/effects/spells/painum.ogg', target_mob)
		cooldown_painum = now + cd_painum_time

	MoveToTarget()
	return TRUE

/mob/living/simple_animal/hostile/wizard/moldywart/MoveToTarget()
	if (!target_mob || !SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
		walk(src, 0)
		return

	stance = HOSTILE_STANCE_ATTACK
	var/dist = get_dist(src, target_mob)
	if (dist <= 3)
		walk_away_od(src, target_mob, 5, speed)
	else if (dist > 8)
		walk_to(src, target_mob, 5, speed)
	else
		walk(src, 0)

/mob/living/simple_animal/hostile/wizard/moldywart/attack_hand(mob/user)
	src.say(pick(taunt_lines))

/mob/living/simple_animal/hostile/wizard/moldywart/death(gibbed)
	if (stat != DEAD)
		new /obj/item/weapon/material/magic/wand/crafted/the_pale_stick(src.loc)
		src.visible_message(SPAN_NOTICE("<b>Lord Moldywart</b> lets out a bloodcurdling shriek and collapses."))
		src.say("I... shall return... again... it is... really getting... old...")
		playsound(src.loc, 'sound/voice/wizard_boy/moldywart_death.ogg', 75, FALSE)
	..(gibbed)

/obj/effect/spawner/mobspawner/moldymen
	name = "moldymen spawner"
	create_path = /mob/living/simple_animal/hostile/wizard/moldy_man
	timer = 600
	icon_state = "npc"
	max_number = 3

/obj/effect/spawner/mobspawner/moldymen_lt
	name = "moldymen lieutenant spawner"
	create_path = /mob/living/simple_animal/hostile/wizard/moldy_man/lieutenant
	timer = 600
	icon_state = "npc"
	max_number = 1

/obj/effect/spawner/mobspawner/moldywart
	name = "moldywart"
	create_path = /mob/living/simple_animal/hostile/wizard/moldywart
	timer = 12000
	icon_state = "npc"
	max_number = 1

/obj/effect/spawner/mobspawner/moldymen/inactive
	create_path = /mob/living/simple_animal/hostile/wizard/moldy_man/attacker
	activated = FALSE

// ============================================================
// TRAINING DUMMY
// ============================================================

/mob/living/simple_animal/hostile/wizard/training_dummy
	name = "Animated Training Dummy"
	desc = "A straw-filled training dummy enchanted to test defensive magic."
	icon = 'icons/mob/npcs_wizards.dmi'
	icon_state = "training_dummy"
	icon_living = "training_dummy"
	icon_dead = "training_dummy_dead"
	maxHealth = 9999
	health = 9999
	wander = FALSE
	stop_automated_movement = TRUE
	faction = "School"
	var/mob/living/human/active_student = null
	var/phase = 1
	var/blocks_done = 0
	var/spell_cooldown = 0

/mob/living/simple_animal/hostile/wizard/training_dummy/Move()
	return FALSE

/mob/living/simple_animal/hostile/wizard/training_dummy/handle_ai()
	if (stat || !loc)
		return
	if (!active_student || active_student.stat || get_dist(src, active_student) > 10)
		active_student = null
		phase = 1
		blocks_done = 0
		if (l_hand) qdel(l_hand)
		if (r_hand) qdel(r_hand)
		l_hand = null
		r_hand = null
		overlays.Cut()
		return

	dir = get_dir(src, active_student)

	if (phase == 1)
		if (world.time >= spell_cooldown)
			spell_cooldown = world.time + 40
			
			for (var/mob/M in player_list)
				if (M.client && (M in view(7, src)))
					M.show_chat_overlay(src, "<i>Zappus!</i>", "#6800a0")
			playsound(src.loc, 'sound/effects/spells/zappus.ogg', 75, FALSE)
			visible_message("<span style=color:'#6800a0'><b>[src]</b> uses <i>Zappus!</i></span>")
			
			var/obj/item/projectile/magic/zappus/slow_purple/bolt = new(src.loc)
			bolt.firer = src
			bolt.firer_original_dir = src.dir
			bolt.def_zone = "chest"
			bolt.launch(active_student, src, src, "chest")
			
	else if (phase == 2)
		if (!r_hand && !l_hand)
			var/obj/item/weapon/material/sword/training/W = new(src)
			r_hand = W
			overlays += image('icons/mob/items/lefthand_weapons.dmi', "wood_sword")
			visible_message(SPAN_WARNING("<b>[src]</b> draws a wooden sword! Use Dropus! to disarm it!"))

/mob/living/simple_animal/hostile/wizard/training_dummy/proc/register_deflection(mob/living/human/H)
	if (phase != 1 || active_student != H)
		return
	blocks_done++
	to_chat(H, SPAN_NOTICE("Successfully deflected [blocks_done]/3 spells!"))
	playsound(src.loc, 'sound/effects/spells/blockum.ogg', 75, FALSE)
	if (blocks_done >= 3)
		phase = 2
		to_chat(H, SPAN_NOTICE("Defensive trial complete! The dummy draws a wooden sword. Cast Dropus! to disarm the dummy!"))
		var/obj/item/weapon/material/sword/training/W = new(src)
		r_hand = W
		overlays += image('icons/mob/items/lefthand_weapons.dmi', "wood_sword")

/mob/living/simple_animal/hostile/wizard/training_dummy/proc/register_hit(mob/living/human/H)
	if (phase != 1 || active_student != H)
		return
	to_chat(H, SPAN_WARNING("You were hit! Try to time your Blockum! cast better. (Requires 3 successful deflections)"))

/mob/living/simple_animal/hostile/wizard/training_dummy/drop_l_hand()
	if (l_hand)
		l_hand.loc = get_turf(src)
		l_hand = null
		update_inv_l_hand()
		check_disarmed()

/mob/living/simple_animal/hostile/wizard/training_dummy/drop_r_hand()
	if (r_hand)
		r_hand.loc = get_turf(src)
		r_hand = null
		update_inv_r_hand()
		check_disarmed()

/mob/living/simple_animal/hostile/wizard/training_dummy/update_inv_l_hand()
	overlays.Cut()
	update_icons()

/mob/living/simple_animal/hostile/wizard/training_dummy/update_inv_r_hand()
	overlays.Cut()
	update_icons()

/mob/living/simple_animal/hostile/wizard/training_dummy/proc/check_disarmed()
	if (phase != 2 || active_student == null)
		return
	if (!r_hand && !l_hand)
		var/mob/living/human/H = active_student
		active_student = null
		phase = 1
		blocks_done = 0
		
		if (H && H.client && map && istype(map, /obj/map_metadata/wizard_boy))
			var/obj/map_metadata/wizard_boy/WB = map
			if (WB.check_level(H.client.ckey) == "2")
				WB.change_level(H.client.ckey, "3")
				to_chat(world, "<font size=3 class='wizard'><b>[H.real_name]</b> ([H.key]) has completed the G.E.M. trial and progressed to qualification level 3 (<b>G.E.M.</b>)!</font>")
			else
				to_chat(H, SPAN_NOTICE("You have completed the trial! (You are not at C.O.A.L. level so you did not advance to G.E.M.)"))
		else if (H)
			to_chat(H, SPAN_NOTICE("You have successfully completed the trial!"))
		
		visible_message(SPAN_NOTICE("<b>[src]</b> powers down, its trial completed."))
		qdel(src)

/mob/living/simple_animal/hostile/wizard/training_dummy/proc/abort_trial()
	if (!active_student)
		qdel(src)
		return
	var/mob/living/human/H = active_student
	active_student = null
	phase = 1
	blocks_done = 0
	if (l_hand)
		qdel(l_hand)
		l_hand = null
	if (r_hand)
		qdel(r_hand)
		r_hand = null
	overlays.Cut()
	to_chat(H, SPAN_WARNING("<b>Trial failed!</b> You must remain in the dueling circle throughout the trial!"))
	visible_message(SPAN_WARNING("<b>[src]</b> powers down as the student left the dueling circle."))
	qdel(src)

/obj/effect/spawner/mobspawner/training_dummy
	name = "training dummy spawner"
	create_path = /mob/living/simple_animal/hostile/wizard/training_dummy
	max_number = 1
	max_range = 0
	timer = 600
	icon_state = "npc"
	activated = FALSE

// ============================================================
// THE GLOOM - Bootleg Dementors
// Floating entities of pure despair that drain heat and hope.
// ============================================================

/mob/living/simple_animal/hostile/wizard/gloom
	name = "Gloom"
	desc = "A terrifying, hooded figure cloaked in tattered black rags. A soul-chilling cold radiates from its presence, and all hope seems to wither near it."
	icon = 'icons/mob/monsters_wizards.dmi'
	icon_state = "gloom"
	icon_living = "gloom"
	icon_dead = "gloom"
	faction = "Moldywart"
	maxHealth = 250
	health = 250
	melee_damage_lower = 15
	melee_damage_upper = 25
	attacktext = "chills"
	attack_verb = "chills"
	speed = 1
	move_to_delay = 5
	possession_candidate = FALSE
	universal_speak = TRUE
	meat_amount = 0
	house_point_value = 50

/mob/living/simple_animal/hostile/wizard/gloom/death()
	if (stat != DEAD)
		new /obj/item/wand_part/gloom_thread(src.loc)
		visible_message(SPAN_DANGER("The [name] lets out a painful hiss as it fades away!"))
		playsound(src.loc, 'sound/animals/monsters/hiss2.ogg', 100, TRUE)
		spawn(10)
			if (src)
				qdel(src)
		..()

/mob/living/simple_animal/hostile/wizard/gloom/bullet_act(var/obj/item/projectile/P)
	if (istype(P, /obj/item/projectile/magic))
		if (P.name in list("Dropus!", "Stinkaeum!", "Freezum!", "Barrelus!", "Painum!", "Deadum!"))
			visible_message(SPAN_NOTICE("The magical bolt passes through \the [src] harmlessly!"))
			return PROJECTILE_FORCE_MISS
	return ..()

/mob/living/simple_animal/hostile/wizard/gloom/AttackTarget()
	. = ..()
	if (. && ishuman(target_mob))
		var/mob/living/human/H = target_mob
		
		H.mood = max(10, H.mood-10)
		
		H.apply_damage(rand(10, 15), BURN)
		
		H.bodytemperature = max(0, H.bodytemperature - 10)
		
		to_chat(H, SPAN_DANGER("You feel a soul-chilling dread as \the [src] drains your very warmth and hope!"))
		if (prob(50))
			playsound(H.loc, 'sound/animals/monsters/shriek1.ogg', 100, TRUE)

/obj/effect/spawner/mobspawner/gloom
	name = "gloom spawner"
	create_path = /mob/living/simple_animal/hostile/wizard/gloom
	timer = 1800
	icon_state = "npc"
	max_number = 1
