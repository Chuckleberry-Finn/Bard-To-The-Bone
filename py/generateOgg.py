import os
import sys
import argparse
import subprocess
import time

def ensure_libs():
    for lib in ["librosa", "soundfile", "numpy"]:
        try:
            __import__(lib)
        except ImportError:
            print(f"Installing {lib}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", lib])

ensure_libs()

import librosa
import soundfile as sf
from mido import Message, MidiFile, MidiTrack

note_map = {
    'Cb': 11, 'Cn': 0,
    'Db': 1,  'Dn': 2,
    'Eb': 3,  'En': 4,
    'Fb': 4,  'Fn': 5,
    'Gb': 6,  'Gn': 7,
    'Ab': 8,  'An': 9,
    'Bb': 10, 'Bn': 11,
}

parser = argparse.ArgumentParser(description="Generate and convert MIDI note files")
# https://en.wikipedia.org/wiki/General_MIDI#Program_change_events
parser.add_argument('--program', type=int, default=56, help='Program change number (0–127)')
parser.add_argument('--outdir', type=str, default='generated_sounds', help='Output directory for OGG files')
args = parser.parse_args()

# --- Resolve paths relative to script ---
script_dir = os.path.dirname(os.path.abspath(__file__))
args.outdir = os.path.join(script_dir, args.outdir)

# Hardcoded paths (relative to this script)
fluidsynth_path = os.path.join(script_dir, "fluidSynth", "bin", "fluidsynth.exe")
soundfont_path = os.path.join(script_dir, "FluidR3_GM.sf2")

# --- Setup ---
os.makedirs(args.outdir, exist_ok=True)

def generate_midi(note_name, octave, midi_note, program, outdir):
    from pathlib import Path

    mid = MidiFile(ticks_per_beat=960)
    track = MidiTrack()
    mid.tracks.append(track)

    track.append(Message('program_change', program=program, time=0))
    track.append(Message('note_on', note=midi_note, velocity=90, time=0))
    track.append(Message('note_off', note=midi_note, velocity=64, time=960))

    midi_path = Path(outdir) / f"{note_name}{octave}.mid"
    mid.save(midi_path)
    mid = None

    # Wait until the file is stable
    for _ in range(20):
        if midi_path.exists() and midi_path.stat().st_size > 0:
            return str(midi_path)
        time.sleep(0.1)

    print(f"Failed to write MIDI file: {midi_path}")
    return None


def convert_midi_file(midi_path):
    from pathlib import Path

    base = Path(midi_path).with_suffix('')
    wav_path = base.with_suffix('.wav').as_posix()
    ogg_path = base.with_suffix('.ogg').as_posix()
    midi_path = Path(midi_path).as_posix()

    if not os.path.exists(midi_path):
        print(f"MIDI file missing: {midi_path}")
        return

    try:
        subprocess.run([
            fluidsynth_path,
            "-ni", "-F", str(wav_path), "-r", "44100",
            soundfont_path,
            str(midi_path)
        ], check=True, timeout=10)

        y, sr = librosa.load(wav_path, sr=None)
        max_duration_sec = 3
        y = y[:int(sr * max_duration_sec)]
        sf.write(ogg_path, y, sr)

        os.remove(wav_path)
        os.remove(midi_path)

    except Exception as e:
        print(f"Failed to convert {midi_path}: {e}")


# --- MAIN EXECUTION ---
midi_paths = []

# 1. Generate all MIDI files first
print(f"\nGenerating MIDI files...")
for octave in range(0, 10):  # Includes octave 0
    for note_name, semitone in note_map.items():
        midi_note = semitone + (octave + 1) * 12
        if not (0 <= midi_note <= 127):
            continue

        path = generate_midi(note_name, octave, midi_note, args.program, args.outdir)
        if path:
            midi_paths.append(path)

input("\nPAUSED: Press Enter after confirming the output_dir was created to continue with conversion...")

# 2. Pause briefly to let file system settle
print(f"\nPausing briefly before conversion ({len(midi_paths)} MIDI files written)...")
time.sleep(10)

# 3. Convert all MIDI files to .ogg
print("\nBeginning batch conversion to OGG...")
for i, midi_path in enumerate(midi_paths, 1):
    print(f"[{i}/{len(midi_paths)}] {os.path.basename(midi_path)}")
    convert_midi_file(midi_path)

print(f"\nDone. {len(midi_paths)} OGG files generated in: {args.outdir}")