// Raid worlds (docs/persistence-raids.md). A region of kind RAID runs an
// extraction-style map that persistent characters visit and leave again. A
// trip into a raid world records the land the raider came from; a raid exit
// sends them back there with what they carry, and a raider who dies there goes
// home with nothing, since their body and gear stay in the raid. Nobody lives
// in a raid world: it cannot be the mainland (scripts/shard-group).

// Saved: the region a raider came from and goes home to. Set only in raid worlds.
/mob/living/human/var/raid_origin = null

// TRUE when region id is a peer of kind RAID.
/proc/region_raid_peer(id)
	if(!shard_group.enabled || !istext(id)) return FALSE
	var/list/peer = shard_group.peers[id]
	return islist(peer) && peer["kind"] == "RAID"

/proc/region_raid_world()
	return shard_group.enabled && shard_group.kind == "RAID"

// An arrival in a raid world remembers where it came from. Never sleeps.
/proc/region_raid_note_origin(mob/living/human/H, list/P)
	if(!istype(H) || !region_raid_world() || !islist(P)) return
	var/from = P["from"]
	if(istext(from) && from != shard_group.region && (from in shard_group.peers) && !region_raid_peer(from))
		H.raid_origin = from

// Where a raider's death in a raid world sends their home: the land they came
// from (region_home_death notes it as a depart there). Null outside a raid.
/proc/region_raid_death_origin(mob/living/human/H)
	if(!istype(H) || !region_raid_world() || !H.persistence_owner_ckey) return null
	var/origin = H.raid_origin
	if(!istext(origin) || !(origin in shard_group.peers)) return null
	log_game("Raid: [H.persistence_owner_ckey]'s character [H.real_name] died in the raid; their home goes back to [origin].")
	return origin

// An extraction point in a raid world: leads each raider back to their own land.
/obj/structure/region_gate/raid_exit
	name = "extraction point"
	desc = "The way out of the raid zone. Raiders leave here for home with what they carry."
	icon = 'icons/obj/structures.dmi'
	icon_state = "propstall1"

// Arrivals land at the raid's entry, never at the way out.
/obj/structure/region_gate/raid_exit/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/raid_exit/travel_refusal(mob/living/human/H)
	if(!region_raid_world()) return "This leads nowhere outside a raid."
	// Another raider's trip is being recorded: keep its destination.
	if(busy) return "The extraction point is busy. Try again in a moment."
	if(!istype(H) || !istext(H.raid_origin) || !(H.raid_origin in shard_group.peers))
		return "Nobody knows where you came from. Ask an admin."
	destination = H.raid_origin
	return ..()

/obj/structure/region_gate/raid_exit/examine(mob/user)
	to_chat(user, "That's \a [src].")
	to_chat(user, desc)
	var/mob/living/human/H = user
	if(istype(H) && istext(H.raid_origin) && (H.raid_origin in shard_group.peers))
		var/list/peer = shard_group.peers[H.raid_origin]
		to_chat(user, SPAN_NOTICE("It leads you home to [peer["name"]]."))
