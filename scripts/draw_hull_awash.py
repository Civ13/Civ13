"""Draws icons/effects/hull_awash.dmi: the film of water over the deck of a
hull whose bilge is awash (code/modules/naval/hull_awash.dm).

One tileable 32x32 state, "awash", of four frames. Flat shades in the sea's
own colours with ripple lines that drift down the deck, so the planks under it
still read. Run from the repository root:

    python3 scripts/draw_hull_awash.py [preview.png]
"""
import sys

from PIL import Image

sys.path.insert(0, "tools")
import dmi  # noqa: E402

T = 32
FRAMES = 4
# The sea's shades, see-through so the deck shows under them.
FILM = (40, 122, 190, 150)
DEEP = (24, 88, 156, 185)
CREST = (126, 198, 236, 205)
FOAM = (238, 250, 255, 225)
# How far each column lifts a ripple: one wave every sixteen pixels.
WAVE = (0, 0, 1, 1, 1, 1, 0, 0, 0, 0, -1, -1, -1, -1, 0, 0)


def shade(x, y, f):
    """The shade at a pixel of frame f. Ripples lie sixteen rows apart and
    drift four rows a frame, and every length divides 32, so tiles and frames
    join without a seam."""
    row = (y + WAVE[x % 16] - 4 * f) % 16
    # Which ripple this is, so neighbours break in different places.
    which = ((y + WAVE[x % 16] - 4 * f) // 16) % 2
    along = (x + 8 * which) % 16
    if row == 0 and along < 10:
        return FOAM if along in (3, 4) else CREST
    if row == 1 and 1 <= along < 11:
        return DEEP
    return FILM


def frame(f):
    img = Image.new("RGBA", (T, T))
    px = img.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = shade(x, y, f)
    return img


def main():
    frames = [frame(f) for f in range(FRAMES)]
    out = dmi.Dmi(T, T)
    state = out.state("awash")
    for img in frames:
        state.frame(img, delay=4)
    out.to_file("icons/effects/hull_awash.dmi")
    if len(sys.argv) > 1:
        preview(frames, sys.argv[1])


def preview(frames, path):
    """The four frames over a 3 x 3 deck of ship planks, six times life size."""
    deck = dmi.Dmi.from_file("icons/turf/floors.dmi")
    plank = None
    for name in ("wood_ship", "wood"):
        try:
            plank = deck.get_state(name).get_frame()
            break
        except Exception:
            continue
    scale = 6
    sheet = Image.new("RGBA", ((3 * T + 8) * (FRAMES + 1) + 8, 3 * T + 16), (24, 28, 34, 255))
    for i in range(FRAMES + 1):
        tile = Image.new("RGBA", (3 * T, 3 * T), (92, 70, 48, 255))
        for tx in range(3):
            for ty in range(3):
                if plank:
                    tile.paste(plank, (tx * T, ty * T))
                if i:
                    tile.alpha_composite(frames[i - 1], (tx * T, ty * T))
        sheet.paste(tile, (8 + i * (3 * T + 8), 8))
    sheet = sheet.resize((sheet.width * scale // 2, sheet.height * scale // 2), Image.NEAREST)
    sheet.save(path)


if __name__ == "__main__":
    main()
