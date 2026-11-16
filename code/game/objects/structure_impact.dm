// Structure impacts: one way to hit any part of a building with a force.
//
// Vehicles, crashing aircraft, falling masonry and siege engines all come
// through structure_impact(), so a wall gives way the same way whatever hit
// it. The force is in hit points of a wooden part: a part of another material
// takes force / resistance (structure_material_resistance()) as damage.
//
// structure_impact() returns the force left over after the part: 0 when it
// held, more when it gave way and the rest carries on (a truck through a plank
// wall keeps some of its push). Something that is not a building part returns
// the whole force untouched; structure_impact_part() says which atoms are.

// How much of a crushing force a material shrugs off: breaking a part takes
// its health times this. Wood is 1.
/proc/structure_material_resistance(name)
	if (!name)
		return 1
	switch (lowertext("[name]"))
		if ("thatch", "straw", "palm", "leaves", "cloth", "canvas", "hide", "leather", "glass", "paper")
			return 0.5
		if ("clay", "adobe", "mud", "earth", "dirt", "cob", "sandbag")
			return 1.5
		if ("stone", "brick", "sandstone", "marble", "granite", "basalt", "obsidian", "tiles", "rock", "limestone")
			return 2.5
		if ("concrete", "cement", "reinforced concrete")
			return 3.5
		if ("steel", "iron", "metal", "plasteel", "aluminium", "bronze", "copper", "gold", "silver", "diamond", "lead")
			return 5
	return 1

// The material name an atom is judged by, or null for wood.
/atom/proc/structure_impact_material()
	return null

/atom/proc/structure_impact_resistance(kind = IMPACT_CRUSH)
	if (kind == IMPACT_RAW)
		return 1
	return structure_material_resistance(structure_impact_material())

// Whether A is a part of a building that structure_impact() damages.
/proc/structure_impact_part(atom/A)
	if (!A || QDELETED(A))
		return FALSE
	return A.structure_impact_part()

/atom/proc/structure_impact_part()
	return FALSE

// Hit this part with force. dir is the way the force travels and source what
// delivered it; both are for the parts and callers that care. Returns the
// force left over.
/atom/proc/structure_impact(force, kind = IMPACT_CRUSH, atom/source = null, dir = 0)
	return force

// Shared bookkeeping: a part with health left takes force / resistance and
// passes on whatever exceeded what it could stand.
/proc/structure_impact_leftover(force, health_before, resistance)
	return max(0, force - max(0, health_before) * resistance)

// ---- player walls, floors and fittings (covers) --------------------------

/obj/covers/structure_impact_material()
	return material

/obj/covers/structure_impact_part()
	return !incomplete

/obj/covers/structure_impact(force, kind = IMPACT_CRUSH, atom/source = null, dir = 0)
	if (force <= 0 || QDELETED(src) || incomplete)
		return force
	var/resistance = structure_impact_resistance(kind)
	var/before = health
	health -= force / resistance
	if (wall)
		update_icon()
	try_destroy()
	return structure_impact_leftover(force, before, resistance)

// Crack stage a wall shows for the damage it has taken: 0 to 3.
/obj/covers/proc/impact_crack_stage()
	if (!wall || maxhealth <= 0 || health >= maxhealth * 0.75)
		return 0
	if (health >= maxhealth * 0.5)
		return 1
	if (health >= maxhealth * 0.25)
		return 2
	return 3

// ---- mapped walls (turfs) -------------------------------------------------

// A mapped wall stands twice its material's hit points against a crash, so it
// is about as sturdy as a player-built wall of the same stuff.
#define TURF_WALL_IMPACT_SCALE 2

/turf/wall/structure_impact_material()
	return material ? material.name : "stone"

/turf/wall/structure_impact_part()
	return TRUE

/turf/wall/structure_impact(force, kind = IMPACT_CRUSH, atom/source = null, dir = 0)
	if (force <= 0)
		return force
	var/resistance = structure_impact_resistance(kind)
	var/cap = material ? material.integrity : 150
	var/before = (cap - damage) * TURF_WALL_IMPACT_SCALE
	take_damage(force / resistance / TURF_WALL_IMPACT_SCALE)
	return structure_impact_leftover(force, before, resistance)

#undef TURF_WALL_IMPACT_SCALE

// The map's edge and other unbreakable walls take nothing and stop everything.
/turf/wall/indestructable/structure_impact(force, kind = IMPACT_CRUSH, atom/source = null, dir = 0)
	return 0

// ---- roofs ------------------------------------------------------------------

/obj/roof/structure_impact_material()
	if (istype(src, /obj/roof/thatch) || istype(src, /obj/roof/palm))
		return "thatch"
	if (istype(src, /obj/roof/canopy))
		return "cloth"
	if (istype(src, /obj/roof/glass))
		return "glass"
	if (istype(src, /obj/roof/clay))
		return "clay"
	if (istype(src, /obj/roof/concrete))
		return "concrete"
	if (istype(src, /obj/roof/sandstone) || istype(src, /obj/roof/mayan))
		return "stone"
	return "wood"

/obj/roof/structure_impact_part()
	return TRUE

/obj/roof/structure_impact(force, kind = IMPACT_CRUSH, atom/source = null, dir = 0)
	if (force <= 0 || QDELETED(src))
		return force
	var/resistance = structure_impact_resistance(kind)
	var/before = health
	health -= force / resistance
	if (health <= 0)
		visible_message(SPAN_DANGER("\The [src] caves in!"))
		qdel(src)
	return structure_impact_leftover(force, before, resistance)

// ---- structures: pillars, supports, doors, gates, barricades ---------------

/obj/structure/structure_impact_material()
	if ("material" in vars)
		var/material/M = vars["material"]
		if (istype(M))
			return M.name
		if (istext(M))
			return M
	if ("material_name" in vars)
		var/name_var = vars["material_name"]
		if (istext(name_var))
			return name_var
	return null

/obj/structure/roof_support/structure_impact_material()
	return "wood"

/obj/structure/mine_support/structure_impact_material()
	return "wood"

/obj/structure/mine_support/stone/structure_impact_material()
	return "stone"

/obj/structure/mine_support/stone/concrete/structure_impact_material()
	return "concrete"

/obj/structure/structure_impact_part()
	return !isnull(health) && (istype(src, /obj/structure/roof_support) || istype(src, /obj/structure/mine_support) || istype(src, /obj/structure/simple_door) || istype(src, /obj/structure/gate) || istype(src, /obj/structure/castle_gate) || istype(src, /obj/structure/barricade))

/obj/structure/structure_impact(force, kind = IMPACT_CRUSH, atom/source = null, dir = 0)
	if (force <= 0 || QDELETED(src) || !structure_impact_part())
		return force
	var/resistance = structure_impact_resistance(kind)
	var/before = health
	impact_structure_damage(force / resistance)
	return structure_impact_leftover(force, before, resistance)

// How a part loses health to an impact. Doors and gates are smashed apart.
/obj/structure/proc/impact_structure_damage(amount)
	return take_structure_damage(amount)

/obj/structure/proc/impact_smash(amount)
	health -= amount
	if (istype(src, /obj/structure/simple_door/key_door))
		src:damage_display()
	if (health <= 0)
		visible_message(SPAN_DANGER("\The [src] is smashed apart!"))
		qdel(src)
		return TRUE
	return FALSE

/obj/structure/simple_door/impact_structure_damage(amount)
	return impact_smash(amount)

/obj/structure/gate/impact_structure_damage(amount)
	return impact_smash(amount)

/obj/structure/castle_gate/impact_structure_damage(amount)
	return impact_smash(amount)
