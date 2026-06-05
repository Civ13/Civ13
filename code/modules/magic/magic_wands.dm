//WANDS
/obj/item/weapon/material/magic/wand
	name = "magic wand"
	desc = "Sparkly."
	icon = 'icons/obj/magic_weapons.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_magic.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_magic.dmi',
		)
	icon_state = "wand"
	item_state = "wand"
	slot_flags = SLOT_BELT
	force_divisor = 0.7
	thrown_force_divisor = 0.5
	block_chance = 35
	attack_verb = list("bonked", "batted", "hit", "whacked")
	hitsound = 'sound/effects/woodhit.ogg'
	drawsound = null
	default_material = null
	secondary_action = TRUE
	var/datum/spell/active_spell = null // currently selected spell datum
	var/maxcharges = 10               // max charge pool
	var/chargetime = 60               // deciseconds per charge tick
	var/casting = FALSE
	var/minimum_level = 0             // minimum magic stat to use wand at all
	var/charges
	var/chargetimer = 0

/obj/item/weapon/material/magic/wand/New()
	charges = maxcharges
	default_material = null
	processing_objects |= src

/obj/item/weapon/material/magic/wand/Destroy()
	processing_objects -= src
	return ..()

/obj/item/weapon/material/magic/wand/process()
	if (charges >= maxcharges)
		chargetimer = 0
		return
	chargetimer += 2
	if (chargetimer >= chargetime)
		charges++
		chargetimer = 0
		if (istype(loc, /mob))
			to_chat(loc, SPAN_NOTICE("\The [src] crackles with magical energy, regaining a charge!"))

// Returns list of datum/spell the user knows, filtered to those they meet the skill_level for.
/obj/item/weapon/material/magic/wand/proc/get_usable_spells(mob/user)
	var/list/usable = list()
	if (!user || !user.spell_list)
		return usable
	var/magic_lvl = 0
	if (ishuman(user))
		var/mob/living/human/H = user
		magic_lvl = H.getStat("magic")
	for (var/datum/spell/S in user.spell_list)
		if (magic_lvl >= S.skill_level)
			usable += S
	return usable

/obj/item/weapon/material/magic/wand/examine(mob/user as mob)
	to_chat(user, SPAN_NOTICE("[desc]"))
	if (ishuman(user))
		var/mob/living/human/H = user
		if (active_spell)
			to_chat(user, SPAN_NOTICE("The currently active spell is <b>[active_spell.name]</b>."))
		else
			to_chat(user, SPAN_NOTICE("No spell is selected. Use the secondary action to pick one."))

		// juice display
		var/fullness
		if (H.getStat("magic") < 100)
			if (H.juice >= 100)
				fullness = "full"
			else if (H.juice >= 75)
				fullness = "almost full"
			else if (H.juice >= 50)
				fullness = "mostly full"
			else if (H.juice >= 25)
				fullness = "partially empty"
			else if (H.juice > 0)
				fullness = "almost empty"
			else
				fullness = "empty"
			to_chat(user, SPAN_NOTICE("The magic within you feels <font color=#9fe6f5>[fullness]!</font>"))
		else
			to_chat(user, SPAN_NOTICE("You have <font color=#9fe6f5>[H.juice]</font> out of <font color=#9fe6f5>100 units of magical juice left!</font>"))

		// list known usable spells
		var/list/usable = get_usable_spells(user)
		if (usable.len)
			var/spell_names = ""
			for (var/datum/spell/S in usable)
				spell_names += "[S.name], "
			to_chat(user, SPAN_NOTICE("Known spells available: [copytext(spell_names, 1, length(spell_names)-1)]"))
		else
			to_chat(user, SPAN_NOTICE("You do not know any spells usable with this wand."))
	else
		to_chat(user, SPAN_NOTICE("Eugh, magic disgusts you. Leave it to humans."))

// Cycle through the user's known spells with secondary action
/obj/item/weapon/material/magic/wand/secondary_attack_self(mob/living/human/user)
	var/list/usable = get_usable_spells(user)
	if (!usable.len)
		to_chat(user, SPAN_WARNING("You don't know any spells you can cast with this wand!"))
		return

	// find current index in usable list
	var/idx = 1
	if (active_spell && (active_spell in usable))
		idx = usable.Find(active_spell) + 1
		if (idx > usable.len)
			idx = 1

	active_spell = usable[idx]
	to_chat(user, SPAN_NOTICE("Spell set to <b>[active_spell.name]</b>!"))
	if (user.hud_used)
		user.hud_used.update_spell_selector(user)
		user.hud_used.update_spellshow(user)

// Cycle through the user's known spells with secondary action
/obj/item/weapon/material/magic/wand/attack_self(mob/living/human/user)
	var/list/usable = get_usable_spells(user)
	if (!usable.len)
		to_chat(user, SPAN_WARNING("You don't know any spells you can cast with this wand!"))
		return

	// find current index in usable list
	var/idx = usable.len
	if (active_spell && (active_spell in usable))
		idx = usable.Find(active_spell) - 1
		if (idx < 1)
			idx = usable.len

	active_spell = usable[idx]
	to_chat(user, SPAN_NOTICE("Spell set to <b>[active_spell.name]</b>!"))
	if (user.hud_used)
		user.hud_used.update_spell_selector(user)
		user.hud_used.update_spellshow(user)

/obj/item/weapon/material/magic/wand/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!user || !target)
		return
	if (casting)
		return
	if (ishuman(user))
		var/area/H_area = get_area(user)
		if (H_area && istype(H_area, /area/caribbean/houses/nml_three))
			to_chat(user, SPAN_DANGER("There's a charm in the police station preventing magic from being cast."))
			casting = FALSE
			return

		var/mob/living/human/H = user
		if (H.getStat("magic") < minimum_level)
			to_chat(user, SPAN_WARNING("You do not have the magical knowledge required to use this wand!"))
			return

	// Validate or auto-select active spell
	var/list/usable = get_usable_spells(user)
	if (!usable.len)
		to_chat(user, SPAN_WARNING("You don't know any spells you can cast with this wand!"))
		return
	if (!active_spell || !(active_spell in usable))
		active_spell = usable[1]
		to_chat(user, SPAN_NOTICE("Spell auto-selected: <b>[active_spell.name]</b>."))
		if (user.hud_used)
			user.hud_used.update_spell_selector(user)
			user.hud_used.update_spellshow(user)

	var/datum/spell/S = active_spell

	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.juice < S.juice_cost)
			to_chat(user, SPAN_WARNING("You don't have enough magical juice to cast this spell!"))
			return

	casting = TRUE

	if (do_after(user, S.cast_time, target))
		if (!src || !user || !target || !S)
			casting = FALSE
			return
		if (ishuman(user))
			var/mob/living/human/H = user
			if (H.juice >= S.juice_cost && user.get_active_hand() == src)
				H.juice -= S.juice_cost
				for (var/mob/living/human/M in view(7, H))
					if (M.client)
						M.show_chat_overlay(H, "<i>[S.name]!</i>", "#dea30d")
				if (S.sound_effect)
					playsound(user.loc, S.sound_effect, 75, FALSE)
					H.visible_message("<span style=color:'#dea30d'><b>[user]</b> uses <i>[S.name]!</i></span>")
					playsound(user.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)
				if (S.skill_level >= 80)
					for (var/mob/living/simple_animal/wizard/bobby/B in view(7, H))
						B.witness_spell(H, S)
				spawn(5)
					if (!src || !user || !target || !S)
						casting = FALSE
						return
					// Handle non-projectile spells directly
					if (S.name == "Wallus")
						var/turf/T = get_turf(target)
						if (T && !T.density)
							new /obj/structure/barricade/magic(T)
							T.visible_message(SPAN_NOTICE("A magical barricade suddenly appears!"))
						else
							to_chat(H, SPAN_WARNING("You cannot summon a barricade there!"))
							// Refund juice if creation fails
							H.juice = min(H.max_juice, H.juice + S.juice_cost)

					else if (S.name == "Lightus")
						// Spawns a temporary light effect on the caster
						new /obj/effect/magic_light_effect(H, H)
						to_chat(H, SPAN_NOTICE("You glow with a soft magical light!"))
					else if (S.name == "Blinkae")
						// Teleport user to target tile
						var/turf/T = get_turf(target)
						// Check if target is a valid, walkable tile within range
						if (T && get_dist(H, T) <= 7 && !T.density)
							H.forceMove(T)
							to_chat(H, SPAN_NOTICE("You blink to [T]!"))
							H.visible_message(SPAN_NOTICE("[H] suddenly disappears and reappears!"))
						else
							to_chat(H, SPAN_WARNING("You cannot blink there!"))
							// Refund juice if teleport fails
							H.juice = min(H.max_juice, H.juice + S.juice_cost)
					// End non-projectile spell handling
					if (S.proj_type)
						var/obj/item/projectile/P = new S.proj_type(user.loc)
						if (P)
							var/tgt_zone = H.targeted_organ || "chest"
							process_projectile(P, user, target, tgt_zone, params)

	casting = FALSE

/obj/item/weapon/material/magic/wand/attack(mob/living/M, mob/living/user, var/target_zone)
	afterattack(M, user, TRUE)
	return TRUE

/obj/item/weapon/material/magic/wand/proc/process_projectile(obj/item/projectile/P, mob/user, atom/target, var/target_zone, var/params=null)
	if (!istype(P))
		return FALSE

	if (params)
		P.set_clickpoint(params)

	var/x_offset = 0
	var/y_offset = 0
	if (istype(user, /mob/living/human))
		var/mob/living/human/H = user
		if (H.shock_stage > 120)
			y_offset = rand(-2, 2)
			x_offset = rand(-2, 2)
		else if (H.shock_stage > 70)
			y_offset = rand(-1, 1)
			x_offset = rand(-1, 1)

	return !P.launch(target, user, src, target_zone, x_offset, y_offset)

// Sub-type: Wizard's wand starts with the default kit
/obj/item/weapon/material/magic/wand/wizard
	name = "wizard's wand"
	desc = "Use with care."
