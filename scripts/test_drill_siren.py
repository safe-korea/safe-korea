import array
from pathlib import Path
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]


class SirenTests(unittest.TestCase):
    def test_platform_assets_identical(self):
        self.assertEqual((ROOT / 'android/app/src/main/res/raw/drill_siren.wav').read_bytes(),
                         (ROOT / 'ios/Runner/drill_siren.wav').read_bytes())

    def test_pcm_duration_and_no_clipping(self):
        with wave.open(str(ROOT / 'ios/Runner/drill_siren.wav')) as audio:
            self.assertEqual((audio.getnchannels(), audio.getsampwidth()), (1, 2))
            self.assertEqual(audio.getnframes() / audio.getframerate(), 6)
            samples = array.array('h', audio.readframes(audio.getnframes()))
        self.assertGreater(max(samples), 5000)
        self.assertLess(max(abs(value) for value in samples), 32767)
        self.assertEqual(samples[0], 0)
