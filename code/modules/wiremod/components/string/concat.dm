/obj/item/circuit_component/operator/string_concat
	name = "string concat component"
	display_name = "String Concat"
	category = "String"
	desc = "Joins text A and text B end to end. An input that is not set counts as empty text, and a number is joined as its digits. The result is cut at 5,000 characters."
	operand_type = PORT_TYPE_STRING
	result_type = PORT_TYPE_STRING

/obj/item/circuit_component/operator/string_concat/operate(left, right, chosen)
	return "[isnull(left) ? "" : left][isnull(right) ? "" : right]"
