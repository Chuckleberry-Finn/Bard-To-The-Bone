import os
import re
import sys
import subprocess

# === Auto-install required libraries (on PATH) ===
def ensure_libs():
    required = ["librosa", "soundfile", "numpy"]
    for lib in required:
        try:
            __import__(lib)
        except ImportError:
            print(f"Installing {lib} to system PATH or user PATH...")
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", lib])
            except subprocess.CalledProcessError:
                print(f"Trying user install for {lib}...")
                subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "--upgrade", lib])

ensure_libs()

# === Re-import now that everything's installed ===
import librosa
import soundfile as sf
import numpy as np

# === Config ===
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "Contents", "mods", "BardToTheBone", "common", "media", "sound", "instruments"))
TARGET_RANGE = range(21, 128)  # MIDI notes A0 (21) to G9 (127)
NOTE_ORDER = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B']

# === MIDI helpers ===
def midi_to_note_name(midi_num):
    note = NOTE_ORDER[midi_num % 12]
    octave = midi_num // 12 - 1
    return f"{note}{octave}"

def note_name_to_midi(note):
    match = re.match(r'([A-Ga-g][b#]?)(-?\d)', note)
    if not match:
        return None
    name, octave = match.groups()
    name = name.capitalize()
    if name not in NOTE_ORDER:
        return None
    return NOTE_ORDER.index(name) + (int(octave) + 1) * 12

# === Pitch shifting without affecting duration/volume ===
def pitch_shift_sample(source_path, semitone_shift, output_path):
    y, sr = librosa.load(source_path, sr=None)
    y_shifted = librosa.effects.pitch_shift(y=y, sr=sr, n_steps=semitone_shift)
    sf.write(output_path, y_shifted, sr)

# === Process one instrument folder ===
def process_instrument_folder(instrument_path):
    print(f"\n▶ Processing: {instrument_path}")
    files = [f for f in os.listdir(instrument_path) if f.lower().endswith(".ogg")]
    present = {}
    for file in files:
        match = re.match(r'([A-Ga-g][b#n]?)(\d)\.ogg', file)
        if match:
            note, octave = match.groups()
            note = note.replace("n", "")  # normalize "An" to "A"
            midi = note_name_to_midi(f"{note}{octave}")
            if midi is not None:
                present[midi] = file

    for midi in TARGET_RANGE:
        if midi not in present:
            if not present:
                continue
            donor_midi = min(present.keys(), key=lambda m: abs(m - midi))
            shift = midi - donor_midi
            donor_file = present[donor_midi]
            donor_path = os.path.join(instrument_path, donor_file)
            out_name = midi_to_note_name(midi) + ".ogg"
            out_path = os.path.join(instrument_path, out_name)
            print(f"  + Generating {out_name} from {donor_file} (shift {shift:+} semitones)")
            pitch_shift_sample(donor_path, shift, out_path)

# === Entry point ===
def main():
    if not os.path.exists(ROOT_DIR):
        print(f"Error: Cannot find instrument folder at {ROOT_DIR}")
        return
    for folder in os.listdir(ROOT_DIR):
        instrument_path = os.path.join(ROOT_DIR, folder)
        if os.path.isdir(instrument_path):
            process_instrument_folder(instrument_path)

if __name__ == "__main__":
    main()
