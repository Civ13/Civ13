// ============================================================
// Wild West mounted raids
// ------------------------------------------------------------
// On Big Trouble in Little Creek the outlaws ride in: each outlaw starts in
// the saddle at the gang's camp, on a free horse there if one is standing
// by, otherwise on a new one. Any ridden horse kicks up dust as it runs.
// Uses the game's own horses and riding; the dust is the 96x96 smoke sprite
// tinted to the colour of dry earth.
// ============================================================

#define RAID_HORSE_REUSE_RANGE 5      // A riderless horse this close to the spawn is reused.
#define HOOF_DUST_INTERVAL 2          // Ticks between dust puffs from one horse.
#define HOOF_DUST_FADE 10             // Ticks a puff takes to settle.

var/global/list/raid_horse_types = list(/mob/living/simple_animal/horse, /mob/living/simple_animal/horse/black, /mob/living/simple_animal/horse/beige, /mob/living/simple_animal/horse/white)

// Called a moment after an outlaw spawns, once they stand at the camp.
/proc/wildwest_mount_outlaw(mob/living/human/H)
	if (!istype(H) || QDELETED(H) || H.stat == DEAD || H.riding || !isturf(H.loc))
		return FALSE
	if (!map || map.ID != MAP_LITTLE_CREEK_TDM)
		return FALSE
	var/mob/living/simple_animal/horse/mount = null
	for (var/mob/living/simple_animal/horse/free in range(RAID_HORSE_REUSE_RANGE, H))
		if (free.stat != DEAD && isnull(free.rider) && !free.pulledby)
			mount = free
			break
	if (!mount)
		var/kind = pick(raid_horse_types)
		mount = new kind(H.loc)
	else
		mount.forceMove(H.loc)
	if (!mount.take_rider(H))
		return FALSE
	to_chat(H, SPAN_NOTICE("You swing into the saddle. Ride for the bank!"))
	return TRUE

/obj/effect/hoof_dust
	name = "dust"
	icon = 'icons/effects/96x96.dmi'
	icon_state = "smoke"
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	should_save = FALSE
	color = "#c9a26b"
	alpha = 110
	layer = 3.98 // Just under the horses (3.99).
	pixel_x = -32
	pixel_y = -40

/obj/effect/hoof_dust/New(loc)
	..()
	var/matrix/M = matrix()
	M.Scale(0.3)
	transform = M
	animate(src, alpha = 0, transform = matrix() * 0.55, time = HOOF_DUST_FADE)
	QDEL_IN(src, HOOF_DUST_FADE)

/mob/living/simple_animal/var/tmp/next_hoof_dust = 0

// Leaves a puff of dust where a ridden horse just was. Not on water or
// indoors, and no more than one puff every HOOF_DUST_INTERVAL ticks.
/proc/hoof_dust(mob/living/simple_animal/horse/mount, turf/from)
	if (!istype(mount) || !istype(from) || world.time < mount.next_hoof_dust)
		return FALSE
	if (!istype(from, /turf/floor) || istype(from, /turf/floor/beach/water))
		return FALSE
	var/area/A = get_area(from)
	if (A && A.location == AREA_INSIDE)
		return FALSE
	mount.next_hoof_dust = world.time + HOOF_DUST_INTERVAL
	new /obj/effect/hoof_dust(from)
	return TRUE

#undef HOOF_DUST_INTERVAL
#undef HOOF_DUST_FADE
