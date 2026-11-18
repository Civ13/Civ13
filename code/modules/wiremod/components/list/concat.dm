/obj/item/circuit_component/operator/list_concat
	name = "list concatenate component"
	display_name = "List Concat"
	category = "List"
	desc = "Joins list A and list B into one list, with the entries of A first. A list holds at most 500 entries; any more are dropped."
	operand_type = PORT_TYPE_LIST
	result_type = PORT_TYPE_LIST

/obj/item/circuit_component/operator/list_concat/operate(left, right, chosen)
	var/list/joined = list()
	if(islist(left))
		joined += left
	if(islist(right))
		joined += right
	return joined
