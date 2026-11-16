// Moving a faction's fixtures (Val, 2026-11-16: "faction leaders and officers
// should be able to move things like this"). A faction's hall seat, nation
// assembly seat, recruitment station, colony charter and strongbox are fixed
// in place. The leader, or an officer whose office has the "works" power
// (faction_offices.dm), can unfasten one with the Fasten or Unfasten verb,
// pull it somewhere else and fasten it again. The fixture keeps its faction,
// tier and delivered materials the whole time. A hall or assembly counts
// toward its faction's limits only while fastened, and the indoor rule for
// higher tiers applies where it is fastened. A loose fixture can be pulled by
// anyone, but only the faction's leader or works officers can fasten it.

#define FACTION_FIXTURE_TIME 50

// The faction this structure is a fixture of, or null.
/obj/structure/proc/fixture_faction()
	return null

/obj/structure/faction_hall/fixture_faction()
	return faction

/obj/structure/recruitment_station/fixture_faction()
	return faction

/obj/structure/colony_charter/fixture_faction()
	return faction

/obj/structure/closet/crate/faction_strongbox/fixture_faction()
	return length(faction) ? faction : null

// Why user cannot fasten or unfasten this fixture now, or null.
/obj/structure/proc/fixture_move_block(mob/living/human/user)
	var/faction = fixture_faction()
	if (!faction || !map)
		return "\The [src] belongs to no faction. Only a faction's fixtures can be fastened and unfastened this way."
	if (!istype(user) || user.stat || !isturf(loc) || !user.Adjacent(src))
		return "You must stand beside \the [src]."
	if (!map.faction_power(user, faction, "works"))
		return "Only the leader of [faction], or one of its officers trusted with its works, can move \the [src]."
	return null

/obj/structure/proc/fixture_toggle(mob/living/human/user)
	var/block = fixture_move_block(user)
	if (block)
		to_chat(user, SPAN_WARNING(block))
		return
	var/fasten = !anchored
	var/faction = fixture_faction()
	user.visible_message(SPAN_NOTICE("[user] starts [fasten ? "fastening" : "unfastening"] \the [src]."), SPAN_NOTICE("You start [fasten ? "fastening" : "unfastening"] \the [src]."))
	if (!do_after(user, FACTION_FIXTURE_TIME, src) || fixture_move_block(user) || anchored == fasten || fixture_faction() != faction)
		return
	anchored = fasten
	if (fasten)
		user.visible_message(SPAN_NOTICE("[user] fastens \the [src] in place."), SPAN_NOTICE("You fasten \the [src] in place."))
	else
		user.visible_message(SPAN_NOTICE("[user] unfastens \the [src]."), SPAN_NOTICE("You unfasten \the [src]. Pull it where it should stand and fasten it again; while it stands loose anyone can pull it away[istype(src, /obj/structure/faction_hall) ? ", and it counts for nothing" : ""]."))
	log_game("Faction fixture: [key_name(user)] [fasten ? "fastened" : "unfastened"] [src] of [faction] at [x],[y],[z].")
	map.recruitment_audit(faction, "[user.real_name] [fasten ? "fastened" : "unfastened"] the [fixture_word()] at [x],[y].", faction_roster_account(user) || "")

// What the audit log calls this fixture.
/obj/structure/proc/fixture_word()
	return initial(name)

/obj/structure/faction_hall/fixture_word()
	return tier ? tiers()[tier][1] : hall_word

/obj/structure/faction_hall/verb/fixture_fasten()
	set name = "Fasten or Unfasten"
	set category = null
	set src in view(1)
	fixture_toggle(usr)

/obj/structure/recruitment_station/verb/fixture_fasten()
	set name = "Fasten or Unfasten"
	set category = null
	set src in view(1)
	fixture_toggle(usr)

/obj/structure/colony_charter/verb/fixture_fasten()
	set name = "Fasten or Unfasten"
	set category = null
	set src in view(1)
	fixture_toggle(usr)

/obj/structure/closet/crate/faction_strongbox/verb/fixture_fasten()
	set name = "Fasten or Unfasten"
	set category = null
	set src in view(1)
	fixture_toggle(usr)

#undef FACTION_FIXTURE_TIME
