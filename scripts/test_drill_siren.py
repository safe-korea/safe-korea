import array
from pathlib import Path
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]


class SirenTests(unittest.TestCase):
    def test_signal_timing_and_voice_assets(self):
        from generate_drill_siren import frequency_at
        self.assertEqual([frequency_at(t) for t in (0, 5, 8)], [500, 900, 500])
        self.assertLess(frequency_at(4), frequency_at(5))
        self.assertGreater(frequency_at(6), frequency_at(7))
        for kind in ('watch', 'cbrn', 'chemical', 'biological', 'release'):
            name = f'drill_{kind}_voice.wav'
            self.assertEqual((ROOT / 'ios/Runner' / name).read_bytes(),
                             (ROOT / 'android/app/src/main/res/raw' / name).read_bytes())
            with wave.open(str(ROOT / 'ios/Runner' / name)) as audio:
                self.assertEqual((audio.getnchannels(), audio.getsampwidth()), (1, 2))
                self.assertGreater(audio.getnframes() / audio.getframerate(), 1)
                self.assertLess(audio.getnframes() / audio.getframerate(), 30)

    def test_platform_assets_identical(self):
        self.assertEqual((ROOT / 'android/app/src/main/res/raw/drill_siren.wav').read_bytes(),
                         (ROOT / 'ios/Runner/drill_siren.wav').read_bytes())

    def test_pcm_duration_and_no_clipping(self):
        with wave.open(str(ROOT / 'ios/Runner/drill_siren.wav')) as audio:
            self.assertEqual((audio.getnchannels(), audio.getsampwidth()), (1, 2))
            self.assertEqual(audio.getnframes() / audio.getframerate(), 8)
            samples = array.array('h', audio.readframes(audio.getnframes()))
        self.assertGreater(max(samples), 5000)
        self.assertLess(max(abs(value) for value in samples), 32767)
        self.assertEqual(samples[0], 0)
