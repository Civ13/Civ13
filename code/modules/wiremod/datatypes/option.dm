// A text restricted to the choices its port lists (/datum/port/input/options).
// The port refuses any other value; the editor shows the choices as a dropdown.
/datum/circuit_datatype/string/option
	datatype = PORT_TYPE_OPTION
	color = "violet"

/datum/circuit_datatype/string/option/ui_data(datum/port/input/port)
	return istype(port) ? port.options : null
