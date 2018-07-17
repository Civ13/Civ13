/obj/plane_part

/obj/plane_part/proc/my_name()
	return "REPLACE THIS: /obj/plane_part/my_name() for [type]"

/obj/plane_part/proc/plane_message()
	return "DELETE THIS PROCEDURE!: /obj/plant_part/proc/plane_message()"

/obj/plane_part/proc/health_percentage_num()
	if (vars.Find("damage"))
		if (vars.Find("max_damage"))
			return (round(src:damage/src:max_damage)*100)
	else
		if (vars.Find("master") && src:master.vars.Find("damage"))
			if (src:master.vars.Find("max_damage"))
				return (round(plane:damage/plane:max_damage)*100)
	return 100

/obj/plane_part/proc/health_percentage()
	return "[health_percentage_num()]%"