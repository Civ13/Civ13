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
	loot = list(/obj/item/weapon/gun/projectile/pistol/m1911,/obj/item/weapon/gun/projectile/shotgun/pump,/obj/item/weapon/gun/projectile/semiautomatic/svd,/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k,/obj/item/weapon/gun/projectile/submachinegun/mp40)

/obj/effect/spawner/lootdrop/guns/industrial
	name = "gun spawner"
	loot = list(/obj/item/weapon/gun/projectile/shotgun/coachgun,/obj/item/weapon/gun/projectile/boltaction/singleshot,/obj/item/weapon/gun/projectile/leveraction/winchester,/obj/item/weapon/gun/projectile/revolver/peacemaker)

/obj/effect/spawner/lootdrop/guns/medieval
	name = "gun spawner"
	loot = list(/obj/item/weapon/gun/projectile/bow/crossbow,/obj/item/weapon/gun/projectile/bow/longbow,/obj/item/weapon/gun/projectile/bow/shortbow)

/obj/effect/spawner/lootdrop/melee
	name = "melee spawner"
	loot = list(/obj/item/weapon/attachment/bayonet,/obj/item/weapon/material/sword/gladius/iron,/obj/item/weapon/material/sword/armingsword,/obj/item/weapon/material/sword/katana,/obj/item/weapon/material/sword/sabre,/obj/item/weapon/material/hatchet/battleaxe,/obj/item/weapon/melee/classic_baton)

/obj/effect/spawner/lootdrop/melee/medieval
	name = "melee spawner"
	loot = list(/obj/item/weapon/material/sword/armingsword,/obj/item/weapon/material/sword/longsword,/obj/item/weapon/material/sword/katana,/obj/item/weapon/material/sword/saif,/obj/item/weapon/material/sword/broadsword,/obj/item/weapon/material/sword/smallsword,/obj/item/weapon/material/sword/zweihander,/obj/item/weapon/melee/mace,/obj/item/weapon/material/spear/sarissa/pike,/obj/item/weapon/material/spear/halberd,/obj/item/weapon/material/hatchet/battleaxe)

/obj/effect/spawner/lootdrop/melee/medieval/clash
	name = "melee spawner"
	loot = list(/obj/item/weapon/material/sword/vikingsword/iron,/obj/item/weapon/material/sword/gaelic,/obj/item/weapon/material/sword/claymore/iron)

/obj/effect/spawner/lootdrop/ammo
	name = "ammo spawner"
	loot = list(/obj/item/ammo_magazine/m1911,/obj/item/ammo_magazine/shellbox/slug,/obj/item/ammo_magazine/mp40,/obj/item/ammo_magazine/gewehr98,/obj/item/ammo_magazine/svd)
	nr = 2

/obj/effect/spawner/lootdrop/ammo/industrial
	name = "ammo spawner"
	loot = list(/obj/item/ammo_magazine/sharps,/obj/item/ammo_magazine/shellbox,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c45)
	nr = 2

/obj/effect/spawner/lootdrop/ammo/medieval
	name = "ammo spawner"
	loot = list(/obj/item/weapon/storage/backpack/quiver/medieval,/obj/item/weapon/storage/backpack/quiver/medieval,/obj/item/weapon/storage/backpack/quiver/crossbow)
	nr = 1

/obj/effect/spawner/lootdrop/armor
	name = "armor spawner"
	loot = list(/obj/item/weapon/shield/roman,/obj/item/clothing/suit/armor/ancient/scale,/obj/item/clothing/suit/armor/medieval,/obj/item/clothing/suit/armor/medieval/chainmail,/obj/item/clothing/head/helmet/horned,/obj/item/clothing/head/helmet/kevlarhelmet,/obj/item/clothing/head/helmet/medieval/coif,/obj/item/clothing/head/helmet/modern/brodie,/obj/item/clothing/head/helmet/modern/stahlhelm,/obj/item/clothing/head/helmet/roman_centurion,/obj/item/clothing/accessory/armor/coldwar/flakjacket,/obj/item/clothing/accessory/armor/coldwar/pasgt)
	nr = 2

/obj/effect/spawner/lootdrop/armor/industrial
	name = "armor spawner"
	loot = list(/obj/item/weapon/shield/roman,/obj/item/clothing/suit/armor/ancient/scale,/obj/item/clothing/suit/armor/medieval,/obj/item/clothing/suit/armor/medieval/chainmail,/obj/item/clothing/head/helmet/horned,/obj/item/clothing/head/helmet/medieval/coif,/obj/item/clothing/head/helmet/modern/stahlhelm,/obj/item/clothing/head/helmet/roman_centurion,/obj/item/clothing/suit/armor/imperial/imperial_chestplate)
	nr = 2

/obj/effect/spawner/lootdrop/armor/medieval
	name = "armor spawner"
	loot = list(/obj/item/clothing/suit/armor/samurai,/obj/item/clothing/suit/armor/medieval,/obj/item/clothing/suit/armor/medieval/bronze_chestplate,/obj/item/clothing/suit/armor/medieval/chainmail,/obj/item/clothing/suit/armor/medieval/hauberk,/obj/item/clothing/suit/armor/medieval/iron_chestplate,/obj/item/clothing/suit/armor/medieval/varangian,/obj/item/clothing/suit/armor/medieval/steppe_leather,/obj/item/clothing/head/helmet/medieval,/obj/item/clothing/head/helmet/medieval/helmet1,/obj/item/clothing/head/helmet/medieval/helmet2,/obj/item/clothing/head/helmet/medieval/helmet3,/obj/item/clothing/head/helmet/medieval/baltic,/obj/item/clothing/head/helmet/medieval/coif,/obj/item/clothing/head/helmet/medieval/coif_helmet,/obj/item/clothing/head/helmet/medieval/viking,/obj/item/clothing/head/helmet/samurai)
	nr = 2

/obj/effect/spawner/lootdrop/accessories
	name = "accessory spawner"
	loot = list(/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars,/obj/item/clothing/accessory/storage/webbing/light,/obj/item/clothing/accessory/storage/webbing/largepouchestan,/obj/item/clothing/accessory/storage/webbing/green_webbing,/obj/item/clothing/accessory/storage/webbing/us_vest,/obj/item/clothing/accessory/storage/webbing/ww1/british,/obj/item/weapon/storage/belt/leather,/obj/item/weapon/storage/belt/medical/full_us,/obj/item/weapon/storage/belt/tactical,/obj/item/weapon/storage/belt/utility,/obj/item/weapon/storage/backpack/civbag,/obj/item/weapon/storage/backpack/rucksack,/obj/item/weapon/storage/backpack/scavpack,/obj/item/weapon/storage/backpack/ww2/jap,/obj/item/clothing/mask/gas/modern2,/obj/item/clothing/mask/gas/modern,/obj/item/clothing/mask/gas/military,/obj/item/clothing/glasses/nvg,/obj/item/weapon/pill_pack/pervitin)
	nr = 2

/obj/effect/spawner/lootdrop/explosives
	name = "explosives spawner"
	loot = list(/obj/item/weapon/grenade/dynamite/ready,/obj/item/weapon/grenade/flashbang/m84,/obj/item/weapon/grenade/incendiary/anm14,/obj/item/weapon/grenade/chemical/mustard,/obj/item/weapon/grenade/chemical/chlorine,/obj/item/weapon/grenade/coldwar/m67,/obj/item/weapon/grenade/ww2/stg1924,/obj/item/mine/ap,/obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust)
	nr = 2