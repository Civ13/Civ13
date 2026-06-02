// ============================================================
// WAND COMPONENT SYSTEM
// magic_wands_parts.dm
//
// Modular wand assembly: Wood + Core + Length = custom wand.
// Each combination produces a unique playstyle, trading off
// cast speed, juice cost, melee capability, and side-effects.
//
// See /obj/item/weapon/material/magic/wand/crafted for the
// assembled type. Pre-made named variants are at the bottom.
// ============================================================


// ============================================================
//  COMPONENT CONSTANTS
// ============================================================

// -- Wood types (chassis) --
#define WAND_WOOD_PINE        "pine"        // Baseline. Mild splinter on overcast.
#define WAND_WOOD_MDF         "mdf"         // Cheap juice; dissolves when wet.
#define WAND_WOOD_BALSA       "balsa"       // Fast but fragile; snaps on melee.
#define WAND_WOOD_SNOOKER     "snooker"     // Slow caster; excellent bludgeon.
#define WAND_WOOD_FIBREGLASS  "fibreglass"  // Whippy fast; lashes you on overcast.
#define WAND_WOOD_BOGOAK      "bogoak"      // Elemental discount; emits stink.

// -- Core types (engine) --
#define WAND_CORE_BADGER   "badger"    // Combat boosted; defensive penalised.
#define WAND_CORE_PIGEON   "pigeon"    // Movement near-instant; panic auto-blink.
#define WAND_CORE_COPPER   "copper"    // -25% all costs; lethal overcast.
#define WAND_CORE_LINT     "lint"      // Wildly random juice cost per cast.
#define WAND_CORE_ASBESTOS "asbestos"  // Fire immunity; passive toxin damage.
#define WAND_CORE_FOX      "fox"       // Silent casts; +2 s cast delay.

// -- Length types (form factor) --
#define WAND_LENGTH_STUBBY      "stubby"       // Tiny, fast-draw, -2 tile range.
#define WAND_LENGTH_STANDARD    "standard"     // Balanced baseline.
#define WAND_LENGTH_OVERCOMP    "overcomp"     // Long, +3 range, -15% proj cost.
#define WAND_LENGTH_TELESCOPIC  "telescopic"   // Alt-click to collapse/extend; 10% collapse per cast.

// -- Spell categories (for targeted bonuses/penalties) --
#define WAND_CAT_COMBAT    "combat"    // Pushum, Sliceum, Explodus, Zappus, Burnus, Painum, Deadum
#define WAND_CAT_DEFENSIVE "defensive" // Blockum, Wallus, Fixae
#define WAND_CAT_MOVEMENT  "movement"  // Floatus, Blinkae


// ============================================================
//  EXTEND BASE WAND TYPE WITH COMPONENT VARS
//  These are readable on all wands; only crafted uses them.
// ============================================================

/obj/item/weapon/material/magic/wand
	// Component identifiers
	var/wand_wood           = WAND_WOOD_PINE
	var/wand_core           = WAND_CORE_PIGEON
	var/wand_length         = WAND_LENGTH_STANDARD

	// Derived modifiers — recomputed by apply_*_stats()
	var/cast_time_mod       = 1.0   // < 1 faster, > 1 slower
	var/juice_cost_mod      = 1.0   // < 1 cheaper, > 1 costlier
	var/wand_melee_force    = WEAPON_FORCE_WEAK  // melee brute force
	var/misfire_chance      = 0     // % chance of fizzle before cast
	var/range_bonus         = 0     // tile range modifier (Blinkae etc.)

	// Wood flags
	var/splinter_chance     = 0     // % splinter on overcast (Pine)
	var/snaps_on_melee      = FALSE // wand destroyed on melee hit (Balsa)
	var/lash_on_overcast    = FALSE // caster lacerates on overcast (Fibreglass)
	var/emit_stink          = FALSE // passive stink cloud (Bog Oak)
	var/bog_elem_discount   = FALSE // -20% juice on elemental spells (Bog Oak)
	var/wand_wet            = FALSE // MDF swelling state
	var/wand_wet_timer      = 0     // ds counter for drying

	// Core flags
	var/silent_cast         = FALSE // suppress VFX/SFX (Fox)
	var/fox_extra_cast_ds   = 0     // extra deciseconds on cast (Fox: +20 ds = 2 s)
	var/panic_blink         = FALSE // auto-blink at critical HP (Pigeon)
	var/overcast_lethal     = FALSE // stun + fire on overcast (Copper)
	var/fireproof           = FALSE // suppress on_fire while held (Asbestos)
	var/asbestos_tox        = FALSE // passive toxin drip (Asbestos)
	var/lint_random_cost    = FALSE // random cost each cast (Lint)
	var/badger_combat       = FALSE // combat spells 20% faster (Badger)
	var/badger_defensive    = FALSE // defensive spells 50% costlier (Badger)
	var/pigeon_movement     = FALSE // movement spells near-instant (Pigeon)

	// Length flags
	var/fast_draw           = FALSE // no equip delay (Stubby)
	var/overcomp_proj_disc  = FALSE // -15% juice on projectile spells (Overcomp)
	var/telescopic_extended = FALSE // current collapse state (Telescopic)

	// Internal timers for process()
	var/stink_timer         = 0
	var/tox_timer           = 0


// ============================================================
//  CRAFTED WAND — THE MODULAR SUBTYPE
// ============================================================

/obj/item/weapon/material/magic/wand/crafted
	name = "crafted wand"
	desc = "A wand assembled from whatever was lying around. It hums with uncertain potential."

/obj/item/weapon/material/magic/wand/crafted/New()
	..()
	apply_wood_stats()
	apply_core_stats()
	apply_length_stats()
	var/default_name = (name == "crafted wand" || name == null || name == "")
	var/default_desc = (desc == "A wand assembled from whatever was lying around. It hums with uncertain potential." || desc == null || desc == "")
	if (default_name || default_desc)
		update_name_and_desc()


// ============================================================
//  APPLY COMPONENT STATS
// ============================================================

/// Apply wood-specific base modifiers. Call after setting wand_wood.
/obj/item/weapon/material/magic/wand/crafted/proc/apply_wood_stats()
	// Reset wood-derived state to neutral
	cast_time_mod    = 1.0
	juice_cost_mod   = 1.0   // Reset here; apply_core_stats multiplies on top
	wand_melee_force = WEAPON_FORCE_WEAK
	misfire_chance   = 0
	splinter_chance  = 0
	snaps_on_melee   = FALSE
	lash_on_overcast = FALSE
	emit_stink       = FALSE
	bog_elem_discount = FALSE

	switch (wand_wood)
		if (WAND_WOOD_PINE)
			// Baseline — no bonuses, no penalties.
			// 5% chance of splinter to active hand when overcasting.
			splinter_chance = 5

		if (WAND_WOOD_MDF)
			// Conductive cheap material: -10% juice cost.
			// When wet: cast time doubled, +20% misfire chance.
			// Wetness penalties applied dynamically in get_effective_*.
			juice_cost_mod = 0.9

		if (WAND_WOOD_BALSA)
			// Light as air: -40% cast time, +20% juice cost, 0 melee, snaps.
			cast_time_mod    = 0.6
			juice_cost_mod   = 1.2
			wand_melee_force = 0
			snaps_on_melee   = TRUE

		if (WAND_WOOD_SNOOKER)
			// Heavy and unbalanced: +20% cast time, brutal melee.
			cast_time_mod    = 1.2
			wand_melee_force = WEAPON_FORCE_LETHAL

		if (WAND_WOOD_FIBREGLASS)
			// Incredibly whippy: -25% cast time, lashes caster on overcast.
			cast_time_mod    = 0.75
			lash_on_overcast = TRUE

		if (WAND_WOOD_BOGOAK)
			// Soggy and elemental: -20% elemental juice, passive stink.
			bog_elem_discount = TRUE
			emit_stink        = TRUE


/// Apply core-specific modifiers. Call after setting wand_core.
/obj/item/weapon/material/magic/wand/crafted/proc/apply_core_stats()
	// Reset core-derived state to neutral
	silent_cast      = FALSE
	fox_extra_cast_ds = 0
	panic_blink      = FALSE
	overcast_lethal  = FALSE
	fireproof        = FALSE
	asbestos_tox     = FALSE
	lint_random_cost = FALSE
	badger_combat    = FALSE
	badger_defensive = FALSE
	pigeon_movement  = FALSE

	switch (wand_core)
		if (WAND_CORE_BADGER)
			// Aggressive: combat spells 20% faster; defensive spells 50% costlier.
			badger_combat    = TRUE
			badger_defensive = TRUE

		if (WAND_CORE_PIGEON)
			// Flighty: movement spells cast near-instantly; panic auto-blink at low HP.
			pigeon_movement = TRUE
			panic_blink     = TRUE

		if (WAND_CORE_COPPER)
			// Efficient but dangerous: -25% all juice costs; lethal short on overcast.
			juice_cost_mod  = max(0.1, juice_cost_mod * 0.75)
			overcast_lethal = TRUE

		if (WAND_CORE_LINT)
			// Chaos: every cast rolls 0x or 2x cost at random.
			lint_random_cost = TRUE

		if (WAND_CORE_ASBESTOS)
			// Fire immunity while held; slow passive toxin damage.
			fireproof    = TRUE
			asbestos_tox = TRUE

		if (WAND_CORE_FOX)
			// Silent casts with no visual/audio cues; +2 s cast time to "sneak" magic out.
			silent_cast       = TRUE
			fox_extra_cast_ds = 20  // 2 seconds in deciseconds


/// Apply length-specific modifiers. Call after setting wand_length.
/obj/item/weapon/material/magic/wand/crafted/proc/apply_length_stats()
	// Reset length-derived state to neutral
	fast_draw         = FALSE
	range_bonus       = 0
	overcomp_proj_disc = FALSE

	switch (wand_length)
		if (WAND_LENGTH_STUBBY)
			// Pocket-sized: tiny w_class, fast-draw, -2 tile range.
			w_class    = ITEM_SIZE_TINY
			slot_flags = SLOT_BELT | SLOT_POCKET
			range_bonus = -2
			fast_draw   = TRUE

		if (WAND_LENGTH_STANDARD)
			// No-frills baseline.
			w_class    = ITEM_SIZE_SMALL
			slot_flags = SLOT_BELT
			range_bonus = 0

		if (WAND_LENGTH_OVERCOMP)
			// Long sniper barrel: big, +3 range, -15% targeted projectile cost.
			w_class    = ITEM_SIZE_NORMAL
			slot_flags = 0  // Too big for belt or pockets
			range_bonus = 3
			overcomp_proj_disc = TRUE

		if (WAND_LENGTH_TELESCOPIC)
			// Starts collapsed. Alt-click to toggle. 10% chance to collapse per cast.
			telescopic_extended = FALSE
			_update_telescopic_length()


/// Internal helper — syncs telescopic wand's length stats to its current state.
/obj/item/weapon/material/magic/wand/crafted/proc/_update_telescopic_length()
	if (telescopic_extended)
		// Extended acts like Overcompensator
		w_class    = ITEM_SIZE_NORMAL
		slot_flags = 0
		range_bonus = 3
		overcomp_proj_disc = TRUE
	else
		// Collapsed acts like Stubby
		w_class    = ITEM_SIZE_TINY
		slot_flags = SLOT_BELT | SLOT_POCKET
		range_bonus = -2
		overcomp_proj_disc = FALSE


// ============================================================
//  NAME AND DESCRIPTION UPDATE
// ============================================================

/// Regenerates the wand's name and desc from its current components.
/obj/item/weapon/material/magic/wand/crafted/proc/update_name_and_desc()
	var/wood_str = ""
	switch (wand_wood)
		if (WAND_WOOD_PINE)       wood_str = "distressed pine"
		if (WAND_WOOD_MDF)        wood_str = "MDF"
		if (WAND_WOOD_BALSA)      wood_str = "balsa"
		if (WAND_WOOD_SNOOKER)    wood_str = "snooker cue"
		if (WAND_WOOD_FIBREGLASS) wood_str = "fibreglass"
		if (WAND_WOOD_BOGOAK)     wood_str = "bog oak"

	var/core_str = ""
	switch (wand_core)
		if (WAND_CORE_BADGER)   core_str = "badger hair"
		if (WAND_CORE_PIGEON)   core_str = "pigeon feather"
		if (WAND_CORE_COPPER)   core_str = "copper wire"
		if (WAND_CORE_LINT)     core_str = "pocket lint"
		if (WAND_CORE_ASBESTOS) core_str = "asbestos fibre"
		if (WAND_CORE_FOX)      core_str = "fox fur"

	var/len_str = ""
	switch (wand_length)
		if (WAND_LENGTH_STUBBY)    len_str = "stubby"
		if (WAND_LENGTH_STANDARD)  len_str = "standard"
		if (WAND_LENGTH_OVERCOMP)  len_str = "overcompensating"
		if (WAND_LENGTH_TELESCOPIC)
			len_str = telescopic_extended ? "extended telescopic" : "collapsed telescopic"

	if (name == "crafted wand" || name == null || name == "")
		name = "[len_str] [wood_str] wand"
	if (desc == "A wand assembled from whatever was lying around. It hums with uncertain potential." || desc == null || desc == "")
		desc = "A [len_str] wand made of [wood_str] with a [core_str] core. It crackles with dubious magical potential."


// ============================================================
//  EFFECTIVE STAT CALCULATORS
// ============================================================

/// Returns the actual cast time (deciseconds) to use for spell S on this wand.
/obj/item/weapon/material/magic/wand/crafted/proc/get_effective_cast_time(datum/spell/S)
	var/mod = cast_time_mod

	// Badger core: combat spells 20% faster
	if (badger_combat && _is_combat_spell(S))
		mod *= 0.8

	// Pigeon core: movement spells near-instant (10% of normal)
	if (pigeon_movement && _is_movement_spell(S))
		mod *= 0.1

	// MDF wet: cast time doubled
	if (wand_wood == WAND_WOOD_MDF && wand_wet)
		mod *= 2.0

	var/eff = max(1, round(S.cast_time * mod))

	// Fox fur: +2 s stealth delay on top
	eff += fox_extra_cast_ds

	return eff


/// Returns the actual juice cost to use for spell S on this wand.
/obj/item/weapon/material/magic/wand/crafted/proc/get_effective_juice_cost(datum/spell/S)
	var/mod = juice_cost_mod

	// Badger core: defensive spells cost 50% more
	if (badger_defensive && _is_defensive_spell(S))
		mod *= 1.5

	// Bog Oak: elemental spells cost 20% less
	if (bog_elem_discount && _is_elemental_spell(S))
		mod *= 0.8

	// Overcompensator: projectile spells cost 15% less
	if (overcomp_proj_disc && S.proj_type)
		mod *= 0.85

	// Lint core: random modifier — 0x (free!) or 2x (ouch)
	if (lint_random_cost)
		mod *= pick(0, 2.0)

	// MDF wet: juice cost doubled on top of other modifiers
	if (wand_wood == WAND_WOOD_MDF && wand_wet)
		mod *= 2.0

	return max(0, round(S.juice_cost * mod))


/// Returns the maximum tile range for targeted spells (default 7).
/obj/item/weapon/material/magic/wand/crafted/proc/get_max_range()
	return max(1, 7 + range_bonus)


// ============================================================
//  SPELL CATEGORY HELPERS
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/proc/_is_combat_spell(datum/spell/S)
	switch (S.name)
		if ("Pushum", "Sliceum", "Explodus", "Zappus", "Burnus", "Painum", "Deadum")
			return TRUE
	return FALSE

/obj/item/weapon/material/magic/wand/crafted/proc/_is_defensive_spell(datum/spell/S)
	switch (S.name)
		if ("Blockum", "Wallus", "Fixae")
			return TRUE
	return FALSE

/obj/item/weapon/material/magic/wand/crafted/proc/_is_movement_spell(datum/spell/S)
	switch (S.name)
		if ("Floatus", "Blinkae")
			return TRUE
	return FALSE

/obj/item/weapon/material/magic/wand/crafted/proc/_is_elemental_spell(datum/spell/S)
	// Elemental spells include the "gross" or environmental force spells.
	switch (S.name)
		if ("Stinkaeum", "Floatus", "Burnus")
			return TRUE
	return FALSE


// ============================================================
//  OVERCAST HANDLER
// ============================================================

/// Called when a cast drains juice below 0. Applies wood/core overcast penalties.
/obj/item/weapon/material/magic/wand/crafted/proc/on_overcast(mob/living/human/H)
	if (!H) return

	// Pine: 5% chance for a splinter to the active hand
	if (wand_wood == WAND_WOOD_PINE && prob(splinter_chance))
		to_chat(H, SPAN_DANGER("You get a splinter from \the [src]! Ow!"))
		var/target_hand = (H.l_hand == src) ? "l_hand" : "r_hand"
		H.apply_damage(3, BRUTE, target_hand)
	// Fibreglass: wand snaps back and lacerates the caster's arm
	if (lash_on_overcast)
		to_chat(H, SPAN_DANGER("\The [src] snaps back violently and lacerates your arm!"))
		H.visible_message(SPAN_DANGER("[H]'s wand whips back and cuts their arm!"))
		// Sharp+edge damage = laceration (bleeding)
		H.apply_damage(8, BRUTE, pick("l_hand", "r_hand"), 0, null, TRUE, TRUE)

	// Copper wire: catastrophic short-circuit — stun + ignition
	if (overcast_lethal)
		to_chat(H, SPAN_DANGER("The copper wiring in \the [src] short-circuits! Electricity surges through you!"))
		H.visible_message(SPAN_DANGER("[H]'s wand erupts in a shower of sparks and shorts out!"))
		playsound(H.loc, 'sound/weapons/magic/spell3.ogg', 80, TRUE)
		H.apply_effects(stun = 5)   // 5-second stun
		H.fire_stacks += 3
		H.IgniteMob()


// ============================================================
//  WET THE WAND (called by rain/mop systems)
// ============================================================

/// Mark this MDF wand as soaked. Can be called from weather or mop bucket code.
/obj/item/weapon/material/magic/wand/crafted/proc/get_wet()
	if (wand_wood != WAND_WOOD_MDF)
		return
	if (!wand_wet)
		wand_wet = TRUE
		wand_wet_timer = 0
		if (istype(loc, /mob))
			to_chat(loc, SPAN_WARNING("\The [src] soaks up moisture. It begins to swell alarmingly."))


// ============================================================
//  AFTERATTACK — FULL CRAFTED CASTING OVERRIDE
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!user || !target) return
	if (casting) return

	// MDF wet check: soak the wand if the caster is outside in precipitation.
	// Checked at cast time so it catches anyone already standing in rain,
	// not just people present when the weather first changed.
	if (wand_wood == WAND_WOOD_MDF && !wand_wet)
		var/area/F_area = get_area(user)
		if (F_area && F_area.location == AREA_OUTSIDE && is_wet_weather_icon(F_area.icon_state))
			get_wet()

	// Skill gate
	if (ishuman(user))
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

	// Calculate effective stats for this cast
	var/eff_cast_time  = get_effective_cast_time(S)
	var/eff_juice_cost = get_effective_juice_cost(S)

	// --- PRE-CAST CHECKS ---

	// Misfire check (always, amplified by MDF wet)
	var/total_misfire = misfire_chance
	if (wand_wood == WAND_WOOD_MDF && wand_wet)
		total_misfire += 20
	if (prob(total_misfire))
		to_chat(user, SPAN_WARNING("\The [src] fizzles! The spell half-forms and dissipates uselessly."))
		playsound(user.loc, 'sound/items/matchstick_lit.ogg', 40, TRUE)
		return

	// Telescopic collapse check — 10% chance to collapse mid-cast, fizzling spell
	if (wand_length == WAND_LENGTH_TELESCOPIC && telescopic_extended && prob(10))
		telescopic_extended = FALSE
		_update_telescopic_length()
		update_name_and_desc()
		to_chat(user, SPAN_WARNING("\The [src] collapses back on itself mid-cast! The spell fizzles!"))
		return

	// Juice check — must have at least 1 juice to attempt a cast
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.juice <= 0)
			to_chat(user, SPAN_WARNING("You don't have enough magical juice to cast this spell!"))
			return

	// --- CASTING ---
	casting = TRUE

	if (do_after(user, eff_cast_time, target))
		if (!src || !user || !target || !S)
			casting = FALSE
			return

		if (ishuman(user))
			var/mob/living/human/H = user

			if (H.juice > 0 && user.get_active_hand() == src)
				// Deduct juice; flag overcast if we go negative
				H.juice -= eff_juice_cost
				var/overcasting = (H.juice < 0)
				if (overcasting)
					H.juice = 0  // Floor juice at 0

				// Cast feedback — suppressed for Fox fur silent cast
				if (!silent_cast)
					H.show_chat_overlay(H, "<i>[S.name]!</i>", "#dea30d")
					if (S.sound_effect)
						playsound(user.loc, S.sound_effect, 75, FALSE)
					H.visible_message("<span style=color:'#dea30d'><b>[user]</b> uses <i>[S.name]!</i></span>")
					playsound(user.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)

				// Bobby wizard witness alert
				if (S.skill_level >= 80)
					for (var/mob/living/simple_animal/wizard/bobby/B in view(7, H))
						B.witness_spell(H, S)

				// Trigger overcast penalties if juice went below 0
				if (overcasting)
					on_overcast(H)

				spawn(5)
					if (!src || !user || !target || !S)
						casting = FALSE
						return

					// --- NON-PROJECTILE SPELL HANDLING ---

					if (S.name == "Wallus")
						var/turf/T = get_turf(target)
						if (T && !T.density)
							new /obj/structure/barricade/magic(T)
							T.visible_message(SPAN_NOTICE("A magical barricade suddenly appears!"))
						else
							to_chat(H, SPAN_WARNING("You cannot summon a barricade there!"))
							H.juice = min(H.max_juice, H.juice + eff_juice_cost)

					else if (S.name == "Lightus")
						new /obj/effect/magic_light_effect(H, H)
						to_chat(H, SPAN_NOTICE("You glow with a soft magical light!"))

					else if (S.name == "Blinkae")
						var/turf/T = get_turf(target)
						var/max_range = get_max_range()
						if (T && get_dist(H, T) <= max_range && !T.density)
							H.forceMove(T)
							to_chat(H, SPAN_NOTICE("You blink to [T]!"))
							H.visible_message(SPAN_NOTICE("[H] suddenly disappears and reappears!"))
						else
							to_chat(H, SPAN_WARNING("You cannot blink there!"))
							H.juice = min(H.max_juice, H.juice + eff_juice_cost)

					// --- PROJECTILE SPELLS ---
					if (S.proj_type)
						var/obj/item/projectile/P = new S.proj_type(user.loc)
						if (P)
							var/tgt_zone = H.targeted_organ || "chest"
							process_projectile(P, user, target, tgt_zone, params)

	casting = FALSE


// ============================================================
//  MELEE ATTACK OVERRIDE (Balsa snap / Snooker bash)
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/attack(mob/living/M, mob/living/user, var/target_zone)
	// Balsa: wand atomically destroys itself on melee contact
	if (snaps_on_melee)
		user.visible_message(SPAN_DANGER("[user] swings \the [src] at [M]... and it snaps clean in half!"))
		to_chat(user, SPAN_DANGER("\The [src] splinters apart in your hand!"))
		playsound(user.loc, 'sound/effects/snap.ogg', 80, TRUE)
		qdel(src)
		return TRUE

	// All other woods: deal melee brute damage instead of casting
	if (wand_melee_force <= 0)
		to_chat(user, SPAN_WARNING("\The [src] is too flimsy to deal any damage in melee!"))
		return TRUE

	M.apply_damage(wand_melee_force, BRUTE, target_zone || "chest")
	M.visible_message(SPAN_DANGER("[user] hits [M] with \the [src]!"))
	playsound(user.loc, hitsound, 75, TRUE)
	return TRUE


// ============================================================
//  ALT-CLICK: TELESCOPIC TOGGLE
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/AltClick(mob/living/user)
	if (wand_length != WAND_LENGTH_TELESCOPIC)
		return ..()
	if (!istype(user, /mob/living/human))
		return
	if (!user.get_active_hand() || user.get_active_hand() != src)
		to_chat(user, SPAN_WARNING("You need to be holding \the [src] to collapse or extend it."))
		return

	telescopic_extended = !telescopic_extended
	_update_telescopic_length()
	update_name_and_desc()

	if (telescopic_extended)
		to_chat(user, SPAN_NOTICE("You extend \the [src] to its full length. It's quite impressive."))
		user.visible_message(SPAN_NOTICE("[user] extends \the [src] to its full length."))
	else
		to_chat(user, SPAN_NOTICE("You collapse \the [src] down to pocket-size."))
		user.visible_message(SPAN_NOTICE("[user] collapses \the [src] with a sharp click."))


// ============================================================
//  EXAMINE: SHOW COMPONENT BREAKDOWN
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/examine(mob/user as mob)
	..()  // Base examine: juice level, active spell, known spells
	if (ishuman(user))
		to_chat(user, SPAN_NOTICE("Wood: <b>[wand_wood]</b> | Core: <b>[wand_core]</b> | Length: <b>[wand_length]</b>"))
		if (wand_wet)
			to_chat(user, SPAN_WARNING("The MDF body has swollen with moisture. It looks very sorry for itself."))
		if (wand_length == WAND_LENGTH_TELESCOPIC)
			var/tele_state = telescopic_extended ? "extended" : "collapsed"
			to_chat(user, SPAN_NOTICE("It is currently <b>[tele_state]</b>. Alt-click to toggle."))


// ============================================================
//  PROCESS: PASSIVE CONTINUOUS EFFECTS
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/process()
	..()  // Base: charge regeneration

	// Determine if a human is holding this wand in their active hand
	var/mob/living/human/holder = null
	if (ishuman(loc))
		var/mob/living/human/H = loc
		if (H.get_active_hand() == src)
			holder = H

	// --- MDF: DRY-OUT TIMER ---
	if (wand_wet)
		wand_wet_timer += 2
		if (wand_wet_timer >= 600)  // 60 seconds to fully dry
			wand_wet = FALSE
			wand_wet_timer = 0
			if (holder)
				to_chat(holder, SPAN_NOTICE("\The [src] has dried out. It's back to its normal, mediocre self."))

	// --- BOG OAK: PASSIVE STINK CLOUD ---
	if (emit_stink && holder)
		stink_timer += 2
		if (stink_timer >= 30)  // Every 3 seconds
			stink_timer = 0
			holder.visible_message(SPAN_NOTICE("[holder] exudes an absolutely revolting smell from \the [src]."))
			for (var/mob/living/M in view(2, holder))
				if (M != holder)
					M.emote("cough")

	// --- ASBESTOS: PASSIVE TOXIN DRIP ---
	if (asbestos_tox && holder)
		tox_timer += 2
		if (tox_timer >= 40)  // 2 tox damage every 4 seconds
			tox_timer = 0
			holder.apply_damage(2, TOX, "chest")

	// --- ASBESTOS: FIRE IMMUNITY (suppress flames while held) ---
	if (fireproof && holder && holder.on_fire)
		holder.on_fire = FALSE
		holder.fire_stacks = min(0, holder.fire_stacks)  // Clamp to ≤ 0 (wet/neutral)

	// --- PIGEON: PANIC BLINK AT CRITICAL HP ---
	if (panic_blink && holder)
		if (holder.health <= (holder.maxHealth * 0.15) && !casting)
			if (prob(5))  // 5% chance per process tick (~0.5 s intervals)
				var/list/candidates = list()
				for (var/turf/T in view(5, holder))
					if (!T.density)
						candidates += T
				if (candidates.len)
					var/turf/dest = pick(candidates)
					holder.visible_message(SPAN_DANGER("[holder]'s wand panics and teleports them wildly!"))
					to_chat(holder, SPAN_WARNING("Your wand panics! It blinks you somewhere — hopefully not into a wall."))
					playsound(holder.loc, 'sound/weapons/magic/spell2.ogg', 60, TRUE)
					holder.forceMove(dest)


// ============================================================
//  PRE-MADE WAND VARIANTS
//  Ready-to-spawn named wand combinations. Add to loot tables,
//  shop inventories, or wizard spawns as desired.
// ============================================================

// ----- The Regulation Wand -----
// Pine + Pigeon Feather + Standard: solid all-rounder with panic escape
/obj/item/weapon/material/magic/wand/crafted/standard
	name = "standard wizard's wand"
	desc = "A standard school-issue wand. Smells of pine resin and floor wax. Reliable, if uninspiring."
	wand_wood   = WAND_WOOD_PINE
	wand_core   = WAND_CORE_PIGEON
	wand_length = WAND_LENGTH_STANDARD

// ----- The Sniper -----
// Fibreglass + Copper Wire + Overcompensator: blazing fast, long-range, cheap — but violent on overcast
/obj/item/weapon/material/magic/wand/crafted/sniper
	wand_wood   = WAND_WOOD_FIBREGLASS
	wand_core   = WAND_CORE_COPPER
	wand_length = WAND_LENGTH_OVERCOMP

// ----- The Mugger -----
// Snooker Cue + Badger Hair + Stubby: fast-draw, awful cast speed, exceptional bludgeoning
/obj/item/weapon/material/magic/wand/crafted/mugger
	wand_wood   = WAND_WOOD_SNOOKER
	wand_core   = WAND_CORE_BADGER
	wand_length = WAND_LENGTH_STUBBY

// ----- The Ghost -----
// Balsa + Fox Fur + Stubby: pocket-sized, invisible lightning casts — but snaps if you sneeze on it
/obj/item/weapon/material/magic/wand/crafted/ghost
	wand_wood   = WAND_WOOD_BALSA
	wand_core   = WAND_CORE_FOX
	wand_length = WAND_LENGTH_STUBBY

// ----- The Gambler -----
// MDF + Pocket Lint + Telescopic: chaotic, cheap, and likely to kill you in the rain
/obj/item/weapon/material/magic/wand/crafted/gambler
	wand_wood   = WAND_WOOD_MDF
	wand_core   = WAND_CORE_LINT
	wand_length = WAND_LENGTH_TELESCOPIC

// ----- The Swamp Thing -----
// Bog Oak + Asbestos Fibre + Overcompensator: long-range elemental supremacy at personal cost
/obj/item/weapon/material/magic/wand/crafted/swamp_thing
	wand_wood   = WAND_WOOD_BOGOAK
	wand_core   = WAND_CORE_ASBESTOS
	wand_length = WAND_LENGTH_OVERCOMP

// ----- The Chaos Stick -----
// MDF + Asbestos Fibre + Stubby: fire-immune, toxin-dripping, swells in rain — pocket chaos
/obj/item/weapon/material/magic/wand/crafted/chaos_stick
	wand_wood   = WAND_WOOD_MDF
	wand_core   = WAND_CORE_ASBESTOS
	wand_length = WAND_LENGTH_STUBBY

// ----- The Coward's Out -----
// Fibreglass + Pigeon Feather + Standard: fastest movement spells in the game, at the cost of pain
/obj/item/weapon/material/magic/wand/crafted/cowards_out
	wand_wood   = WAND_WOOD_FIBREGLASS
	wand_core   = WAND_CORE_PIGEON
	wand_length = WAND_LENGTH_STANDARD
