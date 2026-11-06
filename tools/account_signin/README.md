# Account sign-in service

`signin.py` trades a player's Discord access token for a single-use join
ticket, and lets a world redeem that ticket for the player's Discord ID. See
[docs/accounts/discord-accounts.md](../../docs/accounts/discord-accounts.md)
for how accounts use it. Standard library only; nothing is written to disk.

```
py -3 tools/account_signin/signin.py --config D:/private/account-signin.json
```

```json
{
  "port": 47301,
  "token_file": "D:/private/account-signin-token.txt",
  "client_id": "<login Discord application ID>",
  "servers": {"gaia": 1714, "railyard": 1716},
  "forwarded_header": "CF-Connecting-IP"
}
```

- `client_id` is the Discord application the launcher signs in with. It can be
  Civilizationbot's own application with **Public Client** turned on and the
  redirect `http://127.0.0.1:53134/discord` added, so the launcher's PKCE
  sign-in needs no client secret.
- `token_file` holds at least 32 random characters, the same file the world's
  `config/account_signin.json` names. Only `/redeem` needs it.
- `servers` maps each world's name (its `config/account_signin.json` `server`)
  to its game port. The launcher names a world by the port in its join link.
  A plain list of names also works, but then only callers that send `server`
  can sign in.
- `revoke` (default off) revokes each access token after the check. Leave it
  off for the launcher: a revoke ends the whole authorization, so the stored
  refresh token would stop working and every join would ask for consent.
- `forwarded_header` is the header the HTTPS front puts the player's address
  in. Leave it out when nothing fronts the service.

| Route | Caller | Body | Answer |
| --- | --- | --- | --- |
| `POST /signin` | Launcher, through the HTTPS front | `access_token`, `port` (or `server`) | `ticket`, `expires_in` (120) |
| `POST /redeem` | The world, with `X-Account-Token` | `ticket`, `server`, `address` | `discord_id` |

`/signin` calls Discord's `GET /users/@me` and limits each address to 10 sign-ins a minute. A ticket is used up by its
first redeem, whatever the answer, and is refused for another server or
another address. The service binds 127.0.0.1 only and logs no requests.

It must sit behind HTTPS (a free Cloudflare Tunnel, or a TLS front the bot
host already has): the token is a Discord bearer token that lasts seven days.

Tests: `python3 -I -B -m unittest discover -s tests/account_signin -p 'test_*.py'`.
