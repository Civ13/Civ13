# Paper bin appearance regression

Run from the repository root with a working Python 3 interpreter:

```text
py -3 -B tests/paper_bin_appearance/test_appearance.py
```

The test projects the complete `add`, `attackby`, and `update_icon` DM proc
bodies through the shared offline adapter. It checks the item, count, and icon
after inserting into empty and occupied bins through each insertion path.
Inventory, messages, and engine objects are fakes; this does not execute BYOND
or verify an in-game rendering.
