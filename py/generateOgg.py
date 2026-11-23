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

import warnings
import pyloudnorm as pyln

# The ceiling check below scales any over-full-scale note back down before writing.
warnings.filterwarnings("ignore", message="Possible clipped samples in output.")
import numpy as np
import librosa
import soundfile as sf
from mido import Message, MidiFile, MidiTrack

BASE_LOUDNESS_LUFS = -23.0  # foreground/instrument level
VOLUME_BOOST_PERCENT = 33   # extra loudness on top of the base level
TARGET_LOUDNESS_LUFS = BASE_LOUDNESS_LUFS + 20 * np.log10(1 + VOLUME_BOOST_PERCENT / 100)
CEILING_DBFS = -1.0           # safety margin below full scale (0 dBFS)
CEILING_LINEAR = 10 ** (CEILING_DBFS / 20)

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
parser.add_argument('--program', type=int, default=41, help='General MIDI instrument number (1-128), as listed on the Wikipedia page above')
parser.add_argument('--bank', type=int, default=0, help='Soundfont bank for variation instruments, e.g. 16 with program 26 for Mandolin (0 = General MIDI)')
parser.add_argument('--outdir', type=str, default='violin', help='Output directory for OGG files')
parser.add_argument('--dry', action='store_true', help='Render without the soundfont reverb and chorus')
parser.add_argument('--velocity', type=int, default=90, help='Note-on velocity (1-127)')
parser.add_argument('--note-ticks', type=int, default=7680, help='Note length in ticks (960 per beat)')
parser.add_argument('--max-seconds', type=float, default=7.0, help='Longest sample length in seconds')
parser.add_argument('--highpass', type=float, default=0, help='Cut frequencies below this many Hz (0 = off)')
parser.add_argument('--lowpass', type=float, default=0, help='Cut frequencies above this many Hz (0 = off)')
parser.add_argument('--crush-bits', type=int, default=0, help='Reduce to this many bits for a crunchy sound (0 = off)')
parser.add_argument('--transpose', type=int, default=0, help='Shift every note by this many semitones (12 = one octave up)')
parser.add_argument('--min-note', type=int, default=0, help='Move lower notes up by octaves until they reach this MIDI number')
parser.add_argument('--max-note', type=int, default=127, help='Move higher notes down by octaves until they reach this MIDI number')
parser.add_argument('--drum-note', type=int, default=0, help='Build every note from this General MIDI percussion sound (e.g. 72 Long Whistle), retuned per note and looped to --max-seconds (0 = off)')
parser.add_argument('--drum-root', type=int, default=60, help='MIDI note the --drum-note sound already sounds at, used to retune it')
parser.add_argument('--gain', type=float, default=0, help='FluidSynth render gain, for quiet instruments that come out as silent (0 = FluidSynth default)')
args = parser.parse_args()
if not 1 <= args.program <= 128:
    parser.error('--program must be a General MIDI instrument number from 1 to 128')
if not 0 <= args.min_note <= args.max_note - 11 <= 116:
    parser.error('--min-note and --max-note must be within 0-127 and at least 11 apart')

script_dir = os.path.dirname(os.path.abspath(__file__))
args.outdir = os.path.join(script_dir, 'generated', args.outdir)
os.makedirs(args.outdir, exist_ok=True)

# Hardcoded paths (relative to this script)
fluidsynth_path = os.path.join(script_dir, "fluidSynth", "bin", "fluidsynth.exe")
soundfont_path = os.path.join(script_dir, "fluidSynth", "FluidR3_GM.sf2")


os.makedirs(args.outdir, exist_ok=True)

def generate_midi(note_name, octave, midi_note, program, outdir):
    from pathlib import Path

    mid = MidiFile(ticks_per_beat=960)
    track = MidiTrack()
    mid.tracks.append(track)

    if args.bank:
        track.append(Message('control_change', control=0, value=args.bank, time=0))
    track.append(Message('program_change', program=program - 1, time=0))
    sounding = midi_note + args.transpose
    while sounding > args.max_note:
        sounding -= 12
    while sounding < args.min_note:
        sounding += 12

    midi_path = Path(outdir) / f"{note_name}{octave}.mid"
    if args.drum_note:
        drum_shift[midi_path.as_posix()] = sounding - args.drum_root
        track.append(Message('note_on', channel=9, note=args.drum_note, velocity=args.velocity, time=0))
        track.append(Message('note_off', channel=9, note=args.drum_note, velocity=64, time=args.note_ticks))
    else:
        track.append(Message('note_on', note=sounding, velocity=args.velocity, time=0))
        track.append(Message('note_off', note=sounding, velocity=64, time=args.note_ticks))
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


drum_shift = {}


def retune_and_sustain(y, sr, semitones, seconds):
    # Varispeed: play the sound faster or slower so its pitch moves by `semitones`
    ratio = 2 ** (semitones / 12)
    y = librosa.resample(y, orig_sr=sr, target_sr=int(round(sr / ratio)))

    # Trim silence, then loop the steady middle (between attack and release) until it lasts `seconds`
    audible = np.where(np.abs(y) > np.max(np.abs(y)) * 0.05)[0]
    if len(audible) == 0:
        return y
    y = y[audible[0]:audible[-1] + 1]
    target = int(sr * seconds)
    if len(y) >= target:
        return y[:target]

    attack = int(len(y) * 0.2)
    release = int(len(y) * 0.8)
    body = y[attack:release]
    fade = min(int(sr * 0.02), len(body) // 4)
    if fade < 2:
        return y
    ramp = np.linspace(0, 1, fade)

    out = y[:release].copy()
    while len(out) < target:
        joined = out[-fade:] * (1 - ramp) + body[:fade] * ramp
        out = np.concatenate([out[:-fade], joined, body[fade:]])
    return out[:target]


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
        command = [fluidsynth_path, "-ni", "-F", str(wav_path), "-r", "44100"]
        if args.dry:
            command += ["-R", "0", "-C", "0"]
        if args.gain > 0:
            command += ["-g", str(args.gain)]
        command += [soundfont_path, str(midi_path)]
        subprocess.run(command, check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        y, sr = librosa.load(wav_path, sr=None)
        if args.drum_note:
            y = retune_and_sustain(y, sr, drum_shift[midi_path], args.max_seconds)
        y = y[:int(sr * args.max_seconds)]

        if args.highpass > 0 or args.lowpass > 0:
            from scipy.signal import butter, sosfilt
            if args.highpass > 0:
                y = sosfilt(butter(2, args.highpass, btype='highpass', fs=sr, output='sos'), y)
            if args.lowpass > 0:
                y = sosfilt(butter(2, args.lowpass, btype='lowpass', fs=sr, output='sos'), y)

        if args.crush_bits > 0:
            steps = 2 ** (args.crush_bits - 1)
            y = np.round(y * steps) / steps

        fade_in_duration = int(sr * 0.005)
        y[:fade_in_duration] *= np.linspace(0, 1, fade_in_duration)

        fade_out_duration = min(int(sr * 0.5), len(y) // 2)
        y[-fade_out_duration:] *= np.linspace(1, 0, fade_out_duration)

        meter = pyln.Meter(sr)
        measured = y
        block = int(sr * meter.block_size)
        if len(measured) <= block:
            measured = np.pad(measured, (0, block - len(measured) + int(sr * 0.1)))
        loudness = meter.integrated_loudness(measured)

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


midi_paths = []
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