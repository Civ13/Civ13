# Delayed lava animal remains

Run `python test_callback.py -v` with the repository's verified Python interpreter.
The tests project a deliberately small subset of the actual DM callback and fail
on unrecognized callback syntax. They cover an animal escaping to land, remaining
on the original lava, moving to another lava tile, and being deleted before the
callback. This does not compile DM or establish native gameplay timing.
