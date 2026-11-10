// Fields that only hold art or sound handles rebuilt from type defaults.
// The savefile writer embeds a full copy of every .dmi/.ogg resource stored in
// a field, per entry. On the 2026-11-04 Gaia backup these copies were most of
// 2.sav: each animal's riding overlay held two copies of its icon file (about
// 330 KB), and every animal and item repeated its sound and in-hand icon lists.
// Exclude them on export and on legacy import; constructors already build the
// type defaults, and after_load refreshes the overlay from restored fields.

/mob/living/simple_animal/persistence_runtime_var(key)
	return key == "cover_overlay" || key == "wandersounds" || key == "hostilesounds" || ..()

/mob/living/simple_animal/after_load()
	. = ..()
	// New() built this from the type's icon; icon and icon_riding may be restored.
	cover_overlay = image("icon" = icon, "icon_state" = icon_riding, "layer" = 4.15)
	// Spawners do not save their head count; restored animals rebuild it.
	if (istype(origin, /obj/effect/spawner/mobspawner))
		var/obj/effect/spawner/mobspawner/O = origin
		O.register_spawned(src)

/mob/living/simple_animal/goat/after_load()
	. = ..()
	if (lamb)
		wandersounds = list('sound/animals/goat/baby_goat_1.ogg','sound/animals/goat/baby_goat_2.ogg')

/obj/item/persistence_runtime_var(key)
	return key == "item_icons" || ..()

/obj/structure/bed/bedroll/persistence_runtime_var(key)
	return key == "cover_overlay" || key == "use_cycle" || ..()
