# KOReader Sudoku Plugin

This plugin brings a straightforward Sudoku experience to KOReader so you can solve puzzles while reading.

## Features
- Multiple difficulty levels
- Controls optimized for touch
- Automatic progress saving
- Generate a fresh puzzle **or** load one from a puzzle bank

## New game: Create or Load
Pressing **New game** opens a small popup with two choices:

- **Create** – then pick a difficulty (Easy / Medium / Hard) and a fresh puzzle
  is generated. (The difficulty picker now lives here instead of on the board.)
- **Load from bank** – pick a source, then a file (or "Random puzzle"), and a
  random puzzle from it is loaded. Missing solutions are computed automatically.

Large bank files (the grantm banks can be several MB) are sampled by seeking to
a random position in the file, so loading stays fast no matter how big the file
is.

### Puzzle banks
Puzzle files live under `puzzles/`, one sub-folder per source/format. A few
sample puzzles ship in each folder so the feature works out of the box. Drop in
more files (no restart needed):

| Folder | Format | Example source |
| --- | --- | --- |
| `sudoku-exchange-puzzle-bank/` | `<id> <81-digit puzzle> <rating>` | [grantm/sudoku-exchange-puzzle-bank](https://github.com/grantm/sudoku-exchange-puzzle-bank) |
| `line81/` | one 81-char puzzle per line (`0`/`.` = empty) | 17-clue lists, most `.txt` puzzle dumps |
| `kaggle-csv/` | `puzzle,solution` CSV (solution optional) | Kaggle "1 million Sudoku games" |

The loading code is modular: `sudoku_formats.lua` holds the per-format parsers,
`sudoku_sources.lua` maps folders to formats, and `sudoku_bank.lua` scans the
folders and samples a random puzzle. Adding a new source means adding a parser
and a one-line mapping — see `puzzles/README.md` for details.

## Installation
1. Copy the `sudoku.koplugin` folder into KOReader's `plugins` directory.
2. Restart the KOReader.

## Credits
This project was created with assistance from Windsurf (AI).
