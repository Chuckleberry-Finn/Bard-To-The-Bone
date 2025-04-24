import os

# Base directory where the sound files are located
sound_dir = os.path.join("Contents", "mods", "BardToTheBone", "common", "media", "sound")

# Paths to output the generated sound.script file
output_paths = [
    os.path.join("Contents", "mods", "BardToTheBone", "common", "media", "scripts", "sounds_BardToTheBone.txt"),
    os.path.join("Contents", "mods", "BardToTheBone", "media", "scripts", "sounds_BardToTheBone.txt"),
]

module_name = "BardToTheBone"
category_base = "BardInstrument"
supported_extensions = {".ogg", ".mid"}  # Add more if needed

# Walk through all subdirectories under sound_dir
sounds = []
for root, dirs, files in os.walk(sound_dir):
    for file in files:
        ext = os.path.splitext(file)[1].lower()
        if ext in supported_extensions:
            rel_path = os.path.relpath(os.path.join(root, file), sound_dir).replace("\\", "/")
            note_name = os.path.splitext(file)[0]
            instrument = os.path.basename(os.path.dirname(os.path.join(root, file)))
            sound_name = f"{instrument}_{note_name}"
            category = f"{category_base}_{instrument}"
            sounds.append((sound_name, category, rel_path))

# Write to each output path with correct prefix
for path in output_paths:
    lines = [f"module {module_name} {{\n"]
    prefix = "common/media/sound" if "common" not in path else "media/sound"

    for sound_name, category, rel_path in sounds:
        lines.append(f"    sound {sound_name} {{\n"
                     f"        category = {category}, is3D = true,\n"
                     f"        clip {{ file = {prefix}/{rel_path}, }} }}\n")

    lines.append("}")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines))

print("✅ sound.script generated with multi-format support.")