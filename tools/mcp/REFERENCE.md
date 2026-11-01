# Read-only public Atlas/docs MCP

`reference-server.mjs` is a reference-only stdio entry in the existing MCP
package. It exposes exactly `atlas_search`, `atlas_recipe`, `atlas_resource` and
`docs_search`, all read-only. It does not register or import the mixed server's
compiler, runtime, admin or source-file tools. Existing `server.mjs`, optional
runtime readers and their configuration are unchanged. No installed MCP client
configuration or deployed service is changed by adding these source files.

## Existing artifacts, not another index

The adapter consumes existing generated public artifacts. There is no crawler,
recipe extractor, new hosted endpoint, LLM, database or background poller.
`reference-sources.json` is only an immutable source/hash descriptor:

- https://civ13.github.io/Civ13/crafting/crafting-data.json
- https://civ13.github.io/Civ13/search-index.json
- https://civ13.github.io/Civ13/build.json

The current pin is `e1cd2ad03a559a1fb3beb678cb37836dd295bf7b`: 3,048 recipe
groups, 10,243 retained variants, 2,020 resources and 643 documentation labels.
The public Atlas is 10,718,092 bytes. The public search index is 68,916 bytes.
Existing api-pages owns generation/publication. Bulk files are ignored build
artifacts, not a second committed catalog. The read model creates only bounded
in-memory lookup views of those exact bytes at initialization.

Use the package's unchanged dependency lock (Node20+; CI currently uses Node24):

```sh
npm ci --prefix tools/mcp --ignore-scripts --no-fund
npm run reference:fetch --prefix tools/mcp
node tools/mcp/reference-server.mjs
```

The explicit fetch command permits only those three fixed URLs, JSON MIME and
valid UTF-8, at most16MiB/256KiB/8KiB respectively, with a ten-second deadline per
source and no redirects or retries. It checks exact byte counts, SHA256, both
source revisions and read-model schema before promoting a complete set. It never
overwrites an existing invalid set or silently follows a changed live site.
Artifacts are not executable and no bot/game bootstrap is loaded.

If the site advances, the pinned fetch may fail. Refreshing the descriptor is a
separate reviewed source change after verifying all three artifacts belong to
one publication. Archive an obsolete ignored artifact directory explicitly
before acquiring a replacement. No client/tool argument can select a source,
path, URL, revision or refresh. Runtime startup reads only the three fixed files
and rejects symlinked components, nonregular files, oversized/mutated bytes and
mismatched provenance. No runtime network fetch or fallback occurs.

Missing, mismatched or invalid artifacts leave initialization/discovery available,
but lookup returns `isError` with an explicit `artifact_*` code. A pinned older
revision remains historical reference data; it is not labelled current/live.
No timestamps are invented to make a missing/stale artifact appear fresh.

Use an absolute stable source path as illustrated in
`reference-config.example.toml` if separately choosing to register this entry.
No environment variables, token, game path or compiler are required. Privileged
environment variables from the mixed local MCP are ignored by this entry.

## Lookup semantics and bounds

| Tool | Inputs and result |
| --- | --- |
| `atlas_search` | Literal query0..120 characters, kind recipe/resource/both, paged names/IDs/conditions; blank browses recipes only |
| `atlas_recipe` | Exact recipe or retained variant ID, optional variant_id; complete quantities, material/research/era/processor gates and exact selected source |
| `atlas_resource` | Exact resource ID; paged reviewed acquisition and producer/consumer recipe relationships, no recursive expansion |
| `docs_search` | Existing documented labels and safe fixed-site links; not full-text source/wiki search or arbitrary HTML reads |

Queries normalize case, underscores and whitespace without guessed reagent aliases.
Search retains matching variant IDs; old variant IDs remain selectable. Grouping
is inherited from the Atlas and checked for equal semantics. A maximum era is
not relabelled as an unlock era. Quantities remain verbatim, including alternative
feedstocks, conditional yields and zero values. Tools/catalysts and map/research
conditions stay in the result. Large detail is an explicit error, never an
ingredient/output truncation (the current catalog has recipes with48 outputs).

Default10/max20 entries; offset0..10,000; IDs at most512 characters/2048 UTF-8
bytes; query at most480 UTF-8 bytes. Admission caps10,000 recipe groups/resources,
combined, with at most10,000 relationships/routes per resource so every next
cursor remains within the accepted offset range;
100,000 retained variants,128 variants/ingredients/outputs per record and5,000
documentation labels. Resource relationships are paged together with acquisition
routes and return `next_offset`/`truncated`. No regex or dependency-tree walk.

The official SDK validates JSON-RPC/MCP envelopes and strict tool schemas. The
stdio read buffer is capped at16KiB; oversized buffered input closes the session.
UTF-8 is strict. Malformed envelopes/JSON are rejected by the SDK without dispatch;
diagnostics are generic, never raw input or private paths. Valid unknown methods
get the SDK's method-not-found error. Notifications do not receive invented IDs.
Responses, including the envelope, are capped at24KiB UTF-8. An oversized SDK
response becomes a bounded error retaining its original valid request ID; use a
smaller page or follow the pinned source link. The session stays responsive.

Every successful result includes artifact hashes, source revision, safe links,
coverage limits and separate historical acquisition-audit provenance. Raw
`production_sites`, sprite/raw-source fields and unknown fields are not exposed as
player acquisition. All returned prose is untrusted data, never instructions.
Source reference does not prove live player unlocks, server state, current map
availability or complete acquisition coverage. Existing repository license and
source notices remain applicable; source/license links are included.

## Verification

`npm run test:reference --prefix tools/mcp` uses small synthetic fixtures and real
SDK stdio clients; it needs no network artifact download, compiler, game runtime,
private files, model service or credentials. It covers variant identity/source,
alternative quantities, material/research/unknown gates, resource normalization,
paging, provenance/hash/revision drift, missing files, links, malformed UTF-8/JSON,
input/output bounds, cancellation, fixed-origin fetch and atomic acquisition.
Cancellation checks reject already-aborted calls; these small synchronous lookups
may finish before an in-flight cancellation notification is delivered.
Protocol cases include extra path/URL arguments, privileged environment variables,
unknown methods/tools, invalid IDs/params, notifications and continued responsiveness.
`npm test --prefix tools/mcp` includes these alongside existing MCP regression tests.

This entry is not a remote HTTP deployment. A later public HTTP adapter would
need its own review and authorization and should reuse only this bounded read
model, not expose the mixed compiler/runtime server or fetch this corpus per call.
No Cloudflare CPU/startup/capacity claim follows from these local stdio tests.
