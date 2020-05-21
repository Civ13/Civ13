/obj/effect/spawner/lootdrop
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "x3"
	var/list/loot = list()
	var/nr = 1
	var/loot_spawn
/obj/effect/spawner/lootdrop/New()
	..()
	for (var/i = 1, i<=nr, i++)
		loot_spawn = pick(loot)
		new loot_spawn(get_turf(src))
	qdel(src)


/obj/effect/spawner/lootdrop/guns
	name = "gun spawner"
	loot = list(/obj/item/weapon/gun/projectile/pistol/glock17,/obj/item/weapon/gun/projectile/pistol/m1911,/obj/item/weapon/gun/projectile/shotgun/pump,/obj/item/weapon/gun/projectile/semiautomatic/m1garand,/obj/item/weapon/gun/projectile/automatic/mg34,/obj/item/weapon/gun/projectile/submachinegun/mp40,/obj/item/weapon/gun/projectile/submachinegun/ak47)

/obj/effect/spawner/lootdrop/melee
	name = "melee spawner"
	loot = list(/obj/item/weapon/material/sword/gladius,/obj/item/weapon/material/sword/armingsword,/obj/item/weapon/material/sword/katana,/obj/item/weapon/material/sword/sabre,/obj/item/weapon/material/sword/smallsword,/obj/item/weapon/melee/classic_baton)

/obj/effect/spawner/lootdrop/ammo
	name = "ammo spawner"
	loot = list(/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/m1911,/obj/item/ammo_magazine/shellbox/slug,/obj/item/ammo_magazine/mp40,/obj/item/ammo_magazine/mg34,/obj/item/ammo_magazine/ak47,/obj/item/ammo_magazine/garand)
	nr = 2