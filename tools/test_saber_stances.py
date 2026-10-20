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

while cpu.pc != MAIN_LOOP:
    cpu.step()

def run_frame(btn=0):
    cpu.joy1_bits = btn
    while cpu.pc != WAIT_NMI:
        cpu.step()
    cpu.trigger_nmi()
    while zp("nmi_ready") != 0:
        cpu.step()
    while cpu.pc != MAIN_LOOP:
        cpu.step()

# Boot to title, select BOSS BATTLE (menu_sel=2), pick boss 4 (Rival Red MS)
run_frame(0x20) # SELECT -> menu 1
run_frame(0)
run_frame(0x20) # SELECT -> menu 2
run_frame(0)
for _ in range(4):
    run_frame(0x01)
    run_frame(0)

# Start BOSS BATTLE
run_frame(0x10) # START
run_frame(0)

# Press SELECT once to enter Melee Duel (boss_state=5)
run_frame(0x20) # SELECT
run_frame(0)

print(f"Melee duel active: boss_state={zp('boss_state')}, boss_saber_stance={zp('boss_saber_stance')}, weapon_type={zp('weapon_type')}")
assert zp('boss_state') == 5
assert zp('boss_saber_stance') == 0 # Starts in High Guard (上段の構え)
assert zp('weapon_type') == 3

# Test pressing A in melee duel:
run_frame(0x80) # Press A
print(f"With A pressed: saber_timer={zp('saber_timer')}, weapon_type={zp('weapon_type')}")
assert zp('saber_timer') > 0, f"Expected saber_timer > 0, got {zp('saber_timer')}"

# Release A:
run_frame(0x00) # Release A

# Boss alternates between 0 and 1
stances_seen = set()
for f in range(70):
    run_frame(0)
    stances_seen.add(zp('boss_saber_stance'))

print(f"Stances seen by boss over 70 frames: {stances_seen}")
assert 0 in stances_seen and 1 in stances_seen, "Boss must alternate between High Guard (0) and Slash (1)!"

print("=== SABER HIGH GUARD & SLASH VERIFICATION 100% SUCCESSFUL! ===")
