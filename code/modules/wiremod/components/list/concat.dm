/obj/item/circuit_component/operator/list_concat
	name = "list concatenate component"
	display_name = "List Concat"
	category = "List"
	operand_type = PORT_TYPE_LIST
	result_type = PORT_TYPE_LIST

/obj/item/circuit_component/operator/list_concat/operate(left, right, chosen)
	var/list/joined = list()
	if(islist(left))
		joined += left
	if(islist(right))
		joined += right
	return joined
