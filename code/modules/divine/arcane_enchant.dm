// ============================================================
// Enchantments (magic materials and enchanting plan, PR 4). Hidden mechanic:
// keep it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A magic user taught Imbue beseeches with an ordinary item in the hand that
// is not holding their stick and the needed attuned materials (and a gem, for
// a keepsake) in a worn pouch. The god sees a fixed, server-made scope line and
// grants or refuses it like any invocation. On Grant the materials are used up
// and the item gets hidden saved fields: the enchantment, its charges, its
// maker and when it was made. The item's type, name, sprite and description do
// not change. Charges never refill; imbuing again replaces the old enchantment.
// Destroying, melting or recrafting the item ends it with the item.
//
// The same invocation can unweave anyone's enchantment from the held item for
// one attuned material of any aspect. Each magic user keeps at most
// ARCANE_ENCHANT_CAP of their own enchantments in this world; a sixth asks
// which to let go. Staff list and strip enchantments in Divine Patron, and
// every imbue, use, unweave and strip goes to the admin log.
// ============================================================

#define ARCANE_ENCHANT_CAP 5

// Enchantment id -> what the god and the magic user see it called.
var/global/list/arcane_enchant_names = list(
	"keepsake" = "Keepsake",
	"cleansing" = "Cleansing",
	"warding" = "Warding", // arcane_ward.dm
	"paired" = "Paired stones", // arcane_ward.dm
)

// Enchantment id -> materials and charges by strength 1 / 2 / 3.
var/global/list/arcane_enchant_recipes = list(
	"keepsake" = list("aspect" = "mercy", "count" = 2, "gem" = 1, "charges" = list(1, 2, 3)),
	"cleansing" = list("aspect" = "mercy", "count" = 1, "gem" = 0, "charges" = list(3, 5, 8)),
	"warding" = list("aspect" = "ward", "count" = 2, "gem" = 0, "charges" = list(10, 20, 30), "vigil" = TRUE),
	"paired" = list("aspect" = "omen", "count" = 2, "gem" = 0, "charges" = list(5, 10, 15)),
)

// Enchantment id -> the one plain line a magic user sees on examine.
var/global/list/arcane_enchant_lines = list(
	"keepsake" = "Something about it feels watchful.",
	"cleansing" = "It seems cleaner than it ought to.",
	"warding" = "It feels guarded.",
	"paired" = "It feels as if something is listening.",
)

// Enchanted items in this world. Runtime only: rebuilt as items load, and an
// item leaves it when it is destroyed or its enchantment ends.
var/global/list/arcane_enchanted = list()

/obj/item
	var/arcane_enchant = null       // saved: enchantment id, or null
	var/arcane_charges = 0          // saved: uses left
	var/arcane_enchanter = null     // saved: ckey of the magic user who made it
	var/arcane_enchanted_at = 0     // saved: world.realtime when it was made

/mob/living/human
	var/tmp/list/arcane_imbue_owners = null // owner ckey -> name for a Warding (arcane_ward.dm)
	var/tmp/arcane_imbue_pick = null  // enchantment id (or "unweave") of the Imbue being asked for
	var/tmp/arcane_was_critical = FALSE

// ---- The enchantment on an item ------------------------------------------

/obj/item/proc/arcane_enchant_live()
	if (!arcane_enchant)
		return null
	if (!arcane_enchant_names[arcane_enchant] || arcane_charges < 1)
		arcane_enchant_end()
		return null
	return arcane_enchant

/obj/item/proc/arcane_enchant_end()
	arcane_pair = null // arcane_ward.dm
	arcane_enchant = null
	arcane_charges = 0
	arcane_enchanter = null
	arcane_enchanted_at = 0
	arcane_enchanted -= src

// Called from /obj/item/after_load (abandoned_items.dm).
/obj/item/proc/arcane_enchant_loaded()
	if (arcane_enchant_live())
		arcane_enchanted |= src

// Called from /obj/item/Destroy (items.dm).
/obj/item/proc/arcane_enchant_forget()
	if (arcane_enchant)
		arcane_enchanted -= src

// Uses one charge; the enchantment ends with the last one.
/obj/item/proc/arcane_enchant_spend(why)
	var/kind = arcane_enchant_live()
	if (!kind)
		return FALSE
	arcane_charges--
	log_admin("Enchantment used: [kind] on [src] ([type]) made by [arcane_enchanter], [arcane_charges] left ([why]).")
	if (arcane_charges < 1)
		arcane_enchant_end()
	return TRUE

/proc/arcane_enchantments_of(ckey)
	. = list()
	for (var/obj/item/I in arcane_enchanted)
		if (QDELETED(I) || !I.arcane_enchant_live())
			arcane_enchanted -= I
		else if (I.arcane_enchanter == ckey)
			. += I

/proc/arcane_enchant_place(obj/item/I)
	var/turf/T = get_turf(I)
	var/area/A = T ? T.loc : null
	return T ? "[A ? A.name : "somewhere"] ([T.x], [T.y], [T.z])" : "nowhere"

// ---- What can be imbued ---------------------------------------------------

/proc/arcane_is_trinket(obj/item/I)
	if (istype(I, /obj/item/clothing/gloves/rings) || istype(I, /obj/item/clothing/accessory/storage/lanyard))
		return TRUE
	return istype(I, /obj/item/clothing/accessory) && !istype(I, /obj/item/clothing/accessory/storage)

/proc/arcane_enchant_fits(kind, obj/target)
	if (kind == "warding")
		return arcane_wardable(target) // arcane_ward.dm
	var/obj/item/I = target
	if (!istype(I) || QDELETED(I) || I.magic_repo_id)
		return FALSE
	if (kind == "paired")
		return arcane_single_gem(I) // arcane_ward.dm
	if (istype(I, /obj/item/stack))
		return FALSE
	switch (kind)
		if ("keepsake")
			return arcane_is_trinket(I)
		if ("cleansing")
			var/obj/item/weapon/reagent_containers/RG = I
			return (istype(RG, /obj/item/weapon/reagent_containers/glass) || istype(RG, /obj/item/weapon/reagent_containers/food/drinks)) && RG.reagents && RG.reagents.has_reagent("water")
	return FALSE

/proc/arcane_is_gem(obj/item/I)
	return istype(I, /obj/item/stack/ore/gem) || istype(I, /obj/item/stack/gemstone)

// The item an Imbue works on: whatever is in the hand without the stick.
/mob/living/human/proc/arcane_imbue_item()
	var/obj/item/focus = divine_focus()
	if (!focus)
		return null
	var/obj/item/I = get_active_hand() == focus ? get_inactive_hand() : get_active_hand()
	return istype(I) && !QDELETED(I) ? I : null

// Everything kept in this character's worn belt pouches.
/mob/living/human/proc/arcane_pouch_items()
	. = list()
	for (var/obj/item/clothing/accessory/storage/belt_pouch/P in GetAllContents(4))
		if (!P.hold || QDELETED(P))
			continue
		for (var/obj/item/I in P.hold.contents)
			if (!QDELETED(I))
				. += I

// The pouch items an Imbue of this kind would use up, or null if any are
// missing. An attuned stack counts as one material and gives up one of itself.
/mob/living/human/proc/arcane_imbue_materials(kind)
	var/list/pouch = arcane_pouch_items()
	var/list/picked = list()
	if (kind == "unbinding")
		return arcane_unbind_materials() // arcane_unbind.dm
	if (kind == "unweave" || kind == "unbless")
		for (var/obj/item/I in pouch)
			if (I.arcane_virtue() && !I.arcane_enchant)
				picked += I
				return picked
		return null
	var/list/recipe = arcane_enchant_recipes[kind]
	if (!recipe)
		return null
	var/needed = recipe["count"]
	for (var/obj/item/I in pouch)
		if (needed && I.arcane_virtue() == recipe["aspect"] && !I.arcane_enchant)
			picked += I
			needed--
	if (needed)
		return null
	var/gems = recipe["gem"]
	for (var/obj/item/I in pouch)
		if (gems && arcane_is_gem(I) && !(I in picked) && !I.arcane_enchant)
			picked += I
			gems--
	if (gems)
		return null
	return picked

/proc/arcane_imbue_strength(list/materials)
	var/total = 0
	var/count = 0
	for (var/obj/item/I in materials)
		if (I.arcane_virtue())
			total += I.arcane_strength
			count++
	return count ? clamp(round(total / count), 1, 3) : 1

/proc/arcane_imbue_charges(kind, list/materials)
	var/list/recipe = arcane_enchant_recipes[kind]
	if (!recipe)
		return 0
	var/list/charges = recipe["charges"]
	return charges[arcane_imbue_strength(materials)]

// Why the Imbue being asked for can't go ahead, or null. Called by divine_problem().
/mob/living/human/proc/arcane_imbue_problem(kind)
	var/obj/target = arcane_imbue_target() // arcane_ward.dm
	if (!target)
		return "Hold the thing in your other hand."
	if (!kind)
		return null
	var/obj/item/I = target
	if (kind == "unbinding")
		return arcane_unbind_problem(target) // arcane_unbind.dm
	if (kind == "unweave")
		if (istype(I) ? !I.arcane_enchant_live() : !target.arcane_ward_live())
			return "There is nothing woven into [target]."
	else if (kind == "unbless")
		if (!istype(I) || !I.arcane_bless_tier)
			return "There is no favour on [target]."
	else if (!arcane_enchant_fits(kind, target))
		return "[target] can't hold that."
	var/list/materials = arcane_imbue_materials(kind)
	if (!materials)
		return "You don't have what that needs in your pouch."
	if (kind == "paired" && !arcane_pair_partner(materials))
		return "You need a second plain gem in your pouch."
	var/list/recipe = arcane_enchant_recipes[kind]
	if (recipe && recipe["vigil"] && !arcane_vigil_holds())
		return "The vigil has broken."
	return null

/proc/arcane_imbue_scope(kind, obj/target, list/materials, list/owners = null, vigil = 0)
	var/obj/item/I = target
	var/list/names = list()
	for (var/obj/item/M in materials)
		names += M.arcane_virtue() ? "[M.name] ([M.arcane_virtue()] [M.arcane_strength])" : "[M.name]"
	if (kind == "unbless")
		return "unbless-v1: end the tier [I.arcane_bless_tier] blessing of [I.arcane_bless_stat] (made by [I.arcane_blesser]) on [I.name]; uses up [english_list(names)]; costs the slot"
	if (kind == "unweave" && !istype(I))
		return "unweave-v1: end the ward ([target.arcane_ward_charges] left, made by [target.arcane_ward_by]) on [target.name]; uses up [english_list(names)]; costs the slot"
	if (kind == "warding")
		var/list/who = list()
		for (var/key in owners)
			who += "[owners[key]] ([key])"
		return "imbue-warding-v1: Warding on [target.name], opening only for [english_list(who)], with [arcane_imbue_charges(kind, materials)] charges; uses up [english_list(names)]; vigil of [vigil]; costs the slot"
	if (kind == "unweave")
		return "unweave-v1: end the [I.arcane_enchant] enchantment ([I.arcane_charges] left, made by [I.arcane_enchanter]) on [I.name]; uses up [english_list(names)]; costs the slot"
	return "imbue-[kind]-v1: [arcane_enchant_names[kind]] on [target.name] with [arcane_imbue_charges(kind, materials)] charges; uses up [english_list(names)]; costs the slot"

// Asked in Beseech before the prayer goes up: which enchantment, and which
// old one to let go when this would be a sixth. Returns the scope, or null.
/mob/living/human/proc/arcane_imbue_choose()
	arcane_imbue_pick = null
	arcane_imbue_structure = null
	arcane_imbue_vigil = null
	arcane_imbue_owners = null
	arcane_unbind_repo = null
	var/obj/item/I = arcane_imbue_item()
	var/obj/target = I
	if (!I && divine_focus() && !(get_active_hand() && get_inactive_hand())) // a free hand: ward something beside them (arcane_ward.dm)
		var/list/beside = list()
		for (var/obj/O in arcane_wardables_beside() + arcane_fires_beside()) // arcane_unbind.dm
			beside["[O.name] ([dir2text(get_dir(src, O))])"] = O
		if (beside.len == 1)
			target = beside[beside[1]]
		else if (beside.len > 1)
			target = beside[player_input(src, "Which one?", "Imbue", null, "anything", beside, TRUE)]
		if (target)
			arcane_imbue_structure = target
	if (!target)
		to_chat(src, SPAN_WARNING("Hold the thing in your other hand."))
		return null
	var/list/choices = list()
	for (var/kind in arcane_enchant_names)
		if (arcane_enchant_fits(kind, target))
			choices[arcane_enchant_names[kind]] = kind
	if (I ? I.arcane_enchant_live() : target.arcane_ward_live())
		choices["Unweave what is in it"] = "unweave"
	if (I && I.arcane_bless_tier)
		choices["Unweave its blessing"] = "unbless" // arcane_bless.dm
	if (!I && arcane_unbind_fire(target))
		choices["Work an Unbinding"] = "unbinding" // arcane_unbind.dm
	if (!choices.len)
		to_chat(src, SPAN_WARNING("Nothing you know can be woven into [target]."))
		return null
	var/picked = player_input(src, "What do you ask to weave into [target]?", "Imbue", null, "anything", choices, TRUE)
	var/kind = choices[picked]
	if (!kind || QDELETED(target) || target != arcane_imbue_target())
		return null
	if (arcane_enchant_names[kind])
		var/list/own = list()
		var/list/pairs = list()
		for (var/obj/item/O in arcane_enchantments_of(ckey))
			if (O == I || (O.arcane_pair && (O.arcane_pair in pairs)))
				continue // re-imbuing replaces, and a pair counts once
			if (O.arcane_pair)
				pairs += O.arcane_pair
			own += O
		for (var/obj/O in arcane_wards_of(ckey)) // arcane_ward.dm
			if (O != target)
				own += O
		if (own.len >= ARCANE_ENCHANT_CAP)
			var/list/release = list()
			for (var/obj/O in own)
				var/obj/item/OI = O
				release["[O.name] ([istype(OI) ? arcane_enchant_names[OI.arcane_enchant] : "Warding"], [arcane_enchant_place(O)])"] = O
			var/gone = player_input(src, "You can't hold more than [ARCANE_ENCHANT_CAP] in the world. Which do you let go?", "Imbue", null, "anything", release, TRUE)
			var/obj/O = release[gone]
			if (!O || QDELETED(O))
				return null
			arcane_enchant_let_go(O, ckey)
	if (kind == "unbinding" && !arcane_unbind_pick(target)) // arcane_unbind.dm
		return null
	if (kind == "warding" || kind == "unbinding")
		if (kind == "warding")
			arcane_imbue_owners = arcane_ward_pick_owners() // arcane_ward.dm
		var/list/roster = divine_gather_vigil(target)
		if (!roster || QDELETED(target) || target != arcane_imbue_target())
			return null
		arcane_imbue_vigil = roster
	var/problem = arcane_imbue_problem(kind)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return null
	arcane_imbue_pick = kind
	if (kind == "unbinding")
		return arcane_unbind_scope(target, arcane_imbue_materials(kind), length(arcane_imbue_vigil)) // arcane_unbind.dm
	return arcane_imbue_scope(kind, target, arcane_imbue_materials(kind), arcane_imbue_owners, length(arcane_imbue_vigil))

// Lets go of one of this magic user's enchantments, both stones of a pair.
/proc/arcane_enchant_let_go(obj/O, ckey)
	var/obj/item/I = O
	if (istype(I))
		if (I.arcane_enchanter != ckey)
			return FALSE
		log_admin("Enchantment let go: [ckey] let go of [I.arcane_enchant] on [I] ([I.type]) to make room.")
		var/obj/item/other = I.arcane_pair_other()
		I.arcane_enchant_end()
		if (other)
			other.arcane_enchant_end()
		return TRUE
	if (O.arcane_ward_by != ckey)
		return FALSE
	log_admin("Ward let go: [ckey] let go of the ward on [O] ([O.type]) to make room.")
	O.arcane_ward_end()
	return TRUE

// On Grant, from divine_dispatch() after every recheck: use up the materials
// and weave the enchantment in, with no yield.
/mob/living/human/proc/arcane_imbue_apply(obj/target)
	var/kind = arcane_imbue_pick
	var/list/owners = arcane_imbue_owners
	arcane_imbue_pick = null
	arcane_imbue_owners = null
	arcane_imbue_vigil = null
	arcane_imbue_structure = null
	var/list/materials = arcane_imbue_materials(kind)
	if (!istype(target) || !materials)
		return FALSE
	var/obj/item/I = target
	var/obj/item/partner = kind == "paired" ? arcane_pair_partner(materials) : null
	if (kind == "paired" && !partner)
		return FALSE
	var/charges = arcane_enchant_names[kind] ? arcane_imbue_charges(kind, materials) : 0
	var/obj/unbind_repo = arcane_unbind_repo
	arcane_unbind_repo = null
	var/unbind_amount = kind == "unbinding" ? arcane_unbind_amount(materials) : 0 // arcane_unbind.dm
	var/list/burnt = list()
	for (var/obj/item/M in materials)
		burnt += "[M.name] ([M.arcane_virtue()] [M.arcane_strength])"
	for (var/obj/item/M in materials)
		if (istype(M, /obj/item/stack))
			var/obj/item/stack/S = M
			if (S.amount > 1)
				S.use(1)
				continue
		var/obj/item/weapon/storage/holder = M.loc
		if (istype(holder))
			holder.remove_from_storage(M, get_turf(src))
		qdel(M)
	if (kind == "unbinding")
		return arcane_unbind_apply(target, unbind_repo, unbind_amount, burnt) // arcane_unbind.dm
	if (kind == "unbless")
		log_admin("Blessing unwoven: [key_name(src)] unwove the tier [I.arcane_bless_tier] [I.arcane_bless_stat] blessing made by [I.arcane_blesser] from [I] ([I.type]).")
		I.arcane_bless_end()
		to_chat(src, SPAN_NOTICE("<i>The favour leaves [I].</i>"))
		return TRUE
	if (kind == "unweave")
		if (!istype(I))
			log_admin("Ward unwoven: [key_name(src)] unwove the ward made by [target.arcane_ward_by] from [target] ([target.type]).")
			target.arcane_ward_end()
		else
			log_admin("Enchantment unwoven: [key_name(src)] unwove [I.arcane_enchant] made by [I.arcane_enchanter] from [I] ([I.type]).")
			I.arcane_enchant_end()
		to_chat(src, SPAN_NOTICE("<i>Something leaves [target].</i>"))
		return TRUE
	if (kind == "warding")
		arcane_ward_apply(target, materials, islist(owners) ? owners : list("[ckey]" = real_name)) // arcane_ward.dm
		return TRUE
	if (kind == "paired")
		arcane_pair_apply(I, partner, charges) // arcane_ward.dm
		to_chat(src, SPAN_NOTICE("<i>[arcane_enchant_lines[kind]]</i>"))
		return TRUE
	I.arcane_enchant_end()
	I.arcane_enchant = kind
	I.arcane_charges = charges
	I.arcane_enchanter = ckey
	I.arcane_enchanted_at = world.realtime
	arcane_enchanted |= I
	log_admin("Enchantment made: [key_name(src)] wove [kind] ([charges] charges) into [I] ([I.type]).")
	to_chat(src, SPAN_NOTICE("<i>[arcane_enchant_lines[kind]]</i>"))
	return TRUE

// One plain line for a magic user; called from arcane_examine().
/obj/item/proc/arcane_enchant_examine(mob/living/human/H)
	var/kind = arcane_enchant_live()
	if (kind && arcane_enchant_lines[kind])
		to_chat(H, SPAN_NOTICE("<i>[arcane_enchant_lines[kind]]</i>"))

// ---- What enchantments do -------------------------------------------------

// Keepsake: the first time the wearer drops into critical condition, it eases
// pain and stops their bleeding. Called every Life tick while alive.
/mob/living/human/proc/arcane_critical_check(critical)
	if (!critical)
		arcane_was_critical = FALSE
		return
	if (arcane_was_critical)
		return
	arcane_was_critical = TRUE
	var/obj/item/keepsake = arcane_worn_keepsake()
	if (!keepsake)
		return
	adjustHalLoss(-40)
	for (var/obj/item/organ/external/E in organs)
		E.bandage()
	keepsake.arcane_enchant_spend("kept [key_name(src)] from bleeding out")

/mob/living/human/proc/arcane_worn_keepsake()
	for (var/obj/item/I in get_equipped_items())
		if (I.arcane_enchant == "keepsake" && I.arcane_enchant_live())
			return I
		var/obj/item/clothing/C = I
		if (istype(C) && islist(C.accessories))
			for (var/obj/item/A in C.accessories)
				if (A.arcane_enchant == "keepsake" && A.arcane_enchant_live())
					return A
	return null

// Cleansing: pouring from the bottle into water rids that water of sickness.
// Called from standard_pour_into() after a pour.
/obj/item/proc/arcane_cleansing_pour(atom/target)
	if (arcane_enchant != "cleansing" || !arcane_enchant_live() || !target || !target.reagents || !target.reagents.has_reagent("water"))
		return FALSE
	target.reagents.del_reagent("cholera")
	return arcane_enchant_spend("cleansed [target] ([target.type])")

#undef ARCANE_ENCHANT_CAP
