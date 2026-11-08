// Round-end fun facts: a few short lines at the end of a round, such as who
// drew first blood, who had the most kills and which weapon was deadliest.
// Adapted from CM-SS13's random_facts (cmss13-devs/cmss13, AGPL-3.0);
// reimplemented for Civ13. Nothing here is saved: a round's facts reset with
// the world.

var/global/datum/round_facts/round_facts = new

/mob/living/human/var/tmp/round_fact_weapon = null
/mob/living/human/var/tmp/round_fact_hit_time = -1
/mob/living/human/var/tmp/round_fact_counted = FALSE

// A kill is credited only if the last hit landed this recently.
#define ROUND_FACT_KILL_WINDOW (60 SECONDS)

/mob/living/human/persistence_runtime_var(key)
	return (key in list("round_fact_weapon", "round_fact_hit_time", "round_fact_counted")) || ..()

/datum/round_facts
	var/list/kills = list()        // name -> kills of other humans
	var/list/deaths = list()       // name -> deaths
	var/list/shots = list()        // name -> shots fired
	var/list/weapon_kills = list() // weapon name -> kills
	var/first_blood_victim = null
	var/first_blood_killer = null
	var/first_blood_weapon = null
	var/first_blood_time = 0
	var/announced = FALSE

/proc/round_fact_name(mob/living/human/H)
	if (!H)
		return null
	return H.real_name ? H.real_name : H.name

/datum/round_facts/proc/record_shot(mob/living/human/shooter)
	if (!istype(shooter))
		return
	var/name = round_fact_name(shooter)
	shots[name] = (shots[name] || 0) + 1

// Remembers who last hurt a human and with what, for kill credit.
/datum/round_facts/proc/record_hit(mob/living/human/victim, mob/living/human/attacker, weapon)
	if (!istype(victim) || !istype(attacker) || victim == attacker)
		return
	victim.lastattacker = attacker
	victim.round_fact_weapon = weapon ? "[weapon]" : null
	victim.round_fact_hit_time = world.time

/datum/round_facts/proc/record_death(mob/living/human/victim)
	if (!istype(victim) || istype(victim, /mob/living/human/corpse))
		return
	var/victim_name = round_fact_name(victim)
	deaths[victim_name] = (deaths[victim_name] || 0) + 1
	var/mob/living/human/killer = victim.lastattacker
	if (!istype(killer) || killer == victim || victim.round_fact_counted)
		return
	if (victim.round_fact_hit_time < 0 || world.time - victim.round_fact_hit_time > ROUND_FACT_KILL_WINDOW)
		return
	victim.round_fact_counted = TRUE
	var/killer_name = round_fact_name(killer)
	kills[killer_name] = (kills[killer_name] || 0) + 1
	var/weapon = victim.round_fact_weapon
	if (weapon)
		weapon_kills[weapon] = (weapon_kills[weapon] || 0) + 1
	if (!first_blood_victim)
		first_blood_victim = victim_name
		first_blood_killer = killer_name
		first_blood_weapon = weapon
		first_blood_time = world.time - round_start_time

/proc/round_fact_top(list/L)
	var/best = null
	var/best_n = 0
	for (var/key in L)
		if (L[key] > best_n)
			best = key
			best_n = L[key]
	return best ? list(best, best_n) : null

/proc/round_fact_plural(n, word)
	return "[n] [word][n == 1 ? "" : "s"]"

// The lines to announce, in order. Empty when nothing worth saying happened.
/datum/round_facts/proc/fact_lines()
	var/list/lines = list()
	if (first_blood_victim)
		var/minutes = max(0, round(first_blood_time / 600))
		lines += "First blood: <b>[first_blood_killer]</b> killed <b>[first_blood_victim]</b>[first_blood_weapon ? " with \a [first_blood_weapon]" : ""], [round_fact_plural(minutes, "minute")] into the round."
	var/list/top = round_fact_top(kills)
	if (top && top[2] >= 2)
		lines += "Most kills: <b>[top[1]]</b>, with [round_fact_plural(top[2], "kill")]."
	top = round_fact_top(weapon_kills)
	if (top && top[2] >= 2)
		lines += "Deadliest weapon: the <b>[top[1]]</b>, with [round_fact_plural(top[2], "kill")]."
	top = round_fact_top(shots)
	if (top && top[2] >= 20)
		lines += "Most trigger-happy: <b>[top[1]]</b>, who fired [round_fact_plural(top[2], "shot")]."
	top = round_fact_top(deaths)
	if (top && top[2] >= 3)
		lines += "Most stubborn: <b>[top[1]]</b>, who died [top[2]] times and kept coming back."
	return lines

/datum/round_facts/proc/announce()
	if (announced)
		return FALSE
	announced = TRUE
	var/list/lines = fact_lines()
	if (!lines.len)
		return FALSE
	to_chat(world, "<br><span class='notice'><big><b>Round facts</b></big></span>")
	for (var/line in lines)
		to_chat(world, "<span class='notice'>[line]</span>")
	return TRUE

/hook/death/proc/round_facts_death(mob/living/human/H, gibbed)
	if (round_facts)
		round_facts.record_death(H)
	return TRUE

/hook/roundend/proc/round_facts_announce()
	if (round_facts)
		round_facts.announce()
	return TRUE

#undef ROUND_FACT_KILL_WINDOW
