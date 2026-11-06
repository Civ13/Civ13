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
  "servers": ["gaia"],
  "forwarded_header": "CF-Connecting-IP"
}
```

- `client_id` is a separate Discord application from Civilizationbot's, with
  **Public Client** turned on, so the launcher's PKCE sign-in needs no client
  secret. The service uses the ID only to revoke tokens.
- `token_file` holds at least 32 random characters, the same file the world's
  `config/account_signin.json` names. Only `/redeem` needs it.
- `servers` lists the server names a ticket may be issued for.
- `forwarded_header` is the header the HTTPS front puts the player's address
  in. Leave it out when nothing fronts the service.

| Route | Caller | Body | Answer |
| --- | --- | --- | --- |
| `POST /signin` | Launcher, through the HTTPS front | `access_token`, `server` | `ticket`, `expires_in` (120) |
| `POST /redeem` | The world, with `X-Account-Token` | `ticket`, `server`, `address` | `discord_id` |

`/signin` calls Discord's `GET /users/@me`, revokes the token straight after,
and limits each address to 10 sign-ins a minute. A ticket is used up by its
first redeem, whatever the answer, and is refused for another server or
another address. The service binds 127.0.0.1 only and logs no requests.

It must sit behind HTTPS (a free Cloudflare Tunnel, or a TLS front the bot
host already has): the token is a Discord bearer token for seven days until
the service revokes it.

Tests: `python3 -I -B -m unittest discover -s tests/account_signin -p 'test_*.py'`.
