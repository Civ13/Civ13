// ============================================================
// Hull magnetic signature (docs/naval-mines.md)
// ------------------------------------------------------------
// A steel hull carries a magnetic field of its own; a wooden one does not.
// Magnetic mines (naval_mines.dm) feel it. The signature is worked out from
// what the body is made of only when a mine is close enough to ask, so a
// craft on an empty sea counts nothing:
//
//   - a turf-built ship has a fixed figure for her design (magnetic_base);
//   - a built hull counts its metal floors and walls, one a tile;
//   - a modular boat counts its steel frames, two a frame (wooden frames
//     count nothing, frames of land vehicles one);
//   - every running engine aboard adds MAGNETIC_PER_ENGINE.
//
// What a mine feels is that figure after a wiping and a degaussing coil
// (degaussing.dm) have taken their share off.
// ============================================================

#define MAGNETIC_PER_METAL_TILE 1
#define MAGNETIC_PER_STEEL_FRAME 2
#define MAGNETIC_PER_OTHER_FRAME 1
#define MAGNETIC_PER_ENGINE 5

// The words the helm uses, by the felt signature.
#define MAGNETIC_FAINT 20
#define MAGNETIC_STRONG 100

/datum/vessel
	// The signature of the whole design: 0 for a wooden ship.
	var/magnetic_base = 0

// TRUE for a floor or wall that a magnetic mine would feel.
/obj/covers/proc/magnetic_hull()
	if (wood)
		return FALSE
	var/m = lowertext("[material]")
	return findtext(m, "steel") || findtext(m, "iron") || findtext(m, "metal")

// ---- Bodies ----

/datum/craft_body/proc/magnetic_base()
	return 0

/datum/craft_body/template/magnetic_base()
	return vessel ? vessel.magnetic_base : 0

/datum/craft_body/built/magnetic_base()
	. = 0
	for (var/turf/T in cells())
		for (var/obj/covers/C in T)
			if (C.loc == T && C.magnetic_hull())
				. += MAGNETIC_PER_METAL_TILE
	if (craft)
		for (var/datum/craft_drive/fitted/engine/D in craft.drives)
			if (D.ready())
				. += MAGNETIC_PER_ENGINE

/datum/craft_body/axis/magnetic_base()
	. = 0
	if (!axis)
		return
	for (var/obj/structure/vehicleparts/frame/F in axis.components)
		if (istype(F, /obj/structure/vehicleparts/frame/ship/steel))
			. += MAGNETIC_PER_STEEL_FRAME
		else if (!istype(F, /obj/structure/vehicleparts/frame/ship))
			. += MAGNETIC_PER_OTHER_FRAME
	if (axis.engine && axis.engine.on)
		. += MAGNETIC_PER_ENGINE

// ---- The craft ----

// What fraction of her signature is left after her counters (1 = all of it).
/datum/craft/proc/magnetic_factor()
	return 1

/datum/craft/proc/magnetic_signature()
	if (!body || !body.placed())
		return 0
	return max(0, body.magnetic_base() * magnetic_factor())

/proc/magnetic_reading(signature)
	if (signature <= 0)
		return "none"
	if (signature < MAGNETIC_FAINT)
		return "faint"
	if (signature <= MAGNETIC_STRONG)
		return "strong"
	return "very strong"

// The line the helm reads.
/datum/craft/proc/magnetic_text()
	return "Magnetic signature: [magnetic_reading(magnetic_signature())]."
