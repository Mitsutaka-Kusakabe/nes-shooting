import sys
sys.path.append("/mnt/c/Users/kusak/.gemini/antigravity/brain/3aea7f79-ea53-4913-9a60-4f120e58d1a5/scratch")
from test_start_game import CPU6502

with open("game.nes", "rb") as f:
    rom = f.read()

prg = bytearray(rom[16:16+32768])
cpu = CPU6502(prg)

syms = {}
with open("build/dbg.txt") as f:
    for line in f:
        line = line.strip()
        if line.startswith("sym\t") and 'name="' in line:
            for part in line.split("\t")[1].split(","):
                if part.startswith('name="'):
                    name = part.split('"')[1]
                elif part.startswith("val="):
                    val = int(part.split("=")[1], 16)
            if name and val is not None:
                syms[name] = val

def zp(name):
    return cpu.ram[syms[name]]

MAIN_LOOP = syms["main_loop"]
WAIT_NMI = syms["@wait_nmi"] if "@wait_nmi" in syms else None
if WAIT_NMI is None:
    for k, v in syms.items():
        if "wait_nmi" in k.lower():
            WAIT_NMI = v
            break

steps = 0
while cpu.pc != MAIN_LOOP:
    cpu.step()
    steps += 1
    assert steps < 500000

def run_frame(btn=0):
    cpu.joy1_bits = btn
    s = 0
    while cpu.pc != WAIT_NMI:
        cpu.step()
        s += 1
        assert s < 100000
    cpu.trigger_nmi()
    while zp("nmi_ready") != 0:
        cpu.step()
    while cpu.pc != MAIN_LOOP:
        cpu.step()
    return s

for _ in range(5):
    run_frame(0)

print(f"Title state: {zp('game_state')}, menu_sel: {zp('menu_sel')}")
assert zp('game_state') == 4

# BTN_SELECT is 0x20. Press SELECT twice to move to BOSS BATTLE (menu_sel=2)
run_frame(0x20) # SELECT
run_frame(0)
print(f"After 1st SELECT -> menu_sel: {zp('menu_sel')}")
assert zp('menu_sel') == 1

run_frame(0x20) # SELECT
run_frame(0)
print(f"After 2nd SELECT -> menu_sel: {zp('menu_sel')}")
assert zp('menu_sel') == 2

# Cycle boss_select with RIGHT (0x01) to select 4 (Rival Red MS)
for _ in range(4):
    run_frame(0x01) # RIGHT
    run_frame(0)
print(f"boss_select: {zp('boss_select')}")
assert zp('boss_select') == 4

# Press START (0x10) to begin BOSS BATTLE
run_frame(0x10) # START
run_frame(0)

print(f"Game state: {zp('game_state')}, side_mode: {zp('side_mode')}, boss_state: {zp('boss_state')}, boss_type: {zp('boss_type')}, weapon_type: {zp('weapon_type')}, lives: {zp('lives')}")
assert zp('side_mode') == 1, "Expected side_mode == 1"
assert zp('boss_state') == 1, "Expected boss_state == 1"
assert zp('boss_type') == 1, "Expected boss_type == 1"
assert zp('weapon_type') == 3, "Expected weapon_type == 3 (Gundam)"
assert zp('lives') == 5, "Expected lives == 5"

# Now test SELECT button in fight: toggle into Saber Duel Frenzy!
run_frame(0x20) # SELECT during fight
run_frame(0)
print(f"After pressing SELECT in fight: boss_state={zp('boss_state')}, hp={zp('boss_hp')}")
assert zp('boss_state') == 5, "Expected boss_state == 5 (Saber Duel mode)"

# Test SELECT button again to toggle back
run_frame(0x20) # SELECT again
run_frame(0)
print(f"After 2nd SELECT in fight: boss_state={zp('boss_state')}")
assert zp('boss_state') == 1, "Expected boss_state == 1 (Normal combat)"

print("=== ALL BOSS BATTLE & SELECT TOGGLE TESTS PASSED PERFECTLY! ===")
