# Torch mounts

`probe.dm` puts unlit and lit torches and a lantern into a wall torch mount
through the item click path (`resolve_attackby`), lights a torch in place,
takes it out, and checks the mount's sprite and light each time. It then
replays a load (the saved holder replaces the constructor's, or the holder is
lost) and checks `after_load()` binds or rebuilds it. A katana stand covers the
other structures that own an internal storage.

Regression: `/obj/item/weapon/storage/internal/can_be_inserted()` called
`internal_storage_accepts()`, which was declared on `/obj/item` only, so every
structure-owned holder (torch mount, katana stand, shell rack, cargo hold,
shopping cart, dehydrator) threw a runtime and refused every item.

Native probe (after `bash scripts/cloud_byond_setup.sh` on Linux):

```bash
python3 tests/ecology_spawning/run_linux.py . tests/torch_mount/probe.dm 300
```

Not established: the click path in a real client, and a full save/load
roundtrip of a mount.
