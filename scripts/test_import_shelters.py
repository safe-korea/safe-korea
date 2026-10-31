import unittest
from import_shelters import convert

# Deliberately synthetic test records; never shipped in the app asset.
HEADER = 'id,name,address,latitude,longitude,updatedAt,status\n'
ROW = 'test,테스트 시설,테스트 주소,37.5,127.0,2026-01-01,designated\n'


class ImportTests(unittest.TestCase):
    def test_normalized_official_schema(self):
        result = convert((HEADER + ROW).encode(), '테스트 전용')
        self.assertEqual(len(result['items']), 1)
        self.assertEqual(result['items'][0]['latitude'], 37.5)
        self.assertEqual(len(result['inputSha256']), 64)

    def test_projected_or_invalid_coordinate_rejected(self):
        for invalid in ['200000', 'nan', '0']:
            with self.assertRaises(ValueError):
                convert((HEADER + ROW.replace('37.5', invalid)).encode(), '테스트')

    def test_unknown_status_duplicate_date_and_missing_fields(self):
        for body in [HEADER + ROW.replace('designated', 'unknown'), HEADER + ROW + ROW,
                     HEADER + ROW.replace('2026-01-01', '2999-01-01'), 'name\n테스트\n']:
            with self.assertRaises(ValueError):
                convert(body.encode(), '테스트')

    def test_released_records_are_excluded(self):
        data = HEADER + ROW + ROW.replace('test,', 'released-test,').replace('designated', 'released')
        self.assertEqual(len(convert(data.encode(), '테스트')['items']), 1)


if __name__ == '__main__':
    unittest.main()
