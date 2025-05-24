import os
import sys
import argparse
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

def ensure_libs():
    for lib in ["librosa", "soundfile", "numpy", "pyloudnorm", "mido"]:
        try:
            __import__(lib)
        except ImportError:
            print(f"Installing {lib}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", lib])

ensure_libs()

import pyloudnorm as pyln
import numpy as np
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
parser.add_argument('--program', type=int, default=41, help='Program change number (0–127)')
parser.add_argument('--outdir', type=str, default='violin', help='Output directory for OGG files')
args = parser.parse_args()

script_dir = os.path.dirname(os.path.abspath(__file__))
args.outdir = os.path.join(script_dir, 'generated', args.outdir)
os.makedirs(args.outdir, exist_ok=True)

# Hardcoded paths (relative to this script)
fluidsynth_path = os.path.join(script_dir, "fluidSynth", "bin", "fluidsynth.exe")
soundfont_path = os.path.join(script_dir, "fluidSynth", "FluidR3_GM.sf2")

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

    # Wait until the file exists and is readable
    for _ in range(30):
        if midi_path.exists() and midi_path.stat().st_size > 0:
            try:
                # Try to reopen and read the file
                with open(midi_path, "rb") as f:
                    f.read(1)
                return str(midi_path)
            except Exception:
                pass
        time.sleep(0.1)

    print(f"Failed to fully write or access MIDI file: {midi_path}")
    return None


def convert_midi_file(midi_path):
    from pathlib import Path

    base = Path(midi_path).with_suffix('')
    wav_path = base.with_suffix('.wav').as_posix()
    ogg_path = base.with_suffix('.ogg').as_posix()
    midi_path = Path(midi_path).as_posix()
    name = os.path.basename(base)

    if not os.path.exists(midi_path):
        return name, "missing"

    try:
        subprocess.run([
            fluidsynth_path,
            "-ni", "-F", str(wav_path), "-r", "44100",
            soundfont_path,
            str(midi_path)
        ], check=True, timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        y, sr = librosa.load(wav_path, sr=None)
        max_duration_sec = 3
        y = y[:int(sr * max_duration_sec)]

        fade_in_duration = int(sr * 0.005)
        y[:fade_in_duration] *= np.linspace(0, 1, fade_in_duration)

        meter = pyln.Meter(sr)
        loudness = meter.integrated_loudness(y)

        if not np.isfinite(loudness) or np.max(np.abs(y)) < 0.01:
            os.remove(wav_path)
            os.remove(midi_path)
            return name, "silent"

        y = pyln.normalize.loudness(y, loudness, -38.0)

        peak = np.max(np.abs(y))
        if peak <= 0:
            print(f"Skipping {os.path.basename(midi_path)}: silent audio.")
            return name, "silent"

        sf.write(ogg_path, y, sr)

        os.remove(wav_path)
        os.remove(midi_path)

        return name, "ok"

    except Exception:
        return name, "error"


# --- MAIN EXECUTION ---
midi_paths = []

# 1. Generate all MIDI files first
tasks = []
midi_paths = []

with ThreadPoolExecutor(max_workers=8) as executor:  # Adjust workers as needed
    for octave in range(0, 10):  # Includes octave 0
        for note_name, semitone in note_map.items():
            midi_note = semitone + (octave + 1) * 12
            if not (0 <= midi_note <= 127):
                continue
            future = executor.submit(generate_midi, note_name, octave, midi_note, args.program, args.outdir)
            tasks.append(future)

    for future in as_completed(tasks):
        path = future.result()
        if path:
            midi_paths.append(path)

print(f"MIDI generation complete: {len(midi_paths)} files written to {args.outdir}")

print(f"Pausing briefly before MIDI to OGG conversion...")
time.sleep(1)

max_line_length = len(args.outdir)*4
progress_line = ""

with ThreadPoolExecutor(max_workers=8) as executor:
    futures = {executor.submit(convert_midi_file, path): path for path in midi_paths}

    for future in as_completed(futures):
        name, status = future.result()

        if status == "silent":
            color = "\033[90m"  # gray
        elif status == "ok":
            color = "\033[0m"   # default
        else:
            color = "\033[91m"  # red

        word = f"{color}{name}\033[0m "

        if len(progress_line) + len(name) + 1 > max_line_length:
            print(progress_line)
            progress_line = word
        else:
            progress_line += word

if progress_line.strip():
    print(progress_line)

print(f"[ Done ] {len(midi_paths)} OGG files generated in: {args.outdir}")