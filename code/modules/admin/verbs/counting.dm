/client/proc/count_objects_on_z_level()
	set category = "Mapping"
	set name = "Count Objects On Level"
	var/level = input("Which z-level?","Level?") as text
	if (!level) return
	var/num_level = text2num(level)
	if (!num_level) return
	if (!isnum(num_level)) return

	var/type_text = input("Which type path?","Path?") as text
	if (!type_text) return
	var/type_path = text2path(type_text)
	if (!type_path) return

	var/count = TRUE

	var/list/atom/atom_list = list()

	for (var/atom/A in world)
		if (istype(A,type_path))
			var/atom/B = A
			while (!(isturf(B.loc)))
				if (B && B.loc)
					B = B.loc
				else
					break
			if (B)
				if (B.z == num_level)
					count++
					atom_list += A
	/*
	var/atom/temp_atom
	for (var/i = FALSE; i <= (atom_list.len/10); i++)
		var/line = ""
		for (var/j = TRUE; j <= 10; j++)
			if (i*10+j <= atom_list.len)
				temp_atom = atom_list[i*10+j]
				line += " no.[i+10+j]@\[[temp_atom.x], [temp_atom.y], [temp_atom.z]\]; "
		world << line*/

	world << "There are [count] objects of type [type_path] on z-level [num_level]"


/client/proc/count_objects_all()
	set category = "Mapping"
	set name = "Count Objects All"

	var/type_text = input("Which type path?","") as text
	if (!type_text) return
	var/type_path = text2path(type_text)
	if (!type_path) return

	var/count = FALSE

	for (var/atom/A in world)
		if (istype(A,type_path))
			count++
	/*
	var/atom/temp_atom
	for (var/i = FALSE; i <= (atom_list.len/10); i++)
		var/line = ""
		for (var/j = TRUE; j <= 10; j++)
			if (i*10+j <= atom_list.len)
				temp_atom = atom_list[i*10+j]
				line += " no.[i+10+j]@\[[temp_atom.x], [temp_atom.y], [temp_atom.z]\]; "
		world << line*/

	world << "There are [count] objects of type [type_path] in the game world"

