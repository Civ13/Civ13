/obj/item/circuit_component/operator/arithmetic
	name = "arithmetic component"
	display_name = "Arithmetic"
	category = "Math"
	desc = "Works out a number from A and B with the chosen Operation: add, subtract, multiply, divide, modulo (the remainder), power, minimum or maximum. It waits until both A and B are set. Dividing by zero, or a power with no real answer, leaves Result empty."
	operand_type = PORT_TYPE_NUMBER
	result_type = PORT_TYPE_NUMBER
	operations = list("Add", "Subtract", "Multiply", "Divide", "Modulo", "Power", "Minimum", "Maximum")
	needs_both_inputs = TRUE

/obj/item/circuit_component/operator/arithmetic/operate(left, right, chosen)
	switch(chosen)
		if("Add")
			return left + right
		if("Subtract")
			return left - right
		if("Multiply")
			return left * right
		if("Divide")
			if(right != 0)
				return left / right
		if("Modulo")
			if(right != 0)
				return left %% right
		if("Power")
			// A negative base has no real fractional power, and zero has no negative one.
			if(!(left < 0 && right != round(right)) && !(left == 0 && right < 0))
				return left ** right
		if("Minimum")
			return min(left, right)
		if("Maximum")
			return max(left, right)
	return null
