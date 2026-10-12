# Save latency regression

`run.py --byond-bin <516.1681-bin>` compiles the production serializer and loader with offline world-save adapters, temporary storage and disabled network ports. It measures an independent one-tick heartbeat during first save and whole-generation backup, then verifies dense contents and list values through a native load.

`--large` uses 500x500x2 turfs and 10,000 contained objects. `--baseline <immutable-commit>` selects the baseline serializer and bookkeeping while keeping the same probe. Run comparisons sequentially in a quiet CPU window. Retained evidence includes source hashes, checkout patch, compiler/runtime logs and native saves. These are synthetic latency observations, not production latency or graphical acceptance.

BYOND `world.timeofday` provides decisecond wall-clock samples (with midnight wrapping); avoid `world.realtime`, whose float precision loses sub-minute differences at current epoch values.
