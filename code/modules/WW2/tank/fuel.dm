/obj/tank/proc/refuel(var/obj/item/weapon/vehicle_fueltank/ftank, var/mob/user as mob)
	tank_message("[user] refuels [my_name()] with [ftank].")
	qdel(ftank)
	fuel = max_fuel