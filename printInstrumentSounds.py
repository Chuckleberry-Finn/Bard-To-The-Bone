import os

def print_tree(startpath, prefix=""):
    entries = os.listdir(startpath)
    entries.sort()
    for idx, entry in enumerate(entries):
        path = os.path.join(startpath, entry)
        is_last = idx == len(entries) - 1
        connector = "└── " if is_last else "├── "

        print(prefix + connector + entry)

        if os.path.isdir(path):
            extension = "    " if is_last else "│   "
            print_tree(path, prefix + extension)

if __name__ == "__main__":
    # This assumes the script is placed inside 'Bard-To-The-Bone' folder
    base_dir = os.path.join(
        "Contents", "mods", "BardToTheBone", "common", "media", "sound", "instruments"
    )

    if not os.path.exists(base_dir):
        print(f"Directory not found: {base_dir}")
    else:
        print(f"Instrument Tree from '{base_dir}':\n")
        print_tree(base_dir)
