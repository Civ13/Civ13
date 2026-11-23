# Contraptions Planner

Hold a blank ship's draught and a pen or pencil, then choose **Draw a
contraption on the sheet**. Reopen a saved contraption with **Open Contraptions
Planner**. This is a drawing, not a circuit editor or an automation command.

- Pick a part and click a tile on the 12 by 12, single-level plan. Pick **Tie
  cord**, then a trigger and an actuator, to draw a link. Remove a cord in the
  list; erasing or replacing a part also removes its cords.
- Review the part counts, rope count and checks. Cords use the game's
  seven-tile square reach on the same level and four cords per trigger. A
  portcullis goes within two tiles of its winch: the cord ends at the winch,
  not directly at the gate.
- Use **Test pull or throw over** on a trigger to forecast its connected
  effects, or **Test throwing back** on a lever. Results are explanatory; they
  do not move, ring, unlock, power or spawn anything and do not spend
  materials. Actual cooldowns, locks, obstructions, pressure-plate ownership
  and winch/gate state still apply when built normally.
- **Save on this sheet** writes only the drawing. **Export last saved
  design** gives a shareable code; import from the planner or usual sheet menu.
  Blueprints do not contain world positions, object identifiers, owner
  permissions, or executable expressions.

## Examples

| Drawing | Existing mechanical route |
|---|---|
| Doorway bell | A pressure plate near the doorway pulls a cord and rings an ordinary bell. A completed door opening is **not** a native cord trigger. |
| Lever portcullis | Lever → cord → gate winch → nearby portcullis. |
| Lever sluice | Lever → cord → sluice gate. A sump pump's float is already internal to the pump, not an independently routable trigger. |

An in-world build still uses the normal construction and rope-tie interactions
documented in [Mechanisms](mechanisms.md). The planner does not peg out the
world, edit mechanisms, represent multi-level pulley routes, model full
multi-section gates, install electronics or send an integrated circuit signal.
[Mechanism ports](mechanisms.md#bridges-to-electricity-and-circuits) are a
possible later palette, not part of this draft.

## Design code and verification

`C13MECH/1/name/x,y,key;.../sx,sy,tx,ty;...` has at most 1,024 characters,
24 parts and 32 cords. Coordinates are decimal tile positions on the paper;
names use at most 32 ASCII letters, digits and underscores for spaces. Parts
and edges use only the palette and valid endpoint types. A readable design can
have layout findings: saving a drawing with too-long cords is allowed, but
preview marks it as not buildable. It does not read or write a world binding.

`python3 tests/contraption_plans/test_sources.py` checks producer wiring, palette
help and bounds against the corresponding physical mechanics. The
[mechanisms probe](../tests/mechanisms/README.md) also exercises plan edits,
forecast and code round trips when run under the authorized isolated native
procedure. Compilation alone does not establish those runtime results or real
BYOND browser behavior.
