# Offline agent gateway language experiment

Tracks [#4021](https://github.com/Civ13/Civ13/issues/4021). This is an experiment,
not a PHP replacement for Ada, Player Help, or the DM agent server. No production
behavior, live configuration, permissions, credentials, or deployment changes.

## Question and scope

Would a PHP adapter reduce the CPU cost of Civ13's existing Topic client boundary?
The Python worker calls the real `AgentClient.request`, `encode_topic`, and
`decode_topic` in `../civ13_agent.py`, with an injected in-process transport.
The PHP 8+ worker is a narrow prototype of that boundary. Neither opens a socket.

Each cycle processes the same five deterministic, synthetic cases: status, a
Unicode action, a two-step queue, and observations with 8 and 128 nearby objects.
Both workers build compact JSON arguments, URL-encode the same fields, frame a
BYOND Topic request, decode a prebuilt string reply, parse its JSON, and consume
its revision plus request length. The synthetic token is `not-a-real-token`.
The full production action-name catalog is supplied to both workers, outside timing.
No user data, real tokens, game saves or environment credentials are inputs.

Before *any comparison*, the harness demands identical outgoing packet bytes and
parsed responses for every fixture. A mismatch or missing PHP executable fails
rather than printing a speed ratio. This is corpus parity, **not** complete
protocol/client compatibility. Floating-point serialization, malformed packets,
numeric/null replies, socket framing under partial reads, timeouts, authentication,
long polling, MCP dispatch, persistence, and gameplay are outside this prototype.
There is no reason to deploy it.

## Run

Use an already approved Python 3.10+ and PHP 8+ CLI installation. The harness does
not install anything. Do not run against a game server; there is no host option.

```sh
python3 tools/agent-control/benchmarks/test_gateway_benchmark.py
php -n -l tools/agent-control/benchmarks/gateway_worker.php
python3 tools/agent-control/benchmarks/gateway_benchmark.py > /tmp/gateway-benchmark.json
```

Use `--php /path/to/php` to select an installed CLI, or `--python-only` to smoke-test
only the Python side. Python-only output explicitly says parity was not run and
contains no PHP results. `--samples`, `--iterations` and `--warmup` control the
workload; defaults are 7 independent samples, 2,000 cycles and 100 warmup cycles.

PHP runs with `-n` to ignore php.ini; compiled-in extensions can remain available.
The harness requests no additional extensions or JIT and records the loaded
extensions plus opcache/JIT settings in the parity result. Python uses
isolated mode and `-B` (no bytecode writes). The worker avoids orchestrator-only
imports so those are not charged to Python cold startup. Child environments allow only OS path/temp essentials and disable
Python bytecode writes. Both run one process at a time, alternate sample order,
and use monotonic nanosecond clocks. Fixture construction/imports are outside the
warm timer. Each warm sample starts a fresh interpreter, then warms that process.
The cold metric includes interpreter startup, imports, input parsing, fixture
construction, and one five-request cycle. It is not an HTTP/server startup test.
Warm results are microseconds per operation averaged over that five-case mix;
p95 is nearest-rank across sample averages, not per-request tail latency.

The JSON report includes every sample, versions, platform, corpus/catalog/client/
harness/PHP-source hashes,
checksum, median and p95. Keep raw receipts outside the checkout unless deliberately
reviewed for publication. These reports do not capture memory, CPU frequency,
core pinning or system load; compare repeated runs on a quiet representative host
before making a decision. PHP and Python implementation/library differences are
part of this adapter comparison, not a universal ranking of the languages.

## Interpretation and adoption gate

No measured Python-versus-PHP speedup is established by this PR. PHP syntax,
execution, corpus parity and comparative timings remain unverified until run with
an approved PHP runtime. The Python harness tests in the existing `agent_control`
CI suite do **not** validate PHP. They do not silently skip or simulate that claim.

Even a large microbenchmark speedup does not imply faster model inference or a
faster player-visible response. Profile the real bridge phases first and apply
Amdahl's law: if this boundary occupies fraction `f` of response time and improves
by factor `s`, the ideal total speedup is `1 / ((1 - f) + f / s)`, before any new
interop/startup overhead. For example, making a 1% component twice as fast improves
end-to-end time by only about 0.5%. That is an illustration, not a measured Civ13
fraction.

Before any port: establish parity beyond this happy-path corpus, measure the
actual production bottleneck on an authorized workload, preserve all catalog,
authentication, timeout and error semantics, quantify maintenance/dependency cost,
and obtain Fable's review. Keep Python unless an evidence-backed port is worth it.
