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
	// Every output reads the same clock text, so the numbers always match what
	// Time Format shows, whatever time zone the host keeps.
	var/clock = time2text(station_time_in_ticks, "hh:mm:ss")
	format_output.set_output(wiremod_safe_text(clock))
	switch(unit_input.value)
		if("Hours")
			unit_output.set_output(wiremod_safe_number(text2num(copytext(clock, 1, 3))))
		if("Minutes")
			unit_output.set_output(wiremod_safe_number(text2num(copytext(clock, 4, 6))))
		else
			unit_output.set_output(wiremod_safe_number(text2num(copytext(clock, 7, 9))))
