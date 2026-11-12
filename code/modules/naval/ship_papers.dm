// ============================================================
// Ship's papers (docs/craft-core.md): the crew register at the wheel
// ------------------------------------------------------------
// A ship nobody registered sails for anyone, as before. At the wheel a
// player may register her to their faction (or to themselves when they have
// none). From then on only her crew take the wheel freely:
//
//   - members of the owning party, and listed crew with a steering role,
//     steer as before;
//   - anyone else can force the wheel, slowly and with the crew warned, but
//     only while one of her owners is in the world to defend her. With no
//     owner about the wheel is chained.
//
// The elevator and catapult levers and the radar follow the same rule
// without the delay: crew always, strangers only while an owner is about.
// The register is saved by the wheel beside the ship's own state.
// ============================================================

#define VESSEL_FORCE_WHEEL_TIME 150

// Whether this mob may take the helm: freely, by force, or not at all.
/datum/craft/proc/helm_access(mob/user)
	if (!register || !register.party || register.may_steer(user))
		return CRAFT_HELM_FREE
	return register.owners_online() ? CRAFT_HELM_FORCE : CRAFT_HELM_CHAINED

// Why this mob may not work the ship's fittings, or null.
/datum/craft/proc/fitting_refusal(mob/user)
	if (!register || !register.party || register.is_crew(user) || register.owners_online())
		return null
	return "It is locked. The [name] belongs to [party_train_party_name(register.party)] and none of them are about."

/proc/vessel_fitting_refusal(datum/vessel/V, mob/user)
	var/datum/craft/C = craft_of_vessel(V, FALSE)
	return C ? C.fitting_refusal(user) : null

/datum/craft_register/proc/roles()
	return list(CRAFT_ROLE_CAPTAIN, CRAFT_ROLE_HELMSMAN, CRAFT_ROLE_ENGINEER, CRAFT_ROLE_GUNNER, CRAFT_ROLE_HAND)

// Registers the craft to this character's party with them as captain.
/datum/craft_register/proc/claim(mob/living/human/H)
	if (party || !istype(H))
		return FALSE
	var/claimant = party_train_party_of(H)
	if (!claimant)
		return FALSE
	party = claimant
	crew[H.real_name] = CRAFT_ROLE_CAPTAIN
	return TRUE

// Strikes the craft from the register: she is anyone's again.
/datum/craft_register/proc/give_up()
	party = null
	crew = list()
	requests = list()
	barred = list()
	join_mode = CRAFT_JOIN_CLOSED
	memo = ""

// of is the craft whose words to use (a vehicle is "it" and has a driver);
// without one the papers read as a ship's.
/datum/craft_register/proc/summary_text(ship_name, datum/craft/of = null)
	if (!party)
		return of ? "The [ship_name] is not registered to anyone. Whoever [of.helm_stance] the [of.helm_word] may [of.sail_word] [of.pro_her]." : "The [ship_name] is not registered to anyone. Whoever stands at the wheel may sail her."
	var/list/lines = list("The [ship_name] is registered to [party_train_party_name(party)].")
	var/list/listed = list()
	for (var/who in crew)
		listed += "[who] ([of ? of.role_title(crew[who]) : crew[who]])"
	lines += listed.len ? "Crew: [jointext(listed, ", ")]." : "No crew are listed."
	switch (join_mode)
		if (CRAFT_JOIN_OPEN) lines += "Anyone may sign on as a [of ? of.role_title(CRAFT_ROLE_HAND) : CRAFT_ROLE_HAND]."
		if (CRAFT_JOIN_ASK) lines += "New crew must ask and be accepted."
		if (CRAFT_JOIN_CLOSED) lines += "[of ? capitalize(of.pro_she) : "She"] takes no new crew."
	if (requests.len)
		lines += "Asking to join: [jointext(requests, ", ")]."
	if (barred.len)
		lines += "Barred: [jointext(barred, ", ")]."
	return jointext(lines, " ")

// ---- The wheel ----

/obj/structure/vessel_helm
	// The crew register's register_state() text, saved like vessel_state.
	var/register_state = ""

/obj/structure/vessel_helm/proc/ship_craft()
	return vessel ? craft_of_vessel(vessel) : null

/obj/structure/vessel_helm/proc/ship_register(make = FALSE)
	var/datum/craft/C = ship_craft()
	if (!C)
		return null
	if (!C.register && make)
		C.register = new /datum/craft_register
		C.register.name = C.name
	return C.register

/obj/structure/vessel_helm/before_save()
	..()
	var/datum/craft_register/R = ship_register()
	register_state = (R && R.party) ? R.register_state() : ""

/obj/structure/vessel_helm/after_load()
	..()
	if (!register_state)
		return
	var/datum/craft/C = ship_craft()
	var/datum/craft_register/R = craft_register_restore(register_state)
	if (C && R)
		C.register = R

// What stops this mob steering: CRAFT_HELM_FREE, _FORCE or _CHAINED.
/obj/structure/vessel_helm/proc/steer_access(mob/user)
	var/datum/craft/C = ship_craft()
	return C ? C.helm_access(user) : CRAFT_HELM_FREE

/obj/structure/vessel_helm/proc/force_wheel(mob/living/human/H)
	var/datum/craft/C = ship_craft()
	return C ? C.force_helm(H, src) : TRUE

/obj/structure/vessel_helm/proc/papers(mob/living/human/H)
	var/datum/craft/C = ship_craft()
	if (C)
		C.papers(H, src)

// ---- The papers themselves: one menu for every kind of craft ----

// The words the papers use. A kind of craft that is not a ship sets its own.
/datum/craft
	var/papers_title = "Ship's papers"
	var/kind_word = "ship"
	var/helm_word = "wheel"
	var/helm_stance = "stands at"
	var/sail_word = "sail"
	var/pro_she = "she"
	var/pro_her = "her"       // "sail her"
	var/pro_hers = "her"      // "her crew"

// What a role is called aboard this kind of craft.
/datum/craft/proc/role_title(role)
	return role

// Title -> role, for the menus.
/datum/craft/proc/role_titles(datum/craft_register/R)
	. = list()
	for (var/role in R.roles())
		.[role_title(role)] = role

// Entries a kind of craft adds to its papers, and what they do. An action
// returns TRUE when it handled the choice.
/datum/craft/proc/papers_extra(mob/living/human/H, datum/craft_register/R)
	return list()

/datum/craft/proc/papers_extra_action(mob/living/human/H, datum/craft_register/R, choice, atom/at)
	return FALSE

// Everyone aboard hears it.
/datum/craft/proc/crew_message(text)
	if (!body)
		return
	for (var/mob/living/M in body.aboard())
		to_chat(M, text)

// A stranger takes the wheel by force. Returns TRUE when they have it.
/datum/craft/proc/force_helm(mob/living/human/H, atom/at)
	if (!register || !register.party)
		return TRUE
	var/owner = party_train_party_name(register.party)
	if (WWinput(H, "The [name] belongs to [owner] and you are not one of [pro_hers] crew. Force the [helm_word]? It takes a while and [pro_hers] crew will hear of it.", papers_title, "No", list("Yes", "No")) != "Yes")
		return FALSE
	if (QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1)
		return FALSE
	crew_message(SPAN_DANGER("<b>[H] is forcing the [at.name]!</b>"))
	log_game("[key_name(H)] forced the [helm_word] of the [name] ([owner]) at [at.x],[at.y],[at.z].")
	if (!do_after(H, VESSEL_FORCE_WHEEL_TIME, at))
		return FALSE
	// The owners may have left while the chain was being worked.
	return !QDELETED(src) && helm_access(H) != CRAFT_HELM_CHAINED

// The papers menu. Owners keep the crew list; others may ask to join.
/datum/craft/proc/papers(mob/living/human/H, atom/at)
	if (!istype(H) || QDELETED(at))
		return
	if (!register)
		register = new /datum/craft_register
		register.name = name
	var/datum/craft_register/R = register
	var/list/options = list()
	if (!R.party)
		var/mine = party_train_party_of(H)
		if (mine)
			options += "Register [pro_her] to [party_train_party_name(mine)]"
	else if (R.is_owner(H) || R.role_of(H) == CRAFT_ROLE_CAPTAIN)
		options += list("Sign on crew", "Change a role or strike off", "Bar someone", "Lift a bar", "Who may join", "Write the memo", "Give up the [kind_word]")
		if (R.requests.len)
			options += "Answer a request"
	else if (!R.is_crew(H) && !R.is_barred(H) && R.join_mode != CRAFT_JOIN_CLOSED)
		options += "Ask to join"
	options += papers_extra(H, R)
	var/text = R.summary_text(name, src)
	if (R.memo && R.is_crew(H))
		text += " Memo: [R.memo]"
	var/choice = WWinput(H, text, papers_title, "Close", options + list("Close"))
	if (!(choice in options) || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1 || register != R)
		return
	papers_action(H, R, choice, at)

/datum/craft/proc/papers_still_valid(mob/living/human/H, datum/craft_register/R, atom/at)
	return !QDELETED(src) && !QDELETED(at) && get_dist(H, at) <= 1 && register == R && (R.is_owner(H) || R.role_of(H) == CRAFT_ROLE_CAPTAIN)

/datum/craft/proc/papers_action(mob/living/human/H, datum/craft_register/R, choice, atom/at)
	if (papers_extra_action(H, R, choice, at))
		return
	if (findtext(choice, "Register ") == 1)
		if (R.claim(H))
			crew_message(SPAN_NOTICE("[H] enters the [name] in the register for [party_train_party_name(R.party)]."))
			log_game("[key_name(H)] registered the [name] at [at.x],[at.y],[at.z] to [R.party].")
		return
	if (choice == "Ask to join")
		if (!R.ask_to_join(H))
			to_chat(H, SPAN_WARNING("[capitalize(pro_she)] takes no new crew."))
		else if (R.is_crew(H))
			crew_message(SPAN_NOTICE("[H] signs on as a [role_title(CRAFT_ROLE_HAND)]."))
		else
			crew_message(SPAN_NOTICE("[H] asks to join the crew. An owner or the [role_title(CRAFT_ROLE_CAPTAIN)] can answer at the [helm_word]."))
		return
	if (!papers_still_valid(H, R, at))
		return
	if (choice == "Give up the [kind_word]")
		choice = "Give up"
	var/list/titles = role_titles(R)
	switch (choice)
		if ("Sign on crew")
			var/list/near = list()
			for (var/mob/living/human/M in view(3, at))
				if (M != H && M.stat != DEAD && !R.is_barred(M) && isnull(R.crew[M.real_name]))
					near[M.real_name] = M
			if (!near.len)
				to_chat(H, SPAN_WARNING("Nobody who could sign on is near the [helm_word]."))
				return
			var/who = WWinput(H, "Who signs on?", papers_title, "Cancel", sortList(near) + list("Cancel"))
			if (!(who in near) || !papers_still_valid(H, R, at))
				return
			var/role = WWinput(H, "As what? A [role_title(CRAFT_ROLE_CAPTAIN)] keeps the papers; a [role_title(CRAFT_ROLE_CAPTAIN)] or [role_title(CRAFT_ROLE_HELMSMAN)] may take the [helm_word].", papers_title, role_title(CRAFT_ROLE_HAND), titles)
			if (isnull(titles[role]) || !papers_still_valid(H, R, at))
				return
			R.set_role(who, titles[role])
			crew_message(SPAN_NOTICE("[who] signs on as [role]."))
		if ("Change a role or strike off")
			if (!R.crew.len)
				to_chat(H, SPAN_WARNING("No crew are listed."))
				return
			var/who = WWinput(H, "Whose entry?", papers_title, "Cancel", R.crew + list("Cancel"))
			if (isnull(R.crew[who]) || !papers_still_valid(H, R, at))
				return
			var/role = WWinput(H, "[who] is [role_title(R.crew[who])].", papers_title, "Cancel", titles + list("Strike off", "Cancel"))
			if (!papers_still_valid(H, R, at))
				return
			if (role == "Strike off")
				R.set_role(who, null)
				crew_message(SPAN_NOTICE("[who] is struck off the crew list."))
			else if (!isnull(titles[role]))
				R.set_role(who, titles[role])
				crew_message(SPAN_NOTICE("[who] is now [role]."))
		if ("Answer a request")
			var/who = WWinput(H, "Whose request?", papers_title, "Cancel", R.requests + list("Cancel"))
			if (!(who in R.requests) || !papers_still_valid(H, R, at))
				return
			var/sign_on = "Sign on as a [role_title(CRAFT_ROLE_HAND)]"
			var/answer = WWinput(H, "[who] asks to join.", papers_title, "Cancel", list(sign_on, "Refuse", "Cancel"))
			if (!papers_still_valid(H, R, at))
				return
			if (answer == sign_on)
				R.set_role(who, CRAFT_ROLE_HAND)
				crew_message(SPAN_NOTICE("[who] signs on as a [role_title(CRAFT_ROLE_HAND)]."))
			else if (answer == "Refuse")
				R.requests -= who
		if ("Bar someone")
			var/list/names = R.crew.Copy() | R.requests
			for (var/mob/living/human/M in view(7, at))
				if (M != H && !R.is_owner(M))
					names |= M.real_name
			names -= H.real_name
			if (!names.len)
				to_chat(H, SPAN_WARNING("There is nobody here to bar."))
				return
			var/who = WWinput(H, "Bar whom? They leave the crew and cannot ask to join.", papers_title, "Cancel", sortList(names) + list("Cancel"))
			if (!(who in names) || !papers_still_valid(H, R, at))
				return
			R.bar(who)
			crew_message(SPAN_NOTICE("[who] is barred from the [name]."))
		if ("Lift a bar")
			if (!R.barred.len)
				to_chat(H, SPAN_WARNING("Nobody is barred."))
				return
			var/who = WWinput(H, "Lift whose bar?", papers_title, "Cancel", R.barred + list("Cancel"))
			if (!(who in R.barred) || !papers_still_valid(H, R, at))
				return
			R.barred -= who
		if ("Who may join")
			var/list/modes = list("Anyone may sign on as a [role_title(CRAFT_ROLE_HAND)]" = CRAFT_JOIN_OPEN, "New crew must ask" = CRAFT_JOIN_ASK, "[capitalize(pro_she)] takes no new crew" = CRAFT_JOIN_CLOSED)
			var/mode = WWinput(H, "How does [pro_she] take new crew?", papers_title, "Cancel", modes + list("Cancel"))
			if (isnull(modes[mode]) || !papers_still_valid(H, R, at))
				return
			R.join_mode = modes[mode]
		if ("Write the memo")
			var/memo = player_input(H, "A note every member of the crew can read in the papers.", papers_title, R.memo, "text", null, TRUE)
			if (isnull(memo) || !papers_still_valid(H, R, at))
				return
			R.memo = sanitize(copytext(memo, 1, 300))
		if ("Give up")
			if (!R.is_owner(H))
				to_chat(H, SPAN_WARNING("Only [pro_hers] owners can give [pro_her] up."))
				return
			if (WWinput(H, "Strike the [name] from the register? Anyone may then [sail_word] or register [pro_her].", papers_title, "No", list("Yes", "No")) != "Yes" || !papers_still_valid(H, R, at))
				return
			log_game("[key_name(H)] gave up the [name] ([R.party]) at [at.x],[at.y],[at.z].")
			R.give_up()
			crew_message(SPAN_NOTICE("[H] strikes the [name] from the register."))
