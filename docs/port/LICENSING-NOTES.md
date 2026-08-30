# Licensing notes — what must be replaced before any commercial release

Status: research notes, not legal advice. Verify with a lawyer before money changes hands.

## Baseline

Liberal Crime Squad is **GPL-2.0-or-later** (`/License` = GPL v2 text; every source file
carries the "version 2 ... or (at your option) any later version" header, © 2002–2004 Tarn Adams).

Consequences for a derived work (a Godot port counts as derived if it reuses LCS code,
text, or data files):

- Selling it is allowed. Charging for copies, builds, support or hosting is explicitly permitted.
- It stays GPL. Volume of change does not matter; there is no "enough rewriting" threshold.
- Binaries must ship with an offer of complete corresponding source, and every recipient
  may redistribute it, including for free.
- Only a clean-room reimplementation (no LCS code/text/data, written by someone who has not
  read the source) escapes this. Mechanics and ideas are not copyrightable; expression is.

Practical read: a Godot port that keeps LCS's game text, XML data, or ported logic is GPL
and can be sold, but cannot be closed-source and cannot stop a free fork.

## Assets that are NOT GPL and block commercial use

All five are `.ogg` music recordings (performances). The **compositions** are public domain;
it is the specific recording that is restricted. The matching `.mid` files of the same pieces
are public domain and are fine to keep.

| File | Piece / performer | License | Why it blocks |
|---|---|---|---|
| `art/ogg/sleepers.ogg` | Bach, Toccata & Fugue BWV 565 — James Kibbie | CC BY-NC-ND 3.0 | NonCommercial + NoDerivs |
| `art/ogg/trial.ogg` | Liszt, Hungarian Rhapsody #2 — Simone Renzi | CC BY-NC 3.0 | NonCommercial |
| `art/ogg/newspaper.ogg` | Mozart, Eine Kleine Nachtmusik — Isabella Stewart Gardner Museum / A Far Cry | CC BY-NC-ND 4.0 | NonCommercial + NoDerivs |
| `art/ogg/newscast.ogg` | La Marseillaise — Birds of fire | CC BY-NC-SA 2.0 FR | NonCommercial |
| `art/ogg/victory.ogg` | Star-Spangled Banner — Zoë Keating | CC BY-NC-SA 3.0 | NonCommercial |

Fix: re-source or re-record these five pieces (all public-domain compositions, so any
commercially-licensed or self-made recording works), or drop the tracks.

## Third-party code that blocks commercial use

| Path | License | Why it blocks | Fix |
|---|---|---|---|
| `src/cmarkup/Markup.cpp`, `Markup.h` | CMarkup, © First Objective Software | "Use in commercial applications requires written permission." | Dropped by the port — Godot parses XML/JSON natively. No C++ XML parser is carried over. |

## Third-party code that is fine (and is dropped by the port anyway)

- `src/pdcurses/`, `src/cursesgraphics.*` — PDCurses, public domain. Replaced by Godot UI.
- `src/sdl/`, bundled `SDL2*.dll` — zlib license. Replaced by Godot.
- `libogg` / `libvorbis` / `libvorbisfile` DLLs — BSD-style. Replaced by Godot audio.
- `src/vector.h` — BSD-style.

## Assets that are fine but require attribution (CC BY — keep the credits file)

`titlemode.ogg`, `activate.ogg`, `finances.ogg`, `cartheft.ogg`, `sitemode.ogg`,
`defense.ogg`, `defeat.ogg` (CC BY 3.0); `footchase.ogg` (CC BY 4.0);
`stopevil.ogg` (EFF Open Audio License 1.0).

Everything else in `art/` — all 36 `.mid` files, the remaining `.ogg` recordings, the
`.cmv` / `.cpc` ASCII art, the `.xml` data and `mapCSV_*` maps — is public domain or GPL.
Per `art/licenses.txt` line 506, anything not otherwise listed is GPL-2.0-or-later.

## Carry-forward rule for the port

Whatever the port ships must carry its own `licenses.txt` in the same spirit: CC BY tracks
need attribution, and the five NC tracks must not be in the tree at all if a commercial
release is ever intended. Decide this **before** the audio bus is wired up, not after.
