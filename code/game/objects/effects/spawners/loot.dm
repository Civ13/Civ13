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

/obj/effect/spawner/lootdrop/armor
	name = "armor spawner"
	loot = list(/obj/item/weapon/shield/roman,/obj/item/weapon/shield/aspis,/obj/item/clothing/suit/armor/ancient/scale,/obj/item/clothing/suit/armor/medieval,/obj/item/clothing/suit/armor/medieval/chainmail,/obj/item/clothing/suit/b3,/obj/item/clothing/suit/a6b28,/obj/item/clothing/head/helmet/horned,/obj/item/clothing/head/helmet/kevlarhelmet,/obj/item/clothing/head/helmet/medieval/coif,/obj/item/clothing/head/helmet/modern/brodie,/obj/item/clothing/head/helmet/modern/stahlhelm,/obj/item/clothing/head/helmet/roman_centurion)
	nr = 2

/obj/effect/spawner/lootdrop/accessories
	name = "accessory spawner"
	loot = list(/obj/item/clothing/accessory/storage/webbing/light,/obj/item/clothing/accessory/storage/webbing/largepouchestan,/obj/item/clothing/accessory/storage/webbing/green_webbing,/obj/item/clothing/accessory/storage/webbing/us_vest,/obj/item/clothing/accessory/storage/webbing/ww1/british,/obj/item/weapon/storage/belt/leather,/obj/item/weapon/storage/belt/medical/full_us,/obj/item/weapon/storage/belt/tactical,/obj/item/weapon/storage/belt/utility,/obj/item/weapon/storage/backpack/civbag,/obj/item/weapon/storage/backpack/rucksack,/obj/item/weapon/storage/backpack/scavpack,/obj/item/weapon/storage/backpack/ww2/jap)
	nr = 2