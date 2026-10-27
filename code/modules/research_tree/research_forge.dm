// ============================================================
// Research Tree - resource forge (Phase 3)
// ------------------------------------------------------------
// A faction's research bench cap rises automatically with era, but
// can also be raised further by feeding COINS here. Copper, silver
// and gold coins are accepted, contributing their value in silver-
// equivalents (copper 0.1, silver 1, gold 4). One forge serves the
// whole faction (not tied to a single bench). No world scans: the
// silver-equivalent flows into the map metadata's per-faction forge
// progress, which accumulates across feedings.
// ============================================================

/obj/structure/research_forge
	name = "resource forge"
	desc = "A forge for melting down coins to expand what your faction's research infrastructure can support. Feed it copper, silver or gold coins to raise your faction's research bench limit."
	icon = 'icons/obj/structures.dmi'
	icon_state = "safe"
	density = TRUE
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/research_forge/attackby(obj/item/W as obj, mob/living/human/user as mob)
	if (!istype(W) || !ishuman(user))
		return ..()
	if (!user.civilization || user.civilization == "none")
		to_chat(user, SPAN_WARNING("You must belong to a faction to use a resource forge."))
		return
	if (!map)
		to_chat(user, SPAN_WARNING("This resource forge isn't linked to any research infrastructure."))
		return
	// Only the three metal coin types (and their subtypes) -- NOT the money
	// base, which also covers rubles/francs/euros/pounds/etc.
	if (!istype(W, /obj/item/stack/money/coppercoin) && !istype(W, /obj/item/stack/money/silvercoin) && !istype(W, /obj/item/stack/money/goldcoin))
		to_chat(user, SPAN_WARNING("The resource forge only accepts copper, silver or gold coins."))
		return
	var/obj/item/stack/money/coins = W
	// Let the player choose how much to melt: consuming the whole stack on a
	// single click turns a misclick with a full purse into forge confetti.
	var/count = input(user, "How many coins do you want to melt down? (You are holding [coins.amount])", "Resource Forge", coins.amount) as num|null
	if (!count || count <= 0)
		return
	// Re-validate after the input pause: the stack may have been spent,
	// dropped or deleted while the dialog was open.
	if (QDELETED(coins) || !in_range(src, user))
		return
	count = min(round(count), coins.amount)
	if (count <= 0)
		return
	var/coinname = coins.name
	// Silver-equivalent: coin.value is already 0.1 (copper) / 1 (silver) / 4
	// (gold), so value * count is the silver-denominated contribution.
	var/silver_equiv = coins.value * count
	coins.use(count)
	// Accumulates cumulatively; a slot costing more than one full 500-coin
	// stack is paid off over several feedings, overshoot rolling forward.
	if (map.add_forge_value(user.civilization, silver_equiv))
		to_chat(user, SPAN_NOTICE("You melt down [count] [coinname] ([silver_equiv] in silver). Your faction's research bench limit has increased to [map.get_bench_cap(user.civilization)]!"))
	else
		to_chat(user, SPAN_NOTICE("You melt down [count] [coinname] ([silver_equiv] in silver). Bench cap upgrade progress: [round(map.get_forge_progress(user.civilization), 0.1)]/[map.get_forge_next_cost(user.civilization)] silver."))
