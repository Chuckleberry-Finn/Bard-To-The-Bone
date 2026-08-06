#!/usr/bin/env python3
"""
checkDrumAlignment.py

Sanity-checks a drum track converted to ABC (e.g. via Midi2ABC.exe) BEFORE
you spend time generating samples or testing in-game. It re-derives each
note's MIDI number using the SAME convention BardToTheBone_main.lua uses
(Bard.noteToMidi: octave 4 = the un-marked octave, C4 = MIDI 60), and checks
it against the General MIDI percussion range (35-81).

If most notes fall outside that range, it suggests a percussionOctaveShift
value to set on the "Drum Kit" entry in BardToTheBone_main.lua.

Usage:
    python checkDrumAlignment.py path/to/drums.abc [--voice 2]
"""

import argparse
import re
import sys
from collections import Counter

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

# Must match Bard.drumKitPieces in BardToTheBone_main.lua exactly.
DRUM_KIT_PIECES = {36, 38, 41, 47, 48, 49, 51}

# Must match Bard.drumKitFallback in BardToTheBone_main.lua exactly.
DRUM_KIT_FALLBACK = {
    35: 36, 37: 38, 39: 38, 40: 38, 42: 51, 43: 41, 44: 51, 45: 47,
    46: 49, 50: 48, 52: 49, 53: 51, 54: 51, 55: 49, 56: 51, 57: 49,
    58: 47, 59: 51, 60: 48, 61: 47, 62: 48, 63: 48, 64: 47, 65: 48,
    66: 41, 67: 51, 68: 47, 69: 51, 70: 51, 71: 51, 72: 51, 73: 51,
    74: 51, 75: 38, 76: 48, 77: 47, 78: 47, 79: 41, 80: 51, 81: 51,
}


def resolve_piece(midi):
    """Mirrors Bard.percussionSoundName: exact match, else fallback, else None."""
    if midi in DRUM_KIT_PIECES:
        return GM_PERCUSSION_MAP.get(midi), "exact"
    fb = DRUM_KIT_FALLBACK.get(midi)
    if fb is not None:
        return GM_PERCUSSION_MAP.get(fb), "fallback"
    return None, "unresolved"


BASE_SEMITONE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# A single ABC note token: optional accidental(s), letter, optional octave
# marks ( ' up, , down ), optional duration. Mirrors the note regex used in
# BardToTheBone_main.lua's Bard.parseNoteToken.
NOTE_RE = re.compile(r"([_=^]*)([A-Ga-g])([',]*)(\d*/?\d*)")


def note_to_midi(accidental, letter, octave_marks):
    letter_up = letter.upper()
    octave = 5 if letter.islower() else 4
    for ch in octave_marks:
        octave += 1 if ch == "'" else -1

    pitch = BASE_SEMITONE[letter_up]
    if accidental.startswith("^"):
        pitch += 1
    elif accidental.startswith("_"):
        pitch -= 1

    return (octave + 1) * 12 + pitch


def extract_voice_lines(abc_text, voice):
    """Very small, permissive line-splitter: just enough to isolate a
    voice's note lines for this diagnostic, not a full ABC parser."""
    lines = abc_text.splitlines()
    current_voice = None
    kept = []
    for line in lines:
        stripped = line.strip()
        m = re.match(r"^([A-Za-z]):\s*(.*)$", stripped)
        if m:
            header, value = m.group(1), m.group(2)
            if header == "V":
                current_voice = value.split()[0] if value.split() else value
            continue  # skip all header lines for this diagnostic
        if voice is None or current_voice == voice or (voice is None and current_voice is None):
            kept.append(stripped)
    return kept


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("abc_file", help="Path to a .abc file (typically the drum/channel-10 track from Midi2ABC)")
    parser.add_argument("--voice", default=None, help='Only inspect this V: voice ID (e.g. "10" or "1"). Default: notes not inside any V: block, i.e. a single-voice file.')
    args = parser.parse_args()

    try:
        with open(args.abc_file, "r", encoding="utf-8", errors="replace") as f:
            abc_text = f.read()
    except OSError as e:
        print(f"Could not read {args.abc_file}: {e}")
        sys.exit(1)

    lines = extract_voice_lines(abc_text, args.voice)
    body = " ".join(lines)
    # Strip bracketed chords down to their contents, quoted chord symbols,
    # and comments -- close enough for this diagnostic.
    body = re.sub(r'"[^"]*"', "", body)
    body = re.sub(r"%.*", "", body)
    body = body.replace("[", " ").replace("]", " ")

    midi_counts = Counter()
    for accidental, letter, octave_marks, _dur in NOTE_RE.findall(body):
        midi = note_to_midi(accidental, letter, octave_marks)
        midi_counts[midi] += 1

    if not midi_counts:
        print("No notes found. Check the --voice ID, or that this is the right file/track.")
        sys.exit(1)

    total = sum(midi_counts.values())
    in_range = sum(c for m, c in midi_counts.items() if 35 <= m <= 81)
    pct_in_range = 100 * in_range / total

    print(f"{total} notes found across {len(midi_counts)} distinct pitches.\n")
    print(f"{'MIDI':>5}  {'Count':>6}  {'%':>5}  {'':>10}  Plays as")
    for midi, count in sorted(midi_counts.items(), key=lambda kv: -kv[1]):
        pct = 100 * count / total
        gm_name = GM_PERCUSSION_MAP.get(midi, "-- outside GM drum range --")
        piece, how = resolve_piece(midi)
        if how == "exact":
            plays_as = f"{piece} (exact)"
        elif how == "fallback":
            plays_as = f"{piece} (fallback, kit has no {gm_name})"
        else:
            plays_as = "-- SILENT, no fallback for this note --"
        print(f"{midi:5d}  {count:6d}  {pct:4.1f}%  {gm_name:>10}  {plays_as}")

    print(f"\n{pct_in_range:.1f}% of notes fall in the GM percussion range (35-81).")

    exact = sum(c for m, c in midi_counts.items() if resolve_piece(m)[1] == "exact")
    fallback = sum(c for m, c in midi_counts.items() if resolve_piece(m)[1] == "fallback")
    silent_in_range = sum(c for m, c in midi_counts.items() if 35 <= m <= 81 and resolve_piece(m)[1] == "unresolved")
    if in_range:
        print(f"Of those: {100*exact/in_range:.1f}% play their exact piece, "
              f"{100*fallback/in_range:.1f}% substitute via the fallback table, "
              f"{100*silent_in_range/in_range:.1f}% have no mapping at all (shouldn't happen -- "
              f"every GM 35-81 note has either a kit piece or a fallback).")

    if pct_in_range < 50:
        # Find the octave shift that would put the most notes in range
        best_shift, best_pct = 0, pct_in_range
        for shift in range(-3, 4):
            shifted_in_range = sum(c for m, c in midi_counts.items() if 35 <= (m + shift * 12) <= 81)
            shifted_pct = 100 * shifted_in_range / total
            if shifted_pct > best_pct:
                best_shift, best_pct = shift, shifted_pct

        if best_shift != 0:
            print(f"\nSuggestion: set percussionOctaveShift = {best_shift} on the \"Drum Kit\"")
            print(f"entry in BardToTheBone_main.lua -- that would put {best_pct:.1f}% of notes in range.")
        else:
            print("\nCouldn't find a whole-octave shift that helps much. This track may not")
            print("be a channel-10 percussion track, or may use a non-standard drum map")
            print("(e.g. an extended/GM2 kit) -- worth eyeballing the original MIDI in a")
            print("DAW or MIDI inspector to confirm which channel/track this came from.")
    else:
        print("Looks aligned -- safe to generate a kit and test these pieces in-game.")


if __name__ == "__main__":
    main()
