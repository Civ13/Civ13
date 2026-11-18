/obj/item/circuit_component/operator/logic
	name = "logic component"
	display_name = "Logic"
	category = "Math"
	operand_type = PORT_TYPE_BOOLEAN
	result_type = PORT_TYPE_BOOLEAN
	operations = list("AND", "OR", "XOR")

/obj/item/circuit_component/operator/logic/operate(left, right, chosen)
	switch(chosen)
		if("AND")
			return left && right
		if("OR")
			return left || right
		if("XOR")
			return !!left != !!right
	return null
