#!/usr/bin/env python3
"""Draw the vessel openings art: gun ports in a ship's side, the cargo hatch
and the boat davits.

It writes one sheet:

  icons/obj/vessel_openings.dmi (32x32)
      gunport_wood_gate, gunport_wood_gate_open    4 dirs: a full-height
          planked side under the deck clamp, with a square port. Shut, the lid
          hangs flush from two hinge straps; open, it is swung up and out over
          a dark port
      gunport_steel_gate, gunport_steel_gate_open  4 dirs: the same in riveted
          grey plate under a steel rail
      cargo_hatch, cargo_hatch_open                top-down: a raised coaming
          with battened hatch boards; open, the boards are stacked along one
          side over a dark hold with a ladder and a glimpse of the hold floor
      davit, davit_boat                            4 dirs: a pair of curved
          iron davit arms with their falls; with a small rowing boat slung
          from them, over the side

The gun ports follow icons/obj/railings_built.dmi and icons/obj/ship_edges.dmi
(see create_built_railings.py and create_ship_edges.py): the dir is the tile
edge the piece runs along, SOUTH and NORTH are elevations, EAST and WEST are
strips seen from above with their south end drawn at full height. A davit's
dir is the ship's side it hangs over. Everything is lit from the top left.
The drawing is plain pixel work with Pillow from fixed palettes; nothing is
random, so a rerun writes the same bytes. The shut and open states share every
pixel but the lid or the boards.

  python3 tests/sprites/create_vessel_openings.py                  write the sheet
  python3 tests/sprites/create_vessel_openings.py --check          verify the committed sheet
  python3 tests/sprites/create_vessel_openings.py --preview <png>  also write a review sheet
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_bollards import noise, option  # noqa: E402
from create_built_railings import Cv, shadow, WOOD, STEEL, IRON, BRASS  # noqa: E402
from create_ship_edges import (write_dmi, check_sheets, backdrop, four,  # noqa: E402
                               HULL, PLATE, RUST, DARK)

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/vessel_openings.dmi'

SIZE = 32
EDGE = SIZE - 1
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')  # DMI order for dirs = 4
WALL = 18              # rows of a side wall in elevation (a gunwale is 9, a bulwark 11)
PORT = (11, 20, 5, 14)  # the port in the elevation: x0, x1, y0, y1, inclusive
STRIP_PORT = (3, 12)   # rows of the port along an EAST / WEST strip

ROPE = [(132, 108, 70), (176, 152, 104), (214, 196, 150)]
HOLD = [(12, 10, 9), (24, 18, 14), (38, 28, 20), (54, 40, 28)]
SOOT = (8, 7, 7)


def mix(a, b, k):
    return tuple(int(round(p + (q - p) * k)) for p, q in zip(a, b))


# --- gun ports ------------------------------------------------------------------

class WoodSide:
    """A planked ship's side: four strakes under the deck clamp."""
    name, strip_w = 'gunport_wood_gate', 6
    top = (0, 5, 4, 4, 3, 0)   # the wall from above, west to east
    body = (0, 4, 3, 3, 2, 0)  # its south end

    def front(self, inner):
        c = Cv(SIZE, WALL)
        for x in range(SIZE):
            c.put(x, 0, WOOD[5])
            c.put(x, 1, WOOD[3] if noise(x // 3, 1, 7) < 0.3 else WOOD[4])
            c.put(x, 2, WOOD[0])
            for y in range(3, WALL - 1):
                r = (y - 3) % 4
                if r == 3:
                    t = 1  # the seam between two strakes
                elif r == 0:
                    t = 3 if noise(x // 4, y, 5) < 0.25 else 4
                else:
                    t = 2 if noise(x // 5, y, 5) < 0.2 else 3
                if y >= 15:
                    t = max(t - 1, 1)
                c.put(x, y, HULL[t])
            c.put(x, WALL - 1, HULL[0])
        for x, y in ((6, 3), (26, 7), (5, 11), (27, 15), (24, 3)):  # butt joints
            c.col(x, y, y + 2 if y < 15 else y + 1, HULL[1])
        for x, y in ((4, 4), (8, 4), (24, 8), (28, 8), (3, 12), (7, 12), (25, 15), (29, 12)):  # treenails
            c.put(x, y, HULL[5])
        if inner:  # the frames stand inboard, either side of the port
            for x in (7, 23):
                c.col(x, 3, WALL - 2, WOOD[4])
                c.col(x + 1, 3, WALL - 2, WOOD[2])
                c.col(x + 2, 3, WALL - 2, HULL[0])
        return c

    def lid(self, c, inner):
        x0, x1, y0, y1 = PORT
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                r = (y - y0) % 5
                c.put(x, y, WOOD[5] if r == 0 else WOOD[2] if r == 4 else WOOD[4] if noise(x // 3, y, 11) > 0.2 else WOOD[3])
        c.row(x0, x1, y1, WOOD[2])
        if inner:  # a port bar across the lid, and its ring
            c.row(x0, x1, y0 + 4, WOOD[5])
            c.row(x0, x1, y0 + 5, WOOD[1])
        else:      # two hinge straps hanging from the wall above
            for x in (x0 + 2, x1 - 2):
                c.col(x, y0 - 2, y0 + 5, IRON[2])
                c.put(x, y0 - 2, IRON[4])
                c.put(x, y0 + 5, IRON[4])
        c.put(x0 + 4, y1 - 2, IRON[4])  # the ring bolt
        c.put(x0 + 5, y1 - 2, IRON[1])

    def raised(self, c):
        """The lid swung up and out, seen from outboard on its edge."""
        x0, x1, y0, _ = PORT
        c.row(x0 - 1, x1 + 1, y0 - 5, HULL[0])
        c.row(x0, x1, y0 - 4, WOOD[5])
        c.row(x0, x1, y0 - 3, WOOD[4])
        c.row(x0, x1, y0 - 2, WOOD[2])
        for x in (x0 + 2, x1 - 2):
            c.col(x, y0 - 4, y0 - 2, IRON[2])
            c.put(x, y0 - 4, IRON[4])
        for x in (x0 - 1, x1 + 1):
            c.col(x, y0 - 4, y0 - 2, HULL[0])

    def reveal(self):
        return HULL[1], HULL[2]

    def under(self):
        return WOOD[1]

    def run_row(self, c, n, y):
        joint = y % 16 == 15
        for x, t in enumerate(self.top):
            c.put(x, n, WOOD[2] if joint and t else WOOD[t])
        if y % 8 == 5:
            c.put(3, n, WOOD[2])  # treenail

    def lid_row(self, c, n, k, last, outer):
        """One row of the shut lid's top edge, in the outer half of the wall."""
        inner = self.strip_w - 1 - outer
        step = 1 if outer > inner else -1
        if k in (0, last):
            for x in range(1, self.strip_w - 1):
                c.put(x, n, HULL[1])
            return
        c.put(outer - step, n, IRON[3] if k in (2, last - 2) else WOOD[5])
        c.put(outer - 2 * step, n, IRON[1] if k in (2, last - 2) else HULL[1])

    def open_lid(self):
        return WOOD[5], WOOD[3], HULL[0]

    def end(self):
        c = Cv(self.strip_w, WALL - 2)
        h = c.h
        for x, t in enumerate(self.top):
            c.put(x, 0, WOOD[t])
            c.put(x, 1, WOOD[max(t - 1, 0)])
        c.row(0, self.strip_w - 1, 2, WOOD[0])
        for y in range(3, h - 1):
            for x, t in enumerate(self.body):
                c.put(x, y, HULL[t])
            if (y - 3) % 4 == 3:
                c.row(1, self.strip_w - 2, y, HULL[1])
        c.row(0, self.strip_w - 1, h - 1, HULL[0])
        return c


class SteelSide(WoodSide):
    """A plated ship's side: riveted grey plate under a rail."""
    name, strip_w = 'gunport_steel_gate', 5

    def rivet(self, c, x, y):
        c.put(x, y, PLATE[5])
        c.put(x + 1, y, PLATE[1])

    def front(self, inner):
        c = Cv(SIZE, WALL)
        x0, x1, y0, y1 = PORT
        for x in range(SIZE):
            c.put(x, 0, STEEL[5])
            c.put(x, 1, STEEL[3])
            c.put(x, 2, PLATE[0])
            c.put(x, 3, PLATE[4])
            for y in range(4, WALL - 2):
                c.put(x, y, PLATE[3] if noise(x // 3, y, 9) > 0.06 else PLATE[2])
            c.put(x, WALL - 2, PLATE[2])
            c.put(x, WALL - 1, PLATE[0])
        for x in (5, 26):  # the laps between the plates
            c.col(x, 3, WALL - 2, PLATE[1])
            c.col(x + 1, 3, WALL - 2, PLATE[4])
        for x in range(1, 30, 4):
            if not x0 - 4 <= x <= x1 + 2:
                self.rivet(c, x, 5)
                self.rivet(c, x, WALL - 4)
        c.col(0, 3, WALL - 2, PLATE[4])
        c.col(31, 3, WALL - 2, PLATE[1])
        # the port's doubling frame
        for x in range(x0 - 2, x1 + 3):
            for y in range(y0 - 2, y1 + 3):
                edge = x in (x0 - 2, x1 + 2) or y in (y0 - 2, y1 + 2)
                c.put(x, y, PLATE[1] if edge and (x == x1 + 2 or y == y1 + 2) else PLATE[5] if edge else PLATE[4])
        for x in (x0 - 2, x0 + 3, x1 - 3, x1 + 1):
            self.rivet(c, x, y0 - 2 if not inner else y0 - 1)
        for x, y in ((3, WALL - 2), (3, WALL - 3), (22, WALL - 2), (28, WALL - 2), (28, WALL - 3)):  # rust weeping
            c.put(x, y, RUST if y == WALL - 2 else mix(RUST, PLATE[3], 0.5))
        if inner:  # the frames stand inboard, either side of the port
            for x in (6, 24):
                c.col(x, 3, WALL - 2, PLATE[5])
                c.col(x + 1, 3, WALL - 2, PLATE[1])
        return c

    def lid(self, c, inner):
        x0, x1, y0, y1 = PORT
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c.put(x, y, PLATE[3] if noise(x // 3, y, 13) > 0.08 else PLATE[2])
        c.row(x0, x1, y0, STEEL[5])
        c.col(x0, y0, y1, STEEL[4])
        c.row(x0, x1, y1, PLATE[1])
        c.col(x1, y0 + 1, y1, PLATE[1])
        c.row(x0 + 1, x1 - 1, y0 + 4, PLATE[5])  # stiffener
        c.row(x0 + 1, x1 - 1, y0 + 5, PLATE[1])
        for x, y in ((x0 + 1, y0 + 2), (x1 - 2, y0 + 2), (x0 + 1, y1 - 1), (x1 - 2, y1 - 1)):
            self.rivet(c, x, y)
        if not inner:  # hinge lugs on the frame above
            for x in (x0 + 2, x1 - 2):
                c.col(x, y0 - 2, y0 + 1, IRON[2])
                c.put(x, y0 - 2, IRON[5])
        c.put(x0 + 4, y1 - 2, IRON[1])  # the dog that holds her shut
        c.put(x0 + 5, y1 - 2, IRON[4])

    def raised(self, c):
        x0, x1, y0, _ = PORT
        c.row(x0 - 1, x1 + 1, y0 - 5, PLATE[0])
        c.row(x0, x1, y0 - 4, STEEL[5])
        c.row(x0, x1, y0 - 3, PLATE[4])
        c.row(x0, x1, y0 - 2, PLATE[2])
        for x in (x0 + 2, x1 - 2):
            c.col(x, y0 - 4, y0 - 2, IRON[2])
            c.put(x, y0 - 4, IRON[5])
        self.rivet(c, x0 + 4, y0 - 3)
        for x in (x0 - 1, x1 + 1):
            c.col(x, y0 - 4, y0 - 2, PLATE[0])

    def reveal(self):
        return PLATE[1], PLATE[2]

    def under(self):
        return PLATE[1]

    def run_row(self, c, n, y):
        joint = y % 16 == 15
        c.put(0, n, PLATE[0])
        c.put(1, n, PLATE[2] if joint else STEEL[5])
        c.put(2, n, PLATE[2] if joint else PLATE[5] if y % 4 == 1 else STEEL[4])
        c.put(3, n, PLATE[2] if joint else STEEL[3])
        c.put(4, n, PLATE[0])

    def lid_row(self, c, n, k, last, outer):
        inner = self.strip_w - 1 - outer
        step = 1 if outer > inner else -1
        if k in (0, last):
            for x in range(1, self.strip_w - 1):
                c.put(x, n, PLATE[1])
            return
        c.put(outer - step, n, IRON[2] if k in (2, last - 2) else PLATE[5])
        c.put(outer - 2 * step, n, PLATE[1])

    def open_lid(self):
        return STEEL[5], PLATE[4], PLATE[0]

    def end(self):
        c = Cv(self.strip_w, WALL - 2)
        h = c.h
        for x, t in enumerate((0, 5, 4, 3, 0)):
            c.put(x, 0, STEEL[t] if t else PLATE[0])
            c.put(x, 1, STEEL[t - 1] if t else PLATE[0])
        c.row(0, 4, 2, PLATE[0])
        for y in range(3, h - 1):
            for x, t in enumerate((0, 4, 3, 2, 0)):
                c.put(x, y, PLATE[t])
        for y in (4, 8, h - 3):
            c.put(1, y, PLATE[5])
        c.row(0, 4, h - 1, PLATE[0])
        return c


def port_front(style, opened, inner):
    """The elevation: from outboard for a SOUTH piece, from inboard for a NORTH one."""
    c = style.front(inner)
    x0, x1, y0, y1 = PORT
    for x in range(x0 - 1, x1 + 2):  # the rebate round the port
        for y in range(y0 - 1, y1 + 2):
            if x in (x0 - 1, x1 + 1) or y in (y0 - 1, y1 + 1):
                c.put(x, y, HULL[0] if isinstance(style, WoodSide) and not isinstance(style, SteelSide) else PLATE[0])
    if not opened:
        style.lid(c, inner)
        return c
    side, sill = style.reveal()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c.put(x, y, SOOT if y < y0 + 2 else DARK)
    c.col(x1 if not inner else x0, y0, y1, side)  # the thickness of the side, lit through the port
    c.row(x0, x1, y1, sill)
    c.put(x0, y1, side)
    if inner:  # the raised lid shows through the top of the port
        c.row(x0 + 1, x1, y0, style.under())
        c.put(x0 + 3, y0 + 1, ROPE[1])  # and its lanyard runs out to it
        c.put(x0 + 3, y0 - 2, ROPE[2])
        c.put(x0 + 3, y0 - 3, ROPE[1])
    else:
        style.raised(c)
    return c


def port_strip(style, opened, east):
    """One EAST / WEST strip, a whole tile tall, seen from above."""
    w = style.strip_w
    c = Cv(w, SIZE)
    end = style.end()
    length = SIZE - end.h
    outer = w - 1 if east else 0
    p0, p1 = STRIP_PORT
    for n in range(length):
        style.run_row(c, n, n)
        if p0 <= n <= p1:
            if not opened:
                style.lid_row(c, n, n - p0, p1 - p0, outer)
            else:  # the wall is cut through, and the lid stands out over the side
                lit, mid, line = style.open_lid()
                side, sill = style.reveal()
                for x in range(1, w - 1):
                    c.put(x, n, side if n == p0 else sill if n == p1 else DARK)
                if p0 < n < p1:
                    step = 1 if east else -1
                    c.put(outer, n, lit if n - p0 not in (2, p1 - p0 - 2) else IRON[3])
                    c.put(outer - step, n, mid if n - p0 not in (2, p1 - p0 - 2) else IRON[1])
                    if n in (p0 + 1, p1 - 1):
                        c.put(outer, n, line)
                        c.put(outer - step, n, line)
    c.stamp(end, 0, length)
    return c


def port_tile(style, opened, d):
    c = Cv(SIZE, SIZE)
    if d == 'SOUTH':
        c.stamp(port_front(style, opened, False), 0, SIZE - WALL)
    elif d == 'NORTH':
        c.stamp(port_front(style, opened, True).shaded(0.86), 0, 0)
        shadow(c, WALL)
    else:
        piece = port_strip(style, opened, d == 'EAST')
        c.stamp(piece, SIZE - piece.w if d == 'EAST' else 0, 0)
        if d == 'WEST':  # lit from the left: only a west side shades her own deck
            for y in range(SIZE):
                if c.px[piece.w - 1, y][3] == 255 and not c.px[piece.w, y][3]:
                    c.put(piece.w, y, (0, 0, 0), 56)
    return c.im


# --- cargo hatch ----------------------------------------------------------------

HATCH = (3, 28)   # the coaming's outer edge
WELL = (7, 24)    # the opening inside it
STACK = (17, 27)  # the stacked boards of the open hatch


def coaming(c):
    a, b = HATCH
    for y in range(a, b + 1):
        for x in range(a, b + 1):
            ring = min(x - a, y - a, b - x, b - y)
            if ring > 3:
                continue
            near = x - a == ring or y - a == ring  # the top and left runs
            if ring == 0:
                t = WOOD[0]
            elif ring == 1:
                t = WOOD[5] if near else WOOD[3]
            elif ring == 2:
                t = WOOD[4] if near else WOOD[2]
            else:
                t = WOOD[0] if near else WOOD[1]  # the inner faces: shaded under the lit runs
            c.put(x, y, t)
    for k in (1, 2):  # mitred corners
        for x, y in ((a + k, a + k), (b - k, a + k), (a + k, b - k), (b - k, b - k)):
            c.put(x, y, WOOD[1])
    for x, y in ((a + 8, a + 1), (b - 8, a + 1), (a + 1, a + 8), (a + 1, b - 8),
                 (a + 8, b - 2), (b - 8, b - 2), (b - 2, a + 8), (b - 2, b - 8)):  # bolts
        c.put(x, y, IRON[3])
    for n in range(a + 1, b + 2):  # the shadow she throws on the deck
        c.put(n, b + 1, (0, 0, 0), 64)
        c.put(b + 1, n, (0, 0, 0), 64)


def hatch_boards(c):
    a, b = WELL
    for y in range(a, b + 1):
        for x in range(a, b + 1):
            r = (x - a) % 3
            t = HULL[1] if r == 2 else HULL[4] if r == 0 and noise(x, y // 4, 21) > 0.2 else HULL[3]
            if y == a:
                t = HULL[2] if r != 2 else HULL[1]  # under the coaming's lip
            c.put(x, y, t)
    for y in (a + 3, b - 4):  # battens
        c.row(a, b, y, WOOD[5])
        c.row(a, b, y + 1, WOOD[3])
        c.row(a, b, y + 2, HULL[0])
        for x in range(a + 1, b, 3):
            c.put(x, y, IRON[3])
    for x in (a + 5, b - 6):  # lifting rings
        c.row(x, x + 1, 14, IRON[1])
        c.row(x, x + 1, 17, IRON[4])
        c.col(x - 1, 15, 16, IRON[1])
        c.col(x + 2, 15, 16, IRON[4])


def hatch_hold(c):
    a, b = WELL
    for y in range(a, b + 1):
        for x in range(a, b + 1):
            depth = (y - a) + (x - a)
            t = SOOT if y < a + 2 or x < a + 1 else HOLD[0] if depth < 14 else HOLD[1]
            c.put(x, y, t)
    for y in range(b - 5, b + 1):  # the hold floor, where the light reaches it
        for x in range(a + 4, STACK[0]):
            seam = (y - (b - 5)) % 3 == 2
            c.put(x, y, HOLD[1] if seam else HOLD[3] if y > b - 3 and x > a + 5 else HOLD[2])
    for y in range(a, b - 3):  # the ladder against the coaming
        k = (y - a) / float(b - 4 - a)
        rail = mix(WOOD[4], HOLD[2], k)
        c.put(a + 1, y, rail)
        c.put(a + 5, y, mix(rail, HOLD[0], 0.25))
        if (y - a) % 3 == 1:
            c.row(a + 2, a + 4, y, mix(WOOD[5], HOLD[2], k))
    # the hatch boards, stacked along the east coaming
    x0, x1 = STACK
    for i, (bx, top, bottom) in enumerate(((x0 + 1, 8, 25), (x0 + 4, 6, 23), (x0 + 7, 9, 26))):
        for y in range(top, bottom + 1):
            c.put(bx, y, HULL[5] if i != 1 else WOOD[5])
            c.put(bx + 1, y, HULL[4] if noise(bx, y // 4, 23) > 0.2 else HULL[3])
            c.put(bx + 2, y, HULL[2])
        c.row(bx, bx + 2, top, HULL[5] if i != 1 else WOOD[5])
        c.row(bx - 1, bx + 3, top - 1, HULL[0])
        c.row(bx - 1, bx + 3, bottom + 1, HULL[0])
        c.row(bx, bx + 2, bottom, HULL[1])
        c.col(bx - 1, top, bottom, HULL[0])
        c.col(bx + 3, top, bottom, HULL[0])
        c.put(bx + 1, top + 3, IRON[3])   # the ring bolts
        c.put(bx + 1, bottom - 3, IRON[3])
    for y in range(7, 27):  # the stack shades the hold beside it
        if c.px[x0 - 1, y][:3] in (HOLD[2], HOLD[3]):
            c.put(x0 - 1, y, HOLD[1])


def hatch(opened):
    c = Cv(SIZE, SIZE)
    coaming(c)
    if opened:
        hatch_hold(c)
    else:
        hatch_boards(c)
    return c.im


# --- davits ---------------------------------------------------------------------

def fall(c, x, y0, y1):
    """A two-part rope fall."""
    for y in range(y0, y1 + 1):
        c.put(x, y, ROPE[2] if (y - y0) % 3 != 2 else ROPE[0])


def block(c, x, y):
    c.put(x, y, WOOD[5])
    c.put(x, y + 1, WOOD[2])
    c.put(x - 1, y, WOOD[1])
    c.put(x - 1, y + 1, WOOD[0])


def hook(c, x, y):
    c.put(x, y, IRON[4])
    c.put(x, y + 1, IRON[2])
    c.put(x - 1, y + 1, IRON[1])


def post(c, x, top, base):
    """An upright iron arm two pixels thick, lit on its left, on a foot plate."""
    for y in range(top, base + 1):
        c.put(x, y, IRON[5] if y % 5 == 1 else IRON[4])
        c.put(x + 1, y, IRON[1])
    c.row(x - 1, x + 2, base, IRON[3])
    c.row(x - 1, x + 2, base + 1, IRON[0])
    c.put(x - 1, base, IRON[5])
    for sx in range(x, x + 5):
        c.put(sx, base + 2, (0, 0, 0), 52)
    c.put(x + 3, base + 1, (0, 0, 0), 52)
    c.put(x, top + 6, ROPE[1])  # the fall, made up on its cleat
    c.put(x + 1, top + 6, ROPE[0])
    c.put(x + 1, top + 7, ROPE[1])


def crook(c, x, top, step, reach=5):
    """The curved head of an arm: from the post at x up, over and down by step."""
    lit = ((1, 2), (2, 1)) + tuple((n, 0) for n in range(3, reach)) + ((reach, 1),)
    for dx, dy in lit:
        c.put(x + dx * step, top + dy + 1, IRON[1])
    for dx, dy in lit:
        c.put(x + dx * step, top + dy, IRON[5] if dy == 0 else IRON[4])
    c.put(x, top + 2, IRON[4])
    c.put(x + reach * step, top + 2, IRON[2])
    return x + reach * step


def boat_side(c, x0, y0, well):
    """The rowing boat in elevation, 24 wide: well rows of her inside, then her side."""
    w = 24
    c.row(x0 + 2, x0 + w - 3, y0, HULL[0])
    y = y0 + 1
    c.row(x0 + 1, x0 + w - 2, y, WOOD[3])  # the far gunwale
    c.put(x0 + 1, y, HULL[0])
    c.put(x0 + w - 2, y, HULL[0])
    for n in range(well):
        y += 1
        for x in range(x0 + 1, x0 + w - 1):
            c.put(x, y, HULL[1] if n == 0 else HULL[2])
        for tx in (x0 + 5, x0 + 11, x0 + 17):  # thwarts
            c.put(tx, y, WOOD[5])
            c.put(tx + 1, y, WOOD[3])
        c.put(x0, y, HULL[0])
        c.put(x0 + w - 1, y, HULL[0])
    if well > 1:  # an oar lying along the thwarts
        c.row(x0 + 3, x0 + 15, y - 1, ROPE[2])
        c.row(x0 + 16, x0 + 19, y - 1, WOOD[5])
    y += 1
    c.row(x0, x0 + w - 1, y, WOOD[5])  # the near gunwale
    c.put(x0, y, WOOD[2])
    c.put(x0 + w - 1, y, WOOD[2])
    sides = 30 - y if well == 1 else 2
    for n in range(sides):
        y += 1
        inset = max(0, n - sides + 3) + (1 if n else 0)
        for x in range(x0 + inset, x0 + w - inset):
            t = 1 if n % 3 == 2 and n < sides - 1 else 4 if n == 0 else 3 if n < sides - 1 else 2
            if noise(x // 4, n, 31) < 0.2 and t > 2:
                t -= 1
            c.put(x, y, HULL[t])
        c.put(x0 + inset, y, HULL[0])
        c.put(x0 + w - 1 - inset, y, HULL[0])
    inset = max(0, sides - 2) if sides > 2 else 2
    c.row(x0 + inset, x0 + w - 1 - inset, y + 1, HULL[0])
    return y + 1


def boat_top(c, x0, y0):
    """The rowing boat from above, 8 wide and 24 long, her bow to the north."""
    length = 24
    for n in range(length):
        inset = (3, 2, 1, 1)[n] if n < 4 else (1 if n >= length - 2 else 0)
        y = y0 + n
        a, b = x0 + inset, x0 + 7 - inset
        for x in range(a, b + 1):
            c.put(x, y, HULL[2] if (x - x0) in (3, 4) else HULL[3])
        c.put(a, y, HULL[0])
        c.put(b, y, HULL[0])
        if b - a >= 3:
            c.put(a + 1, y, WOOD[5])
            c.put(b - 1, y, WOOD[2])
        if n in (0, length - 1):
            c.row(a, b, y, HULL[0])
    for n in (6, 12, 18):  # thwarts
        c.row(x0 + 2, x0 + 5, y0 + n, WOOD[5])
        c.row(x0 + 2, x0 + 5, y0 + n + 1, WOOD[2])
    c.col(x0 + 5, y0 + 8, y0 + 11, ROPE[2])  # an oar
    c.col(x0 + 5, y0 + 14, y0 + 17, ROPE[2])
    c.col(x0 + 5, y0 + 20, y0 + 21, WOOD[5])
    c.row(x0 + 2, x0 + 5, y0 + length - 2, WOOD[3])  # stern sheets


def davit(d, boat):
    c = Cv(SIZE, SIZE)
    if d == 'SOUTH':  # seen from outboard: the boat hangs in front of the arms
        heads = []
        for x, step in ((4, 1), (26, -1)):
            post(c, x, 8, 25)
            heads.append(crook(c, x if step < 0 else x + 1, 6, step))
        for hx in heads:
            block(c, hx, 9)
            fall(c, hx, 11, 21 if boat else 16)
            if not boat:
                block(c, hx, 17)
                hook(c, hx, 19)
        if boat:
            for y in range(21, SIZE):  # she hides the feet of the arms
                for x in range(SIZE):
                    c.clear(x, y)
            boat_side(c, 4, 20, 1)
            for hx in heads:  # the falls hook into her ring bolts
                c.put(hx, 22, IRON[4])
    elif d == 'NORTH':  # seen from inboard: the boat hangs beyond the arms
        if boat:  # looked down into, her bow to the west
            plan = Cv(8, 24)
            boat_top(plan, 0, 0)
            lying = Cv(24, 8)
            lying.im = plan.im.transpose(Image.TRANSPOSE)
            lying.px = lying.im.load()
            c.stamp(lying, 4, 1)
        heads = []
        for x, step in ((4, 1), (26, -1)):
            post(c, x, 3, 20)
            heads.append(crook(c, x if step < 0 else x + 1, 1, step))
        for hx in heads:
            block(c, hx, 4)
            if boat:
                c.put(hx, 6, IRON[4])
            else:
                fall(c, hx, 6, 10)
                block(c, hx, 11)
                hook(c, hx, 13)
    else:  # in profile: the arms reach out over the side, the boat lies along it
        east = d == 'EAST'
        step = 1 if east else -1
        px = 19 if east else 11
        if boat:
            boat_top(c, 24 if east else 0, 6)
        for top, base in ((2, 13), (17, 28)):
            post(c, px, top + 3, base)
            hx = crook(c, px + 1 if east else px, top, step, 7) + step
            c.put(hx, top + 1, IRON[4])
            c.put(hx, top + 2, IRON[2])
            block(c, hx, top + 3)
            if boat:
                fall(c, hx, top + 5, top + 6)
                c.put(hx, top + 7, IRON[4])
            else:
                fall(c, hx, top + 5, top + 6)
                block(c, hx, top + 7)
                hook(c, hx, top + 9)
    return c.im


# --- sheet ----------------------------------------------------------------------

def build():
    states = []
    for style in (WoodSide(), SteelSide()):
        for opened in (False, True):
            states.append(four(style.name + ('_open' if opened else ''),
                               [port_tile(style, opened, d) for d in DIRS]))
    states.append(('cargo_hatch', {'dirs': '1', 'frames': '1'}, [hatch(False)]))
    states.append(('cargo_hatch_open', {'dirs': '1', 'frames': '1'}, [hatch(True)]))
    states.append(four('davit', [davit(d, False) for d in DIRS]))
    states.append(four('davit_boat', [davit(d, True) for d in DIRS]))
    return [(SHEET, SIZE, states)]


# --- checks ---------------------------------------------------------------------

def changed_box(a, b):
    """The box of the pixels two frames do not share."""
    pa, pb = a.load(), b.load()
    xs = [x for y in range(SIZE) for x in range(SIZE) if pa[x, y] != pb[x, y]]
    ys = [y for y in range(SIZE) for x in range(SIZE) if pa[x, y] != pb[x, y]]
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1) if xs else None


def check_drawing(sheets):
    problems = []
    states = sheets[0][2]
    by_name = {name: ims for name, _, ims in states}
    want = ['gunport_wood_gate', 'gunport_wood_gate_open', 'gunport_steel_gate', 'gunport_steel_gate_open',
            'cargo_hatch', 'cargo_hatch_open', 'davit', 'davit_boat']
    if [name for name, _, _ in states] != want:
        problems.append('needs the states %s' % ', '.join(want))
    for name, keys, ims in states:
        if len(ims) != int(keys['dirs']):
            problems.append('%s: %d frames for %s dirs' % (name, len(ims), keys['dirs']))
        if keys['dirs'] == '4' and len({im.tobytes() for im in ims}) != 4:
            problems.append('%s: needs four different directions' % name)
        for d, im in zip(DIRS, ims):
            box = im.getchannel('A').getbbox()
            if not box:
                problems.append('%s %s: empty' % (name, d))
                continue
            x0, y0, x1, y1 = box
            if name.startswith('gunport'):
                if not {'SOUTH': y1 == SIZE, 'NORTH': y0 == 0, 'EAST': x1 == SIZE, 'WEST': x0 == 0}[d]:
                    problems.append('%s %s: does not reach its edge' % (name, d))
                reach = {'SOUTH': SIZE - y0, 'NORTH': y1, 'EAST': SIZE - x0, 'WEST': x1}[d]
                if reach > (WALL + 2 if d in ('SOUTH', 'NORTH') else 7):
                    problems.append('%s %s: reaches %d px into the tile' % (name, d, reach))
                if (x0, x1) != (0, SIZE) if d in ('SOUTH', 'NORTH') else (y0, y1) != (0, SIZE):
                    problems.append('%s %s: does not span the tile' % (name, d))
            elif name.startswith('cargo_hatch'):
                if min(x0, y0) not in (2, 3) or max(x1, y1) not in (SIZE - 2, SIZE - 3):
                    problems.append('%s: needs 2 or 3 pixels of margin, has %s' % (name, box))
    # shutting and opening moves the lid or the boards and nothing else
    for shut, opened, limit in (('gunport_wood_gate', 'gunport_wood_gate_open', 16),
                                ('gunport_steel_gate', 'gunport_steel_gate_open', 16),
                                ('cargo_hatch', 'cargo_hatch_open', 24)):
        for d, a, b in zip(DIRS, by_name.get(shut, ()), by_name.get(opened, ())):
            box = changed_box(a, b)
            if not box:
                problems.append('%s %s: shut and open are the same' % (shut, d))
            elif box[2] - box[0] > limit or box[3] - box[1] > limit:
                problems.append('%s %s: opening changes more than the lid, %s' % (shut, d, box))
    for d, a, b in zip(DIRS, by_name.get('davit', ()), by_name.get('davit_boat', ())):
        pa, pb = a.load(), b.load()
        more = sum(1 for y in range(SIZE) for x in range(SIZE) if pb[x, y][3] and not pa[x, y][3])
        if more < 80:
            problems.append('davit_boat %s: no boat on the falls' % d)
        x0, y0, x1, y1 = changed_box(a, b)
        side = {'SOUTH': y1 == SIZE, 'NORTH': y0 <= 3, 'EAST': x1 == SIZE, 'WEST': x0 == 0}[d]
        if not side:
            problems.append('davit_boat %s: the boat does not hang over the side' % d)
    return problems


def write_preview(path, sheets, scale=4):
    """Every state and direction, labelled, on a wooden and on a steel deck."""
    states = sheets[0][2]
    decks = (('wooden deck', (128, 96, 62)), ('steel deck', (104, 110, 116)))
    gap, label_w, head = 4, 50, 12
    block_w = 4 * (SIZE + gap)
    width = label_w + len(decks) * block_w + gap + 4 * (SIZE + 1) + gap
    height = head + len(states) * (SIZE + gap) + gap
    out = Image.new('RGBA', (width, height), (30, 30, 34, 255))
    for row, (name, _, ims) in enumerate(states):
        y = head + row * (SIZE + gap)
        for k, (_, colour) in enumerate(decks):
            for i, im in enumerate(ims):
                x = label_w + k * block_w + i * (SIZE + gap)
                out.alpha_composite(backdrop(SIZE, SIZE, colour, 40), (x, y))
                out.alpha_composite(im, (x, y))
    out = out.convert('RGB').resize((out.width * scale, out.height * scale), Image.NEAREST)
    # the same frames at their real size, on the wooden deck
    for row, (name, _, ims) in enumerate(states):
        for i, im in enumerate(ims):
            x = (label_w + len(decks) * block_w + gap) * scale + i * (SIZE + 4)
            y = (head + row * (SIZE + gap)) * scale + 2 * SIZE - SIZE // 2
            tile = backdrop(SIZE, SIZE, decks[0][1], 40)
            tile.alpha_composite(im)
            out.paste(tile.convert('RGB'), (x, y))
    draw = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    ink, dim = (236, 232, 220), (168, 168, 160)
    for k, (title, _) in enumerate(decks):
        x = (label_w + k * block_w) * scale
        draw.text((x, 4), '4x on a %s' % title, fill=ink, font=font)
        for i, d in enumerate(DIRS):
            draw.text((x + i * (SIZE + gap) * scale, 26), d, fill=dim, font=font)
    draw.text(((label_w + len(decks) * block_w + gap) * scale, 4), '1x', fill=ink, font=font)
    for row, (name, keys, _) in enumerate(states):
        y = (head + row * (SIZE + gap)) * scale
        words = name.split('_')
        lines = ['_'.join(words[:2]), '_' + '_'.join(words[2:])] if len(words) > 2 else [name]
        for n, line in enumerate(lines):
            draw.text((8, y + 40 + n * 14), line, fill=ink, font=font)
        draw.text((8, y + 40 + len(lines) * 14 + 4), '%s dir%s' % (keys['dirs'], 's' if keys['dirs'] != '1' else ''),
                  fill=dim, font=font)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def main():
    sheets = build()
    problems = check_drawing(sheets)
    if '--check' in sys.argv:
        problems += check_sheets(sheets)
        for line in problems:
            print(line)
        print('vessel openings: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    for path, size, states in sheets:
        write_dmi(path, states, size)
    if option('--preview'):
        write_preview(option('--preview'), sheets)
    return 0


if __name__ == '__main__':
    sys.exit(main())
