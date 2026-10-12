"""Source-derived tile plan. This is explicitly not a BYOND/game screenshot."""
import argparse
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont
from test_mall import parse

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'data/mall-design/interchange-mall-plan.png')
    args = parser.parse_args()
    layers = parse((ROOT / 'maps/extraction/interchange_mall.dmm').read_text(encoding='utf-8'))
    size = len(layers[1])
    scale = max(1, 512 // size)
    side, margin, top = size * scale, 24, 85
    image = Image.new('RGB', (side*3+margin*4, side+top+120), '#10151c')
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=14)
    small = ImageFont.load_default(size=11)
    draw.text((margin, 14), 'INTERCHANGE MALL - original Civ13 layout', fill='white', font=font)
    draw.text((margin, 38), f'Source tile plan | {size} x {size} | not a game render | homes z2 / hub z3 omitted', fill='#c3ccd7', font=font)
    colors = {'wall': '#38404b', 'concrete': '#a6acaf', 'dark': '#647380', 'wood': '#b79a70', 'table': '#795138', 'chair': '#8c6550'}
    markers = [('extraction_raid_marker/road', '#4ac9fa'), ('extraction_raid_marker', '#56e2ba'), ('extraction_exit/highway', '#ffd361'), ('extraction_exit', '#e5a0ff'), ('extraction_mall_stairs', '#ffffff'), ('extraction_loot_marker', '#e1654c')]
    for index, z in enumerate((1, 4, 5)):
        left = margin + index*(side+margin)
        draw.text((left, 63), {1: 'z1 Parking / highways', 4: 'z4 Retail / anchor stores', 5: 'z5 Upper gallery'}[z], fill='white', font=font)
        labels = []
        for y, row in enumerate(layers[z]):
            for x, value in enumerate(row):
                color = colors['concrete']
                if '/plating/dark' in value: color = colors['dark']
                if '/floor/wood' in value: color = colors['wood']
                if '/obj/covers/generic_wall' in value: color = colors['wall']
                if '/obj/structure/table' in value: color = colors['table']
                if '/obj/structure/bed/chair' in value: color = colors['chair']
                if '/floor/wood_broken' in value or '/floor/gravel/dust' in value: color = '#776d61'
                if '/extraction_mall_rubble' in value or '/decal/rubbish' in value: color = '#665d4f'
                if '/obj/structure/props/car_wreck' in value: color = '#503c33'
                xx, yy = left+x*scale, top+(size-1-y)*scale
                draw.rectangle((xx, yy, xx+scale-1, yy+scale-1), fill=color)
                for token, marker_color in markers:
                    if token in value:
                        draw.rectangle((xx-2, yy-2, xx+3, yy+3), fill=marker_color)
                        break
                if '/extraction_mall_sign' in value:
                    labels.append((xx, yy, re.search(r'name = "([^"]+)"', value)[1]))
        for xx, yy, label in labels:
            box = draw.textbbox((xx, yy), label, font=small)
            width = box[2]-box[0]
            label_x = min(left+side-width-2, max(left+2, xx-width//2))
            draw.rectangle((label_x-1, yy-6, label_x+width+1, yy+8), fill='#10151c')
            draw.text((label_x, yy-5), label, font=small, fill='white')
    y = top+side+18
    draw.text((margin, y), 'Cyan: road infil | Green: foot infil | Gold: highway exfil | Purple: foot exfil | White: stairs | Red: sealed loot', fill='white', font=font)
    draw.text((margin, y+25), 'Parking connects six stair cores; retail/gallery routes are pedestrian-only. Vehicle routes remain on z1.', fill='#c3ccd7', font=font)
    draw.text((margin, y+50), 'Topology verified separately. Runtime appearance, player readability and driving acceptance remain independent.', fill='#c3ccd7', font=font)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(args.output)


if __name__ == '__main__':
    main()
