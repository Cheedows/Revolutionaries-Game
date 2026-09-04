"""Draws character-grid art large, so the shapes can be judged before shipping.

    python3 .claude/skills/pixel-art/scripts/preview.py out.png [source.gd]

Reads every nine-by-nine grid out of a GDScript file — game/data/icon_art.gd by
default — and rasterises them into one sheet with the names under them. Nine
rows of hashes do not look like anything until they are pixels; this is the
difference between an icon that reads and one that is a smudge.
"""
import re, sys
from PIL import Image, ImageDraw
source = sys.argv[2] if len(sys.argv) > 2 else "game/data/icon_art.gd"
src = open(source).read()
icons = []
for m in re.finditer(r'&"([a-z_]+)": \[\n((?:\t\t"[.#+]{9}",\n)+)\t\],', src):
    rows = re.findall(r'"([.#+]{9})"', m.group(2))
    icons.append((m.group(1), rows))
print("icons found:", len(icons))
S, PAD, COLS = 8, 14, 6
cw, ch = 9*S+PAD*2, 9*S+PAD*2+14
rows_n = (len(icons)+COLS-1)//COLS
img = Image.new("RGB", (COLS*cw, rows_n*ch), (24,26,30))
d = ImageDraw.Draw(img)
for i,(name,rows) in enumerate(icons):
    ox, oy = (i%COLS)*cw+PAD, (i//COLS)*ch+PAD
    for y,row in enumerate(rows):
        for x,c in enumerate(row):
            if c == "#": col=(230,232,236)
            elif c == "+": col=(120,122,126)
            else: continue
            d.rectangle([ox+x*S, oy+y*S, ox+x*S+S-1, oy+y*S+S-1], fill=col)
    d.text((ox, oy+9*S+2), name, fill=(150,155,165))
img.save(sys.argv[1])
print("wrote", sys.argv[1])
