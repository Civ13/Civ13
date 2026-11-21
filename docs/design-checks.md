# Design checks

Every vehicle editor judges a design the same way before anything is built:
what stops it being built, and what will not work well once it is. The code
is `code/modules/craft/design_checks.dm`; the levels are in
`code/__defines/design_checks.dm`.

## Findings and reports

`design_report(kind, design)` runs every check of that kind over a design and
returns a `/datum/design_report` (the caller deletes it). Each
`/datum/design_finding` has:

- `level`: `DESIGN_ERROR` (cannot be built or assembled as it is),
  `DESIGN_WARNING` (can be built, something will not work well) or
  `DESIGN_NOTE` (advice);
- `text`: one or two plain sentences that say what to do about it;
- `cells`: the grid keys it is about (`"x,y"` on a ship's draught, `"col,row"`
  on a submarine sheet, frame offsets in a frame survey), for a window to
  light up;
- `deck`: the deck those cells are on (0 for the main deck; a multi-deck
  design numbers its own);
- `part`: the part key it concerns, so a window can show that part's
  description.

`data()` gives the findings worst first for a window's JSON, `chat_lines()`
for chat, `texts(level)` the words alone. `design_errors(kind, design)` is the
errors as text: a design's `problems()` returns exactly that, so callers that
refuse a design (the slipway, the submarine controls) are unchanged.

## Writing a check

A check is a subtype of its kind's parent with an `order` (lower runs first)
and a `ship_check()`, `sub_check()` or `vehicle_check()`:

```dm
/datum/design_check/ship/figurehead
	order = 120

/datum/design_check/ship/figurehead/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (!D.piece_count("F"))
		R.note("She has no figurehead.", null, "F")
```

Nothing lists the checks: `design_checks_for(kind)` gathers every subtype
whose `kind` is set and whose type is not its `abstract_type`, sorted by
`order`. A new kind of design (a spaceship, a rocket, a station) is a new
parent with its own `kind` and `abstract_type`, its checks, and a
`check_design()` on its datum that calls `design_report()`.

| Kind | Design | Checks |
| --- | --- | --- |
| `ship` | `/datum/ship_draught` | `naval/draught_checks.dm` |
| `sub` | `/datum/sub_draught` | `naval/draught_checks.dm` |
| `vehicle` | `/datum/vehicle_survey` (frames before hand assembly) | `craft/vehicle_checks.dm` |
| `vehicle_sheet` | `/datum/vehicle_draught` (a vehicle sheet, [vehicle-sheets.md](vehicle-sheets.md)) | `craft/vehicle_draught_checks.dm` |

## Describing parts

Selecting any part in an editor shows what it is, what it is for and how to
use it. A `/datum/design_part_book` subtype gives `entries()` for its kind:
`key = list("what" = ..., "use" = ..., "how" = ...)`;
`design_part_help_for(kind)` merges every book of that kind and the windows
receive it as `HELP`. `naval/draught_part_help.dm` describes every floor,
piece and tool of the ship's draught and every section, wall and fitting of
the submarine sheet; `tests/ship_draught/test_design_checks.py` fails when a
new part has no entry.

## Tests

- `tests/ship_draught/test_design_checks.py` (offline): every part described,
  check parents carry a kind, the files are built.
- `tests/naval_carrier/draught_probe.dm`: checks gathered by kind and in
  order, the example ships free of warnings, each ship and submarine warning
  and the cells it lights, the window carrying the descriptions.
- `tests/vehicle_papers/assembly_probe.dm`: an empty tank, the wrong fuel and
  an engine too weak for the weight are warned of before assembly.
