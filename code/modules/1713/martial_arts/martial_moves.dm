// School moves (martial arts plan, Val 2026-11-21). A school's moves work on
// the normal punch and grab paths, so hand injury, strength, dexterity, armour
// and the combat reactions all still apply. Moves unlock at Student and grow
// at Adept and Master. Each school weighs the same two building blocks,
// striking and grappling, plus the targets it drills most:
//   striking  - punch damage, up to +15% at Master for a pure striking school
//   focus     - another +5% a rank on the zones the school aims for
//   grappling - holds tighten faster and holds are slipped more easily, up to
//               30% better at Master for a pure grappling school
// Hard-hand striking also turns conditioned hands into damage (+up to 30%).
// Schools for weapons can add their own entries later; nothing here assumes
// an empty hand beyond the punch path that calls it.

// list(striking weight, grappling weight, focus zones) for a school, or null.
// A switch rather than a global list: the world's global initialiser is at
// the compiler's size limit, so new globals must not add to it.
/proc/martial_school_moves(school_id)
	switch (school_id)
		if ("grappling")
			return list(0.2, 1, null)
		if ("pugilism")
			return list(1, 0, list("head", "mouth", "eyes"))
		if ("pankration")
			return list(0.6, 0.6, null)
		if ("shaolin")
			return list(0.8, 0.3, list("chest", "groin"))
		if ("wing_chun")
			return list(0.8, 0.3, list("chest"))
		if ("hard_hand")
			return list(1, 0, null)
		if ("savate")
			return list(0.9, 0.1, list("l_leg", "r_leg", "l_foot", "r_foot"))
		if ("judo")
			return list(0.2, 1, null)
		if ("combatives")
			return list(0.7, 0.5, list("head", "mouth"))
		if ("krav_maga")
			return list(0.8, 0.5, list("groin", "mouth"))
		if ("bjj")
			return list(0.1, 1, null)
		if ("mma")
			return list(0.7, 0.7, null)
	return null

// Ranks above Novice: 0 for none or Novice, then 1, 2, 3.
/mob/living/human/proc/martial_move_tier()
	if (!martial_school)
		return 0
	return max(0, martial_rank(martial_school) - MARTIAL_RANK_NOVICE)

/mob/living/human/proc/martial_punch_mult(zone)
	var/tier = martial_move_tier()
	var/list/moves = martial_school_moves(martial_school)
	if (tier <= 0 || !islist(moves))
		return 1
	var/mult = 1 + 0.05 * tier * moves[1]
	var/list/focus = moves[3]
	if (islist(focus) && (zone in focus))
		mult += 0.05 * tier
	if (martial_school == "hard_hand")
		mult += 0.1 * tier * current_hand_conditioning() / 100
	return mult

/mob/living/human/proc/martial_grapple_power()
	var/tier = martial_move_tier()
	var/list/moves = martial_school_moves(martial_school)
	if (tier <= 0 || !islist(moves))
		return 1
	return 1 + 0.1 * tier * moves[2]

// How much better A grapples than B through their schools (1 between equals).
/proc/martial_grapple_edge(mob/A, mob/B)
	var/mob/living/human/HA = A
	var/mob/living/human/HB = B
	var/a = istype(HA) ? HA.martial_grapple_power() : 1
	var/b = istype(HB) ? HB.martial_grapple_power() : 1
	return a / b
