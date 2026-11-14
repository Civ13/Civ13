// Optional isolated full-game fixture only. Never starts a normal game.
/mob/living/human/divine_journal_probe
	var/probe_initiated = FALSE
/mob/living/human/divine_journal_probe/can_read_divine_journal()
	return probe_initiated

/proc/divine_journal_probe()
	var/mob/living/human/divine_journal_probe/H = new(locate(1, 1, 1))
	var/obj/item/weapon/book/J = new(locate(1, 1, 1))
	divine_probe_assert(!J.record_divine_advancement(H, "secret", "secret text"), "outsider cannot write")
	var/before = J.divine_journal_html(H)
	J.divine_advancement_entries["secret"] = "secret text"
	divine_probe_assert(J.divine_journal_html(H) == before, "outsider projection independent of contents")
	H.scholarship = list("mathematics" = 100)
	divine_probe_assert(J.divine_journal_html(H) == "", "mathematics cannot project contents")
	H.probe_initiated = TRUE
	divine_probe_assert(J.record_divine_advancement(H, "<title>", "<script>"), "initiated adapter can record")
	divine_probe_assert(findtext(J.divine_journal_html(H), "&lt;script&gt;") && !findtext(J.divine_journal_html(H), "<script>"), "content HTML escaped")
	H.probe_initiated = FALSE
	divine_probe_assert(!findtext(J.divine_journal_html(H), "secret"), "revocation hides on next projection")
	H.probe_initiated = TRUE
	J.divine_advancement_entries = list()
	for (var/i = 1, i <= 32, i++)
		divine_probe_assert(J.record_divine_advancement(H, "Entry [i]", "note"), "bounded ledger accepts entry [i]")
	divine_probe_assert(!J.record_divine_advancement(H, "overflow", "note"), "ledger refuses overflow")
	divine_probe_assert(J.record_divine_advancement(H, "Entry 1", "updated"), "full ledger can update existing entry")
	qdel(J)
	qdel(H)
	return divine_probe_failures == 0
