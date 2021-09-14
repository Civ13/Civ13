//from https://github.com/Persistent-SS13/Persistent-SS13/blob/master/code/modules/world_save/Map%20Storage.dm
//7-september-2021

//////////////////////////////////
///PERSISTENCE STUFF/////////////
/////////////////////////////////

#define TICK_LIMIT_RUNNING 90
#define TICK_LIMIT_TO_RUN 85

#define TICK_CHECK ( world.tick_usage > TICK_LIMIT_RUNNING ? stoplag() : 0 )

//needs to be defined for some atoms
/datum/proc/after_load()
	return
/datum/proc/before_save()
	return

/datum/proc/get_saved_vars()
	var/list/to_save = list()
	var/partial = FALSE

	if (!istype(src, /mob) && ((istype(src, /turf) || istype(src, /obj/structure/wild) || (!istype(src, /obj/item) && !istype(src, /obj/structure) && !istype(src, /obj/map_metadata) && !istype(src, /obj/covers)))))
		partial = TRUE
	if (istype(src, /datum) && !istype(src, /mob) && !istype(src, /obj) && !istype(src, /turf))
		partial = FALSE
	if (partial)
		to_save |= params2list(map_storage_saved_vars)
	else
		for (var/key in src.vars)
			if (src.vars[key] != initial(src.vars[key]) && key != "verbs" && key != "locs" && key != "group")
				to_save |= key
			to_save |= "name"
	return to_save

var/map_storage/map_storage = new("SS13")

/proc/string_explode(var/string, var/separator = "")
	//writepanic("[__FILE__].[__LINE__] \\/proc/string_explode() called tick#: [world.time]")
	if(istext(string) && (istext(separator) || isnull(separator)))
		return splittext(string, separator)
        
/proc/start_watch()
	return TimeOfGame

/proc/stop_watch(wh)
	return round(0.1 * (TimeOfGame - wh), 0.1)

/proc/log_startup_progress(var/message)
	to_chat(world, "<span class='danger'>[message]</span>")

//Key thing that stops lag. Cornerstone of performance in ss13, Just sitting here, in unsorted.dm.
/proc/stoplag()
	. = 1
	sleep(world.tick_lag)
	if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, still not enough tick, sleep for more.
		. += 2
		sleep(world.tick_lag*2)
		if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, STILL not enough tick, sleep for more.
			. += 4
			sleep(world.tick_lag*4)
			//you might be thinking of adding more steps to this, or making it use a loop and a counter var
			//	not worth it.

/*************************************************************************
ATOM ADDITIONS
**************************************************************************/
datum
	var
		load_contents = 0
		should_save = 1
		map_storage_saved_vars = ""
		safe_list_vars = ""
atom
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;id"
	load_contents = 1
/*************************************************************************
MAP STORAGE DATUM
**************************************************************************/
map_storage

	var
		// These are atom types for the map saver to ignore. Objects of these type will
		// not be saved with everything else.
		list/ignore_types = list(/mob/new_player, /atom/movable/lighting_overlay)

		// This text string is tacked onto all saved passwords so that their md5 values
		// will be different than what the password's hash would normally be, providing
		// a bit of extra protection against md5 hash directories.
		game_id = "SS13"

		// INTERNAL VARIABLES - SHOULD NOT BE ALTERED BY USERS

		// List of object types. This will be converted to params and encrypted when saved.
		list/object_reference = list()
		list/obj_references = list()
		list/existing_references = list()
		list/saving_references = list()
		list/all_loaded = list()
		list/found_types = list()
		var/per_pause = 200
		var/so_far = 0
	New(game_id, backdoor, ignore)
		..()
		if(game_id)
			src.game_id = game_id
		if(ignore)
			src.ignore_types = ignore
		return

// Returns true if the value is purely numeric, return false if there are non-numeric
// characters contained within the text string.
/map_storage/proc/IsNumeric(text)
	if(isnum(text))
		return 1
	for(var/n in 1 to length(text))
		var/ascii = text2ascii(text, n)
		if(ascii < 45 || ascii > 57)
			return 0
		if(ascii == 47)
			return 0
	return 1

// If the value is numeric, convert it to a number and return the number value. If
// the value is text, then return it as it is.
/map_storage/proc/Numeric(text)
	if(islist(text))
		return text
	if(IsNumeric(text))
		return text2num(text)
	else
		if(findtext(text, "e+"))
			var/list/nums = string_explode(text, "e+")
			if(nums.len > 1 && nums.len < 3)
				var/integer = text2num(nums[1])
				var/exp = text2num(nums[2])
				if(IsNumeric(integer) && IsNumeric(exp))
					return integer*10**exp
		return text

	// This is called when loading a map after all the verification and
	// password stuff is completed so that the map can have a fresh template
	// to work with.
/map_storage/proc/ClearMap()
	sleep(1)
	world.log << "Clearing mobs..."
	for (var/mob/mob in world)
		if (!istype(mob, /mob/new_player))
			qdel(mob)
	sleep(1)
	world.log << "Clearing objects..."
	for (var/obj/object in world)
		qdel(object)
	return

/datum/data/record
	var/name = "record"
	var/size = 5.0
	var/list/fields = list(  )
	map_storage_saved_vars = "fields"
	safe_list_vars = "fields"
//////////////////////////////////////////
//////////////////GAMETICKER/////////////
//////////////////////////////////////////

/datum/controller/gameticker/proc/savemap()
	var/watch = start_watch()
	to_chat(world, "<FONT color='yellow'><B>SAVING THE MAP! THIS USUALLY TAKES UNDER A MINUTE</B></FONT>")
	sleep(5)
	map_storage.Save_World()
	log_startup_progress("	Saved the map in [stop_watch(watch)]s.")
	return 1

/datum/controller/gameticker/proc/loadmap()
	var/watch = start_watch()
	var/started = 0
	log_startup_progress("Starting map load...")
	sleep(1)
	map_storage.ClearMap()
	sleep(1)
	map_storage.Load_World()
	if(started)
		log_startup_progress("	Loaded the map in [stop_watch(watch)]s.")
	return 1