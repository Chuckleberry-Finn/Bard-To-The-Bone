import os

script_dir = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(script_dir, "..", "Contents", "mods", "BardToTheBone", "common", "media", "sound", "instruments")

for instrument in sorted(os.listdir(path)):
    instrument_path = os.path.join(path, instrument)
    if os.path.isdir(instrument_path):
        print(f"\n{instrument}")
        for note in sorted(os.listdir(instrument_path)):
            print(f"  * {note}")