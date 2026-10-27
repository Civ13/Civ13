//	Observer Pattern Implementation: Stat Set
//		Registration type: /mob/living
//
//		Raised when: A /mob/living changes stat, using the set_stat() proc
//
//		Arguments that the called proc should expect:
//			/mob/living/stat_mob: The mob whose stat changed
//			/old_stat: Status before the change.
//			/new_stat: Status after the change.

GLOBAL_DATUM_INIT(stat_set_event, /decl/observ/stat_set, new)

/decl/observ/stat_set
	name = "Stat Set"
	expected_type = /mob/living

/****************
* Stat Handling *
****************/
/mob/living/set_stat(var/new_stat)
	var/old_stat = stat
	. = ..()
	if(stat != old_stat)
		GLOB.stat_set_event.raise_event(src, old_stat, new_stat)

//	Observer Pattern Implementation: Name Set
//		Registration type: /atom
//
//		Raised when: An atom's name changes.
//
//		Arguments that the called proc should expect:
//			/atom/namee:  The atom that had its name set
//			/old_name: name before the change
//			/new_name: name after the change

GLOBAL_DATUM_INIT(name_set_event, /decl/observ/name_set, new)

/decl/observ/name_set
	name = "Name Set"
	expected_type = /atom

/*********************
* Name Set Handling *
*********************/

/atom/proc/SetName(var/new_name)
	var/old_name = name
	if(old_name != new_name)
		name = new_name
		if(has_extension(src, /datum/extension/labels))
			var/datum/extension/labels/L = get_extension(src, /datum/extension/labels)
			name = L.AppendLabelsToName(name)
		GLOB.name_set_event.raise_event(src, old_name, new_name)
