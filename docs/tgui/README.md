# Civ13 tgui windows

How interface windows work today and how to add one. The frontend build,
browser contract and handshake are in [tgui/README.md](../../tgui/README.md).
Current previews of every window are in [screenshots](screenshots/README.md).
Older migration notes are in [history](history/README.md).

## How a window works

- A window is a `/datum/nanoui/tgui` (`code/modules/nano/tgui.dm`). An owner
  opens it from `ui_interact()` with `open_tgui()` or `open_panel()`.
- The server sends one data list per update. An update that would send the
  same data again is skipped unless the window is owed a reply to an action.
  The first data rides inside the page, so a window draws without waiting for
  a round trip.
- A button sends an action name and one value. The window accepts only the
  names the owner returns from `ui_actions(ui_key)`.
- The action goes to the owner's `ui_act(action, params, user, ui)` when it
  defines one, otherwise to its `Topic()` as `href_list[action] = "value"`.
  The owner must still check range, state and the value itself.
- `updateUsrDialog()`, `updateDialog()` and `GLOB.nanomanager.update_uis(src)`
  refresh open windows. `GLOB.nanomanager.close_user_uis(user, src, ui_key)`
  closes one.

## Adding a window

### First choice: the shared panel

Most object windows are a few status rows, a list and some buttons. Describe
them on the server with the helpers in `code/modules/nano/tgui_panel.dm`; no
frontend change or rebuild is needed.

```dm
/obj/structure/example/ui_actions(ui_key)
	return list("toggle", "take")

/obj/structure/example/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	var/list/items = list()
	for (var/i = 1 to contents.len)
		var/obj/item/I = contents[i]
		items += list(panel_item(I.name, null, list(panel_button("Take", "take", i))))
	var/list/sections = list(
		panel_section("Status", rows = list(panel_row("Door", open ? "Open" : "Closed", open ? "good" : "muted",
			list(panel_button(open ? "Close" : "Open", "toggle"))))),
		panel_section("Contents", items = items, empty = "It is empty."))
	open_panel(user, name, 420, 360, sections, ui = ui, force_open = force_open)
```

- `panel_button(label, action, value, disabled, selected)`: `value` arrives as
  the action's value. Send list positions or fixed ids, never object refs the
  server will not re-check.
- `panel_row(label, value, tone, buttons)`: tones are `good`, `warn`, `info`,
  `ready`, `progress` and `muted`.
- `panel_item(name, detail, buttons)` and
  `panel_section(title, notes, rows, items, buttons, empty)`.
- A section can also carry `table = panel_table(columns, rows)`, whose cells
  are text, numbers or `panel_cell(text, tone)`, and
  `chart = panel_chart(list(panel_series(label, tone, points)), slots, top, left, right)`
  for a line chart. The factory monitor and power meter use both.
- `forms = list(panel_form(label, action, value, fields, button))` adds a line of
  boxes with one button; `panel_field(name, label, value, kind, options)` is a
  number box, a text box or a choice of `panel_option(id, label)`. The owner
  names the fields in `ui_action_fields(ui_key, action)`.
- `panel_item(name, detail, buttons, image)` can show a picture already sent
  with `browse_rsc`; pass its bare `.png` file name.
- Text is shown as text. Do not send HTML.
- `tests/tgui/test_panel.py` fails when a button's action is missing from the
  same file's `ui_actions`.

Converting an old `show_browse` window is the same work: build the panel data
where the HTML was built, declare `ui_actions`, and keep the existing `Topic()`
checks.

### Second choice: a screen of its own

Use this only when the panel cannot express the window (a canvas, a tree, a
document editor).

1. Add the data type to `tgui/src/data.ts`.
2. Write the screen in `tgui/src/interfaces/` using the shared kit components
   and register its template name in `tgui/src/interfaces/index.tsx`.
3. Add a fictional fixture to `tgui/src/fixtures.mts`. The fixture is type
   checked, rendered by the tests and captured by the screenshot gallery.
4. Add the template name to the lists in `tests/tgui/test_backend_contract.py`
   and `tgui/src/interfaces/Parity.test.tsx`.
5. Open it with `open_tgui(user, ui_key, "name.tmpl", title, width, height, data, ui, force_open)`.
6. Rebuild and commit `UI/tgui/civ13-tgui.js` and `.css`.

## Checks

```sh
cd tgui && npm ci --ignore-scripts && npm run check && cd ..
node tests/tgui/bootstrap.test.cjs
python3 -B -m unittest discover -s tests/tgui -p 'test_*.py'
python3 tests/ecology_spawning/run_linux.py . tests/agent_control/screens_probe.dm
```

The last command opens windows on the real engine without a client; it needs
the pinned BYOND from `bash scripts/cloud_byond_setup.sh`. None of these is a
check in a player's game client.
