"""Generate the app's original six-second drill siren. Never plays audio."""
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
SECONDS = 6


def generate():
    phase = 0.0
    frames = bytearray()
    for index in range(RATE * SECONDS):
        t = index / RATE
        frequency = 700 - 200 * math.cos(2 * math.pi * t / 1.5)
        phase += 2 * math.pi * frequency / RATE
        fade = min(1, t / 0.05, (SECONDS - t) / 0.1)
        sample = 0.35 * fade * (0.85 * math.sin(phase) + 0.15 * math.sin(2 * phase))
        frames.extend(struct.pack('<h', round(sample * 32767)))
    for relative in ('android/app/src/main/res/raw/drill_siren.wav', 'ios/Runner/drill_siren.wav'):
        target = ROOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(target), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(frames)


if __name__ == '__main__':
    generate()
