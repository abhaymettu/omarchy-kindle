"""Convert a raw 8-bit grayscale framebuffer dump to PNG. Usage: y8_to_png.py IN OUT WIDTH HEIGHT"""
import struct, sys, zlib

src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
data = open(src, 'rb').read()[:w * h]
raw = b''.join(b'\0' + data[y * w:(y + 1) * w] for y in range(h))
chunk = lambda t, b: struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0))
open(dst, 'wb').write(png + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
