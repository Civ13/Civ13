// Round profiles and the single projectile impact result (issue #4443, phase 4).
//
// A cartridge's caliber decides what it fits; its projectile type carries the
// caliber's own damage, armor penetration and cover passage. A round profile
// (normal, AP, HP) then adjusts those base values within fixed bounds, so AP
// moves a round up about one protection tier instead of multiplying every
// stat, and never grants unlimited wall or body passage.

/datum/ammo_profile
	var/id = "normal"
	var/name = "standard"
	var/damage_mult = 1
	var/armor_penetration_mult = 1
	// Largest armor penetration a profile may add, whatever the multiplier.
	var/armor_penetration_bonus_cap = 0
	// Added to the round's cover passage (penetrating); -1 removes all passage.
	var/cover_passage = 0
	var/summary = null

/datum/ammo_profile/proc/apply(obj/item/projectile/P)
	P.damage = P.base_damage * damage_mult
	var/pen = P.base_armor_penetration * armor_penetration_mult
	if (pen > P.base_armor_penetration)
		pen = min(pen, P.base_armor_penetration + armor_penetration_bonus_cap)
	P.armor_penetration = max(pen, 0)
	if (cover_passage < 0)
		P.penetrating = 0
	else
		P.penetrating = P.base_penetrating + cover_passage

/datum/ammo_profile/armor_piercing
	id = "AP"
	name = "armor-piercing"
	damage_mult = 0.7
	armor_penetration_mult = 1.5
	armor_penetration_bonus_cap = 40
	cover_passage = 1
	summary = "Armor-piercing: about one protection tier better against armor and passes one more layer of cover, but does less damage to unprotected targets."

/datum/ammo_profile/hollow_point
	id = "HP"
	name = "hollow-point"
	damage_mult = 1.3
	armor_penetration_mult = 0.5
	cover_passage = -1
	summary = "Hollow-point: hits unprotected targets harder, but armor stops it easily and it does not pass through cover."

var/global/list/ammo_profiles_by_id = null

// Unknown ids fall back to the standard profile instead of failing.
/proc/ammo_profile(id)
	if (!ammo_profiles_by_id)
		ammo_profiles_by_id = list()
		for (var/profile_type in typesof(/datum/ammo_profile))
			var/datum/ammo_profile/profile = new profile_type
			ammo_profiles_by_id[profile.id] = profile
	var/datum/ammo_profile/found = ammo_profiles_by_id[id]
	return found ? found : ammo_profiles_by_id["normal"]

// Game protection tiers for bullet armor, measured against the standard
// penetration of each round class (pistol 40, intermediate rifle 60, full
// rifle 80). Tiers are game terms, not real-world ratings.
#define BULLET_TIER_PISTOL 40
#define BULLET_TIER_INTERMEDIATE 60
#define BULLET_TIER_RIFLE 80

/proc/bullet_protection_tier(armor)
	if (armor <= 0)
		return null
	if (armor < BULLET_TIER_PISTOL)
		return "light"
	if (armor < BULLET_TIER_INTERMEDIATE)
		return "medium"
	if (armor < BULLET_TIER_RIFLE)
		return "heavy"
	return "very heavy"

/proc/bullet_protection_text(armor)
	switch (bullet_protection_tier(armor))
		if ("light")
			return "Light bullet protection: softens pistol and rifle rounds."
		if ("medium")
			return "Medium bullet protection: stops ordinary pistol rounds and softens rifle rounds."
		if ("heavy")
			return "Heavy bullet protection: stops ordinary pistol and intermediate rifle rounds."
		if ("very heavy")
			return "Very heavy bullet protection: stops ordinary rifle rounds; armor-piercing and heavy rounds still get through."
	return null

#undef BULLET_TIER_PISTOL
#undef BULLET_TIER_INTERMEDIATE
#undef BULLET_TIER_RIFLE

// One projectile hit on one living target, resolved once in order: armor on
// the hit zone, bounded residual damage, nonnegative armor wear, then which
// secondary effects may follow. Every bullet_act step reads this result.
/datum/projectile_impact
	var/mob/living/target = null
	var/def_zone = null
	var/armor = 0
	var/damage_in = 0
	var/damage = 0
	var/absorbed = 0
	var/wear = 0
	// Armor took the whole hit: no wound, stun, embedding or instant kill.
	var/stopped = FALSE

/datum/projectile_impact/Destroy()
	target = null
	return ..()

/mob/living/proc/resolve_projectile_impact(obj/item/projectile/P, def_zone)
	var/datum/projectile_impact/impact = new
	impact.target = src
	impact.def_zone = def_zone
	impact.armor = getarmor(def_zone, P.check_armor)
	impact.damage_in = max(P.damage, 0)
	impact.damage = projectile_armor_residual(P.damage, P.armor_penetration, impact.armor)
	impact.absorbed = max(impact.damage_in - impact.damage, 0)
	impact.wear = impact.absorbed * 0.01
	impact.stopped = impact.armor > 0 && impact.damage <= 0 && impact.damage_in > 0
	return impact

// The impact for this target and zone, resolved on first use and reused by the
// rest of the same hit.
/obj/item/projectile/var/tmp/datum/projectile_impact/impact_result = null

/obj/item/projectile/proc/impact_on(mob/living/L, def_zone)
	if (!impact_result || impact_result.target != L || impact_result.def_zone != def_zone)
		impact_result = L.resolve_projectile_impact(src, def_zone)
	return impact_result
