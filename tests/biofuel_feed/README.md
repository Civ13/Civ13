# Biofuel refinery manual feed

`test_feed.py` models one manual pour against the refinery's shared 300-unit feed store. The native probe pours olive oil, fat oil and ethanol into nearly full, empty and full refineries:

```bash
python3 tests/ecology_spawning/run_linux.py . tests/biofuel_feed/probe.dm
```
