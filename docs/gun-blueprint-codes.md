# Gun blueprint design codes

`code/modules/1713/gunsmithing/gun_design_code.dm`, tests in
`tests/gun_blueprints/`.

```
C13GUN/1/<name>/<stock>/<receiver>/<feeding>/<barrel>/<caliber id>/<look or ->
```

Fields are the blueprint's own values, with spaces written `_` (design codes
drop spaces) and `/` written `-`. The caliber is the id the gun keeps
(`a792x57`, `12gauge`), so a code reads the same on maps whose bench names a
caliber differently. `custom_gun_caliber(name)` is the one table from a
bench caliber name to its id and casing.

Export: any gun blueprint used in hand shows its code in the shared design-code
pop-up (`design_code_show`).

Import: the bench panel's "Import a design code" (action `import_code`). The
bench needs the designer's skill (`can_design`, the same gate as
"Start New Gun"), no gun in progress, and then works the code through
`bench_action` one choice at a time, exactly as if the player had pressed each
button: stock, receiver, feeding system, barrel, caliber, then the look the
bench asks for and the name. Every step is checked by the bench itself against
`design_options()` for the gunsmith's research band and against the steel and
wood on the bench, so a code cannot add a part the gunsmith's people do not
know. A refused step cancels the gun and says which part. The name step makes
both the blueprint and the gun, using the same wood and steel as designing by
hand. It does not charge coins. `importing` keeps the panel from reopening between steps. Accepted imports
are logged for staff (`design_code_log`) and share the paste cooldown.

Codes only repeat choices the bench already allows, so imports are not gated
behind Discord verification.
