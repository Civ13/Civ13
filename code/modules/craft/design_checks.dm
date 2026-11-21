// ============================================================
// Design checks (docs/design-checks.md): one way to judge any vehicle design
// ------------------------------------------------------------
// Every vehicle editor (the ship's draught, the submarine sheet, the frame
// survey of a hand-built car, tank, plane or boat, and any planner added
// later: a spaceship, a rocket, a station) asks the same question before
// anything is built: what is wrong with this, and what is merely unwise?
//
// A design check is a small datum with a kind ("ship", "sub", "vehicle"...)
// and a check() proc that looks at one design and adds findings to a
// report. A new check is one more subtype in any file; nothing else needs to
// list it. A new kind of design is a new kind string, its own checks and a
// proc on its datum that calls design_report().
//
// A finding has a level:
//   DESIGN_ERROR    it cannot be built or assembled as it is
//   DESIGN_WARNING  it can be built, but something will not work well
//   DESIGN_NOTE     advice worth knowing; nothing is wrong
// and may name the cells it is about (in the design's own grid keys, such
// as "x,y"), the deck they lie on (0 for the main deck; a multi-deck design
// numbers its own) and the part it concerns, so a window can light up the
// cells and show that part's description.
//
// Errors are what a design's problems() list returns, so the older callers
// (the slipway, the hand assembly) keep refusing exactly what they did.
// ============================================================

/datum/design_finding
	var/level = DESIGN_NOTE
	var/text = ""
	var/list/cells = null   // Grid keys the finding is about, or null.
	var/deck = 0            // The deck those cells lie on.
	var/part = null         // The part key it concerns, or null.

/datum/design_report
	var/kind = null
	var/list/findings = list()

/datum/design_report/New(new_kind)
	..()
	kind = new_kind

/datum/design_report/Destroy()
	for (var/datum/design_finding/F in findings)
		qdel(F)
	findings.Cut()
	return ..()

/datum/design_report/proc/add(level, text, list/cells = null, part = null, deck = 0)
	var/datum/design_finding/F = new
	F.level = level
	F.text = text
	F.cells = (islist(cells) && cells.len) ? cells.Copy() : null
	F.part = part
	F.deck = deck
	findings += F
	return F

/datum/design_report/proc/error(text, list/cells = null, part = null, deck = 0)
	return add(DESIGN_ERROR, text, cells, part, deck)

/datum/design_report/proc/warning(text, list/cells = null, part = null, deck = 0)
	return add(DESIGN_WARNING, text, cells, part, deck)

/datum/design_report/proc/note(text, list/cells = null, part = null, deck = 0)
	return add(DESIGN_NOTE, text, cells, part, deck)

/datum/design_report/proc/count(level)
	. = 0
	for (var/datum/design_finding/F in findings)
		if (F.level == level)
			.++

// The words of every finding at one level, in the order they were found.
/datum/design_report/proc/texts(level)
	. = list()
	for (var/datum/design_finding/F in findings)
		if (F.level == level)
			. += F.text

/datum/design_report/proc/blocked()
	return count(DESIGN_ERROR) > 0

/proc/design_level_name(level)
	switch (level)
		if (DESIGN_ERROR)
			return "error"
		if (DESIGN_WARNING)
			return "warning"
	return "note"

// The findings for a window, worst first:
// list(list("level", "text", "cells", "deck", "part"), ...).
/datum/design_report/proc/data()
	. = list()
	for (var/level in list(DESIGN_ERROR, DESIGN_WARNING, DESIGN_NOTE))
		for (var/datum/design_finding/F in findings)
			if (F.level != level)
				continue
			. += list(list(
				"level" = design_level_name(level),
				"text" = F.text,
				"cells" = F.cells ? F.cells : list(),
				"deck" = F.deck,
				"part" = F.part ? F.part : "",
			))

// The findings in chat: errors, then warnings, then notes, one per line.
/datum/design_report/proc/chat_lines()
	. = list()
	for (var/text in texts(DESIGN_ERROR))
		. += "<span class='warning'>[text]</span>"
	for (var/text in texts(DESIGN_WARNING))
		. += "<span class='notice'><b>Warning:</b> [text]</span>"
	for (var/text in texts(DESIGN_NOTE))
		. += "<span class='notice'>[text]</span>"

// ---- The checks ----

/datum/design_check
	var/kind = null  // The kind of design it judges.
	var/order = 100  // Lower runs first: the reports read in this order.
	// A parent that only shares code with its checks names its own type here
	// and is not run itself.
	var/abstract_type = /datum/design_check

// Adds what it finds about design D to report R.
/datum/design_check/proc/check(datum/D, datum/design_report/R)
	return

var/global/list/design_checks_by_kind = null // kind -> list of checks, in order

/proc/design_checks_for(kind)
	if (!design_checks_by_kind)
		design_checks_by_kind = list()
		for (var/path in subtypesof(/datum/design_check))
			var/datum/design_check/C = new path
			if (!C.kind || C.type == C.abstract_type)
				qdel(C)
				continue
			var/list/L = design_checks_by_kind[C.kind]
			if (!L)
				L = list()
				design_checks_by_kind[C.kind] = L
			var/at = L.len + 1
			for (var/i = 1, i <= L.len, i++)
				var/datum/design_check/O = L[i]
				if (C.order < O.order)
					at = i
					break
			L.Insert(at, C)
	var/list/found = design_checks_by_kind[kind]
	return found ? found : list()

// Every check of kind run over design D. The caller owns the report.
/proc/design_report(kind, datum/D)
	var/datum/design_report/R = new(kind)
	for (var/datum/design_check/C in design_checks_for(kind))
		C.check(D, R)
	return R

// The errors alone, as text: what a design's problems() returns.
/proc/design_errors(kind, datum/D)
	var/datum/design_report/R = design_report(kind, D)
	. = R.texts(DESIGN_ERROR)
	qdel(R)

// ---- Describing parts ----
// What each part an editor offers is, what it is for and how it is used.
// A part book is a datum with a kind and entries(): part key =
// list("what" = ..., "use" = ..., "how" = ...). Like the checks, a new book
// is one more subtype anywhere. The editors send the book to their windows
// so selecting any part shows all three. A part without an entry still
// shows its name; tests/ship_draught/test_design_checks.py wants every part described.

/datum/design_part_book
	var/kind = null

/datum/design_part_book/proc/entries()
	return list()

var/global/list/design_part_help = null // kind -> key -> list(what, use, how)

/proc/design_part_help_for(kind)
	if (!design_part_help)
		design_part_help = list()
		for (var/path in subtypesof(/datum/design_part_book))
			var/datum/design_part_book/B = new path
			if (B.kind)
				var/list/L = design_part_help[B.kind]
				if (!L)
					L = list()
					design_part_help[B.kind] = L
				var/list/E = B.entries()
				for (var/key in E)
					L[key] = E[key]
			qdel(B)
	var/list/found = design_part_help[kind]
	return found ? found : list()

// One part's description in a line of chat, or null.
/proc/design_part_help_text(kind, key)
	var/list/L = design_part_help_for(kind)
	var/list/H = L[key]
	if (!H)
		return null
	return "[H["what"]] [H["use"]] [H["how"]]"
