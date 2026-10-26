# BYOND hub community links

The shared /world/proc/update_status() in code/world.dm generates the hub
listing for all maps and server configurations, including Nomads, Persistence,
RP, TDM and ALL. There is no separate Nomads or TDM status renderer.

The server title retains its Discord destination, followed by a short row:

    Discord | Website

The row uses the existing DISCORDURL and WEBSITEURL configuration fields.
Defaults in config/config.txt are:

    DISCORDURL https://discord.gg/hBEtg4x
    WEBSITEURL https://civ13.com/

Both are public Civ13 community links. On 2026-10-25, the official
https://civ13.com/ site redirected to https://civ13.github.io/ and linked this
Discord invite in its community and event sections. The Discord landing page
identified the community as Civ 13/14. The same invite appears in the
repository's commented ban-appeals example; README and MOTD previously used
the older https://civ13.com/discord route. The website URL retains the official
domain rather than coupling the listing to its current hosting redirect.

The renderer emits simple anchor and line-break markup, as already used by
Civ13's hub listing. It retains the server name, map, round duration, gamemode,
banner and custom HUB_BODY content. Player counts, status Topic data,
visibility rules, testing ports, hub credentials and join behavior are
unchanged. Player counts are not part of this custom status string.

Literal server/map/mode/time text and link labels/attributes are escaped.
Configured links must be absolute lowercase http:// or https:// URLs using
a conservative ASCII alphabet; empty values, whitespace, markup, credentials
in the authority and executable URL schemes are omitted. This is a
presentation boundary, not a general URL parser or a server fetch facility.
OPEN_HUB_DISCORD_IN_NEW_WINDOW continues to govern the title and Discord
links. Website uses an ordinary anchor. Existing administrator-authored
HUB_BODY HTML and its ROUNDTIME substitution are retained.

## Offline verification

Run with an installed Python interpreter (use its full path on Windows):

    <python-executable> tests/test_hub_status.py

The tests derive encoder operations, URL alphabets and HTML fragments from
the production DM source, and check the renderer's call/guard contracts.
They cover Nomads/TDM and the other configuration modes, custom host text,
no map, missing/invalid links, dynamic HTML injection, query ampersands and
the existing Discord new-window option. They use Python string operations;
they do not execute DM or prove native runtime behavior.

The ordinary CI baseline registers this exact test file as the hub_status suite,
selected for changes to code/world.dm, config/config.txt or the test itself.
No native runner or additional diagnostic workflow is added.

A tiny compile-only fixture can extract the three changed production
procedures with inert configuration/map/name/time stubs. A successful
compilation checks DM syntax and symbol resolution only. Never start that
fixture as part of this source task.

## Activation and remaining acceptance

This source change requires a rebuilt world binary and a separately authorized
restart to install its new procedures. Existing calls to update_status() at
startup, player Login and the existing admin toggles then refresh its status.
Those calls do not hot-load newly compiled procedures into an old running
world. Do not toggle entering/respawn just to refresh a listing.

Each separately maintained server config must retain or deliberately update
its DISCORDURL and WEBSITEURL at the later authorized rollout. Source defaults
do not overwrite a host's private config. No live config changes are included.

After authorized rollout, inspect the actual hub listing for each advertised
server, confirm the existing server/map/mode/count information remains visible,
and click both community links. Hub sanitization, layout, truncation, update
timing, native URL semantics and browser launch behavior require that acceptance.
The reference screenshot could not be materialized on this executor, so no
pixel inspection or Goonstation visual-match claim accompanies this proposal.

This source task never starts a world, changes the live listing, or restarts
Gaia. Gaia remains intentionally offline.
