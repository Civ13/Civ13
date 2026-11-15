"""Original hand-placed 32px art for the gem-science items.

Every pixel comes from the fixed palettes and the character stamps in this
file; there is no external, traced or generated artwork. The ruby and garnet
ramps are the ones used by icons/obj/pocket_stronghold_gems.dmi and
icons/obj/gemstones.dmi so the new stones sit next to them. Top-left lighting,
no black outline. Released under Civ13's AGPL-3.0 licence. Run with Pillow
from the repository root:

    python3 tests/sprites/create_gem_science.py [--preview sheet.png]

It writes icons/obj/gem_science.dmi (all states 32x32, one direction, one
frame), in this order: jewel_bearing, jewel_bearing_garnet, diamond_grit,
diamond_drill_bit, lapping_wheel, quartz_uncut, quartz, galena, crystal_radio,
quartz_crystal_unit, quartz_watch, emery_powder, garnet_paper,
rock_crystal_lens, jewel_lens, ruby_boule, ruby_rod, loupe, gem_scale,
refractometer.

To change the look, edit this script and rerun it; do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_belt_pouches import write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'icons/obj/gem_science.dmi'
S = 32

# Seven-step ramps, lightest first (stamp digits 0-6).
RAMPS = {
    'ruby': ('#ffcfd2', '#f68187', '#f5555d', '#ea323c', '#c42430', '#891e2b', '#571c27'),
    'garnet': ('#f7b9bd', '#d95f70', '#ad2742', '#861532', '#640d29', '#430820', '#290517'),
    'pink': ('#ffe3ea', '#ffb3c4', '#f97f9c', '#e85079', '#c22f5d', '#8f1f47', '#5c1433'),
    'grit': ('#ffffff', '#e6ecf0', '#c4ccd4', '#9fa8b2', '#7a838d', '#585f69', '#3d434b'),
    'emery': ('#8e9096', '#6f7177', '#55575d', '#404248', '#2e3035', '#1f2024', '#141417'),
    'cloudy': ('#ffffff', '#e9f1f5', '#cddbe4', '#a9bccb', '#8399ab', '#5f7488', '#435466'),
    'clear': ('#ffffff', '#e8f3f9', '#c9dde9', '#a3bfd1', '#7b9bb1', '#56758c', '#3a5368'),
    'lead': ('#f4f6f8', '#cfd5db', '#a4acb6', '#7a838e', '#565e69', '#3a4049', '#23272e'),
    'sand': ('#d98a66', '#b9603f', '#9a4830', '#7c3525', '#5c261b', '#3f1a13', '#2a110d'),
}

# Fixed materials (stamp letters).
KEY = {
    # steel
    'S': '#eef1f4', 's': '#b9bfc7', 't': '#8a919b', 'u': '#5c636d', 'v': '#363b43',
    # cast iron
    'I': '#8b9097', 'i': '#63676e', 'j': '#3f4248', 'O': '#2a2c31',
    # brass
    'B': '#ffe89a', 'b': '#e0b84a', 'n': '#b08628', 'm': '#7a5a18', 'M': '#4c3810',
    # copper wire
    'C': '#f2a878', 'c': '#c6703e', 'k': '#8a4622',
    # wood
    'W': '#c99a62', 'w': '#a37443', 'x': '#7a5230', 'y': '#55371f', 'z': '#38230f',
    # paper / card
    'P': '#f4eedc', 'p': '#d8cfb4', 'o': '#b0a584',
    # glass and rock crystal
    'G': '#f8fdff', 'g': '#d3e6f0', 'h': '#a6c1d1', 'H': '#7493a8', 'l': '#4d677b',
    # black rubber / leather / bakelite
    'X': '#4a4c53', 'Y': '#2c2d32', 'Z': '#151519',
    # grey host rock
    'E': '#a1a2a6', 'F': '#7c7d82', 'J': '#56565b', 'L': '#37373b',
    # water
    'a': '#9fd6f2', 'A': '#5a9fcd',
    # diamond studs and glints
    'D': '#ebfeff', 'd': '#94fdff',
    # liquid-crystal display and its digits
    'Q': '#b7c6a4', 'q': '#2f3a2b',
}

# One drilled watch jewel: a tiny disc with a dark oil hole.
JEWEL = (
    '.0112.',
    '012234',
    '12ZZ35',
    '12ZZ45',
    '234455',
    '.4556.',
)
JEWELS = ((8, 9, JEWEL), (17, 11, JEWEL), (11, 17, JEWEL), (20, 19, JEWEL[1:5]))

# name: (ramp, ((left, top, rows), ...)). '.' is transparent; later parts
# draw over earlier ones.
STAMPS = {
    'jewel_bearing': ('ruby', JEWELS),
    'jewel_bearing_garnet': ('garnet', JEWELS),
    # Glittering heap on a creased scrap of paper.
    'diamond_grit': ('grit', ((5, 9, (
        '..........0...d.......',
        '.........0121.........',
        '........012123........',
        '.......01d12234.......',
        '......0121223344......',
        '...PPP12d1223d445PPP..',
        '..PPP0122122334345PPP.',
        '.PPPP12212d3334445pPPo',
        'PPPPPP334444555ppPPPpo',
        '.PPPPPPppppppppPPPPpo.',
        '..pPPPPPPPPPPPPPPppo..',
        '...oppPPPPPPPpppooo...',
        '.....oooopppooo.......',
    )),)),
    # Core bit: hollow crown end up, studs round the rim, plain shank below.
    'diamond_drill_bit': (None, ((10, 4, (
        '..sdsdsdsd..',
        '.dvZZZZZZvs.',
        'svZZZZZZZZvd',
        'dsvZZZZZZvsu',
        'SdDsdDsdDstu',
        'Sddsddsddtuu',
        'SSssssttttuu',
        'SSssssttttuu',
        'SSsvsstvttuu',
        'SSsvsstvttuu',
        'SSsvsstvttuu',
        'SSssssttttuu',
        'SSssssttttuu',
        '.Ssssstttuu.',
        '..Sssstttu..',
        '...Ssstuu...',
        '...Ssstuu...',
        '...Ssstuu...',
        '...Ssstuu...',
        '...Ssstuu...',
        '...Ssstuu...',
        '...Ssstuu...',
        '...uuuuvv...',
    )),)),
    # Flat iron lap on a wooden bench stand, hand crank on the right.
    'lapping_wheel': (None, ((2, 5, (
        '.........IIIIIIIIII.........',
        '.....IIIIIssssssssiiii......',
        '...IIIssssssssssssssiiii....',
        '..IIsssSSsssssssssssssiii...',
        '.IIssSSssssstuussssssssiij..',
        '.IissssssssstuusssssssiiijO.',
        '.jiiissssssssssssssssiiijjO.',
        '.Ojjiiiiissssssssiiiiijjjj..',
        '..OOjjjjiiiiiiiiiijjjjjOO...',
        '....OOOOjjjjjjjjjjjOOOO.....',
        '........OOOuuuuOOOO.........',
        '...........tuuv.............',
        '....WWWWWWWWWWWWWWWWWW......',
        '....WwwwwwwwwwwwwwwwwxtttS..',
        '....WwwwwwwwwwwwwwwwwxuuutS.',
        '....xxxxxxxxxxxxxxxxxy...ts.',
        '....Wwx...........Wwxy...ts.',
        '....Wwx...........Wwxy...ts.',
        '....Wwx...........Wwxy..WWwx',
        '....Wwx...........Wwxy..Wwxy',
        '..WWWWWWWWWWWWWWWWWWWWWW.xy.',
        '..WwwwwwwwwwwwwwwwwwwwwX....',
        '..xxxxxxxxxxxxxxxxxxxxxy....',
        '..yyyyyyyyyyyyyyyyyyyyyy....',
    )),)),
    # Rough six-sided point and a stub in grey host rock.
    'quartz_uncut': ('cloudy', ((8, 6, (
        '.......1........',
        '......0124......',
        '.....001234.....',
        '....0011234.....',
        '....1223456.....',
        '....0122345.....',
        '....0122345.....',
        '....0122345.1...',
        '....01223450124.',
        '....012134501235',
        '...E012234511235',
        '..EF012134501245',
        '.EFF0122345F1235',
        'EFFJ0122345FJ245',
        'FFJJJ12345JJJJ45',
        '.JJJLLJJLLLLJJL.',
        '...LLLLLLLLLL...',
    )),)),
    # Cut and polished: three visible prism faces under a pyramid tip.
    'quartz': ('clear', ((11, 4, (
        '....01....',
        '...0013...',
        '...01134..',
        '..0011345.',
        '..0012345.',
        '.001123455',
        '.011223455',
        '0000233456',
        '0101233456',
        '0011233456',
        '0101233456',
        '0110233456',
        '0111233456',
        '0111233456',
        '0111233456',
        '0111233456',
        '0111233456',
        '0111233456',
        '0111233456',
        '0112233456',
        '.11223345.',
        '.12234456.',
        '..234456..',
        '...3456...',
    )),)),
    # Intergrown metallic cubes with stepped cleavage.
    'galena': ('lead', (
        (15, 7, (
            '..00000002',
            '.000000134',
            '1111111345',
            '2222222345',
            '2222222345',
            '2222222345',
            '2222222345',
            '2222222345',
            '3333333455',
        )),
        (7, 11, (
            '..0000000002',
            '.00000000134',
            '111111111345',
            '222222222345',
            '220222222345',
            '222222222345',
            '222222222345',
            '222222122345',
            '222222222345',
            '222222222345',
            '333333333456',
            '.4444444456.',
        )),
        (17, 17, (
            '..000002',
            '.0000134',
            '11111345',
            '22222345',
            '22222345',
            '22222345',
            '33333456',
        )),
        (5, 20, (
            '..0002',
            '.00134',
            '111345',
            '222345',
            '333456',
        )),
    )),
    # Board, wound coil on a card former, crystal cup with cat's whisker,
    # earphone on its cord.
    'crystal_radio': (None, ((1, 5, (
        '.....pCcCcCcCcCp..............',
        '....PPCcCcCcCcCPp......ss.....',
        '....PpcCcCcCcCcpo.....s..s....',
        '....PpCcCcCcCcCpo....s...s....',
        '....PpckckckckcpoS...s...D....',
        '....Ppkckckckckpot...s..GdG...',
        '..WWPpkkkkkkkkkpoWWWWsWBbbbnWW',
        '.WWWWoooooooooooWWWWWBWWnnnWWW',
        'WWWWWWWWWWWWWWWWWWWWWnWWWWWWWx',
        'WwwwwwwwwwwwwwwwwwwwwwwwwwwwwX',
        'WwwBnwwwwwwwwwwwwwwwwwwwBnwwxy',
        'wwwnmwwwwwwwwwwwwwwwwwwwnYwwxy',
        'xxxxxxxxxxxxxxxxxxxxxxxxxYxxxy',
        'yyyyyyyyyyyyyyyyyyyyyyyyyYyyyz',
        '.........................Y....',
        '....................XXXX.Y....',
        '...................XYYYYXY....',
        '..................XYYXXYYY....',
        '..................XYXZZXYZ....',
        '..................XYXZZXYZ....',
        '..................XYYXXYYZ....',
        '...................YYYYYZ.....',
        '....................ZZZZ......',
    )),)),
    # Plated can with a paper label and two plug pins.
    'quartz_crystal_unit': (None, ((10, 6, (
        '.SSSSSSSSSS.',
        'SSsssssssstu',
        'Sssssssssstu',
        'SsPPPPPPPstu',
        'SsPoPooPPstu',
        'SsPPPPPPPstu',
        'SsPooPoPpstu',
        'SsPPPPPppstu',
        'Sssssssssttu',
        'Sssssssssttu',
        'Sssssssstttu',
        'Sssssstttttu',
        'stttttttttuv',
        '.uuuuuuuuvv.',
        '...St..St...',
        '...st..st...',
        '...st..st...',
        '...st..st...',
        '...tu..tu...',
    )),)),
    # Square steel case, grey-green display, black strap with buckle.
    'quartz_watch': (None, ((10, 2, (
        '...SssssS....',
        '...sXXXXt....',
        '...XYYYYZ....',
        '...XYYZYZ....',
        '...XYYYYZ....',
        '...XYYZYZ....',
        '...XYYYYZ....',
        '..XXYYYYZZ...',
        '.SSSSSSSSSt..',
        'SSsssssssstu.',
        'SsvvvvvvvvtuS',
        'SsvQQQQQQvtut',
        'SsvqQqQqqvtu.',
        'SsvqQqQQqvtu.',
        'SsvqQqQqqvtut',
        'SsvQQQQQQvtuu',
        'Ssvvvvvvvvtu.',
        'Sssstttttttu.',
        '.tuuuuuuuuv..',
        '..XXYYYYZZ...',
        '...XYYYYZ....',
        '...XYYYYZ....',
        '...XYYYYZ....',
        '...XYYYYZ....',
        '...XYYYYZ....',
        '...XYYYYZ....',
        '...XYYYYZ....',
        '....YYYZ.....',
    )),)),
    # Plain dark heap with a few stray grains.
    'emery_powder': ('emery', ((7, 11, (
        '........01........',
        '.......0112.......',
        '......011223......',
        '.....01212234.....',
        '....0112223344....',
        '...011212233445...',
        '..01122232334455..',
        '.0112223233444555.',
        '011222333334445556',
        '.3344444455555566.',
        '...4.5566665.5....',
        '.3...........4..5.',
    )),)),
    # Gritty sheet, one corner curled to show the paper backing.
    'garnet_paper': ('sand', ((6, 7, (
        '...00000000000000000',
        '..011212112121121123',
        '..012112121211212123',
        '..011211212112112123',
        '.0121212112121211223',
        '.0112112121121212123',
        '.0121211211212112123',
        '.0112121212112121223',
        '.011211212121121123.',
        '0121212112112121223.',
        '011211212121211PPp3.',
        '0121212121121PPPPpo.',
        '01121121212PPPPPpo..',
        '012121211213PPPpo...',
        '.3333333333opppo....',
        '...........ooo......',
    )),)),
    # Reading stone: flat-bottomed dome with a bright window highlight.
    'rock_crystal_lens': (None, ((8, 10, (
        '.....gggggg.....',
        '...ggGGGGgggg...',
        '..gGGGGGggggghh.',
        '.gGGGGgggggghhhh',
        '.gGGGgggggghhhhH',
        'gGGggggggghhhhhH',
        'gGggggggghhhhhHH',
        'ggggggghhhhhhHHH',
        'hggghhhhhhhhHHHl',
        'hhhhhhhhhhHHHHHl',
        '.HHhhhhhGGhHHHl.',
        '..lHHHHHHHHHll..',
        '....llllllll....',
    )),)),
    # Tiny lens in the top of a short knurled brass cell.
    'jewel_lens': (None, ((10, 8, (
        '...BBBBBB...',
        '.BBbGGgbbbn.',
        'BBbGGggghbbn',
        'BbbgggghHbnm',
        'BBbbhhHHbnnm',
        'BbBbbbbbnnmm',
        'BbbbbbbnnnmM',
        'BnbnbnbnmnmM',
        'BnbnbnbnmnmM',
        'BbbbbbbnnnmM',
        'nbbbbbnnnmmM',
        '.mmmmmmmmMM.',
        '..Bbbbnnnm..',
        '..BbbnnnmM..',
        '..Bbbbnnnm..',
        '..BbbnnnmM..',
        '..mmmmmMMM..',
    )),)),
    # Flame-fusion boule: rounded crown tapering to the seed stalk.
    'ruby_boule': ('pink', ((11, 4, (
        '...01122..',
        '..0011223.',
        '.001122334',
        '.011122334',
        '0011223345',
        '0101223345',
        '0101223345',
        '0111223345',
        '0111223345',
        '.111223345',
        '.11223345.',
        '.11223345.',
        '..1223345.',
        '..122345..',
        '..123345..',
        '...23345..',
        '...2345...',
        '...2345...',
        '....345...',
        '....345...',
        '....35....',
        '....45....',
        '....45....',
        '....5.....',
    )),)),
    # Laser rod: polished pink cylinder, silvered at both ends.
    'ruby_rod': ('pink', ((4, 12, (
        '.S1111111111111111111SS.',
        'SS0000000000011111111sSS',
        'Ss1100111111111111112sSS',
        'ss2222222222222222223tsS',
        'st3333333333333333334tss',
        'tu4444444444444444445uts',
        'tu5555555555555555555utt',
        '.v6666666666666666666vu.',
    )),)),
    # Folding loupe: lens ring swung out of its teardrop brass cover.
    'loupe': (None, ((5, 6, (
        '...........BBBBBB.....',
        '.........BBbbbbbbbb...',
        '........BbbgGGgghbbn..',
        '.......BbgGGGggggghbn.',
        '.......BbGGGggggggHbn.',
        '......BbgGGggggggghHbn',
        '......BbgGgggggggghHbn',
        '......BbggggggggghhHbn',
        '......BbggggggggghhHnm',
        '.......bhgggggghhhHnm.',
        '......BbnhhhhhhhHHnnm.',
        '....BBbbbnHHHHHHnnmm..',
        '...BbbbbSsnnnnnnmm....',
        '..BbbbbbstnnmmMM......',
        '.BbbbbbbbbnnM.........',
        'BBbbbbbbbbnm..........',
        'BbbbbbbbbnnM..........',
        'BbbbbbbbbnmM..........',
        'nbbbbbbbnnm...........',
        '.nbbbbnnnmM...........',
        '..mnnnnmmM............',
        '....mmMM..............',
    )),)),
    # Hydrostatic balance: beam, two hung pans, a water cup under the left one.
    'gem_scale': (None, ((1, 3, (
        '..............BB...............',
        '..............Bn...............',
        '...BBbbbbbbbbbBnbbbbbbbbbbnnn..',
        '...n..........Bn...........n...',
        '..n.n.........bn..........n.n..',
        '..n.n.........bn..........n.n..',
        '.n...n........bn.........n...n.',
        '.n...n........bn.........n...n.',
        'n.....n.......bn........n.....n',
        'BbbbbbbB......bn.......BbbbbbbB',
        '.nbbbnm.......bn........nbbbnm.',
        '..mmmm........bn.........mmmm..',
        '...u..........bn...............',
        '...u..........bn...............',
        '..GuG.........bn...............',
        'g.....g.......bn...............',
        'gaaaaag.......bn...............',
        'gaAGAah.......bn...............',
        'gaAAAah.......bn...............',
        'gaAAAah......BbnM..............',
        'haAAAah...BBBBbbnnnnn..........',
        '.hhhhH...BbbbbbbbbbbnnM........',
        '.........nnnnnnnnnnnmmM........',
        '.........MMMMMMMMMMMMMM........',
    )),)),
    # Brass box, glass prism window on top, angled eyepiece with eyecup.
    'refractometer': (None, ((4, 5, (
        '...................XX...',
        '..................XYYX..',
        '.................XYYZYY.',
        '.................BXYYYZ.',
        '................BbbXYZ..',
        '....BBBBBBBBBB.Bbbnm....',
        '...BBBllllllBBBbbnm.....',
        '..BBBlGGggghlBBBnm......',
        '.BBBlGGggghhlBBBBB......',
        'BBBBllllllllBBBBBn......',
        'BBBBBBBBBBBBBBBBnnm.....',
        'bbbbbbbbbbbbbbbnnnm.....',
        'bbbbbbbbbbbbbbbnnnm.....',
        'bbPPPPPbbbbbSbbnnmm.....',
        'bbPoPoPbbbbsttbnnmm.....',
        'bbPPPPPbbbbbtbbnnmm.....',
        'bbbbbbbbbbbbbbbnnmm.....',
        'bbbbbbbbbbbbbbbnnmm.....',
        'bbbbbbbbbbbbbbbnnm......',
        'nnnnnnnnnnnnnnnmmm......',
        'MMMMMMMMMMMMMMMMM.......',
    )),)),
}

ORDER = (
    'jewel_bearing', 'jewel_bearing_garnet', 'diamond_grit', 'diamond_drill_bit',
    'lapping_wheel', 'quartz_uncut', 'quartz', 'galena', 'crystal_radio',
    'quartz_crystal_unit', 'quartz_watch', 'emery_powder', 'garnet_paper',
    'rock_crystal_lens', 'jewel_lens', 'ruby_boule', 'ruby_rod', 'loupe',
    'gem_scale', 'refractometer',
)
SLOT = (139, 139, 139, 255)


def rgba(c):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def draw(name):
    ramp, parts = STAMPS[name]
    img = Image.new('RGBA', (S, S))
    for left, top, rows in parts:
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == '.':
                    continue
                img.putpixel((left + x, top + y),
                             rgba(RAMPS[ramp][int(ch)] if ch.isdigit() else KEY[ch]))
    return img


def preview(states, out, scale=4, cols=5):
    """Each state at 4x on a grey slot, its name, then the same icon at 1x."""
    cell, label, gap = S * scale, 14, 6
    pitch = cell + label + S + gap
    rows = (len(states) + cols - 1) // cols
    img = Image.new('RGBA', (cols * (cell + gap) + gap, rows * pitch + gap), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for i, (name, tile) in enumerate(states.items()):
        x, y = gap + (i % cols) * (cell + gap), gap + (i // cols) * pitch
        d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=SLOT)
        img.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (x, y))
        d.text((x + 2, y + cell + 1), name, fill=(235, 235, 235, 255))
        d.rectangle((x + cell - S, y + cell + label, x + cell - 1, y + cell + label + S - 1), fill=SLOT)
        img.alpha_composite(tile, (x + cell - S, y + cell + label))
    img.save(out)


def main(argv):
    states = {name: draw(name) for name in ORDER}
    write_dmi(OUT, states, 1)
    print('wrote', OUT.relative_to(ROOT), 'with', len(states), 'states')
    if '--preview' in argv:
        preview(states, argv[argv.index('--preview') + 1])


if __name__ == '__main__':
    main(sys.argv[1:])
