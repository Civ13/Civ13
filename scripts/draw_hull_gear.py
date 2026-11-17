"""Draws icons/obj/hull_gear.dmi: the killick and the twist of tarred oakum
(code/modules/naval/hull_anchors.dm, hull_caulking.dm).

Two 32x32 states, drawn pixel by pixel in a few flat shades with a dark
outline, to sit beside the iron anchor and the other gear on a deck.

- "killick": a stone lashed between the arms of a wooden crook, a wooden
  shank above it and a rope eye at the top.
- "tarred_oakum": a short twist of picked rope, black-brown with pitch,
  frayed at both ends.

Run from the repository root:

    python3 scripts/draw_hull_gear.py [preview.png]
"""
import sys

from PIL import Image

sys.path.insert(0, "tools")
import dmi  # noqa: E402

T = 32
OUT = (30, 24, 20, 255)
# Wood
W1 = (176, 128, 78, 255)
W2 = (138, 96, 56, 255)
W3 = (96, 64, 38, 255)
# Stone
S1 = (176, 174, 164, 255)
S2 = (138, 136, 128, 255)
S3 = (98, 97, 92, 255)
# Rope
R1 = (214, 190, 138, 255)
R2 = (160, 134, 88, 255)
# Tarred fibre
P1 = (122, 92, 60, 255)
P2 = (84, 60, 38, 255)
P3 = (52, 36, 24, 255)
P4 = (28, 20, 16, 255)


def outline(img):
    """A one-pixel dark line round everything drawn."""
    src = img.copy().load()
    px = img.load()
    for y in range(T):
        for x in range(T):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < T and 0 <= ny < T and src[nx, ny][3]:
                    px[x, y] = OUT
                    break


def killick():
    img = Image.new("RGBA", (T, T))
    px = img.load()
    # The shank: a straight wooden bar, lit on its left.
    for y in range(6, 26):
        px[15, y] = W1
        px[16, y] = W2
        px[17, y] = W3
    # The crook: two arms sweeping down and out from the foot of the shank,
    # their points turned up like flukes.
    for i in range(9):
        y = 26 - (i * i) // 12
        for side in (-1, 1):
            x = 16 + side * (2 + i)
            px[x, y] = W1 if side < 0 else W2
            px[x, y + 1] = W2 if side < 0 else W3
    for side in (-1, 1):
        x = 16 + side * 11
        px[x, 20] = W2
        px[x, 19] = W1
        px[x - side, 20] = W3
    # The stock across the top of the shank.
    for x in range(10, 23):
        px[x, 8] = W1 if x < 16 else W2
        px[x, 9] = W3
    # The stone: a rough oval lashed to the shank above the crook.
    for y in range(14, 24):
        half = (2, 4, 5, 6, 6, 6, 6, 5, 4, 2)[y - 14]
        for x in range(16 - half, 17 + half):
            shade = S1 if (x - 16) + (y - 18) < -3 else (S3 if (x - 16) + (y - 18) > 4 else S2)
            px[x, y] = shade
    px[13, 16] = S3
    px[19, 20] = S1
    px[18, 15] = S3
    # The lashings: two turns of rope round stone and shank.
    for y in (16, 21):
        for x in range(10, 23):
            if px[x, y][3] and px[x, y] in (S1, S2, S3):
                px[x, y] = R1 if x % 2 else R2
    # The rope eye at the head.
    for x, y in ((15, 3), (16, 2), (17, 3), (18, 4), (17, 5), (15, 5), (14, 4)):
        px[x, y] = R1 if y <= 3 else R2
    outline(img)
    return img


def oakum():
    img = Image.new("RGBA", (T, T))
    px = img.load()
    # A thick twist lying from lower left to upper right: each strand is a
    # short slanted stroke, and the strokes repeat along the twist.
    for step in range(13):
        cx = 8 + step
        cy = 22 - step
        for k in range(-3, 4):
            x = cx + k
            y = cy + k
            if not (0 <= x < T and 0 <= y < T):
                continue
            turn = (step + (k + 3) // 2) % 3
            edge = abs(k) == 3
            px[x, y] = P4 if edge else (P1, P2, P3)[turn]
            if y + 1 < T and not edge:
                px[x, y + 1] = (P2, P3, P3)[turn]
    # A glint of wet pitch along the top of the twist.
    for step in range(2, 12, 3):
        px[8 + step - 1, 22 - step - 2] = P1
    # Frayed ends: loose fibres at both ends.
    for x, y in ((4, 24), (5, 26), (6, 27), (3, 22), (7, 25), (5, 23), (6, 24)):
        px[x, y] = P2 if (x + y) % 2 else P3
    for x, y in ((23, 7), (25, 8), (24, 5), (26, 10), (22, 6), (24, 9), (25, 6)):
        px[x, y] = P2 if (x + y) % 2 else P3
    outline(img)
    return img


def main():
    out = dmi.Dmi(T, T)
    out.state("killick").frame(killick())
    out.state("tarred_oakum").frame(oakum())
    out.to_file("icons/obj/hull_gear.dmi")
    if len(sys.argv) > 1:
        plank = dmi.Dmi.from_file("icons/turf/floors.dmi").get_state("wood_ship").get_frame().convert("RGBA")
        anchor = dmi.Dmi.from_file("icons/obj/vehicles/vehicleparts.dmi").get_state("anchor").get_frame().convert("RGBA")
        shots = [anchor, killick(), oakum()]
        sheet = Image.new("RGBA", (len(shots) * 40 + 8, 48), (20, 20, 24, 255))
        for i, art in enumerate(shots):
            tile = plank.copy()
            tile.alpha_composite(art)
            sheet.paste(tile, (8 + i * 40, 8))
        sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
