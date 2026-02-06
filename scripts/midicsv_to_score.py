#!/usr/bin/env python3
"""Convert midicsv format to melodica score JSON."""
import json
import sys

MIDI_NOTE_NAMES = [
    "c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"
]

def midi_to_name(midi_num: int) -> str:
    octave = (midi_num // 12) - 1
    note = MIDI_NOTE_NAMES[midi_num % 12]
    return f"{note}{octave}"

def convert(csv_path: str, output_path: str):
    ppq = 384
    tempo_us = 500000  # default 120 BPM

    notes = []

    with open(csv_path) as f:
        for line in f:
            parts = [p.strip() for p in line.strip().split(",")]
            if len(parts) < 3:
                continue

            record_type = parts[2].strip()

            if record_type == "Header":
                ppq = int(parts[5])
            elif record_type == "Tempo":
                tempo_us = int(parts[3])
            elif record_type == "Note_on_c":
                tick = int(parts[1])
                midi_num = int(parts[4])
                velocity = int(parts[5])
                if velocity > 0:
                    time_sec = tick * (tempo_us / 1_000_000) / ppq
                    name = midi_to_name(midi_num)
                    notes.append({"t": round(time_sec, 4), "n": name})

    notes.sort(key=lambda n: n["t"])

    score = {
        "title": "Gymnopédie No.1",
        "composer": "Erik Satie",
        "notes": notes
    }

    with open(output_path, "w") as f:
        json.dump(score, f, indent=2, ensure_ascii=False)

    print(f"Converted {len(notes)} notes -> {output_path}")

if __name__ == "__main__":
    csv_path = sys.argv[1] if len(sys.argv) > 1 else "gymnopedia.csv"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "gymnopedie1.json"
    convert(csv_path, output_path)
