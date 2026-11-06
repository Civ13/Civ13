# Discord accounts

Civ13 accounts are keyed on Discord user IDs, so a player keeps one identity
whether they connect with a BYOND key or a guest key. BYOND still carries the
connection; Discord proves who the player is. No passwords or player
credentials are stored by the server. The full design, with phases and the
review that shaped it, is in the project's design doc ("Civ13 accounts:
Discord login design").

## Account keys

An account key is `d:` followed by the Discord user ID, for example
`d:123456789012345678`. A BYOND ckey holds only `a-z` and `0-9`, so an account
key can never equal a ckey and old ckey-keyed rows never collide with new ones.

`code/modules/persistence/player_reclaim.dm` (which save fixtures build on
their own) and `code/modules/accounts/discord_accounts.dm` provide:

| Proc | Returns |
| --- | --- |
| `is_account_key(account)` | Whether `account` is a well-formed `d:<id>` key |
| `persistence_owner_valid(account)` | Whether `account` may own a saved character: a non-guest ckey or an account key. Every save-owner check uses it |
| `account_discord_id(client)` | The client's Discord ID: from its redeemed join ticket, else from the verified list for a real BYOND key, else null |
| `account_key(client)` | `d:<id>` when a Discord ID is known, the ckey for an unlinked BYOND key, null for a guest who has not signed in |

Durable stores (home ledger, save owner, preferences, reputation) still use
ckeys. Moving them to `account_key()` is the next phase.

## Where a Discord ID comes from

1. **The verified list.** Civilizationbot's `/approveme` links a BYOND key to a
   Discord account (the player puts a token in their BYOND profile). The game
   reads that list from `SQL/approved.txt` (`ckey=DiscordID` rows) and now
   keeps the IDs: `verified_discord_id(ckey)` in `code/_helpers/access_lists.dm`.
2. **A launcher join ticket.** The launcher signs the player in with Discord and
   trades the token at the sign-in service for a single-use ticket that lasts
   two minutes. The join link carries only that ticket:
   `byond://<host>:<game port>?civ13_ticket=<ticket>`. `client/New` reads it
   before dropping the topic, and the world redeems it once with the service.
   The Discord ID then belongs to that connection only.

The raw Discord token never goes into a `byond://` link: BYOND traffic is not
encrypted and the link sits on the DreamSeeker command line.

## Turning on ticket sign-in

It is off unless `config/account_signin.json` exists:

```json
{"port": 47301, "token_file": "config/account-signin-token.txt", "server": "gaia"}
```

`server` must match one of the service's `servers`, which maps each world's
name to its game port. Run the service as described in
[tools/account_signin/README.md](../../tools/account_signin/README.md).

## Launcher sign-in

The launcher shows "Sign in with Discord" in its footer. It uses the Civ13
sign-in service at `https://signin.valzargaming.com/signin` (a Cloudflare
Tunnel that exposes only `/signin`). A player's `discord.json` in the launcher
data folder can point elsewhere or turn the link off:

```json
{"signin_url": ""}
```

It signs in as a Discord public client with PKCE, using the presence
application's ID unless `signin_client_id` names another. That application
needs **Public Client** turned on and the redirect
`http://127.0.0.1:53134/discord`. The refresh token is kept in
`discord-signin.json` in the launcher data folder. Before each join the
launcher refreshes it and asks the service for a ticket for that world's game
port. If anything fails, the launcher joins with the BYOND key alone.

The panic bunker still bans every guest key while it is on, signed in or not.
