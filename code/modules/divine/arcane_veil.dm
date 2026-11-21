// ============================================================
// Veil (magic materials and enchanting plan, PR 6). Hidden mechanic: keep it
// out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A magic user beseeches Imbue holding a box, case or pack fitted with a false
// bottom (false_bottom.dm), with 2 Omen and 1 Ward material in a worn pouch and
// a vigil of 3 or more. While it holds charges (3 / 6 / 10) the whole container
// is hidden from wards: hidden_from_wards() is TRUE, so a border ward's
// banned-goods search does not see what is inside. It works for anyone
// carrying it. It never lets the carrier past a ward that bans the person.
// Ordinary searches still find the false bottom, and Imbue can unweave it.
//
// For the law plan's border search: skip a container whose hidden_from_wards()
// is TRUE, then call arcane_veil_crossed(repo, carrier) on it once per warded
// crossing, which spends one charge.
// ============================================================

/proc/arcane_veilable(obj/item/weapon/storage/S)
	return istype(S) && !QDELETED(S) && !S.magic_repo_id && S.false_bottom()

/obj/item/weapon/storage/hidden_from_wards()
	return arcane_enchant_live() == "veil" && false_bottom()

/obj/item/weapon/storage/proc/arcane_veil_crossed(obj/repo, mob/carrier)
	if (!hidden_from_wards())
		return FALSE
	return arcane_enchant_spend("hid [carrier ? key_name(carrier) : "its carrier"]'s goods from [repo ? repo.magic_repo_id : "a ward"] at [arcane_enchant_place(src)]")
