// ============================================================
// Divine Sight: how gods observe. Hidden mechanic: keep it out of changelog
// lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// Players observe as spirits (spirit_observe.dm). Staff playing a god use
// Divine Sight instead: their ghost (an admin ghost when they leave a body)
// becomes a divine presence named for their divine identity, with its own
// panel gathering what a god answers - Beseech requests for the god they
// speak as, prayers over the dead, their followers and the spirits still
// bound to bodies - and three abilities: Manifest, Whisper and the Divine
// Patron menu. Every action is checked against admin rights and logged.
// ============================================================

#define DIVINE_SIGHT_WINDOW "divine_sight"
#define DIVINE_MANIFEST_TIME 300   // deciseconds a manifestation lasts

/mob/observer/ghost
	var/tmp/divine_sight = FALSE
	var/tmp/divine_saved_name = null
	var/tmp/divine_manifest_until = 0

var/global/list/divine_sight_verbs = list(
	/mob/observer/ghost/proc/divine_sight_panel,
	/mob/observer/ghost/proc/divine_manifest,
	/mob/observer/ghost/proc/divine_whisper,
	/mob/observer/ghost/proc/divine_patron_menu,
	/mob/observer/ghost/proc/divine_lift_sleep_protection,
	/mob/observer/ghost/proc/divine_sight_leave,
)

/client/proc/divine_sight()
	set category = "Admin"
	set name = "Divine Sight"
	set desc = "Watch the world as your god: prayers, followers and bound spirits in one panel."
	if (!check_rights(R_ADMIN))
		return
	if (isghost(mob))
		var/mob/observer/ghost/G = mob
		if (G.divine_sight)
			G.divine_sight_panel()
			return
	if (istype(mob, /mob/new_player))
		to_chat(src, SPAN_WARNING("Join or Observe first."))
		return
	var/list/entry = divine_identity_of(ckey)
	if (!entry)
		entry = divine_edit_identity()
	if (!entry)
		return
	if (!isghost(mob))
		admin_ghost()
	var/mob/observer/ghost/G = mob
	if (!istype(G))
		return
	G.divine_sight_start(entry)

/mob/observer/ghost/proc/divine_sight_start(list/entry)
	if (divine_sight || !client)
		return
	divine_sight = TRUE
	divine_saved_name = name
	name = divine_identity_label(entry)
	real_name = name
	verbs |= divine_sight_verbs
	if (!seedarkness)
		updateghostsight()
	to_chat(src, "<span class='notice'><b>You look upon the world as [name].</b> The Divine tab holds your panel, Manifest and Whisper.</span>")
	log_admin("[key_name(src)] took up Divine Sight as [name].")
	divine_sight_panel()

/mob/observer/ghost/proc/divine_sight_stop()
	if (!divine_sight)
		return
	divine_end_manifest()
	divine_sight = FALSE
	verbs -= divine_sight_verbs
	if (divine_saved_name)
		name = divine_saved_name
		real_name = divine_saved_name
	divine_saved_name = null
	if (client)
		show_browse(client, null, "window=[DIVINE_SIGHT_WINDOW]")
	log_admin("[key_name(src)] left Divine Sight.")

/mob/observer/ghost/proc/divine_sight_leave()
	set category = "Divine"
	set name = "Leave Divine Sight"
	divine_sight_stop()
	to_chat(src, SPAN_NOTICE("You set Divine Sight aside. Re-enter Corpse returns you to your body."))

/mob/observer/ghost/proc/divine_allowed()
	if (!divine_sight || !client || !check_rights(R_ADMIN, FALSE, src))
		divine_sight_stop()
		return FALSE
	return TRUE

// ---- What the panel shows ------------------------------------------------------

/mob/observer/ghost/proc/divine_go_link(atom/A, text = "Go")
	return A ? "<a href='?src=\ref[src];divine_go=\ref[A]'>[text]</a>" : ""

/mob/observer/ghost/proc/divine_place(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return "nowhere"
	var/area/R = get_area(T)
	return "[R ? R.name : "the wilds"] ([T.x], [T.y], [T.z])"

/mob/observer/ghost/proc/divine_panel_data()
	var/claim = divine_claim_of(client)
	. = list()
	.["label"] = name
	.["claim"] = claim ? divine_label_for(claim) : null
	var/list/requests = list()
	for (var/datum/divine_use_request/R in divine_pending_requests)
		if (!claim || !R.covenant || R.covenant.deity_id != claim)
			continue
		var/mob/caster = R.covenant.caster
		if (!caster)
			continue
		var/mob/target = R.target
		requests += list(list(
			"who" = "[caster.real_name] ([caster.ckey ? caster.ckey : "no player"])",
			"what" = divine_invocation_names[R.spell_id],
			"detail" = (ismob(target) && target != caster) ? "on [target.real_name]" : "",
			"state" = R.state,
			"grant" = R.state == "requested" ? "?src=\ref[R];divine_answer=approve" : null,
			"refuse" = R.state == "requested" ? "?src=\ref[R];divine_answer=deny" : null,
			"go" = "?src=\ref[src];divine_go=\ref[caster]"))
	.["requests"] = requests
	var/list/revivals = list()
	for (var/datum/spirit_revival_prayer/P in spirit_revival_prayers)
		if (!P.current())
			continue
		revivals += list(list(
			"who" = P.prayer ? P.prayer.real_name : "someone",
			"for" = "[P.body.real_name] ([P.spirit_ckey])",
			"grant" = "?src=\ref[P];spirit_grant=1",
			"refuse" = "?src=\ref[P];spirit_refuse=1",
			"go" = "?src=\ref[src];divine_go=\ref[P.body]"))
	.["revivals"] = revivals
	var/list/followers = list()
	if (claim)
		for (var/mob/living/human/H in human_mob_list)
			if (QDELETED(H) || divine_book_key(H.divine_patron) != claim)
				continue
			followers += list(list(
				"name" = H.real_name,
				"status" = H.stat == DEAD ? "dead" : (H.client ? "awake" : "away"),
				"place" = divine_place(H),
				"go" = "?src=\ref[src];divine_go=\ref[H]",
				"haunt" = "?src=\ref[src];divine_haunt=\ref[H]"))
	.["followers"] = followers
	var/list/spirits = list()
	for (var/who in spirit_bindings)
		var/list/B = spirit_binding(who)
		if (!B)
			continue
		var/mob/body = B["body"]
		var/until = B["until"]
		spirits += list(list(
			"name" = body.real_name,
			"ckey" = who,
			"left" = until ? "moving on, [time2text(until - world.realtime, "mm:ss")] left" : "waiting",
			"go" = "?src=\ref[src];divine_go=\ref[body]",
			"release" = "?src=\ref[src];divine_release=[url_encode(who)]"))
	.["spirits"] = spirits
	.["actions"] = list(
		list("label" = "Manifest", "href" = "?src=\ref[src];divine_act=manifest"),
		list("label" = "Whisper", "href" = "?src=\ref[src];divine_act=whisper"),
		list("label" = "Divine Patron", "href" = "?src=\ref[src];divine_act=patron"),
		list("label" = "Admin Map", "href" = "?src=\ref[src];divine_act=map"),
		list("label" = "Refresh", "href" = "?src=\ref[src];divine_act=refresh"))

/mob/observer/ghost/proc/divine_sight_panel()
	set category = "Divine"
	set name = "Divine Panel"
	if (!divine_allowed())
		return
	show_browse(client, divine_sight_panel_html(src, divine_panel_data()), "window=[DIVINE_SIGHT_WINDOW];size=560x680")

// Called from /mob/observer/ghost/Topic (ghost.dm). TRUE when handled.
/mob/observer/ghost/proc/divine_topic(list/href_list)
	if (!(href_list["divine_go"] || href_list["divine_haunt"] || href_list["divine_release"] || href_list["divine_act"]))
		return FALSE
	if (usr != src || !divine_allowed())
		return TRUE
	if (href_list["divine_go"] || href_list["divine_haunt"])
		var/atom/movable/A = locate(href_list["divine_go"] ? href_list["divine_go"] : href_list["divine_haunt"])
		if (!istype(A) || QDELETED(A))
			return TRUE
		stop_following()
		if (href_list["divine_haunt"])
			ManualFollow(A)
		else
			forceMove(get_turf(A))
		return TRUE
	if (href_list["divine_release"])
		var/who = href_list["divine_release"]
		if (!spirit_binding(who))
			to_chat(src, SPAN_WARNING("That spirit is already free."))
		else
			spirit_release(who)
			var/client/C = directory[who]
			if (C && C.mob)
				to_chat(C.mob, "<span class='good'>You feel your spirit let go of your body. <a href='?src=\ref[C.mob];respawn=1'>Respawn</a></span>")
			log_admin("[key_name(src)] as [name] released the spirit of [who].")
		divine_sight_panel()
		return TRUE
	switch (href_list["divine_act"])
		if ("manifest")
			divine_manifest()
		if ("whisper")
			divine_whisper()
		if ("patron")
			divine_patron_menu()
		if ("map")
			client.admin_map()
		else
			divine_sight_panel()
	return TRUE

// ---- Abilities ------------------------------------------------------------------

/mob/observer/ghost/proc/divine_manifest()
	set category = "Divine"
	set name = "Manifest"
	set desc = "Appear to the living around you for half a minute."
	if (!divine_allowed())
		return
	if (divine_manifest_until > world.time)
		divine_end_manifest()
		return
	var/words = sanitize(player_input(src, "What do the living see as you appear? Leave empty for a plain radiance.", "Manifest", null, "text", null, TRUE))
	if (!divine_allowed())
		return
	divine_manifest_until = world.time + DIVINE_MANIFEST_TIME
	invisibility = 0
	alpha = 255
	overlays += image('icons/mob/divine_presence.dmi', "radiance")
	visible_message("<span class='notice'><b>[name]</b> appears in a soft radiance.[words ? " [words]" : ""]</span>")
	log_admin("[key_name(src)] manifested as [name] at [x], [y], [z][words ? ": [words]" : ""].")
	addtimer(CALLBACK(src, PROC_REF(divine_manifest_timeout), divine_manifest_until), DIVINE_MANIFEST_TIME)

/mob/observer/ghost/proc/divine_manifest_timeout(until)
	if (divine_manifest_until == until)
		divine_end_manifest()

/mob/observer/ghost/proc/divine_end_manifest()
	if (!divine_manifest_until)
		return
	divine_manifest_until = 0
	overlays -= image('icons/mob/divine_presence.dmi', "radiance")
	invisibility = initial(invisibility)
	alpha = 127
	if (admin_hidden)
		set_admin_hidden(TRUE)
	visible_message("<span class='notice'>The radiance fades.</span>")

/mob/observer/ghost/proc/divine_whisper()
	set category = "Divine"
	set name = "Whisper"
	set desc = "Speak to one living person alone, as your god."
	if (!divine_allowed())
		return
	var/claim = divine_claim_of(client)
	var/list/choices = list()
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H) || H.stat == DEAD || !H.client)
			continue
		if ((claim && divine_book_key(H.divine_patron) == claim) || (H in view(world.view, src)))
			choices["[H.real_name] ([H.ckey])"] = H
	if (!choices.len)
		to_chat(src, SPAN_WARNING("No follower is awake and nobody living is near you."))
		return
	var/picked = player_input(src, "Whisper to whom? Your followers and anyone near you.", "Whisper", null, "anything", sortList(choices), TRUE)
	var/mob/living/human/H = choices[picked]
	if (!H)
		return
	var/msg = sanitize(player_input(src, "What do you whisper to [H.real_name]?", "Whisper", null, "text", null, TRUE))
	if (!msg || !divine_allowed() || QDELETED(H))
		return
	to_chat(H, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><i>[name] whispers: [msg]</i></span>"))
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You whisper to [H.real_name]: [msg]")))
	log_admin("[key_name(src)] as [name] whispered to [key_name(H)]: [msg]")

/mob/observer/ghost/proc/divine_patron_menu()
	set category = "Divine"
	set name = "Divine Patron"
	if (!divine_allowed())
		return
	client.cmd_admin_divine_patron() // divine_patron.dm

#undef DIVINE_SIGHT_WINDOW
#undef DIVINE_MANIFEST_TIME
