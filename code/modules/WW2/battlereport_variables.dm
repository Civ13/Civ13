#define BATTLEREPORT_VARIABLE_CHECK(_mob) if (!istype(_mob, /mob/living/carbon/human/corpse) && (!get_area(_mob) || !istype(get_area(_mob), /area/prishtina/admin)))

var/list/alive_germans = list()
var/list/alive_italians = list()
var/list/alive_russians = list()
var/list/alive_civilians = list()
var/list/alive_partisans = list()
var/list/alive_undead = list()
var/list/alive_polish = list()
var/list/alive_usa = list()
var/list/alive_japan = list()

var/list/heavily_injured_germans = list()
var/list/heavily_injured_italians = list()
var/list/heavily_injured_russians = list()
var/list/heavily_injured_civilians = list()
var/list/heavily_injured_partisans = list()
var/list/heavily_injured_undead = list()
var/list/heavily_injured_polish = list()
var/list/heavily_injured_usa = list()
var/list/heavily_injured_japan = list()

var/list/dead_germans = list()
var/list/dead_italians = list()
var/list/dead_russians = list()
var/list/dead_civilians = list()
var/list/dead_partisans = list()
var/list/dead_undead = list()
var/list/dead_polish = list()
var/list/dead_usa = list()
var/list/dead_japan = list()

var/list/recently_died = list()

/mob/living/carbon/human/proc/get_battle_report_lists()

	var/list/alive = list()
	var/list/injured = list()
	var/list/dead = list()

	switch (original_job.base_type_flag())
		if (GERMAN)
			dead = dead_germans
			injured = heavily_injured_germans
			alive = alive_germans
		if (ITALIAN)
			dead = dead_italians
			injured = heavily_injured_italians
			alive = alive_italians
		if (SOVIET)
			dead = dead_russians
			injured = heavily_injured_russians
			alive = alive_russians
		if (CIVILIAN)
			dead = dead_civilians
			injured = heavily_injured_civilians
			alive = alive_civilians
		if (PARTISAN)
			dead = dead_partisans
			injured = heavily_injured_partisans
			alive = alive_partisans
		if (PILLARMEN)
			dead = dead_undead
			injured = heavily_injured_undead
			alive = alive_undead
		if (POLISH_INSURGENTS)
			dead = dead_polish
			injured = heavily_injured_polish
			alive = alive_polish
		if (USA)
			dead = dead_usa
			injured = heavily_injured_usa
			alive = alive_usa
		if (JAPAN)
			dead = dead_japan
			injured = heavily_injured_japan
			alive = alive_japan

	return list(alive, dead, injured)

/mob/living/carbon/human/death()

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

		if (istype(original_job, /datum/job/german/trainsystem))
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