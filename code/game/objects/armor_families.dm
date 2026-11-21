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
	var/value = min(ARMOR_FAMILY_CAP, round(armor_tier * multipliers[type] + 0.001, 1))
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
