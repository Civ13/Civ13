// Only input/time and unrelated infrastructure are adapted; production bodies
// provide the consumption arithmetic, activity decision and timed action loops.
#define CONSCIOUS 0
#define UNCONSCIOUS 1
#define DEAD 2
#define TRUE 1
#define FALSE 0
#define INCAPACITATION_DEFAULT 0
#define MAP_NOMADS_DESERT "desert"
/world
	maxx = 2
	maxy = 2
	maxz = 1
	fps = 10
	hub = ""
/datum/proc/persistence_runtime_var(key)
	return key == "parent_sentinel"
/datum/progressbar
/datum/progressbar/New(mob/user, goal, atom/target)
	return
/datum/progressbar/proc/update(progress)
	return
// Mining is outside this fixture: production do_after is called only with its
// default null context. Keep its optional interface declared and fail closed if
// a future probe accidentally supplies a mining context.
/datum/pickaxe_mining_action
	var/wait_started = FALSE
	var/datum/progressbar/progressbar
/datum/pickaxe_mining_action/proc/claim(mob/user, atom/target)
	check(FALSE, "unexpected mining context in metabolism fixture")
	return FALSE
/datum/pickaxe_mining_action/proc/valid(mob/user, atom/target)
	check(FALSE, "unexpected mining context in metabolism fixture")
	return FALSE
/proc/qdel(datum/D)
	del(D)
/obj/structure/bed
/obj/structure/cross
/obj/map_metadata
	var/heat_wave = FALSE
	var/ID = "plain"
var/obj/map_metadata/map
/mob
	var/may_do_mob = TRUE
	var/may_do_after = TRUE
	var/last_movement = -1
	var/next_click = 0
	var/next_move = 0
	var/probe_incapacitated = FALSE
/mob/proc/get_active_hand()
	return null
/mob/proc/incapacitated(flags = 0)
	return probe_incapacitated
/mob/living/human
	var/nutrition = 100
	var/water = 100
	var/stat = CONSCIOUS
	var/inducedSSD = FALSE
	var/obj/buckled
	var/orc = FALSE
	var/goblin = FALSE
	var/crab = FALSE
	var/gorillaman = FALSE
	var/droid = FALSE
	var/exercise_equipment = null
	var/probe_clock = 1000
	var/probe_inactivity = 1000
	var/list/probe_traits = list()
/mob/living/human/proc/find_trait(trait)
	return trait in probe_traits
/mob/living/human/probe/survival_metabolism_time()
	return probe_clock
/mob/living/human/probe/survival_input_inactivity()
	return probe_inactivity
/proc/check(condition, label)
	if (!condition)
		text2file("FAIL: [label]", "result.txt")
		shutdown()
		sleep(100) // shutdown is deferred; do not continue into unrelated assertions.
/proc/consume(mob/living/human/H, food, drink, label)
	H.nutrition = 100
	H.water = 100
	H.probe_consume()
	check(abs((100 - H.nutrition) - food) < 0.00003, "[label] food")
	check(abs((100 - H.water) - drink) < 0.00003, "[label] water")
/world/Error(exception/E)
	text2file("ERROR: [E]", "result.txt")
	world.log << "runtime error: [E]"
	shutdown()
/world/New()
	world.OpenPort("none")
	map = new
	var/mob/living/human/probe/H = new(locate(1,1,1))
	consume(H, 0.0864, 0.0864, "active ordinary")
	H.probe_clock = 1599
	consume(H, 0.0864, 0.0864, "before idle threshold")
	H.probe_clock = 1600
	consume(H, 0.00864, 0.00864, "idle ordinary")
	map.heat_wave = TRUE
	consume(H, 0.00864, 0.0224, "idle heat")
	H.probe_inactivity = 0
	consume(H, 0.0864, 0.224, "input reengagement heat")
	map.heat_wave = FALSE
	map.ID = MAP_NOMADS_DESERT
	consume(H, 0.0864, 0.224, "active desert")
	map.ID = "plain"
	H.probe_inactivity = 10000
	H.probe_clock += 600
	H.last_movement = H.probe_clock
	consume(H, 0.0864, 0.0864, "movement reengagement")
	H.probe_clock += 600
	H.next_click = H.probe_clock + 1
	consume(H, 0.0864, 0.0864, "stationary combat click")
	H.probe_clock += 600
	H.next_move = H.probe_clock + 50
	consume(H, 0.0864, 0.0864, "combat cooldown")
	H.next_move = 0
	H.probe_clock += 600
	consume(H, 0.00864, 0.00864, "idle after cooldown")
	H.probe_traits = list("Gigantism")
	consume(H, 0.012096, 0.00864, "idle gigantism")
	H.probe_traits = list("Dwarfism")
	consume(H, 0.006912, 0.00864, "idle dwarfism")
	H.probe_traits = list()
	H.crab = TRUE
	consume(H, 0.006912, 0.0216, "idle crab")
	H.crab = FALSE
	H.orc = TRUE
	consume(H, 0.01296, 0.00864, "idle orc")
	H.orc = FALSE
	H.goblin = TRUE
	consume(H, 0.006912, 0.00864, "idle goblin")
	H.goblin = FALSE
	H.gorillaman = TRUE
	consume(H, 0.00864, 0.001728, "idle gorilla")
	H.gorillaman = FALSE
	H.droid = TRUE
	consume(H, 0, 0, "idle droid")
	H.droid = FALSE
	H.buckled = new /obj/structure/cross
	consume(H, 0.01296, 0.0432, "idle cross")
	H.buckled = new /obj/structure/bed
	H.stat = UNCONSCIOUS
	consume(H, 0.0032, 0.0032, "bed sleep")
	H.buckled = null
	consume(H, 0.0864, 0.0864, "unconscious ordinary")
	map.heat_wave = TRUE
	consume(H, 0.0864, 0.224, "unconscious heat")
	H.inducedSSD = TRUE
	consume(H, 0, 0, "SSD")
	H.inducedSSD = FALSE
	H.stat = DEAD
	consume(H, 0, 0, "dead")
	map.heat_wave = FALSE
	H.stat = CONSCIOUS
	H.probe_inactivity = -1
	consume(H, 0.0864, 0.0864, "no client")
	H.probe_inactivity = 10000
	H.probe_clock = 0
	consume(H, 0.0864, 0.0864, "clock reset")
	H.last_movement = -1
	H.next_click = 0
	H.probe_clock += 600
	consume(H, 0.00864, 0.00864, "idle before action")
	spawn(0)
		do_after(H, 5, progress = FALSE, check_for_repeats = FALSE)
	sleep(1)
	H.probe_clock += 1000
	consume(H, 0.0864, 0.0864, "stationary unrestricted action")
	check(H.survival_actions == 1, "timed action ownership")
	sleep(6)
	check(H.survival_actions == 0, "completed action releases ownership")
	consume(H, 0.0864, 0.0864, "completed action grace")
	H.probe_clock += 600
	spawn(0)
		do_after(H, 6, progress = FALSE, check_for_repeats = FALSE)
	spawn(0)
		do_after(H, 3, progress = FALSE, check_for_repeats = FALSE)
	sleep(1)
	check(H.survival_actions == 2, "overlapping action count")
	sleep(3)
	check(H.survival_actions == 1, "short action preserves longer action")
	sleep(4)
	check(H.survival_actions == 0, "overlapping actions finish")
	H.probe_incapacitated = TRUE
	do_after(H, 5, progress = FALSE)
	check(H.survival_actions == 0, "cancelled action releases ownership")
	H.probe_incapacitated = FALSE
	spawn(0)
		do_mob(H, H, 3, progress = FALSE)
	sleep(1)
	check(H.survival_actions == 1, "do_mob starts activity")
	sleep(4)
	check(H.survival_actions == 0, "do_mob finishes activity")
	check(H.persistence_runtime_var("survival_rest_since"), "runtime clock exclusion")
	check(H.persistence_runtime_var("survival_actions"), "runtime actions exclusion")
	check(H.persistence_runtime_var("exercise_equipment"), "existing exclusion retained")
	check(H.persistence_runtime_var("parent_sentinel"), "parent exclusion retained")
	check(!H.persistence_runtime_var("nutrition"), "durable nutrition retained")
	text2file("PASS: idle metabolism, reengagement, heat, bed, SSD, traits, actions and exclusions", "result.txt")
	shutdown()
