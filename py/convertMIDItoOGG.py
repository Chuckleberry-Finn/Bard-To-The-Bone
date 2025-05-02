import os
import subprocess
import sys

######################################################################################################
# This script takes existing mid/midi sounds and batch converts them to wav and then finally to ogg. #
######################################################################################################

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

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MIDI_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "Contents", "mods", "BardToTheBone", "common", "media", "sound", "instruments"))
SOUNDFONT = os.path.join(SCRIPT_DIR, "FluidR3_GM.sf2")

def convert_midi_file(midi_path, soundfont="FluidR3_GM.sf2"):
    import shutil

    script_dir = os.path.dirname(os.path.abspath(__file__))
    fluidsynth_path = os.path.join(script_dir, "fluidSynth", "bin", "fluidsynth.exe")
    soundfont_path = os.path.join(script_dir, soundfont)

    base = os.path.splitext(midi_path)[0]
    wav_path = base + ".wav"
    ogg_path = base + ".ogg"

    if not os.path.exists(fluidsynth_path):
        print(f"fluidsynth not found at: {fluidsynth_path}")
        return

    if not os.path.exists(soundfont_path):
        print(f"SoundFont not found: {soundfont_path}")
        return

    try:
        print(f"♬ Converting {os.path.basename(midi_path)} → {os.path.basename(ogg_path)}")
        soundfont_path = soundfont_path.replace("\\", "/")
        midi_path = midi_path.replace("\\", "/")
        wav_path = wav_path.replace("\\", "/")

        subprocess.run([
            fluidsynth_path,
            "-ni",
            "-F", wav_path,
            "-r", "44100",
            soundfont_path,
            midi_path
        ], check=True, timeout=10)

        y, sr = librosa.load(wav_path, sr=None)
        max_duration_sec = 3
        max_samples = int(sr * max_duration_sec)

        if len(y) > max_samples:
            print(f"⚠ Clipping audio to {max_duration_sec}s (was {len(y)/sr:.2f}s)")
            y = y[:max_samples]

        sf.write(ogg_path, y, sr)

        os.remove(wav_path)
        os.remove(midi_path)

    except Exception as e:
        print(f"Failed to convert {midi_path}: {e}")


def scan_and_convert(root):
    all_midi_files = []

    # Collect all .mid and .midi files recursively
    for folder, _, files in os.walk(root):
        for file in files:
            if file.lower().endswith((".mid", ".midi")):
                full_path = os.path.join(folder, file)
                all_midi_files.append(full_path)

    print(f"Note Found {len(all_midi_files)} MIDI file(s) to convert.\n")

    # Convert each one
    for i, midi_file in enumerate(all_midi_files, start=1):
        print(f"▶ [{i}/{len(all_midi_files)}] Processing: {os.path.basename(midi_file)}")
        convert_midi_file(midi_file)


def main():
    print(f"🔍 Scanning for MIDI files in: {MIDI_ROOT}")
    if not os.path.exists(SOUNDFONT):
        print(f"Missing SoundFont file: {SOUNDFONT}")
        print("Download one here: https://member.keymusician.com/Member/FluidR3_GM/index.html")
        return
    scan_and_convert(MIDI_ROOT)

if __name__ == "__main__":
    main()
