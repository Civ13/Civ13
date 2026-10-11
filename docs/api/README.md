# Generating the source API reference

Civ13 uses [SpacemanDMM dmdoc suite-1.10](https://github.com/SpaceManiac/SpacemanDMM/releases/tag/suite-1.10),
GPL-3.0, rather than PHPDocumentor (PHP) or Doxygen (no native DM parser).
The upstream DM preprocessor/parser reads the real `civ13.dme`, including macros,
conditional compilation and inheritance. No alternate DME or regex parser is maintained.
The tool renders annotated files, macros, types, vars, global/member procs, inheritance,
module/type navigation and browser-side navigation filtering. It does not infer descriptions
for every declaration, document inactive branches, or replace DreamMaker compilation.

## Local generation

Install Python 3.12 or newer. In the repository root on Windows, use a verified interpreter:

```powershell
& 'C:\Path\To\Python\python.exe' scripts/build-api-docs.py
```

On Linux x64:

```sh
python3 scripts/build-api-docs.py
```

The script downloads the Windows/Linux x64 release executable over HTTPS and verifies
its SHA-256 against the upstream `suite-1.10.sha256` manifest values committed in the script.
This pins release bytes; it is not independent signature verification. Upstream also publishes
an armored signed manifest. No executable is committed. To upgrade, review the release,
manifest and compatibility, update both hashes and tag, then run both CI and local generation.

Output is ignored `dmdoc/`; open `dmdoc/index.html` in a browser or serve that directory
with `python3 -m http.server --directory dmdoc`. Logs are in `.cache/api-docs/generation.log`.
Generation replaces only the fixed repository-root `dmdoc/` directory. Do not store edits there.
For clickable source links run from a pushed branch with its upstream configured.
Links target the recorded commit; CI builds the PR head, not a merge preview.

## Contributor comments

Use Markdown with `///` or `/** ... */` immediately before the declaration:

```dm
/** Stores a target and reusable arguments.
 * See [/datum/callback/dynamic] for invocation-time targets.
 */
/datum/callback

/// Calls the target and returns its result.
/datum/callback/proc/Invoke(...)
```

Use `//!` or `/*! ... */` inside an item for that enclosing item; at file scope these
annotate the module. Document arguments, return values, side effects and sleep behavior
in prose. Crosslinks use `[/type/proc/name]`, `[/type/var/name]`, `[MACRO]` or
`[label][/type]`; the destination must be documented. Escape literal bracket expressions
or format them as code. A one-line type note without documented members may not get a page.
See the [upstream conventions](https://github.com/SpaceManiac/SpacemanDMM/blob/suite-1.10/crates/dmdoc/README.md).

## Validation and publication

The read-only-permissions PR/default-branch workflow builds and uploads an HTML artifact
and diagnostic log. It never deploys PR content and requires no secrets. Bulk HTML stays
out of history. `build.json` records head SHA, generator hash and page count.
The script checks local links, fragments, assets, and representative callback proc pages.
Nine pre-existing crosslink diagnostics are listed exactly in `baseline-diagnostics.txt`;
any diagnostic change fails and requires review. Do not refresh that file blindly.
dmdoc prints parser errors but may return success, so unexpected stderr also fails validation.
Coverage is deliberately informational, not a universal annotation requirement.

The hosted reference is [civ13.github.io/Civ13](https://civ13.github.io/Civ13/).
The master-only Pages workflow regenerates, validates and publishes the same output,
with write permissions restricted to the deployment job. PRs only build artifacts.
The root showcase and player wiki are separate sites.

Search on every page links to the index, where case-insensitive words match documented
page paths and proc, var and macro anchors. Leading type slashes and actual .dm filenames are supported. Press Enter to focus the first result,
then Enter to follow it. Results are capped at 100; refine the query for more precise
matches. JavaScript is required for search, while the generated reference remains
browsable without it. This searches emitted documentation, not every source declaration.
The footer and build.json identify the exact source commit.
