import argparse
import subprocess
import sys
import os

# You can also import from a .py file if preferred
instruments = [


    {"program": 22, "folder": "accordion"},
    {"program": 106, "folder": "banjo"},
    # "bikehorn" has no midi
    {"program": 76, "folder": "bottle", "extra": ["--dry", "--velocity", "55", "--note-ticks", "120", "--max-seconds", "0.3", "--highpass", "500", "--lowpass", "3500", "--min-note", "62", "--max-note", "101", "--gain", "1.0"]},
    {"program": 34, "folder": "electric_bass"},

    {"program": 28, "folder": "electric_guitarClean"},
    {"program": 29, "folder": "electric_guitarMuted"},
    {"program": 30, "folder": "electric_guitarOverdrive"},
    {"program": 31, "folder": "electric_guitarDistortion"},
    {"program": 32, "folder": "electric_guitarHarmonics"},

    {"program": 72, "folder": "clarinet"},
    {"program": 61, "folder": "frenchhorn"},
    {"program": 74, "folder": "flute"},
    {"program": 10, "folder": "glockenspiel"},
    {"program": 1, "folder": "grandPiano"},
    {"program": 25, "folder": "guitar"},
    {"program": 25, "folder": "lute"},
    {"program": 23, "folder": "harmonica"},
    {"program": 47, "folder": "harp"},

    {"program": 81, "folder": "keytarSquare"},
    {"program": 82, "folder": "keytarSawtooth"},
    {"program": 83, "folder": "keytarCalliope"},
    {"program": 84, "folder": "keytarChiff"},
    {"program": 85, "folder": "keytarCharang"},
    {"program": 86, "folder": "keytarVoice"},
    {"program": 87, "folder": "keytarFifths"},
    {"program": 88, "folder": "keytarBrass"},

    {"program": 2, "folder": "piano"},
    {"program": 75, "folder": "recorder"},
    {"program": 67, "folder": "saxophone"},
    {"program": 58, "folder": "trombone"},
    {"program": 57, "folder": "trumpet"},
    {"program": 41, "folder": "violin"},
    {"program": 79, "folder": "whistle"},
    {"program": 14, "folder": "xylophone", "extra": ["--dry", "--velocity", "60", "--note-ticks", "480", "--max-seconds", "1.5", "--highpass", "600", "--lowpass", "4000", "--min-note", "84", "--max-note", "105", "--gain", "1.0"]},

]

parser = argparse.ArgumentParser(description="Generate note files for several instruments")
parser.add_argument('--only', nargs='+', default=None, help='Only generate these folders, e.g. --only clarinet harp frenchhorn')
parser.add_argument('--skip', nargs='+', default=[], help='Generate everything except these folders, e.g. --skip lute')
args = parser.parse_args()

known = {inst["folder"] for inst in instruments}
unknown = [name for name in (args.only or []) + args.skip if name not in known]
if unknown:
    parser.error('unknown folder(s): ' + ', '.join(unknown) + '. Choose from: ' + ', '.join(sorted(known)))

selected = [inst for inst in instruments if (args.only is None or inst["folder"] in args.only) and inst["folder"] not in args.skip]

script = os.path.join(os.path.dirname(__file__), "generateOgg.py")

for inst in selected:
    program = str(inst["program"])
    outdir = inst["folder"]

    print(f"=== Generating instrument: {outdir} (Program {program}) ===")

    result = subprocess.run([
        sys.executable, script,
        "--program", program,
        "--outdir", outdir
    ] + inst.get("extra", []))

    if result.returncode != 0:
        print(f"Failed to generate {outdir}\n")
    else:
        print(f"Finished generating {outdir}\n")