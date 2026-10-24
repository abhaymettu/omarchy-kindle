"""Recover the export CRC table from a decompressed ARM 4.9 kernel Image (no ELF, no kallsyms).

Layout assumed from the same tree's vmlinux.lds: __ksymtab, __ksymtab_gpl, then __kcrctab,
__kcrctab_gpl, then __ksymtab_strings, with the unused/gpl_future sections empty.
Each ksymtab entry is (value, name_ptr); kcrctab[i] is the CRC of the i-th ksymtab entry.
"""
import json, struct, sys

BASE = 0xC0008000
img = open(sys.argv[1], 'rb').read()
words = lambda off, n: struct.unpack_from(f'<{n}I', img, off)


def find_entry():
    at = -1
    while (at := img.find(b'\0module_layout\0', at + 1)) >= 0:
        ref = img.find(struct.pack('<I', BASE + at + 1))
        if ref > 0 and ref % 4 == 0:
            return ref - 4
    sys.exit('no ksymtab entry points at module_layout')

def cstr(va):
    off = va - BASE
    if not 0 <= off < len(img):
        return None
    end = img.find(b'\0', off, off + 128)
    s = img[off:end]
    return s.decode() if end > off and all(32 < c < 127 for c in s) else None

def valid(off):
    val, name = words(off, 2)
    return val >= 0xC0000000 and cstr(name) is not None

entry = find_entry()
start = entry
while valid(start - 8):
    start -= 8
end = entry
while valid(end):
    end += 8
n = (end - start) // 8
names = [cstr(words(start + 8 * i, 2)[1]) for i in range(n)]
crcs = words(end, n)
print(f'ksymtab entries={n} at image+{start:#x}', file=sys.stderr)
json.dump(dict(zip(names, (f'{c:#010x}' for c in crcs))), sys.stdout, indent=0)
