# Shared paper reader boundary

This source slice follows the versioned document foundation and incorporates
master `fe45306ae516d33abd00e888f1919cfbcf91e142`. It connects existing classic
readers. There is no new TGUI screen, language-selection UI, authoring action,
study progress, stamp repair or live-save migration.

## Routes and admission

`paperwork/view.dm` supplies a per-request, read-only subtype of the existing
document service. It binds the actual controller/client, refuses mutation through
its inherited APIs, and rechecks the actual paper/container/page before projection.
The base document/language implementation and mutation predicates are unchanged.

| Route | Integration and preserved admission |
| --- | --- |
| Paper examination/show | Uses the existing range or observer admission, and the actual supplied reader. Human/ghost/forceshow literacy remains separate from knowledge. |
| Clipboard and folder | The actual paper must still belong to that actual held container; state/restraint and linked client are rechecked. |
| Bundle | The actual paper must be the current valid selected member, physically in that bundle, with current holder/range/observer admission. Existing navigation, removal and photo behavior remain. |
| Noticeboard | The actual paper must still be pinned to that actual adjacent board. This additionally refuses stale distant read links rather than trusting the earlier menu opening. |
| Legacy editor open/refresh | The existing state/physical predicate is retained. Only a null/unclassified record may use its legacy `info_links`; classified records always use the service projection. Pen and write transaction logic remain in the old handlers for the later authoring slice. |

Direct paper examination uses its existing physical admission; it does not create
a new envelope/seal context or a new client-callable read endpoint. Container
menus still perform their existing admission checks. The per-request context
adds current membership/session checks, not a general authorization to read
arbitrary descendants. Reader contexts are runtime-only and are not save data.

## Data and compatibility

Uninitialized papers are viewed without initializing or persisting a record,
minting identities, requiring a pen, inferring a language or changing stored bytes.
Original legacy HTML remains opaque. Ordinary paper/container readers retain the
existing literacy mask; noticeboards retain their historical TT legacy body
without stamps, and old editor views retain their historical unclassified cache.
This does not expand comprehension of any language-tagged section.

Classified records first pass the unchanged foundation validation, legacy-source
freshness check and per-section knowledge/literacy projection. Unsupported or
stale records yield a fixed unreadable view, never a raw cache or partial repair.
The legacy portion remains explicitly unclassified; new body/title/label/answer/
signature sections expose either understood text or the server placeholder.
No canonical record, hidden original, tooltip, accessibility label or copy payload
is sent by the new reader boundary.

All new section text is HTML-encoded, preserving literal markup and line breaks.
Already encoded legacy labels are decoded exactly once and re-escaped for the
HTML title context; stored names and window identifiers remain unchanged.
Only validated ink is emitted, with the existing pen/crayon/signature font defaults
and a white page. Crayon signatures retain both the signature's italic styling
and the crayon's enclosing bold styling, matching the existing pencode renderer.
Old HTML, dates, signature text and concealment are not reparsed
or regenerated. White ink remains visual concealment, not identity authority.
The old classic HTML execution boundary is unchanged; this is not a historical
HTML sanitizer or a complete secure-paperwork claim.

The centralized classic payload is used by paper, clipboard, folder, bundle,
noticeboard and both legacy editor open/refresh paths. Bundle controls remain
outside the paper body and contain no canonical sections. Existing paper labels
remain legacy labels; a language-bearing title section does not overwrite them.
No new persistent UI process or close/using_object hook is introduced. Existing
onclose calls and detached snapshot behavior remain, rather than claiming already
sent plaintext can be revoked after a later body/language change.

## Verification and remaining dependencies

The registered `paper_documents` suite now runs 35 source-projection tests:
22 foundation and 13 reader tests. Reader tests execute complete route-access,
request-access, data-projection and section-render procedures through the existing
bounded Python adapter. Engine range/client/list/HTML seams are explicitly inert;
they are not native or browser acceptance. Eleven causal controls fail by assertions
when client, membership, page, range, read-only, encoding, error or cache boundaries
are removed. These controls are local-only. The CI registry suite passes 65 tests.

The earlier foundation-only native fixture compiled with 516.1688 and zero errors/
warnings, then failed the existing any-sampled-socket rule at engine startup.
No writer assertion/save generation completed and the reader never ran; retained
cleanup completed. That compile does not cover this new reader delta. Native
retry remains held. This source slice has no new native CI handler or fixture
selection; ordinary production compilation and bounded offline CI remain selected.

Next: review this boundary, then add TGUI rendering, then join legacy mutation
transactions and classified authoring with explicit spoken-language selection.
Renaming, incomplete/stable fields, crumpling/clearing, printing/copying and subtype
adapters must be resolved before that authoring activation. The old copy paths
are not a new faithful versioned copier. Forms/stamps, filing and deliberate study
remain later bounded work. Native save/load, real Topic/client authority, seals,
close/body transfer and actual visual ink delivery remain unverified.
