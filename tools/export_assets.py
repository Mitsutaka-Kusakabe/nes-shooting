import os
import sys
import subprocess
import struct
import zlib

def write_png(filename, width, height, rgba_data):
    raw_bytes = bytearray()
    for y in range(height):
        raw_bytes.append(0)  # filter type None
        for x in range(width):
            r, g, b, a = rgba_data[y * width + x]
            raw_bytes.extend([r, g, b, a])
    compressed = zlib.compress(bytes(raw_bytes))
    
    def chunk(tag, data):
        crc = zlib.crc32(tag + data) & 0xffffffff
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)
    
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    with open(filename, "wb") as f:
        f.write(png)

# Authentic NES Master Palettes
NES_COLOR_RGB = {
    0x0F: (0, 0, 0, 255),         # Black
    0x11: (12, 59, 143, 255),     # Cobalt Blue
    0x12: (0, 30, 180, 255),      # Blue
    0x16: (152, 34, 32, 255),     # Crimson Red
    0x17: (142, 60, 0, 255),      # Brown / Gold
    0x1A: (0, 100, 20, 255),      # Zaku Green
    0x21: (68, 115, 239, 255),    # Light Blue
    0x22: (80, 100, 255, 255),    # Violet / Sky Blue
    0x27: (236, 120, 0, 255),     # Orange
    0x28: (250, 180, 0, 255),     # Yellow
    0x2A: (92, 228, 48, 255),     # Light Green
    0x30: (255, 255, 255, 255),   # Pure White
}

# Subpalette Presets (Index 0 is transparent in sprites)
PAL_PLAYER = [None, NES_COLOR_RGB[0x12], NES_COLOR_RGB[0x16], NES_COLOR_RGB[0x30]]
PAL_RIVAL  = [None, NES_COLOR_RGB[0x16], NES_COLOR_RGB[0x27], NES_COLOR_RGB[0x30]]
PAL_ENEMY_GREEN = [None, NES_COLOR_RGB[0x1A], NES_COLOR_RGB[0x2A], NES_COLOR_RGB[0x30]]
PAL_ENEMY_BLUE  = [None, NES_COLOR_RGB[0x11], NES_COLOR_RGB[0x21], NES_COLOR_RGB[0x30]]
PAL_CARRIER_GOLD = [None, NES_COLOR_RGB[0x17], NES_COLOR_RGB[0x28], NES_COLOR_RGB[0x30]]
PAL_SABER  = [None, NES_COLOR_RGB[0x12], NES_COLOR_RGB[0x16], NES_COLOR_RGB[0x30]]

# Extract from gen_chr.py
def load_patterns():
    ns = {}
    with open("tools/gen_chr.py", "r", encoding="utf-8") as f:
        code = f.read()
    
    # Take everything before assets/chr.s writing
    code_before_write = code.split('with open("assets/chr.s"')[0]
    exec(code_before_write, ns)
    return ns

patterns = load_patterns()

def make_boss_48x32(left24):
    rows = []
    for r in left24:
        right = r[::-1]
        rows.append(r + right)
    return rows

CHAR_DEFS = [
    {
        "id": "PLAYER_CORE",
        "name": "自機 コアファイター (第1形態)",
        "category": "player",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 16,
        "height": 16,
        "frames": [
            [
                ".......33.......",
                "......3113......",
                "......3113......",
                ".....332233.....",
                ".....323323.....",
                "....33233233....",
                "...1332222331...",
                "..113332233311..",
                ".11333122133311.",
                "1133311221133311",
                "333221.33.122333",
                "33.22..33..22.33",
                "3.....2332.....3",
                "......2..2......",
                ".....2....2.....",
                "................",
            ],
            [
                ".......33.......",
                "......3113......",
                "......3113......",
                ".....332233.....",
                ".....323323.....",
                "....33233233....",
                "...1332222331...",
                "..113332233311..",
                ".11333122133311.",
                "1133311221133311",
                "333221.33.122333",
                "33.22..33..22.33",
                "3.....2332.....3",
                ".....23..32.....",
                ".....3....3.....",
                ".....2....2.....",
            ]
        ]
    },
    {
        "id": "PLAYER_FORM2",
        "name": "自機 第2形態 (コア+脚部 3-WAY)",
        "category": "player",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 16,
        "height": 24,
        "frames": [
            [
                ".......33.......",
                "......3113......",
                ".....332233.....",
                "....33233233....",
                "..113323323311..",
                ".11333222233311.",
                "1133311221133311",
                "3332211331122333",
                ".3322.2332.2233.",
                "....11322311....",
                "...1133223311...",
                "...3331..1333...",
                "...3331..1333...",
                "..33233..33233..",
                "..33233..33233..",
                "..33333..33333..",
                "..33133..33133..",
                "..33133..33133..",
                "..33333..33333..",
                "..22222..22222..",
                ".223322..223322.",
                ".222222..222222.",
                "..2..2....2..2..",
                "................",
            ]
        ]
    },
    {
        "id": "PLAYER_FORM2_5",
        "name": "自機 第2.5形態 (コア+胸部 2-WAY)",
        "category": "player",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 16,
        "height": 24,
        "frames": [patterns["FORM2_5_CHEST_CORE"]]
    },
    {
        "id": "PLAYER_MS",
        "name": "自機 ガンダムMS (第3形態)",
        "category": "player",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 24,
        "height": 24,
        "frames": [patterns["GUNDAM_STAND_24"]]
    },
    {
        "id": "PART_LEG",
        "name": "合体パーツ B-PARTS (脚部ユニット)",
        "category": "ally",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 16,
        "height": 16,
        "frames": [
            [
                "....11322311....",
                "...1133223311...",
                "..333112211333..",
                "..3331....1333..",
                "..33233..33233..",
                "..33233..33233..",
                "..33333..33333..",
                "..33133..33133..",
                "..33133..33133..",
                "..33333..33333..",
                "..33333..33333..",
                "..22222..22222..",
                ".223322..223322.",
                ".223322..223322.",
                ".222222..222222.",
                "................",
            ]
        ]
    },
    {
        "id": "PART_CHEST",
        "name": "合体パーツ A-PARTS (胸部・頭部ユニット)",
        "category": "ally",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 16,
        "height": 16,
        "frames": [
            [
                "..33...22...33..",
                "...33.3223.33...",
                "....33333333....",
                "....31333313....",
                "....33322333....",
                ".33311122111333.",
                "3323113333113233",
                "3333112222113333",
                "3311111221111133",
                "3311.112211.1133",
                "331..332233..133",
                ".22..331133..22.",
                "......2332......",
                "......2222......",
                "................",
                "................",
            ]
        ]
    },
    {
        "id": "ALLY_CARRIER",
        "name": "味方支援輸送機 (ガンペリー風キャリア)",
        "category": "ally",
        "pal_idx": 3,
        "pal": PAL_CARRIER_GOLD,
        "width": 16,
        "height": 16,
        "frames": [
            [
                "..33..2222..33..",
                ".3113.2332.3113.",
                "3133132332313313",
                "3133132222313313",
                ".31131333313113.",
                "..331132231133..",
                ".22223322332222.",
                "2333332332333332",
                "2333332332333332",
                ".22223322332222.",
                "....11333311....",
                "....13322331....",
                ".....32..23.....",
                ".....2....2.....",
                "................",
                "................",
            ]
        ]
    },
    {
        "id": "ENEMY_SCOUT",
        "name": "モジャ・スカウト (Enemy 0: 小型偵察機)",
        "category": "enemy",
        "pal_idx": 2,
        "pal": PAL_ENEMY_GREEN,
        "width": 16,
        "height": 16,
        "frames": [
            [
                "..1..........1..",
                ".131...11...131.",
                ".131..1331..131.",
                ".111.113311.111.",
                ".11111111111111.",
                ".11331133113311.",
                ".11331133113311.",
                ".11111111111111.",
                ".131.113311.131.",
                ".131..1111..131.",
                ".111..1..1..111.",
                "..1...3..3...1..",
                "......1..1......",
                "................",
                "................",
                "................",
            ]
        ]
    },
    {
        "id": "ENEMY_UFO",
        "name": "アダムスキー型UFO (Enemy 1: 高速円盤)",
        "category": "enemy",
        "pal_idx": 2,
        "pal": PAL_ENEMY_BLUE,
        "width": 16,
        "height": 16,
        "frames": [
            [
                ".....133331.....",
                "....13311331....",
                "...1311331131...",
                "..111111111111..",
                ".11331133113311.",
                "1331133113311331",
                "1111111111111111",
                ".11111111111111.",
                "...1113113111...",
                "....1..11..1....",
                "...3........3...",
                "................",
                "................",
                "................",
                "................",
                "................",
            ]
        ]
    },
    {
        "id": "ENEMY_LANCE",
        "name": "ツインランス突撃機 (Enemy 2: 突撃機)",
        "category": "enemy",
        "pal_idx": 2,
        "pal": PAL_ENEMY_GREEN,
        "width": 16,
        "height": 16,
        "frames": [
            [
                "..3..........3..",
                ".313...11...313.",
                ".111..1331..111.",
                ".11111311311111.",
                ".11311311311311.",
                "..113113311311..",
                "..111331133111..",
                "...1111111111...",
                "....11311311....",
                "....11333311....",
                ".....13..31.....",
                "......3..3......",
                "......1..1......",
                "................",
                "................",
                "................",
            ]
        ]
    },
    {
        "id": "ENEMY_GUNSHIP",
        "name": "重装甲ガンシップ (Enemy 3: 大型重装機)",
        "category": "enemy",
        "pal_idx": 2,
        "pal": PAL_ENEMY_BLUE,
        "width": 16,
        "height": 16,
        "frames": [
            [
                "...1111331111...",
                "..113333333311..",
                ".11311111111311.",
                "1131111331111311",
                "1131111331111311",
                "1311331111331131",
                "1311111331111131",
                ".11311133111311.",
                ".11111111111111.",
                "..131.1..1.131..",
                "..131.3..3.131..",
                "...3..1..1..3...",
                "................",
                "................",
                "................",
                "................",
            ]
        ]
    },
    {
        "id": "MIDBOSS_ZAKU",
        "name": "MOJA-01 量産型ザク中ボス (Stage 1)",
        "category": "boss",
        "pal_idx": 2,
        "pal": PAL_ENEMY_GREEN,
        "width": 24,
        "height": 32,
        "frames": [patterns["MIDBOSS1_ZAKU_24x32"]]
    },
    {
        "id": "MIDBOSS_DOM",
        "name": "MOJA-02 重装甲ドム中ボス (Stage 2)",
        "category": "boss",
        "pal_idx": 1,
        "pal": PAL_RIVAL,
        "width": 24,
        "height": 32,
        "frames": [patterns["MIDBOSS2_DOM_24x32"]]
    },
    {
        "id": "MIDBOSS_ZGOK",
        "name": "MOJA-03 ズゴック水陸中ボス (Stage 3)",
        "category": "boss",
        "pal_idx": 2,
        "pal": PAL_ENEMY_BLUE,
        "width": 24,
        "height": 32,
        "frames": [patterns["MIDBOSS3_ZGOK_24x32"]]
    },
    {
        "id": "MIDBOSS_GOUF",
        "name": "MOJA-04 電熱鞭グフ中ボス (Stage 4)",
        "category": "boss",
        "pal_idx": 2,
        "pal": PAL_ENEMY_BLUE,
        "width": 24,
        "height": 32,
        "frames": [patterns["MIDBOSS4_GOUF_24x32"]]
    },
    {
        "id": "BOSS_RIVAL",
        "name": "宿敵・赤いモビルスーツ (全ステージ決戦)",
        "category": "boss",
        "pal_idx": 1,
        "pal": PAL_RIVAL,
        "width": 24,
        "height": 32,
        "frames": [patterns["RIVAL_RED_MS_24x32"]]
    },
    {
        "id": "BOSS_BIGCORE",
        "name": "LUNAR BIG-CORE (Stage 1 月面要塞ボス)",
        "category": "boss",
        "pal_idx": 3,
        "pal": PAL_CARRIER_GOLD,
        "width": 48,
        "height": 32,
        "frames": [make_boss_48x32(patterns["BOSS1_LEFT24"])]
    },
    {
        "id": "BOSS_VALKYRIE",
        "name": "CRIMSON VALKYRIE (Stage 2 火星要塞ボス)",
        "category": "boss",
        "pal_idx": 1,
        "pal": PAL_RIVAL,
        "width": 48,
        "height": 32,
        "frames": [make_boss_48x32(patterns["BOSS2_LEFT24"])]
    },
    {
        "id": "BOSS_UFO_CARRIER",
        "name": "JUPITER UFO CARRIER (Stage 3 木星超巨大母艦)",
        "category": "boss",
        "pal_idx": 2,
        "pal": PAL_ENEMY_BLUE,
        "width": 48,
        "height": 32,
        "frames": [make_boss_48x32(patterns["BOSS3_LEFT24"])]
    },
    {
        "id": "BOSS_DREADNOUGHT",
        "name": "EMPEROR DREADNOUGHT (Stage 4 最終皇帝要塞艦)",
        "category": "boss",
        "pal_idx": 3,
        "pal": PAL_CARRIER_GOLD,
        "width": 48,
        "height": 32,
        "frames": [make_boss_48x32(patterns["BOSS4_LEFT24"])]
    },
    {
        "id": "PLAYER_SABER",
        "name": "ビームサーベル大一閃 (抜刀・一閃・残心)",
        "category": "player",
        "pal_idx": 0,
        "pal": PAL_SABER,
        "width": 16,
        "height": 16,
        "frames": [patterns["SABER_FRAME1"], patterns["SABER_FRAME2"], patterns["SABER_FRAME3"]]
    },
    {
        "id": "GUNDAM_SIDE_VIEW",
        "name": "ガンダムMS (横画面 1-on-1 ライフル構え)",
        "category": "player",
        "pal_idx": 0,
        "pal": PAL_PLAYER,
        "width": 24,
        "height": 24,
        "frames": [patterns["GUNDAM_SIDE_R_24"]]
    }
]

out_dir = "assets/sprites"
os.makedirs(out_dir, exist_ok=True)
aseprite_exe = r"E:\Tools\Aseprite\aseprite\build\bin\aseprite.exe"
if not os.path.exists(aseprite_exe):
    # Try WSL path
    aseprite_exe = "/mnt/e/Tools/Aseprite/aseprite/build/bin/aseprite.exe"

print(f"Exporting {len(CHAR_DEFS)} characters to {out_dir}...")

for c in CHAR_DEFS:
    cid = c["id"]
    w = c["width"]
    h = c["height"]
    pal = c["pal"]
    frames = c["frames"]
    
    frame_pngs = []
    for f_idx, f_rows in enumerate(frames):
        rgba = []
        for y in range(h):
            row = f_rows[y] if y < len(f_rows) else ""
            for x in range(w):
                ch = row[x] if x < len(row) else "."
                if ch in "123":
                    color = pal[int(ch)]
                    rgba.append(color if color else (0, 0, 0, 0))
                else:
                    rgba.append((0, 0, 0, 0))
        
        f_path = os.path.join(out_dir, f"{cid}_f{f_idx}.png" if len(frames) > 1 else f"{cid}.png")
        write_png(f_path, w, h, rgba)
        frame_pngs.append(f_path)
    
    ase_path = os.path.join(out_dir, f"{cid}.aseprite")
    cmd = [aseprite_exe, "-b"] + frame_pngs + ["--save-as", ase_path]
    
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if res.returncode == 0:
            print(f"  [OK] {cid}: {ase_path} ({w}x{h}, {len(frames)} frames)")
        else:
            print(f"  [FAIL] {cid}: code {res.returncode}")
    except Exception as e:
        print(f"  [ERR] {cid}: {e}")

print("Export completed!")
