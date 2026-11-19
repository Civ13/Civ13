/obj/item/circuit_component/timepiece
	name = "timepiece component"
	display_name = "Timepiece"
	category = "Utility"
	desc = "Reads the station clock. Time Format gives the whole time as hours, minutes and seconds, and Unit of Time gives the chosen part on its own. It reads again whenever Unit changes."

	var/datum/port/input/unit_input
	var/datum/port/output/format_output
	var/datum/port/output/unit_output

/obj/item/circuit_component/timepiece/populate_ports()
	var/list/units = list("Seconds", "Minutes", "Hours")
	unit_input = add_input_port("Unit", PORT_TYPE_OPTION, default = units[1], options = units, trigger = PROC_REF(read_clock))
	format_output = add_output_port("Time Format", PORT_TYPE_STRING)
	unit_output = add_output_port("Unit of Time", PORT_TYPE_NUMBER)
	read_clock()

/obj/item/circuit_component/timepiece/added_to_circuit(obj/item/integrated_circuit/circuit)
	read_clock()

/obj/item/circuit_component/timepiece/proc/read_clock(datum/port/input/input)
	var/ticks = station_time_in_ticks
	format_output.set_output(wiremod_safe_text(time2text(ticks, "hh:mm:ss")))
	switch(unit_input.value)
		if("Hours")
			unit_output.set_output(wiremod_safe_number(round(ticks / 36000) % 24))
		if("Minutes")
			unit_output.set_output(wiremod_safe_number(round((ticks / 600) % 60)))
		else
			unit_output.set_output(wiremod_safe_number(round((ticks / 10) % 60)))
