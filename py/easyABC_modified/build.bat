@echo off
echo Running PyInstaller to build MIDI to ABC Converter executable (PyQt5)...

:: Get directory of this script
set "BASEDIR=%~dp0"
set FINAL_EXE_DIR=C:\Users\Chaden\Desktop\ChucksStuff\ZomboidDEBUG\Workshop\Bard-To-The-Bone\py
cd /d "%BASEDIR%"

:: Set your Python path (must be a 64-bit version if packaging large files)
set PYTHON_EXECUTABLE="C:\Program Files\Python312\python.exe"

:: Install dependencies
echo Installing required dependencies...
%PYTHON_EXECUTABLE% -m pip install --upgrade pip
%PYTHON_EXECUTABLE% -m pip install pyinstaller PyQt5

:: Define build info
set SCRIPT_PATH=midi_2_abc_converter_gui.py
set EXE_NAME=Midi2ABC
set OUTPUT_PATH=%FINAL_EXE_DIR%

:: Run PyInstaller
%PYTHON_EXECUTABLE% -m PyInstaller --onefile --windowed --name %EXE_NAME% ^
    --add-data "%BASEDIR%midi2abc.py;." ^
    --distpath %OUTPUT_PATH% ^
    --workpath build ^
    --specpath build ^
    %SCRIPT_PATH%

echo Build complete!