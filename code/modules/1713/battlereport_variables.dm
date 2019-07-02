#define BATTLEREPORT_VARIABLE_CHECK(_mob) if (!istype(_mob, /mob/living/carbon/human/corpse) && (!get_area(_mob) || !istype(get_area(_mob), /area/caribbean/admin)))

var/list/alive_british = list()
var/list/alive_pirates = list()
var/list/alive_civilians = list()
var/list/alive_french = list()
var/list/alive_spanish = list()
var/list/alive_portuguese = list()
var/list/alive_indians = list()
var/list/alive_dutch = list()
var/list/alive_greek = list()
var/list/alive_roman = list()
var/list/alive_arab = list()
var/list/alive_japanese = list()
var/list/alive_russian = list()
var/list/alive_german = list()
var/list/alive_american = list()
var/list/alive_vietnamese = list()

var/list/heavily_injured_british = list()
var/list/heavily_injured_pirates = list()
var/list/heavily_injured_civilians = list()
var/list/heavily_injured_french = list()
var/list/heavily_injured_spanish = list()
var/list/heavily_injured_portuguese = list()
var/list/heavily_injured_indians = list()
var/list/heavily_injured_dutch = list()
var/list/heavily_injured_roman = list()
var/list/heavily_injured_greek = list()
var/list/heavily_injured_arab = list()
var/list/heavily_injured_japanese = list()
var/list/heavily_injured_russian = list()
var/list/heavily_injured_german = list()
var/list/heavily_injured_american = list()
var/list/heavily_injured_vietnamese = list()

var/list/dead_british = list()
var/list/dead_pirates = list()
var/list/dead_civilians = list()
var/list/dead_french = list()
var/list/dead_spanish = list()
var/list/dead_portuguese = list()
var/list/dead_indians = list()
var/list/dead_dutch = list()
var/list/dead_greek = list()
var/list/dead_roman = list()
var/list/dead_arab = list()
var/list/dead_japanese = list()
var/list/dead_russian = list()
var/list/dead_german = list()
var/list/dead_american = list()
var/list/dead_vietnamese = list()

var/list/recently_died = list()

/mob/living/carbon/human/proc/get_battle_report_lists()

	var/list/alive = list()
	var/list/injured = list()
	var/list/dead = list()
	if (original_job)
		switch (original_job.base_type_flag())
			if (BRITISH)
				dead = dead_british
				injured = heavily_injured_british
				alive = alive_british
			if (PIRATES)
				dead = dead_pirates
				injured = heavily_injured_pirates
				alive = alive_pirates
			if (CIVILIAN)
				dead = dead_civilians
				injured = heavily_injured_civilians
				alive = alive_civilians
			if (FRENCH)
				dead = dead_french
				injured = heavily_injured_french
				alive = alive_french
			if (PORTUGUESE)
				dead = dead_portuguese
				injured = heavily_injured_portuguese
				alive = alive_portuguese
			if (SPANISH)
				dead = dead_spanish
				injured = heavily_injured_spanish
				alive = alive_spanish
			if (INDIANS)
				dead = dead_indians
				injured = heavily_injured_indians
				alive = alive_indians
			if (DUTCH)
				dead = dead_dutch
				injured = heavily_injured_dutch
				alive = alive_dutch
			if (ROMAN)
				dead = dead_roman
				injured = heavily_injured_roman
				alive = alive_roman
			if (GREEK)
				dead = dead_greek
				injured = heavily_injured_greek
				alive = alive_greek
			if (ARAB)
				dead = dead_arab
				injured = heavily_injured_arab
				alive = alive_arab
			if (RUSSIAN)
				dead = dead_russian
				injured = heavily_injured_russian
				alive = alive_russian
			if (JAPANESE)
				dead = dead_japanese
				injured = heavily_injured_japanese
				alive = alive_japanese
			if (GERMAN)
				dead = dead_german
				injured = heavily_injured_german
				alive = alive_german
			if (AMERICAN)
				dead = dead_american
				injured = heavily_injured_american
				alive = alive_american
			if (VIETNAMESE)
				dead = dead_vietnamese
				injured = heavily_injured_vietnamese
				alive = alive_vietnamese
	return list(alive, dead, injured)

/mob/living/carbon/human/death()
	if (original_job_title == "Nomad")
		if (civilization != "none" && map.custom_civs[civilization][4])
			if (map.custom_civs[civilization][4].real_name == real_name)
				map.custom_civs[civilization][4] = null

	BATTLEREPORT_VARIABLE_CHECK(src)
		if (!istype(src, /mob/living/carbon/human/corpse))
			var/list/lists = get_battle_report_lists()
			var/list/alive = lists[1]
			var/list/dead = lists[2]
			var/list/injured = lists[3]

			alive -= getRoundUID()
			injured -= getRoundUID()
			dead |= getRoundUID()

			// prevent one last Life() from potentially undoing this
			var/storedRoundUID = getRoundUID() // in case we're getting gibbed
			recently_died += storedRoundUID
			spawn (200)
				recently_died -= storedRoundUID

	..()


/mob/living/carbon/human/Life()

	var/list/lists = get_battle_report_lists()
	var/list/alive = lists[1]
	var/list/dead = lists[2]
	var/list/injured = lists[3]

	..()

	BATTLEREPORT_VARIABLE_CHECK(src)
		if (istype(src, /mob/living/carbon/human/corpse))
			return

		if (recently_died.Find(getRoundUID()))
			return

		if (stat == DEAD)
			return

		alive -= getRoundUID()
		injured -= getRoundUID()
		dead -= getRoundUID()

		// give these lists starting values to prevent runtimes.
		if (stat == CONSCIOUS)
			alive |= getRoundUID()
		else if (stat == UNCONSCIOUS || (health <= 0 && stat != DEAD))
			injured |= getRoundUID()