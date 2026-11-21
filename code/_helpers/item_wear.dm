// Item wear in one place: an item loses `health` as it is used and breaks at 0.
//
// Every item has `health` and `maxhealth` (set from health in New()). Wear goes
// through apply_wear(), which subtracts and then runs check_health(); a type
// that can break overrides check_health() to say what breaking does (material
// weapons shatter, shields break apart, clothing falls apart). A type that does
// not override it only loses health.
//
// The cause decides who can soften the wear:
// - WEAR_BLOW: a parry, a block or a strike. Electroplating reduces it.
// - WEAR_WORK: tool work such as chopping, splitting or shaping wood.
// - WEAR_HIT: damage passed straight on, such as armour taking a hit.
// A lacquer or varnish finish (lacquer.dm) softens wear of every cause.
//
// Persistence already saves health and maxhealth, so this adds no saved state.
// Pressure suits, firearm parts, orbit pods, radio relays and the reactor keep
// their own wear: their numbers are tuned per system and are not item health.

#define WEAR_BLOW "blow"
#define WEAR_WORK "work"
#define WEAR_HIT "hit"

// Wear the item by amount. Returns TRUE when it broke and is being deleted.
/obj/item/proc/apply_wear(amount, cause = WEAR_WORK, consumed = FALSE)
	if (cause == WEAR_BLOW)
		amount = plating_wear(amount)
	amount = finish_wear(amount) // lacquer.dm
	health -= amount
	return check_health(consumed)

// Break the item if it is worn out. Returns TRUE when it broke.
/obj/item/proc/check_health(consumed)
	return FALSE

// How worn the item is, from 1 (as made) to 0, or null when it has no health.
/obj/item/proc/wear_fraction()
	if (isnull(health) || !maxhealth)
		return null
	return health / maxhealth

// Repair by amount (sharpening, honing, bench repair); each repair costs
// `strain` of the most it can be repaired to, but never more than a tenth of
// it, so a small fragile tool such as a twine-bound flint axe lasts as many
// sharpenings as a sword. Repair never breaks an item: one too worn to take
// the strain is refused and left as it is. Returns TRUE when it was repaired.
/obj/item/proc/repair_wear(amount, strain = 0)
	strain = min(strain, maxhealth * 0.1)
	if (maxhealth - strain < 1)
		return FALSE
	maxhealth -= strain
	health = min(health + amount, maxhealth)
	return TRUE

// TRUE when one more repair would leave less than 1 to repair to; check it
// before the wait so nobody spends the time for nothing.
/obj/item/proc/too_worn_to_repair(strain = 0)
	return maxhealth - min(strain, maxhealth * 0.1) < 1
