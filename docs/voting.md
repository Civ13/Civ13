# Cancellable votes

`vote.request_vote(mode, initiator, automatic, completion)` returns a
`/datum/vote_handle` or null when a request cannot start. Existing
`initiate_vote()` callers retain their Boolean adapter and cooldown behavior.
Map, epoch, restart, gamemode and ship selection retain their route logic.
The gamemode adapter does not call the same process swap twice when it is
already the supplied completion callback.

For new deployment or consent flows use
`vote.request_choices(question, options, initiator, duration, completion,
automatic)`. Options are bounded text choices; duration is 10-6000 ticks.
There is one active server-wide vote. An overlapping request fails rather
than silently replacing it. Cancel the old handle explicitly before starting
a replacement. Ordinary requests preserve the existing vote cooldown;
automatic callers retain the existing exemption.

Handles expose `state` (`pending`, `resolved`, `cancelled`), `generation`,
`deadline` and `winner`. `cancel()` succeeds only while that exact request is
current. It closes tracked vote windows, clears ballots and detaches callback
references without invoking winner effects. `resolve()` is an internal caller
operation, not a client action. Expiry resolves through the same operation.
Generic requests with no ballots resolve with a null winner and invoke their
completion once; legacy modes preserve their defaults and callback behavior.
Callers must check a null result before performing an action.

Completion is a two-element `list(target, proc_name)` called with the winner.
The state becomes terminal and the UI/session is detached before this call.
The manager checks the generation again afterward: if the callback creates a
replacement, old route effects cannot affect it. No old reset follows the
callback. A stale handle, ballot generation or timer cannot resolve or cancel
a replacement. Custom-vote input stores choices locally and checks its setup
generation after each input wait.

The extraction concourse retains its handle and cancels it at round closure.
Future deployment flows should retain their handles and cancel when their
own eligibility, party or round lifetime ends. A vote result does not itself
authorize inventory changes; deployment must revalidate authoritative state.

`tests/extraction/run.py --probe mode --byond-bin <516.1681-bin>` runs production
handle lifecycle code with temporary storage. It covers cancellation, expiry,
replacement, stale ballots/timers, callback reentry, cooldowns, generic empty
results and exactly-once legacy adapter dispatch. Its route adapter records
requests instead of deploying or restarting. `--vote-negative-control stale`,
`cancel` and `reentry` each mutate a temporary source copy and must fail at the
corresponding assertion. These tests do not establish connected-client browse
rendering, production restart behavior or gameplay acceptance.
