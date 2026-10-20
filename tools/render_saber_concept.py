import struct, zlib
import sys
sys.path.insert(0, "tools")
from gen_chr import RIVAL_RED_MS_24x32

# Palette: 0=Dark Bg, 1=Blue, 2=Red, 3=White, 4=Saber White, 5=Saber Red Edge
PAL = [
    (16, 20, 28),     # 0: BG
    (0, 70, 190),     # 1: Blue
    (220, 40, 20),    # 2: Red
    (240, 240, 240),  # 3: White
    (255, 255, 255),  # 4: Saber Core
    (255, 120, 100),  # 5: Saber Edge
]

W, H = 256, 128
buf = [[0 for _ in range(W)] for _ in range(H)]

def set_px(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        buf[y][x] = c

# Draw 1. 上段の構え (High Guard: Raised Overhead) on Left
# Robot at base_x=80, base_y=40 (2x scale)
for ry, row in enumerate(RIVAL_RED_MS_24x32):
    for rx, ch in enumerate(row):
        if ch in ('1', '2', '3'):
            c = int(ch)
            # If arm row (6..9, x<=7), replace horizontal arm with upward raised arm!
            if 6 <= ry <= 9 and rx <= 7:
                continue
            for dy in range(2):
                for dx in range(2):
                    set_px(80 + rx*2 + dx, 40 + ry*2 + dy, c)

# Draw raised arm (raising hilt up to shoulder/head level rx=7..10, ry=2..6)
for ry in range(2, 7):
    for rx in range(6, 10):
        for dy in range(2):
            for dx in range(2):
                set_px(80 + rx*2 + dx, 40 + ry*2 + dy, 2)
# White hand
for dy in range(2):
    for dx in range(2):
        set_px(80 + 7*2 + dx, 40 + 2*2 + dy, 3)

# Draw diagonal beam saber pointing UP-LEFT from hand (80+14, 40+4)
hx, hy = 80 + 14, 40 + 4
for step in range(32):
    bx = hx - int(step * 1.4)
    by = hy - int(step * 1.1)
    set_px(bx, by, 4)
    set_px(bx-1, by, 5)
    set_px(bx+1, by, 5)
    set_px(bx, by-1, 5)
    set_px(bx, by+1, 5)

# Draw 2. 振り下ろし (Downward Slash / Horizontal Strike - Current user image) on Right
# Robot at base_x=190, base_y=40 (2x scale)
for ry, row in enumerate(RIVAL_RED_MS_24x32):
    for rx, ch in enumerate(row):
        if ch in ('1', '2', '3'):
            c = int(ch)
            for dy in range(2):
                for dx in range(2):
                    set_px(190 + rx*2 + dx, 40 + ry*2 + dy, c)

# Draw horizontal beam saber from hand (190+12, 40+14) extending left by 64px
hx, hy = 190 + 12, 40 + 15
for step in range(64):
    bx = hx - step
    set_px(bx, hy, 4)
    set_px(bx, hy-1, 5)
    set_px(bx, hy+1, 5)

# Save as PNG
def save_png(filename):
    raw_data = bytearray()
    for row in buf:
        raw_data.append(0) # filter type none
        for idx in row:
            r, g, b = PAL[idx]
            raw_data.extend((r, g, b))
    
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw_data))) + chunk(b"IEND", b"")
    with open(filename, "wb") as f:
        f.write(png)
    print(f"Wrote {filename}")

save_png("build/saber_stance_concept.png")
