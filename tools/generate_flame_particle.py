"""Generate the soft particle sprite used by arena fires (original work)."""
import struct
import zlib
from pathlib import Path


def chunk(tag, data):
    return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xffffffff)


rows = []
for y in range(64):
    row = bytearray([0])
    for x in range(64):
        dx, dy = (x - 31.5) / 31.5, (y - 31.5) / 31.5
        alpha = max(0, 1 - dx * dx - dy * dy)
        row.extend((255, 255, 255, int(alpha * alpha * 255)))
    rows.append(row)
png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!IIBBBBB', 64, 64, 8, 6, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b''))
(Path(__file__).resolve().parents[1] / 'assets/arena/flame_particle.png').write_bytes(png)
