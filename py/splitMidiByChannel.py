#!/usr/bin/env python3
"""
splitMidiByChannel.py

Midi2ABC.exe (the drag-and-drop GUI in this pack) has no channel/track
selector -- it converts a WHOLE MIDI file into a single, flat ABC voice with
every channel's notes merged together. That's fine for a single-instrument
MIDI, but for a full band/song MIDI it means the drum track and every melodic
instrument all end up interleaved into one unplayable pile of notes, and you
can't isolate "just the drums" or build a proper multi-voice V:1/V:2/... file
from it directly.

This script splits a source .mid into one .mid per channel (each containing
only that channel's note_on/note_off/program_change events, everything else
kept as-is on channel 0 timing so tempo/etc. survive). Run Midi2ABC.exe on
each resulting file separately -- one will be your (channel-10) drum track,
suitable for checkDrumAlignment.py / generateDrumKit.py; the others are your
melodic parts, which you can hand-assemble into a V:1 / V:2 / ... multi-voice
ABC file (or just play them as separate performers/instruments).

Usage:
    python splitMidiByChannel.py song.mid
    -> writes song_ch1.mid, song_ch2.mid, ..., song_ch10.mid (drums), etc.
       (channel numbers shown 1-16, i.e. human/GM convention, not 0-indexed)
"""

import argparse
import os
import sys

try:
    import mido
except ImportError:
    print("Missing dependency: pip install mido")
    sys.exit(1)


def split_by_channel(path, outdir=None):
    mid = mido.MidiFile(path)
    base = os.path.splitext(os.path.basename(path))[0]
    outdir = outdir or os.path.dirname(os.path.abspath(path))

    channels_used = set()
    for track in mid.tracks:
        for msg in track:
            if hasattr(msg, "channel"):
                channels_used.add(msg.channel)

    if not channels_used:
        print("No channel-based events found -- is this a valid Type 0/1 MIDI file?")
        return []

    written = []
    for channel in sorted(channels_used):
        out = mido.MidiFile(ticks_per_beat=mid.ticks_per_beat, type=1)
        for track in mid.tracks:
            new_track = mido.MidiTrack()
            for msg in track:
                if not hasattr(msg, "channel") or msg.channel == channel:
                    new_track.append(msg)
            out.tracks.append(new_track)

        is_drum_channel = (channel == 9)  # MIDI channel 10, 0-indexed as 9
        suffix = f"_ch{channel + 1}{'_DRUMS' if is_drum_channel else ''}"
        out_path = os.path.join(outdir, f"{base}{suffix}.mid")
        out.save(out_path)
        written.append(out_path)
        note_count = sum(1 for track in out.tracks for msg in track if msg.type == "note_on" and msg.velocity > 0)
        print(f"  channel {channel + 1:2d}{' (drums)' if is_drum_channel else '':9s} -> {out_path}  ({note_count} notes)")

    return written


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("midi_file")
    parser.add_argument("--outdir", default=None, help="Output folder (default: alongside the input file)")
    args = parser.parse_args()

    if not os.path.isfile(args.midi_file):
        print(f"Not found: {args.midi_file}")
        sys.exit(1)

    print(f"Splitting {args.midi_file} by channel...")
    written = split_by_channel(args.midi_file, args.outdir)
    print(f"\nWrote {len(written)} file(s). Feed the _DRUMS one into Midi2ABC.exe for your drum track.")


if __name__ == "__main__":
    main()
