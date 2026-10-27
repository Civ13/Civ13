// ============================================================
// Research Tree - research trade goods: notes + books (Phase 3/4.1)
// ------------------------------------------------------------
// Distinct from the legacy /obj/item/weapon/book/research (personal
// skill-training scrolls tied to the old stat/civ-research systems).
// These document ONE tree node for a faction that has completed it,
// and are TRADE GOODS: another faction's bench working that same node
// consumes one to advance. Two strengths:
//   transfer_type "notes" - weaker; grants a chunk of analysis ticks.
//   transfer_type "book"  - stronger; completes the node outright.
// Written and consumed exclusively through research_bench interactions;
// the item has no self-use behaviour, so the legacy subject picker /
// researchkit combo on the parent type is suppressed here.
// ============================================================

/obj/item/weapon/book/research/tree_book
	unique = TRUE
	var/subject = null            // node id this documents
	var/written_by_faction = null
	var/written_by = null         // real name of the researcher who authored it
	var/transfer_type = "book"    // "book" (completes) or "notes" (tick boost)

/obj/item/weapon/book/research/tree_book/attack_self(mob/user as mob)
	to_chat(user, SPAN_NOTICE("This can only be studied at a research bench assigned to its subject."))
	return

/obj/item/weapon/book/research/tree_book/attackby(obj/item/W as obj, mob/user as mob)
	to_chat(user, SPAN_NOTICE("This can only be studied at a research bench assigned to its subject."))
	return
