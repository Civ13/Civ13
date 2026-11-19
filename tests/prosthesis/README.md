# Prosthesis fitting

`test_attachment.py` projects the fitting branches and completion helper from
the DM source with fake waits, messages, organ objects, and engine effects. It
checks side selection, missing limbs, interruption, attachment effects and
medical experience. A negative control removes the null guard and confirms
that the missing-organ case reaches an invalid access.

Run with a verified Python 3 interpreter:

```
<verified-python> -m unittest discover -s tests/prosthesis -p 'test_*.py'
```

The adapter translates a limited subset of DM and treats message interpolation
as opaque text. This is offline control-flow evidence, not native BYOND,
in-game, or rendering verification.
