/obj/item/circuit_component/operator/string_concat
	name = "string concat component"
	display_name = "String Concat"
	category = "String"
	operand_type = PORT_TYPE_STRING
	result_type = PORT_TYPE_STRING

/obj/item/circuit_component/operator/string_concat/operate(left, right, chosen)
	return "[isnull(left) ? "" : left][isnull(right) ? "" : right]"
