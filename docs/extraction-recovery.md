# Offline extraction journal reconciliation

These are operator procedures for the sole server's extraction directories.
They are never invoked by login, map startup or timers. They do not authorize a
production stop/restart or actual account loss. Obtain that operational authority
separately. The current implementation starts a fresh raid on world restart;
it does not resume an active raid or reconstruct unsent physical loadouts.

Stop the sole process using the selected directory. Preserve an offline copy of
the entire account, loot and world journal directories and any relevant runtime
logs before changing a record. The command requires an explicit stopped-server
attestation; it cannot independently prove that another machine has no writer.
Use BYOND 516.1681 and a verified Python interpreter. This launches only a small
closed-port journal world, never normal game startup, clients or outbound hooks.

## Inspect and select the result

`--store-root` is the directory directly containing owner folders, such as the
disposable world's `data/extraction_accounts`, `data/extraction_loot` or
`data/extraction_world`. Use an absolute path. An account owner is its canonical
registered ckey; loot owners are `container1` through `container64`, and the
epoch owner is `world`. Do not substitute an unrelated save directory.

```powershell
& $PythonPath tests/extraction/recover.py --byond-bin $ByondBin --store-root $StoreRoot --owner $Owner --action inspect
```

Keep the JSON report with the preserved evidence. Read the newest generation,
its intent digest and pending flag. There must be exactly one next incomplete
revision, with a valid preceding revision (or a new empty account). Wrong owner,
generation, digest, ambiguous slots, unsupported profile or replay is rejected.
Inspection does not alter any journal. Its temporary binary/report/log are removed.

If the complete intended snapshot survives and matches the intent byte digest,
complete that exact revision:

```powershell
& $PythonPath tests/extraction/recover.py --byond-bin $ByondBin --store-root $StoreRoot --owner $Owner --action complete-snapshot --generation $Generation --digest $Digest --offline-confirmation sole-server-stopped
```

Completion does not copy gear from the preceding slot. Before recovering a
nonempty stash it checks stable root and nested identities against current
profiles in the same store, with a 4096-directory-entry and 2048-node budget.
Already owned components, other unresolved accounts, malformed records and
legacy graphs without nested identities require manual evidence reconciliation.
No account credit is inferred from those cases. It does not establish ownership
in a different server's directory; sharing a journal across servers is unsupported.

For a committed loot profile with `loot_state = pending`, inspect its exact
`pending_item.id`. Retire an uncertain delivery rather than reissue it:

```powershell
& $PythonPath tests/extraction/recover.py --byond-bin $ByondBin --store-root $LootRoot --owner $ContainerOwner --action retire-delivery --generation $Generation --item $ItemId --offline-confirmation sole-server-stopped
```

This removes the pending reference and records its identity/revision. It neither
returns the item to the container nor credits any account. Other unclaimed loot
remains. A successful fresh raid can reset this resolved container normally.

If the intended bytes are missing, corrupt, or conflict with another owner's
gear, exact completion is unavailable. An explicitly approved loss settlement
can unlock the journal by discarding the entire stash and garage, including previously
secured gear. It preserves only the previously committed house level, clears
uncertain loot, advances the raid sequence and records the discarded intent.
This is permanent loss, not selective restoration or a refunded upgrade:

```powershell
& $PythonPath tests/extraction/recover.py --byond-bin $ByondBin --store-root $StoreRoot --owner $Owner --action settle-loss --generation $Generation --digest $Digest --offline-confirmation sole-server-stopped --loss-confirmation discard-account-stash
```

Malformed/ambiguous intents still require forensic repair from the preserved
evidence; the command cannot guess a revision. Never delete a newer intent to
make the old stash load. Never manually add IDs to another account to compensate
without reconciling their ownership.

## Preserve the receipt and verify

Snapshot completion and loss settlement first write `recovery.latest.json` in
the selected owner folder. Loss settlement preserves both slots in that receipt;
exact completion preserves the intended snapshot and overwritten commit. There
is one fixed receipt, not an accumulating runtime recovery history. A second
recovery refuses to overwrite it. Archive the existing receipt with the offline
backup and verify the archive before removing it for a subsequent recovery.
If recovery itself fails, retain both slots and the receipt; inspect again and
resolve the new exact state instead of repeating old parameters blindly.

Reinspect after success. Verify the committed generation and intended stash or
empty loss result, then start only an authorized disposable world for acceptance.
Real-client item appearance, concurrent login rejection and whole-world restart
remain separate acceptance checks. Do not declare a delivery, insurance payout
or trade settled solely because its account journal was made readable.

Native regressions are `tests/extraction/run.py --probe store` and
`tests/extraction/test_recovery.py`. They cover matching bytes, wrong bindings,
nested ownership conflict, no rollback, retained receipts, replay, non-reissuing
loot retirement and explicit stash loss over disposable native journal files.
