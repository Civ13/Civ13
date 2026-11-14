// Part roles (docs/material-roles.md): what a material is like at one job.
//
// A role names the standard material for the job and the properties that
// matter. A rating compares a material with that standard:
//   performance - speed, load or output, PART_PERFORMANCE_MIN..MAX
//   lifetime    - uses before it wears out, PART_LIFETIME_MIN..MAX
//   mass        - weight against the standard part, unbounded
// A term list is property -> exponent: the rating is the product of
// (material's value / standard's value) ** exponent.
/datum/part_role
	var/id
	var/name
	var/standard = "steel"          // material name every rating is measured against
	var/list/performance_terms = list()
	var/list/lifetime_terms = list()
	var/min_toughness = 0           // refuses anything more fragile
	var/min_firmness = 0            // refuses anything softer
	var/min_heat = 0                // refuses anything that fails below this, deg C
	var/refuses_flammable = FALSE

// Why this material cannot do the job at all, or null when it can.
/datum/part_role/proc/refusal(material/M)
	if (!M)
		return "it is not a material"
	if (M.toughness < min_toughness)
		return "[M.display_name] would crack"
	if (M.firmness < min_firmness)
		return "[M.display_name] is too soft"
	if (M.heat_limit < min_heat)
		return "[M.display_name] cannot take the heat"
	if (refuses_flammable && M.flammable)
		return "[M.display_name] would burn"
	for (var/property in performance_terms)
		if (M.role_property(property) <= 0)
			return "[M.display_name] has no [property]"
	return null

/datum/part_role/proc/term_product(material/M, material/S, list/terms)
	. = 1
	for (var/property in terms)
		var/base = S.role_property(property)
		if (base <= 0)
			continue
		. *= (max(0, M.role_property(property)) / base) ** terms[property]

// list(performance, lifetime, mass), or null when the material is refused.
/datum/part_role/proc/rate(material/M)
	var/material/S = get_material_by_name(standard)
	if (!S || refusal(M))
		return null
	var/performance = max(PART_PERFORMANCE_MIN, min(PART_PERFORMANCE_MAX, term_product(M, S, performance_terms)))
	var/lifetime = max(PART_LIFETIME_MIN, min(PART_LIFETIME_MAX, term_product(M, S, lifetime_terms)))
	return list(performance, lifetime, M.density / max(1, S.density))

/datum/part_role/edge
	id = ROLE_EDGE
	name = "cutting edge"
	performance_terms = list("firmness" = 0.5)
	lifetime_terms = list("toughness" = 0.5, "wear" = 0.5)

/datum/part_role/striker
	id = ROLE_STRIKER
	name = "striking head"
	standard = "iron"
	performance_terms = list("density" = 0.5, "firmness" = 0.25)
	lifetime_terms = list("toughness" = 1)
	min_toughness = PART_FRAGILE_TOUGHNESS

/datum/part_role/handle
	id = ROLE_HANDLE
	name = "handle"
	standard = "woodplank"
	performance_terms = list("density" = -0.1)
	lifetime_terms = list("toughness" = 1)
	min_toughness = PART_FRAGILE_TOUGHNESS

/datum/part_role/gear
	id = ROLE_GEAR
	name = "gear"
	performance_terms = list("firmness" = 0.3, "toughness" = 0.5)
	lifetime_terms = list("wear" = 1)
	min_toughness = PART_FRAGILE_TOUGHNESS
	min_firmness = PART_SOFT_FIRMNESS

/datum/part_role/bearing
	id = ROLE_BEARING
	name = "bearing"
	performance_terms = list("wear" = 0.3)
	lifetime_terms = list("wear" = 1)
	min_firmness = PART_SOFT_FIRMNESS

/datum/part_role/spring
	id = ROLE_SPRING
	name = "spring"
	performance_terms = list("spring" = 1)
	lifetime_terms = list("toughness" = 0.5)
	min_firmness = 30 // a coil or leaf of wood is a limb, not a spring

/datum/part_role/limb
	id = ROLE_LIMB
	name = "bow limb"
	standard = "wood"
	performance_terms = list("spring" = 1)
	lifetime_terms = list("toughness" = 0.5)
	min_toughness = PART_FRAGILE_TOUGHNESS

/datum/part_role/pipe
	id = ROLE_PIPE
	name = "pipe"
	lifetime_terms = list("rustproof" = 1)

/datum/part_role/vessel
	id = ROLE_VESSEL
	name = "vessel"
	performance_terms = list("heat_limit" = 0.5, "toughness" = 0.5)
	lifetime_terms = list("rustproof" = 1)
	min_heat = 300
	refuses_flammable = TRUE

/datum/part_role/conductor
	id = ROLE_CONDUCTOR
	name = "conductor"
	standard = "copper"
	performance_terms = list("conductivity" = 1)
	lifetime_terms = list("rustproof" = 0.5)

/datum/part_role/wheel
	id = ROLE_WHEEL
	name = "wheel"
	performance_terms = list("firmness" = 0.3, "toughness" = 0.5)
	lifetime_terms = list("wear" = 1)
	min_firmness = PART_SOFT_FIRMNESS

var/global/list/part_roles          // id -> /datum/part_role
var/global/list/part_rating_cache = list() // "role|material" -> rating list, or 0 when refused

/proc/get_part_role(id)
	if (!part_roles)
		part_roles = list()
		for (var/role_type in typesof(/datum/part_role) - /datum/part_role)
			var/datum/part_role/R = new role_type
			if (R.id)
				part_roles[R.id] = R
	return part_roles[id]

// list(performance, lifetime, mass) for a material name in a role, or null
// when the role is unknown or refuses the material. Worked out once per pair.
/proc/part_rating(role_id, material_name)
	var/key = "[role_id]|[material_name]"
	var/cached = part_rating_cache[key]
	if (isnull(cached))
		var/datum/part_role/R = get_part_role(role_id)
		var/material/M = get_material_by_name(material_name)
		cached = (R && M) ? R.rate(M) : null
		if (!cached)
			cached = 0
		part_rating_cache[key] = cached
	return cached || null

// Performance alone, 0 when refused.
/proc/part_performance(role_id, material_name)
	var/list/rating = part_rating(role_id, material_name)
	return rating ? rating[1] : 0

// Why a role refuses a material name, or null when it accepts it.
/proc/part_refusal(role_id, material_name)
	var/datum/part_role/R = get_part_role(role_id)
	if (!R)
		return "no such part"
	return R.refusal(get_material_by_name(material_name))
