import subprocess
import sys
import os

# You can also import from a .py file if preferred
instruments = [


    {"program": 22, "folder": "accordion"},
    {"program": 106, "folder": "banjo"},
    # "bikehorn" has no midi
    {"program": 77, "folder": "bottle"},
    {"program": 34, "folder": "electric_bass"},

    {"program": 28, "folder": "electric_guitarClean"},
    {"program": 29, "folder": "electric_guitarMuted"},
    {"program": 30, "folder": "electric_guitarOverdrive"},
    {"program": 31, "folder": "electric_guitarDistortion"},
    {"program": 32, "folder": "electric_guitarHarmonics"},

    {"program": 74, "folder": "flute"},
    {"program": 10, "folder": "glockenspiel"},
    {"program": 1, "folder": "grandPiano"},
    {"program": 25, "folder": "guitar"},
    {"program": 23, "folder": "harmonica"},

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
    {"program": 56, "folder": "trumpet"},
    {"program": 41, "folder": "violin"},
    {"program": 79, "folder": "whistle"},
    {"program": 14, "folder": "xylophone"},

]

script = os.path.join(os.path.dirname(__file__), "generateOgg.py")

for inst in instruments:
    program = str(inst["program"])
    outdir = inst["folder"]

    print(f"=== Generating instrument: {outdir} (Program {program}) ===")

    result = subprocess.run([
        sys.executable, script,
        "--program", program,
        "--outdir", outdir
    ])

    if result.returncode != 0:
        print(f"Failed to generate {outdir}\n")
    else:
        print(f"Finished generating {outdir}\n")