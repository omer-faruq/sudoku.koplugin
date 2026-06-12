--[[
Standalone Sudoku grid helpers shared by the puzzle-bank loaders.

A grid is a 9x9 Lua table indexed as grid[row][col] (1-based) holding integers
0-9, where 0 means an empty cell. These helpers intentionally have no dependency
on the game UI so the bank/format modules can parse and validate puzzles without
pulling in the rest of the plugin.
]]--

local Grid = {}

function Grid.copy(src)
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = src[r][c]
        end
    end
    return grid
end

-- Structural check: 9x9 table of integers in the 0-9 range.
function Grid.isValidGrid(grid)
    if type(grid) ~= "table" then
        return false
    end
    for r = 1, 9 do
        local row = grid[r]
        if type(row) ~= "table" then
            return false
        end
        for c = 1, 9 do
            local v = row[c]
            if type(v) ~= "number" or v < 0 or v > 9 or v ~= math.floor(v) then
                return false
            end
        end
    end
    return true
end

local function isValidPlacement(grid, row, col, value)
    for i = 1, 9 do
        if grid[row][i] == value or grid[i][col] == value then
            return false
        end
    end
    local box_row = math.floor((row - 1) / 3) * 3 + 1
    local box_col = math.floor((col - 1) / 3) * 3 + 1
    for r = box_row, box_row + 2 do
        for c = box_col, box_col + 2 do
            if grid[r][c] == value then
                return false
            end
        end
    end
    return true
end

-- Cheap validation used while scanning bank files: returns the whitespace-free
-- 81-character form if `s` looks like a puzzle (only digits and '.'/'0' for
-- empties), or nil otherwise. Deliberately allocates no grid table so it can be
-- run over hundreds of thousands of lines without GC pressure.
function Grid.normalizeString(s)
    if type(s) ~= "string" then
        return nil
    end
    local cleaned = s:gsub("%s", "")
    if #cleaned ~= 81 then
        return nil
    end
    if cleaned:find("[^0-9.]") then
        return nil
    end
    return cleaned
end

-- Parse an 81-character string into a grid. Accepts '0' or '.' for empty cells
-- and ignores any surrounding/internal whitespace. Returns nil on bad input.
function Grid.fromString(s)
    if type(s) ~= "string" then
        return nil
    end
    local cleaned = s:gsub("%s", "")
    if #cleaned ~= 81 then
        return nil
    end
    local grid = {}
    local idx = 1
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            local ch = cleaned:sub(idx, idx)
            local d
            if ch == "." then
                d = 0
            else
                d = tonumber(ch)
            end
            if not d or d < 0 or d > 9 then
                return nil
            end
            grid[r][c] = d
            idx = idx + 1
        end
    end
    return grid
end

-- A grid is "complete" when every cell holds 1-9 and every row, column and box
-- contains each digit exactly once.
function Grid.isComplete(grid)
    if not Grid.isValidGrid(grid) then
        return false
    end
    local function unitOk(cells)
        local seen = {}
        for _, v in ipairs(cells) do
            if v < 1 or v > 9 or seen[v] then
                return false
            end
            seen[v] = true
        end
        return true
    end
    for r = 1, 9 do
        local cells = {}
        for c = 1, 9 do cells[c] = grid[r][c] end
        if not unitOk(cells) then return false end
    end
    for c = 1, 9 do
        local cells = {}
        for r = 1, 9 do cells[r] = grid[r][c] end
        if not unitOk(cells) then return false end
    end
    for box_row = 0, 2 do
        for box_col = 0, 2 do
            local cells = {}
            for r = 1, 3 do
                for c = 1, 3 do
                    cells[#cells + 1] = grid[box_row * 3 + r][box_col * 3 + c]
                end
            end
            if not unitOk(cells) then return false end
        end
    end
    return true
end

-- Backtracking solver with the "minimum remaining values" heuristic: it always
-- branches on the empty cell that has the fewest legal candidates. Plain cell-
-- order backtracking can need hundreds of millions of steps on a minimal (e.g.
-- 17-clue) puzzle, which would hang a slow e-ink device; MRV brings the hardest
-- known puzzles down to a few hundred thousand steps. Returns a fully solved
-- copy of the puzzle, or nil when the puzzle has no solution.
function Grid.solve(puzzle)
    if not Grid.isValidGrid(puzzle) then
        return nil
    end
    local grid = Grid.copy(puzzle)

    -- Safety valve: with MRV even the hardest legitimate puzzles stay well under
    -- this many candidate tests, so hitting the cap means a degenerate input.
    -- Bailing out keeps a bad bank entry from ever freezing the device.
    local steps = 0
    local STEP_LIMIT = 5000000

    -- Find the empty cell with the fewest candidates. Returns row, col, count
    -- (count == 0 means a dead end), or nil when the grid is already full.
    local function findBestCell()
        local best_row, best_col, best_count
        for r = 1, 9 do
            for c = 1, 9 do
                if grid[r][c] == 0 then
                    local count = 0
                    for value = 1, 9 do
                        if isValidPlacement(grid, r, c, value) then
                            count = count + 1
                        end
                    end
                    if not best_count or count < best_count then
                        best_row, best_col, best_count = r, c, count
                        if count <= 1 then
                            return best_row, best_col, best_count
                        end
                    end
                end
            end
        end
        return best_row, best_col, best_count
    end

    local function search()
        local row, col, count = findBestCell()
        if not row then
            return true
        end
        if count == 0 then
            return false
        end
        for value = 1, 9 do
            steps = steps + 1
            if steps > STEP_LIMIT then
                return false
            end
            if isValidPlacement(grid, row, col, value) then
                grid[row][col] = value
                if search() then
                    return true
                end
                grid[row][col] = 0
            end
        end
        return false
    end

    if search() then
        return grid
    end
    return nil
end

-- Does `solution` solve `puzzle`? Requires a complete solution that agrees with
-- every given (non-empty) cell of the puzzle.
function Grid.isSolutionOf(puzzle, solution)
    if not Grid.isComplete(solution) then
        return false
    end
    for r = 1, 9 do
        for c = 1, 9 do
            if puzzle[r][c] ~= 0 and puzzle[r][c] ~= solution[r][c] then
                return false
            end
        end
    end
    return true
end

return Grid
