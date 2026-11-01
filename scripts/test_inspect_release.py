import struct
import unittest
from inspect_release import elf_load_alignment


class ReleaseInspectionTests(unittest.TestCase):
    def elf(self, alignment, offset=0, address=0):
        data = bytearray(120)
        data[:6] = b'\x7fELF\x02\x01'
        struct.pack_into('<Q', data, 32, 64)
        struct.pack_into('<HH', data, 54, 56, 1)
        struct.pack_into('<I', data, 64, 1)
        struct.pack_into('<QQ', data, 72, offset, address)
        struct.pack_into('<Q', data, 112, alignment)
        return data

    def test_accepts_aligned_load_segment(self):
        self.assertTrue(elf_load_alignment(self.elf(16384))[0]['compatible_16kb'])

    def test_rejects_4kb_and_incongruent_offsets(self):
        self.assertFalse(elf_load_alignment(self.elf(4096))[0]['compatible_16kb'])
        self.assertFalse(elf_load_alignment(self.elf(16384,4096,0))[0]['compatible_16kb'])

    def test_invalid_elf_is_not_mistaken_for_compatible(self):
        with self.assertRaises(ValueError):
            elf_load_alignment(b'not an ELF')
