//Sound environment defines. Reverb preset for sounds played in an area, see sound datum reference for more.
#define GENERIC FALSE
#define PADDED_CELL TRUE
#define ROOM 2
#define BATHROOM 3
#define LIVINGROOM 4
#define STONEROOM 5
#define AUDITORIUM 6
#define CONCERT_HALL 7
#define CAVE 8
#define ARENA 9
#define HANGAR 10
#define CARPETED_HALLWAY 11
#define HALLWAY 12
#define STONE_CORRIDOR 13
#define ALLEY 14
#define FOREST 15
#define CITY 16
#define MOUNTAINS 17
#define QUARRY 18
#define PLAIN 19
#define PARKING_LOT 20
#define SEWER_PIPE 21
#define UNDERWATER 22
#define DRUGGED 23
#define DIZZY 24
#define PSYCHOTIC 25

var/list/shatter_sound = list('sound/effects/Glassbr1.ogg','sound/effects/Glassbr2.ogg','sound/effects/Glassbr3.ogg')
var/list/explosion_sound = list('sound/effects/Explosion1.ogg','sound/effects/Explosion2.ogg')
var/list/spark_sound = list('sound/effects/sparks1.ogg','sound/effects/sparks2.ogg','sound/effects/sparks3.ogg','sound/effects/sparks4.ogg')
var/list/rustle_sound = list('sound/effects/rustle1.ogg','sound/effects/rustle2.ogg','sound/effects/rustle3.ogg','sound/effects/rustle4.ogg','sound/effects/rustle5.ogg')
var/list/punch_sound = list('sound/weapons/punch1.ogg','sound/weapons/punch2.ogg','sound/weapons/punch3.ogg', 'sound/weapons/punch4.ogg')
var/list/swing_hit_sound = list('sound/weapons/genhit1.ogg', 'sound/weapons/genhit2.ogg', 'sound/weapons/genhit3.ogg')
var/list/stab_sound = list('sound/weapons/stab1.ogg', 'sound/weapons/stab2.ogg', 'sound/weapons/stab3.ogg')
var/list/slash_sound = list('sound/weapons/slash1.ogg','sound/weapons/slash2.ogg','sound/weapons/slash3.ogg')
var/list/page_sound = list('sound/effects/pageturn1.ogg', 'sound/effects/pageturn2.ogg','sound/effects/pageturn3.ogg')
var/list/miss_sound = list ('sound/weapons/guns/misc/miss.ogg','sound/weapons/guns/misc/miss2.ogg','sound/weapons/guns/misc/miss3.ogg','sound/weapons/guns/misc/miss4.ogg')
var/list/ric_sound = list ('sound/weapons/guns/misc/ric1.ogg','sound/weapons/guns/misc/ric2.ogg','sound/weapons/guns/misc/ric3.ogg','sound/weapons/guns/misc/ric4.ogg','sound/weapons/guns/misc/ric5.ogg')
var/list/bullet_hit_object_sound = list('sound/weapons/guns/misc/bullethit.ogg')
var/list/casing_sound = list ('sound/weapons/guns/misc/casingfall1.ogg','sound/weapons/guns/misc/casingfall2.ogg','sound/weapons/guns/misc/casingfall3.ogg')
var/list/trauma_sound = list('sound/effects/gore/trauma1.ogg', 'sound/effects/gore/trauma2.ogg', 'sound/effects/gore/trauma3.ogg')
var/list/chop_sound = list('sound/effects/gore/chop.ogg', 'sound/effects/gore/chop2.ogg', 'sound/effects/gore/chop3.ogg', 'sound/effects/gore/chop4.ogg', 'sound/effects/gore/chop5.ogg', 'sound/effects/gore/chop6.ogg')
var/list/platingfootsteps = list('sound/effects/footsteps/plating/plating1.ogg','sound/effects/footsteps/plating/plating2.ogg','sound/effects/footsteps/plating/plating3.ogg','sound/effects/footsteps/plating/plating4.ogg')
var/list/erikafootsteps = list('sound/effects/footsteps/tile1.ogg','sound/effects/footsteps/tile2.ogg','sound/effects/footsteps/tile3.ogg','sound/effects/footsteps/tile4.ogg')
var/list/grassfootsteps = list('sound/effects/footsteps/grass/grass1.ogg','sound/effects/footsteps/grass/grass2.ogg','sound/effects/footsteps/grass/grass3.ogg','sound/effects/footsteps/grass/grass4.ogg')
var/list/dirtfootsteps = list('sound/effects/footsteps/dirt/dirt1.ogg','sound/effects/footsteps/dirt/dirt2.ogg','sound/effects/footsteps/dirt/dirt3.ogg','sound/effects/footsteps/dirt/dirt4.ogg')
var/list/waterfootsteps = list('sound/effects/footsteps/water/slosh1.ogg','sound/effects/footsteps/water/slosh2.ogg','sound/effects/footsteps/water/slosh3.ogg','sound/effects/footsteps/water/slosh4.ogg')
var/list/sandfootsteps = list('sound/effects/footsteps/sand/sand_step1.ogg','sound/effects/footsteps/sand/sand_step2.ogg','sound/effects/footsteps/sand/sand_step3.ogg','sound/effects/footsteps/sand/sand_step4.ogg','sound/effects/footsteps/sand/sand_step5.ogg','sound/effects/footsteps/sand/sand_step6.ogg','sound/effects/footsteps/sand/sand_step7.ogg','sound/effects/footsteps/sand/sand_step8.ogg')
var/list/woodfootsteps = list('sound/effects/footsteps/wood/wood_step1.ogg','sound/effects/footsteps/wood/wood_step2.ogg','sound/effects/footsteps/wood/wood_step3.ogg','sound/effects/footsteps/wood/wood_step4.ogg','sound/effects/footsteps/wood/wood_step5.ogg','sound/effects/footsteps/wood/wood_step6.ogg','sound/effects/footsteps/wood/wood_step7.ogg','sound/effects/footsteps/wood/wood_step8.ogg')
var/list/carpetfootsteps = list('sound/effects/footsteps/carpet/carpet_step1.ogg','sound/effects/footsteps/carpet/carpet_step2.ogg','sound/effects/footsteps/carpet/carpet_step3.ogg','sound/effects/footsteps/carpet/carpet_step4.ogg','sound/effects/footsteps/carpet/carpet_step5.ogg','sound/effects/footsteps/carpet/carpet_step6.ogg','sound/effects/footsteps/carpet/carpet_step7.ogg','sound/effects/footsteps/carpet/carpet_step8.ogg')
var/list/snowfootsteps = list('sound/effects/footsteps/snow/snow1.ogg','sound/effects/footsteps/snow/snow2.ogg','sound/effects/footsteps/snow/snow3.ogg','sound/effects/footsteps/snow/snow4.ogg','sound/effects/footsteps/snow/snow5.ogg')
var/list/icefootsteps = list('sound/effects/footsteps/ice/ice1.ogg','sound/effects/footsteps/ice/ice2.ogg','sound/effects/footsteps/ice/ice3.ogg','sound/effects/footsteps/ice/ice4.ogg','sound/effects/footsteps/ice/ice5.ogg')

var/list/artillery_out = list( 'sound/weapons/WW2/new_exp_high_1.ogg', 'sound/weapons/WW2/new_exp_high_2.ogg', 'sound/weapons/WW2/new_exp_high_3.ogg')
var/list/artillery_in = list( 'sound/weapons/WW2/new_artillery_incoming01.ogg', 'sound/weapons/WW2/new_artillery_incoming02.ogg', 'sound/weapons/WW2/new_artillery_incoming03.ogg', 'sound/weapons/WW2/new_artillery_incoming04.ogg', 'sound/weapons/WW2/new_artillery_incoming05.ogg', 'sound/weapons/WW2/new_artillery_incoming06.ogg')
var/list/artillery_out_distance = list( 'sound/weapons/WW2/explo_distant01.ogg', 'sound/weapons/WW2/explo_distant02.ogg', 'sound/weapons/WW2/explo_distant03.ogg', 'sound/weapons/WW2/explo_distant04.ogg', 'sound/weapons/WW2/explo_distant05.ogg', 'sound/weapons/WW2/explo_distant06.ogg', 'sound/weapons/WW2/explo_distant07.ogg', 'sound/weapons/WW2/explo_distant08.ogg')
var/list/artillery_in_distance = list( 'sound/weapons/WW2/explo_distant01.ogg', 'sound/weapons/WW2/explo_distant02.ogg', 'sound/weapons/WW2/explo_distant03.ogg', 'sound/weapons/WW2/explo_distant04.ogg', 'sound/weapons/WW2/explo_distant05.ogg', 'sound/weapons/WW2/explo_distant06.ogg', 'sound/weapons/WW2/explo_distant07.ogg', 'sound/weapons/WW2/explo_distant08.ogg')

var/list/doorknock_sounds = list(
	'sound/effects/doorknock1.ogg',
	'sound/effects/doorknock2.ogg',
	'sound/effects/doorknock3.ogg',
	'sound/effects/doorknock4.ogg',
	'sound/effects/doorknock5.ogg',
	'sound/effects/doorknock6.ogg')

// emote sounds from InterBay
var/list/cough_sounds_male = list(
	'sound/effects/emotes/male_cough1.ogg',
	'sound/effects/emotes/male_cough2.ogg',
	'sound/effects/emotes/male_cough3.ogg',
	'sound/effects/emotes/male_cough4.ogg')

var/list/cry_sounds_male = list(
	'sound/effects/emotes/male_cry1.ogg',
	'sound/effects/emotes/male_cry2.ogg')

var/list/laugh_sounds_male = list(
	'sound/effects/emotes/male_laugh1.ogg')

var/list/chuckle_sounds_male = list(
	'sound/effects/emotes/male_laugh2.ogg',
	'sound/effects/emotes/male_laugh3.ogg')

var/list/yawn_sounds_male = list(
	'sound/effects/emotes/male_yawn1.ogg',
	'sound/effects/emotes/male_yawn2.ogg')

var/list/sigh_sounds_male = list(
	'sound/effects/emotes/male_sigh.ogg')

var/list/sneeze_sounds_male = list(
	'sound/effects/emotes/male_sneeze1.ogg',
	'sound/effects/emotes/male_sneeze2.ogg')

var/list/cough_sounds_female = list(
	'sound/effects/emotes/female_cough1.ogg',
	'sound/effects/emotes/female_cough2.ogg',
	'sound/effects/emotes/female_cough3.ogg',
	'sound/effects/emotes/female_cough4.ogg',
	'sound/effects/emotes/female_cough5.ogg',
	'sound/effects/emotes/female_cough6.ogg')

var/list/cry_sounds_female = list(
	'sound/effects/emotes/female_cry1.ogg',
	'sound/effects/emotes/female_cry2.ogg')

var/list/gasp_sounds_male = list(
	'sound/effects/emotes/man_gasp0.ogg',
	'sound/effects/emotes/man_gasp1.ogg',
	'sound/effects/emotes/man_gasp2.ogg',
	'sound/effects/emotes/man_gasp3.ogg',
	'sound/effects/emotes/man_gasp4.ogg',
	'sound/effects/emotes/man_gasp5.ogg',
	'sound/effects/emotes/man_gasp6.ogg',
	'sound/effects/emotes/man_gasp7.ogg',
	'sound/effects/emotes/man_gasp8.ogg',
	'sound/effects/emotes/man_gasp9.ogg',
	'sound/effects/emotes/man_gasp10.ogg')

var/list/gasp_sounds_female = list(
	'sound/effects/emotes/woman_gasp0.ogg',
	'sound/effects/emotes/woman_gasp1.ogg',
	'sound/effects/emotes/woman_gasp2.ogg',
	'sound/effects/emotes/woman_gasp3.ogg',
	'sound/effects/emotes/woman_gasp4.ogg',
	'sound/effects/emotes/woman_gasp5.ogg',
	'sound/effects/emotes/woman_gasp6.ogg',
	'sound/effects/emotes/woman_gasp7.ogg',
	'sound/effects/emotes/woman_gasp8.ogg',
	'sound/effects/emotes/woman_gasp9.ogg',
	'sound/effects/emotes/woman_gasp10.ogg')

var/list/laugh_sounds_female = list(
	'sound/effects/emotes/female_laugh1.ogg',
	'sound/effects/emotes/female_laugh3.ogg')

var/list/chuckle_sounds_female = list('sound/effects/emotes/female_laugh2.ogg')

var/list/yawn_sounds_female = list(
	'sound/effects/emotes/female_yawn1.ogg',
	'sound/effects/emotes/female_yawn2.ogg',
	'sound/effects/emotes/female_yawn3.ogg')

var/list/sigh_sounds_female = list(
	'sound/effects/emotes/female_sigh.ogg')

var/list/sneeze_sounds_female = list(
	'sound/effects/emotes/female_sneeze1.ogg',
	'sound/effects/emotes/female_sneeze2.ogg')

var/list/charge_sounds_eng = list(
	'sound/effects/emotes/charge_eng.ogg',
	'sound/effects/emotes/god_save_the_king.ogg',)
var/list/charge_sounds_pir = list(
	'sound/effects/emotes/charge_pir.ogg',
	'sound/effects/emotes/charge_pir2.ogg',
	'sound/effects/emotes/charge_pir3.ogg',
	'sound/effects/emotes/charge_pir4.ogg',)
var/list/charge_sounds_ind = list(
	'sound/effects/emotes/charge_ind.ogg',
	'sound/effects/emotes/charge_ind2.ogg',
	'sound/effects/emotes/charge_ind3.ogg',
	'sound/effects/emotes/charge_ind4.ogg',
	'sound/effects/emotes/charge_ind5.ogg',)
var/list/charge_sounds_pt = list(
	'sound/effects/emotes/charge_pt.ogg',)
var/list/charge_sounds_fr = list(
	'sound/effects/emotes/charge_fr.ogg',
	'sound/effects/emotes/charge_fr2.ogg',)
var/list/charge_sounds_sp = list(
	'sound/effects/emotes/charge_sp.ogg',)
var/list/charge_sounds_nl = list(
	'sound/effects/emotes/charge_nl.ogg',
	'sound/effects/emotes/charge_nl2.ogg',
	'sound/effects/emotes/charge_nl3.ogg',
	'sound/effects/emotes/charge_nl4.ogg',)
var/list/charge_sounds_ro = list(
	'sound/effects/emotes/charge_ro.ogg',)
var/list/charge_sounds_jp = list(
	'sound/effects/emotes/charge_jp.ogg',
	'sound/effects/emotes/charge_jp2.ogg',
	'sound/effects/emotes/charge_jp3.ogg',)
var/list/charge_sounds_ru = list(
	'sound/effects/emotes/charge_ru.ogg',
	'sound/effects/emotes/charge_ru2.ogg',
	'sound/effects/emotes/charge_ru3.ogg',)
var/list/charge_sounds_gr = list(
	'sound/effects/emotes/charge_gr.ogg',)
var/list/charge_sounds_ar = list(
	'sound/effects/emotes/charge_ar.ogg',
	'sound/effects/emotes/charge_ar2.ogg',
	'sound/effects/emotes/charge_ar3.ogg',
	'sound/effects/emotes/charge_ar4.ogg',
	'sound/effects/emotes/charge_ar5.ogg',
	'sound/effects/emotes/charge_ar6.ogg',
	)
var/list/charge_sounds_ge = list(
	'sound/effects/emotes/charge_ger.ogg',
	'sound/effects/emotes/charge_ger2.ogg',
	'sound/effects/emotes/charge_ger3.ogg',
	'sound/effects/emotes/charge_ger4.ogg',
	'sound/effects/emotes/charge_ger5.ogg',
	)
var/list/charge_sounds_crusader = list(
	'sound/effects/emotes/charge_crusader.ogg',)
var/list/charge_sounds_vi = list(
	'sound/effects/emotes/charge_vi.ogg',
	'sound/effects/emotes/charge_vi2.ogg',)
var/list/charge_sounds_us = list(
	'sound/effects/emotes/charge_eng.ogg',)
var/list/charge_sounds_isr = list(
	'sound/effects/emotes/charge_isr.ogg',)
// pain, etc sounds from Interbay

/proc/playsound(var/atom/source, soundin, vol as num, vary, extrarange as num, falloff, var/is_global, var/list/excluded = list())

	soundin = get_sfx(soundin) // same sound for everyone

	if (isarea(source))
		error("[source] is an area and is trying to make the sound: [soundin]")
		return

	var/frequency = get_rand_frequency() // Same frequency for everybody
	var/turf/turf_source = get_turf(source)

	var/list/players_who_heard = list()
 	// Looping through the player list has the added bonus of working for mobs inside containers
	for (var/P in player_list)
		var/mob/M = P

		if (istype(source) && isnewplayer(M))
			continue

		if (!M || !M.client)
			continue

		if (excluded.Find(M))
			continue

		var/distance = get_dist(M, turf_source)
		if (distance <= ((7 * 3) + extrarange))
			var/turf/T = get_turf(M)
			if (T && T.z == turf_source.z)
				M.playsound_local(turf_source, soundin, vol, vary, frequency, falloff, is_global)
				players_who_heard += M

	return players_who_heard

var/const/FALLOFF_SOUNDS = 0.5

/mob/proc/playsound_local(var/turf/turf_source, soundin, vol as num, vary, frequency, falloff, is_global)
	if (!client || ear_deaf > 0)	return
	soundin = get_sfx(soundin)

	var/distance = -1

	var/sound/S = sound(soundin)
	S.wait = FALSE //No queue
	S.channel = FALSE //Any channel
	S.volume = vol
	S.environment = -1
	if (vary)
		if (frequency)
			S.frequency = frequency
		else
			S.frequency = get_rand_frequency()

	if (isturf(turf_source))
		// 3D sounds, the technology is here!
		var/turf/T = get_turf(src)

		//sound volume falloff with distance
		distance = get_dist(T, turf_source)

		// multiplicative falloff to add on top of natural audio falloff
		// this is louder now, because it should be louder than war ambience - Kachnov
		S.volume -= min(0, (max(distance - 7, 0) * 1.5))

		// if you're in a different type of area (fake z levels) the sound will only be half as loud - Kachnov
		if (S.volume > 0)
			var/area/source_area = get_area(turf_source)
			var/area/my_area = get_area(T)
			if (source_area.is_void_area != my_area.is_void_area)
				S.volume = ceil(S.volume/2)

		if (S.volume <= 0)
			return	//no volume means no sound

		var/dx = turf_source.x - T.x // Hearing from the right/left
		S.x = dx
		var/dz = turf_source.y - T.y // Hearing from infront/behind
		S.z = dz
		// The y value is for above your head, but there is no ceiling in 2d spessmens.
		S.y = TRUE
		S.falloff = (falloff ? falloff : FALLOFF_SOUNDS)

	if (!is_global)

		if (istype(src,/mob/living/))
			var/mob/living/M = src
			if (M.hallucination)
				S.environment = PSYCHOTIC
			else if (M.druggy)
				S.environment = DRUGGED
			else if (M.drowsyness)
				S.environment = DIZZY
			else if (M.confused)
				S.environment = DIZZY
			else if (M.sleeping)
				S.environment = UNDERWATER
			else
				var/area/A = get_area(src)
				S.environment = A.sound_env
		else
			var/area/A = get_area(src)
			S.environment = A.sound_env

	if (distance > 30)
		S.environment = UNDERWATER

	src << S

/proc/get_rand_frequency()
	return rand(32000, 55000) //Frequency stuff only works with 45kbps oggs.

/proc/get_sfx(soundin)
	if (istext(soundin))
		switch(soundin)
			if ("shatter") soundin = pick(shatter_sound)
			if ("explosion") soundin = pick(explosion_sound)
			if ("sparks") soundin = pick(spark_sound)
			if ("rustle") soundin = pick(rustle_sound)
			if ("punch") soundin = pick(punch_sound)
			if ("swing_hit") soundin = pick(swing_hit_sound)
			if ("slash_sound") soundin = pick(slash_sound)
			if ("stab_sound") soundin = pick(stab_sound)
			if ("pageturn") soundin = pick(page_sound)
			if ("miss_sound") soundin = pick(miss_sound)
			if ("ric_sound") soundin = pick(ric_sound)
			if ("hitobject") soundin = pick(bullet_hit_object_sound)
			if ("trauma") soundin = pick(trauma_sound)
			if ("chop") soundin = pick(chop_sound)
			if ("platingfootsteps") soundin = pick(platingfootsteps)
			if ("erikafootsteps") soundin = pick(erikafootsteps)
			if ("grassfootsteps") soundin = pick(grassfootsteps)
			if ("dirtfootsteps") soundin = pick(dirtfootsteps)
			if ("waterfootsteps") soundin = pick(waterfootsteps)
			if ("sandfootsteps") soundin = pick(sandfootsteps)
			if ("woodfootsteps") soundin = pick(woodfootsteps)
			if ("carpetfootsteps") soundin = pick(carpetfootsteps)
			if ("snowfootsteps") soundin = pick(snowfootsteps)
			if ("icefootsteps") soundin = pick(icefootsteps)
			if ("doorknock") soundin = pick(doorknock_sounds)
			if ("artillery_out") soundin = pick(artillery_out)
			if ("artillery_in") soundin = pick(artillery_in)
			if ("artillery_out_distance") soundin = pick(artillery_out_distance)
			if ("artillery_in_distance") soundin = pick(artillery_in_distance)

			// emote sounds from InterBay
			if ("cough_male")
				soundin = pick(cough_sounds_male)
			if ("cry_male")
				soundin = pick(cry_sounds_male)
			if ("laugh_male")
				soundin = pick(laugh_sounds_male)
			if ("chuckle_male")
				soundin = pick(chuckle_sounds_male)
			if ("yawn_male")
				soundin = pick(yawn_sounds_male)
			if ("sigh_male")
				soundin = pick(sigh_sounds_male)
			if ("sneeze_male")
				soundin = pick(sneeze_sounds_male)
			if ("gasp_male")
				soundin = pick(gasp_sounds_male)
			if ("gasp_female")
				soundin = pick(gasp_sounds_female)
			if ("cough_female")
				soundin = pick(cough_sounds_female)
			if ("cry_female")
				soundin = pick(cry_sounds_female)
			if ("laugh_female")
				soundin = pick(laugh_sounds_female)
			if ("chuckle_female")
				soundin = pick(chuckle_sounds_female)
			if ("yawn_female")
				soundin = pick(yawn_sounds_female)
			if ("sigh_female")
				soundin = pick(sigh_sounds_female)
			if ("sneeze_female")
				soundin = pick(sneeze_sounds_female)

			if ("charge_BRITISH")
				soundin = pick(charge_sounds_eng)
			if ("charge_PIRATES")
				soundin = pick(charge_sounds_pir)
			if ("charge_CIVILIAN")
				soundin = pick(charge_sounds_eng)
			if ("charge_INDIANS")
				soundin = pick(charge_sounds_ind)
			if ("charge_PORTUGUESE")
				soundin = pick(charge_sounds_pt)
			if ("charge_FRENCH")
				soundin = pick(charge_sounds_fr)
			if ("charge_SPANISH")
				soundin = pick(charge_sounds_sp)
			if ("charge_DUTCH")
				soundin = pick(charge_sounds_nl)
			if ("charge_JAPANESE")
				soundin = pick(charge_sounds_jp)
			if ("charge_RUSSIAN")
				soundin = pick(charge_sounds_ru)
			if ("charge_GREEK")
				soundin = pick(charge_sounds_gr)
			if ("charge_ROMAN")
				soundin = pick(charge_sounds_ro)
			if ("charge_GERMAN")
				soundin = pick(charge_sounds_ge)
			if ("charge_ARAB")
				soundin = pick(charge_sounds_ar)
			if ("charge_CRUSADER")
				soundin = pick(charge_sounds_crusader)
			if ("charge_VIETNAMESE")
				soundin = pick(charge_sounds_vi)
			if ("charge_AMERICAN")
				soundin = pick(charge_sounds_us)
			if ("charge_ISRAELI")
				soundin = pick(charge_sounds_isr)
	return soundin
