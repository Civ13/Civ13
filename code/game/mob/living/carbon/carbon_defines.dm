/mob/living/human
	gender = MALE
	var/datum/species/species //Contains icon generation and language information, set during New().
	var/list/stomach_contents = list() // mob/living in stomach, not a food 
	var/life_tick = 0 // The amount of life ticks that have processed on this mob.
	var/analgesic = FALSE // when this is set, the mob isn't affected by shock or pain
	var/obj/item/handcuffed = null //An item that is handcuffed or null if not handcuffed
	var/obj/item/legcuffed = null  //Same as handcuffs but for legs. Bear traps use this.
	var/datum/surgery_status/op_stage = new/datum/surgery_status //Surgery info
	var/pose = null //Active emote/pose
	var/list/chem_effects = list() 
	var/datum/reagents/metabolism/bloodstr = null
	var/datum/reagents/metabolism/ingested = null
	var/datum/reagents/metabolism/touching = null 
	var/losebreath = FALSE //if we failed to breathe last tick
	var/mood = 100 //Morale. At a value between 40 and 60, the stat has no positive bonuses or negative penalties.
	var/coughedtime = FALSE
	var/lastpuke = FALSE
	var/cpr_time = TRUE
	var/list/addictions = list("opioid" = 0, "stimulant" = 0, "nicotine" = 0, "cannabis" = 0, "caffeine" = 0, "alcohol" = 0)
	var/nutrition = 600.0 // hunger in some units; workload and climate set the drain (human_life.dm)
	var/max_nutrition = 600.0
	var/water = 500.0 // thirst in some units
	var/max_water = 500.0
