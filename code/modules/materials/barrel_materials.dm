// Cannon barrels by material (docs/material-roles.md, "Cannon barrels").
//
// The smoothbore cannon can be cast in bronze or iron as well as steel, or
// built of iron-hooped wood. A cannon stores its barrel's material name and
// how worn the barrel is; what the material means is asked of the material:
//   barrel_life(name)        -> shots before the barrel is spent
//   barrel_fails_early(name) -> hard but not tough: it can burst unannounced
// A steel barrel is exactly the cannon it always was and never wears. The
// cannon body in code/modules/1713/siege/piece.dm is untouched; this file
// wraps it.

// A spent barrel that fails early may burst from this share of its life on.
#define BARREL_EARLY_FROM 50
// Chance a shot bursts such a barrel once past that point.
#define BARREL_EARLY_CHANCE 2
// From this share of its life on a barrel that gives warning shows it.
#define BARREL_WARN_FROM 75

var/global/list/barrel_life_cache = list()

// Shots a barrel of this material lasts: wood 5, copper 22, brass 64,
// bronze 101, iron 204.
/proc/barrel_life(material_name)
	var/cached = barrel_life_cache[material_name]
	if (isnull(cached))
		var/material/M = get_material_by_name(material_name)
		cached = M ? max(1, round((M.toughness * M.firmness / 1000) ** 2 * 5)) : 0
		barrel_life_cache[material_name] = cached
	return cached

// A metal at least as hard as it is tough cracks without bulging first: iron.
// Bronze, brass, copper and wood give warning.
/proc/barrel_fails_early(material_name)
	var/material/M = get_material_by_name(material_name)
	return M ? M.toughness <= M.firmness : FALSE

/obj/structure/cannon
	// Material name, as get_material_by_name() takes it.
	var/barrel_material = "steel"
	// 0 (new) to 100 (spent). Steel never wears.
	var/barrel_wear = 0

/obj/structure/cannon/New(newloc, material_name)
	if (istext(material_name) && get_material_by_name(material_name) && barrel_life(material_name))
		barrel_material = material_name
	..(newloc)
	apply_barrel_material()

/obj/structure/cannon/after_load()
	. = ..()
	apply_barrel_material()

/obj/structure/cannon/proc/barrel_name(material/M)
	return "[M.display_name] cannon"

// A steel cannon keeps the name and look it always had.
/obj/structure/cannon/proc/apply_barrel_material()
	var/material/M = get_material_by_name(barrel_material)
	if (!M || barrel_material == "steel")
		return
	name = barrel_name(M)
	color = M.icon_colour

// The same cannon behind its own recipe: iron hoops are a second input, and
// second inputs are declared by result type (config/craft_needs.json).
/obj/structure/cannon/hooped
	name = "hooped cannon"
	desc = "A cannon bored from a log and bound with iron hoops. It is good for a handful of shots."
	barrel_material = "wood"

/obj/structure/cannon/hooped/barrel_name(material/M)
	return "iron-hooped [M.name == "wood" ? "wooden" : M.display_name] cannon"

/obj/structure/cannon/proc/barrel_burst()
	visible_message(SPAN_DANGER("The barrel of \the [src] bursts!"))
	var/turf/T = get_turf(src)
	qdel(src)
	if (T)
		explosion(T, 0, 1, 2, 3)

// Charge one shot to the barrel. Returns TRUE when it burst.
/obj/structure/cannon/proc/barrel_shot()
	if (barrel_material == "steel")
		return FALSE
	var/life = barrel_life(barrel_material)
	if (!life)
		return FALSE
	var/was = barrel_wear
	barrel_wear = min(100, barrel_wear + 100 / life)
	if (barrel_fails_early(barrel_material))
		if (was >= BARREL_EARLY_FROM && prob(BARREL_EARLY_CHANCE))
			barrel_burst()
			return TRUE
	else if (was >= 100)
		barrel_burst()
		return TRUE
	else if (barrel_wear >= 100)
		visible_message(SPAN_DANGER("The barrel of \the [src] has bulged and split along a seam. The next shot will burst it."))
	else if (barrel_wear >= BARREL_WARN_FROM && was < BARREL_WARN_FROM)
		visible_message(SPAN_WARNING("The barrel of \the [src] is starting to bulge."))
	return FALSE

/obj/structure/cannon/discharge(mob/user)
	var/fired = loaded.len
	. = ..()
	if (fired && !QDELETED(src))
		barrel_shot()

/obj/structure/cannon/examine(mob/user, distance)
	..(user, distance)
	if (barrel_material == "steel")
		return
	var/material/M = get_material_by_name(barrel_material)
	if (!M)
		return
	to_chat(user, "Its barrel is [M.display_name], good for about [barrel_life(barrel_material)] shots.")
	if (barrel_fails_early(barrel_material))
		to_chat(user, SPAN_WARNING("A barrel of this metal gives no warning: once it is well used, any shot may burst it."))
		if (barrel_wear >= BARREL_EARLY_FROM)
			to_chat(user, SPAN_WARNING("It has fired a great many shots."))
	else if (barrel_wear >= 100)
		to_chat(user, SPAN_DANGER("The barrel has bulged and split. The next shot will burst it."))
	else if (barrel_wear >= BARREL_WARN_FROM)
		to_chat(user, SPAN_WARNING("The barrel is starting to bulge."))
	else if (barrel_wear > 0)
		to_chat(user, "The barrel has seen some use.")

#undef BARREL_EARLY_FROM
#undef BARREL_EARLY_CHANCE
#undef BARREL_WARN_FROM
