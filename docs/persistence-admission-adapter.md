# Incomplete admission adapter candidate

`code/modules/persistence/admission_contract.dm` supplies runtime-only typed
policy, guard and capability interfaces. It installs no provider, client gate,
background fence or faction activation. Base policy methods deny every request.
Including the file alone changes no ordinary null-policy loading behavior.

The implemented interface-independent behavior is binding validation, copied
scalar selection fields, exact action matching, guard revision invalidation,
and complete capability rechecks after each provider call, including rejection
when callbacks delete the capability, guard or provider. `revoke()` drops the policy and
selection and invalidates previously issued capabilities. `acquire()` and
`permits()` require exact TRUE from recovery readiness and provider validation;
missing or unavailable provider state denies. Callers must check `permits()` again
after any yield and immediately before effects. Local fields and callback TRUE
are an adapter contract, not evidence of durable custody or authenticated identity.

Binding fields are server, world, root, process, operation, generation, members
and schema. These are prototype interface names, not a selected host ABI. `members`
must be the host-bound identity of the exact manifest, not a caller path list or
an invented hash proof. The future provider owns authentication, issuance,
revocation and durable recovery. All strings are bounded scalar values; this
guard does not parse production schemas or normalize paths on the host's behalf.

Base `reserve_restore` returns FALSE, `recover_pending` and `finalize_restore`
return null. Reserve's eventual implementation must durably commit reservation
and conservative mutation-started before TRUE. No method marks local recovery
complete, finalizes through transient release or creates a synthetic host receipt.

The smallest next insertion plan, conditional on actual host selection, is:

1. Create the selected-world guard blocked before constructors/background startup;
   reconcile host pending operations before granting capabilities. The delayed
   `setup.dm` loader is too late to establish the initial fence.
2. Make extraction service readiness require a current capability before journal
   repair or account access. Add separate client attachment, direct store write
   and background materialization guards from the accepted admission inventory.
3. Bridge restore-policy reservation to the same binding, then add explicit restore
   verification/finalization and startup reconciliation. Close transient readers
   independently; null-policy ordinary loading remains supported but cannot admit
   durable faction state.
4. Revalidate capabilities after player prompts/extraction waits and before debit,
   decode, movement and settlement. Fence already connected bodies and ownership
   mutations, not merely terminal admission.

Those insertions are not implemented here. Missing host API/authentication,
immutable members, durable journal, stable production identities and faction
admission decisions remain blockers to an integrated provider. The candidate is
uncompiled and unrun; no runtime/containment or production readiness is claimed.
The focused fixture and omission controls are described in
`tests/persistence_admission/README.md`. Its proposed remote CI step includes the
existing ordinary legacy/v2 restore round trips; execution scope and source review
remain pending. Local helper and native execution remain held.
