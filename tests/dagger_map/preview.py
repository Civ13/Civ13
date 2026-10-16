"""Render a static source diagram, never gameplay or a BYOND sprite preview."""
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_map import ROOT, WIDTH, LENGTH, PALETTE, build, train

OUTPUT = ROOT / "docs/images/dagger-train-map-preview.png"
BG, PANEL, TEXT, MUTED = "#101b24", "#192934", "#edf4f4", "#9eb1bc"
TEAL, AMBER = "#57c9ba", "#e9b85d"


def font(size, bold=False):
    path = Path("C:/Windows/Fonts") / ("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path), size)


def main():
    grid, layout = build()
    im = Image.new("RGB", (1720, 1550), BG)
    d = ImageDraw.Draw(im)

    def text(x, y, value, size=21, color=TEXT, bold=False):
        d.text((x, y), value, font=font(size, bold), fill=color)

    def line(points, color=MUTED, width=2):
        d.line(points, fill=color, width=width)

    def card(box):
        d.rounded_rectangle(box, radius=20, fill=PANEL)

    text(64, 32, "DAGGER / MAP STUDY 01", 19, TEAL, True)
    text(64, 65, "Dagger train home - first draft", 46, bold=True)
    text(64, 126, "Static source diagram  |  North up  |  Original prototype geometry", 22, MUTED)
    card((48, 184, 1010, 1402))
    card((1032, 184, 1672, 731))
    card((1032, 755, 1672, 1402))
    text(78, 205, "01  THE TRAIN", 24, bold=True)
    text(78, 243, "15 x 51 tiles", 22, MUTED)

    ox, oy, c = 282, 219, 22

    def cellbox(x, y):
        px, py = ox + x*c, oy + (LENGTH-1-y)*c
        return px, py, px+c-1, py+c-1

    furniture = {"bed", "crate", "rack", "table", "chair", "anvil", "sink", "toilet"}
    for (x, y), kind in train().items():
        box = cellbox(x, y)
        base = "#264d4d" if y <= 20 else "#695334"
        if kind == "hull":
            base = "#667c87"
        elif kind in ("door", "gate"):
            base = "#f4ce77"
        d.rectangle(box, fill=base, outline="#243742")
        a, b, e, f = box
        if kind in furniture:
            color = "#d8e5df" if y <= 20 else "#f4d7a5"
            if kind == "bed":
                d.rounded_rectangle((a+4,b+3,e-4,f-3), radius=2, outline=color, width=2)
                line([(a+5,b+8),(e-5,b+8)], color)
            elif kind == "crate":
                d.rectangle((a+4,b+4,e-4,f-4), outline=color, width=2)
                line([(a+5,b+5),(e-5,f-5)], color)
                line([(a+5,f-5),(e-5,b+5)], color)
            elif kind == "rack":
                for dy in (5,10,15):
                    line([(a+4,b+dy),(e-4,b+dy)], color)
            elif kind == "chair":
                d.arc((a+4,b+4,e-4,f-4),0,300,fill=color,width=3)
            elif kind == "table":
                d.rectangle((a+4,b+4,e-4,f-4), fill=color)
            else:
                symbol = {"anvil":"A", "sink":"S", "toilet":"T"}[kind]
                text(a+5,b-1,symbol,15,color,True)
        elif kind == "dirt":
            for dx,dy in ((5,7),(12,12),(7,16)):
                d.ellipse((a+dx,b+dy,a+dx+2,b+dy+2),fill="#9e8b6a")

    # Clear aisles/build pads are annotations of actual manifest bounds.
    for pad in layout["build_pads"]:
        x0,y0,x1,y1=pad["bounds"]
        a,b,_,_=cellbox(x0,y1)
        _,_,e,f=cellbox(x1,y0)
        d.rectangle((a+2,b+2,e-2,f-2),outline=AMBER,width=2)
        text(a+7,b+35,"BUILD",12,AMBER,True)
    gate=layout["protected"]["boundary_gates"][0]
    gx,gy,_,_=cellbox(*gate)
    line([(gx+11,gy+11),(665,gy+11)],TEAL)
    text(684,gy-12,"Party boundary",22,TEAL,True)
    text(684,gy+20,"Required in home and raid;",16,MUTED)
    text(684,gy+42,"implementation pending",16,MUTED)

    labels = {"crew":("Crew bunks","Two bunks / private rest"),
              "mess":("Mess + wash","Meals and basic amenities"),
              "stores":("Party stores","Sheltered equipment storage"),
              "repair":("Quiet repair nook","Bench and equipment rack"),
              "workshop":("Build + crafting carriage","Two build pads / open central aisle"),
              "utility":("Utility + helm cabin","Storage, racks and helm study")}
    # Small protected rooms alternate label sides to retain readable leader lines.
    for room in layout["rooms"]:
        x0,y0,x1,y1=room["bounds"]
        py=oy+(LENGTH-1-(y0+y1)/2)*c+11
        left=room["id"] in ("crew","stores")
        color=TEAL if room["protected"] else AMBER
        if left:
            line([(ox-12,py),(ox+18,py)],color)
            text(78,py-31,labels[room["id"]][0],20,color,True)
            text(78,py+1,"Protected intent",16,MUTED)
        else:
            line([(ox+WIDTH*c+8,py),(665,py)],color)
            text(684,py-30,labels[room["id"]][0],22,color,True)
            text(684,py+5,labels[room["id"]][1],16,MUTED)
    text(220,295,"N",23,TEAL,True)
    line([(231,289),(231,251)],TEAL,3)
    d.polygon([(231,245),(225,258),(237,258)],fill=TEAL)
    text(280,1355,"Full rectangular reservation mask, including coupling corners",17,MUTED)

    def stage(x, y, z, scale=3):
        # Draw exact generated staging world; north is at the top.
        for (wx,wy,wz),(kind,area) in grid.items():
            if wz != z:
                continue
            px,py=x+(wx-1)*scale,y+(128-wy)*scale
            d.rectangle((px,py,px+scale-1,py+scale-1),fill=PALETTE[kind][1])
        for slot in layout["slots"]:
            if slot["origin"][2] != z:
                continue
            sx,sy,_=slot["origin"]
            a,b=x+(sx-1)*scale,y+(128-(sy+50))*scale
            d.rectangle((a,b,a+WIDTH*scale-1,b+LENGTH*scale-1),outline=TEAL if z==1 else AMBER,width=2)
        return lambda wx,wy:(x+(wx-1)*scale+scale/2,y+(128-wy)*scale+scale/2)

    text(1062,208,"02  SEPARATED HOMES / Z1",24,bold=True)
    text(1062,247,"Two sealed study enclosures",19,MUTED)
    stage(1140,290,1)
    text(1124,685,"Home west",18,TEAL,True)
    text(1403,685,"Home east",18,TEAL,True)
    text(1062,780,"03  RAID STATION / Z2",24,bold=True)
    text(1062,819,"Parallel berths + common central platform",19,MUTED)
    project=stage(1140,867,2)
    # Boarding paths follow the source platform anchors to their facing ports.
    for slot in layout["slots"]:
        if slot["kind"] != "raid_berth":
            continue
        sx,sy,_=slot["origin"]
        portx=sx+14 if slot["platform_side"]=="east" else sx
        for ax,ay,az in slot["platform_anchors"]:
            points=[project(portx,ay),project(ax,ay),project(57,ay)]
            line(points,"#fff0bd",3)
            px,py=project(ax,ay)
            d.ellipse((px-4,py-4,px+4,py+4),fill="#fff0bd")
    text(1091,1265,"West berth",18,AMBER,True)
    text(1431,1265,"East berth",18,AMBER,True)
    text(1208,1300,"Shared boarding routes",18,"#fff0bd",True)
    text(1062,1348,"128 x 128 x 2 staging world",20,MUTED)

    # Legend sits above footer and is deliberately worded as design intent.
    d.rectangle((66,1434,84,1452),fill=TEAL)
    text(96,1425,"Protected intent",19,TEAL,True)
    d.rectangle((310,1434,328,1452),fill=AMBER)
    text(340,1425,"Exposed carriage",19,AMBER,True)
    text(595,1425,"Symbols: bunk / crossed crate / rack / table / A anvil / S sink / T toilet",18,MUTED)
    text(64,1471,"PROTOTYPE ONLY - Access, damage protection, movement and persistence remain pending.",21,TEXT,True)
    text(64,1506,"Two home slots and two raid berths demonstrate geometry only; they do not define a production party cap. Source diagram, not gameplay.",18,MUTED)
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    im.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
