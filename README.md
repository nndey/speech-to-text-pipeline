# DIY Speech-to-Text Pipeline

A local, offline speech-to-text pipeline that batch-transcribes audio recordings using [faster-whisper](https://github.com/SYSTRAN/faster-whisper). Audio files in any format are automatically normalized via ffmpeg and transcribed in parallel, producing timestamped `.txt` transcripts — no cloud APIs, no data leaving the machine.

## Project Highlights
- Fully local and offline — transcription runs entirely on-device via faster-whisper with no cloud dependencies
- Automatic audio normalization — ffmpeg converts any input format to 16kHz mono WAV before transcription
- Parallel batch processing — multiple files are transcribed concurrently using a configurable thread pool
- Incremental runs — already-transcribed files are skipped automatically, so the pipeline is safe to re-run
- Timestamped output — each transcript includes per-segment start/end timestamps

## Tools and Technologies
- **[faster-whisper](https://github.com/SYSTRAN/faster-whisper)** — CTranslate2-based reimplementation of OpenAI Whisper; runs on CPU with `int8` quantization for efficient local inference
- **ffmpeg / ffprobe** — handles audio probing and conversion to the 16kHz mono WAV format required by Whisper
- **Python** (`concurrent.futures.ThreadPoolExecutor`) — drives the transcription logic and parallelizes file processing across a configurable worker pool
- **Bash** — outer script that wires the pipeline together and embeds the Python transcription logic inline

## Pipeline Overview

### Prerequisites
- Python 3.8+
- ffmpeg (must be on your `PATH`)
- faster-whisper: `pip install faster-whisper`

### Steps

1. **Add audio files** — place any audio files (`.ogg`, `.mp3`, `.wav`, etc.) into the `audio/` directory.

2. **Make the script executable** (first run only):
   ```bash
   chmod +x scripts/batch_transcribe.sh
   ```

3. **Run the pipeline:**
   ```bash
   ./scripts/batch_transcribe.sh
   ```
   The script will convert each file to 16kHz mono WAV if needed, then transcribe it using the Whisper model. Files that already have a transcript in `transcripts/` are skipped automatically.

4. **Find your transcripts** — output `.txt` files are written to `transcripts/`, named to match their source audio file. Each line contains a timestamp range and the transcribed text:
   ```
   [0.00-3.40] This is an example transcript segment.
   ```

### Configuration
To adjust model behavior, edit the config block near the top of `scripts/batch_transcribe.sh`:

| Variable | Default | Description |
|---|---|---|
| `MODEL_SIZE` | `medium` | Whisper model size (`tiny`, `base`, `small`, `medium`, `large`) |
| `COMPUTE_TYPE` | `int8` | Quantization type; `int8` is fastest on CPU |
| `CPU_THREADS` | `12` | Threads allocated to the model |
| `MAX_WORKERS` | `4` | Number of files transcribed in parallel |
| `LANGUAGE` | `en` | Transcription language; set to `None` for auto-detect |


## Outputs
This pipeline produces one `.txt` transcript file per audio file, written to the `transcripts/` directory. Each transcript file is named after its source audio file (e.g. `audio/My-Recording.ogg` → `transcripts/My-Recording.txt`).

Each line in a transcript represents a single spoken segment and follows this format:

```
[start-end] Transcribed text for that segment.
```

For example:
```
[0.00-3.40] So the first thing I want to talk about is how my day went. 
[3.40-7.82] I remember starting the day off fine. Things weren't too bad.
[7.82-11.05] I was able to do my morning routine like going to the gym or watering my plants.
```

Timestamps are in seconds. Segments are generated automatically by Whisper based on natural speech pauses, so segment length will vary.

## Repository Structure
```
/speech-to-text-pipeline
├── audio/             
├── scripts/    
├── tmp/     
├── transcripts/
├── README.md
└── .gitignore
```
