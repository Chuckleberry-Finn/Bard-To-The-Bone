![image](./images/githubBanner.png)
<br>

#### [**Bard-To-The-Bone**](https://steamcommunity.com/sharedfiles/filedetails/?id=3484029638) is a Project Zomboid mod that lets players perform music using ABC notation, with support for all vanilla instruments and custom ones. Click here to visit the [Steam Workshop Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3484029638).

[![PZ Modding Community](https://raw.githubusercontent.com/Chuckleberry-Finn/chuckImages/main/PZmodCommBanner2.png)](https://discord.gg/SReMnbV4V7)

[![Ko-fi](https://raw.githubusercontent.com/ChuckTheSheep/chuckImages/main/kofi.png)](https://ko-fi.com/chuckleberryfinn)


### Disclaimers:
1. I am not a musically inclined person, so there's probably obvious mistakes made / issues with this system. If you're expecting a high fidelity experience this mod is not for you.
2. How Project Zomboid handles threads, framerates, and ticks can impact timings and playback may suffer because of this.
<br><br>

### What is ABC Notation?

[ABC notation](https://en.wikipedia.org/wiki/ABC_notation) is a simple, text-based music format using letters and numbers to represent notes, rhythms, and other musical elements. It's designed to easily write and share music, especially melodies, without needing specialized music software.

**Notable Games that use ABC Notation Music Systems:**
- The Lord of the Rings Online (LOTRO)
- Starbound
- UnReal World
- Wurm Online
- Spacestation 13
<br><br>

### [Bard to The Bone Song Library](./Contents/mods/BardToTheBone/common/media/SONGLIBRARY_README.MD)
**Collection of 780+ songs ready to be played in-game.**<br>
*<sup>Modified from the [Starbound Song Pack](https://github.com/luxx/sbsp)</sup>*
<br><br>

### How to Add Your Own Songs (Step by Step)

**1. Get a song**
- **Already in ABC?** Copy the text from a site like [abcnotation.com](https://abcnotation.com/) and skip to step 3.
- **Have a MIDI file?** Find one on a site like [freemidi.org](https://freemidi.org/), or use your own, and go to step 2.

**2. Convert the MIDI to ABC**
- **Easiest:** open the [Online MIDI to ABC Tool](https://michaeleskin.com/tools/midi2abc/midi2abc.html), load the MIDI and copy the ABC text it gives you.
- **Offline:** drag the MIDI onto [Midi2ABC.exe](https://github.com/Chuckleberry-Finn/Bard-To-The-Bone/releases/tag/Midi2ABC). The `.abc` file appears next to the exe.<br>
<sup>Midi2ABC puts every instrument into one track. For a band song where each player picks their own part, use [easyABC](https://github.com/jwdj/EasyABC) instead, which keeps the instruments as separate voices (`V:1`, `V:2`, ...).</sup>

**3. Check it sounds right (optional)**
- Paste the ABC into the [Online ABC Player and Editor](https://abc.rectanglered.com/) and press play. Fix anything odd here before taking it in-game.

**4. Put it in the game** (either way works)
- **In-game:** equip an instrument, open its song window, click the arrow at the start of the button row to open the editor, press **New**, paste the ABC and press **Save**.
- **As a file:** save the text as a `.txt` or `.abc` file in `Zomboid/Lua/BardToTheBoneSongLibrary/`<br>
<sup>(on Windows: `C:/Users/<you>/Zomboid/Lua/BardToTheBoneSongLibrary/`)</sup>, then press **Reload Songs** in the song window's gear menu.

**5. Play it**
- Pick the song from the list and press **Play**.
- If it has several parts, the voice button next to Play lets you pick one. Leave it on **All** to play the whole song.
- In multiplayer, start the same song as someone nearby and you'll join in, in time.

**If something's off**
- **Too fast or too slow:** change or add the `Q:` line, e.g. `Q:1/4=120` (bigger is faster).
- **Wrong name in the list:** the list shows `C:` (artist) and `T:` (title) as "Artist - Title".
- **Nothing plays:** make sure the header has `X:`, `T:` and `K:` lines and the notes come after `K:`.
- **A big pile of notes on one instrument:** that MIDI had every instrument merged; convert it with easyABC to keep the parts separate.

<sup>The in-game **Song Guide** button (gear menu) opens this page.</sup>
<br><br>

**Useful Links:**

**[Online ABC Player and Editor](https://abc.rectanglered.com/)**<br>
<sup>An online interface for playing and editing ABC notations.</sup>

**[freemidi.org](https://freemidi.org/)**<br>
<sup>A collection of MIDIs you can use an ABC converter on.</sup>

**[Online MIDI to ABC Tool](https://michaeleskin.com/tools/midi2abc/midi2abc.html)**<br>
<sup>Convert MIDIs of songs to ABC for use in the game.</sup>

**[Midi2ABC.exe](https://github.com/Chuckleberry-Finn/Bard-To-The-Bone/releases/tag/Midi2ABC)**<br>
<sup>MIDI to ABC converter executable, supports selecting file(s) and drag and drop.<br>
**Note: This uses a modified easyABC script, and produces everything in a single track.**<br>
*All files are generated in folder alongside the exe.*</sup>

**[easyABC converter](https://github.com/jwdj/EasyABC)**<br>
<sup>Great program for local conversions,<br>
**Note: by default it produces songs in multiple voices/performers** which requires splitting the tracks up manually.</sup>

**[abcnotation.com](https://abcnotation.com/)**<br>
<sup>A great website that features all things ABC-notation, includes: thousands of public-domain songs, links to various related programs and information.</sup>

**[onlinesequencer](https://onlinesequencer.net/)**<br>
<sup>Online MIDI sequencer/player for creating ones own songs, also hosts user generated content.</sup>

<br><br>


**Credits:**
- Music Note Sounds - Generated using fluidSynth & FluidR3_GM.sf2, [SS13-TG](https://github.com/tgstation/tgstation)
- Default Songs - [abcnotation](https://abcnotation.com) & [@duVillage](https://www.youtube.com/@duVillage)
- Song Library - [Luxx's Starbound Song Pack](https://github.com/luxx/sbsp)
- CrystalChris - Animations
- [Shurutsue](https://github.com/Shurutsue) for helping with troubleshooting/research.
###
