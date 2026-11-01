import tempfile
import unittest
from pathlib import Path

from prepare_pwa import prepare


class PwaBuildTests(unittest.TestCase):
    def test_worker_version_changes_with_asset_content_and_is_repeatable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('one')
            prepare(root)
            first = (root / 'safe-worker.js').read_text()
            prepare(root)
            self.assertEqual(first, (root / 'safe-worker.js').read_text())
            (root / 'index.html').write_text('two')
            prepare(root)
            self.assertNotEqual(first, (root / 'safe-worker.js').read_text())

    def test_offline_allowlist_excludes_unused_renderers_and_debug_symbols(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'canvaskit').mkdir()
            for name in ['canvaskit.js', 'canvaskit.wasm', 'skwasm.wasm', 'canvaskit.js.symbols']:
                (root / 'canvaskit' / name).write_bytes(b'test')
            prepare(root)
            worker = (root / 'safe-worker.js').read_text()
            self.assertIn('canvaskit/canvaskit.wasm', worker)
            self.assertNotIn('skwasm.wasm', worker)
            self.assertNotIn('canvaskit.js.symbols', worker)


if __name__ == '__main__':
    unittest.main()
