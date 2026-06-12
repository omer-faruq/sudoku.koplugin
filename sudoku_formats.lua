--[[
Puzzle-bank format adapters.

Each format exposes a `match(line)` function that performs a *cheap* check on a
single text line and, when it looks like a puzzle record, returns a "raw" table
of strings without building any grid:

    {
        puzzle = <81-char string>,   -- digits with 0/'.' for empties (required)
        solution = <81-char string>, -- optional, when the bank ships solutions
        label = <string>,            -- optional extra detail (e.g. "rating 5.0")
        id = <string>,               -- optional puzzle id from the source
    }

Returning strings (not grids) matters: a bank file can hold hundreds of
thousands of lines, and sudoku_bank.lua only ever turns the single *chosen*
record into a real grid. Lines that are not puzzles (header, comment, blank)
return nil.

Adding support for a new bank layout is just a matter of registering another
entry here and pointing a source folder at it in sudoku_sources.lua.
]]--

local Grid = require("sudoku_grid")
local _ = require("gettext")
local T = require("ffi/util").template

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local Formats = {}

-- grantm/sudoku-exchange-puzzle-bank: "<id> <81-char-puzzle> <rating>" per line,
-- where 0 marks an empty cell and the rating looks like "5.0".
-- Every record has the same byte length (13 + 1 + 81 + 1 + 3), so the bank can
-- seek straight to a random line instead of probing a random byte offset.
Formats["sudoku-exchange"] = {
    fixed_width = true,
    match = function(line)
        line = trim(line or "")
        if line == "" or line:sub(1, 1) == "#" then
            return nil
        end
        local f1, f2, rest = line:match("^(%S+)%s+(%S+)%s*(.*)$")
        if not f1 then
            return nil
        end
        local puzzle = f2 and Grid.normalizeString(f2)
        if puzzle then
            -- Normal "<id> <puzzle> <rating>" record.
            local rating = rest and rest:match("^(%S+)")
            local label
            if rating and rating:match("^%d") then
                label = T(_("rating %1"), rating)
            end
            return { puzzle = puzzle, label = label, id = f1 }
        end
        -- Tolerate an id-less "<puzzle> <rating>" line as well.
        puzzle = Grid.normalizeString(f1)
        if puzzle then
            return { puzzle = puzzle }
        end
        return nil
    end,
}

-- Plain banks with one puzzle per line (e.g. Gordon Royle's 17-clue collection
-- or the many "*.txt" lists on GitHub). Empty cells may be 0 or '.'; lines
-- starting with '#', ';' or '//' are treated as comments.
Formats["line81"] = {
    match = function(line)
        line = trim(line or "")
        if line == "" then
            return nil
        end
        local first = line:sub(1, 1)
        if first == "#" or first == ";" or line:sub(1, 2) == "//" then
            return nil
        end
        local token = line:match("^%S+") or line
        local puzzle = Grid.normalizeString(token)
        if not puzzle then
            return nil
        end
        return { puzzle = puzzle }
    end,
}

-- Kaggle-style CSV: "puzzle,solution" per line (the solution column is optional;
-- when present and valid it is used directly instead of re-solving). The header
-- row is skipped automatically because its first field is not an 81-char puzzle.
Formats["csv"] = {
    match = function(line)
        line = trim(line or "")
        if line == "" or line:sub(1, 1) == "#" then
            return nil
        end
        local puzzle_token, solution_token = line:match("^([^,]*),?(.*)$")
        if not puzzle_token then
            return nil
        end
        local puzzle = Grid.normalizeString(trim(puzzle_token))
        if not puzzle then
            return nil
        end
        local solution
        solution_token = trim(solution_token or "")
        if solution_token ~= "" then
            solution = Grid.normalizeString(solution_token)
        end
        return { puzzle = puzzle, solution = solution }
    end,
}

return Formats
