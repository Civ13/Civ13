// Faction membership and recruitment authority.
//
// One place decides who may recruit for a faction and how a character joins
// one, so the direct "Recruit" invite and later recruitment-station
// applications share the same checks (#4237). Recruitment is not leadership:
// holding it grants no treasury, tax, title or permission-management power.

#define FACTION_PERM_MANAGEMENT 1
#define FACTION_PERM_RECRUITMENT 4

// The faction's actual leader, or a current member holding the Recruitment
// permission, may invite and (later) review applications for that faction.
/obj/map_metadata/proc/can_recruit_for_faction(mob/living/human/H, faction)
	if (!istype(H) || QDELETED(H) || H.stat == DEAD)
		return FALSE
	if (!faction || faction == "none" || H.civilization != faction)
		return FALSE
	if (is_faction_leader(H, faction))
		return TRUE
	return islist(H.faction_perms) && H.faction_perms.len >= FACTION_PERM_RECRUITMENT && H.faction_perms[FACTION_PERM_RECRUITMENT] == 1

// Who may change member permissions. perm is the faction_perms index being
// changed, or 0 to ask whether they may open the menu at all. Only the actual
// leader grants or removes Permission Management and Recruitment; a member
// holding Permission Management may manage Announcements and Giving Titles.
// The mob's own leader flag is not enough: it used to be set by granting
// Recruitment, so old saves can carry it on ordinary members.
/obj/map_metadata/proc/can_manage_faction_permissions(mob/living/human/H, faction, perm = 0)
	if (!istype(H) || QDELETED(H) || H.stat == DEAD)
		return FALSE
	if (is_faction_leader(H, faction))
		return TRUE
	if (perm == FACTION_PERM_MANAGEMENT || perm == FACTION_PERM_RECRUITMENT)
		return FALSE
	return H.civilization == faction && islist(H.faction_perms) && H.faction_perms.len >= FACTION_PERM_MANAGEMENT && H.faction_perms[FACTION_PERM_MANAGEMENT] == 1

// TRUE while this character is inside the rejoin cooldown for faction.
/mob/living/human/proc/faction_rejoin_blocked(faction)
	for (var/list/entry in left_factions)
		if (entry.len >= 2 && entry[1] == faction && entry[2] > world.realtime)
			return TRUE
	return FALSE

// Returns null when this character may join faction now, otherwise a short
// player-facing reason. allow_switch lets a consenting member of another
// faction leave it on the way in (direct invites); without it they must
// leave their current faction first.
/mob/living/human/proc/faction_enrollment_block(faction, allow_switch = FALSE)
	if (QDELETED(src) || stat == DEAD)
		return "They are not alive."
	if (!faction || faction == "none")
		return "There is no faction to join."
	if (civilization == faction)
		return "They are already a member of [faction]."
	if (civilization && civilization != "none" && !allow_switch)
		return "They must leave [civilization] first."
	if (faction_rejoin_blocked(faction))
		return "They left [faction] recently and cannot rejoin yet."
	return null

// The one membership transition into a faction. Rechecks eligibility, leaves
// any previous faction (recording its rejoin cooldown), clears every privilege
// the character carried, then joins as an ordinary member. Nothing here
// sleeps, so the checks and the change happen in the same tick.
/mob/living/human/proc/enroll_in_faction(faction, allow_switch = FALSE)
	if (faction_enrollment_block(faction, allow_switch))
		return FALSE
	if (civilization && civilization != "none")
		faction_leaving_proc()
	clear_faction_privileges()
	civilization = faction
	return TRUE

// Strip leadership, permissions, title, research appointment and the role
// verbs that come with them. Used when leaving and when joining a faction.
/mob/living/human/proc/clear_faction_privileges()
	if (title)
		name = replacetext(real_name, "[title] ", "")
	title = ""
	leader = FALSE
	faction_perms = list(0,0,0,0)
	research_role = null
	remove_commander()
	remove_title_changer()
	remove_faction_symbol_editor()

// Return the authoritative record without inventing a faction or leader. Maps
// without this record retain is_faction_leader()'s legacy flag fallback, but
// cannot perform a stored-record leadership transition.
/obj/map_metadata/proc/faction_leader_record(faction)
	if (!faction || faction == "none")
		return null
	var/list/civ_data = custom_civs[faction]
	return islist(civ_data) && civ_data.len >= 4 ? civ_data : null

// Leaving and Nomad death clear only this exact character's stored position.
// Never compare display names: unrelated characters can have identical names.
/obj/map_metadata/proc/clear_faction_leader(mob/living/human/H, faction)
	var/list/civ_data = faction_leader_record(faction)
	if (!H || !civ_data || civ_data[4] != H)
		return FALSE
	civ_data[4] = null
	return TRUE

// Atomic, non-yielding claim/transfer of an existing faction's leader record.
// A null previous leader means claiming a vacant position, not overriding one.
// Callers own map eligibility, proximity, prompts and player-facing messages.
/obj/map_metadata/proc/change_faction_leader(faction, mob/living/human/previous, mob/living/human/next)
	var/list/civ_data = faction_leader_record(faction)
	if (!civ_data || civ_data[4] != previous)
		return FALSE
	if (!istype(next) || QDELETED(next) || next.stat == DEAD || next.civilization != faction || next == previous)
		return FALSE
	if (previous && (QDELETED(previous) || previous.stat == DEAD || !is_faction_leader(previous, faction)))
		return FALSE
	civ_data[4] = next
	next.make_commander()
	next.make_title_changer()
	next.grant_faction_symbol_editor()
	next.leader = TRUE
	next.faction_perms = list(1,1,1,1)
	if (previous)
		// A transfer revokes leadership powers, not titles or research roles.
		previous.leader = FALSE
		previous.faction_perms = list(0,0,0,0)
		previous.remove_title_changer()
		previous.remove_commander()
		previous.remove_faction_symbol_editor()
	return TRUE
