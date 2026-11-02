# Inactive Paper editor slice

This is a local integration candidate on the accepted #3502 tree. No player verb,
attack handler or Topic constructs the editor factory. No switch activates it.

The owned session uses the existing current-client, pen, custody, document
identity/revision/lease and spoken-language checks. It accepts only finite append,
refresh and cancel messages. Signatures come from the actual held pen. A committed
append rotates the lease; an unconfirmed response is never replayed automatically.
The UI retains an invalid or oversized unsent draft for correction.

Every sent snapshot is re-projected for the current viewer. Unsupported or stale
sessions close rather than send cached data. Unknown-language original section text
is never supplied by this UI; the existing server projection supplies placeholders.
Existing unclassified legacy text retains its existing reading policy, without
inventing a language or changing stored bytes. No reading or study XP is awarded.

The minimal modern view supports plain pen sections and an empty legacy body. It
reuses the guarded Book renderer for the document, including opaque white paper,
ink and ordinary selection/accessibility. Unsupported content, crayon fonts,
classic/forced-color rendering failure or oversized metadata fall back as a whole
to an authorized, freshly projected classic preview. The preview adds no writing
controls or legacy href cache and its owned UI rejects actions. Stored legacy HTML
retains the same rendering and authored-link boundary as the existing classic
reader; this does not make historical HTML inert. Existing unclassified legacy
writing paths remain in place until a separately reviewed activation plan replaces
them, so this slice is not end-to-end language-aware authoring for all papers.

The shared NanoUI hook consumes only this owned editor's fixed action. Its default
returns false; the original guarded src_object.Topic path remains in place for all
other UIs. Session/UI/listener state is runtime-only. Factory construction binds
before opening, uses a unique window key, and retires authority on failed or early
construction. Ordinary status checks use physical bindings; snapshots and mutations
still use the full canonical/current-state checks.

Before activation: review and compile/CI this source; integrate the final #3502
merge; decide and implement supported editing for rich legacy content/crayons and
the unclassified legacy writing paths; verify native client Topic/ready/ack,
close/logout/body transfer, owner/custody/pen changes, live observer iteration,
fallback, language/white-ink behavior, signatures, Unicode and save/reload with
an admitted isolated executor. Confirm icon/link refresh for canonical writing.
Study, forms/templates, stamp repair and filing remain separate work. No live
activation, native game run or deployment is included in this local candidate.
