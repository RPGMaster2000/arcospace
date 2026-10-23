"""Focused offline integrity tests; synthesis is optional tooling, not a runtime dependency."""
import unittest
from pathlib import Path
import wave


class SoundAssetTests(unittest.TestCase):
    def test_catalog_sources_are_lossless_and_click_free(self):
        # stdlib-only check: CI does not need NumPy to validate existing assets.
        import array
        import json
        import hashlib
        root = Path(__file__).resolve().parents[1]
        folder = root / 'assets/sound/sfx'
        manifest = json.loads((folder / 'manifest.json').read_text())
        self.assertEqual((manifest['events'], manifest['files']), (24, 38))
        self.assertEqual(manifest['total_bytes'], sum(p.stat().st_size for p in folder.glob('*.wav')))
        catalog = (root / 'resources/audio/sound_catalog.tres').read_text()
        for entry in manifest['assets']:
            with self.subTest(file=entry['file']):
                path = folder / entry['file']
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry['sha256'])
                with wave.open(str(path)) as wav:
                    self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, 48000))
                    data = array.array('h', wav.readframes(wav.getnframes()))
                self.assertEqual(data[0], 0)
                self.assertEqual(data[-1], 0)
                self.assertLess(max(map(abs, data)), 14745)
                self.assertIn('res://assets/sound/sfx/' + path.name, catalog)
                self.assertIn('compress/mode=0', path.with_suffix('.wav.import').read_text())


if __name__ == '__main__':
    unittest.main()
