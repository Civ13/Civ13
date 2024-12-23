
/obj/structure/wild/ore_deposits
	icon = 'icons/obj/flora/ore_deposits.dmi'
	health = 10
	maxhealth = 10

/obj/structure/wild/ore_deposits/hematite_deposit
	name = "hematite deposit"
	icon_state = "hematite_deposit"
	desc = "A deposit of a red mineral.. you wonder what you could do with it."
/obj/structure/wild/ore_deposits/malachite_deposit
	name = "malachite deposit"
	icon_state = "malachite_deposit"
	desc = "A deposit of a blue green mineral.. you wonder what you could do with it."
/obj/structure/wild/ore_deposits/cassiterite_deposit
	name = "cassiterite deposit"
	icon_state = "cassiterite_deposit"
	desc = "A deposit of a gray mineral.. you wonder what you could do with it."

/obj/structure/wild/ore_deposits/attackby(obj/item/W as obj, mob/user as mob) 
	user.setClickCooldown(10)
	playsound(user, 'sound/effects/chop.ogg', 100, 1) // Play sound on hit

	// Decrease health and check if destroyed
	if (--health <= 0)
		visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")

		// Handle different ore types
		if (name == "hematite deposit")
			var/obj/item/stack/ore/iron/iron_stack = new /obj/item/stack/ore/iron(src.loc)
			iron_stack.amount = rand(2, 5) // Drop 2-5 iron
			iron_stack.update_strings()

		else if (name == "malachite deposit")
			var/obj/item/stack/ore/copper/copper_stack = new /obj/item/stack/ore/copper(src.loc)
			copper_stack.amount = rand(2, 5) // Drop 2-5 copper
			copper_stack.update_strings()

		else if (name == "cassiterite deposit")
			var/obj/item/stack/ore/tin/tin_stack = new /obj/item/stack/ore/tin(src.loc)
			tin_stack.amount = rand(2, 5) // Drop 2-5 tin
			tin_stack.update_strings()

		qdel(src) // Delete the deposit object after it's destroyed
		return

	user << "<span class='danger'>You hit the [name].</span>"
