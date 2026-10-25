#!/usr/bin/env python3
"""
README / 仕様書用の高解像度スクリーンショット & キャラクタ画像を docs/images/ に生成する。
実機と同じ 6502 エミュレータ + PPU 描画を使い、RAM を直接セットして各場面を再現する。

使い方: python3 tools/render_readme_shots.py   (game.nes と build/dbg.txt が必要)
"""
import os

# render_screens.py の「# 1. Title screen」より前 (エミュレータ・PPU・run_frame 定義) を再利用する
_src = open("tools/render_screens.py", encoding="utf-8").read()
exec(compile(_src.split("# 1. Title screen")[0], "render_screens_head", "exec"))

OUT = "docs/images"
os.makedirs(OUT, exist_ok=True)

BTN_A, BTN_B, BTN_SELECT, BTN_START = 0x80, 0x40, 0x20, 0x10
BTN_RIGHT, BTN_LEFT, BTN_DOWN, BTN_UP = 0x01, 0x02, 0x04, 0x08

def ram(name, v, idx=0):
    nes.ram[syms[name] + idx] = v

def get(name, idx=0):
    return nes.ram[syms[name] + idx]

def shot(name, scale=2, crop=None, btn=0):
    """kill_flash を消した上で1フレーム進めて撮影。"""
    ram("kill_flash", 0)
    ram("frame_count", 0)   # 次フレームで 1 になり、狂乱ボスの赤/シアン点滅が通常色 (赤) になる
    run_frame(btn)
    ram("kill_flash", 0)
    nes.render_png(f"{OUT}/{name}.png", scale=scale, crop=crop)
    print("wrote", f"{OUT}/{name}.png")

def clear_field():
    for i in range(6):
        ram("enemy_flag", 0, i)
        ram("ebul_flag", 0, i)
    for i in range(8):
        ram("pbul_flag", 0, i)
    for i in range(2):
        ram("item_flag", 0, i)
    ram("ally_state", 0)
    ram("spawner_cnt", 0)

def put_enemy(i, x, y, etype):
    ram("enemy_flag", 1, i)
    ram("enemy_x", x, i)
    ram("enemy_y", y, i)
    ram("enemy_type", etype, i)
    ram("enemy_timer", 0, i)
    ram("enemy_hp", 3 if etype == 3 else 1, i)
    ram("enemy_drop", 0, i)

# ---------------------------------------------------------------- タイトル
for _ in range(5):
    run_frame(0)
shot("title", 2)

# ---------------------------------------------------------------- STAGE 1 開始 (ブリーフィング → 道中)
run_frame(BTN_START)
run_frame(0)
shot("briefing", 2)
for _ in range(120):
    run_frame(0)

# ---------------------------------------------------------------- キャラクタ画像 (縦スクロール道中)
ram("inv_timer", 0)
clear_field()
ram("player_x", 120)
ram("player_y", 120)
for wt, name in [(0, "form1"), (1, "form2"), (2, "form25"), (3, "form3")]:
    ram("weapon_type", wt)
    ram("weapon_level", 3 if wt == 3 else (2 if wt else 1))
    ram("inv_timer", 0)
    ram("laser_timer", 0)
    ram("shot_timer", 99)
    shot(name, 6, crop=(108, 108, 40, 40))

# 敵4種
clear_field()
ram("player_x", 120)
ram("player_y", 200)
ram("weapon_type", 0)
for etype, name in [(0, "enemy_scout"), (1, "enemy_swoop"), (2, "enemy_charger"), (3, "enemy_turret")]:
    clear_field()
    put_enemy(0, 120, 100, etype)
    # 1フレームだけ進める (AIで座標がわずかに動く)
    shot(name, 6, crop=(108, 92, 40, 40))

# 味方支援輸送機 + 脚部パーツ / 胸部パーツ
clear_field()
ram("ally_state", 1)
ram("ally_x", 120)
ram("ally_y", 60)
ram("ally_part", 0)
shot("ally_carrier", 6, crop=(100, 44, 40, 48))
clear_field()
for part, name in [(0, "part_legs"), (1, "part_chest")]:
    clear_field()
    ram("item_flag", 1, 0)
    ram("item_type", part, 0)
    ram("item_x", 120, 0)
    ram("item_y", 100, 0)
    shot(name, 6, crop=(108, 92, 40, 40))

# ---------------------------------------------------------------- STAGE 1 ゲーム画面 (F3 レーザー照射 + 編隊)
clear_field()
ram("weapon_type", 3)
ram("weapon_level", 3)
ram("inv_timer", 0)
ram("player_x", 112)
ram("player_y", 168)
put_enemy(0, 112, 40, 0)
put_enemy(1, 96, 64, 1)
put_enemy(2, 128, 64, 1)
put_enemy(3, 60, 84, 2)
put_enemy(4, 168, 84, 2)
# 敵弾
ram("ebul_flag", 1, 0); ram("ebul_x", 80, 0); ram("ebul_y", 110, 0); ram("ebul_vx", 0, 0); ram("ebul_vy", 0, 0); ram("ebul_tile", 0x0E, 0)
ram("ebul_flag", 1, 1); ram("ebul_x", 150, 1); ram("ebul_y", 120, 1); ram("ebul_vx", 0, 1); ram("ebul_vy", 0, 1); ram("ebul_tile", 0x0E, 1)
ram("laser_timer", 12)
ram("shot_timer", 0)
shot("stage1_gameplay", 3)

# 合体シーン (支援輸送機投下)
clear_field()
ram("weapon_type", 1)
ram("weapon_level", 2)
ram("player_x", 112)
ram("player_y", 168)
ram("ally_state", 1)
ram("ally_x", 112)
ram("ally_y", 70)
ram("ally_part", 1)
ram("laser_timer", 0)
put_enemy(0, 60, 40, 0)
put_enemy(1, 180, 50, 1)
shot("stage1_docking", 3)

# ---------------------------------------------------------------- WARNING
clear_field()
ram("boss_state", 3)
ram("boss_type", 0)
ram("side_mode", 0)
ram("warning_timer", 101)
shot("warning", 3)

# ---------------------------------------------------------------- ボス戦 (横画面)
def setup_boss(boss_type, stage, boss_x=176, boss_y=92, state=1):
    ram("current_stage", stage)
    ram("boss_type", boss_type)
    ram("side_mode", 1)
    ram("boss_state", state)
    ram("boss_x", boss_x)
    ram("boss_y", boss_y)
    ram("boss_hp", 30)
    ram("boss_max_hp", 30)
    ram("boss_flash", 0)
    ram("boss_beam_timer", 0)
    ram("boss_charge_phase", 0)
    ram("boss_charge_timer", 0)
    ram("boss_saber_stance", 0)
    ram("boss_saber_timer", 30)
    ram("boss_timer", 0)
    ram("saber_timer", 0)
    ram("laser_timer", 0)
    ram("weapon_type", 3)
    ram("weapon_level", 3)
    ram("inv_timer", 1)
    ram("player_x", 44)
    ram("player_y", 100)
    ram("cam_x", 1)
    clear_field()

# ボス戦はHUDを除いた領域のみ切り出す
BOSS_CROP = (0, 28, 256, 184)

# STAGE 1 中ボス (ザク型) と対峙 + レーザー照射
setup_boss(0, 0, 176, 92)
ram("laser_timer", 12)
shot("boss_stage1_midboss", 3, crop=BOSS_CROP)

# ボス図鑑 (5体) ※ side_mode 横向き描画
for btype, stage, name in [(0, 0, "boss_trooper"), (0, 1, "boss_hover"), (0, 2, "boss_claw"), (0, 3, "boss_whip"), (1, 0, "boss_rival")]:
    setup_boss(btype, stage, 100, 80)
    ram("player_x", 8)
    ram("player_y", 220)  # 画面下端に退避
    shot(name, 4, crop=(84, 64, 64, 56))

# 宿敵・赤いMS: 上段の構え / 振り下ろし
setup_boss(1, 0, 108, 92, state=5)
ram("boss_saber_stance", 0)
ram("boss_saber_timer", 20)
ram("player_x", 44)
ram("player_y", 92)
shot("boss_saber_jodan", 3, crop=BOSS_CROP, btn=0)

setup_boss(1, 0, 92, 92, state=5)
ram("boss_saber_stance", 1)
ram("boss_saber_timer", 20)
ram("player_x", 44)
ram("player_y", 92)
shot("boss_saber_slash", 3, crop=BOSS_CROP, btn=BTN_A)

# STAGE 4 ラスボス: 即死荷電粒子ビーム
setup_boss(1, 3, 176, 80)
ram("boss_beam_timer", 250)
ram("player_x", 44)
ram("player_y", 180)
ram("inv_timer", 1)
shot("boss_final_beam", 3, crop=BOSS_CROP)

print("done")
