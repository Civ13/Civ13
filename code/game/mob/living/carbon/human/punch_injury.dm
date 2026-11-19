// Bare-knuckle punches can hurt the hand that throws them. Hand wraps and
// gloves cushion the knuckles: punch_protection is the share of that risk the
// worn gloves stop (0 to 100). Left null, it follows the gloves' melee armour.

/obj/item/clothing/gloves
	var/punch_protection = null

/obj/item/clothing/gloves/proc/get_punch_protection()
	if (!isnull(punch_protection))
		return Clamp(punch_protection, 0, 100)
	var/melee = (islist(armor) && isnum(armor["melee"])) ? armor["melee"] : 0
	return Clamp(40 + melee / 2, 0, 90)

// Rings and watches sit in the glove slot but cover nothing.
/obj/item/clothing/gloves/rings
	punch_protection = 0

/obj/item/clothing/gloves/watch
	punch_protection = 0

/obj/item/clothing/gloves/sterile
	punch_protection = 10

/obj/item/clothing/gloves/oven
	punch_protection = 50

/obj/item/clothing/gloves/thick
	punch_protection = 60

/obj/item/clothing/gloves/toughguy
	punch_protection = 80

/obj/item/clothing/gloves/boxing
	punch_protection = 100

/obj/item/clothing/gloves/fingerless/ncr
	punch_protection = 60

/obj/item/clothing/gloves/fingerless/legionaire
	punch_protection = 75

// The simplest protection: a strip of cloth or leather wound round the
// knuckles and wrist. The fingers stay free.
/obj/item/clothing/gloves/hand_wraps
	name = "cloth hand wraps"
	desc = "Strips of cloth wound tight around the knuckles and wrist. They keep a punch from splitting your hand open."
	icon_state = "ncr_handwraps"
	item_state = "ncr_handwraps"
	fingerprint_chance = 100
	flammable = TRUE
	punch_protection = 60

/obj/item/clothing/gloves/hand_wraps/leather
	name = "leather hand wraps"
	desc = "Leather strips bound around the knuckles and wrist. They take the sting out of a hard punch."
	icon_state = "legion_handwraps"
	item_state = "legion_handwraps"
	punch_protection = 75

/mob/living/human/proc/punch_protection()
	var/obj/item/clothing/gloves/G = gloves
	return istype(G) ? G.get_punch_protection() : 0

// Percent chance that a landed punch hurts the puncher's own hand. Skulls and
// armour are hard; a heavier blow risks more.
/mob/living/human/proc/punch_injury_chance(zone, force, target_armor)
	var/chance = 4
	if (zone in list("head", "mouth", "eyes"))
		chance *= 2.5
	chance += max(0, target_armor) / 4
	chance *= 0.6 + Clamp(force, 1, 5) / 10
	chance *= (100 - punch_protection()) / 100
	return max(0, chance)

// Overridden by the probe so it decides each roll.
/mob/living/human/proc/punch_injury_roll(chance)
	return prob(chance)

// Called after a full-force punch lands. Returns TRUE if the hand was hurt.
/mob/living/human/proc/punch_hurts_hand(atom/target, zone, force, target_armor = 0)
	var/hand_zone = hand ? "l_hand" : "r_hand"
	var/obj/item/organ/external/E = organs_by_name[hand_zone]
	if (!E || E.is_stump())
		return FALSE
	var/chance = punch_injury_chance(zone, force, target_armor)
	if (!punch_injury_roll(chance))
		return FALSE
	var/hard = (zone in list("head", "mouth", "eyes")) || target_armor >= 40
	apply_damage(rand(2, 5), BRUTE, hand_zone)
	if (punch_injury_roll(hard ? 15 + target_armor / 5 : 5))
		E.fracture()
		to_chat(src, SPAN_DANGER("Something cracks in your [E.name] as the punch lands on [target]!"))
	else if (hard)
		to_chat(src, SPAN_WARNING("You split your knuckles on [target]!"))
	else
		to_chat(src, SPAN_WARNING("You jar your [E.name] on [target]."))
	return TRUE
