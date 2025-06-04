import sys
from pathlib import Path
from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QPushButton, QTextEdit,
    QVBoxLayout, QHBoxLayout, QFileDialog
)
from PyQt5.QtCore import Qt, QUrl
from PyQt5.QtGui import QDragEnterEvent, QDropEvent
import webbrowser
from midi2abc import midi_to_abc

class MidiToAbcConverter(QWidget):
    def __init__(self):
        super().__init__()

        self.script_dir = Path(sys.argv[0]).resolve().parent
        self.output_dir = self.script_dir / 'convertedABC'
        self.output_dir.mkdir(exist_ok=True)

        self.setWindowTitle("MIDI to ABC Converter")
        self.setAcceptDrops(True)
        self.setFixedSize(360, 480)
        self.setStyleSheet("background-color: #2e2e2e; color: white;")

        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout()

        self.label = QLabel("Drop MIDI files or folders here or use the buttons below")
        self.label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.label)

        self.drop_area = QLabel("\nDrop Files or Folders Here\n")
        self.drop_area.setStyleSheet("background-color: #3c3c3c; border: 1px solid #666; padding: 20px;")
        self.drop_area.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.drop_area)

        btn_layout = QHBoxLayout()
        self.select_btn = QPushButton("Select File(s)")
        self.select_btn.clicked.connect(self.select_files)
        btn_layout.addWidget(self.select_btn)

        self.open_folder_btn = QPushButton("Open Output Folder")
        self.open_folder_btn.clicked.connect(self.open_folder)
        btn_layout.addWidget(self.open_folder_btn)

        layout.addLayout(btn_layout)

        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)
        self.log_box.setStyleSheet("background-color: #1e1e1e; color: lightgray;")
        layout.addWidget(self.log_box)

        self.setLayout(layout)

    def log(self, text):
        self.log_box.append(text)
        self.log_box.verticalScrollBar().setValue(self.log_box.verticalScrollBar().maximum())

    def convert_midi_files(self, files):
        self.log_box.clear()
        midi_files = [str(f) for f in files if f.suffix.lower() in (".mid", ".midi")]

        if not midi_files:
            self.log("No valid MIDI files found.")
            return

        for midi_path in midi_files:
            midi_path = Path(midi_path)
            output_file = self.output_dir / (midi_path.stem + '.abc')
            try:
                abc_text = midi_to_abc(filename=str(midi_path), title=midi_path.stem)
                output_file.write_text(abc_text, encoding='utf-8')
                self.log(f"{output_file.name}")
            except Exception as e:
                self.log(f"{midi_path.name} failed:\n{e}")

    def select_files(self):
        files, _ = QFileDialog.getOpenFileNames(self, "Select MIDI files", "", "MIDI files (*.mid *.midi)")
        if files:
            self.convert_midi_files([Path(f) for f in files])

    def open_folder(self):
        webbrowser.open(str(self.output_dir.resolve()))

    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent):
        files = []
        for url in event.mimeData().urls():
            path = Path(url.toLocalFile())
            if path.is_file():
                files.append(path)
            elif path.is_dir():
                files.extend([f for f in path.rglob("*") if f.suffix.lower() in (".mid", ".midi")])
        self.convert_midi_files(files)

def main():
    app = QApplication(sys.argv)
    window = MidiToAbcConverter()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()