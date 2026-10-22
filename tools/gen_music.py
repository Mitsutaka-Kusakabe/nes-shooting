#!/usr/bin/env python3
"""
Generate:
1. assets/music_stage.s : 通常ステージBGM「LUNAR CATACOMB DRIVE」 (D minor, 150 BPM)
2. assets/music_boss.s  : ボス戦BGM「CRIMSON BATTLE GROUND」 (YS2 Boss style, E minor, 180 BPM)
3. assets/music_title.s : タイトルBGM「SPACE MERCHANT - THE SYONIN」 (YS2 The Syonin style, F major, 130 BPM)
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
    """ギャロップ型ベース (休符で歯切れよく)"""
    r2 = r2 or r1
    pat = [0, None, 12, 0, 0, None, 12, 0]
    toks = []
    for root in (r1, r2):
        base = note_index(root)
        for o in pat:
            toks.append(REST if o is None else base + o)
    return toks


def bass_boss_drive(r1, r2=None):
    """YS2ボス風: 激しいルート・オクターブ・5度を織り交ぜた16分スラッシュベース"""
    r2 = r2 or r1
    pat = [0, 12, 0, 12, 7, 12, 0, 12]
    toks = []
    for root in (r1, r2):
        base = note_index(root)
        for o in pat:
            toks.append(base + o)
    return toks


def bass_bounce(r1, r2=None):
    """シャッフル・バウンスベース (The Syonin風: ルートと5度の軽快な跳ね)"""
    r2 = r2 or r1
    pat = [0, None, 12, None, 7, None, 12, None]
    toks = []
    for root in (r1, r2):
        base = note_index(root)
        for o in pat:
            toks.append(REST if o is None else base + o)
    return toks


# =============================================================================
# 1. 通常ステージ曲: LUNAR CATACOMB DRIVE
# =============================================================================
D_STD = "K . . . S . . K K . K . S . . ."
D_INTRO1 = "K . . . . . . . K . . . . . . ."
D_FILL = "K . . . S . . K K . S S S S S S"
D_B = "K . . K S . . K . K K . S . K ."

BARS_STAGE = {
    "I1": (". . . . . . . . . . . . . . . .", bass_drive("D3"), D_INTRO1),
    "I2": (". . . . . . . . A4 - C5 - D5 - E5 -", bass_drive("D3", "A2"), D_FILL),
    "A1": ("F5 - - - - - E5 - D5 - - - A4 - - -", bass_drive("D3"), D_STD),
    "A2": ("Bb4 - - - C5 - D5 - F5 - - - E5 - D5 -", bass_drive("Bb2"), D_STD),
    "A3": ("E5 - - - - - D5 - C5 - - - G4 - - -", bass_drive("C3"), D_STD),
    "A4": ("A4 - - - - - - - . . A4 - C5 - D5 -", bass_drive("D3"), D_STD),
    "A5": ("F5 - - - - - G5 - A5 - - - F5 - D5 -", bass_drive("D3"), D_STD),
    "A6": ("Bb5 - - - A5 - G5 - F5 - - - G5 - A5 -", bass_drive("Bb2"), D_STD),
    "A7": ("G5 - F5 - E5 - D5 - E5 - - - C#5 - - -", bass_drive("G2", "A2"), D_STD),
    "A8": ("D5 - - - - - - - . . . . E5 - F5 -", bass_drive("A2"), D_FILL),
    "B1": ("G5 - - - - - - - Bb5 - A5 - G5 - F5 -", bass_gallop("G2"), D_B),
    "B2": ("E5 - - - - - - - C#5 - D5 - E5 - - -", bass_gallop("A2"), D_B),
    "B3": ("F5 - - - - - E5 - D5 - - - F5 - A5 -", bass_gallop("D3"), D_B),
    "B4": ("C6 - - - - - - - A5 - - - F5 - - -", bass_gallop("F2"), D_B),
    "B5": ("Bb5 - - - A5 - G5 - A5 - - - Bb5 - - -", bass_gallop("G2"), D_B),
    "B6": ("A5 - - - G5 - F5 - E5 - - - C#5 - E5 -", bass_gallop("A2"), D_B),
    "B7": ("F5 - - - E5 - D5 - E5 - - - G5 - - -", bass_drive("Bb2", "C3"), D_STD),
    "B8": ("A5 G5 F5 E5 D5 C#5 D5 E5 F5 E5 D5 C#5 C#5 - D5 -", bass_drive("A2"), D_FILL),
}

ORDER_STAGE = (
    ["I1", "I2"]
    + ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]
    + ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]
    + ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8"]
)
LOOP_STAGE = 2


# =============================================================================
# 2. ボス戦曲: CRIMSON BATTLE GROUND (YS2 Battle Ground Style)
# E minor, テンポ 5フレーム/step = 180 BPM
# =============================================================================
BD_FAST1 = "K . K . S . K . K . K . S . K ."
BD_FAST2 = "K . K . S . K . K K . K S . S ."
BD_FILL  = "K . K . S . K . S S S S S S S S"
BD_HIT   = "K . . . S . . . K . . . S . S ."

BARS_BOSS = {
    "BI1": ("E5 . G5 . B5 . E6 . D#6 . B5 . G5 . D#5 .", bass_boss_drive("E3"), BD_HIT),
    "BI2": ("E5 . G5 . B5 . E6 . D#6 - F#6 - G6 - A6 -", bass_boss_drive("E3", "B2"), BD_FILL),
    "BA1": ("B5 - - - A5 - G5 - F#5 - G5 - E5 - - -", bass_boss_drive("E3"), BD_FAST1),
    "BA2": ("C6 - - - B5 - A5 - G5 - - - A5 - B5 -", bass_boss_drive("C3"), BD_FAST2),
    "BA3": ("A5 - - - G5 - F#5 - E5 - F#5 - D5 - - -", bass_boss_drive("D3"), BD_FAST1),
    "BA4": ("E5 - - - - - - - . . B4 - D5 - E5 -", bass_boss_drive("E3"), BD_FAST2),
    "BA5": ("B5 - - - C6 - D6 - B5 - - - G5 - - -", bass_boss_drive("E3"), BD_FAST1),
    "BA6": ("C6 - - - D6 - E6 - C6 - - - A5 - - -", bass_boss_drive("C3"), BD_FAST2),
    "BA7": ("D6 - - - C6 - B5 - A5 - - - B5 - C6 -", bass_boss_drive("D3"), BD_FAST1),
    "BA8": ("B5 - - - - - - - . . F#5 - G5 - A5 -", bass_boss_drive("B2"), BD_FILL),
    "BB1": ("C6 - - - - - - - E6 - D6 - C6 - B5 -", bass_boss_drive("A2"), BD_FAST1),
    "BB2": ("B5 - - - - - - - D6 - C6 - B5 - A5 -", bass_boss_drive("B2"), BD_FAST2),
    "BB3": ("A5 - - - G5 - F#5 - G5 - - - A5 - - -", bass_boss_drive("C3"), BD_FAST1),
    "BB4": ("F#5 - - - - - - - . . A5 - B5 - C6 -", bass_boss_drive("D3"), BD_FAST2),
    "BB5": ("D6 - - - - - - - F#6 - E6 - D6 - C6 -", bass_boss_drive("D3"), BD_FAST1),
    "BB6": ("E6 - - - - - - - B5 - - - G5 - - -", bass_boss_drive("E3"), BD_FAST2),
    "BB7": ("C6 - - - B5 - A5 - B5 - - - D#6 - - -", bass_boss_drive("C3", "B2"), BD_FAST1),
    "BB8": ("E6 D#6 E6 F#6 G6 F#6 E6 D#6 B5 - D#6 - E6 - - -", bass_boss_drive("B2"), BD_FILL),
}

ORDER_BOSS = (
    ["BI1", "BI2"]
    + ["BA1", "BA2", "BA3", "BA4", "BA5", "BA6", "BA7", "BA8"]
    + ["BB1", "BB2", "BB3", "BB4", "BB5", "BB6", "BB7", "BB8"]
)
LOOP_BOSS = 2


# =============================================================================
# 3. タイトル曲: SPACE MERCHANT - THE SYONIN (YS2 The Syonin Style)
# F major / D minor, 軽快なバウンス・シャッフルビート (7フレーム/step = 130 BPM)
# 愉快でキャッチー、それでいて商人らしい抜け目のなさと活気のあるメロディ！
# =============================================================================
TD_BEAT1 = "K . . . S . . . K . K . S . . ."
TD_BEAT2 = "K . . . S . . . K . . . S . S ."
TD_INTRO = "K . . . . . . . K . . . S . S ."
TD_FILL  = "K . K . S . . K S S S S S S S S"

BARS_TITLE = {
    # イントロ: 鐘やラッパのように明るく陽気なファンファーレ
    "TI1": ("C5 . F5 . A5 . C6 . A5 . F5 . C5 . . .", bass_bounce("F3"), TD_INTRO),
    "TI2": ("D5 . F5 . Bb5 . D6 . C6 - Bb5 - A5 - G5 -", bass_bounce("Bb2", "C3"), TD_FILL),

    # Aセクション: 軽妙なスキップと跳ねるような商人のテーマ (F -> Bb -> C -> F)
    "TA1": ("A5 - F5 - C5 - F5 - A5 - Bb5 - C6 - - -", bass_bounce("F3"), TD_BEAT1),
    "TA2": ("D6 - C6 - Bb5 - A5 - G5 - - - - - - -", bass_bounce("Bb2", "C3"), TD_BEAT2),
    "TA3": ("Bb5 - G5 - D5 - G5 - Bb5 - C6 - D6 - - -", bass_bounce("G2", "C3"), TD_BEAT1),
    "TA4": ("C6 - Bb5 - A5 - G5 - F5 - - - - - - -", bass_bounce("F3"), TD_BEAT2),
    "TA5": ("A5 - F5 - C5 - F5 - A5 - Bb5 - C6 - - -", bass_bounce("F3"), TD_BEAT1),
    "TA6": ("D6 - - - F6 - - - E6 - D6 - C6 - - -", bass_bounce("Bb2", "F3"), TD_BEAT2),
    "TA7": ("Bb5 - A5 - G5 - F5 - E5 - F5 - G5 - - -", bass_bounce("C3"), TD_BEAT1),
    "TA8": ("F5 - - - - - - - . . C5 - D5 - E5 -", bass_bounce("F3"), TD_FILL),

    # Bセクション: 短調が混じるちょっとコミカル＆いたずらっぽい駆け引き (Dm -> Gm -> A -> Dm)
    "TB1": ("F5 - D5 - A4 - D5 - F5 - - - D5 - - -", bass_bounce("D3"), TD_BEAT1),
    "TB2": ("G5 - E5 - Bb4 - E5 - G5 - - - E5 - - -", bass_bounce("G2"), TD_BEAT2),
    "TB3": ("A5 - G5 - F5 - E5 - F5 - E5 - D5 - C#5 -", bass_bounce("A2"), TD_BEAT1),
    "TB4": ("D5 - - - - - - - . . F5 - G5 - A5 -", bass_bounce("D3"), TD_BEAT2),
    "TB5": ("Bb5 - G5 - D5 - G5 - Bb5 - - - - - - -", bass_bounce("G2"), TD_BEAT1),
    "TB6": ("C6 - A5 - F5 - A5 - C6 - - - - - - -", bass_bounce("F3"), TD_BEAT2),
    "TB7": ("D6 - C6 - Bb5 - A5 - G5 - A5 - Bb5 - G5 -", bass_bounce("Bb2", "C3"), TD_BEAT1),
    "TB8": ("C6 - - - - - - - . . G5 - A5 - Bb5 -", bass_bounce("C3"), TD_FILL),
}

ORDER_TITLE = (
    ["TI1", "TI2"]
    + ["TA1", "TA2", "TA3", "TA4", "TA5", "TA6", "TA7", "TA8"]
    + ["TB1", "TB2", "TB3", "TB4", "TB5", "TB6", "TB7", "TB8"]
)
LOOP_TITLE = 2  # イントロ後は TA1 からループ


# =============================================================================
# 4. ゲームオーバー曲: TEARS OF SYLPH (Ys風 Game Over Arrange, D minor, 69.3 BPM)
# =============================================================================
D_SILENT = ". . . . . . . . . . . . . . . ."

BARS_GAMEOVER = {
    "Y1": (
        "A4 - - - D5 - - - F5 - - - E5 - - -",
        "D2 - - - A2 - - - D3 - - - F3 - - -",
        D_SILENT,
        "D4 - - - F4 - - - A4 - - - D5 - - -",
    ),
    "Y2": (
        "D5 - - - - - - - C#5 - - - D5 - - -",
        "C#2 - - - A2 - - - E3 - - - A3 - - -",
        D_SILENT,
        "F4 - - - A4 - - - E4 - - - F4 - - -",
    ),
    "Y3": (
        "E5 - - - - - F5 - D5 - - - - - - -",
        "A#2 - - - F3 - - - A#3 - - - D4 - - -",
        D_SILENT,
        "G4 - - - - - A4 - F4 - - - A4 - - -",
    ),
    "Y4": (
        "C#5 - - - - - - - - - - - - - - -",
        "A2 - - - E3 - - - A3 - - - C#4 - - -",
        D_SILENT,
        "E4 - - - - - - - A4 - - - C#5 - - -",
    ),
    "Y5": (
        "A4 - - - D5 - - - F5 - - - G5 - - -",
        "D2 - - - A2 - - - D3 - - - F3 - - -",
        D_SILENT,
        "D4 - - - F4 - - - A4 - - - B4 - - -",
    ),
    "Y6": (
        "A5 - - - - - - - G5 - - - F5 - - -",
        "G2 - - - D3 - - - G3 - - - A#3 - - -",
        D_SILENT,
        "C#5 - - - - - - - E5 - - - D5 - - -",
    ),
    "Y7": (
        "E5 - - - - - F5 - E5 - - - D5 - - -",
        "A2 - - - E3 - - - G3 - - - A3 - - -",
        D_SILENT,
        "C#5 - - - - - D5 - C#5 - - - A4 - - -",
    ),
    "Y8": (
        "D5 - - - - - - - - - - - - - - -",
        "D2 - - - A2 - - - D3 - - - - - - -",
        D_SILENT,
        "F4 - - - A4 - - - D5 - - - F5 - - -",
    ),
    "Y9": (
        "F5 - - - G5 - - - A5 - - - - - - -",
        "F2 - - - C3 - - - F3 - - - A3 - - -",
        D_SILENT,
        "D5 - - - E5 - - - F5 - - - - - - -",
    ),
    "Y10": (
        "A#5 - - - - - - - A5 - - - G5 - - -",
        "G2 - - - D3 - - - G3 - - - A#3 - - -",
        D_SILENT,
        "G5 - - - - - - - F5 - - - E5 - - -",
    ),
    "Y11": (
        "A5 - - - - - - - F5 - - - D5 - - -",
        "D2 - - - A2 - - - D3 - - - F3 - - -",
        D_SILENT,
        "F5 - - - - - - - D5 - - - A4 - - -",
    ),
    "Y12": (
        "E5 - - - - - - - - - - - - - - -",
        "A2 - - - E3 - - - A3 - - - C#4 - - -",
        D_SILENT,
        "C#5 - - - - - - - - - - - - - - -",
    ),
    "Y13": (
        "F5 - - - E5 - - - D5 - - - C#5 - - -",
        "A#2 - - - F3 - - - A2 - - - E3 - - -",
        D_SILENT,
        "D5 - - - C#5 - - - A#4 - - - A4 - - -",
    ),
    "Y14": (
        "D5 - - - - - - - - - - - - - - -",
        "D2 - - - A2 - - - D3 - - - - - - -",
        D_SILENT,
        "F4 - - - A4 - - - D5 - - - - - - -",
    ),
    "Y15": (
        ". . . . . . . . . . . . . . . .",
        "D2 - - - - - - - . . . . . . . .",
        D_SILENT,
        ". . . . . . . . . . . . . . . .",
    ),
}

ORDER_GAMEOVER = [
    "Y1", "Y2", "Y3", "Y4", "Y5", "Y6", "Y7", "Y8",
    "Y9", "Y10", "Y11", "Y12", "Y13", "Y14", "Y15"
]
LOOP_GAMEOVER = 0


def period(idx):
    midi = idx + MIDI_BASE
    f = 440.0 * 2 ** ((midi - 69) / 12.0)
    p = int(round(CPU / (16.0 * f) - 1))
    assert 0 < p < 0x800
    return p


def generate_music_file(filename, title, prefix, bars, order, loop_pos):
    names = list(bars.keys())
    out = []
    out.append(f"; {title}")
    out.append("; tools/gen_music.py により自動生成 (直接編集しないこと)")
    out.append('.segment "RODATA"\n')
    out.append(f"{prefix}_LOOP = {loop_pos}")
    out.append(f"{prefix}_order:")
    idxs = [names.index(n) for n in order]
    for i in range(0, len(idxs), 16):
        out.append("    .byte " + ", ".join(str(v) for v in idxs[i:i + 16]))
    out.append("    .byte $FF\n")
    out.append(f"{prefix}_pat_lo:")
    out.append("    .byte " + ", ".join(f"<{prefix}_pat_{n}" for n in names))
    out.append(f"{prefix}_pat_hi:")
    out.append("    .byte " + ", ".join(f">{prefix}_pat_{n}" for n in names) + "\n")
    for n in names:
        bar_data = bars[n]
        mel, bass, drum = bar_data[0], bar_data[1], bar_data[2]
        m = parse_line(mel)
        b = bass if isinstance(bass, list) else parse_line(bass)
        d = parse_drum(drum)
        rows = [m, b, d]
        if len(bar_data) > 3 and bar_data[3]:
            rows.append(parse_line(bar_data[3]))
        out.append(f"{prefix}_pat_{n}:")
        for row in rows:
            out.append("    .byte " + ", ".join(f"${v:02X}" for v in row))

    if prefix == "stg":
        out.append("\n; 音程周期テーブル (1 = A1 ... 64 = C7, 0 = 未使用)")
        per = [0] + [period(i) for i in range(1, 65)]
        out.append("stg_period_lo:")
        for i in range(0, 65, 16):
            out.append("    .byte " + ", ".join(f"${p & 0xFF:02X}" for p in per[i:i + 16]))
        out.append("stg_period_hi:")
        for i in range(0, 65, 16):
            out.append("    .byte " + ", ".join(f"${p >> 8:02X}" for p in per[i:i + 16]))

    with open(filename, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"Generated {filename} ({len(names)} bars, order {len(order)} bars)")


def main():
    generate_music_file(
        "assets/music_stage.s",
        "通常ステージBGM「LUNAR CATACOMB DRIVE」(オリジナル曲)",
        "stg",
        BARS_STAGE,
        ORDER_STAGE,
        LOOP_STAGE
    )
    generate_music_file(
        "assets/music_boss.s",
        "ボス戦BGM「CRIMSON BATTLE GROUND」(YS2 Battle Ground Style オリジナル曲)",
        "boss",
        BARS_BOSS,
        ORDER_BOSS,
        LOOP_BOSS
    )
    generate_music_file(
        "assets/music_title.s",
        "タイトルBGM「SPACE MERCHANT - THE SYONIN」(YS2 The Syonin Style オリジナル曲)",
        "title",
        BARS_TITLE,
        ORDER_TITLE,
        LOOP_TITLE
    )
    generate_music_file(
        "assets/music_gameover.s",
        "ゲームオーバーBGM「TEARS OF SYLPH」(Ys風アレンジ)",
        "gov",
        BARS_GAMEOVER,
        ORDER_GAMEOVER,
        LOOP_GAMEOVER
    )


if __name__ == "__main__":
    main()
