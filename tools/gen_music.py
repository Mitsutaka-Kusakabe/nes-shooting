#!/usr/bin/env python3
"""
Generate assets/music_stage.s : 通常ステージBGM「LUNAR CATACOMB DRIVE」(オリジナル曲)
80年代アクションRPGのダンジョン曲風 (短調・疾走16分ベース・哀愁リード) を意識した完全オリジナル楽曲。

書式: 1小節 = 16ステップ (16分音符)。テンポ 6フレーム/ステップ = 150BPM
  メロディ/ベース: 音名 (例 D5, Bb4, C#5) / '-' = 前の音を伸ばす / '.' = 休符
  ドラム        : 'K' = キック(DPCM) / 'S' = スネア(DPCM) / '.' = なし  (ハイハットはエンジン側で自動)
  ベースは三角波 (表記より1オクターブ低く鳴る)
出力コード: 0 = 休符, $FF = 伸ばし, 1..64 = 音程 (1 = A1 ... 64 = C7)
"""

CPU = 1789773.0
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
HOLD, REST = 0xFF, 0x00
MIDI_BASE = 32  # index 1 = MIDI 33 (A1)


def note_index(tok):
    name = tok[0]
    rest = tok[1:]
    semi = NOTE_NAMES[name]
    while rest and rest[0] in "#b":
        semi += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    midi = (octave + 1) * 12 + semi
    idx = midi - MIDI_BASE
    assert 1 <= idx <= 64, f"note out of range: {tok}"
    return idx


def parse_line(line):
    toks = line.split()
    assert len(toks) == 16, f"need 16 steps: {line!r} ({len(toks)})"
    out = []
    for t in toks:
        if t == "-":
            out.append(HOLD)
        elif t == ".":
            out.append(REST)
        else:
            out.append(note_index(t))
    return out


def parse_drum(line):
    toks = line.split()
    assert len(toks) == 16, f"need 16 drum steps: {line!r}"
    return [{"K": 1, "S": 2, ".": 0}[t] for t in toks]


def bass_drive(r1, r2=None):
    """16分オクターブ・ドライブベース (前半 r1 / 後半 r2)"""
    r2 = r2 or r1
    pat = [0, 0, 12, 0, 0, 12, 0, 12]
    toks = []
    for half, root in ((0, r1), (1, r2)):
        base = note_index(root)
        for o in pat:
            toks.append(base + o)
    return toks


def bass_gallop(r1, r2=None):
    """ギャロップ型ベース (Bセクション用、休符で歯切れよく)"""
    r2 = r2 or r1
    pat = [0, None, 12, 0, 0, None, 12, 0]
    toks = []
    for root in (r1, r2):
        base = note_index(root)
        for o in pat:
            toks.append(REST if o is None else base + o)
    return toks


D_STD = "K . . . S . . K K . K . S . . ."
D_INTRO1 = "K . . . . . . . K . . . . . . ."
D_FILL = "K . . . S . . K K . S S S S S S"
D_B = "K . . K S . . K . K K . S . K ."

# ---- 小節定義: (メロディ, ベース, ドラム) ----
BARS = {
    # イントロ: ベースとドラムだけで疾走感を立ち上げ、2小節目で駆け上がり
    "I1": (". . . . . . . . . . . . . . . .", bass_drive("D3"), D_INTRO1),
    "I2": (". . . . . . . . A4 - C5 - D5 - E5 -", bass_drive("D3", "A2"), D_FILL),

    # A セクション: Dm | Bb | C | Dm | Dm | Bb | Gm A | A
    "A1": ("F5 - - - - - E5 - D5 - - - A4 - - -", bass_drive("D3"), D_STD),
    "A2": ("Bb4 - - - C5 - D5 - F5 - - - E5 - D5 -", bass_drive("Bb2"), D_STD),
    "A3": ("E5 - - - - - D5 - C5 - - - G4 - - -", bass_drive("C3"), D_STD),
    "A4": ("A4 - - - - - - - . . A4 - C5 - D5 -", bass_drive("D3"), D_STD),
    "A5": ("F5 - - - - - G5 - A5 - - - F5 - D5 -", bass_drive("D3"), D_STD),
    "A6": ("Bb5 - - - A5 - G5 - F5 - - - G5 - A5 -", bass_drive("Bb2"), D_STD),
    "A7": ("G5 - F5 - E5 - D5 - E5 - - - C#5 - - -", bass_drive("G2", "A2"), D_STD),
    "A8": ("A4 - - - - - - - . . . . E5 - F5 -", bass_drive("A2"), D_FILL),

    # B セクション: Gm | A | Dm | F | Gm | A | Bb C | A (16分の下降ラン)
    "B1": ("G5 - - - - - - - Bb5 - A5 - G5 - F5 -", bass_gallop("G2"), D_B),
    "B2": ("E5 - - - - - - - C#5 - D5 - E5 - - -", bass_gallop("A2"), D_B),
    "B3": ("F5 - - - - - E5 - D5 - - - F5 - A5 -", bass_gallop("D3"), D_B),
    "B4": ("C6 - - - - - - - A5 - - - F5 - - -", bass_gallop("F2"), D_B),
    "B5": ("Bb5 - - - A5 - G5 - A5 - - - Bb5 - - -", bass_gallop("G2"), D_B),
    "B6": ("A5 - - - G5 - F5 - E5 - - - C#5 - E5 -", bass_gallop("A2"), D_B),
    "B7": ("F5 - - - E5 - D5 - E5 - - - G5 - - -", bass_drive("Bb2", "C3"), D_STD),
    "B8": ("A5 G5 F5 E5 D5 C#5 D5 E5 F5 E5 D5 C#5 A4 - - -", bass_drive("A2"), D_FILL),
}

ORDER = (
    ["I1", "I2"]
    + ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]
    + ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]
    + ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8"]
)
LOOP_POS = 2  # ループ時はイントロを飛ばして A1 から


def period(idx):
    midi = idx + MIDI_BASE
    f = 440.0 * 2 ** ((midi - 69) / 12.0)
    p = int(round(CPU / (16.0 * f) - 1))
    assert 0 < p < 0x800
    return p


def main():
    names = list(BARS.keys())
    out = []
    out.append("; 通常ステージBGM「LUNAR CATACOMB DRIVE」(オリジナル曲)")
    out.append("; tools/gen_music.py により自動生成 (直接編集しないこと)")
    out.append(".segment \"RODATA\"\n")
    out.append(f"STG_LOOP = {LOOP_POS}")
    out.append("stg_order:")
    idxs = [names.index(n) for n in ORDER]
    for i in range(0, len(idxs), 16):
        out.append("    .byte " + ", ".join(str(v) for v in idxs[i:i + 16]))
    out.append("    .byte $FF\n")
    out.append("stg_pat_lo:")
    out.append("    .byte " + ", ".join(f"<stg_pat_{n}" for n in names))
    out.append("stg_pat_hi:")
    out.append("    .byte " + ", ".join(f">stg_pat_{n}" for n in names) + "\n")
    for n in names:
        mel, bass, drum = BARS[n]
        m = parse_line(mel)
        b = bass if isinstance(bass, list) else parse_line(bass)
        d = parse_drum(drum)
        out.append(f"stg_pat_{n}:")
        for row in (m, b, d):
            out.append("    .byte " + ", ".join(f"${v:02X}" for v in row))
    out.append("\n; 音程周期テーブル (1 = A1 ... 64 = C7, 0 = 未使用)")
    per = [0] + [period(i) for i in range(1, 65)]
    out.append("stg_period_lo:")
    for i in range(0, 65, 16):
        out.append("    .byte " + ", ".join(f"${p & 0xFF:02X}" for p in per[i:i + 16]))
    out.append("stg_period_hi:")
    for i in range(0, 65, 16):
        out.append("    .byte " + ", ".join(f"${p >> 8:02X}" for p in per[i:i + 16]))
    with open("assets/music_stage.s", "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    secs = len(ORDER) * 16 * 6 / 60.0
    print(f"Generated assets/music_stage.s ({len(names)} bars, order {len(ORDER)} bars = {secs:.1f}s)")


if __name__ == "__main__":
    main()
