// ============================================================
// The dead wait as spirits on persistent worlds.
// ------------------------------------------------------------
// Dying on a persistent world binds the player to their body as a spirit:
// Respawn is locked and their ghost stays within reach of the body (the same
// leash as Linger, code/modules/divine/arcane_spirits.dm). They are freed when
// the body is gone (it decays, is gibbed or destroyed), when they are brought
// back, or SPIRIT_MOVE_ON_TIME of real time after they choose to move on.
// Staff free them with "Allow player to respawn".
//
// Anyone living may kneel beside a body whose spirit is still bound and pray
// for them. The prayer reaches staff who hear prayers; on Grant the body is
// mended just enough to live and the spirit goes back into it.
//
// Runtime only: a restart frees every spirit.
// ============================================================

#define SPIRIT_MOVE_ON_TIME 3000      // deciseconds of real time: 5 minutes
#define SPIRIT_PRAY_TIME 300          // deciseconds kneeling beside the body
#define SPIRIT_PRAY_COOLDOWN 3000     // deciseconds of real time between prayers over one body
#define SPIRIT_PRAYER_LIFETIME 6000   // deciseconds a prayer waits for an answer

// ckey -> list("body" = the dead body, "until" = world.realtime when moving on ends, or 0)
var/global/list/spirit_bindings = list()
var/global/list/datum/spirit_revival_prayer/spirit_revival_prayers = list()

/mob/observer/ghost
	var/tmp/spirit_leashed = FALSE    // the anchor is the bound body, not a chosen Linger

/mob/living/human
	var/tmp/spirit_prayed_at = 0      // world.realtime of the last prayer over this body

// Called from death() while the player is still in the body.
/proc/spirit_bind(mob/living/human/H)
	if (!istype(H) || !H.ckey || !map || !map.persistence)
		return
	spirit_bindings[H.ckey] = list("body" = H, "until" = 0)
	to_chat(H, "<span class='notice'><b>Your spirit stays with your body for now.</b> The living may bring you back or pray for you. When you are ready, use Respawn to start moving on.</span>")

/proc/spirit_release(ckey)
	if (ckey)
		spirit_bindings -= ckey

// The binding still holding this player, or null once they are free.
/proc/spirit_binding(ckey)
	if (!ckey)
		return null
	var/list/B = spirit_bindings[ckey]
	if (!islist(B))
		return null
	var/mob/living/human/body = B["body"]
	var/until = B["until"]
	if (!istype(body) || QDELETED(body) || body.stat != DEAD || (until && (world.realtime >= until || world.realtime < until - SPIRIT_MOVE_ON_TIME)))
		spirit_bindings -= ckey
		return null
	return B

// Where a bound spirit is held: the grave its body lies in, or the body.
/proc/spirit_anchor_of(mob/body)
	if (!body || QDELETED(body))
		return null
	for (var/atom/A = body.loc, A && !isturf(A), A = A.loc)
		if (istype(A, /obj/structure/religious/grave))
			return get_turf(A)
	return get_turf(body)

// Called from ghostize(): a bound spirit's ghost starts at the body and stays near it.
/mob/observer/ghost/proc/spirit_leash()
	var/list/B = spirit_binding(ckey)
	if (!B)
		return
	var/turf/T = spirit_anchor_of(B["body"])
	if (!T)
		return
	arcane_anchor = T
	spirit_leashed = TRUE

// Keeps the leash on the body as it is carried about; drops it once free.
/mob/observer/ghost/proc/spirit_refresh_leash()
	if (!spirit_leashed)
		return
	var/list/B = spirit_binding(ckey)
	var/turf/T = B ? spirit_anchor_of(B["body"]) : null
	if (T)
		arcane_anchor = T
	else
		spirit_leashed = FALSE
		arcane_anchor = null

// Called from Respawn. TRUE when the player is still bound and must wait.
/mob/proc/spirit_wait_blocks()
	var/list/B = spirit_binding(ckey)
	if (!B)
		return FALSE
	var/until = B["until"]
	if (until)
		to_chat(src, SPAN_NOTICE("You are moving on. [time2text(until - world.realtime, "mm:ss")] left."))
		return TRUE
	if (player_alert(src, "Your spirit is still bound to your body. The living may yet bring you back or pray for you. Move on? It takes 5 minutes, and then you can respawn.", "Move on", list("Move on", "Stay")) != "Move on")
		return TRUE
	B = spirit_binding(ckey)
	if (!B || B["until"])
		return !!B
	B["until"] = world.realtime + SPIRIT_MOVE_ON_TIME
	to_chat(src, SPAN_NOTICE("You begin to let go. In 5 minutes you can respawn."))
	log_game("[key_name(src)] began moving on.")
	var/who = ckey
	spawn(SPIRIT_MOVE_ON_TIME + 10)
		if (!spirit_binding(who))
			var/client/C = directory[who]
			if (C && C.mob && C.mob.stat == DEAD)
				to_chat(C.mob, "<span class='good'>You have moved on. <a href='?src=\ref[C.mob];respawn=1'>Respawn</a></span>")
	return TRUE

// ---- Praying for the dead ----------------------------------------------------

/datum/spirit_revival_prayer
	should_save = FALSE
	var/mob/living/human/prayer
	var/mob/living/human/body
	var/spirit_ckey
	var/expires_at = 0

/datum/spirit_revival_prayer/New(mob/living/human/P, mob/living/human/B, ckey)
	..()
	prayer = P
	body = B
	spirit_ckey = ckey
	expires_at = world.time + SPIRIT_PRAYER_LIFETIME
	spirit_revival_prayers += src

/datum/spirit_revival_prayer/Destroy()
	spirit_revival_prayers -= src
	prayer = null
	body = null
	return ..()

/datum/spirit_revival_prayer/proc/current()
	if (world.time > expires_at || !body || QDELETED(body) || body.stat != DEAD)
		return FALSE
	var/list/B = spirit_binding(spirit_ckey)
	return B && B["body"] == body

/datum/spirit_revival_prayer/proc/alert_staff()
	var/link = "<a href='?src=\ref[src];spirit_grant=1'>Grant</a> | <a href='?src=\ref[src];spirit_refuse=1'>Refuse</a>"
	var/note = "<span class='notice'><b><font color=purple>PRAYER FOR THE DEAD:</font> [key_name(prayer, TRUE)]</b> prays over the body of [body.real_name] ([spirit_ckey]), whose spirit is still bound, asking for them to be revived. [link]</span>"
	for (var/client/C in prayer_hearers())
		to_chat(C, CHAT_TYPED(CHAT_PRAYER, note))

/datum/spirit_revival_prayer/Topic(href, href_list)
	if (!usr || !usr.client || !check_rights(R_ADMIN, TRUE, usr))
		return
	if (!(src in spirit_revival_prayers))
		to_chat(usr, SPAN_WARNING("That prayer has already been answered."))
		return
	if (href_list["spirit_refuse"])
		log_admin("[key_name(usr)] refused a prayer by [key_name(prayer)] to revive [spirit_ckey].")
		to_chat(usr, SPAN_NOTICE("You let the prayer go unanswered."))
		qdel(src)
		return
	if (!href_list["spirit_grant"])
		return
	if (!current())
		to_chat(usr, SPAN_WARNING("It is too late: the body is gone, already living, or the spirit has moved on."))
		qdel(src)
		return
	var/mob/living/human/H = body
	var/list/entry = divine_identity_of(usr.ckey)
	var/god = entry ? divine_identity_label(entry) : "the gods"
	if (!H.spirit_divine_revive())
		to_chat(usr, SPAN_WARNING("[H.real_name]'s body can't be brought back: it has no head."))
		qdel(src)
		return
	spirit_release(spirit_ckey)
	if (prayer && !QDELETED(prayer))
		to_chat(prayer, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("<i>Your prayer is answered.</i>")))
	to_chat(H, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("<i>You are called back to your body.</i>")))
	to_chat(usr, SPAN_NOTICE("You brought [H.real_name] back as [god]."))
	log_admin("[key_name(usr)] as [god] granted a prayer by [key_name(prayer)] and revived [key_name(H)].")
	qdel(src)

// Mends the body just enough to live and puts the spirit back. Time and rot
// do not stop a god; a missing head does.
/mob/living/human/proc/spirit_divine_revive()
	if (stat != DEAD || QDELETED(src))
		return FALSE
	var/obj/item/organ/external/head = organs_by_name["head"]
	if (!head || (head.status & ORGAN_DESTROYED))
		return FALSE
	rotting_stage = 0
	revival_clock = max(world.time, 1)
	for (var/obj/item/organ/O in internal_organs)
		O.status &= ~ORGAN_DEAD
		O.damage = min(O.damage, O.max_damage / 2)
	setBrainLoss(min(getBrainLoss(), 40))
	for (var/datum/reagents/R in list(reagents, ingested))
		R.clear_reagents()
	adjustToxLoss(-getToxLoss())
	restore_blood()
	updatehealth()
	var/short = config.health_threshold_dead + 15 - (health + getOxyLoss())
	if (short > 0)
		heal_overall_damage(short, short)
	if (resuscitation_blocker() || !restart_from_death(null))
		rejuvenate() // whatever is left, a god can mend
		return_revived_spirit()
	return TRUE

/mob/living/human/verb/spirit_pray_for()
	set name = "Pray for Them"
	set category = null
	set src in oview(1)
	var/mob/living/human/P = usr
	if (!istype(P) || P == src || P.stat != CONSCIOUS || P.incapacitated() || stat != DEAD)
		return
	var/list/B = spirit_binding(revival_ckey)
	if (!B || B["body"] != src)
		to_chat(P, SPAN_WARNING("[src]'s spirit is no longer here to pray for."))
		return
	if (spirit_prayed_at && world.realtime < spirit_prayed_at + SPIRIT_PRAY_COOLDOWN && world.realtime >= spirit_prayed_at)
		to_chat(P, SPAN_WARNING("Someone has prayed over [src] only just now."))
		return
	P.visible_message("<span class='notice'>[P] kneels beside [src] and prays.</span>", "<span class='notice'>You kneel beside [src] and pray for them.</span>")
	var/datum/spirit_revival_prayer/old = null
	for (var/datum/spirit_revival_prayer/R in spirit_revival_prayers)
		if (R.body == src)
			old = R
	if (old && old.current())
		to_chat(P, SPAN_NOTICE("A prayer for [src] is already waiting on an answer."))
		return
	if (!do_after(P, SPIRIT_PRAY_TIME, src, needhand = FALSE))
		return
	B = spirit_binding(revival_ckey)
	if (!B || B["body"] != src || stat != DEAD || (spirit_prayed_at && world.realtime < spirit_prayed_at + SPIRIT_PRAY_COOLDOWN && world.realtime >= spirit_prayed_at))
		return
	spirit_prayed_at = world.realtime
	var/mob/observer/ghost/G = revival_ghost()
	if (G)
		to_chat(G, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("<i>[P.real_name] prays for you to return.</i>")))
	log_game("[key_name(P)] prayed over [key_name(src)] ([revival_ckey]) for revival.")
	if (!length(prayer_hearers()))
		to_chat(P, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You finish your prayer. Nothing answers.")))
		return
	var/datum/spirit_revival_prayer/R = new(P, src, revival_ckey)
	R.alert_staff()
	to_chat(P, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You finish your prayer.")))
	var/datum/spirit_revival_prayer/watched = R
	spawn(SPIRIT_PRAYER_LIFETIME + 5)
		if (watched && (watched in spirit_revival_prayers))
			qdel(watched)

#undef SPIRIT_MOVE_ON_TIME
#undef SPIRIT_PRAY_TIME
#undef SPIRIT_PRAY_COOLDOWN
#undef SPIRIT_PRAYER_LIFETIME
