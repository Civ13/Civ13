// this is great, everybody loves this
/area/admin/persistent

/obj/structure/storage_holder
	icon = 'icons/obj/cult.dmi'
	icon_state = "forge"
	
/obj/structure/storage_holder/department_holder
	var/list/department_list = list()
	map_storage_saved_vars = "department_list"
	
/obj/structure/storage_holder/department_holder/New()
	if(!department_datums || !department_datums.len)
		setup_department_datums()
	department_list = department_datums
	..()
	
/obj/structure/storage_holder/department_holder/after_load()
	if(department_list && department_list.len)
		department_datums = department_list
	else
		if(!department_datums || !department_datums.len)
			setup_department_datums()
		department_list = department_datums