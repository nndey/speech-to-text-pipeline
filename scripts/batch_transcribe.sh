#!/bin/bash

INPUT_DIR="$HOME/speech-to-text-pipeline/audio"
OUTPUT_DIR="$HOME/speech-to-text-pipeline/transcripts"
TMP_DIR="$HOME/speech-to-text-pipeline/tmp"

mkdir -p "$OUTPUT_DIR" "$TMP_DIR"

python - <<EOF
from faster_whisper import WhisperModel
import subprocess
from pathlib import Path
import json
from concurrent.futures import ThreadPoolExecutor

input_dir = Path("$INPUT_DIR")
output_dir = Path("$OUTPUT_DIR")
tmp_dir = Path("$TMP_DIR")

# CONFIG
MODEL_SIZE = "medium"
COMPUTE_TYPE = "int8"
CPU_THREADS = 12
MAX_WORKERS = 4

# Language:
# None = auto-detect
# "en" = force English, etc.
LANGUAGE = "en"

model = WhisperModel(MODEL_SIZE, compute_type=COMPUTE_TYPE, cpu_threads=CPU_THREADS)

def get_audio_info(file):
    result = subprocess.run([
        "ffprobe", "-v", "quiet",
        "-print_format", "json",
        "-show_streams",
        str(file)
    ], capture_output=True, text=True)

    data = json.loads(result.stdout)
    stream = data["streams"][0]

    sample_rate = int(stream.get("sample_rate", 0))
    channels = int(stream.get("channels", 0))

    return sample_rate, channels

def prepare_audio(file, name):
    # Skip probing for non-WAV -> always convert
    if file.suffix.lower() != ".wav":
        needs_conversion = True
    else:
        sample_rate, channels = get_audio_info(file)
        needs_conversion = not (sample_rate == 16000 and channels == 1)

    if needs_conversion:
        tmp_wav = tmp_dir / f"{name}.wav"

        subprocess.run([
            "ffmpeg", "-y", "-i", str(file),
            "-ac", "1", "-ar", "16000",
            str(tmp_wav)
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        return tmp_wav, True
    else:
        return file, False

def transcribe_file(file):
    name = file.stem
    out_txt = output_dir / f"{name}.txt"

    # Skip if already done
    if out_txt.exists():
        print(f"Skipping {file.name} (already transcribed)")
        return

    print(f"Processing {file.name}...")

    audio_path, converted = prepare_audio(file, name)

    segments, _ = model.transcribe(
        str(audio_path),
        language=LANGUAGE
    )

    with open(out_txt, "w") as f:
        for s in segments:
            f.write(f"[{s.start:.2f}-{s.end:.2f}] {s.text}\\n")

    if converted:
        audio_path.unlink(missing_ok=True)

    print(f"Done: {file.name}")

AUDIO_EXTENSIONS = {".wav", ".mp3", ".ogg", ".flac", ".aac", ".m4a", ".opus", ".wma"}
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".mov", ".avi", ".webm", ".m4v", ".ts", ".wmv"}
SUPPORTED_EXTENSIONS = AUDIO_EXTENSIONS | VIDEO_EXTENSIONS

files = [f for f in input_dir.iterdir() if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS]

with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
    executor.map(transcribe_file, files)

print("All done.")
EOF
