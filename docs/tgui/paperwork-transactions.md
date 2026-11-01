# Paper transactions: first integration slice

Base: merged reader30be33c31e21be5131651ea57f08319167a07602. This slice does
not initialize classified documents from a
player route, add a language selector, enable TGUI authoring or change pencode.
Copying, rename/airplane/crumple adapters and subtype/system writers remain
activation prerequisites in the source-boundary audit.

## Shared data transaction

The internal prepare/commit functions validate an existing v1 record and its
opaque legacy snapshot, then make a bounded candidate copy. The token captures
the original record reference, identity/revision and complete canonical/physical
snapshot encodings. It is never stored on an item, persisted or sent to a UI.
It is a server data-consistency primitive, not a grant of actor or machine access:
each caller must retain its own current actor/tool or trusted physical-event
admission. Typed append retains every existing controller/client, language,
pen, identity, revision and capacity guard before committing through it.

Commit rejects replacement or in-place mutation of the original, legacy drift,
bad schema/identity, section-sequence rollback, anything other than exactly one revision increment, and
invalid/oversized candidate data. It copies both the committed canonical record
and physical legacy fields separately, so neither aliases the caller's mutable
candidate or each other's lists. It performs explicit legacy-field assignments
without callbacks/yields, then installs the record. Effects/cache rebuilds remain
after successful commit. Whole records keep4096nodes, legacy snapshots1024nodes,
depth16/text-unit131072 bounds and the independent128-section/3072-text/capacity
limits. No language/lineage translation or invented author provenance occurs.

## Chemical clearing

Acetone and ethanol already invoke clearpaper. Legacy-null clearing preserves
the previous operation's values: info/stamps become null, stamped becomes empty,
capacity resets; the old field counter and icon-offset lists remain unchanged.
Classified clearing changes that same legacy data and removes every section in
one transaction, keeping document identity and monotonically increasing section
sequence while advancing revision once. Stale prepared edits/appends cannot
restore erased text. No ordinary erase action or new UI endpoint is added.

Unknown/malformed/stale/overbudget records or exhausted revision cannot be
silently repaired or converted to legacy-null by erasure. Refusal preserves
physical/canonical fields, overlays and cache/icon effects. Reagent callers now
emit their success message only when clearpaper returns true. This is a trusted
physical reagent event, not a new actor-less authoring API. Native reagent
dispatch, sound/message delivery and save/load still require acceptance.

## Legacy prompt boundary

Legacy field/EOF editing binds the original body/client and actual held pen
before input, then rechecks them and the paper after input. Classified or unknown
records are refused at both points, including a legacy prompt crossing into a
classified state. Logout/reconnect/body transfer, incapacitation/restraint, pen
loss/change/deletion and lost physical access reject before parsing/effects.

Physical admission is explicit: held sheet or adjacent turf; held/adjacent-turf
clipboard/folder; actual current bundle page with held/adjacent-turf bundle or
eligible folder; opened held/adjacent-turf envelope. The existing knifed-envelope
state uses opened even if its historical sealed flag remains set. Closed
envelopes, deleted containers, off-page bundle refs and unsupported/nested
storage paths are refused. This tightens the old blanket Adjacent shortcut;
it does not claim that every storage type has a modern adapter. It introduces
no ghost-range write bypass and no new species/language comprehension rule.
Legacy pencode/field ordinals and existing signature/ink formatting are unchanged.
Full input scheduling, movement and browser-close behavior are not projected by
these tests; the future TGUI editor still needs request-generation cancellation.

## Verification and remaining activation work

The registered paper suite adds complete selected production helper/clearpaper
projections, with explicit inert overlay clear, href rebuild, icon callbacks,
client/type/range/list seams. The adapter models DM record-reference equality
as identity, rather than Python dict value equality. Topic domination and the
two reagent success-call sites are source contracts, not native execution of
the entire prompt/reagent stack. Unknown statements/call methods still fail
projection preparation. Causal controls remain local-only, as documented.

The first preparation failure was an unsupported attribute-call statement in
the strict adapter, corrected without dropping the real overlay/icon/cache
statements. A subsequent source-contract extractor stopped at an existing
unindented block comment; the test now bounds Topic at the next real procedure
and asserts required markers before indexing. The existing selected-page reader
control also encountered a duplicate anchor in the new write guard; it now
mutates only the original complete reader-admission procedure and retains the
same behavioral assertion. All three failed observations/logs are retained
privately. They are not successful negative controls.

No new compile, native client/Topic/reagent, Unicode indexing or save round-trip
acceptance is claimed. The earlier native socket hold remains. Existing game
source includes both touched DM modules already; no new fixture/controller or
native CI selector is added. The normal offline paper registration explicitly
includes the new mutation test file, plus a registry contract.

Before authoring activation: finish label/damage adapters; use one canonical
copy installer for printing press and faction mailbox (new document identity,
preserved section language/lineage/version/ink/signature, independent lists and
rebuilt hrefs); handle deferred constructors and teleprinter ownership/language;
then expose typed editing/forms and the separately reviewed study system.
Do not pass edit tokens or canonical originals to client previews/fallbacks.
