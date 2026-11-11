# Dream lifecycle projection

Run from the repository root with a verified Python 3 executable:

```
python -B -m unittest discover -s tests/dream_lifecycle -p test_*.py -v
```

This test reads the production dream-loop statements and projects their order,
guards, lock assignments, and delay on a deterministic clock. It forces the
random admission roll to succeed, a three-message dream, and the minimum delay.
It checks concurrent admission, completion, waking, death, and disconnection.
The saved pre-fix loop is a negative control for both early unlock and messages
after interruption. Unsupported source shapes fail rather than silently pass;
update the projection if the DM implementation changes structurally.

The projection does not compile or execute DM, exercise BYOND scheduling,
client delivery, mob deletion, or run the game. It is not native or gameplay
evidence. The test uses no DreamDaemon, network access, or shared server state.
