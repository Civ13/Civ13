// The circuit editor window: who may use it, the data it shows and the actions
// it may send. Everything a window sends is untrusted and is checked here.

/proc/wiremod_display_value(value)
	if(isnull(value))
		return "(unset)"
	if(islist(value))
		return "List ([length(value)] entries)"
	if(!isnum(value) && !istext(value))
		// An entity is shown by its name. The caller escapes it like any other text.
		value = wiremod_entity_name(value)
		if(isnull(value))
			return "(unset)"
	return copytext("[value]", 1, 101)

// Letters, digits, spaces and plain punctuation only: the result is shown in
// chat and examine text, which render HTML.
/proc/wiremod_clean_label(value, max_length)
	if(!istext(value))
		return ""
	var/static/regex/unsafe = regex(@"[^A-Za-z0-9 _.,:+-]", "g")
	return trim(copytext(unsafe.Replace(copytext(value, 1, 257), ""), 1, max_length + 1))

// A number field of a request, sent as a number or as its text: a finite
// number, or null.
/proc/wiremod_ui_number(value)
	if(istext(value))
		value = text2num(value)
	return wiremod_safe_number(value)

// A whole number from 1 to maximum, or 0.
/proc/wiremod_action_index(value, maximum)
	value = wiremod_ui_number(value)
	if(isnull(value) || value < 1 || value > maximum || value != round(value))
		return 0
	return value

// A yes/no field of a request; absent or unreadable is no.
/proc/wiremod_ui_flag(value)
	return wiremod_parse_boolean(value) ? TRUE : FALSE

/proc/wiremod_ui_coordinate(value, fallback = 0)
	value = wiremod_ui_number(value)
	if(isnull(value))
		return fallback
	return round(max(-10000, min(10000, value)))

// The editor's name for a port: its component's circuit_id and its position on
// that component. A component keeps its id for as long as it is in the circuit,
// so the name of a port does not change when another component is removed.
/proc/wiremod_ui_port_ref(datum/port/port)
	var/obj/item/circuit_component/component = port.connected_component
	if(!component?.circuit_id)
		return ""
	if(istype(port, /datum/port/output))
		return "output-[component.circuit_id]-[component.output_ports.Find(port)]"
	return "input-[component.circuit_id]-[component.input_ports.Find(port)]"

/proc/wiremod_ui_component_data(obj/item/circuit_component/component)
	var/list/input_data = list()
	for(var/datum/port/input/input_port as anything in component.input_ports)
		var/list/connected_to = list()
		if(input_port.connected_output)
			connected_to += wiremod_ui_port_ref(input_port.connected_output)
		// Everything about how a port looks comes from its datatype.
		var/datum/circuit_datatype/handler = input_port.datatype_handler
		var/list/port_view = list(
			"name" = input_port.name,
			"type" = input_port.datatype,
			"color" = handler.color,
			"ref" = wiremod_ui_port_ref(input_port),
			"connected_to" = connected_to,
			"current_data" = handler.ui_value(input_port.value)
		)
		var/datatype_data = handler.ui_data(input_port)
		if(!isnull(datatype_data))
			port_view["datatype_data"] = datatype_data
		input_data += list(port_view)
	var/list/output_data = list()
	for(var/datum/port/output/output_port as anything in component.output_ports)
		output_data += list(list(
			"name" = output_port.name,
			"type" = output_port.datatype,
			"color" = output_port.datatype_handler.color,
			"ref" = wiremod_ui_port_ref(output_port)
		))
	return list(
		"id" = component.circuit_id,
		"type" = "[component.type]",
		"name" = component.display_name,
		"description" = component.desc,
		"category" = component.category,
		"x" = component.rel_x,
		"y" = component.rel_y,
		"removable" = component.removable,
		"input_ports" = input_data,
		"output_ports" = output_data
	)

// The buttons under a component's description in the editor's info panel: one
// for each port, in the port's colour, naming its datatype.
/proc/wiremod_ui_component_notices(obj/item/circuit_component/component)
	var/list/notices = list()
	for(var/datum/port/input/input_port as anything in component.input_ports)
		notices += list(list("content" = "In: [input_port.name] ([input_port.datatype])", "color" = input_port.datatype_handler.color))
	for(var/datum/port/output/output_port as anything in component.output_ports)
		notices += list(list("content" = "Out: [output_port.name] ([output_port.datatype])", "color" = output_port.datatype_handler.color))
	return notices

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

// The one question every way into the editor asks.
/obj/item/integrated_circuit/proc/can_be_edited_by(mob/user)
	return user && wiremod_circuit_state.can_use_topic(src, user) == STATUS_INTERACTIVE

/obj/item/integrated_circuit/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if(!can_be_edited_by(user))
		return
	open_tgui(user, ui_key, "wiremod_circuit.tmpl", name, 760, 700, circuit_editor_data(), ui, force_open, wiremod_circuit_state, keep_interaction = TRUE)

/obj/item/integrated_circuit/proc/circuit_editor_data()
	var/list/component_data = list()
	var/list/variable_data = list()
	for(var/obj/item/circuit_component/component as anything in attached_components)
		component_data += list(wiremod_ui_component_data(component))
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
		"global_basic_types" = CIRCUIT_VARIABLE_TYPES,
		"variables" = variable_data,
		"is_admin" = FALSE,
		"component_catalog" = wiremod_ui_component_catalog(),
		"examined_name" = examined_component?.display_name,
		"examined_desc" = examined_component?.desc,
		"examined_notices" = examined_component ? wiremod_ui_component_notices(examined_component) : list(),
		"examined_rel_x" = examined_rel_x,
		"examined_rel_y" = examined_rel_y
	)

// Sends the circuit's current state to its open editors, at most once every
// CIRCUIT_UI_REFRESH_INTERVAL: a circuit that runs many times a second (a
// spammed remote, a delay loop) would otherwise send the whole editor each
// time. A refresh that comes too soon is held back by a timer, never dropped,
// so the editor always ends on the final state.
/obj/item/integrated_circuit/proc/refresh_editor()
	if(editor_refresh_timer || QDELETED(src))
		return
	if(world.time < next_editor_refresh)
		editor_refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh_editor_now)), next_editor_refresh - world.time, TIMER_STOPPABLE)
		return
	refresh_editor_now()

// Only a refresh that reached an open editor starts the interval, so a circuit
// nobody is looking at never holds a timer.
/obj/item/integrated_circuit/proc/refresh_editor_now()
	editor_refresh_timer = null
	if(GLOB.nanomanager?.update_uis(src))
		next_editor_refresh = world.time + CIRCUIT_UI_REFRESH_INTERVAL

// Every action the editor may send, in one table: the proc that handles it,
// then the fields it may carry. The window transport (code/modules/nano/tgui.dm)
// refuses any other action or field and any value that is not text or a number;
// everything else about a value is untrusted and is checked by the handler.
// A handler is named act_<action> and takes (list/params, mob/user).
/obj/item/integrated_circuit/proc/ui_action_table()
	var/static/list/table = list(
		"print_component" = list(PROC_REF(act_print_component), "component_to_print", "rel_x", "rel_y"),
		"detach_component" = list(PROC_REF(act_detach_component), "component_id"),
		"set_component_coordinates" = list(PROC_REF(act_set_component_coordinates), "component_id", "rel_x", "rel_y"),
		"add_connection" = list(PROC_REF(act_add_connection), "input_component_id", "input_port_id", "output_component_id", "output_port_id"),
		"remove_connection" = list(PROC_REF(act_remove_connection), "component_id", "is_input", "port_id"),
		"set_component_input" = list(PROC_REF(act_set_component_input), "component_id", "port_id", "input", "set_null", "marked_atom"),
		"get_component_value" = list(PROC_REF(act_get_component_value), "component_id", "port_id"),
		"move_screen" = list(PROC_REF(act_move_screen), "screen_x", "screen_y"),
		"toggle_grid_mode" = list(PROC_REF(act_toggle_grid_mode)),
		"set_display_name" = list(PROC_REF(act_set_display_name), "display_name"),
		"set_examined_component" = list(PROC_REF(act_set_examined_component), "component_id", "x", "y"),
		"remove_examined_component" = list(PROC_REF(act_remove_examined_component)),
		"add_variable" = list(PROC_REF(act_add_variable), "variable_name", "variable_datatype", "is_list", "is_assoc_list"),
		"remove_variable" = list(PROC_REF(act_remove_variable), "variable_name"),
		"add_setter_or_getter" = list(PROC_REF(act_add_setter_or_getter), "variable", "is_setter", "rel_x", "rel_y"),
	)
	return table

/obj/item/integrated_circuit/ui_actions(ui_key)
	. = list()
	for(var/action in ui_action_table())
		. += action

/obj/item/integrated_circuit/ui_action_fields(ui_key, action)
	var/list/entry = istext(action) ? ui_action_table()[action] : null
	return entry ? entry.Copy(2) : null

/obj/item/integrated_circuit/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if(!islist(params) || !can_be_edited_by(user))
		return TRUE
	var/list/entry = istext(action) ? ui_action_table()[action] : null
	if(entry)
		call(src, entry[1])(params, user)
	return TRUE

// The attached component a request names by its circuit_id, or null.
/obj/item/integrated_circuit/proc/ui_component(value)
	var/id = wiremod_action_index(value, last_component_id)
	return id ? component_by_id(id) : null

// The port a request names by its component's circuit_id and its own position
// on that component, or null.
/obj/item/integrated_circuit/proc/ui_port(component_value, port_value, is_output = FALSE)
	var/obj/item/circuit_component/component = ui_component(component_value)
	if(!component)
		return null
	var/list/ports = is_output ? component.output_ports : component.input_ports
	var/port_index = wiremod_action_index(port_value, length(ports))
	return port_index ? ports[port_index] : null

// The circuit variable a request names, or null. Only text is a name: a number
// would index the list by position instead.
/obj/item/integrated_circuit/proc/ui_variable(value)
	if(!istext(value) || !(value in circuit_variables))
		return null
	return circuit_variables[value]

// Makes a component for the editor and puts it where the request says. The
// caller chooses the type; nothing a window sends reaches `new`. A component
// made here is marked printed, so removing it deletes it: the editor cannot be
// used to produce items.
/obj/item/integrated_circuit/proc/ui_new_component(typepath, list/params, mob/user)
	if(length(attached_components) >= CIRCUIT_MAX_COMPONENTS)
		to_chat(user, "<span class='warning'>The circuit is at its component limit.</span>")
		return null
	var/obj/item/circuit_component/new_component = new typepath(src)
	new_component.printed = TRUE
	if(!add_component(new_component, user))
		qdel(new_component)
		return null
	new_component.rel_x = wiremod_ui_coordinate(params["rel_x"], new_component.rel_x)
	new_component.rel_y = wiremod_ui_coordinate(params["rel_y"], new_component.rel_y)
	return new_component

/obj/item/integrated_circuit/proc/act_print_component(list/params, mob/user)
	var/typepath
	if(istext(params["component_to_print"]))
		for(var/available_type in wiremod_available_components())
			if("[available_type]" == params["component_to_print"])
				typepath = available_type
				break
	if(!typepath)
		to_chat(user, "<span class='warning'>That circuit component is unavailable.</span>")
		return
	ui_new_component(typepath, params, user)

/obj/item/integrated_circuit/proc/act_detach_component(list/params, mob/user)
	detach_component(ui_component(params["component_id"]), user)

/obj/item/integrated_circuit/proc/act_set_component_coordinates(list/params, mob/user)
	var/obj/item/circuit_component/component = ui_component(params["component_id"])
	if(component)
		component.rel_x = wiremod_ui_coordinate(params["rel_x"], component.rel_x)
		component.rel_y = wiremod_ui_coordinate(params["rel_y"], component.rel_y)

/obj/item/integrated_circuit/proc/act_add_connection(list/params, mob/user)
	var/datum/port/input/input_port = ui_port(params["input_component_id"], params["input_port_id"])
	var/datum/port/output/output_port = ui_port(params["output_component_id"], params["output_port_id"], TRUE)
	if(!input_port || !output_port)
		return
	if(input_port.connected_output != output_port && !input_port.connect(output_port))
		to_chat(user, "<span class='warning'>Those circuit ports cannot be connected.</span>")

/obj/item/integrated_circuit/proc/act_remove_connection(list/params, mob/user)
	if(wiremod_ui_flag(params["is_input"]))
		var/datum/port/input/input_port = ui_port(params["component_id"], params["port_id"])
		input_port?.disconnect()
	else
		var/datum/port/output/output_port = ui_port(params["component_id"], params["port_id"], TRUE)
		output_port?.disconnect_all()

/obj/item/integrated_circuit/proc/act_set_component_input(list/params, mob/user)
	var/datum/port/input/input_port = ui_port(params["component_id"], params["port_id"])
	if(!input_port)
		return
	if(input_port.datatype == PORT_TYPE_SIGNAL)
		// Pressing a signal input fires it by hand.
		input_port.set_input(COMPONENT_SIGNAL)
	else if(input_port.connected_output)
		to_chat(user, "<span class='warning'>That input is wired to an output.</span>")
	else if(wiremod_ui_flag(params["marked_atom"]))
		mark_input(input_port, user)
	else if(wiremod_ui_flag(params["set_null"]))
		if(!input_port.options)
			input_port.set_input(null)
	else if(("input" in params) && (input_port.options || (input_port.datatype in CIRCUIT_USER_TYPES)))
		set_manual_input(input_port, params["input"], user)

// What a player marks when pressing an entity input: the item in a hand other
// than the circuit (or the remote it is built into), or the player with nothing
// else in hand. tgstation marks a thing with a multitool first; this is the
// Civ13 equivalent. A request never names the thing, so a player can only mark
// what they hold or themselves.
/obj/item/integrated_circuit/proc/marked_entity(mob/user)
	var/obj/item/own = istype(loc, /obj/item/compact_remote) ? loc : src
	for(var/obj/item/held in list(user.get_active_hand(), user.get_inactive_hand()))
		if(held != own && held != src)
			return held
	return user

// Sets an unwired input whose datatype takes one to what the player marks.
// Marking the thing an input already holds clears the input.
/obj/item/integrated_circuit/proc/mark_input(datum/port/input/input_port, mob/user)
	if(!input_port.datatype_handler.takes_marked_entity)
		to_chat(user, "<span class='warning'>That input does not take an entity.</span>")
		return
	var/atom/movable/marked = marked_entity(user)
	var/datum/weakref/handle = WEAKREF(marked)
	if(!handle)
		return
	if(input_port.value == handle)
		input_port.set_input(null)
		to_chat(user, "<span class='notice'>You clear [html_encode(input_port.name)].</span>")
		return
	input_port.set_input(handle)
	to_chat(user, "<span class='notice'>You mark [html_encode(marked.name)] as [html_encode(input_port.name)]. Hold something else in your other hand to mark that instead; mark the same thing again to clear the input.</span>")

// Sets an unwired input from what a player typed. The port's datatype reads the
// text; a value it cannot read is refused with that datatype's message.
/obj/item/integrated_circuit/proc/set_manual_input(datum/port/input/input_port, manual_value, mob/user)
	if(!isnum(manual_value) && !istext(manual_value))
		return FALSE
	if(istext(manual_value) && length(manual_value) > PORT_MAX_STRING_LENGTH)
		to_chat(user, "<span class='warning'>Input is too long.</span>")
		return FALSE
	var/parsed_value = input_port.datatype_handler.parse_manual(manual_value)
	if(isnull(parsed_value))
		to_chat(user, "<span class='warning'>[input_port.datatype_handler.manual_error]</span>")
		return FALSE
	input_port.set_input(parsed_value)
	return TRUE

/obj/item/integrated_circuit/proc/act_get_component_value(list/params, mob/user)
	var/datum/port/output/output_port = ui_port(params["component_id"], params["port_id"], TRUE)
	if(output_port)
		to_chat(user, "<span class='notice'>[html_encode(output_port.name)] value: [html_encode(wiremod_display_value(output_port.value))]</span>")

/obj/item/integrated_circuit/proc/act_move_screen(list/params, mob/user)
	screen_x = wiremod_ui_coordinate(params["screen_x"], screen_x)
	screen_y = wiremod_ui_coordinate(params["screen_y"], screen_y)

/obj/item/integrated_circuit/proc/act_toggle_grid_mode(list/params, mob/user)
	grid_mode = !grid_mode

/obj/item/integrated_circuit/proc/act_set_display_name(list/params, mob/user)
	display_name = wiremod_clean_label(params["display_name"], 32)
	name = length(display_name) ? "[initial(name)] ([display_name])" : initial(name)

/obj/item/integrated_circuit/proc/act_set_examined_component(list/params, mob/user)
	var/obj/item/circuit_component/component = ui_component(params["component_id"])
	if(component)
		examined_component = component
		examined_rel_x = wiremod_ui_coordinate(params["x"], 0)
		examined_rel_y = wiremod_ui_coordinate(params["y"], 0)

/obj/item/integrated_circuit/proc/act_remove_examined_component(list/params, mob/user)
	examined_component = null

/obj/item/integrated_circuit/proc/act_add_variable(list/params, mob/user)
	var/variable_name = wiremod_clean_label(params["variable_name"], 24)
	var/variable_datatype = params["variable_datatype"]
	if(!length(variable_name) || (variable_name in circuit_variables))
		to_chat(user, "<span class='warning'>Enter a new variable name using letters and digits.</span>")
	else if(!istext(variable_datatype) || !(variable_datatype in CIRCUIT_VARIABLE_TYPES))
		to_chat(user, "<span class='warning'>That variable type is unavailable.</span>")
	else if(length(circuit_variables) >= CIRCUIT_MAX_VARIABLES)
		to_chat(user, "<span class='warning'>The circuit is at its variable limit.</span>")
	else
		add_variable(variable_name, variable_datatype, wiremod_ui_flag(params["is_list"]) || wiremod_ui_flag(params["is_assoc_list"]))

/obj/item/integrated_circuit/proc/act_remove_variable(list/params, mob/user)
	var/datum/circuit_variable/variable = ui_variable(params["variable_name"])
	if(variable)
		remove_variable(variable)
	else
		to_chat(user, "<span class='warning'>That circuit variable no longer exists.</span>")

/obj/item/integrated_circuit/proc/act_add_setter_or_getter(list/params, mob/user)
	var/datum/circuit_variable/variable = ui_variable(params["variable"])
	if(!variable)
		to_chat(user, "<span class='warning'>That circuit variable no longer exists.</span>")
		return
	var/node_type = wiremod_ui_flag(params["is_setter"]) ? /obj/item/circuit_component/variable/setter : /obj/item/circuit_component/variable/getter
	var/obj/item/circuit_component/variable/node = ui_new_component(node_type, params, user)
	node?.bind(variable)
