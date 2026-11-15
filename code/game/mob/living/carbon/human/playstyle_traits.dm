// ============================================================
// Playstyle traits
// ------------------------------------------------------------
// Optional traits that suit a way of playing: the reclusive scholar, the
// intimidating bandit, the farmer, the quartermaster. Each costs 0 points
// because it carries its own drawback, a character may take only one (they
// exclude each other in trait_list), and none of them hinders other players:
// most drawbacks slow how fast a skill is learned rather than capping it.
// ============================================================

var/global/list/playstyle_trait_names = list("Recluse Scholar", "Menacing", "Hardened Fighter", "Quartermaster", "Green Thumb", "Tinkerer", "Wanderer", "Rallying Voice")
var/global/list/playstyle_combat_stats = list("rifle", "pistol", "bows", "machinegun", "swords", "throwing")

#define PLAYSTYLE_FAST_SKILL 1.5
#define PLAYSTYLE_SLOW_SKILL 0.75
#define RECLUSE_REACH 5
#define RECLUSE_ALONE_RATE 1.25
#define RECLUSE_COMPANY_RATE 0.8
#define RECLUSE_CROWD 3
#define INTIMIDATE_REACH 5
#define INTIMIDATE_COOLDOWN 300
#define INTIMIDATE_TARGET_COOLDOWN 1200
#define INTIMIDATE_MOOD 2
#define HARDENED_PAIN_MULT 0.85
#define QUARTERMASTER_DRAG_MULT 0.6
#define GREEN_THUMB_HARVEST_BONUS 0.1
#define WANDERER_FOOD_MULT 0.9
#define WANDERER_RECOVERY_MULT 1.5
#define WANDERER_MOVING_WINDOW 50
#define WANDERER_SETTLE_RANGE 20
#define WANDERER_SETTLE_TIME 27000
#define RALLY_REACH 7
#define RALLY_MOOD 1
#define RALLY_LISTENER_COOLDOWN 1200

/mob/living/human
	var/tmp/last_intimidate = -INTIMIDATE_COOLDOWN
	var/tmp/last_intimidated = -INTIMIDATE_TARGET_COOLDOWN
	var/tmp/last_rallied = -RALLY_LISTENER_COOLDOWN
	var/tmp/turf/wander_anchor = null
	var/tmp/wander_anchor_time = 0

// Runtime timers describe this process, not the saved body.
/mob/living/human/persistence_runtime_var(key)
	return key == "last_intimidate" || key == "last_intimidated" || key == "last_rallied" || key == "wander_anchor" || key == "wander_anchor_time" || ..()

// ------------------------------------------------------------
// Skill gain
// ------------------------------------------------------------

// Multiplier on stat training from adaptStat().
/mob/living/human/proc/trait_skill_gain_mult(statname)
	. = 1
	if (find_trait("Quick Learner"))
		. *= 1.15
	if (find_trait("Slow Learner"))
		. *= 0.85
	if (find_trait("Hardened Fighter"))
		if (statname == "swords")
			. *= PLAYSTYLE_FAST_SKILL
		else if (statname == "crafting")
			. *= PLAYSTYLE_SLOW_SKILL
	if (find_trait("Quartermaster") && (statname in playstyle_combat_stats))
		. *= PLAYSTYLE_SLOW_SKILL
	if (find_trait("Green Thumb"))
		if (statname == "farming")
			. *= PLAYSTYLE_FAST_SKILL
		else if (statname == "hunting" || (statname in playstyle_combat_stats))
			. *= PLAYSTYLE_SLOW_SKILL

// Multiplier on scholarship gained in a discipline.
/mob/living/human/proc/trait_scholarship_gain_mult(discipline)
	. = 1
	if (find_trait("Hardened Fighter"))
		. *= PLAYSTYLE_SLOW_SKILL
	if (find_trait("Tinkerer") && discipline == "engineering")
		. *= PLAYSTYLE_FAST_SKILL

// ------------------------------------------------------------
// Recluse Scholar
// ------------------------------------------------------------

// Study and research pace: faster alone, slower with company nearby.
/mob/living/human/proc/recluse_rate()
	if (!find_trait("Recluse Scholar"))
		return 1
	for (var/mob/living/human/H in range(RECLUSE_REACH, src))
		if (H != src && H.stat != DEAD)
			return RECLUSE_COMPANY_RATE
	return RECLUSE_ALONE_RATE

// ------------------------------------------------------------
// Menacing
// ------------------------------------------------------------

/mob/living/human/proc/intimidate_problem()
	if (!find_trait("Menacing"))
		return "You don't have the presence to pull that off."
	if (stat != CONSCIOUS || incapacitated())
		return "You can't do that right now."
	if (world.time < last_intimidate + INTIMIDATE_COOLDOWN)
		return "You need a moment before you can glare like that again."
	return null

/mob/living/human/proc/intimidate_targets()
	. = list()
	for (var/mob/living/human/H in view(INTIMIDATE_REACH, src))
		if (H != src && H.stat == CONSCIOUS)
			. += H

/mob/living/human/verb/intimidate()
	set name = "Intimidate"
	set category = "IC"
	set desc = "Make it clear to someone that you mean business."
	var/problem = intimidate_problem()
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/list/targets = intimidate_targets()
	if (!targets.len)
		to_chat(src, SPAN_WARNING("There is nobody close enough to intimidate."))
		return
	var/mob/living/human/T = player_input(src, "Who do you want to intimidate?", "Intimidate", null, "anything", targets, TRUE)
	if (!T || intimidate_problem() || !(T in intimidate_targets()))
		return
	do_intimidate(T)

/mob/living/human/proc/do_intimidate(mob/living/human/T)
	last_intimidate = world.time
	visible_message(SPAN_WARNING("[src] fixes [T] with a menacing stare."), SPAN_WARNING("You fix [T] with a menacing stare."))
	// Only someone who can see it feels it, and only once in a while.
	if (!T.find_trait("Blind") && !T.blinded && (src in view(T)))
		to_chat(T, SPAN_DANGER("[src] makes it very clear that they mean business."))
		if (world.time >= T.last_intimidated + INTIMIDATE_TARGET_COOLDOWN)
			T.last_intimidated = world.time
			T.adjust_mood(-INTIMIDATE_MOOD, "being threatened")
	for (var/mob/living/simple_animal/A in view(INTIMIDATE_REACH, src))
		A.startle_from(src)

// Wild grazing animals bolt from a menacing glare; led, ridden or fighting
// animals hold their ground.
/mob/living/simple_animal/proc/startle_from(mob/living/human/M)
	if (!herbivore || stat != CONSCIOUS || following_mob || istype(src, /mob/living/simple_animal/horse) || behaviour == "hostile")
		return FALSE
	if (npc_subtile_flee_enabled && npc_subtile_enabled)
		var/list/flee_receipt = list()
		if (npc_subtile_start_flee(M, 7, npc_subtile_native_interval(2), flee_receipt))
			var/list/flee_ticket = flee_receipt["ticket"]
			var/flee_remaining = max(0, flee_ticket["expires_at"] - world.time)
			addtimer(CALLBACK(src, PROC_REF(npc_subtile_stop_flee_ticket), flee_ticket), max(1, flee_remaining))
			return TRUE
	else if (npc_subtile_enabled || npc_subtile_continuous_legacy_ready("flee"))
		walk_away_od(src, M, 7, 2)
		addtimer(CALLBACK(src, PROC_REF(stop_startled_walk)), 50)
		return TRUE
	return FALSE

/mob/living/simple_animal/proc/stop_startled_walk()
	walk(src, 0)

// ------------------------------------------------------------
// Hardened Fighter, Quartermaster, Green Thumb, Tinkerer
// ------------------------------------------------------------

/mob/living/human/proc/trait_pain_mult()
	. = 1
	if (find_trait("Hardened Fighter") || find_trait("Thick Skinned"))
		. *= HARDENED_PAIN_MULT
	if (find_trait("Low Pain Tolerance"))
		. *= 1.2

// Scales how much pulling something slows the puller.
/mob/proc/pull_drag_mult()
	. = 1
	if (find_trait("Quartermaster"))
		. *= QUARTERMASTER_DRAG_MULT
	if (find_trait("Strong Back"))
		. *= 0.8
	if (find_trait("Bad Back"))
		. *= 1.25

// Time to study a research chapter.
/mob/living/human/proc/trait_study_time_mult()
	. = 1
	if (find_trait("Bookworm"))
		. *= 0.85
	if (find_trait("Dyslexic"))
		. *= 1.25

// Mood lost to a gruesome sight.
/mob/living/human/proc/trait_gore_mood_mult()
	return find_trait("Squeamish") ? 2 : 1

// Included after human_needs.dm, so this wraps the ordinary adjust_mood().
/mob/living/human/adjust_mood(amount, cause = null)
	if (amount < 0 && cause == "seeing someone maimed")
		amount *= trait_gore_mood_mult()
	return ..(amount, cause)

/mob/living/human/proc/trait_harvest_bonus(statname)
	return (statname == "farming" && find_trait("Green Thumb")) ? GREEN_THUMB_HARVEST_BONUS : 0

// Quartermasters count what is in a closed crate at a glance.
/obj/structure/closet/proc/quartermaster_count(mob/user)
	if (opened || !ishuman(user) || !user.find_trait("Quartermaster"))
		return
	var/count = 0
	for (var/obj/item/I in contents)
		if (!I.anchored)
			count++
	if (count)
		to_chat(user, SPAN_NOTICE("By your count it holds [count] item[count == 1 ? "" : "s"]."))

// ------------------------------------------------------------
// Wanderer
// ------------------------------------------------------------

/mob/living/human/proc/trait_food_mult()
	. = 1
	if (find_trait("Wanderer"))
		. *= WANDERER_FOOD_MULT
	if (find_trait("Light Eater"))
		. *= 0.85
	if (find_trait("Glutton"))
		. *= 1.2

/mob/living/human/proc/trait_stamina_recovery_mult()
	. = 1
	if (find_trait("Wanderer") && last_movement >= 0 && world.time - last_movement <= WANDERER_MOVING_WINDOW)
		. *= WANDERER_RECOVERY_MULT
	if (find_trait("Deep Lungs"))
		. *= 1.25
	if (find_trait("Asthmatic"))
		. *= 0.75

// Runs right after the ordinary recovery (diet_recover_stamina, 2% a tick) and
// adds or takes back the difference, so the total runs at the multiplied rate.
// A slower recovery never drains a full or empty bar.
/mob/living/human/proc/wanderer_recover_stamina()
	var/extra = trait_stamina_recovery_mult() - 1
	if (!extra || !islist(stats["stamina"]))
		return
	var/cap = diet_stamina_cap()
	var/current = stats["stamina"][1]
	if (current >= cap || current <= 0)
		return
	stats["stamina"][1] = clamp(current + stats["stamina"][2] * 0.02 * diet_recovery_factor() * extra, 0, cap)

// Restless feet: staying around one spot for a long while wears on the mood.
/mob/living/human/proc/handle_wanderer()
	var/turf/T = get_turf(src)
	if (!T)
		return
	if (!wander_anchor || wander_anchor.z != T.z || get_dist(wander_anchor, T) > WANDERER_SETTLE_RANGE)
		wander_anchor = T
		wander_anchor_time = world.time
		return
	if (world.time - wander_anchor_time >= WANDERER_SETTLE_TIME && prob(20))
		adjust_mood(-0.2, "staying in one place")

// ------------------------------------------------------------
// Rallying Voice
// ------------------------------------------------------------

// Included after say.dm, so this wraps the ordinary human say().
/mob/living/human/say(var/message, var/howling = FALSE)
	. = ..()
	if (istext(message) && dd_hassuffix(trim(message), "!") && !werewolf && !gorillaman)
		rally_shout()

// A shout lifts the spirits of friendly people who hear it.
/mob/living/human/proc/rally_shout()
	if (!find_trait("Rallying Voice") || stat != CONSCIOUS || silent || find_trait("Mute"))
		return
	for (var/mob/living/human/H in hearers(RALLY_REACH, src))
		if (H == src || H.stat != CONSCIOUS || H.find_trait("Deaf") || H.ear_deaf || (H.sdisabilities & DEAF))
			continue
		if (civilization && civilization != "none" && H.civilization && H.civilization != "none" && H.civilization != civilization)
			continue
		if (world.time < H.last_rallied + RALLY_LISTENER_COOLDOWN)
			continue
		H.last_rallied = world.time
		H.adjust_mood(RALLY_MOOD, "a rousing voice")

// ------------------------------------------------------------
// Mood from company (Life, hunger-enabled modes)
// ------------------------------------------------------------

/mob/living/human/proc/handle_playstyle_traits()
	if (find_trait("Wanderer"))
		handle_wanderer()
	if (!prob(20))
		return
	if (find_trait("Recluse Scholar"))
		var/crowd = 0
		for (var/mob/living/human/H in range(3, src))
			if (H != src && H.stat != DEAD)
				crowd++
				if (crowd >= RECLUSE_CROWD)
					adjust_mood(-0.3, "crowds")
					break
	else if (find_trait("Rallying Voice"))
		for (var/mob/living/human/H in range(3, src))
			if (H != src && H.stat != DEAD)
				return
		adjust_mood(-0.3, "being alone")

#undef PLAYSTYLE_FAST_SKILL
#undef PLAYSTYLE_SLOW_SKILL
#undef RECLUSE_REACH
#undef RECLUSE_ALONE_RATE
#undef RECLUSE_COMPANY_RATE
#undef RECLUSE_CROWD
#undef INTIMIDATE_REACH
#undef INTIMIDATE_COOLDOWN
#undef INTIMIDATE_TARGET_COOLDOWN
#undef INTIMIDATE_MOOD
#undef HARDENED_PAIN_MULT
#undef QUARTERMASTER_DRAG_MULT
#undef GREEN_THUMB_HARVEST_BONUS
#undef WANDERER_FOOD_MULT
#undef WANDERER_RECOVERY_MULT
#undef WANDERER_MOVING_WINDOW
#undef WANDERER_SETTLE_RANGE
#undef WANDERER_SETTLE_TIME
#undef RALLY_REACH
#undef RALLY_MOOD
#undef RALLY_LISTENER_COOLDOWN
