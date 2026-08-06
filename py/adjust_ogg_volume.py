#!/usr/bin/env python3
"""
adjust_ogg_volume.py

Increases or decreases the volume of all .ogg files in a given folder
by a percentage entered at the console.

Requires:
    pip install pydub
    ffmpeg installed and available on PATH (used by pydub to decode/encode ogg)
"""

import math
import os
import shutil
import subprocess
import sys


def ensure_pydub_installed():
    """Import pydub, installing it automatically via pip if it's missing."""
    try:
        from pydub import AudioSegment
        return AudioSegment
    except ImportError:
        print("'pydub' is not installed. Installing it now...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "pydub"])
        except subprocess.CalledProcessError as e:
            print(f"Failed to install 'pydub' automatically: {e}")
            print("Please install it manually with:  pip install pydub")
            sys.exit(1)

        try:
            from pydub import AudioSegment
            print("'pydub' installed successfully.\n")
            return AudioSegment
        except ImportError:
            print("Installation seemed to succeed, but 'pydub' still can't be imported.")
            print("Try restarting the script or installing manually with:  pip install pydub")
            sys.exit(1)


def ensure_ffmpeg_available():
    """ffmpeg can't reliably be pip-installed, so just check it's on PATH and warn if not."""
    if shutil.which("ffmpeg") is None:
        print("Warning: 'ffmpeg' was not found on your PATH.")
        print("pydub needs ffmpeg to read/write .ogg files.")
        print("Install it from https://ffmpeg.org/download.html")
        print("  - Windows: download a build and add its 'bin' folder to PATH")
        print("  - macOS:   brew install ffmpeg")
        print("  - Linux:   sudo apt install ffmpeg  (or your distro's package manager)")
        proceed = input("Continue anyway? (y/n): ").strip().lower()
        if proceed != "y":
            sys.exit(1)


AudioSegment = ensure_pydub_installed()
ensure_ffmpeg_available()


def percent_to_db(percent: float) -> float:
    """
    Convert a percentage volume change into a dB gain/loss.

    percent > 0  -> louder  (e.g. 50 means 'increase volume by 50%')
    percent < 0  -> quieter (e.g. -50 means 'decrease volume by 50%')

    Volume is treated as amplitude, so the new amplitude factor is:
        factor = 1 + (percent / 100)
    and dB change is:
        dB = 20 * log10(factor)
    """
    factor = 1 + (percent / 100.0)
    if factor <= 0:
        # A factor of 0 or less means "silence" -- cap it so log10 doesn't explode.
        factor = 0.0001
    return 20 * math.log10(factor)


def get_ogg_files(folder_path: str):
    """
    Recursively find all .ogg files under folder_path.
    Returns paths relative to folder_path (so subfolder structure can be preserved).
    """
    relative_paths = []
    for root, _dirs, files in os.walk(folder_path):
        for f in files:
            if f.lower().endswith(".ogg"):
                full_path = os.path.join(root, f)
                rel_path = os.path.relpath(full_path, folder_path)
                relative_paths.append(rel_path)
    return relative_paths


def main():
    folder_path = input("Enter the path to the folder containing .ogg files: ").strip().strip('"')

    if not os.path.isdir(folder_path):
        print(f"Error: '{folder_path}' is not a valid directory.")
        sys.exit(1)

    percent_input = input(
        "Enter volume change percentage (e.g. 50 to increase by 50%, -30 to decrease by 30%): "
    ).strip()

    try:
        percent = float(percent_input)
    except ValueError:
        print("Error: please enter a valid number (e.g. 25 or -25).")
        sys.exit(1)

    db_change = percent_to_db(percent)

    ogg_files = get_ogg_files(folder_path)
    if not ogg_files:
        print(f"No .ogg files found in '{folder_path}'.")
        sys.exit(0)

    print(f"\nFound {len(ogg_files)} .ogg file(s). Applying {db_change:+.2f} dB "
          f"({percent:+.1f}% volume change)...\n")

    # Optional: write to a subfolder instead of overwriting originals.
    overwrite = input(
        "Overwrite original files? (y/n) [n = save to './volume_adjusted' subfolder]: "
    ).strip().lower() == "y"

    if overwrite:
        output_folder = folder_path
    else:
        output_folder = os.path.join(folder_path, "volume_adjusted")
        os.makedirs(output_folder, exist_ok=True)

    for rel_path in ogg_files:
        input_path = os.path.join(folder_path, rel_path)
        output_path = os.path.join(output_folder, rel_path)

        try:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            audio = AudioSegment.from_ogg(input_path)
            adjusted = audio.apply_gain(db_change)
            adjusted.export(output_path, format="ogg")
            print(f"  OK   {rel_path}")
        except Exception as e:
            print(f"  FAIL {rel_path}: {e}")

    print(f"\nDone. Files saved to: {output_folder}")


if __name__ == "__main__":
    main()
