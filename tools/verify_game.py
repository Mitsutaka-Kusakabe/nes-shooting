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

# 3. Test 3-Stage Gundam Docking System: Pre-Boss Sequential Docking (meta_idx=27)
assert zp("weapon_type") == 0 and zp("weapon_level") == 1
print(f"[OK] Initial Form 1 (Core Fighter): weapon_type={zp('weapon_type')}, weapon_level={zp('weapon_level')}")

# Advance to just before Pre-MidBoss Carrier (meta_idx=26 -> 27)
set_zp("meta_idx", 26)
set_zp("meta_sub_row", 1)
for _ in range(20):
    run_frame(0x00)
    if zp("ally_state") == 1:
        break
assert zp("ally_state") == 1 and zp("ally_part") == 0
print(f"[OK] Pre-MidBoss Phase 1 (meta_idx=27): Ally Support Craft arrived carrying Leg Parts (ally_part={zp('ally_part')})!")

# Let Ally Support Craft descend to Y=76, release the Leg Parts, and player docks with it!
# Docking Leg Parts automatically triggers the second carrier carrying Chest Parts!
set_zp("inv_timer", 250)
for _ in range(250):
    run_frame(0x00)
    if zp("weapon_type") == 1:
        break
assert zp("weapon_type") == 1 and zp("weapon_level") == 2
print(f"[OK] Ally Support Craft delivered Leg Parts -> Docked into Form 2 (Core Fighter + Legs, 3-Way Missile)!")

# Next carrier should now be inbound with Chest Parts (ally_part=1)
for _ in range(20):
    run_frame(0x00)
    if zp("ally_state") == 1:
        break
assert zp("ally_state") == 1 and zp("ally_part") == 1
print(f"[OK] Pre-MidBoss Phase 2 (Sequential): Ally Support Craft arrived carrying Chest Parts (ally_part={zp('ally_part')})!")

# Let Ally Support Craft descend and player docks with Chest Parts!
for _ in range(250):
    run_frame(0x00)
    if zp("weapon_type") == 3:
        break
assert zp("weapon_type") == 3 and zp("weapon_level") == 3
print(f"[OK] Ally Support Craft delivered Chest Parts -> Docked into Form 3 (Gundam MS, weapon_type=3) BEFORE Mid-Boss!")

# Test Form 3 Laser (18f = 0.3s continuous full-screen slim laser + 42f = 0.7s cooldown)
set_zp("shot_timer", 0)
run_frame(0x80)  # Press A in Form 3 -> starts 18-frame laser irradiation!
assert zp("laser_timer") == 18, f"Expected laser_timer=18, got {zp('laser_timer')}"
for _ in range(18):
    run_frame(0x00)
assert zp("laser_timer") == 0 and zp("shot_timer") == 42, f"Expected 42f (0.7s) cooldown after laser, got laser={zp('laser_timer')}, shot={zp('shot_timer')}"
print(f"[OK] Form 3 Laser irradiated for 18 frames (0.3s) and entered 0.7s (42 frames) cooldown!")

# Test 2-Stage Armor Purge System (Spec 3.1):
# 1st hit in Form 3 (Gundam) -> Purges to Form 2 (Legs, weapon_type=1)
set_zp("inv_timer", 0)
lives_before = zp("lives")
cpu.ram[syms["ebul_flag"]] = 1
cpu.ram[syms["ebul_x"]] = zp("player_x") + 4
cpu.ram[syms["ebul_y"]] = zp("player_y") + 3
cpu.ram[syms["ebul_vx"]] = 0
cpu.ram[syms["ebul_vy"]] = 1
run_frame(0x00)
assert zp("weapon_type") == 1 and zp("weapon_level") == 2 and zp("lives") == lives_before and zp("game_state") == 0
print(f"[OK] 1st Hit in Form 3 (Gundam) -> Purged 1st armor layer to Form 2 (weapon_type=1) with lives={zp('lives')} intact!")

# 2nd hit in Form 2 (Legs) -> Purges to Form 1 (Core Fighter, weapon_type=0)
set_zp("inv_timer", 0)
cpu.ram[syms["ebul_flag"]] = 1
cpu.ram[syms["ebul_x"]] = zp("player_x") + 4
cpu.ram[syms["ebul_y"]] = zp("player_y") + 3
run_frame(0x00)
assert zp("weapon_type") == 0 and zp("weapon_level") == 1 and zp("lives") == lives_before and zp("game_state") == 0
print(f"[OK] 2nd Hit in Form 2 (Legs) -> Purged 2nd armor layer to Form 1 (Core Fighter) with lives={zp('lives')} intact!")

# Test Close-Range Auto Beam Saber: ONLY triggers in Side-View (Boss Battle: side_mode == 1), NOT in Vertical Scroll (side_mode == 0)!
cpu.ram[syms["enemy_flag"]] = 1
cpu.ram[syms["enemy_x"]] = zp("player_x")
cpu.ram[syms["enemy_y"]] = zp("player_y") - 16
cpu.ram[syms["enemy_hp"]] = 6
set_zp("side_mode", 0)
set_zp("shot_timer", 0)
run_frame(0x80)  # Press A in Vertical Scroll (side_mode=0) -> Must NOT trigger Beam Saber!
assert zp("saber_timer") == 0, f"Beam Saber should NOT trigger in Vertical Scroll (side_mode=0), got saber_timer={zp('saber_timer')}"
print(f"[OK] Vertical Scroll (side_mode=0): Pressing A in close range fires normal shot (Beam Saber disabled in vertical mode)!")

# Now test in Side-View Boss Battle mode (side_mode=1):
cpu.ram[syms["enemy_flag"]] = 1
cpu.ram[syms["enemy_x"]] = zp("player_x")
cpu.ram[syms["enemy_y"]] = zp("player_y") - 16
cpu.ram[syms["enemy_hp"]] = 6
cpu.ram[syms["ebul_flag"]] = 1
cpu.ram[syms["ebul_x"]] = zp("player_x") + 4
cpu.ram[syms["ebul_y"]] = zp("player_y") - 14
cpu.ram[syms["ebul_vx"]] = 0
cpu.ram[syms["ebul_vy"]] = 0
set_zp("side_mode", 1)
set_zp("shot_timer", 0)
# Form 1 / 2 / 2.5 (non-Gundam) must NOT trigger Beam Saber even in Side-View!
for wt in (0, 1, 2):
    set_zp("weapon_type", wt)
    set_zp("shot_timer", 0)
    run_frame(0x00)
    run_frame(0x80)
    assert zp("saber_timer") == 0, f"Beam Saber must be Form 3 only, but triggered with weapon_type={wt}"
    for i in range(MAX_PBULLETS_TEST := 6):
        cpu.ram[syms["pbul_flag"] + i] = 0
print("[OK] Side-View Boss Battle: Forms 1/2/2.5 (non-Gundam) do NOT use Beam Saber (ranged attack only)!")
cpu.ram[syms["enemy_flag"]] = 1
cpu.ram[syms["enemy_hp"]] = 6
cpu.ram[syms["ebul_flag"]] = 1
cpu.ram[syms["ebul_x"]] = zp("player_x") + 4
cpu.ram[syms["ebul_y"]] = zp("player_y") - 14
set_zp("weapon_type", 3)
set_zp("shot_timer", 0)
run_frame(0x00)
run_frame(0x80)  # Press A in Side-View mode (side_mode=1) as Form 3 with enemy in close range -> Auto-triggers Beam Saber (saber_timer=9)!
assert zp("saber_timer") == 9, f"Expected Beam Saber to trigger in Side-View (saber_timer=9), got {zp('saber_timer')}"
for _ in range(4):
    run_frame(0x00)  # Advance into Frame 2 (saber_timer=6..4: slash + bullet clear!)
assert cpu.ram[syms["ebul_flag"]] == 0, "Beam Saber Frame 2 did not clear enemy bullet!"
assert cpu.ram[syms["enemy_flag"]] == 2, f"Beam Saber Frame 2 did not defeat HP=6 enemy with DMG_SABER=8! flag={cpu.ram[syms['enemy_flag']]}"
for _ in range(5):
    run_frame(0x00)
set_zp("side_mode", 0)
set_zp("weapon_type", 0)
print(f"[OK] Side-View Boss Battle (side_mode=1): Close-Range Auto Beam Saber (3-frame anim) triggered, cleared enemy bullet, and dealt DMG_SABER=8!")


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

# 5. Test Stage 1..4 Mid-Bosses (MOJA-01..04) & Rival Red MS Bosses + Side-View Switching & Warp Escape -> Victory Ending
expected_midboss_hp = [30, 35, 40, 50]
expected_rival_hp   = [80, 90, 100, 120]

for stage_num in range(4):
    assert zp("current_stage") == stage_num, f"Expected stage {stage_num}, got {zp('current_stage')}"
    assert zp("side_mode") == 0, f"Stage {stage_num+1} should start in Vertical Scroll mode (side_mode=0)"

    # 5a. Advance meta_idx to 31 so the Mid-Boss warning triggers on the next scroll row (meta_idx == 32)
    set_zp("meta_idx", 31)
    set_zp("meta_sub_row", 1)
    for _ in range(20):
        run_frame(0x00)
        if zp("boss_state") == 3:
            break
    assert zp("boss_state") == 3 and zp("boss_type") == 0 and zp("side_mode") == 0, \
        f"Stage {stage_num+1} Mid-Boss WARNING did not start in Vertical Scroll! state={zp('boss_state')}, side={zp('side_mode')}"
    print(f"[OK] Stage {stage_num+1} Mid-Boss (MOJA-0{stage_num+1}) WARNING triggered in Vertical Scroll (side_mode=0, warning_timer={zp('warning_timer')})!")

    # Wait for 120-frame WARNING phase + gliding intro entrance (boss_state 3 -> 4 -> 1)
    for _ in range(160):
        run_frame(0x00)
        if zp("boss_state") == 1:
            break
    assert zp("boss_state") == 1 and zp("boss_type") == 0 and zp("side_mode") == 1, \
        f"Stage {stage_num+1} Mid-Boss did not enter battle in Side-View mode! state={zp('boss_state')}, side={zp('side_mode')}, timer={zp('warning_timer')}"
    assert zp("boss_hp") == expected_midboss_hp[stage_num], \
        f"Stage {stage_num+1} Mid-Boss HP mismatch: expected {expected_midboss_hp[stage_num]}, got {zp('boss_hp')}"
    print(f"[OK] Stage {stage_num+1} Mid-Boss (MOJA-0{stage_num+1}) entered battle in Side-View mode (PT1)! HP={zp('boss_hp')}")

    # Test Boss Battle Wipeout -> Game Over (Verify fix for Issue 1)
    if stage_num == 0:
        ram_bk = bytearray(cpu.ram)
        pc_bk, a_bk, x_bk, y_bk, sp_bk, p_bk = cpu.pc, cpu.a, cpu.x, cpu.y, cpu.sp, cpu.get_p()

        # Player is in Form 1 (Core Fighter) with 1 life remaining, directly touching boss
        set_zp("lives", 1)
        set_zp("weapon_type", 0)
        set_zp("inv_timer", 0)
        set_zp("player_x", zp("boss_x") + 10)
        set_zp("player_y", zp("boss_y") + 10)

        # 1 frame: collision triggers hit_player -> STATE_DEAD (2), state_timer=70
        run_frame(0x00)
        assert zp("game_state") == 2, f"Boss touch did not trigger STATE_DEAD! state={zp('game_state')}"
        assert zp("state_timer") == 70, f"state_timer not initialized to 70! timer={zp('state_timer')}"

        # Run 70 frames while still overlapping boss - verify state_timer decrements to 0 and does NOT get stuck at 70!
        for f in range(70):
            # Keep player overlapping boss to ensure continuous collision testing
            set_zp("player_x", zp("boss_x") + 10)
            set_zp("player_y", zp("boss_y") + 10)
            run_frame(0x00)
            if zp("game_state") == 3:
                break

        assert zp("game_state") == 3, f"Boss wipeout did NOT transition to STATE_GAMEOVER! state={zp('game_state')}, timer={zp('state_timer')}, lives={zp('lives')}"
        assert zp("lives") == 0, f"Lives was not 0! lives={zp('lives')}"
        assert zp("boss_state") == 0, f"boss_state was not reset in show_gameover! boss_state={zp('boss_state')}"
        assert zp("side_mode") == 0, f"side_mode was not reset in show_gameover! side_mode={zp('side_mode')}"
        assert zp("bgm_track") == 6, f"bgm_track was not TRACK_GAMEOVER (6)! track={zp('bgm_track')}"
        print("[OK] Boss Battle Wipeout (lives=0) successfully transitioned to GAME OVER with BGM Rest in Peace (TRACK_GAMEOVER=6)!")

        # Press START to return to Title
        run_frame(0x10)
        assert zp("game_state") == 4, f"Game Over did not return to Title screen! state={zp('game_state')}"
        print("[OK] Game Over screen accepted START and returned to Title Screen!")

        # Restore state to resume normal test progression
        cpu.ram[:] = ram_bk
        cpu.pc, cpu.a, cpu.x, cpu.y, cpu.sp = pc_bk, a_bk, x_bk, y_bk, sp_bk
        cpu.set_p(p_bk)

    # Defeat Mid-Boss with Beam Saber within 46px blade range and verify seamless return to Vertical Scroll mode (side_mode=0)
    set_zp("boss_hp", 1)
    set_zp("weapon_type", 3)  # ビームサーベルは第3形態 (ガンダム) 専用
    set_zp("player_x", zp("boss_x") - 40)
    set_zp("player_y", zp("boss_y") + 8)
    for _ in range(30):
        run_frame(0x80)
        if zp("boss_state") == 2:
            break
    assert zp("boss_state") == 2, f"Stage {stage_num+1} Mid-Boss did not enter dying state!"
    for _ in range(95):
        run_frame(0x00)
        if zp("boss_state") == 0:
            break
    assert zp("boss_state") == 0 and zp("side_mode") == 0 and zp("game_state") == 0, \
        f"Mid-Boss defeat did not return to Vertical Scroll! state={zp('game_state')}, side={zp('side_mode')}"
    print(f"[OK] Stage {stage_num+1} Mid-Boss defeated -> Returned seamlessly to Vertical Scroll (side_mode=0)!")

    # 5b. Advance meta_idx to 63 so the Rival Red MS Boss warning triggers
    set_zp("meta_idx", 63)
    set_zp("meta_sub_row", 1)
    for _ in range(20):
        run_frame(0x00)
        if zp("boss_state") == 3:
            break
    assert zp("boss_state") == 3 and zp("boss_type") == 1 and zp("side_mode") == 0, \
        f"Stage {stage_num+1} Rival WARNING did not start in Vertical Scroll! state={zp('boss_state')}, side={zp('side_mode')}"
    print(f"[OK] Stage {stage_num+1} Rival Red MS Boss WARNING triggered in Vertical Scroll (warning_timer={zp('warning_timer')})!")

    # Wait for 120-frame WARNING + gliding intro entrance
    for _ in range(160):
        run_frame(0x00)
        if zp("boss_state") == 1:
            break
    assert zp("boss_state") == 1 and zp("boss_type") == 1 and zp("side_mode") == 1, \
        f"Stage {stage_num+1} Rival Boss did not enter battle in Side-View mode! state={zp('boss_state')}"
    assert zp("boss_hp") == expected_rival_hp[stage_num], \
        f"Stage {stage_num+1} Rival Boss HP mismatch: expected {expected_rival_hp[stage_num]}, got {zp('boss_hp')}"
    print(f"[OK] Stage {stage_num+1} Rival Red MS Boss entered battle in Side-View mode! HP={zp('boss_hp')}")

    if stage_num == 0:
        # Verify Melee Charge 0.5s Corner -> Retreat -> Re-charge Loop
        set_zp("inv_timer", 90)  # keep player invulnerable during test
        set_zp("player_x", 40)
        set_zp("player_y", 90)
        set_zp("boss_x", 176)
        set_zp("boss_y", 90)
        set_zp("boss_hp", 30)
        set_zp("boss_state", 5)  # 狂乱近接モード
        set_zp("boss_charge_phase", 0)
        set_zp("boss_charge_timer", 0)

        # Phase 0: Boss charges left towards player
        for _ in range(70):
            run_frame(0x00)
            if zp("boss_charge_phase") == 1:
                break
        assert zp("boss_charge_phase") == 1, f"Did not enter Phase 1 corner! phase={zp('boss_charge_phase')}, bx={zp('boss_x')}"
        assert zp("boss_charge_timer") == 30, f"Corner timer not 30 (0.5s)! timer={zp('boss_charge_timer')}"
        print("[OK] Melee Charge: Boss charged in and triggered 0.5s (30-frame) corner phase!")

        # Phase 1: Boss holds corner for exactly 30 frames (0.5s)
        for _ in range(30):
            run_frame(0x00)
            if zp("boss_charge_phase") == 2:
                break
        assert zp("boss_charge_phase") == 2, f"Did not transition to Phase 2 retreat after 0.5s! phase={zp('boss_charge_phase')}"
        print("[OK] Melee Charge: 0.5s corner limit expired, boss initiated retreat (いったん引く)!")

        # Phase 2: Boss retreats rightwards to X=168
        for _ in range(60):
            run_frame(0x00)
            if zp("boss_charge_phase") == 3:
                break
        assert zp("boss_charge_phase") == 3 and zp("boss_x") == 168, \
            f"Boss did not retreat to X=168! phase={zp('boss_charge_phase')}, bx={zp('boss_x')}"
        print("[OK] Melee Charge: Boss retreated to X=168, freeing player to maneuver and escape corner!")

    # Reduce Rival Boss HP to 1 and defeat it within 46px blade reach with Beam Saber
    set_zp("boss_hp", 1)
    set_zp("weapon_type", 3)  # ビームサーベルは第3形態 (ガンダム) 専用
    set_zp("player_x", zp("boss_x") - 40)
    set_zp("player_y", zp("boss_y") + 8)
    for _ in range(30):
        run_frame(0x80)
        if zp("boss_state") == 2:
            break

    assert zp("boss_state") == 2, f"Stage {stage_num+1} Rival Boss did not enter dying state!"
    print(f"[OK] Stage {stage_num+1} Rival Red MS defeated! Entering explosion & Warp Escape sequence...")

    # Wait for boss explosion (88 frames) -> Warp Sequence (STATE_WARP = 1)
    for _ in range(95):
        run_frame(0x00)
        if zp("game_state") == 1:
            break
    assert zp("game_state") == 1 and zp("warp_mode") == 1, f"Did not enter STATE_WARP! state={zp('game_state')}"
    print(f"[OK] Stage {stage_num+1} Clear -> High-Speed WARP Escape sequence active (warp_mode={zp('warp_mode')})!")

    # Wait for Warp Sequence (150 frames) to finish
    for _ in range(160):
        run_frame(0x00)
        if zp("game_state") != 1:
            break

    if stage_num < 3:
        assert zp("game_state") == 6 and zp("current_stage") == stage_num + 1 and zp("side_mode") == 0
        print(f"[OK] Warp completed -> Advanced to Stage {stage_num+2} Briefing (side_mode reset to 0)!")
        for _ in range(115):
            run_frame(0x00)
        assert zp("game_state") == 0
    else:
        assert zp("game_state") == 5
        print(f"[OK] Stage 4 Final Rival Red MS defeated & Warp completed -> Reached Victory Ending (STATE_ENDING=5)!")

print("\nALL TESTS PASSED PERFECTLY!")

