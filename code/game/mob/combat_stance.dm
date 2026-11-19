// Combat stances: a melee swing, punch, kick, grab or shove picks its own body
// part from the attacker's stance, weapon and intent, read against what the
// opponent wears, holds and last did. Manual keeps the zone doll's choice and
// "random" keeps the random toggle. Auto only chooses; it adds no accuracy or
// damage, so every existing hit, miss, armour and block rule still applies.

/mob
	var/combat_stance = COMBAT_STANCE_MANUAL
	var/tmp/last_auto_zone = null
	var/tmp/combat_doll_flash = null
	var/tmp/combat_reason_time = -1000
	// The last attack on this mob: the zone it went for, the attacker's limb
	// that threw it, who (a "\ref" text, never a pointer) and when.
	var/tmp/last_struck_zone = null
	var/tmp/last_struck_limb = null
	var/tmp/last_struck_by = null
	var/tmp/last_struck_time = -1000

var/global/list/combat_stance_order = list(COMBAT_STANCE_MEASURED, COMBAT_STANCE_AGGRESSIVE,
	COMBAT_STANCE_DISARMING, COMBAT_STANCE_LOW, COMBAT_STANCE_GUARDED)

var/global/list/combat_stance_names = list(
	COMBAT_STANCE_MANUAL = "Manual",
	COMBAT_STANCE_MEASURED = "Measured",
	COMBAT_STANCE_AGGRESSIVE = "Aggressive",
	COMBAT_STANCE_DISARMING = "Disarming",
	COMBAT_STANCE_LOW = "Low line",
	COMBAT_STANCE_GUARDED = "Guarded")

var/global/list/combat_stance_blurbs = list(
	COMBAT_STANCE_MANUAL = "You will aim where you choose on the body doll.",
	COMBAT_STANCE_MEASURED = "You will look for gaps in their armour.",
	COMBAT_STANCE_AGGRESSIVE = "You will go for the head.",
	COMBAT_STANCE_DISARMING = "You will go for their weapon hand.",
	COMBAT_STANCE_LOW = "You will go for the legs.",
	COMBAT_STANCE_GUARDED = "You will keep your guard and answer the limb that strikes you.")

// Short HUD label shown on the random/stance button.
var/global/list/combat_stance_labels = list(
	COMBAT_STANCE_MEASURED = "ME",
	COMBAT_STANCE_AGGRESSIVE = "AG",
	COMBAT_STANCE_DISARMING = "DS",
	COMBAT_STANCE_LOW = "LO",
	COMBAT_STANCE_GUARDED = "GU")

// Zones an automatic pick may choose; eyes stay a deliberate aim.
var/global/list/combat_auto_zones = list("head", "mouth", "chest", "groin",
	"l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot")

// What a landed hit on each zone is worth before armour.
var/global/list/combat_zone_payoff = list("head" = 1.3, "mouth" = 0.9, "chest" = 1, "groin" = 0.9,
	"l_arm" = 0.7, "r_arm" = 0.7, "l_hand" = 0.4, "r_hand" = 0.4,
	"l_leg" = 0.75, "r_leg" = 0.75, "l_foot" = 0.35, "r_foot" = 0.35)

var/global/list/combat_random_zones = list("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")

/proc/combat_zone_is_high(zone)
	return zone == "head" || zone == "mouth" || zone == "eyes"

/proc/combat_zone_is_low(zone)
	return zone == "l_leg" || zone == "r_leg" || zone == "l_foot" || zone == "r_foot" || zone == "groin"

/proc/combat_zone_is_limb(zone)
	return zone == "l_arm" || zone == "r_arm" || zone == "l_leg" || zone == "r_leg"

/proc/combat_hand_arm(hand_zone)
	return hand_zone == "l_hand" ? "l_arm" : "r_arm"

/proc/valid_combat_stance(stance)
	return stance == COMBAT_STANCE_MANUAL || (stance in combat_stance_order)

// The zone an attack of `kind` on `target` goes for. Random and Manual work as
// before; any other stance scores the zones and picks one.
/mob/proc/resolve_attack_zone(mob/living/target, obj/item/weapon, kind = COMBAT_ATTACK_WEAPON)
	if (targeted_organ == "random")
		if (kind == COMBAT_ATTACK_SHOVE)
			return "random"
		return pick(combat_random_zones)
	if (!combat_stance_active() || target == src || !ishuman(target) || a_intent == I_HELP)
		return targeted_organ
	var/zone = choose_combat_zone(target, weapon, kind)
	return zone ? zone : targeted_organ

/mob/proc/combat_stance_active()
	return combat_stance && combat_stance != COMBAT_STANCE_MANUAL

// Records an attack this mob just received, so it can be read back.
/mob/proc/note_struck_by(mob/attacker, zone, limb)
	if (!attacker || attacker == src)
		return
	last_struck_zone = zone
	last_struck_limb = limb
	last_struck_by = "\ref[attacker]"
	last_struck_time = world.time

// The limb an attacker throws a hand attack with: the active hand's arm.
/mob/proc/attacking_arm()
	return hand ? "l_arm" : "r_arm"

// TRUE when `opponent` attacked this mob within the read window.
/mob/proc/recently_struck_by(mob/opponent)
	return opponent && last_struck_by == "\ref[opponent]" && world.time - last_struck_time <= COMBAT_READ_WINDOW

/mob/proc/choose_combat_zone(mob/living/human/target, obj/item/weapon, kind)
	var/list/scores = combat_zone_scores(target, weapon, kind)
	if (!scores || !scores.len)
		return null
	var/zone = pick_combat_zone(scores, combat_read_skill(target, weapon))
	last_auto_zone = zone
	flash_combat_zone(zone)
	combat_stance_reason(target, zone, weapon, kind)
	return zone

// Weighted pick. A higher read skill sharpens the weights toward the best zone.
/proc/pick_combat_zone(list/scores, read_skill)
	var/sharpness = 1 + 2 * read_skill
	var/total = 0
	var/list/weights = list()
	for (var/zone in scores)
		var/w = scores[zone] > 0 ? scores[zone] ** sharpness : 0
		weights[zone] = w
		total += w
	if (total <= 0)
		return null
	var/roll = rand() * total
	for (var/zone in weights)
		roll -= weights[zone]
		if (roll <= 0)
			return zone
	return weights[weights.len]

// How well this attacker reads a fight: dexterity and weapon skill, tilted by
// the strength/dexterity contest against the target (physical_contest.dm).
/mob/proc/combat_read_skill(mob/living/target, obj/item/weapon)
	return 1

/mob/living/human/combat_read_skill(mob/living/target, obj/item/weapon)
	var/skill = max(0.1, getStatCoeff("dexterity"))
	if (weapon && ("stat" in weapon.vars) && istext(weapon.vars["stat"]))
		var/weapon_skill = getStatCoeff(weapon.vars["stat"])
		if (weapon_skill)
			skill = (skill + weapon_skill) / 2
	skill *= physical_contest_ratio(src, target, 0, 1)
	return clamp(skill, 0.25, 3)

// Scores every zone the attack can reach: hit chance x damage that gets past
// armour x what the zone is worth x stance weight x openings read on the target.
/mob/proc/combat_zone_scores(mob/living/human/target, obj/item/weapon, kind)
	if (!istype(target))
		return null
	. = list()
	if (kind == COMBAT_ATTACK_GRAB || kind == COMBAT_ATTACK_SHOVE)
		var/hand_zone = combat_weapon_hand(target)
		if (hand_zone && (kind == COMBAT_ATTACK_GRAB || combat_stance == COMBAT_STANCE_DISARMING))
			.[hand_zone] = 1
		else
			.["chest"] = 1
		return .
	var/sure_hit = target.lying || target.buckled
	for (var/obj/item/weapon/grab/G in target.grabbed_by)
		if (G.state >= GRAB_AGGRESSIVE)
			sure_hit = TRUE
	var/striking = kind == COMBAT_ATTACK_WEAPON && weapon
	var/blunt = striking && !weapon.edge && !weapon.sharp
	var/piercing = striking && weapon.sharp && !weapon.edge
	var/edged = striking && weapon.edge
	var/pen = striking ? weapon.armor_penetration : 0
	var/read = recently_struck_by(target)
	for (var/zone in combat_auto_zones)
		var/obj/item/organ/external/part = target.get_organ(check_zone(zone))
		if (!part || part.is_stump())
			continue
		if (kind == COMBAT_ATTACK_KICK && combat_zone_is_high(zone) && !target.lying)
			continue
		var/score = combat_zone_payoff[zone]
		// Hit chance (human_defense.dm hit_with_weapon, human_attackhand.dm dodges).
		if (!sure_hit)
			if (kind == COMBAT_ATTACK_WEAPON)
				if (combat_zone_is_high(zone))
					score *= 0.82
				else if (combat_zone_is_limb(zone))
					score *= 0.85
				else if (zone != "chest" && zone != "groin")
					score *= 0.675
			else if (kind == COMBAT_ATTACK_PUNCH && zone != "chest")
				score *= 1 - physical_contest_chance(15, physical_contest_ratio(target, src, 0, 1)) / 100
		// Damage that gets through: expected run_armor_check outcome is 1 - armour.
		var/armour = clamp(target.getarmor_organ(part, "melee") - pen, 0, 95) / 100
		score *= piercing ? (1 - armour) ** 1.5 : (1 - armour)
		// Weapon kinds.
		if (blunt && combat_zone_is_high(zone))
			score *= zone == "head" ? 1.3 : 1.2
		if (edged && combat_zone_is_limb(zone))
			score *= 1.25
		if (piercing && (zone == "chest" || zone == "groin"))
			score *= 1.15
		if (kind == COMBAT_ATTACK_PUNCH && combat_zone_is_high(zone) && armour >= 0.2)
			score *= 0.6 // a bare fist on a helmet hurts the fist (punch_injury.dm)
		if (striking && a_intent == I_DISARM)
			if (combat_zone_is_limb(zone))
				score *= 1.5 // striking to cripple: joints
			else if (combat_zone_is_high(zone))
				score *= 0.7
		score *= combat_stance_weight(zone, target)
		score *= combat_opening(zone, target, read)
		if (score > 0)
			.[zone] = score

// The hand holding something that can be knocked away, preferring the active one.
/proc/combat_weapon_hand(mob/living/human/target)
	var/list/order = target.hand ? list("l_hand", "r_hand") : list("r_hand", "l_hand")
	for (var/hand_zone in order)
		var/obj/item/I = hand_zone == "l_hand" ? target.l_hand : target.r_hand
		if (I && !istype(I, /obj/item/weapon/grab) && I.can_be_knocked_from_hand(target))
			return hand_zone
	return null

/mob/proc/combat_stance_weight(zone, mob/living/human/target)
	switch (combat_stance)
		if (COMBAT_STANCE_AGGRESSIVE)
			if (zone == "head")
				return 2.5
			if (zone == "mouth")
				return 2
			if (zone == "chest")
				return 0.8
			if (zone == "groin")
				return 0.6
			return 0.4
		if (COMBAT_STANCE_DISARMING)
			var/weapon_hand = combat_weapon_hand(target)
			if (!weapon_hand)
				return 1
			if (zone == weapon_hand)
				var/obj/item/I = weapon_hand == "l_hand" ? target.l_hand : target.r_hand
				return I && I.grip_tightened ? 3 : 6
			if (zone == combat_hand_arm(weapon_hand))
				return 2
			return 0.4
		if (COMBAT_STANCE_LOW)
			if (zone == "l_leg" || zone == "r_leg")
				return 2.5
			if (zone == "l_foot" || zone == "r_foot")
				return 1.5
			if (zone == "groin")
				return 1
			return 0.3
		if (COMBAT_STANCE_GUARDED)
			if (zone == "chest")
				return 1.5
			if (zone == "groin")
				return 1
			if (zone == "head")
				return 0.5
			if (combat_zone_is_limb(zone))
				return 0.6
			return 0.3
	return 1

// Openings read on the target: where their last attack on you went, what they
// are reaching with, and which side a shield covers.
/mob/proc/combat_opening(zone, mob/living/human/target, read)
	. = 1
	if (read)
		if (combat_zone_is_low(last_struck_zone) && (zone == "head" || zone == "mouth"))
			. *= 1.3
		else if (combat_zone_is_high(last_struck_zone) && (zone == "l_leg" || zone == "r_leg" || zone == "l_foot" || zone == "r_foot"))
			. *= 1.3
		if (combat_stance == COMBAT_STANCE_GUARDED && last_struck_limb)
			if (zone == last_struck_limb)
				. *= 6
			else if ((last_struck_limb == "l_arm" && zone == "l_hand") || (last_struck_limb == "r_arm" && zone == "r_hand"))
				. *= 3
	if ((target.a_intent == I_GRAB || target.a_intent == I_DISARM) && (zone == "l_arm" || zone == "r_arm" || zone == "l_hand" || zone == "r_hand"))
		. *= 1.25
	for (var/hand_zone in list("l_hand", "r_hand"))
		var/obj/item/I = hand_zone == "l_hand" ? target.l_hand : target.r_hand
		if (istype(I, /obj/item/weapon/shield) && (zone == hand_zone || zone == combat_hand_arm(hand_zone)))
			. *= 0.5

// Occasional short reason, at most every 5 seconds, so players learn the matchups.
/mob/proc/combat_stance_reason(mob/living/human/target, zone, obj/item/weapon, kind)
	if (!client || world.time - combat_reason_time < 50 || !prob(35))
		return
	var/part = parse_zone(zone)
	var/msg = null
	if (combat_stance == COMBAT_STANCE_GUARDED && recently_struck_by(target) && (zone == last_struck_limb || zone == "l_hand" && last_struck_limb == "l_arm" || zone == "r_hand" && last_struck_limb == "r_arm"))
		msg = "You answer the [part] that struck you."
	else if (combat_stance == COMBAT_STANCE_DISARMING && zone == combat_weapon_hand(target))
		msg = "You go for [target]'s weapon hand."
	else
		var/obj/item/organ/external/part_organ = target.get_organ(check_zone(zone))
		if (part_organ && target.getarmor_organ(part_organ, "melee") < 10 && target.getarmor_organ(target.get_organ("chest"), "melee") >= 30)
			msg = "You aim for [target]'s unprotected [part]."
	if (msg)
		combat_reason_time = world.time
		to_chat(src, SPAN_NOTICE(msg))

// Shows an automatic pick on the zone doll for a moment.
/mob/proc/flash_combat_zone(zone)
	if (!client || !HUDneed)
		return
	var/obj/screen/doll = HUDneed["damage zone"]
	if (!doll)
		return
	combat_doll_flash = zone
	doll.update_icon()
	addtimer(CALLBACK(src, PROC_REF(clear_combat_zone_flash), zone), COMBAT_DOLL_FLASH_TIME)

/mob/proc/clear_combat_zone_flash(zone)
	if (QDELETED(src) || combat_doll_flash != zone)
		return
	combat_doll_flash = null
	if (HUDneed && HUDneed["damage zone"])
		var/obj/screen/doll = HUDneed["damage zone"]
		doll.update_icon()

// The doll overlay for an automatic pick, drawn over the normal selection.
/proc/combat_doll_flash_image(icon/doll_icon, zone)
	var/image/flash = image(doll_icon, "[zone]")
	flash.color = "#ffb000"
	return flash

/mob/proc/set_combat_stance(stance, silent = FALSE)
	if (!valid_combat_stance(stance))
		return FALSE
	combat_stance = stance
	if (!silent)
		to_chat(src, SPAN_WARNING("[combat_stance_names[stance]] stance. [combat_stance_blurbs[stance]]"))
	update_combat_stance_button()
	return TRUE

// Choosing a zone on the doll or by hotkey takes manual control again.
/mob/proc/combat_stance_doll_clicked()
	if (combat_stance_active())
		set_combat_stance(COMBAT_STANCE_MANUAL)

/mob/proc/update_combat_stance_button()
	if (HUDneed && HUDneed["random damage zone"])
		var/obj/screen/B = HUDneed["random damage zone"]
		B.update_icon()

/mob/living/human/verb/choose_combat_stance()
	set name = "Combat Stance"
	set desc = "Choose how your attacks pick where to strike."
	set category = "IC"
	var/list/options = list()
	for (var/stance in list(COMBAT_STANCE_MANUAL) + combat_stance_order)
		options[combat_stance_names[stance]] = stance
	var/choice = input(src, "How should your attacks choose where to strike?", "Combat Stance", combat_stance_names[combat_stance]) as null|anything in options
	if (!choice || QDELETED(src))
		return
	if (targeted_organ == "random")
		var/obj/screen/zone_sel_random/B = HUDneed ? HUDneed["random damage zone"] : null
		targeted_organ = istype(B) && B.previous_s ? B.previous_s : "chest"
		if (HUDneed && HUDneed["damage zone"])
			var/obj/screen/doll = HUDneed["damage zone"]
			doll.update_icon()
	set_combat_stance(options[choice])

// One line for examine: a stance others can read and counter.
/mob/living/human/proc/combat_stance_examine_line(datum/gender/T)
	switch (combat_stance)
		if (COMBAT_STANCE_MEASURED)
			return "[T.He] [T.is] watching for an opening."
		if (COMBAT_STANCE_AGGRESSIVE)
			return "[T.He] [T.is] squared up to go for the head."
		if (COMBAT_STANCE_DISARMING)
			return "[T.He] [T.is] eyeing the hands of anyone armed."
		if (COMBAT_STANCE_LOW)
			return "[T.He] [T.is] in a low stance, watching the legs."
		if (COMBAT_STANCE_GUARDED)
			return "[T.He] [T.is] holding a tight guard."
	return null
