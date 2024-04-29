/datum/extension
	var/datum/holder = null // The holder
	var/expected_type = /datum
	var/flags = EXTENSION_FLAG_NONE

/datum/extension/New(var/datum/holder)
	if(!istype(holder, expected_type))
		CRASH("Invalid holder type. Expected [expected_type], was [holder.type]")
	src.holder = holder

/datum/extension/Destroy()
	holder = null
	. = ..()

/datum/var/list/datum/extension/extensions

/datum/Destroy()
	if(extensions)
		for(var/expansion_key in extensions)
			var/list/extension = extensions[expansion_key]
			if(islist(extension))
				extension.Cut()
			else
				qdel(extension)
		extensions = null
	return ..()

//Variadic - Additional positional arguments can be given. Named arguments might not work so well
/proc/set_extension(var/datum/source, var/datum/extension/base_type, var/extension_type)
	if(!source.extensions)
		source.extensions = list()
	var/datum/extension/existing_extension = source.extensions[base_type]
	if(istype(existing_extension))
		qdel(existing_extension)

	if(initial(base_type.flags) & EXTENSION_FLAG_IMMEDIATE)
		. = construct_extension_instance(extension_type, source, args.Copy(4))
		source.extensions[base_type] = .
	else
		var/list/extension_data = list(extension_type, source)
		if(args.len > 3)
			extension_data += args.Copy(4)
		source.extensions[base_type] = extension_data

/proc/get_extension(var/datum/source, var/base_type)
	if(!source.extensions)
		return
	. = source.extensions[base_type]
	if(!.)
		return
	if(islist(.)) //a list, so it's expecting to be lazy-loaded
		var/list/extension_data = .
		. = construct_extension_instance(extension_data[1], extension_data[2], extension_data.Copy(3))
		source.extensions[base_type] = .

//Fast way to check if it has an extension, also doesn't trigger instantiation of lazy loaded extensions
/proc/has_extension(var/datum/source, var/base_type)
	return (source.extensions && source.extensions[base_type])

/proc/construct_extension_instance(var/extension_type, var/datum/source, var/list/arguments)
	arguments = list(source) + arguments
	return new extension_type(arglist(arguments))

/datum/extension/labels
	var/atom/atom_holder
	var/list/labels

/datum/extension/labels/New()
	..()
	atom_holder = holder

/datum/extension/labels/Destroy()
	atom_holder = null
	return ..()

/datum/extension/labels/proc/AttachLabel(var/mob/user, var/label)
	if(!CanAttachLabel(user, label))
		return

	if(!LAZYLEN(labels))
		atom_holder.verbs += /atom/proc/RemoveLabel
	LAZYADD(labels, label)

	user.visible_message("<span class='notice'>\The [user] attaches a label to \the [atom_holder].</span>", \
						 "<span class='notice'>You attach a label, '[label]', to \the [atom_holder].</span>")

	var/old_name = atom_holder.name
	atom_holder.name = "[atom_holder.name] ([label])"
	GLOB.name_set_event.raise_event(src, old_name, atom_holder.name)

/datum/extension/labels/proc/RemoveLabel(var/mob/user, var/label)
	if(!(label in labels))
		return

	LAZYREMOVE(labels, label)
	if(!LAZYLEN(labels))
		atom_holder.verbs -= /atom/proc/RemoveLabel

	var/full_label = " ([label])"
	var/index = findtextEx(atom_holder.name, full_label)
	if(!index) // Playing it safe, something might not have set the name properly
		return

	user.visible_message("<span class='notice'>\The [user] removes a label from \the [atom_holder].</span>", \
						 "<span class='notice'>You remove a label, '[label]', from \the [atom_holder].</span>")

	var/old_name = atom_holder.name
	// We find and replace the first instance, since that's the one we removed from the list
	atom_holder.name = replacetext(atom_holder.name, full_label, "", index, index + length(full_label))
	GLOB.name_set_event.raise_event(src, old_name, atom_holder.name)

// We may have to do something more complex here
// in case something appends strings to something that's labelled rather than replace the name outright
// Non-printable characters should be of help if this comes up
/datum/extension/labels/proc/AppendLabelsToName(var/name)
	if(!LAZYLEN(labels))
		return name
	. = list(name)
	for(var/entry in labels)
		. += " ([entry])"
	. = jointext(., null)

/datum/extension/labels/proc/CanAttachLabel(var/user, var/label)
	if(!length(label))
		return FALSE
	if(ExcessLabelLength(label, user))
		return FALSE
	return TRUE

/datum/extension/labels/proc/ExcessLabelLength(var/label, var/user)
	. = length(label) + 3 // Each label also adds a space and two brackets when applied to a name
	if(LAZYLEN(labels))
		for(var/entry in labels)
			. += length(entry) + 3
	. = . > 64 ? TRUE : FALSE
	if(. && user)
		to_chat(user, "<span class='warning'>The label won't fit.</span>")

/proc/get_attached_labels(var/atom/source)
	if(has_extension(source, /datum/extension/labels))
		var/datum/extension/labels/L = get_extension(source, /datum/extension/labels)
		if(LAZYLEN(L.labels))
			return L.labels.Copy()
		return list()

/atom/proc/RemoveLabel(var/label in get_attached_labels(src))
	set name = "Remove Label"
	set desc = "Used to remove labels"
	set category = "Object"
	set src in view(1)

	if(CanPhysicallyInteract(usr))
		if(has_extension(src, /datum/extension/labels))
			var/datum/extension/labels/L = get_extension(src, /datum/extension/labels)
			L.RemoveLabel(usr, label)
