## Bard to the Bone Python Scripts

### `fixSongLibrary.py`
Optional. Renames the files with in `songLibrary\songs` to match their T: (title) line.
<br><br>

### `autoGenSoundScripts.py`
Generates `sounds_BardToTheBone` which is needed for sounds to play in game, should be ran last if you're making your own sounds.
<br><br>

### `generateOgg.py`
Generates a suite of notes, refer to: [change_events](https://en.wikipedia.org/wiki/General_MIDI#Program_change_events) for the `change_event` param, the `output_dir` should match the instrument ID in `BardToTheBone_main`. Results will be in `py/generated/<output_dir>/`.
<br><br>

### `batchGenerate.py`
Has a table of params for `generateOgg` to batch process through, can take a while to complete.
<br><br>