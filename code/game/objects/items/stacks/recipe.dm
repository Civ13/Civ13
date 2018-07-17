/*
 * Recipe datum
 */
/datum/stack_recipe
	var/title = "ERROR"
	var/result_type
	var/req_amount = 1 //amount of material needed for this recipe
	var/res_amount = 1 //amount of stuff that is produced in one batch (e.g. 4 for floor tiles)
	var/max_res_amount = 1
	var/time = FALSE
	var/one_per_turf = FALSE
	var/on_floor = FALSE
	var/use_material

	New(_title, _result_type, _req_amount = 1, _res_amount = 1, _max_res_amount = 1, _time = 0, _one_per_turf = FALSE, _on_floor = FALSE, _supplied_material = null)

		title = _title
		result_type = _result_type
		req_amount = _req_amount
		res_amount = _res_amount
		max_res_amount = _max_res_amount
		time = _time
		one_per_turf = _one_per_turf
		on_floor = _on_floor
		use_material = _supplied_material

/*
 * Recipe list datum
 */
/datum/stack_recipe_list
	var/title = "ERROR"
	var/list/recipes = null
	New(_title, _recipes)
		title = _title
		recipes = _recipes
