# Starter jar reload

`test_resume.py` checks offline that a loaded fermentation starter jar restarts the loop its saved state needs and that each loop keeps a single runtime-only guard. The native probe loads flour, grain, yeast, legacy icon-only and empty jars:

```bash
python3 tests/ecology_spawning/run_linux.py . tests/starter_jar_load/probe.dm
```
