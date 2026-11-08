// ============================================================
// Wider network (orbital stations, stage D)
// ------------------------------------------------------------
// Flights already join every world of the group: a two-stage or reusable
// rocket flies from the mainland, the Moon or Mars up to orbit, and a crewed
// lander flies from a station's launch pad down to the Moon or Mars once a
// survey map of it ships with the game (lander.dm, orbital_flight.dm).
//
// Radio crosses worlds only through long-range relays (radio_relay.dm). A
// station transceiver is a relay with its own dish, so a station needs no
// separate antenna on its hull. It wears, keys and repairs like any relay.
// ============================================================

/obj/structure/telecom/relay/station
	name = "station transceiver"
	desc = "A compact relay desk wired to a dish on the hull. With a network key it carries radio traffic to other worlds whose relay shares the key, as long as both are powered and kept in repair."

/obj/structure/telecom/relay/station/has_antenna()
	return TRUE
