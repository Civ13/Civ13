# Legacy telephone recipient characterization

Run the offline source-only suite with a verified Python executable:

```powershell
& $PythonPath -B -m unittest discover -s tests/telephone -v
```

The production change replaces the local seen-human list's repeated `Find`
checks with associative identity flags. It retains registry order, marks a human
before the consciousness check, and preserves every matching visible-phone
delivery. Two different matching phones may legitimately produce two deliveries
to one hearer; this change does not collapse that existing multiset.

`fixtures/telephone_before.txt` freezes the five relevant procedures from master
`9d3c1d5a02ba2c1e7e00b27de7a0102e357292dd`. Tests never query Git history.
Complete production bodies execute through the existing reviewed source adapter.
Only list/type/view, input/output/icon and timer boundaries are inert adapters.
String interpolation retains message text with deterministic icon tokens; it does
not validate native bitmap compositing. Python's stable event queue models the
six explicit callback registrations without changing production scheduling.

Cases cover duplicate registry identities, distinct same-name humans, overlapping
phone views, unconscious/empty listeners, emotes, live link changes during delivery,
duplicate dial numbers/busy early return, answer/hangup message counts and ground
versus held peer delivery. Ring/call procedure statements remain unchanged.

The legacy callback behavior is characterized, not repaired: cancelling an
outgoing unanswered call can leave the remote ringing, and old captured-origin
callbacks/200-tick timeout can affect rapid redial. The model reproduces those
source behaviors before and after this change. Fixing them requires a separate
behavioral slice, not a scheduling-loop rewrite in this refactor.

No compiler, native daemon/client, real clock, socket, message transport or save
is launched. Native list lookup cost, callback timing, sound, UI and gameplay
remain unverified. No FPS or measured CPU improvement is claimed. Modern network
landline overrides are separate and untouched.
