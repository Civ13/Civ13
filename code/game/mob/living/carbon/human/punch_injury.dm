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

// The simplest protection: cloth or leather wound round the knuckles and
// wrist. On grab intent, use a cloth or leather stack on your own hand to wrap
// both hands with one sheet. The wrap is still that sheet: taken off, dropped
// or stripped, it unwinds into the same material again.
/obj/item/stack/material
	var/hand_wrap_type = null

/obj/item/stack/material/cloth
	hand_wrap_type = /obj/item/clothing/gloves/hand_wraps

/obj/item/stack/material/woolcloth
	hand_wrap_type = /obj/item/clothing/gloves/hand_wraps

/obj/item/stack/material/leather
	hand_wrap_type = /obj/item/clothing/gloves/hand_wraps/leather

/obj/item/stack/material/attack(mob/living/M, mob/living/user, target_zone)
	if (M == user && user.a_intent == I_HELP && (target_zone == "head" || target_zone == "mouth") && ishuman(user) && is_cloth_sheet(src))
		dye_own_hair(user, target_zone == "mouth")
		return TRUE
	if (hand_wrap_type && M == user && user.a_intent == I_GRAB && (target_zone in list("l_hand", "r_hand")) && ishuman(user))
		wrap_hands(user)
		return TRUE
	return ..()

/obj/item/stack/material/proc/wrap_hands(mob/living/human/H)
	if (H.gloves)
		to_chat(H, SPAN_WARNING("Take off \the [H.gloves] first."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] starts winding \the [src] around \his hands."), SPAN_NOTICE("You start winding \the [src] around your hands."))
	if (!hand_wrap_wait(H) || H.gloves || QDELETED(src) || loc != H || amount < 1)
		return FALSE
	var/obj/item/clothing/gloves/hand_wraps/W = new hand_wrap_type(H)
	W.unwraps_to = type
	W.name = "[initial(name)] hand wraps"
	use(1)
	if (!H.equip_to_slot_if_possible(W, slot_gloves))
		W.forceMove(get_turf(H))
		W.unwind()
		return FALSE
	to_chat(H, SPAN_NOTICE("You bind your knuckles and wrists with \the [W]."))
	return TRUE

// Overridden by the probe, which has no do_after timing.
/obj/item/stack/material/proc/hand_wrap_wait(mob/living/human/H)
	return do_after(H, 20, H)

/obj/item/clothing/gloves/hand_wraps
	name = "cloth hand wraps"
	desc = "A strip of cloth wound tight around the knuckles and wrists. It keeps a punch from splitting your hand open, and unwinds back into cloth when taken off."
	icon_state = "ncr_handwraps"
	item_state = "ncr_handwraps"
	fingerprint_chance = 100
	flammable = TRUE
	punch_protection = 60
	var/unwraps_to = /obj/item/stack/material/cloth

/obj/item/clothing/gloves/hand_wraps/leather
	name = "leather hand wraps"
	desc = "Leather bound around the knuckles and wrists. It takes the sting out of a hard punch, and unwinds back into leather when taken off."
	icon_state = "legion_handwraps"
	item_state = "legion_handwraps"
	punch_protection = 75
	unwraps_to = /obj/item/stack/material/leather

// Anywhere but on the hands, the wrap is a sheet again. Settled a tick later,
// so a wrap taken off into the hand finishes moving before it unwinds.
/obj/item/clothing/gloves/hand_wraps/equipped(mob/user, slot)
	..()
	if (slot != slot_gloves)
		queue_settle()

/obj/item/clothing/gloves/hand_wraps/dropped(mob/user)
	..()
	queue_settle()

// Overridden by the probe, which runs no timers.
/obj/item/clothing/gloves/hand_wraps/proc/queue_settle()
	addtimer(CALLBACK(src, PROC_REF(settle_wrap)), 1)

/obj/item/clothing/gloves/hand_wraps/proc/settle_wrap()
	if (QDELETED(src))
		return FALSE
	var/mob/living/human/H = loc
	if (istype(H) && H.gloves == src)
		return FALSE
	return unwind()

/obj/item/clothing/gloves/hand_wraps/proc/unwind()
	var/atom/where = loc
	var/mob/M = ismob(where) ? where : null
	if (M)
		M.drop_from_inventory(src)
		where = M.loc
	var/obj/item/stack/material/S = new unwraps_to(M ? M : where, 1, !M)
	if (M && !M.put_in_hands(S))
		S.forceMove(where)
	qdel(src)
	return S

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
	// Conditioned knuckles (hand_conditioning.dm) take more before they give.
	chance *= hand_conditioning_factor()
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
