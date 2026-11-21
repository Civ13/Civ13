// ============================================================
// Apostates (magic materials and enchanting plan, PR 11). Hidden mechanic:
// keep it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A verified magic user may renounce their god once in a life: Renounce from
// Beseech, two confirmations, then 10 real minutes kneeling still. The god is
// not asked, but every god speaking for that faith is told. The apostate loses
// their patron, every repository tie, their altars and all they were taught,
// except up to 2 invocations they choose to keep. A kept invocation works
// without a god's click at half effect, costs the slot and one attuned
// material, and fades after 5 uses or 14 real days. The former god senses
// them (Divine Patron > List apostates) and that god's magic users feel that
// something is wrong when they examine one. The former god can take them back
// at any time; another god only 14 days after they renounced.
// ============================================================

#define ARCANE_APOSTATE_KNEEL 6000       // deciseconds kneeling to renounce
#define ARCANE_APOSTATE_DAYS 12096000    // 14 real days in deciseconds
#define ARCANE_APOSTATE_USES 5
#define ARCANE_APOSTATE_KEEP 2
#define ARCANE_APOSTATE_REACH 7          // as far as Affliction reaches (covenant.dm)

// Invocations an apostate can keep: those that need no god to speak or grant.
var/global/list/arcane_apostate_keepable = list("mercy", "affliction")

/mob/living/human
	var/arcane_renounced = FALSE         // saved: renounced once this life
	var/arcane_apostate_of = null        // saved: the former god's key while apostate
	var/arcane_apostate_at = 0           // saved: world.realtime when they renounced
	var/list/arcane_apostate_uses = null  // saved: kept invocation id -> uses left
	var/list/arcane_apostate_fades = null // saved: kept invocation id -> world.realtime it fades
	var/tmp/arcane_renouncing = FALSE

// ---- Renouncing ------------------------------------------------------------

/mob/living/human/proc/arcane_can_renounce()
	return !arcane_renounced && !arcane_apostate_of && istext(divine_patron) && length(divine_patron) && magic_allowed() && verified_discord_id(ckey)

/mob/living/human/proc/arcane_renounce()
	if (!arcane_can_renounce() || arcane_renouncing || divine_request)
		return
	var/god = divine_label_for(divine_patron)
	if (player_alert(src, "Renounce [god]? You lose your god, your ties and nearly everything you were taught. You can only do this once.", "Renounce", list("Renounce", "Cancel")) != "Renounce")
		return
	if (player_alert(src, "Are you certain? [god] will know.", "Renounce", list("I am certain", "Cancel")) != "I am certain")
		return
	var/list/options = list()
	for (var/spell in arcane_apostate_keepable)
		if (islist(divine_known) && (spell in divine_known))
			options[divine_invocation_names[spell]] = spell
	var/list/kept = list()
	while (options.len && kept.len < ARCANE_APOSTATE_KEEP)
		var/list/menu = options.Copy()
		menu["Nothing more"] = null
		var/pick = player_input(src, "What do you hold on to? ([ARCANE_APOSTATE_KEEP - kept.len] left)", "Renounce", null, "anything", menu, TRUE)
		var/spell = options[pick]
		if (!spell)
			break
		kept += spell
		options -= pick
	if (!arcane_can_renounce() || arcane_renouncing || divine_request)
		return
	arcane_renouncing = TRUE
	to_chat(src, SPAN_NOTICE("You kneel and begin to turn away from [god]. Stay still."))
	visible_message("<span class='notice'>[src] kneels.</span>", null, 3)
	var/done = do_after(src, ARCANE_APOSTATE_KNEEL, src, needhand = FALSE)
	arcane_renouncing = FALSE
	if (!done || !arcane_can_renounce() || divine_request)
		to_chat(src, SPAN_WARNING("You break off before it is done."))
		return
	arcane_become_apostate(kept)

/mob/living/human/proc/arcane_become_apostate(list/kept)
	var/former = divine_book_key(divine_patron)
	var/label = divine_label_for(divine_patron)
	if (divine_covenant || divine_request)
		divine_break_covenant()
	if (divine_vigil_member)
		divine_leave_vigil()
	magic_repo_withdraw_all() // repository.dm
	for (var/id in magic_registered_repos)
		var/obj/O = magic_repo_find(id)
		if (O && islist(O.magic_repo_registrants))
			O.magic_repo_registrants -= magic_key()
	magic_registered_repos = null
	for (var/obj/O in arcane_my_altars()) // arcane_altars.dm
		O.arcane_altar_end()
	arcane_altar_spots = null
	divine_patron = null
	divine_known = null
	arcane_renounced = TRUE
	arcane_apostate_of = former
	arcane_apostate_at = world.realtime
	arcane_apostate_uses = list()
	arcane_apostate_fades = list()
	for (var/spell in kept)
		arcane_apostate_uses[spell] = ARCANE_APOSTATE_USES
		arcane_apostate_fades[spell] = world.realtime + ARCANE_APOSTATE_DAYS
	divine_refresh_verbs()
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("<i>It is done. [label] is gone from you[kept.len ? ", but something remains" : ""].</i>")))
	for (var/client/C in divine_online_operators(former))
		to_chat(C, CHAT_TYPED(CHAT_PRAYER, SPAN_WARNING("[real_name] ([ckey]) has renounced [label].")))
	var/list/names = list()
	for (var/spell in kept)
		names += divine_invocation_names[spell]
	log_admin("Apostasy: [key_name(src)] renounced [former], keeping [names.len ? english_list(names) : "nothing"].")

// ---- What remains ----------------------------------------------------------

// Drops kept invocations that have faded; returns the live ones.
/mob/living/human/proc/arcane_apostate_kept()
	. = list()
	if (!arcane_apostate_of || !islist(arcane_apostate_uses))
		return
	for (var/spell in arcane_apostate_uses.Copy())
		var/fades = islist(arcane_apostate_fades) ? arcane_apostate_fades[spell] : 0
		if (arcane_apostate_uses[spell] <= 0 || !isnum(fades) || world.realtime >= fades)
			arcane_apostate_uses -= spell
			if (islist(arcane_apostate_fades))
				arcane_apostate_fades -= spell
			continue
		. += spell

// Beseech stays for an apostate while anything they kept lives (divine_refresh_verbs).
/mob/living/human/proc/arcane_apostate_can_pray()
	return arcane_apostate_of && magic_allowed() && length(arcane_apostate_kept())

// The first attuned material in a worn pouch, used up by a kept invocation.
/mob/living/human/proc/arcane_apostate_material()
	for (var/obj/item/clothing/accessory/storage/belt_pouch/P in GetAllContents(4))
		if (!P.hold || QDELETED(P))
			continue
		for (var/obj/item/I in P.hold.contents)
			if (!QDELETED(I) && I.arcane_virtue())
				return I
	return null

/mob/living/human/proc/arcane_apostate_problem(spell)
	if (!magic_allowed())
		return "Nothing stirs."
	if (stat != CONSCIOUS || incapacitated())
		return "You can't do that like this."
	if (map && map.persistence && (!persistence_player_restore_ready || persistence_save_in_progress || persistence_active_operation))
		return "Wait for the world save or load to finish."
	if (spell && !(spell in arcane_apostate_kept()))
		return "That is gone from you."
	if (!divine_slot_ready())
		return "You are too spent for that. Rest first."
	if (!divine_focus())
		return "You need to hold your stick."
	if (!arcane_apostate_material())
		return "Nothing in your pouch answers you."
	return null

// Called from Beseech instead of a prayer while apostate (covenant.dm).
/mob/living/human/proc/arcane_apostate_beseech()
	var/problem = arcane_apostate_problem(null)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/list/choices = list()
	for (var/spell in arcane_apostate_kept())
		choices[divine_invocation_names[spell]] = spell
	if (!choices.len)
		divine_refresh_verbs()
		return
	var/spell = choices[player_input(src, "What do you call on?", "What remains", null, "anything", choices, TRUE)]
	if (!spell)
		return
	var/range = spell == "affliction" ? ARCANE_APOSTATE_REACH : 1
	var/list/targets = list()
	for (var/mob/living/human/H in view(range, src))
		if (divine_target_legal(src, spell, H))
			targets["[H.name][H == src ? " (yourself)" : ""]"] = H
	if (!targets.len)
		to_chat(src, SPAN_WARNING("There is no one here for that."))
		return
	var/mob/living/human/target = targets[player_input(src, "For whom?", "What remains", null, "anything", targets, TRUE)]
	if (!target || !do_after(src, 30, target, needhand = FALSE))
		return
	problem = arcane_apostate_problem(spell)
	if (!problem && !divine_target_legal(src, spell, target))
		problem = "They are no longer there."
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/obj/item/M = arcane_apostate_material()
	var/used = "[M] ([M.type], [M.arcane_aspect] [M.arcane_strength])"
	var/obj/item/stack/S = M
	if (istype(S) && S.amount > 1)
		S.use(1)
	else
		var/obj/item/weapon/storage/box = M.loc
		if (istype(box))
			box.remove_from_storage(M, get_turf(src))
		qdel(M)
	divine_slot_spent = TRUE
	divine_spent_realtime = world.realtime
	switch (spell)
		if ("mercy")
			divine_drain(src, 0.3)
			target.adjustHalLoss(-20)
			divine_drain(target, -0.125)
			to_chat(target, SPAN_NOTICE("Your pain eases a little."))
			if (target != src)
				to_chat(src, SPAN_NOTICE("You feel drained."))
		if ("affliction")
			divine_drain(src, 0.3)
			target.adjustHalLoss(10)
			divine_drain(target, 0.2)
			to_chat(target, SPAN_WARNING("A dull ache runs through you."))
			to_chat(src, SPAN_NOTICE("You feel drained."))
	arcane_apostate_uses[spell]--
	var/left = arcane_apostate_uses[spell]
	log_admin("Apostate use: [spell] by [key_name(src)] (renounced [arcane_apostate_of]) on [key_name(target)], spending [used]; [left] uses left.")
	if (left <= 0)
		arcane_apostate_kept()
		to_chat(src, SPAN_WARNING("<i>Something you held on to is gone for good.</i>"))
		divine_refresh_verbs()

// ---- Marked ----------------------------------------------------------------

// One plain line for the former god's magic users (human examine.dm).
/mob/living/human/proc/arcane_apostate_examine(mob/user)
	var/mob/living/human/H = user
	if (!arcane_apostate_of || !istype(H) || H == src || !H.arcane_magic_user() || divine_book_key(H.divine_patron) != arcane_apostate_of)
		return ""
	return "<br><i>Something about them feels wrong to you.</i>"

// Whether a god may initiate this character (Divine Patron > Initiate).
/mob/living/human/proc/arcane_apostate_may_join(claim)
	if (!arcane_apostate_of || arcane_apostate_of == claim)
		return TRUE
	return world.realtime >= arcane_apostate_at + ARCANE_APOSTATE_DAYS || world.realtime < arcane_apostate_at

// On being initiated again: the former god gets back what has not faded.
/mob/living/human/proc/arcane_apostate_return(claim)
	if (!arcane_apostate_of)
		return
	if (arcane_apostate_of == claim)
		if (!islist(divine_known))
			divine_known = list()
		divine_known |= arcane_apostate_kept()
	log_admin("Apostasy: [key_name(src)] (renounced [arcane_apostate_of]) was taken in by [claim].")
	arcane_apostate_of = null
	arcane_apostate_uses = null
	arcane_apostate_fades = null

/client/proc/arcane_list_apostates(claim)
	var/list/lines = list()
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H) || H.arcane_apostate_of != claim)
			continue
		var/list/kept = list()
		for (var/spell in H.arcane_apostate_kept())
			kept += "[divine_invocation_names[spell]] ([H.arcane_apostate_uses[spell]] left)"
		var/turf/T = get_turf(H)
		var/area/A = T ? T.loc : null
		var/days = round(max(0, world.realtime - H.arcane_apostate_at) / 864000)
		lines += "[H.real_name] ([H.ckey ? H.ckey : "no player"])[H.stat == DEAD ? ", dead" : ""], at [A ? A.name : "nowhere"] ([T ? "[T.x], [T.y], [T.z]" : "?"]), renounced [days] days ago: [kept.len ? english_list(kept) : "nothing kept"]"
	to_chat(src, "<b>Apostates of [divine_label_for(claim)] in this world:</b><br>[lines.len ? jointext(lines, "<br>") : "none"]")

#undef ARCANE_APOSTATE_KNEEL
#undef ARCANE_APOSTATE_DAYS
#undef ARCANE_APOSTATE_USES
#undef ARCANE_APOSTATE_KEEP
#undef ARCANE_APOSTATE_REACH
