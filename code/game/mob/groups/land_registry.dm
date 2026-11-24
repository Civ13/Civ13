// Land registry and deeds (docs/land-registry.md). A faction's registrar (its
// leader, or anyone with the registry power, faction_offices.dm) marks a plot
// between two boundary stones at its opposite corners and issues a deed for
// it. The deed is the title: whoever holds it holds the plot, so land is sold
// by handing the deed over. A valid deed is also the master key of its plot:
// its holder can lock and unlock keyed doors (not jail doors) and chests that
// stand on it. The
// registrar can set a land tax, paid into the faction's strongbox
// (faction_treasury.dm), and can reissue a deed, which voids the old one
// (for a lost deed, or a plot seized for unpaid tax). The game never evicts
// anyone: players enforce what the registry says.
//
// The register lives in map.faction_recruitment["plots"] (durable, renamed
// with the faction):
//   faction -> list(id text -> list(name, x1, y1, x2, y2, z, serial,
//                                    tax silver a week, paid through, registered to))
// "Paid through" is a world.realtime; tax owed is the time since it, in weeks,
// times the tax. Boundary stones and deeds keep their own vars and save with
// the world.
//
// Nothing here sleeps except the prompts, which recheck after.

#define LAND_PLOT_MAX_SIDE 32
#define LAND_PLOT_MIN_SIDE 2
#define LAND_PLOTS_PER_FACTION 60
#define LAND_TAX_MAX 100 // silver a week
#define LAND_NAME_MAX 40
#define LAND_WEEK 6048000

var/global/list/boundary_stones = list()
var/global/list/land_deeds = list()

// --- Register -------------------------------------------------------------------

/obj/map_metadata/proc/land_state()
	var/list/S = recruitment_state()
	if (!islist(S["plots"]))
		S["plots"] = list()
	return S["plots"]

/obj/map_metadata/proc/land_plots(faction)
	var/list/S = land_state()
	var/list/rows = S[faction]
	return islist(rows) ? rows : list()

/proc/land_row_valid(list/row)
	if (!islist(row) || row.len != 10 || !istext(row[1]) || !istext(row[10]))
		return FALSE
	for (var/i in 2 to 9)
		if (!isnum(row[i]))
			return FALSE
	return row[2] <= row[4] && row[3] <= row[5] && row[4] - row[2] < LAND_PLOT_MAX_SIDE && row[5] - row[3] < LAND_PLOT_MAX_SIDE && row[8] >= 0

/obj/map_metadata/proc/land_plot(faction, id)
	var/list/rows = land_plots(faction)
	var/list/row = rows[id]
	return land_row_valid(row) ? row : null

/obj/map_metadata/proc/land_normalize()
	var/list/S = land_state()
	for (var/faction in S.Copy())
		var/list/rows = S[faction]
		if (!istext(faction) || !islist(rows))
			S -= faction
			continue
		for (var/id in rows.Copy())
			if (!istext(id) || !land_row_valid(rows[id]))
				rows -= id

/obj/map_metadata/proc/land_rename(old_name, new_name)
	faction_rename_assoc_key(land_state(), old_name, new_name)
	for (var/obj/item/land_deed/D in land_deeds)
		if (D.faction == old_name)
			D.faction = new_name
			D.update_deed_name()

/proc/land_row_contains(list/row, x, y, z)
	return row[6] == z && x >= row[2] && x <= row[4] && y >= row[3] && y <= row[5]

// list(faction, id) of the registered plot covering a turf, or null.
/obj/map_metadata/proc/land_plot_at(turf/T)
	if (!T)
		return null
	var/list/S = land_state()
	for (var/faction in S)
		var/list/rows = S[faction]
		if (!islist(rows))
			continue
		for (var/id in rows)
			var/list/row = rows[id]
			if (land_row_valid(row) && land_row_contains(row, T.x, T.y, T.z))
				return list(faction, id)
	return null

// TRUE when the rectangle overlaps any registered plot.
/obj/map_metadata/proc/land_overlaps(x1, y1, x2, y2, z)
	var/list/S = land_state()
	for (var/faction in S)
		var/list/rows = S[faction]
		if (!islist(rows))
			continue
		for (var/id in rows)
			var/list/row = rows[id]
			if (land_row_valid(row) && row[6] == z && x1 <= row[4] && x2 >= row[2] && y1 <= row[5] && y2 >= row[3])
				return TRUE
	return FALSE

// Registers a plot between two corners and returns its id, or an error text
// prefixed with "!".
/obj/map_metadata/proc/land_register(faction, name, turf/A, turf/B, holder_name)
	if (!istext(faction) || !length(faction) || faction == "none" || !A || !B || A.z != B.z)
		return "!The corners must be on the same level."
	var/x1 = min(A.x, B.x)
	var/x2 = max(A.x, B.x)
	var/y1 = min(A.y, B.y)
	var/y2 = max(A.y, B.y)
	if (x2 - x1 + 1 > LAND_PLOT_MAX_SIDE || y2 - y1 + 1 > LAND_PLOT_MAX_SIDE)
		return "!A plot can be at most [LAND_PLOT_MAX_SIDE] tiles on a side."
	if (x2 - x1 + 1 < LAND_PLOT_MIN_SIDE || y2 - y1 + 1 < LAND_PLOT_MIN_SIDE)
		return "!A plot must be at least [LAND_PLOT_MIN_SIDE] tiles on a side."
	if (land_overlaps(x1, y1, x2, y2, A.z))
		return "!That land overlaps a plot already registered."
	var/list/S = land_state()
	var/list/rows = S[faction]
	if (!islist(rows))
		rows = list()
		S[faction] = rows
	if (rows.len >= LAND_PLOTS_PER_FACTION)
		return "![faction] has registered as many plots as its register holds ([LAND_PLOTS_PER_FACTION])."
	var/highest = 0
	for (var/id in rows)
		highest = max(highest, text2num(id) || 0)
	var/id = "[highest + 1]"
	rows[id] = list(land_name_clean(name, "Plot [id]"), x1, y1, x2, y2, A.z, 1, 0, recruitment_now(), holder_name || "")
	return id

/proc/land_name_clean(value, fallback)
	if (!istext(value))
		return fallback
	var/clean = sanitize(value, LAND_NAME_MAX + 1, FALSE)
	if (!istext(clean))
		return fallback
	clean = trim(clean)
	if (!length(clean) || length(clean) > LAND_NAME_MAX)
		return fallback
	return clean

// Silver of land tax owed on a plot now.
/proc/land_tax_owed(list/row, now)
	if (!land_row_valid(row) || row[8] <= 0 || now <= row[9])
		return 0
	return round(row[8] * (now - row[9]) / LAND_WEEK, 0.1)

// Pays worth toward a plot's tax: moves its paid-through time forward.
/proc/land_tax_pay(list/row, worth)
	if (!land_row_valid(row) || row[8] <= 0 || worth <= 0)
		return FALSE
	row[9] += worth / row[8] * LAND_WEEK
	return TRUE

/proc/land_plot_text(faction, id, list/row)
	var/text = "[row[1]] of [faction] (plot [id]): [row[4] - row[2] + 1] by [row[5] - row[3] + 1] tiles, from ([row[2]], [row[3]]) to ([row[4]], [row[5]])"
	if (length(row[10]))
		text += ", registered to [row[10]]"
	if (row[8] > 0)
		var/owed = land_tax_owed(row, recruitment_now())
		text += ". Land tax [row[8]] silver a week[owed > 0 ? ", [weighed_silver_text(owed)] owed" : ", paid up"]"
	return "[text]."

// --- Deeds -------------------------------------------------------------------------

/obj/item/land_deed
	name = "land deed"
	desc = "A deed to a registered plot of land."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper_seal-court"
	w_class = ITEM_SIZE_TINY
	var/faction = ""
	var/plot_id = ""
	var/serial = 0
	var/plot_name = ""

/obj/item/land_deed/New()
	..()
	land_deeds |= src

/obj/item/land_deed/Destroy()
	land_deeds -= src
	return ..()

/obj/item/land_deed/after_load()
	..()
	update_deed_name()

/obj/item/land_deed/proc/update_deed_name()
	name = length(plot_name) ? "deed to [plot_name]" : initial(name)
	desc = length(faction) ? "A deed to [plot_name], registered with [faction]. Whoever holds it holds the land." : initial(desc)

/obj/item/land_deed/proc/plot_row()
	if (!map)
		return null
	return map.land_plot(faction, plot_id)

// "valid", "void" (reissued or released) or "unknown".
/obj/item/land_deed/proc/verdict()
	var/list/row = plot_row()
	if (!row)
		return length(faction) ? "void" : "unknown"
	return row[7] == serial ? "valid" : "void"

/obj/item/land_deed/examine(mob/user, distance = -1)
	..()
	if (!length(faction))
		return
	var/list/row = plot_row()
	if (row && verdict() == "valid")
		to_chat(user, SPAN_NOTICE(land_plot_text(faction, plot_id, row)))
	else
		to_chat(user, SPAN_WARNING("The register of [faction] no longer honours this deed."))

/obj/map_metadata/proc/land_issue_deed(faction, id, atom/where)
	var/list/row = land_plot(faction, id)
	if (!row)
		return null
	var/obj/item/land_deed/D = new(where)
	D.faction = faction
	D.plot_id = id
	D.serial = row[7]
	D.plot_name = row[1]
	D.update_deed_name()
	return D

// Locks the deed can work: doors and chests standing on its plot.
/obj/item/land_deed/proc/lockables(mob/user)
	var/list/found = list()
	var/list/row = plot_row()
	if (!row || verdict() != "valid")
		return found
	for (var/atom/A in range(1, user))
		if (!istype(A, /obj/structure/simple_door/key_door/custom) && !istype(A, /obj/structure/closet))
			continue
		if (istype(A, /obj/structure/simple_door/key_door/custom/jail) || istype(A, /obj/structure/closet/crate/faction_strongbox))
			continue // jails and the treasury answer only to their keepers
		var/turf/T = get_turf(A)
		if (T && land_row_contains(row, T.x, T.y, T.z))
			found["[A.name] ([dir2text(get_dir(user, A)) || "here"])"] = A
	return found

/obj/item/land_deed/attack_self(mob/living/human/user)
	if (!istype(user))
		return
	if (verdict() != "valid")
		to_chat(user, SPAN_WARNING("This deed is void: the register of [faction] no longer honours it."))
		return
	var/list/row = plot_row()
	var/list/locks = lockables(user)
	if (!locks.len)
		to_chat(user, SPAN_NOTICE(land_plot_text(faction, plot_id, row)))
		to_chat(user, SPAN_NOTICE("Standing beside a door or chest on this land, you can lock or unlock it with the deed."))
		return
	var/pick = WWinput(user, "Lock or unlock which, as the holder of this land?", "Deed", "Cancel", locks + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in locks) || user.get_active_hand() != src || verdict() != "valid")
		return
	var/atom/A = locks[pick]
	if (QDELETED(A) || get_dist(user, A) > 1 || !(A in lockables(user)))
		return
	if (istype(A, /obj/structure/simple_door/key_door/custom))
		var/obj/structure/simple_door/key_door/custom/door = A
		if (door.state)
			to_chat(user, SPAN_NOTICE("Close it first."))
			return
		door.locked = !door.locked
		user.visible_message(SPAN_NOTICE("[user] [door.locked ? "locks" : "unlocks"] \the [door]."))
	else
		var/obj/structure/closet/C = A
		if (C.opened)
			to_chat(user, SPAN_NOTICE("Close it first."))
			return
		C.locked = !C.locked
		user.visible_message(SPAN_NOTICE("[user] [C.locked ? "locks" : "unlocks"] \the [C]."))
	playsound(get_turf(A), 'sound/effects/door_lock_unlock.ogg', 100)

// --- Boundary stones ---------------------------------------------------------------

/obj/structure/boundary_stone
	name = "boundary stone"
	desc = "A stone set upright to mark the corner of a plot. A faction's registrar registers the land between two stones."
	icon = 'icons/obj/stone_age_rites.dmi'
	icon_state = "cairn"
	density = FALSE
	anchored = TRUE
	flammable = FALSE
	not_disassemblable = FALSE
	dismantle_wood_fallback = FALSE

/obj/structure/boundary_stone/New()
	..()
	boundary_stones |= src

/obj/structure/boundary_stone/Destroy()
	boundary_stones -= src
	return ..()

/obj/structure/boundary_stone/examine(mob/user, distance = -1)
	..()
	var/list/at = map ? map.land_plot_at(get_turf(src)) : null
	if (at)
		var/list/row = map.land_plot(at[1], at[2])
		to_chat(user, SPAN_NOTICE("It marks [row[1]] of [at[1]]."))

/obj/structure/boundary_stone/attack_hand(mob/living/human/user)
	if (!istype(user) || !map)
		return ..()
	var/faction = user.civilization
	var/registrar = faction && faction != "none" && map.faction_power(user, faction, "registry")
	var/list/at = map.land_plot_at(get_turf(src))
	var/list/row = at ? map.land_plot(at[1], at[2]) : null
	if (!registrar || (at && at[1] != faction))
		if (row)
			to_chat(user, SPAN_NOTICE(land_plot_text(at[1], at[2], row)))
		else
			to_chat(user, SPAN_NOTICE("No registered land is marked here. A faction's leader or registrar can register the land between two boundary stones."))
		return
	var/list/choices = list()
	if (row)
		choices += list("Read the register", "Set the land tax", "Reissue the deed", "Rename the plot", "Strike the plot from the register")
	else
		choices += "Register a plot to another stone"
	choices += "Cancel"
	var/choice = WWinput(user, row ? "[row[1]] of [faction]" : "Land registry of [faction]", "Boundary stone", "Cancel", choices)
	if (!choice || choice == "Cancel" || !(choice in choices) || !user.Adjacent(src) || !map.faction_power(user, faction, "registry"))
		return
	if (choice == "Register a plot to another stone")
		register_plot(user, faction)
		return
	// The plot may have changed during the prompt.
	row = map.land_plot(faction, at[2])
	if (!row)
		return
	var/id = at[2]
	switch (choice)
		if ("Read the register")
			to_chat(user, SPAN_NOTICE(land_plot_text(faction, id, row)))
		if ("Set the land tax")
			var/value = player_input(user, "Land tax on [row[1]], in silver a week (0 to [LAND_TAX_MAX]). It is paid into the faction's strongbox.", "Land tax", row[8], "num", null, TRUE)
			if (!isnum(value) || !map.faction_power(user, faction, "registry") || !map.land_plot(faction, id))
				return
			var/owed = land_tax_owed(row, recruitment_now())
			row[8] = clamp(round(value), 0, LAND_TAX_MAX)
			// Arrears at the old rate are kept at the new one.
			row[9] = recruitment_now()
			if (owed > 0 && row[8] > 0)
				row[9] -= owed / row[8] * LAND_WEEK
			land_log(faction, "[user.real_name] set the land tax on [row[1]] at [row[8]] silver a week.")
			to_chat(user, SPAN_NOTICE("The land tax on [row[1]] is now [row[8]] silver a week."))
		if ("Reissue the deed")
			var/confirm = WWinput(user, "Reissue the deed to [row[1]]? The old deed becomes void, wherever it is. Use this for a lost deed, or land taken back for unpaid tax.", "Reissue", "Cancel", list("Reissue it", "Cancel"))
			if (confirm != "Reissue it" || !map.faction_power(user, faction, "registry") || !map.land_plot(faction, id))
				return
			row[7]++
			row[10] = user.real_name
			var/obj/item/land_deed/D = map.land_issue_deed(faction, id, get_turf(user))
			user.put_in_hands(D)
			land_log(faction, "[user.real_name] reissued the deed to [row[1]]; the old deed is void.")
			to_chat(user, SPAN_NOTICE("You write out a new deed to [row[1]]. The old one is void."))
		if ("Rename the plot")
			var/value = land_name_clean(player_input(user, "New name for the plot:", "Plot", row[1], "text", null, TRUE), null)
			if (!value || !map.faction_power(user, faction, "registry") || !map.land_plot(faction, id))
				return
			row[1] = value
			for (var/obj/item/land_deed/D in land_deeds)
				if (D.faction == faction && D.plot_id == id)
					D.plot_name = value
					D.update_deed_name()
			to_chat(user, SPAN_NOTICE("The plot is now called [value]."))
		if ("Strike the plot from the register")
			var/confirm = WWinput(user, "Strike [row[1]] from the register? Its deed becomes void and the land is unclaimed.", "Strike", "Cancel", list("Strike it", "Cancel"))
			if (confirm != "Strike it" || !map.faction_power(user, faction, "registry"))
				return
			var/list/rows = map.land_plots(faction)
			rows -= id
			land_log(faction, "[user.real_name] struck [row[1]] from the register.")
			to_chat(user, SPAN_NOTICE("[row[1]] is struck from the register."))

/obj/structure/boundary_stone/proc/register_plot(mob/living/human/user, faction)
	var/list/options = list()
	for (var/obj/structure/boundary_stone/B in boundary_stones)
		if (B == src || QDELETED(B) || B.z != z || !isturf(B.loc))
			continue
		var/dx = B.x - x
		var/dy = B.y - y
		if (abs(dx) >= LAND_PLOT_MAX_SIDE || abs(dy) >= LAND_PLOT_MAX_SIDE || !dx || !dy)
			continue
		options["stone [abs(dx)] [dx > 0 ? "east" : "west"], [abs(dy)] [dy > 0 ? "north" : "south"]"] = B
	if (!options.len)
		to_chat(user, SPAN_NOTICE("Set another boundary stone at the opposite corner of the plot, at most [LAND_PLOT_MAX_SIDE - 1] tiles away each way."))
		return
	var/pick = WWinput(user, "Which stone marks the opposite corner?", "Register a plot", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options))
		return
	var/obj/structure/boundary_stone/other = options[pick]
	var/name = player_input(user, "Name the plot (for example, \"the mill\" or \"Reeve's farm\"):", "Register a plot", "", "text", null, TRUE)
	if (QDELETED(other) || !user.Adjacent(src) || !map.faction_power(user, faction, "registry"))
		return
	var/id = map.land_register(faction, name, get_turf(src), get_turf(other), user.real_name)
	if (copytext(id, 1, 2) == "!")
		to_chat(user, SPAN_WARNING(copytext(id, 2)))
		return
	var/obj/item/land_deed/D = map.land_issue_deed(faction, id, get_turf(user))
	user.put_in_hands(D)
	var/list/row = map.land_plot(faction, id)
	land_log(faction, "[user.real_name] registered [row[1]].")
	to_chat(user, SPAN_NOTICE("You register [row[1]] and write out its deed. Whoever holds the deed holds the land."))
	log_game("[key_name(user)] registered plot [id] ([row[1]]) of [faction] at ([row[2]],[row[3]])-([row[4]],[row[5]],[row[6]]).")

/proc/land_log(faction, text)
	if (map)
		map.treasury_log(faction, text)

// --- Land tax at the strongbox ----------------------------------------------------------

/obj/structure/closet/crate/faction_strongbox/proc/pay_land_tax(mob/living/human/user)
	var/obj/item/stack/money/M = user.get_active_hand()
	if (!istype(M) || !M.is_metal_coin() || M.amount < 1)
		to_chat(user, SPAN_NOTICE("Hold the coins you want to pay in your hand."))
		return
	var/list/options = list()
	var/list/rows = map.land_plots(faction)
	for (var/id in rows)
		var/list/row = map.land_plot(faction, id)
		if (row && row[8] > 0)
			options["[row[1]] ([weighed_silver_text(land_tax_owed(row, recruitment_now()))] owed)"] = id
	if (!options.len)
		to_chat(user, SPAN_NOTICE("[faction] taxes no land."))
		return
	var/pick = WWinput(user, "Pay land tax on which plot?", "Land tax", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options) || user.get_active_hand() != M || !user.Adjacent(src))
		return
	var/list/row = map.land_plot(faction, options[pick])
	if (!row || row[8] <= 0)
		return
	var/worth = round(M.amount * M.value, 0.1)
	user.drop_from_inventory(M)
	M.forceMove(opened ? loc : src)
	land_tax_pay(row, worth)
	var/owed = land_tax_owed(row, recruitment_now())
	map.treasury_log(faction, "[user.real_name] paid land tax worth [weighed_silver_text(worth)] on [row[1]].")
	to_chat(user, SPAN_NOTICE("You pay [weighed_silver_text(worth)] of land tax on [row[1]]. [owed > 0 ? "[weighed_silver_text(owed)] is still owed." : "It is paid up."]"))

#undef LAND_PLOT_MAX_SIDE
#undef LAND_PLOT_MIN_SIDE
#undef LAND_PLOTS_PER_FACTION
#undef LAND_TAX_MAX
#undef LAND_NAME_MAX
#undef LAND_WEEK
