// ============================================================
// Spirits (magic materials and enchanting plan, PR 10). Hidden mechanic: keep
// it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A ghost may Linger. While it lingers it is anchored: it cannot move more
// than ARCANE_SPIRIT_RANGE tiles from its grave (if its body lies in one) or
// its body, and Jump to Mob and Follow stop working. After it stops it cannot
// linger again for an hour. A verified magic user can Commune (no god's
// click): every lingering spirit anchored within range is asked, in plain
// words, whether it answers, and the first to accept speaks to that magic
// user alone, as faint lines in the Prayer tab, for up to 10 minutes. One
// communion per rest. A food or drink left for the spirit during communion
// lets it give one small sign within its anchor range: a knock, or a chill
// felt by one living person. Spirits never deal damage, open locks or move
// items. Every communion, line and sign is logged with both ckeys.
// ============================================================

#define ARCANE_SPIRIT_RANGE 15
#define ARCANE_LINGER_COOLDOWN 36000        // deciseconds of real time: an hour
#define ARCANE_COMMUNE_TIME 6000            // deciseconds: 10 minutes
#define ARCANE_COMMUNE_REST_FALLBACK 36000  // real time after which a communion is ready again without sleep
#define ARCANE_SPIRIT_SIGN_RANGE 3

// ckey -> world.realtime when that ghost last stopped lingering. Runtime only.
var/global/list/arcane_linger_stopped = list()
var/global/list/datum/arcane_communion/arcane_communions = list()

/mob/observer/ghost
	var/tmp/turf/arcane_anchor = null   // set while lingering
	var/tmp/arcane_signs = 0            // small signs earned by offerings
	var/tmp/datum/arcane_communion/arcane_communion = null

/mob/living/human
	var/arcane_communed_at = 0          // saved: world.realtime of the last communion, 0 once rested
	var/tmp/datum/arcane_communion/arcane_communing = null

/datum/arcane_communion
	should_save = FALSE
	var/mob/living/human/living
	var/mob/observer/ghost/spirit
	var/turf/start
	var/ends_at = 0

/datum/arcane_communion/New(mob/living/human/H, mob/observer/ghost/G)
	..()
	living = H
	spirit = G
	start = get_turf(H)
	ends_at = world.time + ARCANE_COMMUNE_TIME
	H.arcane_communing = src
	G.arcane_communion = src
	G.verbs |= list(/mob/observer/ghost/proc/arcane_spirit_whisper, /mob/observer/ghost/proc/arcane_spirit_sign, /mob/observer/ghost/proc/arcane_spirit_end)
	arcane_communions += src
	log_admin("Communion: [key_name(H)] communes with the spirit [key_name(G)].")

/datum/arcane_communion/proc/current()
	if (!living || QDELETED(living) || !spirit || QDELETED(spirit) || !spirit.client || !living.client)
		return FALSE
	if (world.time > ends_at || !spirit.arcane_anchor || living.stat != CONSCIOUS)
		return FALSE
	var/turf/T = get_turf(living)
	return T && start && T.z == start.z && get_dist(T, start) <= 1

/datum/arcane_communion/proc/finish(why)
	if (!(src in arcane_communions))
		return
	arcane_communions -= src
	if (living)
		if (living.arcane_communing == src)
			living.arcane_communing = null
		to_chat(living, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("<i>The presence fades.</i>")))
	if (spirit)
		if (spirit.arcane_communion == src)
			spirit.arcane_communion = null
		spirit.verbs -= list(/mob/observer/ghost/proc/arcane_spirit_whisper, /mob/observer/ghost/proc/arcane_spirit_sign, /mob/observer/ghost/proc/arcane_spirit_end)
		to_chat(spirit, SPAN_NOTICE("You drift away from the living."))
	log_admin("Communion ended ([why]): [key_name(living)] and the spirit [key_name(spirit)].")
	qdel(src)

/datum/arcane_communion/Destroy()
	arcane_communions -= src
	living = null
	spirit = null
	start = null
	return ..()

// ---- Lingering --------------------------------------------------------------

// Where this ghost is anchored: its grave if its body lies in one, otherwise its body.
/mob/observer/ghost/proc/arcane_find_anchor()
	var/mob/body = mind ? mind.current : null
	if (!body || QDELETED(body) || body.stat != DEAD)
		return null
	for (var/atom/A = body.loc, A && !isturf(A), A = A.loc)
		if (istype(A, /obj/structure/religious/grave))
			return get_turf(A)
	return get_turf(body)

/mob/observer/ghost/proc/arcane_in_anchor_range(atom/where)
	var/turf/T = get_turf(where)
	return T && arcane_anchor && T.z == arcane_anchor.z && get_dist(T, arcane_anchor) <= ARCANE_SPIRIT_RANGE

/mob/observer/ghost/verb/arcane_linger()
	set category = "Ghost"
	set name = "Linger"
	set desc = "Stay close to where your body lies, or stop."
	if (!client || admin_ghosted)
		return
	if (arcane_anchor)
		arcane_anchor = null
		arcane_linger_stopped[ckey] = world.realtime
		if (arcane_communion)
			arcane_communion.finish("the spirit stopped lingering")
		to_chat(src, SPAN_NOTICE("You let go and drift free. You can't linger again for an hour."))
		return
	var/stopped = arcane_linger_stopped[ckey]
	if (isnum(stopped) && world.realtime >= stopped && world.realtime < stopped + ARCANE_LINGER_COOLDOWN)
		to_chat(src, SPAN_WARNING("You can't hold on again yet."))
		return
	var/turf/anchor = arcane_find_anchor()
	if (!anchor)
		to_chat(src, SPAN_WARNING("Nothing of yours remains to hold onto."))
		return
	stop_following()
	arcane_anchor = anchor
	if (!arcane_in_anchor_range(src))
		forceMove(anchor)
	to_chat(src, SPAN_NOTICE("You linger near your remains. You can't wander far, and the living may call on you."))
	log_game("[key_name(src)] lingers as a spirit at [anchor.x], [anchor.y], [anchor.z].")

// A lingering ghost goes nowhere beyond its anchor's reach (incorporeal steps,
// Jump to Mob, Follow and level changes all move it through forceMove).
/mob/observer/ghost/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	if (arcane_anchor && destination && !arcane_in_anchor_range(destination))
		return FALSE
	return ..()

// ---- Communing ----------------------------------------------------------------

/mob/living/human/proc/arcane_commune_ready()
	if (!arcane_communed_at)
		return TRUE
	if (world.realtime >= arcane_communed_at + ARCANE_COMMUNE_REST_FALLBACK || world.realtime < arcane_communed_at)
		arcane_communed_at = 0
		return TRUE
	return FALSE

/mob/living/human/proc/arcane_spirits_near()
	. = list()
	var/turf/T = get_turf(src)
	if (!T)
		return
	for (var/mob/observer/ghost/G in player_list)
		if (G.client && G.arcane_anchor && !G.arcane_communion && G.arcane_in_anchor_range(T))
			. += G

/mob/living/human/proc/arcane_commune()
	set name = "Commune"
	set category = "IC"
	set desc = "Call on the dead nearby, end a communion, or leave something for a spirit."
	if (usr != src || !client || client.mob != src || !arcane_magic_user() || stat != CONSCIOUS)
		return
	if (arcane_communing)
		var/list/options = list("End the communion")
		var/obj/item/I = get_active_hand()
		if (istype(I, /obj/item/weapon/reagent_containers/food) && arcane_communing.spirit && get_dist(get_turf(src), arcane_communing.spirit.arcane_anchor) <= 1)
			options += "Leave [I.name] for the spirit"
		var/pick = player_input(src, "What do you do?", "Commune", null, "anything", options, TRUE)
		if (!pick || !arcane_communing)
			return
		if (pick == "End the communion")
			arcane_communing.finish("the living ended it")
			return
		var/datum/arcane_communion/C = arcane_communing
		if (I != get_active_hand() || QDELETED(I) || !C.current())
			return
		log_admin("Spirit offering: [key_name(src)] left [I] ([I.type]) for the spirit [key_name(C.spirit)].")
		qdel(I)
		C.spirit.arcane_signs = 1
		to_chat(src, SPAN_NOTICE("You set it down for the dead."))
		to_chat(C.spirit, SPAN_NOTICE("Something has been left for you. You could give the living one small sign."))
		return
	if (!verified_discord_id(ckey))
		to_chat(src, SPAN_WARNING("No one answers."))
		return
	if (!arcane_commune_ready())
		to_chat(src, SPAN_WARNING("You are too tired to call on the dead again. Rest first."))
		return
	var/list/spirits = arcane_spirits_near()
	if (!spirits.len)
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You call quietly, but nothing answers.")))
		return
	arcane_communed_at = world.realtime
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You still yourself and call quietly to the dead.")))
	log_game("[key_name(src)] calls on the dead ([spirits.len] lingering nearby).")
	var/list/answered = list()
	for (var/mob/observer/ghost/G in spirits)
		spawn(0)
			if (G && G.client && WWinput(G, "Someone among the living is calling to the dead. Will you answer?", "A call", "No", list("Yes", "No")) == "Yes")
				if (!answered.len)
					answered += G
	var/waited = 0
	while (!answered.len && waited < 300)
		sleep(10)
		waited += 10
	var/mob/observer/ghost/G = answered.len ? answered[1] : null
	if (!G || QDELETED(G) || !G.client || !G.arcane_anchor || G.arcane_communion || arcane_communing || !G.arcane_in_anchor_range(src) || QDELETED(src) || stat != CONSCIOUS)
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("Nothing answers.")))
		return
	new /datum/arcane_communion(src, G)
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("<i>You feel someone listening.</i>")))
	to_chat(G, SPAN_NOTICE("You answer. Only [real_name] can hear you now (Whisper to the Living). It lasts ten minutes at most."))
	var/datum/arcane_communion/C = arcane_communing
	spawn(0)
		while (C && (C in arcane_communions))
			if (!C.current())
				C.finish("time, distance or departure")
				break
			sleep(20)

// ---- What a spirit can do ----------------------------------------------------

/mob/observer/ghost/proc/arcane_spirit_whisper()
	set name = "Whisper to the Living"
	set category = "Ghost"
	var/datum/arcane_communion/C = arcane_communion
	if (!C || !C.current())
		return
	var/raw = player_input(src, "What do you say? Only [C.living.real_name] hears it.", "Whisper", null, "text", null, TRUE)
	var/words = raw ? sanitize(raw, MAX_MESSAGE_LEN) : null
	if (!words || arcane_communion != C || !C.current())
		return
	to_chat(C.living, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><i>A faint voice: \"[words]\"</i></span>"))
	to_chat(src, SPAN_NOTICE("You whisper: \"[words]\""))
	log_game("Spirit [key_name(src)] to [key_name(C.living)]: [words]")

/mob/observer/ghost/proc/arcane_spirit_sign()
	set name = "Give a Sign"
	set category = "Ghost"
	var/datum/arcane_communion/C = arcane_communion
	if (!C || !C.current() || arcane_signs < 1)
		to_chat(src, SPAN_WARNING("You have nothing to give a sign with."))
		return
	var/list/options = list()
	var/list/knockable = list()
	for (var/turf/T in range(ARCANE_SPIRIT_SIGN_RANGE, src))
		if (T.density && arcane_in_anchor_range(T))
			knockable += T
	for (var/obj/structure/S in range(ARCANE_SPIRIT_SIGN_RANGE, src))
		if (S.density && istype(S, /obj/structure/simple_door) && arcane_in_anchor_range(S))
			knockable += S
	if (knockable.len)
		options["Knock"] = "knock"
	var/list/people = list()
	for (var/mob/living/human/H in range(ARCANE_SPIRIT_SIGN_RANGE, src))
		if (H.stat == CONSCIOUS && H.client && arcane_in_anchor_range(H))
			people["[H.real_name]"] = H
	if (people.len)
		options["Send a chill"] = "chill"
	if (!options.len)
		to_chat(src, SPAN_WARNING("There is nothing near enough."))
		return
	var/pick = options[player_input(src, "What sign?", "Sign", null, "anything", options, TRUE)]
	if (!pick || arcane_communion != C || !C.current() || arcane_signs < 1)
		return
	if (pick == "knock")
		var/atom/A = pick(knockable)
		if (!A || QDELETED(A))
			return
		arcane_signs--
		playsound(get_turf(A), 'sound/effects/doorknock1.ogg', 50, TRUE)
		var/turf/T = get_turf(A)
		T.visible_message("<span class='notice'>Something knocks on \the [A].</span>")
		log_admin("Spirit sign: [key_name(src)] knocked at [T.x], [T.y], [T.z] for [key_name(C.living)].")
	else
		var/who = player_input(src, "Who feels it?", "Sign", null, "anything", people, TRUE)
		var/mob/living/human/H = people[who]
		if (!H || QDELETED(H) || arcane_communion != C || arcane_signs < 1 || !arcane_in_anchor_range(H))
			return
		arcane_signs--
		to_chat(H, SPAN_NOTICE("A sudden chill runs down your spine."))
		log_admin("Spirit sign: [key_name(src)] sent a chill to [key_name(H)] for [key_name(C.living)].")

/mob/observer/ghost/proc/arcane_spirit_end()
	set name = "End Communion"
	set category = "Ghost"
	if (arcane_communion)
		arcane_communion.finish("the spirit ended it")

#undef ARCANE_SPIRIT_RANGE
#undef ARCANE_LINGER_COOLDOWN
#undef ARCANE_COMMUNE_TIME
#undef ARCANE_COMMUNE_REST_FALLBACK
#undef ARCANE_SPIRIT_SIGN_RANGE
