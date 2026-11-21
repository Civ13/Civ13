// Training company and gear for the martial schools (martial arts plan, Val
// 2026-11-21). Every rank can be reached alone; company only speeds it up:
//   a training partner of the same school within 2 tiles      x1.5
//   a Master of the same school within 2 tiles                x2
//   landing punches on a Master of the same school (sparring)  x2.5
// Partners must be other players at their keyboards. The Master bonuses go
// only to Masters whose account is Discord-verified (the verified soft
// whitelist), so an alt key can't be made into a private teacher.

#define MARTIAL_COMPANY_RANGE 2
#define MARTIAL_PARTNER_MULT 1.5
#define MARTIAL_MASTER_MULT 2
#define MARTIAL_SPARRING_MULT 2.5
// A drill set on training gear, about six seconds.
#define MARTIAL_DRILL_TIME 60

// Overridden by the probe, which has no clients.
/mob/living/human/proc/martial_company_present(mob/living/human/other)
	return other.client && other.ckey != ckey

// Overridden by the probe, which has no verified list.
/mob/living/human/proc/martial_master_verified(mob/living/human/other)
	return account_verified(other.ckey)

// Whether other counts as company for this character's training now.
/mob/living/human/proc/martial_partner_ok(mob/living/human/other)
	if (!istype(other) || other == src || other.stat != CONSCIOUS || !martial_school || other.martial_school != martial_school)
		return FALSE
	if (other.z != z || get_dist(src, other) > MARTIAL_COMPANY_RANGE)
		return FALSE
	return martial_company_present(other)

/mob/living/human/proc/martial_teacher_ok(mob/living/human/other)
	return martial_partner_ok(other) && other.martial_rank(martial_school) == MARTIAL_RANK_MASTER && martial_master_verified(other)

// How much faster practice goes in this company.
/mob/living/human/proc/martial_training_mult(mob/living/human/sparring = null)
	if (!martial_school || !isturf(loc))
		return 1
	if (sparring && martial_teacher_ok(sparring))
		return MARTIAL_SPARRING_MULT
	var/mult = 1
	for (var/mob/living/human/other in range(MARTIAL_COMPANY_RANGE, src))
		if (martial_teacher_ok(other))
			return MARTIAL_MASTER_MULT
		if (martial_partner_ok(other))
			mult = MARTIAL_PARTNER_MULT
	return mult

// --- Gear ---------------------------------------------------------------------

// Struck bare-handed on harm intent for a drill set. Gear never hurts the hand
// and builds no conditioning; it teaches the school faster than forms alone.
/obj/structure/martial_gear
	name = "training gear"
	icon = 'icons/obj/martial_training.dmi'
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/drill_noun = "the gear"
	// School points one set adds on top of the unarmed practice.
	var/drill_bonus = 1

/obj/structure/martial_gear/heavy_bag
	name = "heavy bag"
	desc = "A long leather bag packed with sand and rags, hung from a timber frame. Strike it bare-handed on harm intent to drill your school's combinations."
	icon_state = "heavy_bag"
	drill_noun = "the heavy bag"
	drill_bonus = 1

/obj/structure/martial_gear/wooden_dummy
	name = "wooden dummy"
	desc = "A heavy log on a frame with wooden arms and a leg, for drilling blocks, traps and strikes against a partner who never tires. Strike it bare-handed on harm intent."
	icon_state = "wooden_dummy"
	drill_noun = "the wooden dummy"
	drill_bonus = 1.5

/obj/structure/martial_gear/wrestling_mat
	name = "wrestling mat"
	desc = "A quilted hide pad stuffed with straw, for drilling throws, falls and holds. It does most for schools that grapple. Strike it bare-handed on harm intent to drill."
	icon_state = "wrestling_mat"
	density = FALSE
	layer = TURF_LAYER + 0.1
	drill_noun = "the wrestling mat"
	drill_bonus = 1.5

// School points a set on G adds for this character.
/obj/structure/martial_gear/proc/martial_drill_bonus(mob/living/human/H)
	return drill_bonus

// Throws and holds need a grappling school: others get half.
/obj/structure/martial_gear/wrestling_mat/martial_drill_bonus(mob/living/human/H)
	var/list/moves = martial_school_moves(H.martial_school)
	if (islist(moves) && moves[2] >= 0.5)
		return drill_bonus
	return drill_bonus / 2

/obj/structure/martial_gear/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, SPAN_NOTICE("Strike it with a bare or wrapped hand on harm intent for a drill set. It teaches your martial school faster than forms alone, and never hurts your hand."))

/obj/structure/martial_gear/attack_hand(mob/living/human/H)
	if (!istype(H) || H.a_intent != I_HARM)
		return ..()
	H.drill_martial_gear(src)

// Overridden by the probe, which has no do_after timing.
/mob/living/human/proc/martial_drill_wait(atom/target)
	return do_after(src, MARTIAL_DRILL_TIME, target)

/mob/living/human/proc/drill_martial_gear(obj/structure/martial_gear/G)
	var/refusal = conditioning_refusal()
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return FALSE
	visible_message(SPAN_NOTICE("[src] drills against [G.drill_noun]."), SPAN_NOTICE("You start drilling against [G.drill_noun]."))
	do_attack_animation(G)
	playsound(get_turf(G), "punch", 25, TRUE, -1)
	if (!martial_drill_wait(G))
		return FALSE
	refusal = conditioning_refusal()
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return FALSE
	var/rate = 1 - exercise_fatigue / 8
	exercise_spend(2)
	practice_unarmed(1)
	if (martial_school)
		martial_practice(G.martial_drill_bonus(src) * rate)
		to_chat(src, SPAN_NOTICE("You finish a drill set. [martial_status_text()]"))
	else
		to_chat(src, SPAN_NOTICE("You finish a drill set. Follow a martial school to get more from it."))
	return TRUE

#undef MARTIAL_COMPANY_RANGE
#undef MARTIAL_PARTNER_MULT
#undef MARTIAL_MASTER_MULT
#undef MARTIAL_SPARRING_MULT
#undef MARTIAL_DRILL_TIME
