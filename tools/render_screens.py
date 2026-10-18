#!/usr/bin/env python3
"""
Render actual NES PPU screenshots (Title, Briefing, Gameplay, Boss) of game.nes
into PNG files using pure Python (zlib + struct) so we can visually inspect every screen!
"""
import sys, struct, zlib
sys.path.append("/mnt/c/Users/kusak/.gemini/antigravity/brain/3aea7f79-ea53-4913-9a60-4f120e58d1a5/scratch")
from test_start_game import CPU6502

NES_PALETTE = [
    (84,84,84),    (0,30,116),    (8,16,144),    (48,0,136),    (68,0,100),    (92,0,48),     (84,4,0),      (60,24,0),
    (32,42,0),     (8,58,0),      (0,64,0),      (0,60,0),      (0,50,60),     (0,0,0),       (0,0,0),       (0,0,0),
    (152,150,152), (8,76,196),    (48,50,236),   (92,30,228),   (136,20,176),  (160,20,100),  (152,34,32),   (120,60,0),
    (84,90,0),     (40,114,0),    (8,124,0),     (0,118,40),    (0,102,120),   (0,0,0),       (0,0,0),       (0,0,0),
    (236,238,236), (76,154,236),  (120,124,236), (176,98,236),  (228,84,236),  (236,88,180),  (236,106,100), (212,136,32),
    (160,170,0),   (116,196,0),   (76,208,32),   (56,204,108),  (56,180,204),  (60,60,60),    (0,0,0),       (0,0,0),
    (236,238,236), (168,204,236), (188,188,236), (212,178,236), (236,174,236), (236,174,212), (236,180,176), (228,196,144),
    (204,210,120), (180,222,120), (168,226,144), (152,226,180), (160,214,228), (160,162,160), (0,0,0),       (0,0,0),
]

class NESWithPPU(CPU6502):
    def __init__(self, prg, chr_rom):
        super().__init__(prg)
        self.chr = chr_rom
        self.vram = bytearray(0x1000) # 2 nametables: 0x000-0x3FF ($2000/$2400), 0x800-0xBFF ($2800/$2C00)
        self.pal = bytearray(32)
        self.ppu_ctrl = 0
        self.ppu_mask = 0
        self.ppu_addr = 0
        self.ppu_latch = 0
        self.scroll_x = 0
        self.scroll_y = 0

    def map_vram(self, addr):
        # Horizontal mirroring: $2000/$2400 -> 0x000, $2800/$2C00 -> 0x400
        a = addr & 0x0FFF
        nt = (a >> 10) & 3
        off = a & 0x03FF
        if nt in (0, 1):
            return off
        else:
            return 0x400 + off

    def read(self, addr):
        addr &= 0xFFFF
        if 0x2000 <= addr < 0x4000:
            reg = addr & 0x2007
            if reg == 0x2002:
                self.ppu_latch = 0
                return self.ppu_status
        return super().read(addr)

    def write(self, addr, val):
        addr &= 0xFFFF
        val &= 0xFF
        if 0x2000 <= addr < 0x4000:
            reg = addr & 0x2007
            if reg == 0x2000:
                self.ppu_ctrl = val
            elif reg == 0x2001:
                self.ppu_mask = val
            elif reg == 0x2005:
                if self.ppu_latch == 0:
                    self.scroll_x = val
                    self.ppu_latch = 1
                else:
                    self.scroll_y = val
                    self.ppu_latch = 0
            elif reg == 0x2006:
                if self.ppu_latch == 0:
                    self.ppu_addr = (val << 8) | (self.ppu_addr & 0x00FF)
                    self.ppu_latch = 1
                else:
                    self.ppu_addr = (self.ppu_addr & 0xFF00) | val
                    self.ppu_latch = 0
            elif reg == 0x2007:
                a = self.ppu_addr & 0x3FFF
                if 0x2000 <= a < 0x3F00:
                    self.vram[self.map_vram(a)] = val
                elif 0x3F00 <= a < 0x4000:
                    p = a & 0x1F
                    if p in (0x10, 0x14, 0x18, 0x1C):
                        p -= 0x10
                    self.pal[p] = val & 0x3F
                inc = 32 if (self.ppu_ctrl & 0x04) else 1
                self.ppu_addr = (self.ppu_addr + inc) & 0xFFFF
            return
        super().write(addr, val)

    def render_png(self, path):
        w, h = 256, 240
        bg_c0 = NES_PALETTE[self.pal[0] & 0x3F]
        fb = [[bg_c0 for _ in range(w)] for _ in range(h)]

        base_nt = 1 if (self.ppu_ctrl & 0x02) else 0
        sy = self.scroll_y % 240

        # Render BG
        for y in range(h):
            wy = y + sy
            nt_y = (base_nt ^ 1) if wy >= 240 else base_nt
            ly = wy % 240
            ty = ly >> 3
            py = ly & 7
            nt_base = 0x400 if nt_y else 0x000
            for tx in range(32):
                t_idx = self.vram[nt_base + ty * 32 + tx]
                attr_byte = self.vram[nt_base + 0x3C0 + (ty >> 2) * 8 + (tx >> 2)]
                shift = ((ty & 2) << 1) | (tx & 2)
                pal_idx = (attr_byte >> shift) & 3

                lo = self.chr[t_idx * 16 + py]
                hi = self.chr[t_idx * 16 + 8 + py]
                for px in range(8):
                    bit = 7 - px
                    c = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                    if c != 0:
                        col_id = self.pal[pal_idx * 4 + c] & 0x3F
                        fb[y][tx * 8 + px] = NES_PALETTE[col_id]

        # Render Sprites (reverse order so lower index has priority)
        for s in range(63, -1, -1):
            base = 0x200 + s * 4
            spy = self.ram[base] + 1
            t_idx = self.ram[base + 1]
            attr = self.ram[base + 2]
            spx = self.ram[base + 3]
            if spy >= 240:
                continue
            pal_idx = attr & 3
            hflip = bool(attr & 0x40)
            vflip = bool(attr & 0x80)
            for py in range(8):
                ry = (7 - py) if vflip else py
                lo = self.chr[t_idx * 16 + ry]
                hi = self.chr[t_idx * 16 + 8 + ry]
                yy = spy + py
                if not (0 <= yy < 240):
                    continue
                for px in range(8):
                    rx = px if hflip else (7 - px)
                    c = ((lo >> rx) & 1) | (((hi >> rx) & 1) << 1)
                    if c != 0:
                        xx = spx + px
                        if 0 <= xx < 256:
                            col_id = self.pal[16 + pal_idx * 4 + c] & 0x3F
                            fb[yy][xx] = NES_PALETTE[col_id]

        # Encode PNG
        raw = bytearray()
        for row in fb:
            raw.append(0)
            for r, g, b in row:
                raw.extend((r, g, b))
        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)

with open("game.nes", "rb") as f:
    rom = f.read()

prg = bytearray(rom[16:16+32768])
chr_rom = bytearray(rom[16+32768:16+32768+8192])
nes = NESWithPPU(prg, chr_rom)

syms = {}
with open("build/dbg.txt") as f:
    for line in f:
        if line.startswith("sym\t"):
            name = None
            val = None
            for part in line.split("\t")[1].split(","):
                if part.startswith('name="'): name = part.split('"')[1]
                elif part.startswith("val="): val = int(part.split("=")[1], 16)
            if name and val is not None:
                syms[name] = val

MAIN_LOOP = syms["main_loop"]
for addr in range(len(prg)-6):
    if prg[addr] == 0xA5 and prg[addr+1] == syms["nmi_ready"] and prg[addr+2] == 0xD0:
        WAIT_NMI = 0x8000 + addr
        break

while nes.pc != MAIN_LOOP:
    nes.step()

def run_frame(btn=0):
    nes.joy1_bits = btn
    while nes.pc != WAIT_NMI:
        nes.step()
    nes.trigger_nmi()
    while nes.ram[syms["nmi_ready"]] != 0:
        nes.step()
    while nes.pc != MAIN_LOOP:
        nes.step()

# 1. Title screen
for _ in range(5):
    run_frame(0)
nes.render_png("build/title.png")

# 2. Briefing screen
run_frame(0x10)
run_frame(0)
nes.render_png("build/briefing.png")

# 3. Gameplay screen (Form 2.5: Core Fighter + Chest firing 2-WAY Missiles while Ally Support Craft delivers 16x16 Parts!)
for _ in range(115):
    run_frame(0)
nes.ram[syms["inv_timer"]] = 0
nes.ram[syms["weapon_type"]] = 2   # Form 2.5: Core Fighter + Chest (F2.5)
nes.ram[syms["weapon_level"]] = 2
nes.ram[syms["meta_idx"]] = 41
nes.ram[syms["meta_sub_row"]] = 1
for _ in range(52):
    run_frame(0x80)
nes.ram[syms["item_flag"] + 1] = 1
nes.ram[syms["item_type"] + 1] = 0
nes.ram[syms["item_x"] + 1] = 76
nes.ram[syms["item_y"] + 1] = 92
run_frame(0x80)
nes.render_png("build/gameplay.png")
nes.ram[syms["item_flag"] + 1] = 0

# 4. Boss fight screen (Form 3: Gundam MS irradiating full-screen 2-second piercing laser vs Giant Boss)
nes.ram[syms["ally_state"]] = 0
nes.ram[syms["weapon_type"]] = 3   # Form 3: Gundam MS (F3)
nes.ram[syms["weapon_level"]] = 3
nes.ram[syms["meta_idx"]] = 63
nes.ram[syms["meta_sub_row"]] = 1
for _ in range(50):
    run_frame(0x80)
nes.render_png("build/boss.png")
print("Rendered build/title.png, build/briefing.png, build/gameplay.png, build/boss.png")
