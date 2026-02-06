#!/usr/bin/env python3
"""Generate piano key WAV files for the melodica app.

Usage:
    python generate_keys.py [OPTIONS]

Examples:
    python generate_keys.py
    python generate_keys.py --instrument piano
    python generate_keys.py --instrument melodica --output ../assets
    python generate_keys.py --instrument organ --octaves 4 5 6
"""

import argparse
import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
DURATION = 1.5  # seconds

# Note frequencies (A4 = 440 Hz)
NOTE_FREQS = {
    "c": 261.63, "cs": 277.18, "db": 277.18,
    "d": 293.66, "ds": 311.13, "eb": 311.13,
    "e": 329.63,
    "f": 349.23, "fs": 369.99, "gb": 369.99,
    "g": 392.00, "gs": 415.30, "ab": 415.30,
    "a": 440.00, "as": 466.16, "bb": 466.16,
    "b": 493.88,
}

# Octave multipliers relative to octave 4
def freq(note: str, octave: int) -> float:
    return NOTE_FREQS[note] * (2 ** (octave - 4))


def envelope(t: float, attack: float, decay: float, sustain: float,
             release_start: float, release_dur: float) -> float:
    """ADSR envelope."""
    if t < attack:
        return t / attack
    elif t < attack + decay:
        return 1.0 - (1.0 - sustain) * ((t - attack) / decay)
    elif t < release_start:
        return sustain
    elif t < release_start + release_dur:
        return sustain * (1.0 - (t - release_start) / release_dur)
    else:
        return 0.0


# ── Instrument definitions ──────────────────────────────────────────

def synth_piano(f: float, t: float) -> float:
    """Bright piano-like tone with harmonics and fast decay."""
    env = envelope(t, 0.005, 0.15, 0.3, DURATION - 0.3, 0.3)
    s = (
        1.0  * math.sin(2 * math.pi * f * t) +
        0.5  * math.sin(2 * math.pi * 2 * f * t) +
        0.25 * math.sin(2 * math.pi * 3 * f * t) +
        0.12 * math.sin(2 * math.pi * 4 * f * t) +
        0.06 * math.sin(2 * math.pi * 5 * f * t)
    )
    return s * env / 1.93


def synth_melodica(f: float, t: float) -> float:
    """Breathy melodica / reed organ tone."""
    env = envelope(t, 0.06, 0.1, 0.6, DURATION - 0.2, 0.2)
    # Slight vibrato
    vibrato = 1.0 + 0.003 * math.sin(2 * math.pi * 5.0 * t)
    fv = f * vibrato
    s = (
        1.0  * math.sin(2 * math.pi * fv * t) +
        0.6  * math.sin(2 * math.pi * 2 * fv * t) +
        0.1  * math.sin(2 * math.pi * 3 * fv * t) +
        0.3  * math.sin(2 * math.pi * 4 * fv * t) +
        0.05 * math.sin(2 * math.pi * 5 * fv * t)
    )
    # Add breath noise
    import random
    noise = random.gauss(0, 0.02) * env
    return (s * env / 2.05) + noise


def synth_organ(f: float, t: float) -> float:
    """Drawbar organ tone (Hammond-like)."""
    env = envelope(t, 0.01, 0.05, 0.8, DURATION - 0.15, 0.15)
    # Drawbar registrations: 16' 8' 5-1/3' 4' 2-2/3' 2' 1-3/5' 1-1/3' 1'
    s = (
        0.5  * math.sin(2 * math.pi * 0.5 * f * t) +  # 16'
        1.0  * math.sin(2 * math.pi * f * t) +          # 8'
        0.7  * math.sin(2 * math.pi * 1.5 * f * t) +   # 5-1/3'
        0.8  * math.sin(2 * math.pi * 2 * f * t) +     # 4'
        0.3  * math.sin(2 * math.pi * 3 * f * t) +     # 2-2/3'
        0.5  * math.sin(2 * math.pi * 4 * f * t) +     # 2'
        0.1  * math.sin(2 * math.pi * 5 * f * t) +     # 1-3/5'
        0.2  * math.sin(2 * math.pi * 6 * f * t) +     # 1-1/3'
        0.1  * math.sin(2 * math.pi * 8 * f * t)       # 1'
    )
    return s * env / 4.2


def synth_sine(f: float, t: float) -> float:
    """Pure sine wave."""
    env = envelope(t, 0.01, 0.1, 0.6, DURATION - 0.2, 0.2)
    return math.sin(2 * math.pi * f * t) * env


def synth_celesta(f: float, t: float) -> float:
    """Bell-like celesta tone."""
    env = envelope(t, 0.002, 0.3, 0.1, DURATION - 0.4, 0.4)
    s = (
        1.0  * math.sin(2 * math.pi * f * t) * math.exp(-t * 2.0) +
        0.8  * math.sin(2 * math.pi * 2 * f * t) * math.exp(-t * 3.0) +
        0.5  * math.sin(2 * math.pi * 3 * f * t) * math.exp(-t * 4.5) +
        0.3  * math.sin(2 * math.pi * 4.2 * f * t) * math.exp(-t * 6.0) +
        0.15 * math.sin(2 * math.pi * 5.4 * f * t) * math.exp(-t * 8.0)
    )
    return s * env / 2.75


INSTRUMENTS = {
    "piano":    synth_piano,
    "melodica": synth_melodica,
    "organ":    synth_organ,
    "sine":     synth_sine,
    "celesta":  synth_celesta,
}

# ── WAV generation ──────────────────────────────────────────────────

def generate_wav(filepath: Path, f: float, synth_func, duration: float = DURATION):
    """Generate a WAV file for a single note."""
    n_samples = int(SAMPLE_RATE * duration)
    samples = []

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        s = synth_func(f, t)
        s = max(-1.0, min(1.0, s))  # clamp
        samples.append(int(s * 32767))

    with wave.open(str(filepath), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def main():
    parser = argparse.ArgumentParser(
        description="Generate piano key WAV files for the melodica app."
    )
    parser.add_argument(
        "-i", "--instrument",
        choices=list(INSTRUMENTS.keys()),
        default="melodica",
        help="Instrument sound to generate (default: melodica)",
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "assets",
        help="Output directory (default: ../assets)",
    )
    parser.add_argument(
        "--octaves",
        type=int,
        nargs="+",
        default=[4, 5],
        help="Octaves to generate (default: 4 5)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=DURATION,
        help=f"Note duration in seconds (default: {DURATION})",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available instruments and exit",
    )
    args = parser.parse_args()

    if args.list:
        print("Available instruments:")
        for name in INSTRUMENTS:
            print(f"  {name}")
        return

    synth_func = INSTRUMENTS[args.instrument]
    output_dir = args.output
    output_dir.mkdir(parents=True, exist_ok=True)

    notes = ["c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"]
    # Also generate enharmonics
    enharmonics = {"cs": "db", "ds": "eb", "fs": "gb", "gs": "ab", "as": "bb"}

    generated = 0
    for octave in args.octaves:
        for note in notes:
            f = freq(note, octave)
            filename = f"key_{note}{octave}.wav"
            filepath = output_dir / filename
            generate_wav(filepath, f, synth_func, args.duration)
            print(f"  {filename:16s}  {f:8.2f} Hz")
            generated += 1

            # Generate enharmonic equivalent if exists
            if note in enharmonics:
                enh = enharmonics[note]
                enh_filename = f"key_{enh}{octave}.wav"
                enh_filepath = output_dir / enh_filename
                generate_wav(enh_filepath, f, synth_func, args.duration)
                print(f"  {enh_filename:16s}  {f:8.2f} Hz  (enharmonic)")
                generated += 1

    print(f"\nGenerated {generated} files in {output_dir}/ ({args.instrument})")


if __name__ == "__main__":
    main()
