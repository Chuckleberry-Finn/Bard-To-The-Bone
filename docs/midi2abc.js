(function (root) {
    "use strict";

    var GM_PROGRAMS = [
        "Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano", "Honky-tonk Piano", "Electric Piano 1", "Electric Piano 2", "Harpsichord", "Clavinet",
        "Celesta", "Glockenspiel", "Music Box", "Vibraphone", "Marimba", "Xylophone", "Tubular Bells", "Dulcimer",
        "Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ", "Reed Organ", "Accordion", "Harmonica", "Tango Accordion",
        "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)", "Electric Guitar (jazz)", "Electric Guitar (clean)", "Electric Guitar (muted)", "Overdriven Guitar", "Distortion Guitar", "Guitar Harmonics",
        "Acoustic Bass", "Electric Bass (finger)", "Electric Bass (pick)", "Fretless Bass", "Slap Bass 1", "Slap Bass 2", "Synth Bass 1", "Synth Bass 2",
        "Violin", "Viola", "Cello", "Contrabass", "Tremolo Strings", "Pizzicato Strings", "Orchestral Harp", "Timpani",
        "String Ensemble 1", "String Ensemble 2", "Synth Strings 1", "Synth Strings 2", "Choir Aahs", "Voice Oohs", "Synth Voice", "Orchestra Hit",
        "Trumpet", "Trombone", "Tuba", "Muted Trumpet", "French Horn", "Brass Section", "Synth Brass 1", "Synth Brass 2",
        "Soprano Sax", "Alto Sax", "Tenor Sax", "Baritone Sax", "Oboe", "English Horn", "Bassoon", "Clarinet",
        "Piccolo", "Flute", "Recorder", "Pan Flute", "Blown Bottle", "Shakuhachi", "Whistle", "Ocarina",
        "Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)", "Lead 4 (chiff)", "Lead 5 (charang)", "Lead 6 (voice)", "Lead 7 (fifths)", "Lead 8 (bass + lead)",
        "Pad 1 (new age)", "Pad 2 (warm)", "Pad 3 (polysynth)", "Pad 4 (choir)", "Pad 5 (bowed)", "Pad 6 (metallic)", "Pad 7 (halo)", "Pad 8 (sweep)",
        "FX 1 (rain)", "FX 2 (soundtrack)", "FX 3 (crystal)", "FX 4 (atmosphere)", "FX 5 (brightness)", "FX 6 (goblins)", "FX 7 (echoes)", "FX 8 (sci-fi)",
        "Sitar", "Banjo", "Shamisen", "Koto", "Kalimba", "Bagpipe", "Fiddle", "Shanai",
        "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock", "Taiko Drum", "Melodic Tom", "Synth Drum", "Reverse Cymbal",
        "Guitar Fret Noise", "Breath Noise", "Seashore", "Bird Tweet", "Telephone Ring", "Helicopter", "Applause", "Gunshot"
    ];

    var DRUM_CHANNEL = 9;
    var SHARP_SPELLING = [["C", ""], ["C", "^"], ["D", ""], ["D", "^"], ["E", ""], ["F", ""], ["F", "^"], ["G", ""], ["G", "^"], ["A", ""], ["A", "^"], ["B", ""]];
    var FLAT_SPELLING = [["C", ""], ["D", "_"], ["D", ""], ["E", "_"], ["E", ""], ["F", ""], ["G", "_"], ["G", ""], ["A", "_"], ["A", ""], ["B", "_"], ["B", ""]];
    var SHARP_ORDER = ["F", "C", "G", "D", "A", "E", "B"];
    var FLAT_ORDER = ["B", "E", "A", "D", "G", "C", "F"];
    var MAJOR_NAMES = { "-7": "Cb", "-6": "Gb", "-5": "Db", "-4": "Ab", "-3": "Eb", "-2": "Bb", "-1": "F", "0": "C", "1": "G", "2": "D", "3": "A", "4": "E", "5": "B", "6": "F#", "7": "C#" };
    var MINOR_NAMES = { "-7": "Abm", "-6": "Ebm", "-5": "Bbm", "-4": "Fm", "-3": "Cm", "-2": "Gm", "-1": "Dm", "0": "Am", "1": "Em", "2": "Bm", "3": "F#m", "4": "C#m", "5": "G#m", "6": "D#m", "7": "A#m" };
    var MAJOR_PROFILE = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
    var MINOR_PROFILE = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];
    var MAJOR_TONIC_FIFTHS = [0, -5, 2, -3, 4, -1, 6, 1, -4, 3, -2, 5];
    var MINOR_TONIC_FIFTHS = [-3, 4, -1, -6, 1, -4, 3, -2, 5, 0, -5, 2];

    function gcd(a, b) {
        a = Math.abs(a);
        b = Math.abs(b);
        while (b) {
            var t = a % b;
            a = b;
            b = t;
        }
        return a;
    }

    function Reader(bytes) {
        this.bytes = bytes;
        this.pos = 0;
    }

    Reader.prototype.eof = function () { return this.pos >= this.bytes.length; };
    Reader.prototype.u8 = function () {
        if (this.pos >= this.bytes.length) throw new Error("Unexpected end of MIDI data");
        return this.bytes[this.pos++];
    };
    Reader.prototype.u16 = function () { return (this.u8() << 8) | this.u8(); };
    Reader.prototype.u32 = function () { return ((this.u8() << 24) >>> 0) + (this.u8() << 16) + (this.u8() << 8) + this.u8(); };
    Reader.prototype.ascii = function (n) {
        var s = "";
        for (var i = 0; i < n; i++) s += String.fromCharCode(this.u8());
        return s;
    };
    Reader.prototype.vlq = function () {
        var value = 0;
        for (var i = 0; i < 4; i++) {
            var b = this.u8();
            value = (value << 7) | (b & 0x7f);
            if (!(b & 0x80)) return value;
        }
        return value;
    };
    Reader.prototype.text = function (n) {
        var raw = this.bytes.subarray(this.pos, this.pos + n);
        this.pos += n;
        var s = "";
        for (var i = 0; i < raw.length; i++) s += String.fromCharCode(raw[i]);
        try { return decodeURIComponent(escape(s)); } catch (e) { return s; }
    };

    function parseTrack(reader, end) {
        var events = [];
        var tick = 0;
        var status = 0;
        while (reader.pos < end) {
            tick += reader.vlq();
            var first = reader.u8();
            if (first === 0xff) {
                var metaType = reader.u8();
                var length = reader.vlq();
                var dataStart = reader.pos;
                if (metaType === 0x51 && length >= 3) {
                    events.push({ tick: tick, type: "tempo", usPerQuarter: (reader.u8() << 16) | (reader.u8() << 8) | reader.u8() });
                } else if (metaType === 0x58 && length >= 2) {
                    var nn = reader.u8();
                    var dd = reader.u8();
                    events.push({ tick: tick, type: "timeSignature", numerator: nn, denominator: Math.pow(2, dd) });
                } else if (metaType === 0x59 && length >= 2) {
                    var sf = reader.u8();
                    if (sf > 127) sf -= 256;
                    events.push({ tick: tick, type: "keySignature", fifths: sf, minor: reader.u8() === 1 });
                } else if (metaType === 0x03) {
                    events.push({ tick: tick, type: "trackName", text: reader.text(length) });
                } else if (metaType === 0x04) {
                    events.push({ tick: tick, type: "instrumentName", text: reader.text(length) });
                } else if (metaType === 0x2f) {
                    reader.pos = dataStart + length;
                    break;
                }
                reader.pos = dataStart + length;
                continue;
            }
            if (first === 0xf0 || first === 0xf7) {
                reader.pos += reader.vlq();
                continue;
            }
            var data1;
            if (first & 0x80) {
                status = first;
                data1 = reader.u8();
            } else {
                if (!status) throw new Error("Running status without a previous status byte");
                data1 = first;
            }
            var kind = status & 0xf0;
            var channel = status & 0x0f;
            if (kind === 0xc0 || kind === 0xd0) {
                if (kind === 0xc0) events.push({ tick: tick, type: "program", channel: channel, program: data1 });
                continue;
            }
            var data2 = reader.u8();
            if (kind === 0x90 && data2 > 0) {
                events.push({ tick: tick, type: "noteOn", channel: channel, pitch: data1, velocity: data2 });
            } else if (kind === 0x80 || kind === 0x90) {
                events.push({ tick: tick, type: "noteOff", channel: channel, pitch: data1 });
            }
        }
        reader.pos = end;
        return events;
    }

    function parseMidi(input) {
        var bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
        var reader = new Reader(bytes);
        var riff = reader.ascii(4);
        if (riff === "RIFF") {
            reader.pos = 20;
            riff = reader.ascii(4);
        }
        if (riff !== "MThd") throw new Error("Not a MIDI file (missing MThd header)");
        var headerLength = reader.u32();
        var headerStart = reader.pos;
        var format = reader.u16();
        var trackCount = reader.u16();
        var division = reader.u16();
        reader.pos = headerStart + headerLength;

        var ppq = division;
        var smpte = false;
        if (division & 0x8000) {
            var fps = 256 - (division >> 8);
            ppq = fps * (division & 0xff);
            smpte = true;
        }

        var tracks = [];
        while (!reader.eof() && tracks.length < trackCount) {
            if (reader.bytes.length - reader.pos < 8) break;
            var id = reader.ascii(4);
            var length = reader.u32();
            var end = Math.min(reader.pos + length, bytes.length);
            if (id === "MTrk") {
                tracks.push(parseTrack(reader, end));
            } else {
                reader.pos = end;
            }
        }
        if (smpte) {
            tracks.unshift([{ tick: 0, type: "tempo", usPerQuarter: 1000000 }]);
        }
        return { format: format, ppq: ppq, tracks: tracks };
    }

    function collectSong(midi, options) {
        var tempos = [];
        var signatures = [];
        var keys = [];
        var groups = {};
        var groupOrder = [];
        var lastTick = 0;

        midi.tracks.forEach(function (events, trackIndex) {
            var trackName = "";
            var instrumentName = "";
            var programs = {};
            var open = {};
            events.forEach(function (event) {
                lastTick = Math.max(lastTick, event.tick);
                if (event.type === "tempo") tempos.push({ tick: event.tick, usPerQuarter: event.usPerQuarter, order: tempos.length });
                else if (event.type === "timeSignature") signatures.push({ tick: event.tick, numerator: event.numerator, denominator: event.denominator, order: signatures.length });
                else if (event.type === "keySignature") keys.push(event);
                else if (event.type === "trackName" && !trackName) trackName = event.text.trim();
                else if (event.type === "instrumentName" && !instrumentName) instrumentName = event.text.trim();
                else if (event.type === "program") programs[event.channel] = programs[event.channel] === undefined ? event.program : programs[event.channel];
                else if (event.type === "noteOn" || event.type === "noteOff") {
                    var isDrum = event.channel === DRUM_CHANNEL;
                    if (isDrum && !options.includeDrums) return;
                    var groupKey;
                    if (isDrum) groupKey = options.split === "track" ? "drums:" + trackIndex : "drums";
                    else if (options.split === "single") groupKey = "all";
                    else if (options.split === "channel") groupKey = "ch:" + event.channel;
                    else groupKey = "t" + trackIndex + ":ch" + event.channel;
                    var group = groups[groupKey];
                    if (!group) {
                        group = groups[groupKey] = { key: groupKey, isDrum: isDrum, notes: [], trackIndex: trackIndex, channel: event.channel, trackName: "", instrumentName: "", program: undefined };
                        groupOrder.push(groupKey);
                    }
                    var openKey = groupKey + "|" + event.channel + "|" + event.pitch;
                    var stack = open[openKey];
                    if (event.type === "noteOn") {
                        if (stack && stack.length) {
                            var previous = stack.shift();
                            previous.end = event.tick;
                        }
                        var note = { start: event.tick, end: null, pitch: event.pitch, velocity: event.velocity, group: group, channel: event.channel };
                        group.notes.push(note);
                        open[openKey] = [note];
                    } else if (stack && stack.length) {
                        stack.shift().end = event.tick;
                    }
                }
            });
            Object.keys(open).forEach(function (openKey) {
                open[openKey].forEach(function (note) { note.end = Math.max(note.start + 1, lastTick); });
            });
            groupOrder.forEach(function (groupKey) {
                var group = groups[groupKey];
                if (group.trackIndex !== trackIndex && group.key !== "all" && group.key !== "drums" && group.key.indexOf("ch:") !== 0) return;
                if (!group.trackName && trackName) group.trackName = trackName;
                if (!group.instrumentName && instrumentName) group.instrumentName = instrumentName;
                if (group.program === undefined && programs[group.channel] !== undefined) group.program = programs[group.channel];
            });
        });

        groupOrder.forEach(function (groupKey) {
            groups[groupKey].notes.forEach(function (note) { if (note.end === null) note.end = Math.max(note.start + 1, lastTick); });
        });

        tempos.sort(function (a, b) { return a.tick - b.tick || a.order - b.order; });
        signatures.sort(function (a, b) { return a.tick - b.tick || a.order - b.order; });

        return {
            ppq: midi.ppq,
            tempos: tempos,
            signatures: signatures,
            keys: keys.sort(function (a, b) { return a.tick - b.tick; }),
            groups: groupOrder.map(function (k) { return groups[k]; }).filter(function (g) { return g.notes.length > 0; }),
            lastTick: lastTick
        };
    }

    function quantizeNotes(song, gridPerQuarter) {
        var scale = gridPerQuarter > 0 ? gridPerQuarter / song.ppq : 1;
        function snap(tick) { return Math.round(tick * scale); }
        if (gridPerQuarter > 0) song.ppq = gridPerQuarter;
        song.tempos.forEach(function (tempo) { tempo.tick = snap(tempo.tick); });
        song.signatures.forEach(function (signature) { signature.tick = snap(signature.tick); });
        song.keys.forEach(function (key) { key.tick = snap(key.tick); });
        song.groups.forEach(function (group) {
            var seen = {};
            var kept = [];
            group.notes.forEach(function (note) {
                var start = snap(note.start);
                var end = Math.max(start + 1, snap(note.end));
                var id = start + ":" + note.pitch;
                if (seen[id]) {
                    seen[id].end = Math.max(seen[id].end, end);
                    return;
                }
                var copy = { start: start, end: end, pitch: note.pitch, velocity: note.velocity || 64 };
                seen[id] = copy;
                kept.push(copy);
            });
            kept.sort(function (a, b) { return a.start - b.start || a.pitch - b.pitch; });
            group.notes = kept;
        });
    }

    function tempoChanges(song) {
        var result = [];
        song.tempos.forEach(function (tempo) {
            var tick = tempo.tick;
            var bpm = 60000000 / tempo.usPerQuarter;
            if (result.length && result[result.length - 1].tick === tick) result[result.length - 1].bpm = bpm;
            else result.push({ tick: tick, bpm: bpm });
        });
        if (!result.length || result[0].tick > 0) result.unshift({ tick: 0, bpm: 120 });
        var written = [];
        result.forEach(function (change) {
            var q = formatTempo(change.bpm);
            if (written.length && written[written.length - 1].text === q) return;
            if (written.length && written[written.length - 1].tick === change.tick) written[written.length - 1].text = q;
            else written.push({ tick: change.tick, text: q });
        });
        return written;
    }

    function formatTempo(bpm) {
        var best = null;
        var units = [4, 8, 16];
        for (var i = 0; i < units.length; i++) {
            var value = bpm * units[i] / 4;
            var rounded = Math.max(1, Math.round(value));
            var error = Math.abs(rounded - value) / value;
            if (!best || error < best.error) best = { unit: units[i], value: rounded, error: error };
            if (error <= 0.001) break;
        }
        return "1/" + best.unit + "=" + best.value;
    }

    function barTicks(song, endTick) {
        var signatures = song.signatures.slice();
        if (!signatures.length || signatures[0].tick > 0) signatures.unshift({ tick: 0, numerator: 4, denominator: 4 });
        var index = 0;
        while (index + 1 < signatures.length && signatures[index + 1].tick <= 0) index++;
        var current = signatures[index];
        var meters = [{ tick: 0, text: current.numerator + "/" + current.denominator }];
        var bars = [];
        var tick = 0;
        while (tick < endTick) {
            var next = tick + Math.max(1, Math.round(song.ppq * 4 * current.numerator / current.denominator));
            if (index + 1 < signatures.length && signatures[index + 1].tick > tick && signatures[index + 1].tick < next) next = signatures[index + 1].tick;
            tick = next;
            bars.push(tick);
            while (index + 1 < signatures.length && signatures[index + 1].tick <= tick) {
                index++;
                current = signatures[index];
                var text = current.numerator + "/" + current.denominator;
                if (meters[meters.length - 1].text !== text) meters.push({ tick: tick, text: text });
            }
        }
        return { bars: bars, meters: meters };
    }

    function detectKey(song) {
        if (song.keys.length) return { fifths: Math.max(-7, Math.min(7, song.keys[0].fifths)), minor: song.keys[0].minor };
        var weights = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        var total = 0;
        song.groups.forEach(function (group) {
            if (group.isDrum) return;
            group.notes.forEach(function (note) {
                var w = note.end - note.start;
                weights[note.pitch % 12] += w;
                total += w;
            });
        });
        if (!total) return { fifths: 0, minor: false };
        function correlate(profile, tonic) {
            var meanW = total / 12;
            var meanP = profile.reduce(function (a, b) { return a + b; }, 0) / 12;
            var num = 0, dw = 0, dp = 0;
            for (var i = 0; i < 12; i++) {
                var w = weights[(tonic + i) % 12] - meanW;
                var p = profile[i] - meanP;
                num += w * p;
                dw += w * w;
                dp += p * p;
            }
            return dw && dp ? num / Math.sqrt(dw * dp) : 0;
        }
        var best = { score: -2, fifths: 0, minor: false };
        for (var tonic = 0; tonic < 12; tonic++) {
            var major = correlate(MAJOR_PROFILE, tonic);
            if (major > best.score) best = { score: major, fifths: MAJOR_TONIC_FIFTHS[tonic], minor: false };
            var minor = correlate(MINOR_PROFILE, tonic);
            if (minor > best.score) best = { score: minor, fifths: MINOR_TONIC_FIFTHS[tonic], minor: true };
        }
        return { fifths: best.fifths, minor: best.minor };
    }

    function keyAccidentals(fifths) {
        var acc = {};
        if (fifths > 0) for (var i = 0; i < fifths; i++) acc[SHARP_ORDER[i]] = "^";
        if (fifths < 0) for (var j = 0; j < -fifths; j++) acc[FLAT_ORDER[j]] = "_";
        return acc;
    }

    function Speller(fifths) {
        this.table = fifths < 0 ? FLAT_SPELLING : SHARP_SPELLING;
        this.key = keyAccidentals(fifths);
        this.memory = {};
    }

    Speller.prototype.resetBar = function () { this.memory = {}; };
    Speller.prototype.spell = function (pitch) {
        var spelling = this.table[((pitch % 12) + 12) % 12];
        var letter = spelling[0];
        var needed = spelling[1] || "=";
        var octave = Math.floor(pitch / 12) - 1;
        var memory = this.memory[octave] || (this.memory[octave] = {});
        var implied = memory[letter] || this.key[letter] || "=";
        var prefix = "";
        if (needed !== implied) {
            prefix = needed;
            memory[letter] = needed;
        }
        var name;
        if (octave >= 5) {
            name = letter.toLowerCase();
            for (var up = 5; up < octave; up++) name += "'";
        } else {
            name = letter;
            for (var down = 4; down > octave; down--) name += ",";
        }
        return prefix + name;
    };

    function Durations(ppq, unitDenominator) {
        this.ticksPerUnit = ppq * 4 / unitDenominator;
        this.ppq = ppq;
        this.unitDenominator = unitDenominator;
    }

    Durations.prototype.format = function (ticks) {
        var num = Math.round(ticks) * this.unitDenominator;
        var den = this.ppq * 4;
        var g = gcd(num, den);
        num /= g;
        den /= g;
        if (den === 1) return num === 1 ? "" : String(num);
        if (num === 1) return den === 2 ? "/" : "/" + den;
        return num + "/" + den;
    };

    function escapeName(name) {
        return String(name).replace(/"/g, "'").replace(/%/g, "").replace(/[\r\n]+/g, " ").trim();
    }

    var LAYER_WORDS = ["detune", "detuned", "echo", "delay", "double", "doubled", "layer", "copy", "reverb", "chorus", "unison"];

    function labelGroups(groups, split) {
        var perTrack = {};
        groups.forEach(function (group) { if (!group.isDrum) perTrack[group.trackIndex] = (perTrack[group.trackIndex] || 0) + 1; });
        groups.forEach(function (group) {
            var name;
            var programName = group.program !== undefined ? GM_PROGRAMS[group.program] : "";
            var shared = split !== "track" || perTrack[group.trackIndex] > 1;
            if (group.isDrum) name = "Drums";
            else if (split === "single") name = "Melody";
            else if (shared) name = group.instrumentName && split === "track" ? group.instrumentName : (programName || group.trackName || ("Channel " + (group.channel + 1)));
            else name = group.trackName || group.instrumentName || programName || ("Channel " + (group.channel + 1));
            group.name = escapeName(name) || "Part";
            group.namedInMidi = !group.isDrum && split !== "single" && (name === group.trackName || name === group.instrumentName);
        });
    }

    function baseName(name) {
        var words = name.toLowerCase().replace(/[()\[\]_\-]+/g, " ").split(/\s+/).filter(function (w) { return w.length; });
        var changed = true;
        while (changed && words.length > 1) {
            changed = false;
            var last = words[words.length - 1];
            if (/^\d+$/.test(last) || LAYER_WORDS.indexOf(last) !== -1) {
                words.pop();
                changed = true;
            }
        }
        return words.join(" ");
    }

    function averageVelocity(group) {
        var total = 0;
        group.notes.forEach(function (note) { total += note.velocity || 64; });
        return group.notes.length ? total / group.notes.length : 0;
    }

    function copyOf(copy, original) {
        if (copy.isDrum !== original.isDrum || !copy.notes.length || !original.notes.length) return false;
        var small = Math.min(copy.notes.length, original.notes.length);
        var large = Math.max(copy.notes.length, original.notes.length);
        if (small < large * 0.9) return false;
        var lookup = {};
        original.notes.forEach(function (note) { lookup[note.start + ":" + note.pitch] = true; });
        var shifts = [0, copy.notes[0].start - original.notes[0].start];
        return shifts.some(function (shift) {
            if (shift < 0) return false;
            var hits = 0;
            copy.notes.forEach(function (note) { if (lookup[(note.start - shift) + ":" + note.pitch]) hits++; });
            return hits >= copy.notes.length * 0.9;
        });
    }

    function dropCopies(groups) {
        var order = groups.slice().sort(function (a, b) {
            return averageVelocity(b) - averageVelocity(a) || a.notes[0].start - b.notes[0].start;
        });
        var kept = [];
        order.forEach(function (group) {
            if (!kept.some(function (original) { return copyOf(group, original); })) kept.push(group);
        });
        return groups.filter(function (group) { return kept.indexOf(group) !== -1; });
    }

    function mergeGroups(groups, keyOf) {
        var byKey = {};
        var merged = [];
        groups.forEach(function (group) {
            var key = (group.isDrum ? "drum:" : "part:") + keyOf(group);
            var existing = byKey[key];
            if (existing) {
                existing.notes = existing.notes.concat(group.notes);
                existing.needsSort = true;
                return;
            }
            byKey[key] = group;
            merged.push(group);
        });
        merged.forEach(function (group) {
            if (!group.needsSort) return;
            group.needsSort = false;
            var seen = {};
            var kept = [];
            group.notes.forEach(function (note) {
                var id = note.start + ":" + note.pitch;
                if (seen[id]) {
                    seen[id].end = Math.max(seen[id].end, note.end);
                    return;
                }
                seen[id] = note;
                kept.push(note);
            });
            kept.sort(function (a, b) { return a.start - b.start || a.pitch - b.pitch; });
            group.notes = kept;
        });
        return merged;
    }

    function finishGroups(groups, split, combine) {
        labelGroups(groups, split);
        if (combine) {
            groups = dropCopies(groups);
            groups.forEach(function (group) {
                if (!group.namedInMidi) {
                    group.mergeKey = group.name.toLowerCase();
                    return;
                }
                var base = baseName(group.name);
                var main = groups.filter(function (other) { return other.namedInMidi && other.name.toLowerCase() === base; })[0];
                group.mergeKey = main ? base : group.name.toLowerCase();
                if (main) group.mergeName = main.name;
                if (!main && base !== group.name.toLowerCase()) {
                    var siblings = groups.filter(function (other) { return other.namedInMidi && baseName(other.name) === base; });
                    if (siblings.length > 1) {
                        group.mergeKey = base;
                        var shortest = siblings.reduce(function (a, b) { return a.name.length <= b.name.length ? a : b; });
                        group.mergeName = shortest.name;
                    }
                }
            });
            groups = mergeGroups(groups, function (group) { return group.mergeKey; });
            groups.forEach(function (group) { if (group.mergeName) group.name = group.mergeName; });
        } else {
            groups = mergeGroups(groups, function (group) { return group.name.toLowerCase(); });
        }
        var used = {};
        groups.forEach(function (group) {
            var name = group.name;
            var n = 2;
            while (used[name.toLowerCase()]) name = group.name + " " + n++;
            used[name.toLowerCase()] = true;
            group.name = name;
        });
        return groups;
    }

    function writeVoice(group, context) {
        var notes = group.notes;
        var speller = new Speller(context.key.fifths);
        var durations = context.durations;
        var points = {};
        var byStart = {};
        notes.forEach(function (note) {
            points[note.start] = true;
            (byStart[note.start] = byStart[note.start] || []).push(note);
        });
        var lastStart = notes.length ? notes[notes.length - 1].start : 0;
        var tempoAt = {};
        context.tempos.forEach(function (tempo) {
            if (tempo.tick > 0 && tempo.tick <= lastStart) {
                points[tempo.tick] = true;
                tempoAt[tempo.tick] = tempo.text;
            }
        });
        var meterAt = {};
        context.meters.forEach(function (meter) {
            if (meter.tick > 0) meterAt[meter.tick] = meter.text;
        });
        var barAt = {};
        context.bars.forEach(function (tick) {
            if (tick > 0 && tick <= lastStart) {
                points[tick] = true;
                barAt[tick] = true;
            }
        });
        points[0] = true;
        var sorted = Object.keys(points).map(Number).sort(function (a, b) { return a - b; });

        var lines = [];
        var line = [];
        var barsOnLine = 0;
        var pendingRest = 0;

        function flushRest() {
            if (pendingRest > 0) line.push("z" + durations.format(pendingRest));
            pendingRest = 0;
        }

        for (var i = 0; i < sorted.length; i++) {
            var tick = sorted[i];
            var next = i + 1 < sorted.length ? sorted[i + 1] : null;
            if (barAt[tick]) {
                flushRest();
                line.push("|");
                speller.resetBar();
                barsOnLine++;
                if (barsOnLine >= context.barsPerLine) {
                    lines.push(line.join(" "));
                    line = [];
                    barsOnLine = 0;
                }
            }
            if (meterAt[tick]) {
                flushRest();
                line.push("[M:" + meterAt[tick] + "]");
            }
            if (tempoAt[tick]) {
                flushRest();
                line.push("[Q:" + tempoAt[tick] + "]");
            }
            var starting = byStart[tick];
            if (!starting) {
                if (next !== null) pendingRest += next - tick;
                continue;
            }
            flushRest();
            var gap = next !== null ? next - tick : null;
            var shortest = Infinity;
            var parts = starting.map(function (note) {
                var length = note.end - note.start;
                shortest = Math.min(shortest, length);
                return speller.spell(note.pitch) + durations.format(length);
            });
            if (gap === null) {
                line.push(parts.length > 1 ? "[" + parts.join("") + "]" : parts[0]);
            } else if (shortest > gap) {
                line.push("[" + parts.join("") + "z" + durations.format(gap) + "]");
            } else {
                line.push(parts.length > 1 ? "[" + parts.join("") + "]" : parts[0]);
                if (shortest < gap) pendingRest += gap - shortest;
            }
        }
        flushRest();
        line.push("|]");
        lines.push(line.join(" "));
        return lines.filter(function (l) { return l.trim().length; }).join("\n");
    }

    function convert(input, options) {
        options = options || {};
        var settings = {
            title: options.title || "Untitled",
            split: options.split || "track",
            includeDrums: options.includeDrums !== false,
            grid: options.grid === undefined ? 24 : options.grid,
            unit: options.unit || 8,
            barsPerLine: options.barsPerLine || 4,
            minNotes: options.minNotes || 1,
            combineLayers: options.combineLayers !== false
        };
        var midi = input && input.tracks ? input : parseMidi(input);
        var song = collectSong(midi, settings);
        quantizeNotes(song, settings.grid);
        song.groups = song.groups.filter(function (group) { return group.notes.length >= settings.minNotes; });
        if (!song.groups.length) throw new Error("No notes found in this MIDI");

        var key = detectKey(song);
        var tempos = tempoChanges(song);
        var lastStart = 0;
        song.groups.forEach(function (group) {
            group.notes.forEach(function (note) { lastStart = Math.max(lastStart, note.end); });
        });
        var bars = barTicks(song, lastStart);
        song.groups = finishGroups(song.groups, settings.split, settings.combineLayers);

        var context = {
            key: key,
            tempos: tempos,
            bars: bars.bars,
            meters: bars.meters,
            durations: new Durations(song.ppq, settings.unit),
            barsPerLine: settings.barsPerLine
        };

        var keyName = (key.minor ? MINOR_NAMES : MAJOR_NAMES)[String(key.fifths)];
        var out = [];
        out.push("X:1");
        out.push("T:" + escapeName(settings.title));
        out.push("M:" + bars.meters[0].text);
        out.push("L:1/" + settings.unit);
        out.push("Q:" + tempos[0].text);
        out.push("K:" + keyName);
        var multiTempo = tempos.length > 1;
        var voices = [];
        var nextId = 1;
        song.groups.forEach(function (group) {
            if (nextId === 10) nextId++;
            var id = nextId++;
            out.push("V:" + id + ' name="' + group.name + '"');
            if (group.isDrum) out.push("%%MIDI channel 10");
            if (multiTempo) out.push("[Q:" + tempos[0].text + "]");
            out.push(writeVoice(group, context));
            voices.push({ id: String(id), name: group.name, notes: group.notes.length, isDrum: group.isDrum });
        });
        return { abc: out.join("\n") + "\n", voices: voices, key: keyName, tempo: tempos[0].text, tempoChanges: tempos.length - 1, meter: bars.meters[0].text };
    }

    var api = { parseMidi: parseMidi, convert: convert, formatTempo: formatTempo, GM_PROGRAMS: GM_PROGRAMS };
    if (typeof module !== "undefined" && module.exports) module.exports = api;
    else root.BttbMidi2Abc = api;
})(this);
