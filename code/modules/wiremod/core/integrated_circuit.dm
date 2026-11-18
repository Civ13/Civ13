/proc/wiremod_available_components()
	return list(
		/obj/item/circuit_component/arithmetic,
		/obj/item/circuit_component/comparison,
		/obj/item/circuit_component/logic,
		/obj/item/circuit_component/length,
		/obj/item/circuit_component/random,
		/obj/item/circuit_component/list_index,
		/obj/item/circuit_component/list_concat,
		/obj/item/circuit_component/list_add,
		/obj/item/circuit_component/list_remove,
		/obj/item/circuit_component/string_concat,
		/obj/item/circuit_component/string_contains,
		/obj/item/circuit_component/string_case,
		/obj/item/circuit_component/string_replace,
		/obj/item/circuit_component/string_split,
		/obj/item/circuit_component/string_to_number,
		/obj/item/circuit_component/delay,
	)

/proc/wiremod_display_value(value)
	if(isnull(value))
		return "(unset)"
	if(islist(value))
		return "List ([length(value)] entries)"
	if(!isnum(value) && !istext(value))
		return "(unset)"
	return copytext("[value]", 1, 101)

// Letters, digits, spaces and plain punctuation only: the result is shown in
// chat and examine text, which render HTML.
/proc/wiremod_clean_label(value, max_length)
	if(!istext(value))
		return ""
	var/static/regex/unsafe = regex(@"[^A-Za-z0-9 _.,:+-]", "g")
	return trim(copytext(unsafe.Replace(copytext(value, 1, 257), ""), 1, max_length + 1))

/proc/wiremod_action_index(value, maximum)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value) || isnan(value) || value < 1 || value > maximum || value != round(value))
		return 0
	return value

/proc/wiremod_ui_boolean(value)
	if(isnum(value))
		return !!value
	if(istext(value))
		return lowertext(value) in list("true", "yes", "on", "1")
	return FALSE

/proc/wiremod_ui_coordinate(value, fallback = 0)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value) || isnan(value))
		return fallback
	return round(max(-10000, min(10000, value)))

/proc/wiremod_ui_port_color(port_type)
	if(port_type == PORT_TYPE_NUMBER)
		return "green"
	if(port_type == PORT_TYPE_BOOLEAN)
		return "yellow"
	if(port_type == PORT_TYPE_STRING)
		return "orange"
	if(port_type == PORT_TYPE_SIGNAL)
		return "purple"
	if(port_type == PORT_TYPE_LIST)
		return "grey"
	return "blue"

/proc/wiremod_ui_component_data(obj/item/circuit_component/component, component_index = 0, obj/item/integrated_circuit/circuit = null)
	var/list/input_data = list()
	for(var/port_index = 1, port_index <= length(component.input_ports), port_index++)
		var/datum/port/input/input_port = component.input_ports[port_index]
		var/list/connected_to = list()
		if(circuit && input_port.connected_output)
			var/output_ref = circuit.ui_port_reference(input_port.connected_output, TRUE)
			if(output_ref)
				connected_to += output_ref
		var/input_ref = component_index ? "input-[component_index]-[port_index]" : ""
		var/current_data
		if(isnum(input_port.value) || istext(input_port.value))
			current_data = input_port.value
		var/list/port_view = list(
			"name" = input_port.name,
			"type" = input_port.options ? PORT_TYPE_OPTION : input_port.datatype,
			"color" = wiremod_ui_port_color(input_port.datatype),
			"ref" = input_ref,
			"connected_to" = connected_to,
			"current_data" = current_data
		)
		if(input_port.options)
			port_view["datatype_data"] = input_port.options
		input_data += list(port_view)
	var/list/output_data = list()
	for(var/port_index = 1, port_index <= length(component.output_ports), port_index++)
		var/datum/port/output/output_port = component.output_ports[port_index]
		var/output_ref = component_index ? "output-[component_index]-[port_index]" : ""
		output_data += list(list(
			"name" = output_port.name,
			"type" = output_port.datatype,
			"color" = wiremod_ui_port_color(output_port.datatype),
			"ref" = output_ref
		))
	return list(
		"type" = "[component.type]",
		"name" = component.display_name,
		"description" = component.desc,
		"category" = component.category,
		"input_ports" = input_data,
		"output_ports" = output_data
	)

/proc/wiremod_ui_component_catalog()
	var/static/list/catalog
	if(catalog)
		return catalog
	catalog = list()
	for(var/typepath in wiremod_available_components())
		var/obj/item/circuit_component/prototype = new typepath()
		catalog += list(wiremod_ui_component_data(prototype))
		qdel(prototype)
	return catalog

// A living, conscious, unrestrained user holding the circuit (or the remote it
// is built into), or standing next to it while it lies on the ground.
/datum/topic_state/wiremod_circuit/can_use_topic(var/src_object, var/mob/user)
	if(!istype(user, /mob/living) || user.stat || user.restrained() || !istype(src_object, /obj/item/integrated_circuit))
		return STATUS_CLOSE
	var/obj/item/integrated_circuit/circuit = src_object
	var/obj/item/holder = circuit
	if(istype(circuit.loc, /obj/item/compact_remote))
		holder = circuit.loc
	if(holder.loc == user || (isturf(holder.loc) && holder.Adjacent(user)))
		return STATUS_INTERACTIVE
	return STATUS_CLOSE

/var/global/datum/topic_state/wiremod_circuit/wiremod_circuit_state = new()

/obj/item/integrated_circuit
	name = "integrated circuit"
	desc = "A programmable circuit board. Use it in hand to add components and connect their ports."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "integrated_circuit"
	w_class = ITEM_SIZE_SMALL
	// Components, ports and links are live graph state; circuits are not written to saves.
	should_save = FALSE

	var/list/obj/item/circuit_component/attached_components = list()
	var/list/datum/circuit_variable/circuit_variables = list()
	var/list/execution_queue = list()
	var/on = TRUE
	var/grid_mode = TRUE
	var/screen_x = 0
	var/screen_y = 0
	var/is_executing = FALSE
	// TRUE once a propagation tried to queue more than CIRCUIT_MAX_EXECUTIONS calls.
	var/queue_overflowed = FALSE
	// world.time until which an overloaded circuit ignores its inputs.
	var/overloaded_until = 0
	// The player's label, shown in the editor and after the item's name.
	var/display_name = ""
	var/obj/item/circuit_component/examined_component
	var/examined_rel_x = 0
	var/examined_rel_y = 0

/obj/item/integrated_circuit/Destroy()
	execution_queue.Cut()
	examined_component = null
	for(var/obj/item/circuit_component/component in attached_components.Copy())
		qdel(component)
	attached_components.Cut()
	for(var/variable_name in circuit_variables)
		qdel(circuit_variables[variable_name])
	circuit_variables.Cut()
	return ..()

/obj/item/integrated_circuit/proc/add_component(obj/item/circuit_component/component, mob/user)
	if(!istype(component) || component.parent || QDELETED(component) || QDELETED(src))
		return FALSE
	if(length(attached_components) >= CIRCUIT_MAX_COMPONENTS)
		if(user)
			to_chat(user, "<span class='warning'>The circuit is at its component limit.</span>")
		return FALSE
	component.disconnect()
	if(ismob(component.loc))
		var/mob/holder = component.loc
		holder.drop_from_inventory(component, src)
	if(component.loc != src)
		component.forceMove(src)
	component.parent = src
	attached_components += component
	component.rel_x = 48 + ((length(attached_components) - 1) * 24)
	component.rel_y = 64 + ((length(attached_components) - 1) * 24)
	return TRUE

// Unlinks a component. It stays inside the circuit unless a destination is
// given; the caller deletes it or hands it on.
/obj/item/integrated_circuit/proc/remove_component(obj/item/circuit_component/component, atom/destination = null)
	if(!component || component.parent != src)
		return FALSE
	if(examined_component == component)
		examined_component = null
	if(istype(component, /obj/item/circuit_component/variable))
		var/obj/item/circuit_component/variable/variable_component = component
		if(variable_component.circuit_variable)
			variable_component.circuit_variable.listeners -= variable_component
			variable_component.circuit_variable = null
	component.disconnect()
	attached_components -= component
	component.parent = null
	if(destination)
		component.forceMove(destination)
	return TRUE

// Takes a component out for a user. One made in the editor, and any variable
// node, is deleted; one inserted by hand goes back to the user.
/obj/item/integrated_circuit/proc/detach_component(obj/item/circuit_component/component, mob/user)
	if(!component || component.parent != src || !component.removable)
		return FALSE
	if(component.printed || istype(component, /obj/item/circuit_component/variable) || !user)
		qdel(component)
		return TRUE
	remove_component(component, get_turf(src))
	user.put_in_hands(component)
	return TRUE

// Runs a component call and everything it sets off, breadth first. The queue is
// never trimmed while it runs, so its length is the number of calls this
// propagation has made: at CIRCUIT_MAX_EXECUTIONS the rest is dropped and the
// circuit overloads, which is what stops a feedback loop.
/obj/item/integrated_circuit/proc/queue_input(datum/port/input/input_port)
	if(!on || world.time < overloaded_until || !input_port || input_port.connected_component?.parent != src)
		return
	if(length(execution_queue) >= CIRCUIT_MAX_EXECUTIONS)
		queue_overflowed = TRUE
		return
	execution_queue += input_port
	if(is_executing)
		return
	is_executing = TRUE
	var/position = 0
	var/exception/failure
	try
		while(position < length(execution_queue))
			position++
			var/datum/port/input/next_input = execution_queue[position]
			if(next_input?.connected_component?.parent == src)
				next_input.connected_component.trigger_component(next_input)
	catch(var/exception/caught)
		failure = caught
	// Always reset, so a runtime in one component cannot leave the circuit
	// queueing forever behind a stuck flag.
	execution_queue.Cut()
	is_executing = FALSE
	if(queue_overflowed)
		queue_overflowed = FALSE
		overload()
	if(GLOB.nanomanager)
		GLOB.nanomanager.update_uis(src)
	if(failure)
		throw failure

/obj/item/integrated_circuit/proc/overload()
	overloaded_until = world.time + CIRCUIT_OVERLOAD_COOLDOWN
	var/atom/holder = loc
	while(holder && !ismob(holder) && !isturf(holder))
		holder = holder.loc
	if(ismob(holder))
		to_chat(holder, "<span class='warning'>[src] overloads and goes quiet for a few seconds. Something in it is feeding back on itself.</span>")

/obj/item/integrated_circuit/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/circuit_component))
		var/obj/item/circuit_component/component = item
		if(add_component(component, user))
			to_chat(user, "<span class='notice'>You insert [component] into [src].</span>")
			if(GLOB.nanomanager)
				GLOB.nanomanager.update_uis(src)
			return TRUE
		return FALSE
	return ..()

/obj/item/integrated_circuit/attack_self(mob/user)
	ui_interact(user)

/obj/item/integrated_circuit/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if(!user || wiremod_circuit_state.can_use_topic(src, user) != STATUS_INTERACTIVE)
		return
	open_tgui(user, ui_key, "wiremod_circuit.tmpl", name, 760, 700, circuit_editor_data(), ui, force_open, wiremod_circuit_state, keep_interaction = TRUE)

/obj/item/integrated_circuit/proc/circuit_editor_data()
	var/list/component_data = list()
	var/list/stored_designs = list()
	var/list/variable_data = list()
	for(var/component_index = 1, component_index <= length(attached_components), component_index++)
		var/obj/item/circuit_component/component = attached_components[component_index]
		var/list/component_view = wiremod_ui_component_data(component, component_index, src)
		component_view["index"] = component_index
		component_view["x"] = component.rel_x
		component_view["y"] = component.rel_y
		component_view["removable"] = component.removable
		component_data += list(component_view)
	for(var/typepath in wiremod_available_components())
		stored_designs["[typepath]"] = TRUE
	for(var/variable_name in circuit_variables)
		var/datum/circuit_variable/variable = circuit_variables[variable_name]
		variable_data += list(list(
			"name" = variable.name,
			"datatype" = variable.datatype,
			"color" = variable.color,
			"is_list" = variable.is_list
		))
	return list(
		"on" = on,
		"display_name" = display_name,
		"grid_mode" = grid_mode,
		"screen_x" = screen_x,
		"screen_y" = screen_y,
		"components" = component_data,
		"stored_designs" = stored_designs,
		"global_basic_types" = list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY),
		"variables" = variable_data,
		"is_admin" = FALSE,
		"component_catalog" = wiremod_ui_component_catalog(),
		"examined_name" = examined_component?.display_name,
		"examined_desc" = examined_component?.desc,
		"examined_notices" = list(),
		"examined_rel_x" = examined_rel_x,
		"examined_rel_y" = examined_rel_y
	)

// Every action the editor may send. The window transport (code/modules/nano/tgui.dm)
// has already checked the action and field names and that each value is text or
// a number; everything else about them is untrusted and is checked in ui_act().
/obj/item/integrated_circuit/ui_actions(ui_key)
	return list(
		"print_component", "detach_component", "set_component_coordinates", "add_connection", "remove_connection",
		"set_component_input", "get_component_value", "move_screen", "toggle_grid_mode", "set_display_name",
		"set_examined_component", "remove_examined_component", "add_variable", "remove_variable",
		"add_setter_or_getter"
	)

/obj/item/integrated_circuit/ui_action_fields(ui_key, action)
	switch(action)
		if("detach_component")
			return list("component_id")
		if("print_component")
			return list("component_to_print", "rel_x", "rel_y")
		if("set_component_coordinates")
			return list("component_id", "rel_x", "rel_y")
		if("add_connection")
			return list("input_component_id", "input_port_id", "output_component_id", "output_port_id")
		if("remove_connection")
			return list("component_id", "is_input", "port_id")
		if("set_component_input")
			return list("component_id", "port_id", "input", "set_null", "marked_atom")
		if("get_component_value")
			return list("component_id", "port_id")
		if("move_screen")
			return list("screen_x", "screen_y")
		if("set_display_name")
			return list("display_name")
		if("set_examined_component")
			return list("component_id", "x", "y")
		if("add_variable")
			return list("variable_name", "variable_datatype", "is_list", "is_assoc_list")
		if("remove_variable")
			return list("variable_name")
		if("add_setter_or_getter")
			return list("variable", "is_setter", "rel_x", "rel_y")
	return null

// The attached component a request names by its position, or null.
/obj/item/integrated_circuit/proc/ui_component(value)
	var/component_index = wiremod_action_index(value, length(attached_components))
	if(!component_index)
		return null
	return attached_components[component_index]

// The circuit variable a request names, or null. Only text is a name: a number
// would index the list by position instead.
/obj/item/integrated_circuit/proc/ui_variable(value)
	if(!istext(value) || !(value in circuit_variables))
		return null
	return circuit_variables[value]

/obj/item/integrated_circuit/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if(!islist(params) || !user || wiremod_circuit_state.can_use_topic(src, user) != STATUS_INTERACTIVE)
		return TRUE
	switch(action)
		if("toggle_grid_mode")
			grid_mode = !grid_mode
		if("print_component")
			var/typepath
			if(istext(params["component_to_print"]))
				for(var/available_type in wiremod_available_components())
					if("[available_type]" == params["component_to_print"])
						typepath = available_type
						break
			if(!typepath)
				to_chat(user, "<span class='warning'>That circuit component is unavailable.</span>")
			else if(length(attached_components) >= CIRCUIT_MAX_COMPONENTS)
				to_chat(user, "<span class='warning'>The circuit is at its component limit.</span>")
			else
				var/obj/item/circuit_component/new_component = new typepath(src)
				new_component.printed = TRUE
				if(add_component(new_component, user))
					new_component.rel_x = wiremod_ui_coordinate(params["rel_x"], new_component.rel_x)
					new_component.rel_y = wiremod_ui_coordinate(params["rel_y"], new_component.rel_y)
				else
					qdel(new_component)
		if("detach_component")
			detach_component(ui_component(params["component_id"]), user)
		if("set_component_coordinates")
			var/obj/item/circuit_component/component = ui_component(params["component_id"])
			if(component)
				component.rel_x = wiremod_ui_coordinate(params["rel_x"], component.rel_x)
				component.rel_y = wiremod_ui_coordinate(params["rel_y"], component.rel_y)
		if("add_connection")
			var/obj/item/circuit_component/input_component = ui_component(params["input_component_id"])
			var/obj/item/circuit_component/output_component = ui_component(params["output_component_id"])
			if(input_component && output_component)
				var/input_port_index = wiremod_action_index(params["input_port_id"], length(input_component.input_ports))
				var/output_port_index = wiremod_action_index(params["output_port_id"], length(output_component.output_ports))
				if(input_port_index && output_port_index)
					var/datum/port/input/input_port = input_component.input_ports[input_port_index]
					var/datum/port/output/output_port = output_component.output_ports[output_port_index]
					if(input_port.connected_output != output_port && !input_port.connect(output_port))
						to_chat(user, "<span class='warning'>Those circuit ports cannot be connected.</span>")
		if("remove_connection")
			var/obj/item/circuit_component/component = ui_component(params["component_id"])
			if(component)
				var/is_input = wiremod_ui_boolean(params["is_input"])
				var/port_index = wiremod_action_index(params["port_id"], is_input ? length(component.input_ports) : length(component.output_ports))
				if(port_index && is_input)
					var/datum/port/input/input_port = component.input_ports[port_index]
					input_port.disconnect()
				else if(port_index)
					var/datum/port/output/output_port = component.output_ports[port_index]
					output_port.disconnect_all()
		if("set_component_input")
			var/obj/item/circuit_component/component = ui_component(params["component_id"])
			if(component)
				var/port_index = wiremod_action_index(params["port_id"], length(component.input_ports))
				if(port_index)
					var/datum/port/input/input_port = component.input_ports[port_index]
					if(wiremod_ui_boolean(params["marked_atom"]))
						to_chat(user, "<span class='warning'>Entity inputs are not available in core circuits.</span>")
					else if(input_port.datatype == PORT_TYPE_SIGNAL)
						// Pressing a signal input fires it by hand.
						input_port.set_input(COMPONENT_SIGNAL)
					else if(input_port.connected_output)
						to_chat(user, "<span class='warning'>That input is wired to an output.</span>")
					else if(wiremod_ui_boolean(params["set_null"]))
						if(!input_port.options)
							input_port.set_input(null)
					else if((input_port.datatype in list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY)) && ("input" in params))
						set_manual_input(input_port, params["input"], user)
		if("get_component_value")
			var/obj/item/circuit_component/component = ui_component(params["component_id"])
			if(component)
				var/port_index = wiremod_action_index(params["port_id"], length(component.output_ports))
				if(port_index)
					var/datum/port/output/output_port = component.output_ports[port_index]
					to_chat(user, "<span class='notice'>[html_encode(output_port.name)] value: [html_encode(wiremod_display_value(output_port.value))]</span>")
		if("move_screen")
			screen_x = wiremod_ui_coordinate(params["screen_x"], screen_x)
			screen_y = wiremod_ui_coordinate(params["screen_y"], screen_y)
		if("set_display_name")
			display_name = wiremod_clean_label(params["display_name"], 32)
			name = length(display_name) ? "[initial(name)] ([display_name])" : initial(name)
		if("set_examined_component")
			var/obj/item/circuit_component/component = ui_component(params["component_id"])
			if(component)
				examined_component = component
				examined_rel_x = wiremod_ui_coordinate(params["x"], 0)
				examined_rel_y = wiremod_ui_coordinate(params["y"], 0)
		if("remove_examined_component")
			examined_component = null
		if("add_variable")
			var/variable_name = wiremod_clean_label(params["variable_name"], 24)
			var/variable_datatype = params["variable_datatype"]
			if(!length(variable_name) || (variable_name in circuit_variables))
				to_chat(user, "<span class='warning'>Enter a new variable name using letters and digits.</span>")
			else if(!istext(variable_datatype) || !(variable_datatype in list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY)))
				to_chat(user, "<span class='warning'>That variable type is unavailable.</span>")
			else if(length(circuit_variables) >= CIRCUIT_MAX_VARIABLES)
				to_chat(user, "<span class='warning'>The circuit is at its variable limit.</span>")
			else
				var/is_list = wiremod_ui_boolean(params["is_list"]) || wiremod_ui_boolean(params["is_assoc_list"])
				circuit_variables[variable_name] = new /datum/circuit_variable(variable_name, variable_datatype, is_list)
		if("remove_variable")
			var/datum/circuit_variable/variable = ui_variable(params["variable_name"])
			if(variable)
				for(var/obj/item/circuit_component/variable/variable_component in attached_components.Copy())
					if(variable_component.circuit_variable == variable)
						qdel(variable_component)
				circuit_variables -= variable.name
				qdel(variable)
			else
				to_chat(user, "<span class='warning'>That circuit variable no longer exists.</span>")
		if("add_setter_or_getter")
			var/datum/circuit_variable/variable = ui_variable(params["variable"])
			if(!variable)
				to_chat(user, "<span class='warning'>That circuit variable no longer exists.</span>")
			else if(length(attached_components) >= CIRCUIT_MAX_COMPONENTS)
				to_chat(user, "<span class='warning'>The circuit is at its component limit.</span>")
			else
				var/is_setter = wiremod_ui_boolean(params["is_setter"])
				var/obj/item/circuit_component/variable/variable_component
				if(is_setter)
					var/obj/item/circuit_component/variable/setter/setter_component = new(src)
					setter_component.value_input.set_datatype(variable.port_datatype)
					variable_component = setter_component
					variable_component.display_name = "Setter: [variable.name]"
				else
					var/obj/item/circuit_component/variable/getter/getter_component = new(src)
					getter_component.value_output.set_datatype(variable.port_datatype)
					variable_component = getter_component
					variable_component.display_name = "Getter: [variable.name]"
				variable_component.printed = TRUE
				if(add_component(variable_component, user))
					variable_component.circuit_variable = variable
					variable_component.rel_x = wiremod_ui_coordinate(params["rel_x"], variable_component.rel_x)
					variable_component.rel_y = wiremod_ui_coordinate(params["rel_y"], variable_component.rel_y)
					if(!is_setter)
						variable.listeners += variable_component
						var/obj/item/circuit_component/variable/getter/added_getter = variable_component
						added_getter.value_output.set_output(variable.value)
				else
					qdel(variable_component)
	return TRUE

/obj/item/integrated_circuit/proc/set_manual_input(datum/port/input/input_port, manual_value, mob/user)
	if(istext(manual_value) && length(manual_value) > PORT_MAX_STRING_LENGTH)
		to_chat(user, "<span class='warning'>Input is too long.</span>")
		return FALSE
	if(input_port.datatype == PORT_TYPE_NUMBER)
		if(istext(manual_value))
			manual_value = text2num(manual_value)
		if(isnull(wiremod_safe_number(manual_value)))
			to_chat(user, "<span class='warning'>Enter a valid number.</span>")
			return FALSE
	else if(input_port.datatype == PORT_TYPE_BOOLEAN)
		if(isnum(manual_value))
			manual_value = !!manual_value
		else if(istext(manual_value))
			manual_value = lowertext(manual_value)
			if(!(manual_value in list("true", "false", "yes", "no", "on", "off", "1", "0")))
				to_chat(user, "<span class='warning'>Enter true or false.</span>")
				return FALSE
		else
			return FALSE
	else if(input_port.datatype == PORT_TYPE_ANY)
		if(istext(manual_value))
			var/numeric_value = wiremod_safe_number(text2num(manual_value))
			if(!isnull(numeric_value) && "[numeric_value]" == manual_value)
				manual_value = numeric_value
		else if(!isnull(manual_value) && !isnum(manual_value))
			manual_value = "[manual_value]"
	else if(input_port.datatype == PORT_TYPE_STRING && !istext(manual_value))
		manual_value = "[manual_value]"
	input_port.set_input(manual_value)
	return TRUE

/obj/item/integrated_circuit/proc/ui_port_reference(datum/port/target_port, is_output)
	if(!target_port)
		return null
	for(var/component_index = 1, component_index <= length(attached_components); component_index++)
		var/obj/item/circuit_component/component = attached_components[component_index]
		if(component != target_port.connected_component)
			continue
		var/list/ports = is_output ? component.output_ports : component.input_ports
		for(var/port_index = 1, port_index <= length(ports); port_index++)
			if(ports[port_index] == target_port)
				var/direction = is_output ? "output" : "input"
				return "[direction]-[component_index]-[port_index]"
	return null

/datum/circuit_variable
	should_save = FALSE
	var/name
	var/datatype
	var/port_datatype
	var/color
	var/value
	var/is_list = FALSE
	var/list/obj/item/circuit_component/variable/getter/listeners = list()

/datum/circuit_variable/New(variable_name, variable_datatype, variable_is_list = FALSE)
	. = ..()
	name = variable_name
	datatype = variable_datatype
	is_list = variable_is_list
	port_datatype = is_list ? PORT_TYPE_LIST : datatype
	color = wiremod_ui_port_color(port_datatype)
	if(is_list)
		value = list()

/datum/circuit_variable/proc/set_value(new_value)
	if(port_datatype == PORT_TYPE_LIST && !islist(new_value))
		return FALSE
	// The list handler returns a bounded copy, so the variable never shares a
	// list with the port that set it.
	var/datum/circuit_datatype/handler = circuit_datatype_for(port_datatype)
	value = handler.convert(new_value)
	for(var/obj/item/circuit_component/variable/getter/listener as anything in listeners.Copy())
		if(listener.parent)
			listener.value_output.set_output(value)
	return TRUE

/datum/circuit_variable/Destroy()
	listeners.Cut()
	value = null
	return ..()

/obj/item/circuit_component/variable
	display_name = "Variable"
	category = "Utility"

	var/datum/circuit_variable/circuit_variable

/obj/item/circuit_component/variable/getter
	display_name = "Variable Getter"

	var/datum/port/output/value_output

/obj/item/circuit_component/variable/getter/populate_ports()
	value_output = add_output_port("Value", PORT_TYPE_ANY)

/obj/item/circuit_component/variable/getter/Destroy()
	if(circuit_variable)
		circuit_variable.listeners -= src
		circuit_variable = null
	return ..()

/obj/item/circuit_component/variable/setter
	display_name = "Variable Setter"

	var/datum/port/input/value_input

/obj/item/circuit_component/variable/setter/populate_ports()
	value_input = add_input_port("Input", PORT_TYPE_ANY, trigger = PROC_REF(set_variable))

/obj/item/circuit_component/variable/setter/proc/set_variable(datum/port/input/input_port)
	if(circuit_variable)
		circuit_variable.set_value(input_port.value)

/obj/item/circuit_component/variable/setter/Destroy()
	circuit_variable = null
	return ..()

/obj/item/integrated_circuit/examine(mob/user)
	. = ..()
	to_chat(user, "It contains [length(attached_components)] component[length(attached_components) == 1 ? "" : "s"].")
	if(length(display_name))
		to_chat(user, "It is labelled \"[display_name]\".")
