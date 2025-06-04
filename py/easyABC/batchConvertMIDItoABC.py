import os
import subprocess
from pathlib import Path

# Define paths
script_dir = Path(__file__).resolve().parent
midi2abc_path = script_dir / 'midi2abc.py'
input_dir = script_dir / 'songsToConvert'
output_dir = script_dir / 'convertedABC'

# Create output directory if it doesn't exist
output_dir.mkdir(exist_ok=True)

# Iterate over all MIDI files in the input directory
for midi_file in input_dir.glob('*.mid'):
    output_file = output_dir / (midi_file.stem + '.abc')
    try:
        # Call the midi2abc.py script with appropriate arguments
        subprocess.run([
            'python', str(midi2abc_path),
            '-f', str(midi_file),
            '-o', str(output_file)
        ], check=True)
        print(f"Converted: {midi_file.name} -> {output_file.name}")
    except subprocess.CalledProcessError as e:
        print(f"Error converting {midi_file.name}: {e}")
