// Faction halls (docs/land-stages.md, "Faction halls"). Val (2026-11-14):
// factions grow through meaningful infrastructure, never by buying from NPCs.
// A faction's member limit starts at FACTION_HALL_BASE_LIMIT. Its leader
// designates a hall seat and members deliver materials to raise it a tier at
// a time; each tier needs a later age and raises the limit while the hall
// stands. From the longhouse on, the hall must stand indoors. Every standing
// colony of the faction in another land adds FACTION_HALL_COLONY_BONUS. The
// server's FACTION_MEMBER_LIMIT stays the ceiling, and a leader may still set
// a lower limit. A lower limit never removes anyone: it only stops new
// members joining. A destroyed hall takes its tiers with it.
//
// The hall keeps its faction, tier and delivered materials in its own vars,
// so it saves with the world. The leader or a works officer can unfasten it
// and move it (faction_fixtures.dm); a loose hall counts for nothing. Nothing here sleeps except the designate
// prompt, which rechecks after it.

#define FACTION_HALL_BASE_LIMIT 10
#define FACTION_HALL_COLONY_BONUS 5

var/global/list/faction_halls = list() // every faction hall, designated or not

// Tier -> list(name, member limit, earliest ordinal age, indoors,
// list(material kind = list(stack type, amount, label))).
var/global/list/faction_hall_tiers = list(
	list("council fire", 15, 0, FALSE, list(
		"wood" = list(/obj/item/stack/material/wood, 40, "wood"),
		"stone" = list(/obj/item/stack/material/stone, 40, "stone"))),
	list("longhouse", 25, 1, TRUE, list(
		"wood" = list(/obj/item/stack/material/wood, 150, "wood"),
		"stone" = list(/obj/item/stack/material/stone, 100, "stone"),
		"cloth" = list(/obj/item/stack/material/cloth, 30, "cloth"))),
	list("town hall", 35, 2, TRUE, list(
		"stone" = list(/obj/item/stack/material/stone, 300, "stone"),
		"iron" = list(/obj/item/stack/material/iron, 60, "iron"),
		"glass" = list(/obj/item/stack/material/glass, 40, "glass"))),
	list("capitol", 50, 4, TRUE, list(
		"stone" = list(/obj/item/stack/material/stone, 600, "stone"),
		"steel" = list(/obj/item/stack/material/steel, 150, "steel"),
		"glass" = list(/obj/item/stack/material/glass, 80, "glass"),
		"gold" = list(/obj/item/stack/material/gold, 20, "gold"))))

// --- Limits ----------------------------------------------------------------

// The highest tier among the faction's standing halls (0 = none).
/obj/map_metadata/proc/faction_hall_tier(faction)
	var/best = 0
	for (var/obj/structure/faction_hall/H in faction_halls)
		if (!QDELETED(H) && H.faction == faction && isturf(H.loc) && H.anchored && H.tier > best && H.tier_stands(H.tier))
			best = H.tier
	return best

// Standing colonies of this faction in other lands, as the coordinator last
// reported them (land_stage.dm).
/obj/map_metadata/proc/faction_colony_count(faction)
	if (!shard_group.enabled || faction_colonies()[faction])
		return 0
	var/parent = party_train_faction_party(faction)
	var/count = 0
	for (var/land in land_stages)
		var/list/entry = land_stages[land]
		if (!islist(entry) || !islist(entry["colonies"]))
			continue
		for (var/list/colony in entry["colonies"])
			if (islist(colony) && colony["parent"] == parent && !colony["paused"])
				count++
	return count

// What the faction's infrastructure supports, before the server ceiling.
/obj/map_metadata/proc/faction_infrastructure_limit(faction)
	var/tier = faction_hall_tier(faction)
	var/limit = tier ? faction_hall_tiers[tier][2] : FACTION_HALL_BASE_LIMIT
	return limit + faction_colony_count(faction) * FACTION_HALL_COLONY_BONUS + province_rank_member_bonus(faction) // province_ranks.dm

// --- The hall ----------------------------------------------------------------

/obj/structure/faction_hall
	name = "faction hall seat"
	desc = "The seat of a faction's hall. Its leader designates it; members raise it into a council fire, a longhouse, a town hall and a capitol, and each lets the faction take in more members."
	icon = 'icons/obj/banners.dmi'
	icon_state = "banner_a"
	density = TRUE
	anchored = TRUE
	flammable = TRUE
	// The faction this hall belongs to, by name. faction_rename.dm rewrites
	// vars called "faction", so a rename keeps the binding.
	var/faction = null
	var/tier = 0 // tiers built (faction_hall_tiers)
	var/list/delivered = list() // materials handed over toward the next tier
	var/seat_name = "hall seat" // its name before the first tier
	var/hall_word = "hall" // what it is called in messages
	var/last_words = "It is a capitol, the greatest hall." // said once fully built

// The tiers this seat is raised through (faction_hall_tiers' layout).
/obj/structure/faction_hall/proc/tiers()
	return faction_hall_tiers

/obj/structure/faction_hall/New()
	..()
	faction_halls |= src
	update_icon()

/obj/structure/faction_hall/Destroy()
	faction_halls -= src
	return ..()

/obj/structure/faction_hall/update_icon()
	name = faction ? (tier ? "[faction] [tiers()[tier][1]]" : "[faction] [seat_name]") : initial(name)

// A tier counts only where it may stand: indoor tiers need a roof.
/obj/structure/faction_hall/proc/tier_stands(t)
	if (t < 1 || t > tiers().len)
		return FALSE
	if (!tiers()[t][4])
		return TRUE
	var/area/A = get_area(src)
	return A && A.location != AREA_OUTSIDE

/obj/structure/faction_hall/proc/next_tier()
	return tier < tiers().len ? tier + 1 : 0

/obj/structure/faction_hall/proc/remaining()
	var/list/left = list()
	var/t = next_tier()
	if (!t)
		return left
	var/list/needs = tiers()[t][5]
	for (var/kind in needs)
		var/list/need = needs[kind]
		var/missing = need[2] - (delivered[kind] || 0)
		if (missing > 0)
			left[kind] = missing
	return left

/obj/structure/faction_hall/proc/progress_text()
	var/t = next_tier()
	if (!t)
		return last_words
	var/list/parts = list()
	var/list/needs = tiers()[t][5]
	for (var/kind in needs)
		var/list/need = needs[kind]
		parts += "[need[3]] [delivered[kind] || 0]/[need[2]]"
	return "Toward a [tiers()[t][1]]: [jointext(parts, ", ")]."

// Why the next tier cannot be built here yet, or null.
/obj/structure/faction_hall/proc/tier_block(t)
	if (!t)
		return "This hall cannot grow any further."
	if (!map || map.ordinal_age < tiers()[t][3])
		return "A [tiers()[t][1]] needs the [ordinal_age_name(tiers()[t][3])]."
	var/area/A = get_area(src)
	if (tiers()[t][4] && (!A || A.location == AREA_OUTSIDE))
		return "A [tiers()[t][1]] must stand indoors, under a roof."
	return null

/obj/structure/faction_hall/examine(mob/user)
	..()
	if (!faction)
		to_chat(user, "No faction holds it yet. A faction leader can designate it as their faction's hall.")
		return
	if (!anchored)
		to_chat(user, SPAN_WARNING("It stands loose. Until its leader or a works officer fastens it again, it counts for nothing."))
	else if (tier && !tier_stands(tier))
		to_chat(user, SPAN_WARNING("A [tiers()[tier][1]] must stand indoors; out in the open it counts for nothing."))
	var/limit = limit_text()
	if (limit)
		to_chat(user, limit)
	to_chat(user, progress_text())

// What the seat's tiers do for its faction now, or null.
/obj/structure/faction_hall/proc/limit_text()
	return map ? "[faction] may take in up to [map.faction_member_limit(faction)] members." : null

// Why user cannot designate this seat for their faction, or null.
/obj/structure/faction_hall/proc/designate_block(mob/living/human/user)
	if (!map || !map.allows_custom_factions() || !user.civilization || user.civilization == "none" || !map.is_faction_leader(user, user.civilization))
		return "Only a faction's leader can designate a hall."
	return null

/obj/structure/faction_hall/proc/designate_prompt(name)
	return "Make this the hall of [name]? Only a hall that stands lets the faction grow, and raiders can burn it."


/obj/structure/faction_hall/attack_hand(mob/living/human/user)
	if (!ishuman(user))
		return ..()
	if (faction)
		examine(user)
		province_ledger_show(user, src) // province_ranks.dm: a seat's Province ledger
		return
	var/block = designate_block(user)
	if (block)
		to_chat(user, SPAN_WARNING(block))
		return
	var/name = user.civilization
	var/answer = WWinput(user, designate_prompt(name), initial(src.name), "Cancel", list("Designate", "Cancel"))
	if (answer != "Designate" || faction || user.civilization != name || designate_block(user) || get_dist(user, src) > 1 || user.stat)
		return
	faction = name
	update_icon()
	map.recruitment_audit(name, "[user.real_name] designated a [hall_word] at [x],[y].", faction_roster_account(user) || "")
	visible_message(SPAN_NOTICE("[user] makes this the [hall_word] of [name]."))

/obj/structure/faction_hall/attackby(obj/item/W, mob/living/human/user)
	if (!istype(W, /obj/item/stack) || !faction || !ishuman(user))
		return ..()
	if (user.civilization != faction)
		to_chat(user, SPAN_WARNING("Only members of [faction] can build up its hall."))
		return TRUE
	var/t = next_tier()
	var/block = tier_block(t)
	if (block)
		to_chat(user, SPAN_WARNING(block))
		return TRUE
	var/obj/item/stack/S = W
	var/list/needs = tiers()[t][5]
	for (var/kind in needs)
		var/list/need = needs[kind]
		if (!stack_matches_recipe_material(S, need[1]))
			continue
		var/missing = need[2] - (delivered[kind] || 0)
		if (missing <= 0)
			to_chat(user, SPAN_NOTICE("The [tiers()[t][1]] needs no more [need[3]]."))
			return TRUE
		var/amount = min(missing, S.amount)
		if (amount < 1 || !S.use(amount))
			return TRUE
		delivered[kind] = (delivered[kind] || 0) + amount
		to_chat(user, SPAN_NOTICE("You add [amount] [need[3]]. [progress_text()]"))
		if (!length(remaining()))
			raise_tier(user)
		return TRUE
	return ..()

/obj/structure/faction_hall/proc/raise_tier(mob/user)
	var/t = next_tier()
	if (!t)
		return
	tier = t
	delivered = list()
	update_icon()
	log_game("Faction [hall_word]: [faction] raised its [hall_word] at [x],[y],[z] to a [tiers()[t][1]][user ? " ([key_name(user)])" : ""].")
	if (map)
		map.recruitment_audit(faction, "The [hall_word] became a [tiers()[t][1]]. [limit_text()]", user ? (faction_roster_account(user) || "") : "")
	visible_message(SPAN_NOTICE("The [hall_word] of [faction] is now a [tiers()[t][1]]."))

#undef FACTION_HALL_BASE_LIMIT
#undef FACTION_HALL_COLONY_BONUS
