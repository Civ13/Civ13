// ============================================================
// Divine casting on persistent worlds (#5142). Hidden mechanic: keep it out of
// changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// Staff playing a god speak as that god (Divine Patron admin verb), initiate a
// character as a follower and teach them invocations. A follower beseeches
// their god for one use at a time; every use waits for that god's own approval
// (approval.dm). Knowing an invocation never grants permission by itself.
//
// Saved on the character: the patron, the learned invocations and whether the
// day's one invocation has been spent. Never saved: claims, covenants and
// requests; a restart or transfer simply drops anything pending.
//
// A follower needs an ordinary held stick as a focus and an ordinary pouch
// with something small in it (one item is used up per invocation). Nothing
// here gives an item a special name, sprite or examine line.
// ============================================================

#define DIVINE_REQUEST_LIFETIME 600     // deciseconds a god has to answer (approval.dm cap)
#define DIVINE_VIGIL_DURATION 150       // deciseconds the vigil is held after approval
#define DIVINE_REST_FALLBACK 36000      // deciseconds of real time; sleeping restores sooner
#define DIVINE_AFFLICTION_RANGE 7

// deity key -> list of staff ckeys currently speaking as that god. Runtime only.
var/global/list/divine_patron_claims = list()
// Requests waiting on, or channelling after, a god's answer. Runtime only.
var/global/list/divine_pending_requests = list()

// Invocation id -> name shown only to followers and staff.
var/global/list/divine_invocation_names = list(
	"mercy" = "Mercy",
	"affliction" = "Affliction",
	"omen" = "Omen",
	"vigil" = "Vigil of Recovery",
	"repository" = "Keep a repository", // repository.dm
	"imbue" = "Imbue", // arcane_enchant.dm
	"bless" = "Bless", // arcane_bless.dm
	// Rites the repository grant brings (repository_tiers.dm); never taught alone.
	"repository_strengthen" = "Strengthen a repository",
	"repository_attune" = "Re-attune a repository",
	"repository_move" = "Move a repository into something greater",
	"repository_consecrate" = "Consecrate a fallen repository",
)

/mob/living/human
	var/divine_patron = null            // saved: the god this character follows
	var/list/divine_known = null        // saved: invocation ids the god has taught
	var/divine_slot_spent = FALSE       // saved: the one invocation is used until rest
	var/divine_spent_realtime = 0       // saved: world.realtime when it was used
	var/tmp/datum/divine_covenant_runtime/divine_covenant = null
	var/tmp/datum/divine_use_request/divine_request = null
	var/tmp/datum/divine_use_request/ritual/divine_vigil_member = null // a vigil this body is keeping
	var/tmp/divine_invite_from = null   // a god's invitation waiting for an answer (divine_patron.dm)

/mob/living/human/persistence_runtime_var(key)
	return key == "divine_covenant" || key == "divine_request" || key == "divine_vigil_member" || key == "divine_invite_from" || ..()

/proc/divine_claimants(deity)
	var/key = divine_book_key(deity)
	if (!key)
		return list()
	var/list/claims = divine_patron_claims[key]
	return islist(claims) ? claims : list()

/proc/divine_online_operators(deity)
	. = list()
	for (var/ckey in divine_claimants(deity))
		var/client/C = directory[ckey]
		if (C && C.holder && (C.holder.rights & R_ADMIN))
			. += C

/proc/divine_claim_of(client/C)
	if (!C)
		return null
	for (var/key in divine_patron_claims)
		var/list/claims = divine_patron_claims[key]
		if (islist(claims) && (C.ckey in claims))
			return key
	return null

/mob/living/human/proc/divine_refresh_verbs()
	// Off the magic whitelist (magic_whitelist.dm) the patron stays saved but Beseech goes away.
	if ((istext(divine_patron) && length(divine_patron) && magic_allowed()) || arcane_apostate_can_pray()) // apostates: arcane_apostate.dm
		verbs |= /mob/living/human/proc/divine_beseech
	else
		verbs -= /mob/living/human/proc/divine_beseech
	magic_repo_refresh_verbs() // repository.dm
	arcane_refresh_verbs() // arcane_altars.dm
	heteromorph_refresh_verbs() // heteromorph_form.dm

// Any movement, body change, logout or transfer ends what is pending, including
// leaving and coming back to the same tile, which snapshots cannot see.
/mob/living/human/proc/divine_break_covenant(reason)
	var/datum/divine_use_request/R = divine_request
	if (divine_covenant)
		divine_covenant.invalidate()
	if (R && (R.state == "requested" || R.state == "approved"))
		R.state = "cancelled"
		if (reason && client)
			to_chat(src, SPAN_WARNING(reason))
		divine_finish_request(R)

/mob/living/human/proc/divine_leave_vigil()
	var/datum/divine_use_request/ritual/V = divine_vigil_member
	divine_vigil_member = null
	if (V && (V in divine_pending_requests))
		if (V.covenant && V.covenant.caster)
			to_chat(V.covenant.caster, SPAN_WARNING("The vigil is broken."))
		if (V.covenant)
			V.covenant.invalidate()
		divine_finish_request(V)

/mob/living/human/Move()
	. = ..()
	if (.)
		if (divine_covenant)
			divine_break_covenant("You break off your prayer.")
		if (divine_vigil_member)
			divine_leave_vigil()

/mob/living/human/Logout()
	if (divine_covenant)
		divine_break_covenant()
	if (divine_vigil_member)
		divine_leave_vigil()
	return ..()

/mob/living/human/Login()
	. = ..()
	if (divine_covenant)
		divine_break_covenant()
	if (divine_vigil_member)
		divine_leave_vigil()
	divine_self_worship() // repository_nations.dm
	divine_refresh_verbs()

/mob/living/human/proc/divine_slot_ready()
	if (!divine_slot_spent)
		return TRUE
	if (world.realtime >= divine_spent_realtime + DIVINE_REST_FALLBACK || world.realtime < divine_spent_realtime)
		divine_slot_spent = FALSE
		return TRUE
	return FALSE

// Called when a sleeper finishes waking up: a night's rest restores the slot.
/mob/living/human/proc/divine_rested()
	divine_slot_spent = FALSE
	arcane_rested()

/mob/living/human/proc/divine_focus()
	var/obj/item/I = get_active_hand()
	if (istype(I, /obj/item/weapon/branch) || arcane_storm_focus(I)) // storm wood: arcane_altars.dm
		return I
	I = get_inactive_hand()
	if (istype(I, /obj/item/weapon/branch) || arcane_storm_focus(I))
		return I
	return null

// The first small thing kept in a worn pouch, used up by an invocation.
/mob/living/human/proc/divine_component()
	for (var/obj/item/clothing/accessory/storage/belt_pouch/P in GetAllContents(4))
		if (!P.hold || QDELETED(P))
			continue
		for (var/obj/item/I in P.hold.contents)
			if (!QDELETED(I))
				return I
	return null

// Why this follower can't beseech right now, or null.
/mob/living/human/proc/divine_problem(spell)
	if (!istext(divine_patron) || !length(divine_patron))
		return "You have no one to pray to."
	if (!magic_allowed())
		return "No answer comes."
	if (stat != CONSCIOUS || incapacitated())
		return "You can't pray like this."
	if (map && map.persistence && (!persistence_player_restore_ready || persistence_save_in_progress || persistence_active_operation))
		return "Wait for the world save or load to finish."
	if (spell && !(spell in divine_spells_allowed()))
		return "You don't know that prayer."
	if (!divine_slot_ready())
		return "You are too spent to pray for that again. Rest first."
	if (!divine_focus())
		return "You need to hold your stick."
	if (!divine_component())
		return "Your pouch is empty."
	if (spell == "repository")
		return magic_repo_begin_problem() // repository.dm
	if (spell == "imbue")
		return arcane_imbue_problem(arcane_imbue_pick) // arcane_enchant.dm
	if (spell == "bless")
		return arcane_bless_problem(arcane_bless_pick) // arcane_bless.dm
	if (magic_repo_rite_spell(spell))
		return magic_repo_rite_problem(spell) // repository_tiers.dm
	return null

// The legal target of an invocation at this moment, or null.
/proc/divine_target_legal(mob/living/human/caster, spell, mob/living/human/target)
	if (spell == "imbue") // the held item, or the chest or door beside them (arcane_enchant.dm, arcane_ward.dm)
		return istype(caster) && target && target == caster.arcane_imbue_target()
	if (spell == "bless") // the target is the held item (arcane_bless.dm)
		return istype(caster) && target && target == caster.arcane_imbue_item()
	if (!istype(caster) || !istype(target) || QDELETED(target) || target.stat == DEAD)
		return FALSE
	var/turf/A = get_turf(caster)
	var/turf/B = get_turf(target)
	if (!A || !B || A.z != B.z)
		return FALSE
	if (magic_repo_rite_spell(spell))
		return target == caster // repository_tiers.dm
	switch (spell)
		if ("mercy")
			return get_dist(A, B) <= 1
		if ("affliction")
			return target != caster && get_dist(A, B) <= DIVINE_AFFLICTION_RANGE && (target in view(DIVINE_AFFLICTION_RANGE, caster))
		if ("omen")
			return target == caster
		if ("vigil")
			return get_dist(A, B) <= 1
		if ("repository")
			return target == caster
	return FALSE

// Fixed, server-made effect and cost specification shown to the god.
/proc/divine_scope(spell)
	switch (spell)
		if ("mercy")
			return "mercy-v1: ease pain 40, restore a quarter of energy; costs the slot, 30% energy, one pouch item"
		if ("affliction")
			return "affliction-v1: pain 20, drain 40% energy; costs the slot, 30% energy, one pouch item"
		if ("omen")
			return "omen-v1: one private message you write; costs the slot, one pouch item"
		if ("vigil")
			return "vigil-v1: heal 15 brute and 15 burn, ease pain 30 on the patient; costs the slot, one pouch item, 25% energy from everyone keeping it"
		if ("repository")
			return "repository-v1: begin a personal repository in the small thing they hold; then 30 minutes of channelling paid with hunger, thirst and energy or stored charge; costs the slot, one pouch item"
		if ("repository_strengthen")
			return "repository-strengthen-v1: raise a repository they keep one tier, once it has stayed three quarters full for days with enough tied magic users present; then hours of channelling paid from stored charge; costs the slot, one pouch item"
		if ("repository_attune")
			return "repository-attune-v1: raise a repository's skill to the keeper's own; hours of channelling paid from stored charge; costs the slot, one pouch item"
		if ("repository_move")
			return "repository-move-v1: move a repository they keep, charge and all, into a greater object beside them; the old one becomes ordinary; costs the slot, one pouch item"
		if ("repository_consecrate")
			return "repository-consecrate-v1: take up a settlement or greater repository whose seat has fallen, for their own god, keeping its charge; costs the slot, one pouch item"
	return null

/mob/living/human/proc/divine_beseech()
	set name = "Beseech"
	set category = "IC"
	set desc = "Ask your god for a favour."

	if (usr != src || !client || client.mob != src)
		return
	if (arcane_apostate_of)
		arcane_apostate_beseech() // arcane_apostate.dm
		return
	if (divine_request)
		to_chat(src, SPAN_WARNING("You are already waiting on an answer."))
		return
	var/problem = divine_problem()
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/list/choices = list()
	for (var/spell in divine_spells_allowed())
		if (divine_invocation_names[spell])
			choices[divine_invocation_names[spell]] = spell
	if (arcane_can_renounce()) // arcane_apostate.dm
		choices["Renounce"] = "renounce"
	if (!choices.len)
		to_chat(src, SPAN_WARNING("You don't know any prayers yet."))
		return
	var/picked = player_input(src, "What do you ask for?", "Beseech", null, "anything", choices, TRUE)
	var/spell = choices[picked]
	if (!spell || usr != src || !client || divine_request)
		return
	if (spell == "renounce")
		arcane_renounce()
		return
	var/mob/living/human/target = src
	var/scope = divine_scope(spell)
	if (spell == "imbue")
		scope = arcane_imbue_choose() // arcane_enchant.dm
		target = arcane_imbue_target()
		if (!scope || !target)
			return
	else if (spell == "bless")
		scope = arcane_bless_choose() // arcane_bless.dm
		target = arcane_imbue_item()
		if (!scope || !target)
			return
	else if (spell != "omen" && findtext(spell, "repository") != 1)
		var/list/targets = list()
		var/range = spell == "affliction" ? DIVINE_AFFLICTION_RANGE : 1
		for (var/mob/living/human/H in view(range, src))
			if (divine_target_legal(src, spell, H))
				targets["[H.name][H == src ? " (yourself)" : ""]"] = H
		if (!targets.len)
			to_chat(src, SPAN_WARNING("There is no one here for that."))
			return
		var/who = player_input(src, "For whom?", "Beseech", null, "anything", targets, TRUE)
		target = targets[who]
		if (!target)
			return
	if (magic_repo_rite_spell(spell) && !magic_repo_rite_choose(spell)) // repository_tiers.dm
		return
	var/list/helpers = null
	if (spell == "vigil")
		helpers = divine_gather_vigil(target)
		if (!helpers)
			return
	problem = divine_problem(spell)
	if (!problem && !divine_target_legal(src, spell, target))
		problem = "They are no longer there."
	if (!problem && divine_request)
		problem = "You are already waiting on an answer."
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/list/operators = list()
	for (var/client/C in divine_online_operators(divine_patron))
		operators += C.ckey
	if (!operators.len)
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You pray, but nothing answers.")))
		return
	var/datum/divine_covenant_runtime/covenant = new(src, divine_book_key(divine_patron), operators, divine_spells_allowed())
	covenant.active = TRUE
	var/datum/divine_use_request/R
	if (spell == "vigil")
		R = new /datum/divine_use_request/ritual(covenant, spell, target, divine_scope(spell), helpers, divine_focus(), DIVINE_VIGIL_DURATION, 3, DIVINE_REQUEST_LIFETIME)
	else
		R = new /datum/divine_use_request(covenant, spell, target, scope, DIVINE_REQUEST_LIFETIME)
	if (R.state != "requested")
		qdel(R)
		qdel(covenant)
		to_chat(src, SPAN_WARNING("Your prayer falters. Stay still, keep your stick in hand and try again."))
		return
	divine_covenant = covenant
	divine_request = R
	divine_pending_requests += R
	if (istype(R, /datum/divine_use_request/ritual))
		var/datum/divine_use_request/ritual/V = R
		for (var/mob/living/human/M in V.participants)
			if (M != src)
				M.divine_vigil_member = V
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You hold still and pray to [divine_label_for(divine_patron)].")))
	visible_message("<span class='notice'>[src] bows their head.</span>", null, 3)
	log_game("[key_name(src)] beseeched [divine_patron]: [spell] on [ismob(target) ? key_name(target) : "[target] ([target.type])"].")
	divine_alert_operators(R)
	var/datum/divine_use_request/watched = R
	spawn(DIVINE_REQUEST_LIFETIME + 5)
		if (watched && watched.state == "requested")
			watched.state = "expired"
			if (watched.covenant && watched.covenant.caster)
				to_chat(watched.covenant.caster, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("No answer comes.")))
			divine_finish_request(watched)

// Asks nearby people, at once, whether they will keep the vigil. Ordinary words:
// helpers need not follow any god. Returns the roster including the leader.
/mob/living/human/proc/divine_gather_vigil(mob/living/human/patient)
	var/list/candidates = list()
	for (var/mob/living/human/H in view(3, src))
		if (H != src && H != patient && H.client && H.stat == CONSCIOUS && !H.incapacitated())
			candidates["[H.name]"] = H
	if (candidates.len < 2)
		to_chat(src, SPAN_WARNING("You need at least two others nearby to keep a vigil."))
		return null
	var/list/asked = list()
	while (asked.len < 7 && candidates.len)
		var/who = player_input(src, "Who will keep the vigil with you? ([asked.len] chosen; pick Done when ready)", "Vigil", null, "anything", candidates + "Done", TRUE)
		if (!who)
			return null
		if (who == "Done")
			break
		asked += candidates[who]
		candidates -= who
	if (asked.len < 2)
		to_chat(src, SPAN_WARNING("You need at least two others to keep a vigil."))
		return null
	var/list/answers = list()
	for (var/mob/living/human/H in asked)
		spawn(0)
			if (H && H.client && WWinput(H, "[name] asks you to keep a vigil with them over [patient.name]. Stand still nearby until it is done. Will you?", "Vigil", "No", list("Yes", "No")) == "Yes")
				answers[H] = TRUE
			else
				answers[H] = FALSE
	var/waited = 0
	while (answers.len < asked.len && waited < 200)
		sleep(5)
		waited += 5
	var/list/roster = list(src)
	for (var/mob/living/human/H in asked)
		if (answers[H] && !QDELETED(H))
			roster += H
	if (roster.len < 3)
		to_chat(src, SPAN_WARNING("Not enough people agreed to keep the vigil."))
		return null
	return roster

/proc/divine_alert_operators(datum/divine_use_request/R)
	var/mob/living/human/caster = R.covenant.caster
	var/mob/target = R.target
	var/spell_name = divine_invocation_names[R.spell_id]
	var/text = "<b>[caster.divine_patron]: [caster.real_name] ([caster.ckey]) beseeches you for [spell_name]</b>[karma_staff_badge(karma_mob_ckey(caster))]"
	if (target != caster && ismob(target))
		text += " on [target.real_name] ([target.ckey ? target.ckey : "no player"])[karma_mob_ckey(target) ? karma_staff_badge(karma_mob_ckey(target)) : ""]"
	if (istype(R, /datum/divine_use_request/ritual))
		var/datum/divine_use_request/ritual/V = R
		var/list/names = list()
		for (var/mob/M in V.participants)
			if (M != caster)
				names += M.real_name
		text += ", with [english_list(names)] keeping the vigil"
	text += ". <i>[R.scope_key]</i>. Answer within a minute: "
	text += "<a href='?src=\ref[R];divine_answer=approve'>Grant</a> | <a href='?src=\ref[R];divine_answer=deny'>Refuse</a> | <a href='?_src_=holder;adminplayerobservefollow=\ref[caster]'>Follow</a>"
	for (var/client/C in divine_online_operators(caster.divine_patron))
		if (C.ckey in R.covenant.operator_ckeys)
			to_chat(C, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'>[text]</span>"))
			C << 'sound/effects/adminhelp.ogg'

/datum/divine_use_request/Topic(href, href_list)
	if (!usr || !usr.client || !(src in divine_pending_requests))
		return
	var/client/C = usr.client
	var/answer = href_list["divine_answer"]
	if (answer == "approve")
		divine_grant(src, C)
	else if (answer == "deny")
		divine_refuse(src, C)

/proc/divine_refuse(datum/divine_use_request/R, client/C)
	if (!R || !(R in divine_pending_requests))
		return
	if (!R.deny(C))
		to_chat(C, SPAN_WARNING("That prayer can't be answered now."))
		return
	var/mob/caster = R.covenant.caster
	to_chat(C, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You refused [caster.real_name].")))
	to_chat(caster, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("Your prayer goes unanswered.")))
	divine_finish_request(R)

/proc/divine_grant(datum/divine_use_request/R, client/C)
	if (!R || !(R in divine_pending_requests) || !R.covenant)
		return
	if (!R.covenant.operator_allowed(C) || divine_claim_of(C) != R.covenant.deity_id)
		to_chat(C, SPAN_WARNING("You are not speaking as this follower's god."))
		return
	var/omen_text = null
	if (R.spell_id == "omen")
		// Written before approving, so nothing yields between approval and the effect.
		var/raw = player_input(C, "What does [R.covenant.caster.real_name] see or hear? Only they will.", "Omen", null, "message", null, TRUE)
		omen_text = raw ? sanitize(raw, MAX_MESSAGE_LEN) : null
		if (!omen_text || !(R in divine_pending_requests))
			return
	if (!R.approve(C))
		to_chat(C, SPAN_WARNING("That prayer can't be answered now: they moved, changed or the time ran out."))
		if (!R.current())
			divine_finish_request(R)
		return
	divine_note_self_approval(R, C) // repository_nations.dm
	if (istype(R, /datum/divine_use_request/ritual))
		var/datum/divine_use_request/ritual/V = R
		if (!V.start_channel())
			to_chat(C, SPAN_WARNING("The vigil broke before it could begin."))
			to_chat(V.covenant.caster, SPAN_WARNING("The vigil falters."))
			divine_finish_request(V)
			return
		for (var/mob/M in V.participants)
			to_chat(M, SPAN_NOTICE("A calm settles over the vigil. Hold still a little longer."))
		to_chat(C, SPAN_NOTICE("You granted the vigil; it completes in [DIVINE_VIGIL_DURATION / 10] seconds if they hold it."))
		spawn(DIVINE_VIGIL_DURATION + 1)
			if (V && (V in divine_pending_requests))
				divine_dispatch(V, null)
		return
	to_chat(C, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You granted [R.covenant.caster.real_name]'s prayer.")))
	divine_dispatch(R, omen_text)

// Recheck, consume, charge and apply in one synchronous call with no yield.
// Failure after consumption keeps the approval spent; nothing is refunded.
/proc/divine_dispatch(datum/divine_use_request/R, omen_text)
	var/mob/living/human/caster = R.covenant ? R.covenant.caster : null
	var/mob/living/human/target = R.target
	var/spell = R.spell_id
	if (!istype(caster) || caster.divine_problem(spell) || !divine_target_legal(caster, spell, target))
		if (caster)
			to_chat(caster, SPAN_WARNING("Your prayer slips away."))
		R.state = "cancelled"
		divine_finish_request(R)
		return FALSE
	var/obj/item/component = (spell == "imbue" || spell == "bless") ? null : caster.divine_component() // Imbue and Bless use up their own materials
	if (!R.consume(caster, spell, target, R.scope_key))
		to_chat(caster, SPAN_WARNING("Your prayer slips away."))
		divine_finish_request(R)
		return FALSE
	caster.divine_slot_spent = TRUE
	caster.divine_spent_realtime = world.realtime
	if (arcane_storm_focus(caster.divine_focus())) // storm wood brings the slot back after 45 minutes
		caster.divine_spent_realtime -= DIVINE_REST_FALLBACK / 4
	var/bonus = arcane_component_bonus(component, spell) // arcane_altars.dm
	if (component)
		var/obj/item/weapon/storage/S = component.loc
		if (istype(S))
			S.remove_from_storage(component, get_turf(caster))
		qdel(component)
	switch (spell)
		if ("mercy")
			divine_drain(caster, 0.3)
			target.adjustHalLoss(-round(40 * bonus))
			divine_drain(target, -0.25)
			to_chat(target, SPAN_NOTICE("Your pain eases and you feel a little stronger."))
			if (target != caster)
				to_chat(caster, SPAN_NOTICE("You feel drained."))
		if ("affliction")
			divine_drain(caster, 0.3)
			target.adjustHalLoss(round(20 * bonus))
			divine_drain(target, 0.4)
			to_chat(target, SPAN_WARNING("A sudden ache runs through you and your limbs feel heavy."))
			to_chat(caster, SPAN_NOTICE("You feel drained."))
		if ("omen")
			to_chat(caster, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><i>[omen_text]</i></span>"))
		if ("vigil")
			var/datum/divine_use_request/ritual/V = R
			for (var/mob/living/human/M in V.participants)
				divine_drain(M, 0.25)
				if (M != target)
					to_chat(M, SPAN_NOTICE("The vigil is over. You feel tired."))
			target.heal_overall_damage(round(15 * bonus), round(15 * bonus))
			target.adjustHalLoss(-round(30 * bonus))
			to_chat(target, SPAN_NOTICE("You feel your strength returning."))
		if ("repository")
			caster.magic_repo_begin() // repository.dm
		if ("imbue")
			caster.arcane_imbue_apply(R.target) // arcane_enchant.dm
		if ("bless")
			caster.arcane_bless_apply(R.target) // arcane_bless.dm
		if ("repository_strengthen", "repository_attune", "repository_move", "repository_consecrate")
			caster.magic_repo_rite_granted(spell) // repository_tiers.dm
	log_admin("Divine use applied: [spell] by [key_name(caster)] on [ismob(target) ? key_name(target) : "[R.target] ([R.target.type])"] for [R.approved_deity] (approved by [R.approver_ckey]).")
	divine_finish_request(R)
	return TRUE

// Positive fraction drains energy, negative restores it.
/proc/divine_drain(mob/living/human/H, fraction)
	if (!istype(H) || !H.stats || !islist(H.stats["stamina"]))
		return
	var/list/S = H.stats["stamina"]
	S[1] = clamp(S[1] - round(S[2] * fraction), 0, S[2])

/proc/divine_finish_request(datum/divine_use_request/R)
	if (!R)
		return
	divine_pending_requests -= R
	var/datum/divine_covenant_runtime/covenant = R.covenant
	var/mob/living/human/caster = covenant ? covenant.caster : null
	if (istype(caster) && caster.divine_request == R)
		caster.divine_request = null
		caster.divine_covenant = null
	if (istype(R, /datum/divine_use_request/ritual))
		var/datum/divine_use_request/ritual/V = R
		for (var/mob/living/human/M in V.participants)
			if (M.divine_vigil_member == V)
				M.divine_vigil_member = null
	if (R.state == "requested" || R.state == "approved")
		R.state = "cancelled"
	qdel(R)
	if (covenant)
		qdel(covenant)

#undef DIVINE_AFFLICTION_RANGE
