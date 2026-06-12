--[[
Registry of known puzzle "sources".

Each source maps a sub-folder under the plugin's `puzzles/` directory to one of
the format adapters in sudoku_formats.lua. To support a new bank you can either
add an entry here (recommended, so it gets a friendly name) or just drop files
into one of the existing folders that matches the file layout.

Fields:
    id     - stable identifier
    name   - human readable label shown in the load menu
    dir    - folder name under puzzles/ that holds this source's files
    format - key into sudoku_formats.lua
]]--

local _ = require("gettext")

return {
    {
        id = "sudoku-exchange-puzzle-bank",
        name = _("Sudoku Exchange Puzzle Bank"),
        dir = "sudoku-exchange-puzzle-bank",
        format = "sudoku-exchange",
    },
    {
        id = "line81",
        name = _("Plain puzzles (one per line)"),
        dir = "line81",
        format = "line81",
    },
    {
        id = "kaggle-csv",
        name = _("CSV (puzzle, solution)"),
        dir = "kaggle-csv",
        format = "csv",
    },
}
