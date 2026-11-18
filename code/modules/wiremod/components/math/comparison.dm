/obj/item/circuit_component/operator/comparison
	name = "comparison component"
	display_name = "Comparison"
	category = "Math"
	result_type = PORT_TYPE_BOOLEAN
	operations = list("Equal", "Not Equal", "Greater Than", "Less Than", "Greater Than or Equal", "Less Than or Equal")

/obj/item/circuit_component/operator/comparison/operate(left, right, chosen)
	// A list equals nothing, itself included: == on lists would only tell
	// whether the two inputs happen to be fed by the same wire.
	var/either_is_list = islist(left) || islist(right)
	switch(chosen)
		if("Equal")
			return !either_is_list && left == right
		if("Not Equal")
			return either_is_list || left != right
	// Which side is the greater: positive for the left, negative for the right.
	// Only two numbers or two texts have an order.
	var/order
	if(isnum(left) && isnum(right))
		order = left > right ? 1 : (left < right ? -1 : 0)
	else if(istext(left) && istext(right))
		// sorttext() is positive when its arguments are already in ascending order.
		order = sorttext(right, left)
	else
		return null
	switch(chosen)
		if("Greater Than")
			return order > 0
		if("Less Than")
			return order < 0
		if("Greater Than or Equal")
			return order >= 0
		if("Less Than or Equal")
			return order <= 0
	return null
