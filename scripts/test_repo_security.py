import unittest
from check_repo_security import PATTERNS, sensitive_path


class RepoSecurityTests(unittest.TestCase):
    def test_private_config_and_signing_paths_are_blocked(self):
        for path in ['android/key.properties', 'config/kakao.local.json',
                     'android/upload.jks', 'backup.P12', '.env']:
            self.assertTrue(sensitive_path(path), path)
        for path in ['config/api.production.json', '.env.example',
                     'android/app/build.gradle.kts']:
            self.assertFalse(sensitive_path(path), path)

    def test_token_pattern_is_detected_without_printing_value(self):
        fake = ('ghp' + '_' + 'x' * 36).encode()
        self.assertTrue(any(pattern.search(fake) for pattern in PATTERNS))
        self.assertFalse(any(pattern.search(b'ordinary public config') for pattern in PATTERNS))
