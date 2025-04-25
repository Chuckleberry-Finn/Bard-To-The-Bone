## Bard to the Bone Song Library
**Collection of 900+ songs ready to be entered in-game.**<br>
*<sup>Modified from the [Starbound Song Pack](https://github.com/luxx/sbsp) using [./renameSongLibrary.py](renameSongLibrary.py)</sup>*
####

## ABC Notation Field Reference

This guide outlines the most commonly used fields in [ABC notation](https://abcnotation.com/wiki/abc:standard). These metadata tags appear at the top of `.abc` files and describe key musical information.

### Basic Required Fields

| Field | Description |
|-------|-------------|
| `X:`  | **Reference number** (Required, unique per tune in a file) |
| `T:`  | **Title** (Can appear multiple times for subtitles) |
| `M:`  | **Meter / Time signature** (e.g., `4/4`, `6/8`, `C` for common time) |
| `K:`  | **Key signature** (e.g., `C`, `Dmaj`, `Amin`, `Gdor`) |
| `L:`  | **Default note length** (e.g., `1/8`, optional but recommended) |

**While not required, the Q header can change the speed/tempo of a song.**

| `Q:` | Tempo, e.g. `Q:1/4=120` or `Q:Moderato` |
|------|-----------------------------------------|

<details>
<summary><strong>Commonly Used Fields</strong></summary>

| Field | Description |
|-------|-------------|
| `C:`  | Composer |
| `O:`  | Origin or country of tune |
| `R:`  | Rhythm or tune type (e.g., `Reel`, `Jig`, `Hornpipe`) |
| `S:`  | Source or transcriber |
| `Z:`  | Transcription notes or transcriber's name |
| `N:`  | Notes about the piece |
| `P:`  | Parts or structure (e.g., `AB`, `AABB`) |
| `V:`  | Voice — used for multi-voice songs (e.g., `V:1`, `V:2`) |
| `B:`  | Book reference |
| `D:`  | Discography or audio recording reference |
| `F:`  | File reference (e.g., associated audio or image) |
| `G:`  | Group or genre |
| `H:`  | History of the tune |
| `I:`  | Instruction for layout, e.g. `I:linebreak` |
| `w:`  | Lyrics (must follow music line, lowercase `w`) |
</details>

####
## Music Body

After the header, the music is written in a compact format using notes, measures (`|`), rests (`z`), and voices (`[V:1]`).

```abc
X:1
T:Example Tune
M:4/4
K:C
C D E F | G A B c |
```



