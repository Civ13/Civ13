#!/usr/bin/env python3
"""Draws pottery_designs.dmi, bands.json, glazes.json and pottery-preview.png.
Pixel art written procedurally with Pillow (no image generation).
Each pot is a hand-written lathe profile (half-width per row) plus hand-placed
handle/spout pixels; tones are picked from short hand-chosen ramps.
Usage: python3 tests/sprites/create_pottery_designs.py OUT_DIR, then copy
pottery_designs.dmi to icons/obj/."""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFont
from PIL.PngImagePlugin import PngInfo

OUT = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
T = 32
BOTTOM = 27  # last pot row

# ramps, dark -> light
TERRA = ["#6b2f2e", "#873b30", "#a14a35", "#b95c3d", "#cc7348", "#dc8d5c"]
RAW   = ["#665c57", "#746a63", "#82776f", "#8e837a", "#998e85", "#a69b91"]
GLAZE = ["#86868c", "#a2a2a7", "#bdbdc0", "#d5d5d7", "#ebebec", "#ffffff"]
INSIDE = {"terra": "#4a2228", "raw": "#4f4743"}

def rgb(h): return tuple(int(h[i:i+2], 16) for i in (1, 3, 5))

# hw = half-width per row, top to bottom; body is symmetric about x=15|16.
# mouth: 'open' = 3-row rim (back lip, dark interior, front lip); 'narrow' = lip row with dark centre
# handles: {row: [offsets]} offset o -> x=16+o (right) / 15-o (left); side 'r','l' or 'both'
# extra: [(row, dx)] single pixels at absolute dx from x=16 (negative = left), e.g. a spout
SHAPES = {
 "cup": dict(hw=[5,5,5,5,5,5,5,4,4], mouth="open", foot=1,
             handles=("r", {1:[5,6], 2:[7], 3:[7], 4:[7], 5:[5,6]}),
             band=(12, 22, 8, 3)),
 "bowl": dict(hw=[7,8,8,8,8,7,6,4,3], mouth="open", foot=1,
              band=(10, 22, 12, 3)),
 "jug": dict(hw=[3,3,2,2,3,4,5,6,6,6,6,6,5,4,3,3], mouth="narrow", foot=1,
             handles=("r", {1:[3,4], 2:[5], 3:[5], 4:[6], 5:[6], 6:[5,6]}),
             extra=[(0, -5), (0, -4)],
             band=(11, 19, 10, 4)),
 "jar": dict(hw=[4,4,4,3,5,6,7,7,7,7,7,6,6,5,4,4], mouth="open", foot=1,
             band=(10, 18, 12, 4)),
 "vase": dict(hw=[4,3,2,2,2,3,4,5,6,6,6,6,5,5,4,4,3,3,4], mouth="narrow", foot=1,
              band=(11, 17, 10, 4)),
 "amphora": dict(hw=[4,3,2,2,2,2,3,5,6,7,7,7,7,7,6,6,5,5,4,4,3,2,2,3], mouth="narrow", foot=2,
                 handles=("both", {2:[2,3,4], 3:[5], 4:[5], 5:[5], 6:[5]}),
                 band=(10, 13, 12, 5)),
 "flask": dict(hw=[3,2,2,2,4,5,6,7,7,7,7,7,7,6,5,4,3], mouth="narrow", foot=1,
               handles=("both", {2:[2,3,4], 3:[5], 4:[5]}),
               band=(10, 19, 12, 4)),
 "storage_jar": dict(hw=[6,6,6,5,7,9,10,11,11,11,11,11,11,11,11,10,10,9,9,8,7,6,5,5,5],
                     mouth="open", foot=2, ridges=[4, 16],
                     band=(8, 11, 16, 6)),
}

def build(spec):
    """-> dict (x,y) -> (kind, intensity 0..1). kinds: body rim inside foot handle"""
    hw = spec["hw"]; n = len(hw); top = BOTTOM - n + 1
    px = {}
    for r, h in enumerate(hw):
        y = top + r; v = r / (n - 1)
        slope = max(-2, min(2, hw[min(n-1, r+1)] - hw[max(0, r-1)]))
        for x in range(16 - h, 16 + h):
            u = (x + 0.5 - 16) / h
            nz = math.sqrt(max(0.0, 1 - u*u))
            i = 0.30 + 0.25*u + 0.50*nz - 0.12*v - 0.04*slope
            i -= 0.25 * max(0.0, abs(u) - 0.6) / 0.4
            kind = "body"
            if r >= n - spec["foot"]:
                kind = "foot"; i -= 0.10
            if r in spec.get("ridges", []):
                i += 0.10
            if (r - 1) in spec.get("ridges", []):
                i -= 0.08
            if spec["mouth"] == "open":
                if r == 0: kind = "rim"; i += 0.10
                elif r == 1:
                    edge = x in (16 - h, 16 + h - 1)
                    kind = "rim" if edge else "inside"; i += 0.10
                elif r == 2: kind = "rim"; i += 0.16
                elif r == 3: i -= 0.08          # shadow under the lip
            else:
                if r == 0:
                    kind = "inside" if abs(x + 0.5 - 16) < h - 1 else "rim"; i += 0.12
                elif r == 1: i -= 0.06
            px[(x, y)] = (kind, max(0.0, min(1.0, i)))
    if "handles" in spec:
        side, rows = spec["handles"]
        for r, offs in rows.items():
            for o in offs:
                if side in ("r", "both"): px[(16 + o, top + r)] = ("handle", 0.62 if o < max(offs) or len(offs) > 1 else 0.50)
                if side in ("l", "both"): px[(15 - o, top + r)] = ("handle", 0.30)
    for r, dx in spec.get("extra", []):
        px[(16 + dx, top + r)] = ("rim", 0.45)
    return px

def tone(ramp, i, contrast=1.0):
    i = 0.5 + (i - 0.5) * contrast
    return rgb(ramp[max(0, min(len(ramp) - 1, int(i * len(ramp))))])

def draw_base(px, kind):
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    ramp, con = (TERRA, 1.0) if kind == "terra" else (RAW, 0.72)   # raw clay is matte: flatter
    for (x, y), (k, i) in px.items():
        c = rgb(INSIDE[kind]) if k == "inside" else tone(ramp, i, con)
        im.putpixel((x, y), c + (255,))
    return im

def draw_glaze(px, spec):
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    n = len(spec["hw"]); top = BOTTOM - n + 1
    last = BOTTOM - spec["foot"]            # last glazed row
    for (x, y), (k, i) in px.items():
        if k in ("inside", "foot"): continue
        a = 255
        if y == last and n > 12 and (x * 3 + 1) % 4 == 0:
            continue                         # uneven dipped edge on the bigger pots
        im.putpixel((x, y), tone(GLAZE, i + 0.06) + (a,))
    return im

def draw_shade(px, spec):
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    bl, bt, bw, bh = spec["band"]
    N = 0.60
    for (x, y), (k, i) in px.items():
        if k == "inside": continue
        if bt <= y < bt + bh: f = 1.0
        elif y in (bt - 1, bt + bh): f = 0.55
        else: f = 0.28
        if i < N:
            a = (N - i) / N * 140 * f; col = (20, 10, 14)
        else:
            a = (i - N) / (1 - N) * 90 * f; col = (255, 250, 240)
        a = int(a / 12) * 12                 # stepped, keeps flat pixel clusters
        if a > 0: im.putpixel((x, y), col + (a,))
    return im

def check_band(px, spec, name):
    l, t, w, h = spec["band"]
    for y in range(t, t + h):
        for x in range(l, l + w):
            assert px.get((x, y), ("",))[0] == "body", f"{name}: band pixel {(x, y)} not on body"

# ---------- build states ----------
states = []
frames = {}
bands = {}
for name, spec in SHAPES.items():
    px = build(spec)
    check_band(px, spec, name)
    frames[name + "_unfired"] = draw_base(px, "raw")
    frames[name] = draw_base(px, "terra")
    frames[name + "_glaze"] = draw_glaze(px, spec)
    frames[name + "_shade"] = draw_shade(px, spec)
    states += [name + "_unfired", name, name + "_glaze", name + "_shade"]
    l, t, w, h = spec["band"]
    bands[name] = {"left": l, "top": t, "w": w, "h": h}

cols = math.ceil(math.sqrt(len(states)))
rows = math.ceil(len(states) / cols)
sheet = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
for n, s in enumerate(states):
    sheet.paste(frames[s], ((n % cols) * T, (n // cols) * T))
desc = "# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n"
for s in states:
    desc += f'state = "{s}"\n\tdirs = 1\n\tframes = 1\n'
desc += "# END DMI\n"
meta = PngInfo(); meta.add_text("Description", desc, zip=True)
sheet.save(os.path.join(OUT, "pottery_designs.dmi"), format="PNG", pnginfo=meta, optimize=True)

json.dump(bands, open(os.path.join(OUT, "bands.json"), "w"), indent=1)

GLAZES = [
 {"name": "wood-ash glaze", "hex": "#a3a878", "era_hint": "Bronze Age onward - accidental then deliberate kiln-ash glaze (Shang China c.1500 BC); olive green-brown"},
 {"name": "white slip", "hex": "#e9dcc0", "era_hint": "Neolithic onward - fine pale clay slip (white-ground wares); available from the earliest pottery"},
 {"name": "red ochre slip", "hex": "#b5442f", "era_hint": "Neolithic to Roman - burnished iron-oxide slip (red-slip ware, terra sigillata)"},
 {"name": "black gloss", "hex": "#2e2927", "era_hint": "Iron Age / Classical - Attic black gloss, a reduction-fired iron slip (6th-4th c. BC)"},
 {"name": "turquoise alkaline glaze", "hex": "#35b3ad", "era_hint": "Bronze Age to medieval - copper in alkaline glaze (Egyptian faience, Parthian, Islamic wares)"},
 {"name": "lead amber glaze", "hex": "#cf8f2c", "era_hint": "Classical to medieval - iron-tinted lead glaze (Roman, Byzantine, medieval European jugs)"},
 {"name": "copper green lead glaze", "hex": "#4c9450", "era_hint": "Classical to medieval - copper-tinted lead glaze (Han China, Tang sancai, medieval Europe)"},
 {"name": "celadon", "hex": "#a9cbab", "era_hint": "Classical to medieval - iron-in-reduction stoneware glaze (Yue ware, Song Longquan)"},
 {"name": "tin white glaze", "hex": "#f3f1e9", "era_hint": "Medieval onward - opaque tin-opacified glaze (9th c. Abbasid Iraq, maiolica, delftware)"},
 {"name": "cobalt blue", "hex": "#3353ad", "era_hint": "Medieval onward - cobalt oxide (9th c. Abbasid blue-on-white, 14th c. Yuan blue-and-white)"},
]
json.dump(GLAZES, open(os.path.join(OUT, "glazes.json"), "w"), indent=1)

# ---------- preview ----------
def multiply(layer, hexcol):
    c = rgb(hexcol); out = layer.copy(); p = out.load()
    for y in range(T):
        for x in range(T):
            r, g, b, a = p[x, y]
            if a: p[x, y] = (r * c[0] // 255, g * c[1] // 255, b * c[2] // 255, a)
    return out

def band_img(w, h, ground, line, accent):
    im = Image.new("RGBA", (w, h), rgb(ground) + (255,))
    for x in range(w):
        im.putpixel((x, 0), rgb(line) + (255,)); im.putpixel((x, h - 1), rgb(line) + (255,))
    inner = h - 2
    for x in range(w):
        if inner >= 3:      # meander (square wave), on the taller bands
            ph = x % 6
            ys = range(inner) if ph in (0, 3) else ([0] if ph in (1, 2) else [inner - 1])
            ys = [yy for yy in ys if not (inner >= 4 and yy in (0, inner - 1) and False)]
            for yy in ys: im.putpixel((x, 1 + yy), rgb(accent) + (255,))
        elif inner == 2:    # zigzag
            im.putpixel((x, 1 + (0 if x % 4 in (0, 1) else 1)), rgb(accent) + (255,))
        else:               # dotted row
            if x % 2 == 0: im.putpixel((x, 1), rgb(accent) + (255,))
    return im

def comp(name, glaze=None, band=None):
    out = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    out.alpha_composite(frames[name])
    if glaze: out.alpha_composite(multiply(frames[name + "_glaze"], glaze))
    if band:
        b = bands[name]
        out.alpha_composite(band_img(b["w"], b["h"], *band), (b["left"], b["top"]))
        out.alpha_composite(frames[name + "_shade"])
    return out

S = 4; CW = T * S + 12; LW = 96; TH = 34
colnames = ["unfired", "bisque", "glazed", "glazed", "glazed", "bisque + band", "glazed + band"]
names = list(SHAPES)
W = LW + CW * len(colnames) + 8; H = TH + (T * S + 26) * len(names) + 8
pv = Image.new("RGBA", (W, H), (201, 196, 184, 255))
d = ImageDraw.Draw(pv)
try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
except Exception: font = ImageFont.load_default()
for c, cn in enumerate(colnames):
    d.text((LW + c * CW + 6, 10), cn, fill=(40, 34, 30), font=font)
G = {g["name"]: g["hex"] for g in GLAZES}; gl = list(G)
for r, name in enumerate(names):
    y0 = TH + r * (T * S + 26)
    d.text((8, y0 + 50), name, fill=(40, 34, 30), font=font)
    b = bands[name]
    d.text((8, y0 + 66), f"band {b['w']}x{b['h']}", fill=(90, 80, 72), font=font)
    d.text((8, y0 + 80), f"@ {b['left']},{b['top']}", fill=(90, 80, 72), font=font)
    three = [gl[(r * 3 + k) % len(gl)] for k in range(3)]
    bandglaze = ["tin white glaze", "celadon", "white slip", "turquoise alkaline glaze"][r % 4]
    bandcols = {"tin white glaze": ("#f3f1e9", "#27408f", "#27408f"), "celadon": ("#a9cbab", "#3d5b46", "#f1ead2"),
                "white slip": ("#e9dcc0", "#2e2927", "#a5402c"), "turquoise alkaline glaze": ("#35b3ad", "#1d2a4a", "#f1ead2")}[bandglaze]
    cells = [(comp(name + "_unfired") if False else frames[name + "_unfired"], ""),
             (comp(name), ""),
             (comp(name, G[three[0]]), three[0]), (comp(name, G[three[1]]), three[1]), (comp(name, G[three[2]]), three[2]),
             (comp(name, None, ("#2e2927", "#e9dcc0", "#e9dcc0") if r % 2 == 0 else ("#e9dcc0", "#2e2927", "#8a2f25")), "black / cream slip paint"),
             (comp(name, G[bandglaze], bandcols), bandglaze)]
    for c, (im, cap) in enumerate(cells):
        x0 = LW + c * CW
        d.rectangle([x0, y0, x0 + T * S - 1, y0 + T * S - 1], fill=(186, 181, 168))
        pv.alpha_composite(im.resize((T * S, T * S), Image.NEAREST), (x0, y0))
        d.text((x0, y0 + T * S + 2), cap.replace(" glaze", "").replace(" alkaline", "")[:22], fill=(70, 62, 56), font=font)
pv.convert("RGB").save(os.path.join(OUT, "pottery-preview.png"))
print("states:", len(states), "sheet", sheet.size)
