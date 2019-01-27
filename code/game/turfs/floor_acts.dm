/turf/floor/ex_act(severity)
	var/area/src_area = get_area(src)
	if (src_area && src_area.type == /area/caribbean/void)
		return
	switch(severity)
		if (1.0)
			make_grass()
		if (2.0)
			if (prob(75))
				make_grass()
			else
				break_tile()
				hotspot_expose(1000,CELL_VOLUME)
		if (3.0)
			if (prob(50))
				break_tile()
				hotspot_expose(1000,CELL_VOLUME)
	return

/turf/floor/fire_act(temperature)

	var/temp_destroy = get_damage_temperature()
	if (!burnt && prob(5))
		burn_tile(temperature)
	else if (temp_destroy && temperature >= (temp_destroy + 100) && prob(1) && !is_plating())
		make_plating() //destroy the tile, exposing plating
		burn_tile(temperature)
	return

//should be a little bit lower than the temperature required to destroy the material
/turf/floor/proc/get_damage_temperature()
	return flooring ? flooring.damage_temperature : null
