"""Makes icons/effects/hull_awash.dmi: the water washing over the deck of a
hull whose bilge is awash (code/modules/naval/hull_awash.dm).

The film is cut from the game's own deep sea (icons/turf/beach.dmi, state
"seadeep"), so the water on a deck is the water around it: the same net of
light, the same shades and the same twelve-frame swell. The body of the sea
is one flat see-through blue, so the planks show under it and the deck still
reads as water. The blue body leaves the plank grain and silhouette dominant;
only the brightest moving highlights cover more than half of the plank. Three
flat levels of see-through, no blending between them.

Run from the repository root:

    python3 scripts/draw_hull_awash.py [preview.png]
"""
import sys

from PIL import Image

sys.path.insert(0, "tools")
import dmi  # noqa: E402

T = 32
SEA_ICON = "icons/turf/beach.dmi"
SEA_STATE = "seadeep"
# How much of the deck each part of the sea hides, of 255.
BODY = 72    # the blue body of the water
SHADE = 110   # the soft edge of the light
LIGHT = 155   # the net of light itself
# The body is one flat blue, a little deeper than the sea, so that wood seen
# through it stays blue water and does not go grey.
BODY_BLUE = (40, 122, 190)


def lum(p):
    return (p[0] * 3 + p[1] * 6 + p[2]) / 10


def film(sea):
    """One frame of the sea as a see-through film."""
    sea = sea.convert("RGBA")
    src = sea.load()
    lums = sorted(lum(src[x, y]) for x in range(T) for y in range(T))
    body = lums[len(lums) // 2]      # the commonest shade is the body
    top = lums[-1]
    out = Image.new("RGBA", (T, T))
    px = out.load()
    for y in range(T):
        for x in range(T):
            p = src[x, y]
            t = (lum(p) - body) / max(1.0, top - body)
            if t < 0.25:
                px[x, y] = BODY_BLUE + (BODY,)
            else:
                px[x, y] = (p[0], p[1], p[2], SHADE if t < 0.6 else LIGHT)
    return out


def main():
    sea = dmi.Dmi.from_file(SEA_ICON).get_state(SEA_STATE)
    count = sea.framecount
    delays = list(getattr(sea, "delays", None) or [])
    frames = [film(sea.get_frame(i)) for i in range(count)]
    out = dmi.Dmi(T, T)
    state = out.state("awash")
    for i, img in enumerate(frames):
        state.frame(img, delay=delays[i] if i < len(delays) else 2)
    out.to_file("icons/effects/hull_awash.dmi")
    if len(sys.argv) > 1:
        preview(frames, sea.get_frame(0).convert("RGBA"), sys.argv[1])


def preview(frames, sea, path):
    """A five by five deck on the sea: dry, then awash at three moments of
    the swell, twice life size."""
    plank = dmi.Dmi.from_file("icons/turf/floors.dmi").get_state("wood_ship").get_frame().convert("RGBA")
    W, H = 7, 7
    shots = [None, 0, len(frames) // 3, 2 * len(frames) // 3]
    sheet = Image.new("RGBA", (len(shots) * (W * T + 8) - 8, H * T), (20, 20, 24, 255))
    for i, f in enumerate(shots):
        scene = Image.new("RGBA", (W * T, H * T))
        for x in range(W):
            for y in range(H):
                scene.paste(sea, (x * T, y * T))
        for x in range(1, 6):
            for y in range(1, 6):
                scene.paste(plank, (x * T, y * T))
                if f is not None:
                    scene.alpha_composite(frames[f], (x * T, y * T))
        sheet.paste(scene, (i * (W * T + 8), 0))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)


if __name__ == "__main__":
    main()
