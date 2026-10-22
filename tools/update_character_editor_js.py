import json
import re

from export_assets import CHAR_DEFS

js_path = "docs/character-editor/character-editor.js"
with open(js_path, "r", encoding="utf-8") as f:
    content = f.read()

# Generate Row constants and DEFAULT_CHARACTERS
lines = []
lines.append("  // =============================================================================")
lines.append("  // Full MOJAxMOJA WARS Character Roster (All 18 Active In-Game Assets)")
lines.append("  // =============================================================================")
lines.append("")

for c in CHAR_DEFS:
    cid = c["id"]
    frames = c["frames"]
    for f_idx, f_rows in enumerate(frames):
        var_name = f"{cid}_ROWS_{f_idx+1}" if len(frames) > 1 else f"{cid}_ROWS"
        lines.append(f"  const {var_name} = [")
        for r in f_rows:
            lines.append(f'    "{r}",')
        lines.append("  ];")
        lines.append("")

lines.append("  const DEFAULT_CHARACTERS = [")
for c in CHAR_DEFS:
    cid = c["id"]
    name = c["name"]
    category = c["category"]
    pal_idx = c["pal_idx"]
    w = c["width"]
    h = c["height"]
    frames = c["frames"]
    
    lines.append("    {")
    lines.append(f'      id: "{cid}",')
    lines.append(f'      name: "{name}",')
    lines.append(f'      category: "{category}",')
    lines.append(f'      paletteIdx: {pal_idx},')
    lines.append("      subpalettes: createDefaultSubpalettes(),")
    lines.append("      animations: {")
    
    if len(frames) == 1:
        f_name = f"{cid}_ROWS"
        lines.append(f"        idle: [parseRowsToFrame({f_name}, {w}, {h}, 12)],")
        lines.append(f"        fly: [parseRowsToFrame({f_name}, {w}, {h}, 10)],")
        lines.append(f"        attack: [parseRowsToFrame({f_name}, {w}, {h}, 8)],")
        lines.append(f"        damage: [parseRowsToFrame({f_name}, {w}, {h}, 4)],")
        lines.append(f"        destroy: [parseRowsToFrame({f_name}, {w}, {h}, 4)]")
    elif cid == "PLAYER_CORE":
        lines.append(f"        idle: [parseRowsToFrame({cid}_ROWS_1, {w}, {h}, 8), parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 8)],")
        lines.append(f"        fly: [parseRowsToFrame({cid}_ROWS_1, {w}, {h}, 6), parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 6)],")
        lines.append(f"        attack: [parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 6)],")
        lines.append(f"        damage: [parseRowsToFrame({cid}_ROWS_1, {w}, {h}, 4)],")
        lines.append(f"        destroy: [parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 4)]")
    elif cid == "PLAYER_SABER":
        lines.append(f"        idle: [parseRowsToFrame({cid}_ROWS_1, {w}, {h}, 8), parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 8), parseRowsToFrame({cid}_ROWS_3, {w}, {h}, 8)],")
        lines.append(f"        fly: [parseRowsToFrame({cid}_ROWS_1, {w}, {h}, 6), parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 6), parseRowsToFrame({cid}_ROWS_3, {w}, {h}, 6)],")
        lines.append(f"        attack: [parseRowsToFrame({cid}_ROWS_2, {w}, {h}, 8)],")
        lines.append(f"        damage: [parseRowsToFrame({cid}_ROWS_1, {w}, {h}, 4)],")
        lines.append(f"        destroy: [parseRowsToFrame({cid}_ROWS_3, {w}, {h}, 4)]")
    else:
        flist = ", ".join([f"parseRowsToFrame({cid}_ROWS_{i+1}, {w}, {h}, 8)" for i in range(len(frames))])
        lines.append(f"        idle: [{flist}],")
        lines.append(f"        fly: [{flist}],")
        lines.append(f"        attack: [{flist}],")
        lines.append(f"        damage: [{flist}],")
        lines.append(f"        destroy: [{flist}]")
    
    lines.append("      }")
    lines.append("    },")

lines.append("  ];")

new_presets_section = "\n".join(lines)

start_marker_1 = "  // 1. CORE FIGHTER"
start_marker_2 = "  // Full MOJAxMOJA WARS Character Roster"
end_marker = "// Editor State"

if start_marker_2 in content and end_marker in content:
    prefix = content.split("  // =============================================================================\n  // Full MOJAxMOJA WARS Character Roster")[0]
    suffix = "// Editor State" + content.split(end_marker)[1]
    updated = prefix + new_presets_section + "\n\n// =============================================================================\n" + suffix
    with open(js_path, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"Successfully updated {js_path} with all 18 characters!")
elif start_marker_1 in content and end_marker in content:
    prefix = content.split(start_marker_1)[0]
    suffix = "// Editor State" + content.split(end_marker)[1]
    updated = prefix + new_presets_section + "\n\n// =============================================================================\n" + suffix
    with open(js_path, "w", encoding="utf-8") as f:
        f.write(updated)
    print(f"Successfully updated {js_path} with all 18 characters!")
else:
    print(f"ERROR: markers not found in {js_path}")
