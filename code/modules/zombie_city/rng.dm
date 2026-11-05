// Private seeded generator for the zombie city. The city must come out the
// same for a seed whatever else the world does between ticks, so nothing in
// the generator touches rand(), prob() or pick().
//
// A 24-bit linear congruential generator: BYOND numbers are single-precision
// floats, exact only below 2^24, so the multiply is done in 12-bit limbs and
// reduced modulo 2^24. Multiplier 214013 (5 mod 8) with an odd increment gives
// the full 2^24 period; the low bits are weak, so draws use the top 16 bits.
#define ZOMBIE_CITY_RNG_MOD 16777216
#define ZOMBIE_CITY_RNG_LIMB 4096
#define ZOMBIE_CITY_RNG_MUL_HI 52
#define ZOMBIE_CITY_RNG_MUL_LO 1021
// Increment 2531011 = 617 * 4096 + 3779.
#define ZOMBIE_CITY_RNG_INC_HI 617
#define ZOMBIE_CITY_RNG_INC_LO 3779

/datum/zombie_city_rng
	var/state = 1
	var/draws = 0

/datum/zombie_city_rng/New(seed)
	..()
	reseed(seed)

/datum/zombie_city_rng/proc/reseed(seed)
	seed = isnum(seed) ? abs(round(seed)) : 1
	state = seed % ZOMBIE_CITY_RNG_MOD
	draws = 0
	// Spread small seeds (cycle counters, realtime) through the state once.
	for (var/i = 1 to 4)
		advance()

// Every intermediate value stays below 2^24, where floats are exact integers.
/datum/zombie_city_rng/proc/advance()
	var/s_hi = round(state / ZOMBIE_CITY_RNG_LIMB)
	var/s_lo = state - s_hi * ZOMBIE_CITY_RNG_LIMB
	var/cross = (ZOMBIE_CITY_RNG_MUL_HI * s_lo + ZOMBIE_CITY_RNG_MUL_LO * s_hi) % ZOMBIE_CITY_RNG_LIMB
	var/low_product = ZOMBIE_CITY_RNG_MUL_LO * s_lo
	var/p_hi = round(low_product / ZOMBIE_CITY_RNG_LIMB)
	var/p_lo = low_product - p_hi * ZOMBIE_CITY_RNG_LIMB + ZOMBIE_CITY_RNG_INC_LO
	var/carry = 0
	if (p_lo >= ZOMBIE_CITY_RNG_LIMB)
		p_lo -= ZOMBIE_CITY_RNG_LIMB
		carry = 1
	p_hi = (p_hi + cross + ZOMBIE_CITY_RNG_INC_HI + carry) % ZOMBIE_CITY_RNG_LIMB
	state = p_hi * ZOMBIE_CITY_RNG_LIMB + p_lo
	draws++
	return round(state / 256)

// Integer in [low, high]. Reversed bounds are swapped; equal bounds return low.
/datum/zombie_city_rng/proc/between(low, high)
	low = round(low)
	high = round(high)
	if (high < low)
		var/swap = low
		low = high
		high = swap
	var/span = high - low + 1
	if (span <= 1)
		return low
	return low + advance() % span

// TRUE with the given percentage.
/datum/zombie_city_rng/proc/chance(percent)
	return advance() % 100 < percent

/datum/zombie_city_rng/proc/choose(list/options)
	if (!islist(options) || !options.len)
		return null
	return options[between(1, options.len)]

// Fisher-Yates in place, so callers can take the first n as a sample.
/datum/zombie_city_rng/proc/shuffle(list/items)
	for (var/i = items.len, i > 1, i--)
		var/j = between(1, i)
		if (i != j)
			items.Swap(i, j)
	return items
