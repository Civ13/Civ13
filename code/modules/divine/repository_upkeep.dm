// ============================================================
// Repository upkeep (Val, 2026-11-19). Hidden mechanic: keep it out of
// changelog lines, the wiki and anything an ordinary player sees.
// ------------------------------------------------------------
// Too few keepers: a shrine or greater repository needs as many keepers on the
// magic whitelist as its tier asks (config "keepers"). Short of that it keeps
// working for a grace period (config "keeper_grace_days"), then goes still
// until the count is met again. Nothing is lost.
//
// A shrine belongs to the place it was made a shrine. Keepers may carry it,
// but outside that place's reach (its land plot, or the shrine radius when
// off-plot) it goes still until it is brought back.
// ============================================================

#define MAGIC_UPKEEP_DAY 864000

/obj
	var/magic_repo_short_since = 0 // saved: realtime it last fell short of keepers, 0 while it has enough
	var/magic_repo_home = null     // saved: "x,y,z" a shrine belongs to
	var/magic_repo_astray = FALSE  // saved: a shrine carried out of its home's reach

/proc/magic_repo_keepers_needed(tier)
	return tier >= 2 ? magic_tier_value(tier, "keepers", 1) : 1

/obj/proc/magic_repo_keeper_count()
	if (!islist(magic_repo_keepers))
		return 0
	if (!magic_whitelist_applies())
		return magic_repo_keepers.len
	. = 0
	for (var/key in magic_repo_keepers)
		if (magic_whitelisted(key))
			.++

// The grace period has run out with too few keepers (magic_repo_dormant()).
/obj/proc/magic_repo_short_dormant()
	return magic_repo_short_since && world.realtime - magic_repo_short_since >= magic_balance_num("keeper_grace_days", 7) * MAGIC_UPKEEP_DAY

/obj/proc/magic_repo_check_keepers()
	if (magic_repo_tier < 2 || magic_repo_keeper_count() >= magic_repo_keepers_needed(magic_repo_tier))
		magic_repo_short_since = 0
	else if (!magic_repo_short_since)
		magic_repo_short_since = world.realtime

/proc/magic_repo_home_turf(text)
	if (!istext(text))
		return null
	var/list/xyz = splittext(text, ",")
	if (xyz.len != 3)
		return null
	return locate(text2num(xyz[1]), text2num(xyz[2]), text2num(xyz[3]))

// TRUE when T is within reach of the shrine's home.
/obj/proc/magic_repo_at_home(turf/T)
	var/turf/home = magic_repo_home_turf(magic_repo_home)
	if (!home || !T)
		return FALSE
	var/list/plot = map ? map.land_plot_at(home) : null
	if (islist(plot))
		var/list/there = map.land_plot_at(T)
		return islist(there) && there[1] == plot[1] && there[2] == plot[2]
	return home.z == T.z && get_dist(home, T) <= magic_reach_value("shrine_radius", 7)

/obj/proc/magic_repo_check_home()
	if (magic_repo_tier != 2)
		magic_repo_home = null
		magic_repo_astray = FALSE
		return
	var/turf/T = get_turf(src)
	if (!T)
		return
	if (!magic_repo_home_turf(magic_repo_home))
		magic_repo_home = "[T.x],[T.y],[T.z]"
	var/astray = !magic_repo_at_home(T)
	if (astray != magic_repo_astray)
		magic_repo_astray = astray
		log_game("Repository [magic_repo_id] [astray ? "was carried out of" : "came back to"] its home at [magic_repo_home].")

// Why a keeper feels it has gone still, for examine.
/obj/proc/magic_repo_still_text()
	if (magic_repo_astray)
		return "It feels cold and still, far from where it belongs."
	if (magic_repo_short_dormant())
		return "It feels cold and still. Too few keep it."
	return "It feels cold and still."

#undef MAGIC_UPKEEP_DAY
