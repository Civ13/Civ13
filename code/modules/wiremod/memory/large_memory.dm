// A large memory owns an even share of the shell's 512 KiB, minus whatever the
// small memories claim. Its Address is a byte offset inside that share.

/obj/item/circuit_component/memory/large
	name = "large memory component"
	display_name = "Large Memory"
	desc = "Holds an even share of the 512 KiB a shell provides. Address is a byte offset inside this component, Mode is 0 to read and 1 to write, and Trigger performs the access."
	small = FALSE
