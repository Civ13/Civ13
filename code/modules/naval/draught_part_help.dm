// ============================================================
// What every part on a ship's draught or a submarine sheet is
// (docs/design-checks.md)
// ------------------------------------------------------------
// Part books (craft/design_checks.dm) for the "ship" and "sub" kinds:
// for each floor, piece, tool, section, fitting and wall the designers offer,
// what it is, what it is for and how to use it. The designer windows show it
// when the part is selected. tests/ship_draught/test_design_checks.py wants an entry for every
// key in the draught tables, so a new piece needs its words here.
// ============================================================

/datum/design_part_book/ship
	kind = "ship"

/datum/design_part_book/ship/entries()
	return list(
		// Floors and tools
		"w" = list("what" = "A plank floor: one tile of wooden hull laid over the water.", "use" = "Every tile of a ship is a floor; the floors are her hull and decide her size class, her burden and how many tiles her anchors must hold.", "how" = "Paint it on the sheet tile by tile or drag a box. On the slipway each one takes 2 wood."),
		"s" = list("what" = "A steel floor: one tile of plated hull.", "use" = "The same as a plank floor afloat, built from steel instead of wood. Mix both on one hull if you like.", "how" = "Paint it like a plank floor. On the slipway each one takes 1 steel."),
		"u" = list("what" = "A tile of deck off her main deck: a deck above her hull, or her hold below it.", "use" = "Room for a cabin roof, a quarterdeck, a forecastle or a hold for cargo. Every deck counts towards the deck cap with her hull tiles.", "how" = "Pick the deck at the top of the sheet, then paint it over the level it rests on; right-click takes it up. The deck above is laid by hand once she is afloat and needs open air over her. Join each deck to the next with a ladder."),
		"x" = list("what" = "The eraser.", "use" = "Takes a whole tile off the sheet: its floor, what stands on it and any deck above.", "how" = "Click or drag over tiles. Undo brings them back."),
		// Steering and drive
		"O" = list("what" = "A steering oar: a broad oar lashed over the quarter on its post.", "use" = "Her helm. Cheaper than a tiller, and steers her just the same.", "how" = "Put exactly one helm on her, usually at the stern. Stand at it afloat to ring speeds, come about and call the anchor."),
		"T" = list("what" = "A tiller on its post, with a rudder under the planks.", "use" = "Her helm: it is where her papers are kept, her speed rung and her anchor called.", "how" = "Put exactly one helm on her. After building, use it to commission her, and later to refit her or draw her lines."),
		"M" = list("what" = "A ship mast with a yard and a sail.", "use" = "Drives her at up to half ahead on a reach, less running before the wind and much less into it, and never tires.", "how" = "Stand masts along her centre line. Rig a sail on each afloat. A ship with masts wants weight low in her as ballast or she sails crank."),
		"N" = list("what" = "A ship mast with a crow's nest at its masthead.", "use" = "Drives her like a mast, and a lookout climbed up to the nest sees 8 tiles further than her deck allows.", "how" = "Stand it on her centre line like any mast. Afloat, grab the mast with a free hand to climb to the nest."),
		"J" = list("what" = "A bowsprit: a spar run out over her bow to carry a jib.", "use" = "With a sail rigged on it, the jib pushes her half as hard as a sail on a mast, and is set, reefed and furled the same way.", "how" = "Put it at her bow, the top of the sheet, with none of her deck ahead of it. Rig a sail on it afloat."),
		"F" = list("what" = "A figurehead: a carved figure on her bow.", "use" = "Only for looks. The first hand to work on it chooses what it is carved as.", "how" = "Put it at her bow facing ahead (turn it with R)."),
		"R" = list("what" = "A rowing bench: a thwart with an oar through a port.", "use" = "Each manned bench pushes her; enough of them make full ahead, which sails cannot.", "how" = "Line them along her sides facing across her (turn with R). Each needs a rower sitting at it; rowers tire on long voyages."),
		"E" = list("what" = "A steam engine standing on her deck.", "use" = "Drives her at up to full ahead whatever the wind, burning fuel in its fires.", "how" = "Fit it on an open tile with deck around it. Afloat, feed its fires wood or coal and start it; more fires lit give more power."),
		// Gear
		"K" = list("what" = "A killick: a wooden anchor weighted with a stone.", "use" = "Holds 40 tiles of hull when her anchor is called down at the helm.", "how" = "Fit one or more; their holding adds up and must cover every tile of her. Small craft need no anchor."),
		"A" = list("what" = "An iron anchor on its cable.", "use" = "Holds 100 tiles of hull when her anchor is called down at the helm.", "how" = "Fit it on her deck; its holding adds to any killicks she carries."),
		"P" = list("what" = "A hand bilge and cellar pump.", "use" = "Lifts two bucketfuls over the side with every stroke: one hand at the pump keeps ahead of one hole.", "how" = "Fit it where crew can stand beside it. Work it by hand when she takes water."),
		"Q" = list("what" = "A steam bilge pump.", "use" = "Lifts 80 bucketfuls a minute out of her bilge while its fire burns.", "how" = "Fit it with open deck beside it. Feed it coal, charcoal or wood and start it by hand."),
		"U" = list("what" = "An electric sump pump with a float switch.", "use" = "Lifts 40 bucketfuls a minute, starting by itself whenever water comes in.", "how" = "Lay a powered cable under it from a generator aboard, or keep its battery charged."),
		"C" = list("what" = "A wooden crate.", "use" = "Stows cargo and stores. Its weight counts on her deck, which helps ballast a ship with masts.", "how" = "Fit crates where crew can reach them, in the hold or along the sides."),
		"B" = list("what" = "A wooden bed.", "use" = "A berth for crew to sleep aboard on long voyages.", "how" = "Fit beds in a cabin or below the deck above."),
		// Arms
		"H" = list("what" = "A cannon bored from a log and bound with iron hoops.", "use" = "A cheap gun good for a handful of shots.", "how" = "Turn it to face out over the side or the bow (R), and leave open deck behind it for the crew to load and fire."),
		"Z" = list("what" = "A cast cannon.", "use" = "Her main guns: fires cannon balls along the way it faces.", "how" = "Turn it to face out over the side or the bow (R), and leave open deck behind it for the crew to load and fire."),
		"L" = list("what" = "A steel torpedo tube on a training mount.", "use" = "Fires a torpedo along the line it points, out past her hull.", "how" = "Turn it to face out (R). Afloat, bolt it down with a wrench, load a torpedo and fire."),
		// Cabin
		"W" = list("what" = "A plank wall.", "use" = "Closes off a cabin or a hold and keeps weather and boarders out.", "how" = "Draw walls round a cabin and leave a door in them. Walls block crew from what stands behind them."),
		"D" = list("what" = "A wooden door anyone can open.", "use" = "The way in and out of a walled cabin.", "how" = "Put it in a line of walls (turn it with R). It lets crew through where a wall would not."),
		"G" = list("what" = "A wooden window frame.", "use" = "Lets light into a cabin while closing it like a wall.", "how" = "Put it in a line of walls. Crew cannot walk through it."),
		"V" = list("what" = "A steel window frame.", "use" = "A window in a steel cabin: light in, crew and weather out.", "how" = "Put it in a line of walls. Crew cannot walk through it."),
		// Sides
		"Y" = list("what" = "A gangway: a gate in her gunwale.", "use" = "Where crew and cargo come aboard over her side, and where a gangplank is run out to a quay or another ship.", "how" = "Put it on a tile at her edge and turn it (R) to face out over the side. Her other edge tiles get gunwales by themselves."),
		"I" = list("what" = "A steel fire door.", "use" = "A heavy door for a steel cabin or engine room.", "how" = "Put it in a line of walls (turn it with R). It lets crew through where a wall would not."),
		// Between decks
		"X" = list("what" = "A wooden ladder stood up to the deck above.", "use" = "How crew climb between her decks: out of her hold to her main deck, or from one deck to the deck above it.", "how" = "Draw it on the lower deck under a tile of the deck above, and leave that tile clear: the ladder's head stands there. Every part of her hold needs one."),
	)

/datum/design_part_book/sub
	kind = "sub"

/datum/design_part_book/sub/entries()
	return list(
		// Sections
		"h" = list("what" = "A section of pressure hull.", "use" = "Every section of her is hull unless it is a hatch; her rows decide her length, cost, battery and air.", "how" = "Click a section to make it hull again. The glass bow and the stern engine room are drawn for you."),
		"x" = list("what" = "A lock-out hatch in her side.", "use" = "Where crew board her on the surface and divers leave or return under water. She needs at least one.", "how" = "Make one of her side sections (not the middle column, the bow row or the engine room) a hatch."),
		// Walls across a section's bow side
		"wb" = list("what" = "A bulkhead across the bow side of a section.", "use" = "Splits her into watertight rooms, so one flooded room does not sink her.", "how" = "Click a section to close its bow side. Leave a door in every row of bulkheads or the rooms aft are cut off."),
		"wd" = list("what" = "A watertight door across the bow side of a section.", "use" = "A way through a bulkhead that still closes against flooding.", "how" = "Put one in each row of bulkheads."),
		"wn" = list("what" = "No wall: the bow side of the section is open.", "use" = "Joins the section to the one ahead of it as one room.", "how" = "Click a section to take its bulkhead or door away."),
		// Fittings
		"W" = list("what" = "The ship's wheel.", "use" = "Steers her and rings her speed. She needs exactly one.", "how" = "Put it in a section crew can reach from the control room, usually near the bow."),
		"S" = list("what" = "The ballast and periscope station.", "use" = "Floods and blows her tanks to dive and surface, and raises the periscope. She needs exactly one.", "how" = "Put it near the wheel so one crew can steer and dive."),
		"E" = list("what" = "A battery bank.", "use" = "Each bank adds half a Scout's battery: the charge that runs her motors and floodlights under water.", "how" = "Fit one or more in any section but the engine room. The diesel charges them on the surface."),
		"A" = list("what" = "An air bank.", "use" = "Each bank adds half a Scout's reserve of air for the crew on a dive.", "how" = "Fit one or more in any section but the engine room."),
		"L" = list("what" = "A locker.", "use" = "Stows gear, diving suits and stores aboard.", "how" = "Fit lockers where crew can reach them."),
		"B" = list("what" = "A berth.", "use" = "Somewhere for crew to sleep on a long patrol.", "how" = "Fit berths in the after rooms, away from the controls."),
	)
