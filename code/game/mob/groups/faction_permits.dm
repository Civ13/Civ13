// Permits and licences (docs/faction-permits.md). A faction may require, on its
// registered land (land_registry.dm), a building permit to build there and a
// trading licence to set up a stall there. Both are off unless the faction's
// papers power (faction_papers.dm) turns them on. Permits are papers of the
// faction's register, issued, revoked and named like citizenship papers, and
// count only for their holder. Members of the faction and whoever carries the
// plot's valid deed never need one.
//
// The setting lives in the faction's papers record (map.faction_recruitment["papers"]):
//   faction -> list(..., "require" = list("build", "trade"))
// Nothing sleeps except the prompts, which recheck after.

var/global/list/faction_permit_kinds = list("build", "trade")

/obj/map_metadata/proc/permits_required(faction)
	var/list/R = papers_record(faction)
	var/list/require = R["require"]
	if (!islist(require))
		require = list()
		R["require"] = require
	for (var/kind in require.Copy())
		if (!(kind in faction_permit_kinds))
			require -= kind
	var/list/names = list()
	for (var/kind in require)
		names += faction_paper_kinds[kind]
	return names

/obj/map_metadata/proc/permit_required(faction, kind)
	var/list/R = papers_record(faction)
	var/list/require = R["require"]
	return islist(require) && (kind in require)

/obj/map_metadata/proc/permit_set_required(faction, kind, on)
	if (!(kind in faction_permit_kinds))
		return FALSE
	permits_required(faction)
	var/list/R = papers_record(faction)
	var/list/require = R["require"]
	if (on)
		require |= kind
	else
		require -= kind
	return TRUE

// Whether H carries a permit of kind from faction that is in force and theirs.
/proc/permit_held(mob/living/human/H, faction, kind)
	if (!map || !istype(H))
		return FALSE
	var/account = faction_roster_account(H)
	if (!account)
		return FALSE
	for (var/obj/item/faction_papers/P in H.contents)
		if (P.faction != faction || P.kind != kind || P.holder_account != account)
			continue
		var/list/row = map.papers_row(faction, P.serial)
		if (row && row[1] == kind && row[3] == account)
			return TRUE
	return FALSE

// Whether H carries the valid deed of the plot faction/id.
/proc/permit_deed_held(mob/living/human/H, faction, id)
	for (var/obj/item/land_deed/D in H.contents)
		if (D.faction == faction && D.plot_id == id && D.verdict() == "valid")
			return TRUE
	return FALSE

// Null when H may do what needs kind at T, else the name of the faction whose
// permit is missing.
/proc/permit_missing(mob/living/human/H, turf/T, kind)
	if (!map || !istype(H) || !T)
		return null
	var/list/at = map.land_plot_at(T)
	if (!at)
		return null
	var/faction = at[1]
	if (!map.permit_required(faction, kind) || H.civilization == faction)
		return null
	if (permit_deed_held(H, faction, at[2]) || permit_held(H, faction, kind))
		return null
	return faction

// Building a structure on land that requires a building permit; a stall needs
// a trading licence instead.
/datum/craft_guard/land_permit
	order = 70
	after_wait = TRUE

/datum/craft_guard/land_permit/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	if (!ispath(R.result_type, /obj/structure) && !ispath(R.result_type, /obj/covers) && !ispath(R.result_type, /turf))
		return null
	var/kind = ispath(R.result_type, /obj/structure/vending/sales) ? "trade" : "build"
	var/faction = permit_missing(H, get_turf(H), kind)
	if (!faction)
		return null
	return phase == CRAFT_GUARD_START ? SPAN_WARNING("This is registered land of [faction]. You need its [faction_paper_kinds[kind]] to [kind == "trade" ? "set up a stall" : "build"] here.") : ""

/mob/living/human/proc/permits_require_menu(faction)
	var/list/options = list()
	for (var/kind in faction_permit_kinds)
		options["[map.permit_required(faction, kind) ? "Stop requiring" : "Require"] a [faction_paper_kinds[kind]]"] = kind
	var/pick = WWinput(src, "On the registered land of [faction], outsiders without the plot's deed may need a permit. Members never do.", "Permits", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options) || civilization != faction || !map.faction_power(src, faction, "papers"))
		return
	var/kind = options[pick]
	var/on = !map.permit_required(faction, kind)
	map.permit_set_required(faction, kind, on)
	map.office_announce(faction, "[faction] [on ? "now requires" : "no longer requires"] a [faction_paper_kinds[kind]] on its registered land.")
	log_game("[key_name(src)] [on ? "required" : "stopped requiring"] [kind] permits on the land of [faction].")
