#!/usr/bin/env python3
"""Draw the combat stance HUD button states into the four HUD icon sheets.

Hand-placed pixel art: every glyph and pictogram below is a pixel map typed
out by hand, drawn in each HUD style's own palette on that style's existing
button frame. Nothing is generated or resampled.

Adds (or redraws) six states per sheet, beside the tactic button states:
    stance_manual, stance_measured, stance_aggressive,
    stance_disarming, stance_low, stance_guarded

Run from the repository root:
    python3 scripts/draw_combat_stance_buttons.py            # write the sheets
    python3 scripts/draw_combat_stance_buttons.py --preview out.png
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from dmi import Dmi  # noqa: E402

SCREEN = ROOT / "icons" / "mob" / "screen"
STANCES = ["manual", "measured", "aggressive", "disarming", "low", "guarded"]
# The caption has room for six narrow letters, like the tactic button's.
LABELS = {
    "manual": "MANUAL",
    "measured": "MEASRD",
    "aggressive": "AGGRO",
    "disarming": "DISARM",
    "low": "LOW",
    "guarded": "GUARD",
}

# 3x7 caption letters, matching the tactic button lettering.
FONT = {
    "A": [".#.", "#.#", "#.#", "###", "#.#", "#.#", "#.#"],
    "D": ["##.", "#.#", "#.#", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "#..", "##.", "#..", "#..", "###"],
    "G": [".##", "#..", "#..", "#.#", "#.#", "#.#", ".##"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "L": ["#..", "#..", "#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", "#.#", "#.#", ".#."],
    "R": ["##.", "#.#", "#.#", "##.", "#.#", "#.#", "#.#"],
    "S": [".##", "#..", "#..", ".#.", "..#", "..#", "##."],
    "U": ["#.#", "#.#", "#.#", "#.#", "#.#", "#.#", "###"],
    "W": ["#.#", "#.#", "#.#", "#.#", "###", "###", "#.#"],
}

# 3x5 small capitals for the liteweb plaque.
SMALL = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "I": ["#", "#", "#", "#", "#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
}

# Pictograms, 20 wide by 15 tall. '#' is the main tone, '+' the shade.
DOLL = [
    "...###...",
    "...###...",
    "...###...",
    ".#######.",
    "#.#####.#",
    "#.#####.#",
    "#.#####.#",
    "#.#####.#",
    "..#####..",
    "..##.##..",
    "..##.##..",
    "..##.##..",
    "..##.##..",
    "..##.##..",
]
ARROW = [  # points left at the chosen body part
    "..#....",
    ".##....",
    "#######",
    ".##....",
    "..#....",
]
CURSOR = [  # the player's own pointer
    "#.....",
    "##....",
    "###...",
    "####..",
    "#####.",
    "###...",
    "#.##..",
    "...#..",
]
SCALES = [
    ".........#.........",
    "...#############...",
    "...#.....#.....#...",
    "..+.+....#....+.+..",
    "..+.+....#....+.+..",
    ".+...+...#...+...+.",
    ".+...+...#...+...+.",
    "#######..#..#######",
    ".#####...#...#####.",
    ".........#.........",
    ".........#.........",
    ".......#####.......",
    "......#######......",
]
SHIELD = [
    "++.....++",
    "+#+++++#+",
    "+#######+",
    "+#######+",
    "+#######+",
    "++#####++",
    ".+#####+.",
    ".++###++.",
    "..+++++..",
]


def blank(w=20, h=15):
    return [["."] * w for _ in range(h)]


def stamp(grid, art, x, y):
    for dy, row in enumerate(art):
        for dx, c in enumerate(row):
            if c != ".":
                grid[y + dy][x + dx] = c


def pictogram(stance):
    g = blank()
    if stance == "measured":
        stamp(g, SCALES, 0, 1)
        return g
    if stance == "guarded":
        stamp(g, DOLL, 0, 1)
        stamp(g, SHIELD, 11, 4)
        return g
    stamp(g, DOLL, 3, 1)
    if stance == "manual":
        stamp(g, CURSOR, 13, 6)
    elif stance == "aggressive":
        stamp(g, ARROW, 12, 0)   # at the head
    elif stance == "disarming":
        stamp(g, ARROW, 13, 5)   # at the weapon hand
    elif stance == "low":
        stamp(g, ARROW, 11, 10)  # at the legs
    return g


def text_width(text, font):
    return sum(len(font[c][0]) for c in text) + len(text) - 1


def draw_text(im, text, font, x, y, colour):
    for ch in text:
        glyph = font[ch]
        for dy, row in enumerate(glyph):
            for dx, c in enumerate(row):
                if c == "#":
                    im.putpixel((x + dx, y + dy), colour(x + dx, y + dy))
        x += len(glyph[0]) + 1


def draw_pictogram(im, stance, x, y, main, shade):
    for dy, row in enumerate(pictogram(stance)):
        for dx, c in enumerate(row):
            if c == "#":
                im.putpixel((x + dx, y + dy), main)
            elif c == "+":
                im.putpixel((x + dx, y + dy), shade)


def centred(text, font, left, right):
    return left + (right - left + 1 - text_width(text, font)) // 2


def draw_1713(sheet, stance):
    im = sheet.get_state("defend").frames[0].copy()
    light, mid = (150, 132, 115, 255), (135, 116, 99, 255)
    rows = {0: (91, 71, 54, 255), 1: (85, 65, 49, 255)}  # woven backing
    for y in range(5, 12):
        for x in range(5, 28):
            im.putpixel((x, y), rows[y % 2])
    for y in range(12, 27):
        for x in range(6, 26):
            im.putpixel((x, y), rows[y % 2])
    label = LABELS[stance]
    draw_text(im, label, FONT, centred(label, FONT, 5, 27), 5, lambda x, y: light)
    draw_pictogram(im, stance, 6, 12, light, mid)
    return im


def draw_console(sheet, stance):
    im = sheet.get_state("defend").frames[0].copy()
    back, cream, edge = (20, 17, 14, 150), (250, 237, 210, 255), (223, 211, 187, 211)
    for y in range(4, 29):
        for x in range(2, 30):
            im.putpixel((x, y), back)
    label = LABELS[stance]
    draw_text(im, label, FONT, centred(label, FONT, 4, 27), 5, lambda x, y: cream)
    draw_pictogram(im, stance, 6, 14, cream, edge)
    return im


def draw_fof(sheet, stance):
    im = sheet.get_state("kick").frames[0].copy()
    back, gold, dull = (34, 30, 28, 255), (174, 153, 65, 255), (139, 101, 52, 255)
    for y in range(4, 28):
        for x in range(4, 28):
            im.putpixel((x, y), back)
    label = LABELS[stance]
    draw_text(im, label, FONT, centred(label, FONT, 4, 27), 5, lambda x, y: gold)
    draw_pictogram(im, stance, 6, 13, gold, dull)
    return im


def draw_liteweb(sheet, stance):
    im = sheet.get_state("defend").frames[0].copy()
    plate, band, amber = (39, 55, 36, 255), (19, 21, 18, 255), (125, 89, 53, 255)
    label = LABELS[stance]
    left = centred(label, SMALL, 3, 27)
    right = left + text_width(label, SMALL) - 1
    for y in range(13, 20):
        for x in range(3, 28):
            im.putpixel((x, y), band if left - 1 <= x <= right + 1 else plate)
    draw_text(im, label, SMALL, left, 14, lambda x, y: amber)
    # An amber stud in the crest tells the stance plaque from the tactic one.
    stud = (61, 82, 72, 255)
    for y in range(2, 7):
        for x in range(12, 20):
            if im.getpixel((x, y)) == stud:
                im.putpixel((x, y), amber)
    return im


STYLES = [
    ("1713Style.dmi", draw_1713),
    ("ConsoleStyle.dmi", draw_console),
    ("FoFStyle.dmi", draw_fof),
    ("litewebStyle.dmi", draw_liteweb),
]


def build(style_file, draw):
    sheet = Dmi.from_file(str(SCREEN / style_file))
    drawn = {}
    for stance in STANCES:
        name = "stance_" + stance
        image = draw(sheet, stance)
        drawn[name] = image
        try:
            sheet.get_state(name).frames[0] = image
        except KeyError:
            sheet.state(name).frame(image)
    return sheet, drawn


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--preview", help="write an enlarged preview PNG instead of the sheets")
    args = parser.parse_args()

    if args.preview:
        scale, pad = 6, 4
        cell = 32 + pad
        out = Image.new("RGBA", (len(STANCES) * cell + pad, len(STYLES) * cell + pad), (92, 108, 88, 255))
        for r, (style_file, draw) in enumerate(STYLES):
            _, drawn = build(style_file, draw)
            for c, stance in enumerate(STANCES):
                out.alpha_composite(drawn["stance_" + stance], (pad + c * cell, pad + r * cell))
        out.resize((out.width * scale, out.height * scale), Image.NEAREST).save(args.preview)
        return

    for style_file, draw in STYLES:
        sheet, _ = build(style_file, draw)
        sheet.to_file(str(SCREEN / style_file))
        print("wrote", style_file)


if __name__ == "__main__":
    main()
