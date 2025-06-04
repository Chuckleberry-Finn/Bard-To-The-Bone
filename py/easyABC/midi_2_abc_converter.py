import os
import sys
import subprocess

def ensure_libs():
    for lib in ["tkinter", "tkinterdnd2"]:
        try:
            __import__(lib)
        except ImportError:
            print(f"Installing {lib}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", lib])

ensure_libs()

import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from tkinterdnd2 import DND_FILES, TkinterDnD
from pathlib import Path
import webbrowser


# === Paths ===
script_dir = Path.cwd()
midi2abc_path = script_dir / 'midi2abc.py'
output_dir = script_dir / 'convertedABC'
output_dir.mkdir(exist_ok=True)

# === Conversion Logic ===
def convert_midi_files(files):
    log_box.delete("1.0", tk.END)
    midi_files = [f for f in files if f.lower().endswith(('.mid', '.midi'))]
    if not midi_files:
        messagebox.showinfo("No MIDI Files", "No valid MIDI files were selected.")
        return

    for midi_file in midi_files:
        midi_path = Path(midi_file)
        output_file = output_dir / (midi_path.stem + '.abc')
        try:
            result = subprocess.run([
                sys.executable, str(midi2abc_path),
                '-f', str(midi_path),
                '-o', str(output_file)
            ], capture_output=True, text=True, check=True)
            log_box.insert(tk.END, f"\u2705 {output_file.name}\n")
        except subprocess.CalledProcessError as e:
            log_box.insert(tk.END, f"\u274C {midi_path.name} failed:\n{e.stderr or e.stdout}\n")
    log_box.see(tk.END)

# === GUI Setup ===
def open_folder():
    webbrowser.open(str(output_dir.resolve()))

def select_folder():
    folder = filedialog.askdirectory()
    if folder:
        midi_files = list(Path(folder).glob('*.mid')) + list(Path(folder).glob('*.midi'))
        convert_midi_files([str(f) for f in midi_files])

def select_files():
    files = filedialog.askopenfilenames(filetypes=[("MIDI files", "*.mid *.midi")])
    if files:
        convert_midi_files(files)

def on_drop(event):
    dropped_files = root.tk.splitlist(event.data)
    convert_midi_files(dropped_files)

# === TkinterDnD GUI ===
root = TkinterDnD.Tk()
root.title("MIDI to ABC Converter")
root.geometry("640x460")
root.configure(bg="#2e2e2e")

style = ttk.Style()
style.theme_use("default")
style.configure("TButton", background="#444", foreground="white", font=('Segoe UI', 10))
style.configure("TLabel", background="#2e2e2e", foreground="white", font=('Segoe UI', 10))

ttk.Label(root, text="Drop MIDI files here or use the buttons below").pack(pady=10)

# Drop area
drop_frame = tk.Label(root, text="Drop Files Here", bg="#3c3c3c", fg="white", relief="groove", height=4)
drop_frame.pack(fill="x", padx=20, pady=10)
drop_frame.drop_target_register(DND_FILES)
drop_frame.dnd_bind("<<Drop>>", on_drop)

# Button container (horizontal)
button_frame = tk.Frame(root, bg="#2e2e2e")
button_frame.pack(pady=10)

ttk.Button(button_frame, text="Select Files", command=select_files).pack(side="left", padx=5)
ttk.Button(button_frame, text="Select Folder", command=select_folder).pack(side="left", padx=5)
ttk.Button(button_frame, text="Open Output Folder", command=open_folder).pack(side="left", padx=5)

# Log box
log_box = tk.Text(root, height=10, bg="#1e1e1e", fg="lightgray", insertbackground="white")
log_box.pack(fill="both", expand=True, padx=10, pady=10)

root.mainloop()