import os
import re

###########################################################################
# This script renames the file to match the T(tile) line within the file. #
###########################################################################

def clean_title_for_filename(title):
    # Remove timestamps like (M:S) or (MM:SS)
    title = re.sub(r'\(\d{1,2}:\d{2}\)', '', title)
    # Remove characters illegal for filenames across platforms
    title = re.sub(r'[<>:"/\\|?*\n\r]', '', title)
    title = title.strip().replace(' ', '_')
    return title

def find_title_in_abc(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith('T:'):
                return line[2:].strip()
    return None

def rename_abc_files_in_folder(folder_path):
    for filename in os.listdir(folder_path):
        if filename.lower().endswith('.abc'):
            full_path = os.path.join(folder_path, filename)
            title = find_title_in_abc(full_path)
            if title:
                clean_title = clean_title_for_filename(title)
                new_filename = clean_title + '.abc'
                new_full_path = os.path.join(folder_path, new_filename)
                if not os.path.exists(new_full_path):
                    os.rename(full_path, new_full_path)
                    print(f"Renamed: {filename} -> {new_filename}")
                else:
                    print(f"Skipped (exists): {new_filename}")
            else:
                print(f"No title found in {filename}")

if __name__ == '__main__':
    # Use the current script's location to resolve relative path
    base_dir = os.path.dirname(os.path.abspath(__file__))
    song_library_path = os.path.join(base_dir, 'songLibrary')
    rename_abc_files_in_folder(song_library_path)
