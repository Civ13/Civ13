"""Hand-placed 32px armor for the gunfire-era pieces (docs/armor-families.md),
drawn by Fable: the proof cuirass (polished steel breastplate with a central
ridge, proving dents and leather shoulder straps), the japanese proof do (dark
lacquered okegawa-do of riveted lames with red cords and a bullet dent) and
the First World War resin body shield (khaki quilted vest with amber resin
stitching). Every pixel is placed by this script from fixed palettes (Pillow
only); no external or generated artwork.

It appends to shared sheets and leaves every other state untouched:
  icons/obj/clothing/suits.dmi   proof_cuirass, proof_do      item icons
  icons/obj/clothing/ties.dmi    resin_shield                 item icon
  icons/mob/suit.dmi             all three                    worn, four directions
  icons/mob/ties.dmi             resin_shield                 worn, four directions
Running it again redraws the same cells. `--check` verifies the committed
states, `--preview <png>` writes a review sheet (item, worn, worn on the base
body). Released under Civ13 AGPL-3.0.
"""
import re
import struct
import sys
import zlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def grid(pal, x0, y0, rows):
    im=Image.new('RGBA',(32,32),(0,0,0,0))
    for j,r in enumerate(rows):
        for i,ch in enumerate(r):
            if ch!='.': im.putpixel((x0+i,y0+j),pal[ch]+(255,))
    return im


mir = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)


# ---- proof cuirass: polished steel, leather straps
PC={'O':(38,42,46),'D':(80,86,92),'M':(128,135,142),'L':(168,175,182),'H':(216,222,228),
    'B':(88,58,32),'b':(126,86,50),'X':(50,54,58),'G':(182,146,62)}
pc_item=grid(PC,9,9,[
"..Bb......bB..",
"..Bb......bB..",
".OGDOOOOOODGO.",
"ODMLLLHHLLMMDO",
"OMLLLLHHLLMMDO",
"OMLXLLHHLLMMDO",
"OMLLHLHHLLMMDO",
".OMLLLHHLLMDO.",
".OMLLLHHLMMDO.",
".OMMLLHHLXMDO.",
".ODMMLHHMMLDO.",
"..ODMMLLMMDO..",
".OLLLLLLLLLMO.",
"..OOOOOOOOOO.."])
pc_s=grid(PC,10,10,[
".Bb.....bB.",
".GDOOOOODG.",
"ODMLLHLLMDO",
"OMLLLHLLMDO",
"OMLXLHLLMDO",
"OMLLHHLLMDO",
".OMLLHLMDO.",
".OMLLHLXDO.",
".OMMLHLMDO.",
".ODMMHMDDO.",
"..OLLLLMO..",
"...OOOOO..."])
pc_n=grid(PC,10,10,[
".bB.....Bb.",
".BDOOOOODB.",
"ODMMMMMMMDO",
"OMLLLMMMMDO",
"OMLLMMMMMDO",
"OMLMMMMMMDO",
".OMMMMMMDO.",
".OBBbGbBBO.",
".OMMMMMMDO.",
".ODMMMMDDO.",
"..OMMMMDO..",
"...OOOOO..."])
pc_e=grid(PC,12,10,[
"..Bb.....",
".ODBOO...",
"ODMMLLO..",
"OMMDLLHO.",
"OMMDLLLHO",
"OMMBLLLHO",
"OMMDLXLHO",
".OMDLLLHO",
".OMDMLLO.",
".ODDMMDO.",
"..OMLLO..",
"...OOO..."])

# ---- proof do: dark lacquered okegawa-do, riveted lames, red cords
PD={'O':(14,14,16),'D':(28,29,32),'M':(42,44,48),'L':(68,71,76),'H':(112,116,122),
    'R':(132,136,142),'C':(142,36,32),'c':(196,74,52),'X':(6,6,7)}
pd_item=grid(PD,9,8,[
"..MM......MM..",
"..ML......LM..",
"..cC......Cc..",
".OMLOOOOOOLMO.",
"OLLLLLLLLLLLMO",
"ORMMMMMMMMMDRO",
"OLLLLLLLLLLLMO",
"ORMMMMMXHMMDRO",
"OLLLLLLLLLLLMO",
"ORMMMMMMMMMDRO",
".OLLLLLLLLLMO.",
".ORMMMMMMMDRO.",
".OLLLLLLLLLMO.",
".ORMMMMMMMDRO.",
".OCDcDCDcDCDO.",
"..OOOOOOOOOO.."])
pd_s=grid(PD,10,10,[
".ML.....LM.",
".cC.....Cc.",
"OLLLLLLLLMO",
"ORMMMMMMDRO",
"OLLLLLLLLMO",
"ORMMMXHMDRO",
".OLLLLLLMO.",
".ORMMMMDRO.",
".OLLLLLLMO.",
".ORMMMMDRO.",
".OCDcDCDcO.",
"..OOOOOOO.."])
pd_n=grid(PD,10,10,[
".LM.....ML.",
".Cc.....cC.",
"OLLLLLLLLMO",
"ORMMCMCMDRO",
"OLLLLcLLLMO",
"ORMMCMCMDRO",
".OLLLLLLMO.",
".ORMMMMDRO.",
".OLLLLLLMO.",
".ORMMMMDRO.",
".OcDCDcDCO.",
"..OOOOOOO.."])
pd_e=grid(PD,12,10,[
"..ML.....",
"..cC.....",
".OLLLLO..",
"OMMMMMRO.",
"OLLLLLLLO",
"OMMCMMMRO",
"OLLcLLLLO",
"OMMMMXHRO",
".OLLLLLO.",
".OMMMMRO.",
".OCDcDCO.",
"..OOOOO.."])

# ---- resin body shield: khaki quilted vest, amber resin stitching
RS={'O':(74,58,36),'k':(116,96,60),'K':(152,130,86),'J':(180,157,108),
    'A':(206,140,46),'a':(236,184,88),'S':(98,76,48),'s':(128,102,66)}
rs_item=grid(RS,9,9,[
"..Ss......sS..",
"..Ss......sS..",
".OJKO....OKKO.",
"OJKKKOOOOKKKkO",
"OJKAKKKAKKKAkO",
"OJKAKKKAKKKAkO",
"OkkakkkakkkakO",
"OJKAKKKAKKKAkO",
"OJKAKKKAKKKAkO",
"OkkakkkakkkakO",
"OJKAKKKAKKKAkO",
"OJKAKKKAKKKAkO",
".OkkkkkkkkkkO.",
"..OOOOOOOOOO.."])
rs_s=grid(RS,10,10,[
"..s.....s..",
"..S.....S..",
".OJKOOOKKO.",
"OJKAKKKAKkO",
"OkkakkkakkO",
"OJKAKKKAKkO",
".OJAKKKAkO.",
".OkakkkakO.",
".OJAKKKAkO.",
".OJAKKKAkO.",
"..OOOOOOO.."])
rs_n=grid(RS,10,10,[
"..s.....s..",
"..S.....S..",
".OJKKKKKKO.",
"OJKKKAKKKkO",
"OkkkkakkkkO",
"OJKKKAKKKkO",
".OJKKAKKkO.",
".OSSsSsSSO.",
".OJKKAKKkO.",
".OJKKAKKkO.",
"..OOOOOOO.."])
rs_e=grid(RS,12,10,[
"..s.....",
"..Ss....",
".OKKKO..",
"OkKAKJO.",
"OkkakkkO",
"OkKAKKJO",
"OkKAKKJO",
"OkkakkkO",
"OkKAKKJO",
".OKAKJO.",
"..OOOO.."])
SETS={'proof_cuirass':(pc_item,[pc_s,pc_n,pc_e,mir(pc_e)]),
      'proof_do':(pd_item,[pd_s,pd_n,pd_e,mir(pd_e)]),
      'resin_shield':(rs_item,[rs_s,rs_n,rs_e,mir(rs_e)])}

SETS = {'proof_cuirass': (pc_item, [pc_s, pc_n, pc_e, mir(pc_e)]),
        'proof_do': (pd_item, [pd_s, pd_n, pd_e, mir(pd_e)]),
        'resin_shield': (rs_item, [rs_s, rs_n, rs_e, mir(rs_e)])}
worn = lambda *names: [(n, SETS[n][1]) for n in names]
SHEETS = {'icons/obj/clothing/suits.dmi': [('proof_cuirass', [pc_item]), ('proof_do', [pd_item])],
          'icons/obj/clothing/ties.dmi': [('resin_shield', [rs_item])],
          'icons/mob/suit.dmi': worn('proof_cuirass', 'proof_do', 'resin_shield'),
          'icons/mob/ties.dmi': worn('resin_shield')}


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def read(path):
    data = path.read_bytes()
    offset = 8
    while offset < len(data):
        size, kind = struct.unpack('>I4s', data[offset:offset + 8])
        body = data[offset + 8:offset + 8 + size]
        offset += size + 12
        if kind == b'zTXt' and body.startswith(b'Description\0\0'):
            text = zlib.decompress(body[13:]).decode()
    states, first = {}, 0
    for part in re.split(r'^state\s*=\s*', text, flags=re.M)[1:]:
        dirs = int(re.search(r'\bdirs\s*=\s*(\d+)', part)[1])
        frames = int(re.search(r'\bframes\s*=\s*(\d+)', part)[1])
        states[re.match(r'"(.*)"', part)[1]] = (first, dirs * frames)
        first += dirs * frames
    return text, states, first, Image.open(path).convert('RGBA')


def cell(sheet, n):
    cols = sheet.width // 32
    return ((n % cols) * 32, (n // cols) * 32, (n % cols + 1) * 32, (n // cols + 1) * 32)


def build(path, additions, check):
    text, states, used, sheet = read(path)
    end = text.rindex('# END DMI')
    head, foot = text[:end], text[end:]
    for name, frames in additions:
        if name not in states:
            if check:
                raise SystemExit(f'FAIL: {path} has no state {name}')
            if used + len(frames) > (sheet.width // 32) * (sheet.height // 32):
                raise SystemExit(f'{path} is full; grow the sheet first')
            states[name] = (used, len(frames))
            head += f'state = "{name}"\n\tdirs = {len(frames)}\n\tframes = 1\n'
            used += len(frames)
        first, count = states[name]
        if count != len(frames):
            raise SystemExit(f'FAIL: {path} state {name} has {count} frames, expected {len(frames)}')
        for n, frame in enumerate(frames, first):
            if check:
                if sheet.crop(cell(sheet, n)).tobytes() != frame.tobytes():
                    raise SystemExit(f'FAIL: {path} state {name} differs from this script')
            else:
                sheet.paste(frame, cell(sheet, n)[:2])
    if check:
        return
    # the layout these sheets already use: IHDR, zTXt, one IDAT of unfiltered rows, IEND
    px, width = sheet.tobytes(), sheet.width * 4
    raw = b''.join(b'\0' + px[y * width:(y + 1) * width] for y in range(sheet.height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'
                     + chunk(b'IHDR', struct.pack('>IIBBBBB', sheet.width, sheet.height, 8, 6, 0, 0, 0))
                     + chunk(b'zTXt', b'Description\0\0' + zlib.compress((head + foot).encode(), 9))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def preview(target):
    _, states, _, human = read(ROOT / 'icons/mob/human_races/r_human.dmi')
    parts = [f'{p}_m' for p in ('torso', 'groin', 'head', 'r_arm', 'l_arm', 'r_leg', 'l_leg', 'r_hand', 'l_hand',
                                'r_foot', 'l_foot')]
    scale = 8
    out = Image.new('RGBA', (9 * 34 * scale, len(SETS) * 34 * scale), (96, 112, 100, 255))
    for row, (item, dirs) in enumerate(SETS.values()):
        cells = [item] + dirs
        for k in range(4):
            body = Image.new('RGBA', (32, 32))
            for part in parts:
                body.alpha_composite(human.crop(cell(human, states[part][0] + k)))
            body.alpha_composite(dirs[k])
            cells.append(body)
        for col, im in enumerate(cells):
            out.alpha_composite(im.resize((32 * scale, 32 * scale), Image.NEAREST),
                                ((col * 34 + 1) * scale, (row * 34 + 1) * scale))
    out.save(target)


if __name__ == '__main__':
    check = '--check' in sys.argv
    for rel, additions in SHEETS.items():
        build(ROOT / rel, additions, check)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    print('PASS: gun armor states match this script' if check else 'wrote ' + ', '.join(SHEETS))
