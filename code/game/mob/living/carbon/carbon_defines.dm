/mob/living/human
	gender = MALE
	var/datum/species/species //Contains icon generation and language information, set during New().
	var/list/stomach_contents = list() // mob/living in stomach, not a food 
	var/list/datum/disease2/disease/virus2 = list() //was a virus mechanics, in fact are removed (partially) from code //TO DO TODO: Totally remove, or fix
	var/list/antibodies = list() //was an antibodies mechanics, in fact are removed (partially) from code //TO DO TODO: Totally remove, or fix
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
	var/list/addictions = list("cocaine" = 0, "opium" = 0, "alcohol" = 0, "tobacco" = 0)
	var/nutrition = 400.0 // hunger in some units... 
	var/max_nutrition = 400.0
	var/water = 350.0 // thirst in some units... 
	var/max_water = 350.0
