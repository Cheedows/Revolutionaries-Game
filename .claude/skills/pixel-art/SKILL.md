---
name: pixel-art
description: >
  The character-grid art pipeline in Revolutionaries: how to turn ASCII grids
  and the original's own art/*.cpc files into pixel art the game can draw. Use
  this skill BEFORE adding or changing any icon, button picture, masthead,
  headline, or other in-game graphic; before writing anything that rasterises,
  scales or tints art; and whenever a request sounds like "add an icon for X",
  "make a picture of Y", "the buttons need graphics", "draw this in the game",
  "convert this ASCII art", "use the original's art", or "why does this icon
  look like a smudge". Also use it when reviewing pixel art somebody else
  added, or when art comes out blurred, inverted, the wrong size, or drags a
  page off the side of a phone.
---

# Pixel art in Revolutionaries

This game's art is characters on a grid, because the game it is a port of drew
everything into an eighty-by-twenty-five terminal. That is not a limitation to
work around. It is the look, and it is why a new picture here is written rather
than painted.

Two grids go in and an `Image` comes out of both. Everything else is placement.

## The two formats

**Written grids** — art authored in this repository, as lines of text in
`game/data/icon_art.gd`. One character is one pixel:

| character | means |
|---|---|
| `#` | ink |
| `+` | half ink, for a softened edge |
| `.` | nothing |

```gdscript
&"house": [
    "....#....",
    "...###...",
    "..#####..",
    ".#######.",
    "#########",
    "#.......#",
    "#..###..#",
    "#..#.#..#",
    "#..###..#",
],
```

Nine by nine, always square, always the same size, so a row of them lines up
without anybody measuring anything. `PixelArt.from_rows()` rasterises it and
`Icons.of()` hands it out as a texture, enlarged three times.

**Cell grids** — the original's own art, in `art/*.cpc`, lifted by
`tools/extract_art.py` into `game/data/char_art.gd`. Four bytes to a cell: a
code page 437 character, a foreground colour, a background colour, and a bold
flag. `PixelArt.from_cells()` turns each cell into a four-by-eight block of
pixels. The three files hold the newspaper mastheads, the block capitals a
headline is set in, and the pictures that run beside a major event.

## Adding an icon

1. Write the grid in `game/data/icon_art.gd`, with a comment saying what the
   picture is *of* — "a roof over a door", "a pair of scales".
2. **Look at it**: `python3 .claude/skills/pixel-art/scripts/preview.py out.png`
   draws every grid at eight times with its name underneath. Read the sheet.
   An icon that needs its label to be recognisable is not finished.
3. Hang it on a button with `Icons.on(button, &"name")`, which sets the texture
   and the nearest-neighbour filter together.
4. Run `tools/check_layout.sh`, because an icon changes how wide a button wants
   to be and a row of buttons is what runs off the side of a phone.

## The rules that came from getting it wrong

**Look at a frame before believing anything.** Every mistake below passed the
tests and was found by rendering a picture and looking at it.

**Three times, not two.** A nine-pixel grid at two is eighteen pixels beside a
nineteen-pixel line of text, and every shape reads as a smudge.

**Nearest neighbour, always.** Godot's default filter is linear, which smears
pixel art into mud. `Icons.on()` and `PixelArtRect` both set it; anything that
hangs a texture some other way has to set it too.

**Enlarge by whole numbers.** `PixelArt.enlarged()` refuses to do anything
else. A 1.5× scale puts some pixels at two and some at one, and the picture
develops a limp.

**Ask for a height, never a width.** A masthead is eighty cells across. A
control that insists on its natural width drags the whole page off the side of
a phone — it does not wrap, it just goes. `PixelArtRect` asks for a height and
takes whatever width it is given.

**In the original's art the letters are the background.** The mastheads and the
block capitals are drawn as *space characters on a coloured ground*, not as
glyphs. Two consequences: a tint has to go by how bright a cell was, not by
"is it black", or the letterforms invert; and a check for "does this letter
have any ink" has to look at the colours, not the characters.

**Draw the original's art in the original's colours.** The masthead is black
blocks on white because it is a newspaper. Tinting it to the interface palette
makes a grey bar where the paper's name should be. Tint art that is standing in
for an interface element; leave art that is standing in for itself alone.

**Every character in the original's art is a rectangle.** Full block, half
block on one of four sides, three dithers, two rules. That is the whole
vocabulary, which is why `PixelArt` can draw it without a code page 437 font
and why the shapes come across exactly rather than approximately.

## Where things live

| file | what it is |
|---|---|
| `game/ui/theme/pixel_art.gd` | both formats in, `Image` out; scaling, joining, tinting |
| `game/ui/theme/icons.gd` | icons as textures, cached, hung on buttons |
| `game/data/icon_art.gd` | the icon grids |
| `game/data/char_art.gd` | the original's art (generated) |
| `game/ui/widgets/pixel_art_rect.gd` | an image on screen, at a height |
| `game/ui/adapters/block_capitals.gd` | a line set in the original's headline font |
| `tools/extract_art.py` | `art/*.cpc` → `char_art.gd` |
| `tools/shots/icons.gd` | every icon rendered through the real engine |
| `scripts/preview.py` | every grid at eight times, as one sheet |

## What not to do

- Do not add an icon that replaces a label. Icons here are a second way of
  saying the same thing; a row of eight unlabelled glyphs is a puzzle, and this
  game asks enough of the player already.
- Do not paint a PNG and commit it. A picture that can be read in the source is
  a picture the next person can change.
- Do not invent a new character for a grid without adding it to `PixelArt` and
  saying what it means here.
- Do not scale art to fit by stretching one axis. Keep the aspect; the cells
  are two-to-one for a reason, and at square cells every masthead comes out
  twice as tall as it should be.
