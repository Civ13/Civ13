// ============================================================
// Pressure suits (space settlement phase 4)
// ------------------------------------------------------------
// A pressure suit, its helmet and an air tank on the back keep the outside
// out (sealed_against_outside() in outside_exposure.dm). Each breath taken
// on unbreathable ground draws on the tank; the suit's heater holds the
// wearer at room temperature while its battery lasts. Hits wear down the
// suit's integrity and so does scrambling over crater rubble; at zero the
// suit no longer seals until it is patched. A badly worn suit leaks, so the
// tank empties faster.
//
// The tank refills from a habitat module's air (it takes the oxygen out of
// that module's ledger) or from a landed lander's reserve; the heater
// recharges at a powered habitat heater. Everything is a plain number on
// the items, so a restart or a region transfer keeps what was left.
// Reuses existing sprites; no new art.
// ============================================================

#define SUIT_INTEGRITY_MAX 100
#define SUIT_LEAKY_INTEGRITY 25
#define SUIT_LEAK_MULTIPLIER 3
#define SUIT_PATCH_INTEGRITY 50
#define SUIT_HIT_MIN_DAMAGE 3
#define SUIT_TANK_SECONDS 1800
#define SUIT_HEATER_SECONDS 7200
#define SUIT_LOW_TANK_SECONDS 300
#define SUIT_EMPTY_TANK_SECONDS 60
#define SUIT_LOW_HEATER_SECONDS 600
#define SUIT_ROOM_C 20
// An unheated sealed suit still insulates against this much of the cold.
#define SUIT_UNHEATED_INSULATION_C 30
// One human life tick.
#define SUIT_LIFE_SECONDS 2
// Chance, per step onto crater rubble, of a scrape.
#define SUIT_RUBBLE_SCRAPE_CHANCE 4

/obj/item/clothing/suit/pressure_suit
	name = "pressure suit"
	desc = "A layered, airtight suit with a battery heater, for working outside a habitat. Wear it with the matching helmet and an air tank on your back."
	icon_state = "astronaut"
	item_state = "astronaut"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|FEET|HANDS
	armor = list(melee = 10, arrow = 5, gun = FALSE, energy = 5, bomb = 20, bio = 100, rad = 60)
	ripable = FALSE
	w_class = ITEM_SIZE_LARGE
	slowdown = 1
	var/integrity = SUIT_INTEGRITY_MAX
	var/heater_charge = SUIT_HEATER_SECONDS

/obj/item/clothing/suit/pressure_suit/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Integrity [round(integrity)]%. Heater battery [round(100 * heater_charge / SUIT_HEATER_SECONDS)]%."))
	if (integrity <= 0)
		to_chat(user, SPAN_DANGER("It is torn open and will not seal until it is patched."))
	else if (integrity <= SUIT_LEAKY_INTEGRITY)
		to_chat(user, SPAN_WARNING("It is badly worn and leaks."))

/obj/item/clothing/suit/pressure_suit/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/pressure_suit_patch))
		var/obj/item/pressure_suit_patch/P = W
		P.patch(src, user)
		return
	return ..()

// Takes damage off the suit's integrity. Returns TRUE when this tore it open.
/obj/item/clothing/suit/pressure_suit/proc/wear_down(amount)
	if (amount <= 0 || integrity <= 0)
		return FALSE
	integrity = max(0, integrity - amount)
	return integrity <= 0

/obj/item/clothing/head/pressure_helmet
	name = "pressure helmet"
	desc = "A sealed helmet with a tinted visor that locks onto a pressure suit's collar."
	icon_state = "astronaut"
	item_state = "astronaut"
	flags_inv = HIDEFACE|BLOCKHAIR
	armor = list(melee = 15, arrow = 10, gun = 5, energy = 5, bomb = 20, bio = 100, rad = 60)
	w_class = ITEM_SIZE_NORMAL

/obj/item/pressure_tank
	name = "suit air tank"
	desc = "A compressed-air bottle that feeds a sealed pressure suit. Wear it on your back. Refill it at a habitat module's core or a landed lander."
	icon = 'icons/obj/cans.dmi'
	icon_state = "small_can_o2"
	slot_flags = SLOT_BACK
	w_class = ITEM_SIZE_NORMAL
	var/air_seconds = SUIT_TANK_SECONDS

/obj/item/pressure_tank/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("About [round(air_seconds / 60)] minute\s of air left."))

// The oxygen (kPa-tiles of a habitat ledger) that tops this tank up.
/obj/item/pressure_tank/proc/refill_need()
	return max(0, SUIT_TANK_SECONDS - air_seconds) * HABITAT_BREATH_PER_SECOND

// Adds air bought with this much oxygen; returns the oxygen used.
/obj/item/pressure_tank/proc/refill(oxygen)
	var/used = min(max(0, oxygen), refill_need())
	air_seconds = min(SUIT_TANK_SECONDS, air_seconds + used / HABITAT_BREATH_PER_SECOND)
	return used

/obj/item/pressure_suit_patch
	name = "suit patch kit"
	desc = "Adhesive patches and sealant for a torn pressure suit. Use it on the suit, or on someone wearing one."
	icon = 'icons/obj/storage.dmi'
	icon_state = "firstaid"
	w_class = ITEM_SIZE_SMALL

/obj/item/pressure_suit_patch/attack(mob/living/M as mob, mob/living/user as mob)
	var/mob/living/human/H = M
	if (istype(H) && istype(H.wear_suit, /obj/item/clothing/suit/pressure_suit))
		patch(H.wear_suit, user)
		return TRUE
	return ..()

/obj/item/pressure_suit_patch/proc/patch(obj/item/clothing/suit/pressure_suit/S, mob/user)
	if (!istype(S))
		return FALSE
	if (S.integrity >= SUIT_INTEGRITY_MAX)
		to_chat(user, SPAN_NOTICE("\The [S] has nothing to patch."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start patching \the [S]..."))
	if (!do_after(user, 30, S) || QDELETED(src) || QDELETED(S))
		return FALSE
	S.integrity = min(SUIT_INTEGRITY_MAX, S.integrity + SUIT_PATCH_INTEGRITY)
	user.visible_message(SPAN_NOTICE("[user] patches \the [S]."))
	qdel(src)
	return TRUE

// ---------------------------------------------------------------- refilling

/obj/structure/habitat_core/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/pressure_tank))
		pressure_tank_refill_from_ledger(W, air(), user, src)
		store_air()
		return
	return ..()

/obj/structure/landed_lander/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/pressure_tank))
		var/obj/item/pressure_tank/A = W
		if (A.refill_need() <= 0)
			to_chat(user, SPAN_NOTICE("\The [A] is already full."))
			return
		var/used = A.refill(oxygen_reserve)
		if (used <= 0)
			to_chat(user, SPAN_WARNING("\The [src] has no oxygen left to spare."))
			return
		oxygen_reserve -= used
		to_chat(user, SPAN_NOTICE("You refill \the [A] from \the [src]'s reserve."))
		return
	return ..()

// Refills a tank from a module's air, keeping the module breathable.
/proc/pressure_tank_refill_from_ledger(obj/item/pressure_tank/A, datum/habitat_ledger/L, mob/user, atom/source)
	if (!istype(A) || !L)
		return 0
	if (A.refill_need() <= 0)
		to_chat(user, SPAN_NOTICE("\The [A] is already full."))
		return 0
	var/spare = max(0, L.oxygen - HABITAT_MIN_OXYGEN_KPA * L.volume)
	var/used = A.refill(spare)
	if (used <= 0)
		to_chat(user, SPAN_WARNING("\The [source] has no oxygen to spare; fill the module first."))
		return 0
	L.oxygen -= used
	to_chat(user, SPAN_NOTICE("You refill \the [A] from \the [source]."))
	return used

/obj/structure/life_support/heater/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/clothing/suit/pressure_suit))
		var/obj/item/clothing/suit/pressure_suit/S = W
		if (S.heater_charge >= SUIT_HEATER_SECONDS)
			to_chat(user, SPAN_NOTICE("\The [S]'s heater battery is already full."))
			return
		if (!has_power())
			to_chat(user, SPAN_WARNING("\The [src] has no power to charge it."))
			return
		to_chat(user, SPAN_NOTICE("You plug \the [S] into \the [src]..."))
		if (!do_after(user, 30, src) || QDELETED(S))
			return
		S.heater_charge = SUIT_HEATER_SECONDS
		to_chat(user, SPAN_NOTICE("\The [S]'s heater battery is full."))
		return
	return ..()

// ---------------------------------------------------------------- wearer

/mob/living/human/proc/pressure_suit_sealed()
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	if (!istype(S) || S.integrity <= 0)
		return FALSE
	if (!istype(head, /obj/item/clothing/head/pressure_helmet))
		return FALSE
	var/obj/item/pressure_tank/A = back
	return istype(A) && A.air_seconds > 0

/proc/pressure_crossed(before, after, threshold)
	return before > threshold && after <= threshold

// One breath from the tank while sealed outside.
/mob/living/human/proc/pressure_suit_breathe(seconds = SUIT_LIFE_SECONDS)
	var/obj/item/pressure_tank/A = back
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	if (!istype(A) || !istype(S))
		return FALSE
	var/used = seconds
	if (S.integrity <= SUIT_LEAKY_INTEGRITY)
		used *= SUIT_LEAK_MULTIPLIER
	var/before = A.air_seconds
	A.air_seconds = max(0, A.air_seconds - used)
	if (A.air_seconds <= 0)
		to_chat(src, SPAN_DANGER("Your air tank is empty!"))
	else if (pressure_crossed(before, A.air_seconds, SUIT_EMPTY_TANK_SECONDS))
		to_chat(src, SPAN_DANGER("Your air tank is almost empty. Get inside now!"))
	else if (pressure_crossed(before, A.air_seconds, SUIT_LOW_TANK_SECONDS))
		to_chat(src, SPAN_WARNING("Your air tank is running low."))
	return TRUE

// The temperature a sealed wearer feels against this ambient.
/mob/living/human/proc/pressure_suit_temperature_c(ambient)
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	if (!istype(S) || ambient >= SUIT_ROOM_C)
		return ambient
	if (S.heater_charge <= 0)
		return min(SUIT_ROOM_C, ambient + SUIT_UNHEATED_INSULATION_C)
	var/before = S.heater_charge
	S.heater_charge = max(0, S.heater_charge - SUIT_LIFE_SECONDS)
	if (S.heater_charge <= 0)
		to_chat(src, SPAN_DANGER("Your suit heater has run flat."))
	else if (pressure_crossed(before, S.heater_charge, SUIT_LOW_HEATER_SECONDS))
		to_chat(src, SPAN_WARNING("Your suit heater battery is running low."))
	return SUIT_ROOM_C

// Called by apply_damage for brute and burn hits.
/mob/living/human/handle_suit_punctures(var/damtype, var/damage, var/def_zone)
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	if (!istype(S) || damage < SUIT_HIT_MIN_DAMAGE)
		return ..()
	if (S.wear_down(damage / 2))
		to_chat(src, SPAN_DANGER("Your pressure suit tears open!"))
	return ..()

// Crater rubble scrapes suits.
/turf/floor/dirt/dust/regolith/crater/Entered(atom/movable/A, atom/OldLoc)
	..()
	var/mob/living/human/H = A
	if (!istype(H) || !prob(SUIT_RUBBLE_SCRAPE_CHANCE))
		return
	var/obj/item/clothing/suit/pressure_suit/S = H.wear_suit
	if (istype(S) && S.integrity > 0)
		if (S.wear_down(2))
			to_chat(H, SPAN_DANGER("Sharp rubble tears your pressure suit open!"))
		else
			to_chat(H, SPAN_WARNING("Sharp rubble scrapes your pressure suit."))

// Suit readout in the Status panel.
/mob/living/human/Stat()
	. = ..()
	var/obj/item/clothing/suit/pressure_suit/S = wear_suit
	if (!istype(S) || !statpanel("Status"))
		return
	var/obj/item/pressure_tank/A = back
	stat("Suit integrity:", "[round(S.integrity)]%")
	stat("Suit heater:", "[round(100 * S.heater_charge / SUIT_HEATER_SECONDS)]%")
	stat("Suit air:", istype(A) ? "[round(A.air_seconds / 60)] min" : "no tank")
