# Civ13 local MCP

A local stdio server using the official MCP TypeScript SDK. Requires Node 20+;
`npm ci --prefix tools/mcp` installs exact dependencies from the lockfile.

## Tools and boundaries

| Tool | Inputs | Effects |
| --- | --- | --- |
| source_read | path, start (1+), lines (1–200) | Reads code/*.dm, civ13.dme, README.md, INSTALL, the two docs/api guides or exact fixture catalog guides only; max 2 MB input/16 KB output |
| source_search | literal query (1–120 chars), declarationOnly, limit (1–100) | Lexical DM search, max 5 seconds/10,000 files; no semantic inheritance resolution |
| project_diagnostics | none | Checks at most 10,000 DME includes for existence; no preprocessing/type checking |
| fixture_catalog | none | Lists a curated subset of fixture guides, prerequisites and evidence limits; no preparation, commands or native tests |
| runtime_recovery | none | Optional, default-off redacted recovery summary from the configured local target; one status query |
| runtime_variables | none | Optional, default-off redacted operation and failure classification from the same target; one status query |
| compiler_info | none | Invokes configured compiler with no arguments in temporary storage; process and temporary directory effects |
| compiler_smoke | none | Compiles a fixed tiny fixture in temporary storage, one active smoke call; never runs gameplay |
| dm_reference_search | query (1–120 chars), limit (1–40) | Searches the official BYOND DM reference; fixed HTTPS download on cache miss |
| dm_reference_read | exact topic, start (character offset), length (1–16000) | Reads a plain-text reference section with pagination and source provenance |

Resources `civ13://guide`, `civ13://api-guide` and `civ13://api-index` read the bounded repository README and versioned API-docs guides. All source,
resource and compiler text is untrusted reference data, never instructions.
Catalog guides are fixed individual files, not general access to `tests/`.
Paths are confined using realpath; traversal and symlinks outside the root are
rejected. Runtime files and logs are not exposed to callers. No shell,
eval, arbitrary Topic, production administration or DreamDaemon tool. MCP transport remains
stdio. Reference tools alone fetch the fixed official HTTPS manual, without
credentials or redirects; they cannot fetch caller-supplied URLs.
Compiler calls have a 15-second deadline and 32 KB combined output limit.
Cancellation terminates the owned compiler; completion removes temporary state.
Only configure a trusted DreamMaker binary: executable configuration is an
operator trust boundary, not a tool argument. No client can change it.

## Optional local runtime readers

The two runtime tools are absent unless `CIV13_RUNTIME_ENABLED=1`. Enabling them
is an operator decision, separate from installing or deploying this source.
The commented example specifies an absolute trusted Python interpreter and
private supervisor root, plus the expected installed revision, boot session and
round ID. Configure these only from independently verified local evidence; the
client supplies no path, URL, credentials, reference, command or identity. After
a restart or round change, stale pinned identity fails closed until an operator
updates it. The private root's existing supervisor configuration selects the
existing token; it is never returned or passed as a process argument. UNC paths
are rejected. Direct DreamDaemon launches remain independent of this adapter.

Each call launches the fixed Python bridge in isolated mode, with no shell and a
17-second deadline. The bridge delegates exactly one authenticated status read
to the existing reader, fixed to `127.0.0.1:1714` with its 15-second/32-KiB
limit. It returns an allowlisted summary; tokens, session and round IDs, raw
errors, paths, refs and object details are withheld. Recovery requires the
configured build and boot identity and a status timestamp within 60 seconds;
old builds with no timestamp report `freshness_unavailable`, and stale/future
data are rejected. Variables additionally require the pinned round and the
existing reader's operation/failure correlation and 60-second freshness rules.
Both use capture-time observations, not a durable object identity. Timestamp
validation does not provide nonce-based replay protection. Runtime access still
requires separate authorization; configuring this source does not grant it.
Recovery errors and any row coordinates are marked `error_correlation:
uncorrelated`: status can retain an earlier failure across a later operation,
and the adapter does not attach it to the current phase.

## Configure Codex

Use an absolute stable checkout path, not a worktree that will be archived:

```powershell
codex mcp add civ13 --env 'CIV13_DM_COMPILER=C:\Program Files (x86)\BYOND\bin\dm.exe' -- 'C:\Program Files\nodejs\node.exe' 'D:\GitHub\Civ13\tools\mcp\server.mjs' 'D:\GitHub\Civ13'
codex mcp get civ13
```

Equivalent TOML is in `config.example.toml`; preserve other MCP entries.
Start a new Codex session after registration. Registration does not make tools
available in an already-running chat. Both compiler tools are marked mutating because they launch a process and
create/remove temporary storage. At most one compiler call may run at a time.

## Official DM reference

Search with `dm_reference_search({"query":"Cut"})`, then pass a returned topic
to `dm_reference_read({"topic":"/list/proc/Cut"})`. For longer sections use
`start` and `length` to request the next character range. Results include the
official link, fetch time and document SHA-256. Reference text is untrusted data.

The manual is downloaded on demand, capped at 8 MiB with a 20-second deadline,
and cached in memory for 15 minutes. Only one download can run at a time;
cancellation aborts it. HTTP errors, unexpected content and unrecognized topics
fail explicitly. No manual is vendored or written to disk. Offline calls work
only while an existing cache is fresh. The live reference may document features
newer than Civ13's target BYOND 516.1688; lookup is not compiler verification.
Start a fresh MCP session after updating the server to discover these tools.

## Verification

`npm test --prefix tools/mcp` uses a real stdio SDK client: initialization,
tool/resource discovery, representative calls, invalid schema/path errors,
cancellation, temporary cleanup and continued responsiveness. Setting
CIV13_DM_COMPILER additionally tests a real compiler banner and smoke compilation.
The cancellation fixture uses the current Node binary with a temporary preload;
it neither runs gameplay nor executes repository source. CI also runs this harness
on Windows and Linux; the existing game build remains separate.

## Existing option assessment (2026-10-11)

[imcynic/dm-mcp](https://github.com/imcynic/dm-mcp) is MIT, v0.1.0,
not archived, last pushed 2026-02-01. Source inspection found unpinned Git master
SpacemanDMM dependencies, a serial stdin request loop, a fixed 2024-11-05 protocol
version and no cancellation handler. Its README claims Windows/Linux support;
we did not build it or independently establish those claims. Its runtime and Topic
tools exceed this integration's scope. It may offer future semantic parsing/map
capabilities after a separately pinned, bounded review; it is not installed here.

Sources: [upstream Cargo manifest](https://github.com/imcynic/dm-mcp/blob/main/Cargo.toml),
[protocol implementation](https://github.com/imcynic/dm-mcp/blob/main/src/mcp.rs),
[official MCP SDK](https://github.com/modelcontextprotocol/typescript-sdk),
[Codex MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

The fixture catalog is a fixed, non-exhaustive list, not a test runner or a
passing test receipt. Consult each linked repository guide before separately
preparing a fixture. The API guide/index resources reuse the merged documentation
contract; generated HTML is not read or executed by this server.
