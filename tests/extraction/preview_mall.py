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
    parser.add_argument('--floor', type=int, choices=(1, 4, 5), help='One floor at twice the overview resolution')
    args = parser.parse_args()
    layers = parse((ROOT / 'maps/extraction/interchange_mall.dmm').read_text(encoding='utf-8'))
    size = len(layers[1])
    floors = (args.floor,) if args.floor else (1, 4, 5)
    scale = max(1, (1024 if args.floor else 512) // size)
    side, margin, top = size * scale, 24, 85
    image = Image.new('RGB', (side*len(floors)+margin*(len(floors)+1), side+top+380), '#10151c')
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=14)
    small = ImageFont.load_default(size=11)
    draw.text((margin, 14), 'INTERCHANGE MALL - original Civ13 layout', fill='white', font=font)
    draw.text((margin, 38), f'SOURCE TILE PLAN | {size} x {size} | not a game render | homes z2 / hub z3 omitted', fill='#c3ccd7', font=font)
    colors = {'wall': '#38404b', 'concrete': '#a6acaf', 'dark': '#647380', 'wood': '#b79a70', 'table': '#795138', 'chair': '#8c6550'}
    markers = [('extraction_raid_marker/road', '#4ac9fa'), ('extraction_raid_marker', '#56e2ba'), ('extraction_exit/highway', '#ffd361'), ('extraction_exit', '#e5a0ff'), ('extraction_mall_stairs', '#ffffff'), ('extraction_loot_marker', '#e1654c')]
    for index, z in enumerate(floors):
        left = margin + index*(side+margin)
        draw.text((left, 63), {1: 'z1 Parking / highways', 4: 'z4 Retail / anchor stores', 5: 'z5 Upper gallery'}[z], fill='white', font=font)
        labels, objects = [], []
        for y, row in enumerate(layers[z]):
            for x, value in enumerate(row):
                color = colors['concrete']
                if '/plating/dark' in value: color = colors['dark']
                if '/floor/wood' in value: color = colors['wood']
                if '/obj/covers/generic_wall' in value: color = colors['wall']
                if '/obj/structure/table' in value: color = colors['table']
                if '/obj/structure/bed/chair' in value: color = colors['chair']
                if '/obj/structure/bed/' in value: color = '#6f7867'
                if '/obj/structure/closet' in value or '/obj/structure/oven' in value: color = '#555b63'
                if '/obj/structure/sink' in value or '/obj/structure/toilet' in value: color = '#e1dcd2'
                if '/road/whiteline' in value or '/plating/white' in value: color = '#d3d7cf'
                if '/floor/wood_broken' in value or '/floor/gravel/dust' in value: color = '#776d61'
                if '/extraction_mall_rubble' in value or '/decal/rubbish' in value: color = '#665d4f'
                if '/obj/structure/props/car_wreck' in value: color = '#503c33'
                xx, yy = left+x*scale, top+(size-1-y)*scale
                draw.rectangle((xx, yy, xx+scale-1, yy+scale-1), fill=color)
                if '/obj/structure/props/car_wreck' in value:
                    objects.append((xx, yy-scale, xx+3*scale-1, yy+scale-1, '#503c33'))
                for token, marker_color in markers:
                    if token in value:
                        objects.append((xx-2, yy-2, xx+3, yy+3, marker_color))
                        break
                if '/extraction_mall_sign' in value:
                    label = re.search(r'name = "([^"]+)"', value)[1]
                    internal = ('Display suite', 'Design consultation', 'Furniture receiving',
                                'Tool repair', 'Hardware stockroom', 'Reserved hardware',
                                'Bakery preparation', 'Cold storage', 'Receiving', 'Staff lockers',
                                'Accounts office', 'Fitting rooms', 'Central concourse',
                                'Shared food court', 'West public', 'East public', 'Parking row')
                    if not label.startswith(internal):
                        labels.append((xx, yy, label))
        for x1, y1, x2, y2, color in objects:
            draw.rectangle((x1, y1, x2, y2), fill=color)
        # Only compact location badges overlay geometry. The numbered directory
        # stays outside the floorplan, without hiding walls, aisles or furniture.
        labels.sort(key=lambda item: (item[1], item[0]))
        rows = (len(labels)+1)//2
        for i, (xx, yy, label) in enumerate(labels):
            number = str(i+1)
            width = draw.textbbox((0, 0), number, font=small)[2]+6
            draw.rectangle((xx-width//2, yy-7, xx+width//2, yy+7), fill='#10151c', outline='#bdcbd4')
            draw.text((xx-width//2+3, yy-6), number, font=small, fill='white')
            column, row = divmod(i, rows)
            label = label.replace(' - cubicles and wash counter', '').replace(' - receiving and service stairs', '')
            draw.text((left+column*(side//2), top+side+18+row*20), f'{number}. {label}', fill='#e0e8ed', font=small)
    y = top+side+280
    draw.text((margin, y), 'Cyan: road infil | Green: foot infil | Gold: highway exfil | Purple: foot exfil | White: stairs | Red: sealed loot', fill='white', font=font)
    draw.text((margin, y+25), 'Parking connects six stair cores; retail/gallery routes are pedestrian-only. Vehicle routes remain on z1.', fill='#c3ccd7', font=font)
    draw.text((margin, y+50), 'Topology verified separately. Runtime appearance, player readability and driving acceptance remain independent.', fill='#c3ccd7', font=font)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(args.output)


if __name__ == '__main__':
    main()
