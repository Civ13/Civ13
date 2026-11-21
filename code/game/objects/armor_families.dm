// Armor families: protection comes from how a piece is built (its family) and
// what it is made of (its tier), never from which culture it looks like.
// Every look within a family and tier protects the same way.
//
// A family piece resists cut, pierce, blunt and arrow hits with
// tier x the family's multiplier for that kind, capped at ARMOR_FAMILY_CAP.
// Its "melee" value (traps, poured liquids, generic attacks) is the mean of
// the three melee kinds. Other keys (gun, bomb, bio...) stay in the armor list.
// Pieces without a family keep reading their armor list (hit_kinds.dm).

#define ARMOR_FAMILY_CAP 95
#define ARMOR_GRADE_CAP 90 // a stock grade never lifts a value past this

var/global/list/armor_family_multipliers = list(
	ARMOR_FAMILY_PADDED = list(HIT_CUT = 1.0, HIT_PIERCE = 0.7, HIT_BLUNT = 1.3, "arrow" = 1.0),
	ARMOR_FAMILY_LEATHER = list(HIT_CUT = 1.2, HIT_PIERCE = 0.7, HIT_BLUNT = 0.7, "arrow" = 0.9),
	ARMOR_FAMILY_LAMELLAR = list(HIT_CUT = 1.2, HIT_PIERCE = 0.8, HIT_BLUNT = 0.9, "arrow" = 1.3),
	ARMOR_FAMILY_MAIL = list(HIT_CUT = 1.4, HIT_PIERCE = 0.8, HIT_BLUNT = 0.5, "arrow" = 0.9),
	ARMOR_FAMILY_PLATE = list(HIT_CUT = 1.3, HIT_PIERCE = 1.3, HIT_BLUNT = 1.0, "arrow" = 1.4))

/obj/item/clothing/var/armor_family = null
/obj/item/clothing/var/armor_tier = 0
// Graded stock (steel_grades.dm): blows by one factor, arrows by another.
/obj/item/clothing/var/armor_blow_grade = 1
/obj/item/clothing/var/armor_arrow_grade = 1
// An under-layer worn beneath other armor only cushions: it keeps its blunt
// value and half its arrow value, and gives nothing against cuts or thrusts.
/obj/item/clothing/var/armor_underlayer = FALSE

// The family value for one kind of hit, or null when the piece has no family
// or the family does not set that kind.
/obj/item/clothing/proc/armor_family_value(type)
	if (!armor_family || armor_tier <= 0)
		return null
	var/list/multipliers = armor_family_multipliers[armor_family]
	if (!multipliers)
		return null
	if (type == "melee")
		return round((armor_family_value(HIT_CUT) + armor_family_value(HIT_PIERCE) + armor_family_value(HIT_BLUNT)) / 3, 1)
	if (!(type in multipliers))
		return null
	// + 0.001: 45 x 1.3 is 58.4999 in floats.
	if (armor_underlayer && (type == HIT_CUT || type == HIT_PIERCE))
		return 0
	var/share = (armor_underlayer && type == "arrow") ? 0.5 : 1
	var/value = min(ARMOR_FAMILY_CAP, round(armor_tier * multipliers[type] * share + 0.001, 1))
	var/grade = type == "arrow" ? armor_arrow_grade : armor_blow_grade
	if (grade > 1)
		value = max(value, min(ARMOR_GRADE_CAP, round(value * grade, 1)))
	return value

// The protection this piece gives against one kind of hit.
/obj/item/clothing/proc/armor_value(type)
	var/value = armor_family_value(type)
	if (!isnull(value))
		return value
	return armor_rating(armor, type)

// The tier a forged piece takes from the metal it was forged from.
/proc/armor_tier_for_stock(obj/item/stack/material/stock)
	if (istype(stock, /obj/item/stack/material/steel))
		return ARMOR_TIER_STEEL
	if (istype(stock, /obj/item/stack/material/iron))
		return ARMOR_TIER_IRON
	if (istype(stock, /obj/item/stack/material/bronze))
		return ARMOR_TIER_BRONZE
	return 0

#undef ARMOR_FAMILY_CAP
#undef ARMOR_GRADE_CAP

////////////////////////////////////////////////////////////////////////////////
// Suits. Weight sits with each type in its apparel file: padded and leather
// 0.2, lamellar 0.5, mail 0.6, plate 1.5, torso-only plate 0.75. Vars set here
// must not also be set there, or the include order would pick the value.

// Padded
/obj/item/clothing/suit/armor/ancient/linen
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_HIDE
// Worn under armor on the uniform: cushions only.
/obj/item/clothing/accessory/armor/padded_jack
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_HIDE
	armor_underlayer = TRUE
// Mail worn on the uniform's armor slot protects as mail.
/obj/item/clothing/accessory/armor/chainmail
	armor_family = ARMOR_FAMILY_MAIL
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/ancient/aztec_harness
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_HIDE

// Leather
/obj/item/clothing/suit/armor/medieval/leather
	armor_family = ARMOR_FAMILY_LEATHER
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/suit/armor/medieval/steppe_leather
	armor_family = ARMOR_FAMILY_LEATHER
	armor_tier = ARMOR_TIER_LACED

// Lamellar and scale
/obj/item/clothing/suit/armor/samurai
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/suit/armor/samurai/warrior
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/ancient/bronze_lamellar
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/suit/armor/ancient/scaled
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/suit/armor/ancient/scale
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/ancient/gator_scale_armor
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/suit/armor/chitin
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_CHITIN
/obj/item/clothing/suit/armor/medieval/varangian
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/medieval/imperial_chinese
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_IRON

// Mail
/obj/item/clothing/suit/armor/ancient/chainmail
	armor_family = ARMOR_FAMILY_MAIL
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/medieval/chainmail
	armor_family = ARMOR_FAMILY_MAIL
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/medieval/hauberk
	armor_family = ARMOR_FAMILY_MAIL
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/medieval/emirate
	armor_family = ARMOR_FAMILY_MAIL
	armor_tier = ARMOR_TIER_IRON

// Plate
/obj/item/clothing/suit/armor/medieval
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_STEEL
/obj/item/clothing/suit/armor/samurai/lord
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_STEEL
/obj/item/clothing/suit/armor/medieval/bronze_chestplate
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/suit/armor/medieval/iron_chestplate
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/suit/armor/imperial/imperial_chestplate
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_STEEL

////////////////////////////////////////////////////////////////////////////////
// Helmets, gauntlets and boots keep their own weight. A family set on a base
// type is cleared on fantasy and cloth subtypes that keep their own values.

// Padded
/obj/item/clothing/head/helmet/brown_eisenbruck
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/head/helmet/grey_eisenbruck
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/head/helmet/aged_eisenbruck
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_HIDE

// Leather
/obj/item/clothing/head/helmet/leather
	armor_family = ARMOR_FAMILY_LEATHER
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/head/helmet/leather_skullcap
	armor_family = ARMOR_FAMILY_LEATHER
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/head/helmet/hatchigane
	armor_family = ARMOR_FAMILY_LEATHER
	armor_tier = ARMOR_TIER_HIDE
/obj/item/clothing/head/helmet/khepresh
	armor_family = ARMOR_FAMILY_LEATHER
	armor_tier = ARMOR_TIER_HIDE

// Lamellar
/obj/item/clothing/head/helmet/samurai
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/samurai/guard
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/shoes/tsuranuki
	armor_family = ARMOR_FAMILY_LAMELLAR
	armor_tier = ARMOR_TIER_IRON

// Plate, with the mail, padded and lamellar pieces under plate base types.
/obj/item/clothing/head/helmet/samurai/lord
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_STEEL
/obj/item/clothing/head/helmet/medieval
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/medieval/coif
	armor_family = ARMOR_FAMILY_MAIL
/obj/item/clothing/head/helmet/medieval/mamluk/coif
	armor_family = ARMOR_FAMILY_MAIL
/obj/item/clothing/head/helmet/medieval/nomads/arab
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/head/helmet/medieval/nomads/arab2
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/head/helmet/medieval/nomads/arab3
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/head/helmet/medieval/nomads/arab4
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/head/helmet/medieval/emirate
	armor_family = ARMOR_FAMILY_PADDED
	armor_tier = ARMOR_TIER_LACED
/obj/item/clothing/head/helmet/medieval/arab
	armor_family = null
/obj/item/clothing/head/helmet/medieval/arab2
	armor_family = null
/obj/item/clothing/head/helmet/medieval/arab3
	armor_family = null
/obj/item/clothing/head/helmet/medieval/baltic_priest
	armor_family = null
/obj/item/clothing/head/helmet/medieval/priest
	armor_family = null
/obj/item/clothing/head/helmet/medieval/saint
	armor_family = null
/obj/item/clothing/head/helmet/medieval/giantdad
	armor_family = null
/obj/item/clothing/head/helmet/medieval/hellknight
	armor_family = null
/obj/item/clothing/head/helmet/medieval/whitestrake
	armor_family = null
/obj/item/clothing/head/helmet/medieval/tes13
	armor_family = null
/obj/item/clothing/head/helmet/bascinet
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/sallet
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/imperial/morion
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/imperial/cabasset
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/roman
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/roman_centurion
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/roman_decurion
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/solinvictus
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/horned
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/asterix
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/head/helmet/phrigian
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/gladiator
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/chinese_warrior
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/egyptian
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/egyptian/anubis
	armor_family = null
/obj/item/clothing/head/helmet/egyptian/osiris
	armor_family = null
/obj/item/clothing/head/helmet/greek
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/greek_sl
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/greek_commander
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/head/helmet/anax
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_BRONZE
/obj/item/clothing/gloves/gauntlets
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON
/obj/item/clothing/gloves/gauntlets/kote
	armor_family = ARMOR_FAMILY_LAMELLAR
/obj/item/clothing/gloves/gauntlets/giantdad
	armor_family = null
/obj/item/clothing/gloves/gauntlets/orc
	armor_family = null
/obj/item/clothing/gloves/gauntlets/tes13
	armor_family = null
/obj/item/clothing/shoes/medieval/knight
	armor_family = ARMOR_FAMILY_PLATE
	armor_tier = ARMOR_TIER_IRON

// Weapon roles: how hard a hit wears the armor that takes it. Hatchets
// bite deep; other edged and pointed hits wear a little; a blow wears
// ARMOR_BLUNT_WEAR times as much, so maces and clubs beat armor down.
/proc/armor_hit_wear(obj/item/source, kind)
	if (!source)
		return 0
	var/wear = 0.8
	if (is_tool(source, TOOL_HATCHET))
		wear = 8
	else if (istype(source, /obj/item/weapon/melee) && kind != HIT_BLUNT)
		wear = 0
	if (kind == HIT_BLUNT)
		wear *= ARMOR_BLUNT_WEAR
	return wear

// A thrust slips between rings and lames: mail and lamellar on the struck
// part give a pierce hit ARMOR_GAP_PENETRATION extra penetration, unless
// plate also covers it.
/mob/living/human/armor_gap_penetration(def_zone, attack_flag)
	if (attack_flag != HIT_PIERCE || !def_zone)
		return 0
	var/obj/item/organ/external/affecting = isorgan(def_zone) ? def_zone : get_organ(def_zone)
	if (!affecting)
		return 0
	var/gaps = FALSE
	for (var/obj/item/clothing/C in list(head, wear_mask, wear_suit, w_uniform, gloves, shoes))
		var/list/layers = list(C) + C.accessories
		for (var/obj/item/clothing/L in layers)
			if (!(L.body_parts_covered & affecting.body_part))
				continue
			// Plate over the part leaves no gap to find.
			if (L.armor_family == ARMOR_FAMILY_PLATE)
				return 0
			if (L.armor_family == ARMOR_FAMILY_MAIL || L.armor_family == ARMOR_FAMILY_LAMELLAR)
				gaps = TRUE
	return gaps ? ARMOR_GAP_PENETRATION : 0

// Tell both sides when a thrust got through the gaps in mail or lamellar.
/mob/living/human/proc/armor_gap_message(obj/item/I, mob/living/user, blocked, hit_zone)
	if (blocked >= 2 || !I || I.get_hit_kind() != HIT_PIERCE || !armor_gap_penetration(hit_zone, HIT_PIERCE))
		return FALSE
	to_chat(src, "<span class='warning'>The point finds a gap in your armor!</span>")
	if (user && user != src)
		to_chat(user, "<span class='notice'>Your thrust finds a gap in [src]'s armor.</span>")
	return TRUE

// A blow that armor fully stops still bruises the body under it.
/mob/living/human/proc/armor_bruise(obj/item/I, effective_force, blocked, hit_zone)
	if (blocked < 2 || !I || !(effective_force > 0) || I.damtype != BRUTE || I.get_hit_kind() != HIT_BLUNT)
		return FALSE
	var/obj/item/organ/external/affecting = get_organ(hit_zone)
	if (!affecting)
		return FALSE
	apply_damage(effective_force * ARMOR_BRUISE_SHARE, BRUTE, hit_zone, 0, used_weapon = I)
	to_chat(src, "<span class='warning'>The blow bruises your [affecting.name] through your armor.</span>")
	return TRUE

// Examine says what a family piece is good and bad against, and what it is
// made of, so players can choose armor without reading numbers.
/obj/item/clothing/examine(mob/user)
	..(user)
	var/strengths = armor_family_strengths()
	if (strengths)
		to_chat(user, SPAN_NOTICE(strengths))

/obj/item/clothing/proc/armor_family_strengths()
	if (!armor_family || armor_tier <= 0)
		return null
	if (armor_underlayer)
		return "Worn under armor, it softens blows and arrows. On its own it does little against blades or points."
	var/material = armor_tier_name(armor_tier)
	var/made = material ? " It is made of [material]." : ""
	switch (armor_family)
		if (ARMOR_FAMILY_PADDED)
			return "Padded armor: it softens blows and arrows well, but blades and points get through more easily.[made]"
		if (ARMOR_FAMILY_LEATHER)
			return "Leather armor: light and good against cuts, but weak against thrusts and blows.[made]"
		if (ARMOR_FAMILY_LAMELLAR)
			return "Lamellar armor: very good against arrows and good against cuts, but a thrust can find the gaps.[made]"
		if (ARMOR_FAMILY_MAIL)
			return "Mail: very good against cuts, but blows go through it and a thrust can find the gaps. Wear padding underneath.[made]"
		if (ARMOR_FAMILY_PLATE)
			return "Plate armor: strong against cuts, thrusts and arrows, and fair against blows, but heavy.[made]"
	return null

/proc/armor_tier_name(tier)
	switch (tier)
		if (ARMOR_TIER_HIDE)
			return "hide or cloth"
		if (ARMOR_TIER_LACED)
			return "laced leather"
		if (ARMOR_TIER_CHITIN)
			return "chitin"
		if (ARMOR_TIER_BRONZE)
			return "bronze"
		if (ARMOR_TIER_IRON)
			return "iron"
		if (ARMOR_TIER_STEEL)
			return "steel"
	return null
