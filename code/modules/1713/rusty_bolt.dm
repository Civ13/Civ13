// The "rusty bolt" effect. A corroded metal joint behaves like a crude diode:
// close to a strong AM transmitter it rectifies the carrier and the metal
// faintly sounds out the broadcast, garbled. Only powerful transmitters cause it
// (powered radio sets, broadcast desks and relay masts, never handhelds), and it
// runs only when one of them airs a line, so idle worlds pay nothing.
#define RUSTY_BOLT_RANGE 6
#define RUSTY_BOLT_HEAR_RANGE 2
#define RUSTY_BOLT_MAX_SOURCES 3
#define RUSTY_BOLT_MAX_LISTENERS 12

// Percent chance that this object picks up one strong nearby broadcast.
/obj/proc/rusty_bolt_chance()
	return 0

/obj/structure/grille/ironfence/rusty_bolt_chance()
	return 25

/obj/structure/grille/chainlinkfence/rusty_bolt_chance()
	return 20

/obj/structure/grille/metalsheetfence/rusty_bolt_chance()
	return 15

// A running fan's loose housing rattles the signal out.
/obj/structure/coolingfan/rusty_bolt_chance()
	return on ? 40 : 0

// Metal bedsprings; chairs, bedrolls and wooden frames stay silent.
/obj/structure/bed/rusty_bolt_chance()
	if (istype(src, /obj/structure/bed/chair) || istype(src, /obj/structure/bed/bedroll))
		return 0
	return (get_material_name() in list("iron", "steel", "bronze", "copper")) ? 15 : 0

// Closer to the mast, clearer the voice: percent of letters that survive.
/proc/rusty_bolt_clarity(distance)
	return max(30, min(65, 70 - distance * 6))

// Called when a strong transmitter airs a line. Returns how many listeners
// heard it through nearby metal. chance_override is for tests only.
/proc/rusty_bolt_reradiate(atom/transmitter, message, datum/language/language, chance_override = null)
	var/turf/T = get_turf(transmitter)
	if (!T || !message)
		return 0
	var/sources = 0
	var/list/heard = list()
	for (var/obj/O in range(RUSTY_BOLT_RANGE, T))
		if (sources >= RUSTY_BOLT_MAX_SOURCES || heard.len >= RUSTY_BOLT_MAX_LISTENERS)
			break
		if (O == transmitter || !isturf(O.loc))
			continue
		var/chance = O.rusty_bolt_chance()
		if (chance <= 0 || !prob(isnull(chance_override) ? chance : chance_override))
			continue
		sources++
		var/garbled = stars(message, rusty_bolt_clarity(get_dist(O, T)))
		for (var/mob/living/human/H in hearers(RUSTY_BOLT_HEAR_RANGE, O))
			if (heard.len >= RUSTY_BOLT_MAX_LISTENERS)
				break
			if ((H in heard) || H.stat != CONSCIOUS || H.sleeping || (H.sdisabilities & DEAF) || H.ear_deaf || H.find_trait("Deaf"))
				continue
			heard += H
			var/line = garbled
			if (language && !(language.flags & INNATE) && !H.say_understands(null, language))
				line = language.scramble(line, H)
			H.hear_rusty_bolt(O, line)
	return heard.len

/mob/living/human/proc/hear_rusty_bolt(obj/source, line)
	if (!client)
		return
	var/sound_verb = pick("buzzes", "hums", "crackles", "whispers tinnily")
	on_hear_radio(null, "<span class='notice'><i>\The [source] faintly [sound_verb]: \"[line]\"</i></span>")

// Powered radio sets only; portable radios are too weak to drive it.
/proc/rusty_bolt_from_radio(obj/R, message, mob/living/human/speaker)
	if (!istype(R, /obj/structure/radio))
		return 0
	var/obj/structure/radio/S = R
	if (!S.check_power() && S.powerneeded != 0)
		return 0
	return rusty_bolt_reradiate(S, message, speaker ? speaker.default_language : null)

#undef RUSTY_BOLT_RANGE
#undef RUSTY_BOLT_HEAR_RANGE
#undef RUSTY_BOLT_MAX_SOURCES
#undef RUSTY_BOLT_MAX_LISTENERS
