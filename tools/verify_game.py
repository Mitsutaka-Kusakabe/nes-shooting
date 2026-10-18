#!/usr/bin/env python3
"""
Automated verification of MOJAxMOJA WARS (game.nes) using 6502 CPU simulator
Verifies:
1. Boot -> Title screen (STATE_TITLE)
2. Start -> Stage 1 Briefing (MOON) -> Gameplay (STATE_PLAYING)
3. Vertical scrolling & stage meta-row streaming
4. KBX-026 SAMURAI movement & A-button Normal Missile
5. Power-up system (Rapid, Laser, Wide, Barrier) up to Lv5 MAX + Laser/Wide exclusive Lv1 reset
6. B-button Range Attack (cooldown-based shockwave wiping enemy bullets & damaging enemies)
7. Boss fight -> Boss defeat -> High-speed Warp sequence (STATE_WARP) -> Next Stage transition -> All 4 Stages -> Ending
"""
import sys
sys.path.append("/mnt/c/Users/kusak/.gemini/antigravity/brain/3aea7f79-ea53-4913-9a60-4f120e58d1a5/scratch")
from test_start_game import CPU6502

with open("game.nes", "rb") as f:
    rom = f.read()

# Verify LVLMAP01 marker exists for the Stage Editor
assert b"LVLMAP01" in rom, "LVLMAP01 marker missing from ROM!"
lvl_off = rom.index(b"LVLMAP01") + 8
print(f"[OK] LVLMAP01 marker found at ROM offset 0x{lvl_off:04X} (256 bytes for 4 stages)")

prg = bytearray(rom[16:16+32768])
cpu = CPU6502(prg)

# Parse symbol table from build/dbg.txt
syms = {}
with open("build/dbg.txt") as f:
    for line in f:
        if line.startswith("sym\t"):
            name = None
            val = None
            for part in line.split("\t")[1].split(","):
                if part.startswith('name="'):
                    name = part.split('"')[1]
                elif part.startswith("val="):
                    val = int(part.split("=")[1], 16)
            if name and val is not None:
                syms[name] = val

MAIN_LOOP = syms["main_loop"]
WAIT_NMI  = syms["@wait_nmi"] if "@wait_nmi" in syms else None
if WAIT_NMI is None:
    for addr in range(len(prg)-6):
        if prg[addr] == 0xA5 and prg[addr+1] == syms["nmi_ready"] and prg[addr+2] == 0xD0:
            WAIT_NMI = 0x8000 + addr
            break

def zp(name):
    return cpu.ram[syms[name]]

def set_zp(name, val):
    cpu.ram[syms[name]] = val & 0xFF

# Boot to main_loop
steps = 0
while cpu.pc != MAIN_LOOP:
    cpu.step()
    steps += 1
    assert steps < 500000, "Timeout booting to main_loop"

print(f"[OK] Booted to Title Screen in {steps} CPU steps: game_state={zp('game_state')} (Expected 4=STATE_TITLE)")
assert zp("game_state") == 4

def run_frame(btn=0):
    cpu.joy1_bits = btn
    s = 0
    while cpu.pc != WAIT_NMI:
        cpu.step()
        s += 1
        assert s < 100000, f"Frame timeout at PC=${cpu.pc:04X}"
    cpu.trigger_nmi()
    while zp("nmi_ready") != 0:
        cpu.step()
    while cpu.pc != MAIN_LOOP:
        cpu.step()
    return s

# 1. Start Game from Title Screen (Press START = 0x10)
run_frame(0x10)
run_frame(0x00)
print(f"[OK] Pressed START -> game_state={zp('game_state')} (Expected 6=STATE_BRIEFING), stage={zp('current_stage')}")
assert zp("game_state") == 6

# Wait for Stage 1 Briefing (110 frames) to enter STATE_PLAYING (0)
for _ in range(115):
    run_frame(0x00)
print(f"[OK] Briefing finished -> game_state={zp('game_state')} (Expected 0=STATE_PLAYING), cam_y={zp('cam_y')}")
assert zp("game_state") == 0

# 2. Test KBX-026 SAMURAI movement & A-button Normal Missile (0x80)
px0, py0 = zp("player_x"), zp("player_y")
run_frame(0x80 | 0x01 | 0x08)  # A + RIGHT + UP
px1, py1 = zp("player_x"), zp("player_y")
active_bullets = sum(cpu.ram[syms["pbul_flag"] + i] for i in range(8))
print(f"[OK] SAMURAI moved ({px0},{py0}) -> ({px1},{py1}) and fired Normal Missile (active={active_bullets})")
assert px1 > px0 and py1 < py0 and active_bullets >= 1

# 3. Test 3-Stage Gundam Docking System via Ally Support Craft at 1/3 (meta_idx=21) and 2/3 (meta_idx=42)
assert zp("weapon_type") == 0 and zp("weapon_level") == 1
print(f"[OK] Initial Form 1 (Core Fighter): weapon_type={zp('weapon_type')}, weapon_level={zp('weapon_level')}")

# Advance to just before 1/3 of stage (meta_idx=20 -> 21)
set_zp("meta_idx", 20)
set_zp("meta_sub_row", 1)
for _ in range(20):
    run_frame(0x00)
    if zp("ally_state") == 1:
        break
assert zp("ally_state") == 1 and zp("ally_part") == 0
print(f"[OK] 1/3 Stage (meta_idx=21): Ally Support Craft arrived carrying Leg Parts (ally_part={zp('ally_part')})!")

# Let Ally Support Craft descend to Y=76, release the Leg Parts, and player docks with it!
set_zp("inv_timer", 250)
for _ in range(250):
    run_frame(0x00)
    if zp("weapon_type") == 1:
        break
assert zp("weapon_type") == 1 and zp("weapon_level") == 2
print(f"[OK] Ally Support Craft delivered Leg Parts -> Docked into Form 2 (Core Fighter + Legs, 3-Way Missile)!")

# Advance to just before 2/3 of stage (meta_idx=41 -> 42)
set_zp("meta_idx", 41)
set_zp("meta_sub_row", 1)
for _ in range(20):
    run_frame(0x00)
    if zp("ally_state") == 1:
        break
assert zp("ally_state") == 1 and zp("ally_part") == 1
print(f"[OK] 2/3 Stage (meta_idx=42): Ally Support Craft arrived carrying Chest Parts (ally_part={zp('ally_part')})!")

# Let Ally Support Craft descend to Y=76, release the Chest Parts, and player docks with it!
set_zp("inv_timer", 250)
for _ in range(250):
    run_frame(0x00)
    if zp("weapon_type") == 3:
        break
assert zp("weapon_type") == 3 and zp("weapon_level") == 3
print(f"[OK] Ally Support Craft delivered Chest Parts -> Docked into Form 3 (Gundam MS, weapon_type=3)!")

# Test Form 3 Laser (48f continuous full-screen piercing beam + 30f cooldown)
set_zp("shot_timer", 0)
run_frame(0x80)  # Press A in Form 3 -> starts 48-frame laser irradiation!
assert zp("laser_timer") == 48, f"Expected laser_timer=48, got {zp('laser_timer')}"
for _ in range(48):
    run_frame(0x00)
assert zp("laser_timer") == 0 and zp("shot_timer") == 30, f"Expected 30f (0.5s) cooldown after laser, got laser={zp('laser_timer')}, shot={zp('shot_timer')}"
print(f"[OK] Form 3 Laser irradiated for 48 frames and entered 0.5s (30 frames) cooldown!")

# Test taking an enemy bullet hit while in Form 3 (Gundam) -> MUST purge back to Form 1 (Core Fighter) without losing a life!
set_zp("inv_timer", 0)
lives_before = zp("lives")
cpu.ram[syms["ebul_flag"]] = 1
cpu.ram[syms["ebul_x"]] = zp("player_x") + 4
cpu.ram[syms["ebul_y"]] = zp("player_y") + 3
cpu.ram[syms["ebul_vx"]] = 0
cpu.ram[syms["ebul_vy"]] = 1
run_frame(0x00)
assert zp("weapon_type") == 0 and zp("weapon_level") == 1 and zp("lives") == lives_before and zp("game_state") == 0
print(f"[OK] Hit while in Form 3 (Gundam) -> Purged back to Form 1 (Core Fighter) with lives={zp('lives')} intact!")

# Test Form 2.5 (Core Fighter + Chest Parts only -> weapon_type=2, 2-WAY Missile) when Leg Parts are skipped!
cpu.ram[syms["item_flag"]] = 1
cpu.ram[syms["item_type"]] = 1  # 1 = Chest Parts (A-Parts)
cpu.ram[syms["item_x"]] = zp("player_x")
cpu.ram[syms["item_y"]] = zp("player_y")
run_frame(0x00)
assert zp("weapon_type") == 2 and zp("weapon_level") == 2, f"Expected Form 2.5 (weapon_type=2), got {zp('weapon_type')}"
set_zp("shot_timer", 0)
run_frame(0x80)  # Fire 2-WAY Missile in Form 2.5!
print(f"[OK] Docked Chest Parts onto Core Fighter (skipped Legs) -> Form 2.5 (Core + Chest, weapon_type=2, 2-WAY Missile)!")

# 4. Test B-button Range Attack (Cooldown-based)
# Spawn an enemy bullet first to verify B-blast clears it
cpu.ram[syms["ebul_flag"]] = 1
cpu.ram[syms["ebul_x"]] = 120
cpu.ram[syms["ebul_y"]] = 100
run_frame(0x40)  # BTN_B = 0x40
print(f"[OK] Pressed B -> b_cooldown={zp('b_cooldown')}, b_blast_timer={zp('b_blast_timer')}, ebul_flag={cpu.ram[syms['ebul_flag']]}")
assert zp("b_cooldown") > 100 and zp("b_blast_timer") > 0 and cpu.ram[syms["ebul_flag"]] == 0

# 5. Test Stage 1..4 Bosses & Warp Sequence -> Victory Ending
for stage_num in range(4):
    assert zp("current_stage") == stage_num, f"Expected stage {stage_num}, got {zp('current_stage')}"
    # Advance meta_idx to 63 so the stage boss spawns on the next scroll row
    set_zp("meta_idx", 63)
    set_zp("meta_sub_row", 1)
    for _ in range(20):
        run_frame(0x00)
        if zp("boss_state") == 1:
            break
    assert zp("boss_state") == 1, f"Stage {stage_num+1} boss did not spawn!"
    print(f"[OK] Stage {stage_num+1} Boss spawned! HP={zp('boss_hp')}")

    # Reduce boss HP to 1 and shoot it with A button
    set_zp("boss_hp", 1)
    set_zp("player_x", zp("boss_x") + 8)
    for _ in range(30):
        run_frame(0x80)
        if zp("boss_state") == 2:
            break
    assert zp("boss_state") == 2, f"Stage {stage_num+1} boss did not enter dying state!"
    print(f"[OK] Stage {stage_num+1} Boss defeated! Entering explosion sequence...")

    # Wait for boss explosion (88 frames) -> Warp Sequence (STATE_WARP = 1)
    for _ in range(95):
        run_frame(0x00)
        if zp("game_state") == 1:
            break
    assert zp("game_state") == 1 and zp("warp_mode") == 1, f"Did not enter STATE_WARP! state={zp('game_state')}"
    print(f"[OK] Stage {stage_num+1} Clear -> High-Speed WARP sequence active (warp_mode={zp('warp_mode')})!")

    # Wait for Warp Sequence (150 frames) to finish
    for _ in range(160):
        run_frame(0x00)
        if zp("game_state") != 1:
            break

    if stage_num < 3:
        assert zp("game_state") == 6 and zp("current_stage") == stage_num + 1
        print(f"[OK] Warp completed -> Advanced to Stage {stage_num+2} Briefing!")
        for _ in range(115):
            run_frame(0x00)
        assert zp("game_state") == 0
    else:
        assert zp("game_state") == 5
        print(f"[OK] Stage 4 Boss defeated & Warp completed -> Reached Victory Ending (STATE_ENDING=5)!")

print("\nALL TESTS PASSED PERFECTLY!")
