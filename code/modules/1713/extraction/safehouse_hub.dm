// Original bounded hub. Private staging reuses the production workbench and
// the account inventory graph instead of introducing another persistence owner.
/obj/structure/component_workbench/extraction_private
	name = "private tool assembly workbench"
	should_save = FALSE
	var/room = 1
	can_use(mob/living/human/H)
		if (!..()) return FALSE
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(M) || !M.owned(H)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		return !S.transitioning && S.profile["state"] == "home" && S.house?.room == room && z == S.house.z && get_dist(src, S.house) <= 4

/obj/map_metadata/extraction_survival/proc/house_workbench(datum/extraction_session/S)
	if (!S?.house) return null
	for (var/obj/structure/component_workbench/extraction_private/B in range(4, S.house))
		if (B.room == S.house.room && B.z == S.house.z) return B
	return null

/obj/effect/extraction_hub_guide
	name = "safe-house briefing board"
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "anvil"
	anchored = TRUE
	var/briefing = "Return to your private house at the central desk. Equipment stays in private storage while visiting the concourse."
	attack_hand(mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(H) || !istype(M) || !M.owned(H) || H.stat != CONSCIOUS || z != 3 || H.z != 3 || !Adjacent(H)) return
		to_chat(H, briefing)

/obj/effect/extraction_hub_guide/lounge
	name = "raid group briefing board"
	briefing = "Meet other raiders here, then return to your private terminal to invite up to three partners. Every member chooses and confirms their own loadout and insurance. A shared car needs everyone's consent and enough seats. Each account keeps its own extraction credit."

/obj/effect/extraction_hub_guide/workshop
	name = "crafting reference desk"
	briefing = "Open the Crafting Atlas for production recipes and acquisition requirements. Each private room has a tool assembly workbench; raid warehouses have shared benches. Insert a matching usable head and handle, select the tool, assemble, then retrieve it. Save your private stash before deploying."
	attack_hand(mob/user)
		..()
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(H) && istype(M) && M.owned(H) && H.stat == CONSCIOUS && H.z == 3 && z == 3 && Adjacent(H)) crafting_atlas_reference.show(H)

/obj/effect/extraction_hub_guide/operations
	name = "district operations board"
	briefing = "The industrial district closes thirty minutes after opening, with a five-minute warning. Extract or commit a shipment before closure. Your private stash and secure crate remain yours; unsent raid gear is lost. Insurance returns eligible reusable equipment in its lost condition after reconciliation. The central desk votes for the next map after this round settles."
	attack_hand(mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(H) && istype(M) && M.owned(H) && H.stat == CONSCIOUS && H.z == 3 && z == 3 && Adjacent(H)) to_chat(H, "[M.round_briefing()] Your private stash, secure crate and committed shipments remain yours. Unsent raid gear is lost at closure. Insurance returns eligible reusable equipment in its lost condition after reconciliation. The central desk votes for the next map after settlement.")
