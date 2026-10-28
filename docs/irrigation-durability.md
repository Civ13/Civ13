# Irrigation durability candidate -- unpublished, engine acceptance pending

This candidate addresses ordinary floor irrigation only. Source baseline:
`067478b82c7ad9f1b83759a221e6f22080ba865a`. The candidate was reconciled in a
separate full checkout at that exact commit. Historical source-only candidate
`5c6b96ab010b8121f5b1e8b5894b81d4fb25acb1` remains preserved separately.

## Source correction

- Active channels append `irrigation_save_version=1`, `irrigation`, `flooded` and
  `salty` through a parent-calling floor get_saved_vars override. Explicit zero
  values are retained by the existing generic scalar encoder. Inactive floors
  do not gain four fields each. Dirt fertility and native trench progress retain
  their existing inherited save admission.
- Derived irrigation_overlay is excluded from custom export/import. All loaded
  floor types reset irrigation fields to their own native defaults before saved
  fields decode, including same-type ChangeTurf reuse. Natural salty/flooded
  subtype defaults are not forced to zero.
- The existing placed-turf preflight pass invokes one floor-specific validator.
  Its helpers inspect scalar envelopes, never graph-decode a saved reference.
  Unsupported/incomplete/contradictory tuples fail before clearing the map.
- The existing per-level after_load phase rebuilds channel junction overlays
  after same-level flags decode. It performs four cardinal neighbor checks per
  channel. It does not call irrigate, check_relatives or expand_flood, create a
  timer, change layers, or charge crop resources. Restoration replays saved
  flags exactly; it is not a source/contamination event.
- Full-checkout reconciliation found snowfall already owns floor after_load.
  Its existing hook is unchanged; the parent turf hook restores irrigation.
  Irrigation replaces only its own overlay instead of calling update_icon,
  which clears the whole overlay list. Both restoration behaviors are retained.

Two guarded callsites are added to loading.dm: floor reset before payload decode
and floor-specific validation in the existing preflight pass. Save transactions,
operation ownership, graph encoding/decoding, frame transfers, publication and
recovery architecture are unchanged. These hunks need Main's integration review
alongside nutrition's separate transaction-contract work.

## Compatibility and limits

| Input | Result |
| --- | --- |
| Version-1 1/0/0 | Restore dry channel and dry junction overlay |
| Version-1 1/1/0 | Restore freshwater channel, including after original source removal |
| Version-1 1/1/1 | Restore salty channel; adding freshwater does not clear saved salt |
| Version-1 incomplete fields, wrong envelopes/types, unsupported version, inactive or dry-salty tuple | Reject in existing preflight before ClearMap |
| Unversioned explicit irrigation/image field | Reject with explicit review diagnostic; no silent migration |
| Legacy canonical channel name but no durable tuple | Reject as ambiguous; do not infer freshwater/salt from artwork/name |
| Old ordinary floor/native flooded trench without a channel tuple | Keep its existing native import behavior, after resetting stale destination channel state |

The historical design proposed a level-wide active-channel index to detect a
whole tuple omitted from an otherwise versioned file. This narrow correction
deliberately does not add file-header, transaction or manifest architecture.
Consequently, omission of all four fields AND use of an arbitrary custom name is
indistinguishable from an old ordinary floor entry. It cannot be detected by this
candidate. Original flags of those historical saves cannot be reconstructed.
That boundary remains explicit for Main; no name-based salvage is performed.

No natural-source volume, drainage, salinity propagation, water-use, growth,
harvest, research, greenhouse, weather or roof policy is changed. Saved wetness
survives source removal. Native construction can still have transient effects
before payload decode, but admitted saved flags overwrite those defaults;
engine acceptance must check that assertion rather than assume it.

## Validation actually run / gates

The workflow explicitly prepares the immutable baseline SHA before these tests;
the tests themselves never fetch or skip a missing baseline. The new hosted
fixture step uses an explicit 516.1688 runner profile for normal/filling/digging
cases. Historical callers still default to strict 516.1681. Compile-only mode
returns before a local daemon or config/name copy, with unchanged 120/60-second
compiler/runtime limits. Hosted fixture results are separate from full-game
compiler results and remain pending until observed.

Offline checks cover source-blob baselines,
translated production preflight helpers, JSON disk round trips and mutation
controls. The complete previous irrigation file and loader project back to the
baseline after removing only the new block/two guarded callsites; the snowfall
file is byte-for-byte unchanged.

Prepared native ordinary-channel fixture: NOT RUN. BYOND
savefile round trips, actual after_load ordering, same-type replacement behavior,
rendered overlays, runtime diagnostics, full-map compatibility, CI and deployment
remain unverified. Compile-only receipts, if present, establish source/toolchain
acceptance only. No engine/client/server was launched, no public PR or branch
is implied by local validation, and the dirty playtest checkout was not edited.
