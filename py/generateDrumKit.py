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

TARGET_LOUDNESS_LUFS = -23.0  # foreground/instrument level
CEILING_DBFS = -1.0           # safety margin below full scale (0 dBFS)
CEILING_LINEAR = 10 ** (CEILING_DBFS / 20)

# General MIDI percussion key map (channel 10, notes 35-81). Names MUST match
# Bard.gmPercussionMap in BardToTheBone_main.lua -- that's how the game finds
# "media/sound/instruments/<drum-kit-folder>/<Name>.ogg" for a given note.
GM_PERCUSSION_MAP = {
    35: "AcousticBassDrum", 36: "BassDrum1",     37: "SideStick",
    38: "AcousticSnare",    39: "HandClap",      40: "ElectricSnare",
    41: "LowFloorTom",      42: "ClosedHiHat",   43: "HighFloorTom",
    44: "PedalHiHat",       45: "LowTom",        46: "OpenHiHat",
    47: "LowMidTom",        48: "HiMidTom",      49: "CrashCymbal1",
    50: "HighTom",          51: "RideCymbal1",   52: "ChineseCymbal",
    53: "RideBell",         54: "Tambourine",    55: "SplashCymbal",
    56: "Cowbell",          57: "CrashCymbal2",  58: "Vibraslap",
    59: "RideCymbal2",      60: "HiBongo",       61: "LowBongo",
    62: "MuteHiConga",      63: "OpenHiConga",   64: "LowConga",
    65: "HighTimbale",      66: "LowTimbale",    67: "HighAgogo",
    68: "LowAgogo",         69: "Cabasa",        70: "Maracas",
    71: "ShortWhistle",     72: "LongWhistle",   73: "ShortGuiro",
    74: "LongGuiro",        75: "Claves",        76: "HiWoodBlock",
    77: "LowWoodBlock",     78: "MuteCuica",     79: "OpenCuica",
    80: "MuteTriangle",     81: "OpenTriangle",
}

# The default drum kit's actual playable pieces -- MUST match
# Bard.drumKitPieces in BardToTheBone_main.lua exactly (both the note
# numbers and names): kick, snare, 2 rack toms, 1 floor tom, crash, ride.
# --full below generates every GM piece if you want a bigger/different kit.
CORE_KIT = [36, 38, 41, 47, 48, 49, 51]

parser = argparse.ArgumentParser(description="Generate a General MIDI drum kit's OGG samples")
parser.add_argument('--outdir', type=str, default='drumkit', help='Output directory for OGG files (should match the instrument soundDir, e.g. "drumkit")')
parser.add_argument('--full', action='store_true', help='Generate all 47 GM percussion pieces instead of just the CORE_KIT subset')
parser.add_argument('--hit-velocity', type=int, default=100, help='Note-on velocity (0-127); percussion samples are usually not velocity-layered per-sample, but louder velocity can pick a different articulation in some soundfonts')
args = parser.parse_args()

script_dir = os.path.dirname(os.path.abspath(__file__))
args.outdir = os.path.join(script_dir, 'generated', args.outdir)
os.makedirs(args.outdir, exist_ok=True)

fluidsynth_path = os.path.join(script_dir, "fluidSynth", "bin", "fluidsynth.exe")
soundfont_path = os.path.join(script_dir, "fluidSynth", "FluidR3_GM.sf2")

PERCUSSION_CHANNEL = 9  # MIDI channel 10 (0-indexed) -- fixed by the GM spec, no program change needed


def generate_midi(note_number, name, outdir):
    from pathlib import Path

    mid = MidiFile(ticks_per_beat=960)
    track = MidiTrack()
    mid.tracks.append(track)

    # No program_change: channel 10 is the percussion channel by GM
    # convention, and note_number selects the drum piece directly.
    track.append(Message('note_on', channel=PERCUSSION_CHANNEL, note=note_number, velocity=args.hit_velocity, time=0))
    track.append(Message('note_off', channel=PERCUSSION_CHANNEL, note=note_number, velocity=64, time=3840))

    midi_path = Path(outdir) / f"{name}.mid"
    mid.save(midi_path)
    mid = None

    for _ in range(30):
        if midi_path.exists() and midi_path.stat().st_size > 0:
            try:
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

        # Drum hits are short one-shots; trim tail silence more aggressively
        # than the pitched-instrument generator does.
        max_duration_sec = 3
        y = y[:int(sr * max_duration_sec)]

        fade_in_duration = int(sr * 0.002)
        y[:fade_in_duration] *= np.linspace(0, 1, fade_in_duration)

        fade_out_duration = int(sr * 0.15)
        y[-fade_out_duration:] *= np.linspace(1, 0, fade_out_duration)

        meter = pyln.Meter(sr)
        loudness = meter.integrated_loudness(y)

        if not np.isfinite(loudness) or np.max(np.abs(y)) < 0.01:
            os.remove(wav_path)
            os.remove(midi_path)
            return name, "silent"

        y = pyln.normalize.loudness(y, loudness, TARGET_LOUDNESS_LUFS)

        peak = np.max(np.abs(y))
        if peak <= 0:
            print(f"Skipping {os.path.basename(midi_path)}: silent audio.")
            return name, "silent"

        # Safeguard: loudness-normalizing to a louder target can push peaks
        # past the safe ceiling (clipping). If that happens, scale the whole
        # sample down just enough to sit under the ceiling instead.
        if peak > CEILING_LINEAR:
            y = y * (CEILING_LINEAR / peak)

        sf.write(ogg_path, y, sr)

        os.remove(wav_path)
        os.remove(midi_path)

        return name, "ok"

    except Exception:
        return name, "error"


pieces = GM_PERCUSSION_MAP if args.full else {n: GM_PERCUSSION_MAP[n] for n in CORE_KIT}

midi_paths = []
tasks = []

with ThreadPoolExecutor(max_workers=8) as executor:
    for note_number, name in pieces.items():
        future = executor.submit(generate_midi, note_number, name, args.outdir)
        tasks.append(future)

    for future in as_completed(tasks):
        path = future.result()
        if path:
            midi_paths.append(path)

print(f"MIDI generation complete: {len(midi_paths)} files written to {args.outdir}")
print("Pausing briefly before MIDI to OGG conversion...")
time.sleep(1)

with ThreadPoolExecutor(max_workers=8) as executor:
    futures = {executor.submit(convert_midi_file, path): path for path in midi_paths}
    for future in as_completed(futures):
        name, status = future.result()
        print(f"  {status.upper():7s} {name}")

print(f"[ Done ] {len(midi_paths)} drum OGG files generated in: {args.outdir}")
print("Reminder: these filenames must match Bard.gmPercussionMap in BardToTheBone_main.lua exactly.")
