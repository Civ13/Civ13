# Blackpowder regression

Run `run.ps1 -ByondBin <516.1681-bin>` for production assembly, forge payment,
interruption, concurrency, catalogs and native item persistence with isolated
startup, actor/inventory and selected wait adapters.

Forge interruption cases explicitly disable native stack auto-merge when creating
fresh steel inputs and assert they are live before invoking the forge. Otherwise
new stacks merge into existing held steel and retire before the wait, causing
cancellation cases to pass without exercising interruption. Production stack
merging and forging behavior remain unchanged.

`-ForgeMergeControl` restores constructor auto-merge and must fail only at the
fresh-material assertion. `-NegativeControl` removes post-wait part compatibility
in a generated production copy and must detect the missing-flint rejection.
Controls require clean compilation and reject native engine diagnostics, even if
an expected assertion failure is present. They cannot be combined.

These are isolated source/runtime contracts, not client or live-server acceptance.