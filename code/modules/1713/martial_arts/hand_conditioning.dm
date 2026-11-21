// Hand conditioning (martial arts plan, Val 2026-11-21): striking hard
// targets toughens the knuckles, so later punches hurt your own hand less
// (punch_injury.dm). It is earned only by risking the hand: every set on a
// makiwara post, a gravel pail or bare rock can bruise, split or break it.
// Conditioning fades slowly without practice. Sets share the exercise
// fatigue of the lifting stones and the tread wheels (active_training.dm).

#define HAND_CONDITIONING_MAX 100
// A set is one sitting of strikes, about six seconds.
#define HAND_CONDITIONING_SET_TIME 60
// One point fades per real day without a set.
#define HAND_CONDITIONING_FADE_DAY 864000

/mob/living/human
	var/hand_conditioning = 0
	// world.realtime of the last set (or of the last fade step).
	var/hand_conditioning_at = 0

// Overridden by the probe so it can move time on.
/mob/living/human/proc/hand_conditioning_clock()
	return world.realtime

/mob/living/human/proc/current_hand_conditioning()
	if (hand_conditioning > 0 && hand_conditioning_at > 0)
		var/days = round((hand_conditioning_clock() - hand_conditioning_at) / HAND_CONDITIONING_FADE_DAY)
		if (days > 0)
			hand_conditioning = max(0, hand_conditioning - days)
			hand_conditioning_at += days * HAND_CONDITIONING_FADE_DAY
	return hand_conditioning

// Each full 10 points cuts the punch injury chance by 6%, 60% at 100.
/mob/living/human/proc/hand_conditioning_factor()
	return 1 - 0.06 * round(current_hand_conditioning() / 10)

// The unarmed skill. Saves made before it existed lack the entry.
/mob/living/human/proc/ensure_unarmed_stat()
	if (!islist(stats["unarmed"]))
		stats["unarmed"] = list(100, 100)

/mob/living/human/proc/practice_unarmed(amount, mob/living/human/sparring = null)
	ensure_unarmed_stat()
	adaptStat("unarmed", amount)
	// Punches and hand sets count toward the followed school (martial_schools.dm).
	martial_practice(amount / 2, sparring)

// Punch damage from the unarmed skill: +25% at 200, -12.5% at 50.
/mob/living/human/proc/unarmed_damage_mult()
	var/coeff = getStatCoeff("unarmed")
	if (!coeff)
		return 1
	return clamp(1 + (coeff - 1) / 4, 0.75, 1.5)

// --- Striking targets ------------------------------------------------------

/obj/structure/striking_post
	name = "makiwara post"
	desc = "A springy wooden post bound with straw rope at fist height. Strike it bare-handed on harm intent to toughen your knuckles."
	icon = 'icons/obj/martial_training.dmi'
	icon_state = "makiwara"
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/strike_noun = "the makiwara"
	// Conditioning one set adds, and the most this target can build.
	var/conditioning_gain = 2
	var/conditioning_cap = 30
	// Percent chance a bare-handed set hurts the hand.
	var/injury_chance = 5
	// Percent of injuries that break the hand.
	var/fracture_share = 0
	var/sharp_injury = FALSE

/obj/structure/striking_post/gravel_pail
	name = "gravel pail"
	desc = "A stout wooden pail packed with gravel. Drive your fingers and knuckles into it on harm intent to harden them. It bites back."
	icon_state = "gravel_pail"
	density = FALSE
	strike_noun = "the gravel"
	conditioning_gain = 3
	conditioning_cap = 60
	injury_chance = 10
	fracture_share = 5
	sharp_injury = TRUE

/obj/structure/striking_post/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, "<span class='notice'>Strike it with a bare or wrapped hand on harm intent. It can build hand conditioning up to [conditioning_cap].</span>")

/obj/structure/striking_post/attack_hand(mob/living/human/H)
	if (!istype(H) || H.a_intent != I_HARM)
		return ..()
	H.strike_conditioning_target(src, strike_noun, conditioning_gain, conditioning_cap, injury_chance, fracture_share, sharp_injury)

// Bare rock: the hardest teacher. Striking a rock wall builds conditioning
// all the way, and about one injury in four breaks the hand.
/turf/wall/rockwall/attack_hand(mob/living/human/H)
	if (istype(H) && H.a_intent == I_HARM && Adjacent(H))
		H.strike_conditioning_target(src, "the rock", 4, HAND_CONDITIONING_MAX, 18, 25, FALSE)
		return
	return ..()

// --- One set ----------------------------------------------------------------

// Overridden by the probe, which has no do_after timing.
/mob/living/human/proc/conditioning_set_wait(atom/target)
	return do_after(src, HAND_CONDITIONING_SET_TIME, target)

// Overridden by the probe so it decides each roll.
/mob/living/human/proc/conditioning_roll(chance)
	return prob(chance)

// Why the striking hand cannot train now, or null.
/mob/living/human/proc/conditioning_refusal()
	var/obj/item/organ/external/E = organs_by_name[hand ? "l_hand" : "r_hand"]
	if (!E || E.is_stump() || !E.is_usable())
		return "You can't use that hand."
	if (E.status & ORGAN_BROKEN)
		return "Your [E.name] is broken. Let it heal before you strike anything."
	if (get_active_hand())
		return "Your striking hand needs to be empty."
	return exercise_refusal()

// The injury chance for one set on a target, after protection, fatigue and
// an already hurt hand.
/mob/living/human/proc/conditioning_set_chance(base_chance)
	var/protection = punch_protection()
	if (protection >= 100)
		return 0
	var/chance = base_chance
	if (protection > 0)
		chance /= 2
	var/obj/item/organ/external/E = organs_by_name[hand ? "l_hand" : "r_hand"]
	if (exercise_fatigue >= 4 || (E && E.brute_dam > 0))
		chance *= 2
	return chance

// The conditioning one set adds: half through wraps or gloves, none through
// padding that stops every injury.
/mob/living/human/proc/conditioning_set_gain(base_gain)
	var/protection = punch_protection()
	if (protection >= 100)
		return 0
	return protection > 0 ? base_gain / 2 : base_gain

/mob/living/human/proc/strike_conditioning_target(atom/target, noun, gain, cap, base_chance, fracture_share, sharp)
	var/refusal = conditioning_refusal()
	if (refusal)
		to_chat(src, "<span class='warning'>[refusal]</span>")
		return FALSE
	visible_message("<span class='notice'>[src] starts striking [noun] with \his fists.</span>", "<span class='notice'>You start striking [noun] again and again.</span>")
	do_attack_animation(target)
	playsound(get_turf(target), "punch", 25, TRUE, -1)
	if (!conditioning_set_wait(target))
		return FALSE
	refusal = conditioning_refusal()
	if (refusal)
		to_chat(src, "<span class='warning'>[refusal]</span>")
		return FALSE
	var/chance = conditioning_set_chance(base_chance)
	var/added = conditioning_set_gain(gain)
	exercise_spend(2)
	practice_unarmed(1)
	var/had = current_hand_conditioning()
	if (added > 0 && had < cap)
		hand_conditioning = min(cap, had + added)
	if (hand_conditioning > 0)
		hand_conditioning_at = hand_conditioning_clock()
	if (chance > 0 && conditioning_roll(chance))
		hurt_striking_hand(noun, fracture_share, sharp)
		return TRUE
	if (added <= 0)
		to_chat(src, "<span class='notice'>Your padding takes every blow. It is safe, but it toughens nothing.</span>")
	else if (had >= cap)
		to_chat(src, "<span class='notice'>Your hands are already as hard as [noun] can make them. Something harder would teach you more.</span>")
	else
		to_chat(src, "<span class='notice'>Your knuckles ache, but they are a little harder for it.</span>")
	return TRUE

/mob/living/human/proc/hurt_striking_hand(noun, fracture_share, sharp)
	var/hand_zone = hand ? "l_hand" : "r_hand"
	var/obj/item/organ/external/E = organs_by_name[hand_zone]
	if (!E)
		return FALSE
	apply_damage(rand(3, 6), BRUTE, hand_zone, 0, sharp = sharp)
	if (fracture_share > 0 && conditioning_roll(fracture_share))
		E.fracture()
		to_chat(src, "<span class='danger'>Something cracks in your [E.name] against [noun]!</span>")
	else if (sharp)
		to_chat(src, "<span class='warning'>[capitalize(noun)] splits your knuckles open.</span>")
	else
		to_chat(src, "<span class='warning'>You bruise your [E.name] on [noun].</span>")
	return TRUE

#undef HAND_CONDITIONING_MAX
#undef HAND_CONDITIONING_SET_TIME
#undef HAND_CONDITIONING_FADE_DAY
