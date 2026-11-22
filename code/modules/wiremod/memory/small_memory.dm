// A small memory claims 1 KiB. That kilobyte is taken evenly from the large
// memories sharing the shell, so adding one shrinks each large share.

/obj/item/circuit_component/memory/small
	name = "small memory component"
	display_name = "Small Memory"
	desc = "Holds 1 KiB, taken evenly from the large memories sharing its shell. Address is a byte offset inside this component, Mode is 0 to read and 1 to write, and Trigger performs the access."
	small = TRUE
