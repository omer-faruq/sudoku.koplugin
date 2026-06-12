# Sudoku puzzle banks

The **New game → Load from bank** option picks a random puzzle from the files in
this folder. Each sub-folder is a *source* whose files share one text format.
Drop additional puzzle files into the matching folder and they show up
automatically (no restart needed).

## Folders / formats

| Folder | Format | Each line looks like |
| --- | --- | --- |
| `sudoku-exchange-puzzle-bank/` | `sudoku-exchange` | `<id> <81-digit puzzle> <rating>` |
| `line81/` | `line81` | one 81-character puzzle (`0` or `.` = empty) |
| `kaggle-csv/` | `csv` | `puzzle,solution` (solution column optional) |

In every format an empty cell is `0` or `.`, and the 81 cells are listed in row
order. When a solution is not provided it is computed automatically on load.

## Where to get more puzzles

- **Sudoku Exchange Puzzle Bank** — https://github.com/grantm/sudoku-exchange-puzzle-bank
  Download the `puzzles_*.txt` files into `sudoku-exchange-puzzle-bank/`.
- **17-clue minimal puzzles (Gordon Royle)** and most plain `.txt` puzzle lists
  found online go into `line81/`.
- **Kaggle "1 million Sudoku games"** and similar `puzzle,solution` CSVs go into
  `kaggle-csv/`.

## Adding a brand-new source

1. Add a parser to `sudoku_formats.lua`.
2. Register a folder → format mapping in `sudoku_sources.lua`.

That is all the game needs to recognise and load the new bank.
