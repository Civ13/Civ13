"""Render the old violin and trumpet MIDI note files to Ogg Vorbis samples.

The violin and trumpet (/obj/item/trombone) shipped one MIDI file per note.
The BYOND client plays MIDI through the player's system synthesiser, which is
silent on most setups, so the notes are rendered once to .ogg with FluidSynth
and the FluidR3 General MIDI soundfont (MIT licence) and committed.

Usage: python3 render_midi_samples.py <midi dir> <ogg dir>
Needs fluidsynth, ffmpeg (with libvorbis) and FluidR3_GM.sf2.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SOUNDFONT = '/usr/share/sounds/sf2/FluidR3_GM.sf2'


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                          '-of', 'csv=p=0', str(path)], capture_output=True, text=True, check=True)
    try:
        return float(out.stdout.strip())
    except ValueError:
        return 0.0


def render(midi, ogg):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / 'note.wav'
        subprocess.run(['fluidsynth', '-ni', '-g', '1.0', '-r', '44100', '-F', str(wav),
                        SOUNDFONT, str(midi)], check=True, capture_output=True)
        trimmed = Path(tmp) / 'trimmed.wav'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(wav), '-af',
                        'silenceremove=start_periods=1:start_threshold=-60dB,'
                        'areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse',
                        str(trimmed)], check=True)
        length = duration(trimmed)
        if length < 0.05:
            return False  # The MIDI file holds no audible note.
        fade = max(length - 0.2, 0.05)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(trimmed), '-af',
                        f'apad=pad_dur=0.05,afade=t=out:st={fade:.3f}:d=0.25,'
                        'loudnorm=I=-20:TP=-6:LRA=7', '-ac', '1', '-ar', '44100',
                        '-c:a', 'libvorbis', '-q:a', '3', str(ogg)], check=True)
    return True


def main(source, target):
    source, target = Path(source), Path(target)
    target.mkdir(parents=True, exist_ok=True)
    for midi in sorted(source.glob('*.mid')):
        if not render(midi, target / (midi.stem + '.ogg')):
            print(f'silent, skipped: {midi.name}')


if __name__ == '__main__':
    main(*sys.argv[1:3])
