# Autopilot action contract

This is the opt-in guarded queue path used by `autopilot.py`. Existing CLI,
MCP and manually written clients retain their legacy request behavior unless
constructed with `AgentClient(..., correlated=True)` and `QueueClient`.
Authentication, scopes, visibility and ordinary game action rules still apply.
A guard is an ordering ticket, not an authorization token or a new permission.

## Request and receipt identity

Every strict transport request carries a fresh UUID `request_id`. A response
must be an object with the same id, a Boolean/0/1 `ok`, and, on success, the
requested action and a result. Missing/mismatched ids, duplicate JSON fields,
non-finite JSON constants and malformed receipts stop the run. Uncorrelated
older servers fail closed rather than silently falling back.

A character observation supplies `queue.guard`. The next queue request sends
that exact guard and its transport request id. The server binds the guard to
the observing agent and character, expires it after 300 world ticks, supersedes
it on another observation, and consumes it before queue mutation. Direct manual
character actions invalidate the earlier guard too. Replaying a consumed guard,
using an older observation, or reusing any of the last 64 accepted guarded
request ids is refused before enqueueing or clearing. A fresh guard does not
make an old model decision current: the autopilot separately re-observes and
checks its character state and referenced visible targets before applying it.

`character_queue` returns `state: accepted`, its `request_id`, and the queued
step ids. Acceptance only means the plan entered the queue. Each terminal
step result has `state: completed`, the originating request id, step id, action,
`ok`, detail and world time. Completion means the game action procedure returned,
not that the intended craft, movement or social outcome happened. The autopilot
also waits for an empty queue, `running: false`, and no timed work (`self.busy`).

Only one accepted plan per character is outstanding in the strict client.
The guarded server path likewise refuses new work while another queue or timed
action is active. A hard failed step or a blocked move skips the remaining
stop-on-failure suffix. The client does not continue later high-level steps
after a hard failure or refusal. Existing explicitly soft inventory steps keep
their best-effort behavior.

Completion receipts must match every accepted id and action. Repeated identical
polls are fine; duplicate ids within one response, changed receipts, missing
terminal results, mismatched request ids or out-of-order ids are not. Results
are retained for 64 steps. Until the whole plan is terminal, the strict client
polls below its first accepted id, even if a cancelled suffix finishes before
a running lower-id action. Legacy clients using `queue_since` must likewise
not advance their cursor past an unfinished step.

## Model decisions and deterministic reflexes

There is one inference worker and one pending decision id. Completion consumes
that id once. Expired, cancelled, duplicate or unsolicited answers cannot run.
The final observation rechecks position, consciousness, movement/busy state,
hands, inventory and intent; referenced targets must still be visible with
unchanged material metadata, including hazards, amounts, contents and position.
Positive oven-fuel drift is allowed, but exhausted fuel is a material change.
Naturally ticking health, wounds and needs are evaluated from current state
by deterministic survival logic instead of indefinitely discarding answers. Expansion uses the fresh observation, and a
new urgent threat still invokes the deterministic reflex instead of the answer. This cannot establish durable atom
identity after ref reuse, and ordinary game targeting remains the authority.

The existing deterministic reflex poll keeps running while inference waits.
If it acts, the older model answer is discarded. A lost character observation,
death, run deadline, model timeout or pause ends the wait. The inference-only
worker is a daemon thread with no game client. A late HTTP response cannot
apply an action or keep process exit waiting for a hung inference thread.

## Timeouts, reconnects, cancellation and manual control

- Read-only polling may retry after a transport timeout. Strict mutation calls,
  including release, are never automatically resent. A malformed mutation reply,
  runtime-error response, disconnect or timeout makes the outcome uncertain.
- The client retains accepted or uncertain request identity, stops subsequent
  work, and exits with code 2. `--watch` holds that character instead of restarting
  it automatically. After inspecting current state and any effects, an operator
  may deliberately restart. Restarting is not proof that an earlier action failed.
- Queue waits have a 30-second limit. Partial or empty receipts at timeout are
  not success. On exit the run attempts a fresh observation and one guarded
  cancellation targeting only its own request id. A failed cleanup is reported,
  not retried or described as successful. Another operator's queue is preserved.
- `clear: true` validates the entire request before changing anything. Optional
  `cancel_request_id` restricts cancellation to that request. Guarded cancellation
  cannot also replace the plan. Pending steps receive terminal cancellation
  receipts. Running game procedures are not rolled back or forcibly killed;
  their eventual receipt warns that effects may already have happened, and their
  repeats cannot revive a cancelled plan.
- `--pause-file PATH` stops work while an operator-controlled file exists. The
  same path reaches every watched child, including its model/queue waits. The
  watcher stops launching children and lets them perform their own cleanup.
  The watcher waits at most 120 seconds for cleanup, reports an unconfirmed stop
  if children remain, and does not forcibly kill game work. Ctrl+C also signals
  children through a shared pause file (a unique private runtime file when no
  path was supplied). Explicit operator files are never removed automatically.
  Keep the file in place until the runs exit; remove it and deliberately restart
  to resume. No new mutation is sent after the client sees pause, except cleanup
  cancellation or an explicitly requested `--release`.
- The player's existing Toggle AI Control and character release remain the
  manual takeover paths. They invalidate control and cancel pending work. Scope
  or identity/config replacement is rechecked before queued steps, including waits. No pause mechanism
  changes credentials, host configuration or production activation.

## Verification and limits

Offline replay: `python -m unittest discover -s tests/agent_control -p test_action_contract.py`.
It uses only synthetic observations, fake request data and an in-memory transport.
The existing suite remains `test_agent_control.py`; navigation replay is separate.

The production-source native assertions are in
`tests/agent_observe/action_contract_probe.dm`, included by the existing opt-in
`tests/agent_observe/run.py` fixture. They cover guard consumption/expiry/order,
request-id duplication, acceptance/completion, malformed replacement, pending
work, targeted cancellation and scope loss.

The fixture was compiled with BYOND 516.1688 (0 errors, 0 warnings). Runtime
execution was not validated here: its shared runtime verifier unconditionally
requires the pinned Linux archive, so the Windows runner stops before launch.
That integrity check was not bypassed. No live server, production data, rollout,
or external model service was used. Source compilation and offline replay do
not establish in-game cancellation timing or native acceptance.
