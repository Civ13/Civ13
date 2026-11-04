"""Cut the recorded village take into the finished trailer.

Upscales the native capture with nearest-neighbour filtering to 1080p, adds a
caption for each production step from the director's timeline, then
crossfades into the Civ13 end card with the Civ13.com call to action.

    python3 tools/village-trailer/edit.py --take take.mkv \
        --timeline trailer-timeline.json --title UI/images/civ13.png --out trailer.mp4
"""
import argparse
import json
from pathlib import Path
import subprocess

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
FONT_SANS = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
W, H = 1920, 1080
END_SECONDS = 7.0
FADE = 1.5

# Beat -> caption. A caption runs from its beat until the next captioned beat.
CAPTIONS = [
    ('seeds', 'Gather wild seeds'),
    ('plant', 'Plant your fields'),
    ('harvest', 'Harvest the crops'),
    ('deliver', 'Carry the grain to the mill'),
    ('bakery', 'Mill it into flour'),
    ('bake', 'Bake fresh bread'),
    ('serve', 'Trade with your neighbours'),
    ('carriage', 'Travel by horse and carriage'),
    ('station', 'Catch the train'),
    ('depart', 'and go wherever history takes you'),
]


def esc(text):
    return text.replace('\\', '\\\\').replace(':', '\\:').replace("'", "’")


def probe_duration(path):
    out = subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                                   '-of', 'default=nw=1:nk=1', str(path)], text=True)
    return float(out.strip())


def caption_filters(timeline, take_seconds):
    beats = {row['beat']: float(row['t']) for row in timeline}
    marks = [(beats[b], text) for b, text in CAPTIONS if b in beats]
    marks.sort()
    filters = []
    for i, (start, text) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else take_seconds
        start, end = start + 0.3, max(start + 1.5, end - 0.2)
        fade = 0.4
        alpha = (f"if(lt(t,{start}),0,if(lt(t,{start + fade}),(t-{start})/{fade},"
                 f"if(lt(t,{end - fade}),1,if(lt(t,{end}),({end}-t)/{fade},0))))")
        filters.append(
            f"drawtext=fontfile={FONT}:text='{esc(text)}':fontsize=56:fontcolor=white:"
            f"borderw=4:bordercolor=black@0.85:x=80:y=h-150:alpha='{alpha}'")
    # Opening title over the first shot.
    alpha = "if(lt(t,0.5),0,if(lt(t,1.2),(t-0.5)/0.7,if(lt(t,3.5),1,if(lt(t,4.2),(4.2-t)/0.7,0))))"
    filters.append(
        f"drawtext=fontfile={FONT}:text='Civilization 13':fontsize=110:fontcolor=#f0c040:"
        f"borderw=6:bordercolor=black@0.9:x=(w-text_w)/2:y=h*0.18:alpha='{alpha}'")
    return filters


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--take', required=True)
    p.add_argument('--timeline', required=True)
    p.add_argument('--title', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--trim-end', type=float, default=0.0, help='seconds to drop from the end of the take')
    a = p.parse_args()
    timeline = json.loads(Path(a.timeline).read_text())
    take_seconds = probe_duration(a.take) - a.trim_end
    beats = {row['beat']: float(row['t']) for row in timeline}
    if 'end' in beats:
        take_seconds = min(take_seconds, beats['end'])
    captions = ','.join(caption_filters(timeline, take_seconds))
    offset = take_seconds - FADE
    graph = (
        f"[0:v]trim=0:{take_seconds},setpts=PTS-STARTPTS,fps=30,"
        f"scale={W}:-2:flags=neighbor,crop={W}:'min(ih,{H})',pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:black,{captions},fade=t=in:st=0:d=0.8,format=yuv420p,setsar=1[game];"
        # End card: the game's title art (header + illustration, without the
        # badge between them) and the Civ13.com call to action.
        f"[1:v]split[ha][ia];[ha]crop=800:104:0:18,pad=800:128:0:0:black[hd];[ia]crop=800:258:0:184[il];"
        f"[hd][il]vstack,scale=-1:{int(H * 0.70)}:flags=neighbor,pad={W}:{H}:(ow-iw)/2:(oh-ih)/2-70:black,"
        f"drawtext=fontfile={FONT_SANS}:text='Play free at Civ13.com':fontsize=64:fontcolor=white:"
        f"x=(w-text_w)/2:y=h-140,fps=30,format=yuv420p,setsar=1,trim=0:{END_SECONDS + FADE},setpts=PTS-STARTPTS[end];"
        f"[game][end]xfade=transition=fade:duration={FADE}:offset={offset},fade=t=out:st={offset + FADE + END_SECONDS - 1.0}:d=1.0[v]"
    )
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y', '-i', a.take,
           '-loop', '1', '-framerate', '30', '-t', str(END_SECONDS + FADE + 1), '-i', a.title,
           '-filter_complex', graph, '-map', '[v]', '-c:v', 'libx264', '-preset', 'slow', '-crf', '18',
           '-movflags', '+faststart', a.out]
    subprocess.check_call(cmd)
    print(a.out, probe_duration(a.out))


if __name__ == '__main__':
    main()
