local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local DataStorage = require("datastorage")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local LuaSettings = require("luasettings")
local RenderText = require("ui/rendertext")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Font = require("ui/font")
local SudokuGrid = require("sudoku_grid")
local _ = require("gettext")
local T = require("ffi/util").template

local DISPLAY_PINS_ON_GIVEN = true

local Screen = Device.screen
local DEFAULT_DIFFICULTY = "medium"
local DIFFICULTY_ORDER = { "easy", "medium", "hard" }
local DIFFICULTY_LABELS = {
    easy = _("Easy"),
    medium = _("Medium"),
    hard = _("Hard"),
}

local function emptyGrid()
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = 0
        end
    end
    return grid
end

local function copyGrid(src)
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = src[r][c]
        end
    end
    return grid
end

local function emptyNotes()
    local notes = {}
    for r = 1, 9 do
        notes[r] = {}
        for c = 1, 9 do
            notes[r][c] = {}
        end
    end
    return notes
end

local function emptyMarkerGrid()
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = false
        end
    end
    return grid
end

local function cloneNoteCell(cell)
    if not cell then
        return nil
    end
    local copy = nil
    for digit = 1, 9 do
        if cell[digit] then
            copy = copy or {}
            copy[digit] = true
        end
    end
    return copy
end

local function copyNotes(src)
    local notes = {}
    for r = 1, 9 do
        notes[r] = {}
        for c = 1, 9 do
            local dest_cell = {}
            local source_cell = src and src[r] and src[r][c]
            if type(source_cell) == "table" then
                local had_array_values = false
                for _, digit in ipairs(source_cell) do
                    local d = tonumber(digit)
                    if d and d >= 1 and d <= 9 then
                        dest_cell[d] = true
                        had_array_values = true
                    end
                end
                if not had_array_values then
                    for digit, flag in pairs(source_cell) do
                        local d = tonumber(digit)
                        if d and d >= 1 and d <= 9 and flag then
                            dest_cell[d] = true
                        end
                    end
                end
            end
            notes[r][c] = dest_cell
        end
    end
    return notes
end

local function shuffledDigits()
    local digits = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    for i = #digits, 2, -1 do
        local j = math.random(i)
        digits[i], digits[j] = digits[j], digits[i]
    end
    return digits
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

local function fillBoard(grid, cell)
    if cell > 81 then
        return true
    end
    local row = math.floor((cell - 1) / 9) + 1
    local col = (cell - 1) % 9 + 1
    local numbers = shuffledDigits()
    for _, value in ipairs(numbers) do
        if isValidPlacement(grid, row, col, value) then
            grid[row][col] = value
            if fillBoard(grid, cell + 1) then
                return true
            end
            grid[row][col] = 0
        end
    end
    return false
end

local function generateSolvedBoard()
    local grid = emptyGrid()
    fillBoard(grid, 1)
    return grid
end

local function countSolutions(grid, limit)
    local solutions = 0
    local function search(cell)
        if solutions >= limit then
            return
        end
        if cell > 81 then
            solutions = solutions + 1
            return
        end
        local row = math.floor((cell - 1) / 9) + 1
        local col = (cell - 1) % 9 + 1
        if grid[row][col] ~= 0 then
            search(cell + 1)
            return
        end
        for _, value in ipairs(shuffledDigits()) do
            if isValidPlacement(grid, row, col, value) then
                grid[row][col] = value
                search(cell + 1)
                grid[row][col] = 0
                if solutions >= limit then
                    return
                end
            end
        end
    end
    search(1)
    return solutions
end

local function createPuzzle(solved_grid, difficulty)
    local puzzle = copyGrid(solved_grid)
    local targets = { easy = 35, medium = 45, hard = 53 }
    local removals = targets[difficulty] or targets.medium
    local cells = {}
    for r = 1, 9 do
        for c = 1, 9 do
            cells[#cells + 1] = { r = r, c = c }
        end
    end
    for i = #cells, 2, -1 do
        local j = math.random(i)
        cells[i], cells[j] = cells[j], cells[i]
    end
    local removed = 0
    for _, cell in ipairs(cells) do
        if removed >= removals then
            break
        end
        local row, col = cell.r, cell.c
        if puzzle[row][col] ~= 0 then
            local backup = puzzle[row][col]
            puzzle[row][col] = 0
            local working = copyGrid(puzzle)
            if countSolutions(working, 2) == 1 then
                removed = removed + 1
            else
                puzzle[row][col] = backup
            end
        end
    end
    return puzzle
end

local SudokuBoard = {}
SudokuBoard.__index = SudokuBoard

function SudokuBoard:new()
    local board = {
        puzzle = emptyGrid(),
        solution = emptyGrid(),
        user = emptyGrid(),
        conflicts = emptyGrid(),
        notes = emptyNotes(),
        wrong_marks = emptyMarkerGrid(),
        selected = { row = 1, col = 1 },
        difficulty = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function SudokuBoard:serialize()
    return {
        puzzle = copyGrid(self.puzzle),
        solution = copyGrid(self.solution),
        user = copyGrid(self.user),
        notes = copyNotes(self.notes),
        wrong_marks = copyGrid(self.wrong_marks),
        selected = { row = self.selected.row, col = self.selected.col },
        difficulty = self.difficulty,
        reveal_solution = self.reveal_solution,
        source_label = self.source_label,
    }
end

function SudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.puzzle = copyGrid(state.puzzle)
    self.solution = copyGrid(state.solution)
    self.user = copyGrid(state.user)
    self.notes = copyNotes(state.notes)
    if state.wrong_marks then
        self.wrong_marks = copyGrid(state.wrong_marks)
    else
        self.wrong_marks = emptyMarkerGrid()
    end
    self.difficulty = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack = {}
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(9, state.selected.row or 1)),
            col = math.max(1, math.min(9, state.selected.col or 1)),
        }
    else
        self.selected = { row = 1, col = 1 }
    end
    self.reveal_solution = state.reveal_solution or false
    self.source_label = state.source_label
    self:recalcConflicts()
    return true
end

function SudokuBoard:generate(difficulty)
    self.difficulty = difficulty or self.difficulty or DEFAULT_DIFFICULTY
    local solution = generateSolvedBoard()
    local puzzle = createPuzzle(solution, self.difficulty)
    self.puzzle = puzzle
    self.solution = solution
    self.user = emptyGrid()
    self.notes = emptyNotes()
    self.wrong_marks = emptyMarkerGrid()
    self.selected = { row = 1, col = 1 }
    self.reveal_solution = false
    self.source_label = nil
    self.undo_stack = {}
    self:recalcConflicts()
end

-- Load an externally supplied puzzle (e.g. from a puzzle bank). When no valid
-- solution is supplied it is computed by solving the puzzle. Returns ok, err.
function SudokuBoard:loadPuzzle(puzzle_grid, opts)
    opts = opts or {}
    if not SudokuGrid.isValidGrid(puzzle_grid) then
        return false, _("This puzzle could not be read.")
    end
    local solution = opts.solution
    if solution and not SudokuGrid.isSolutionOf(puzzle_grid, solution) then
        solution = nil
    end
    if not solution then
        solution = SudokuGrid.solve(puzzle_grid)
    end
    if not solution then
        return false, _("This puzzle has no solution and was skipped.")
    end
    self.puzzle = copyGrid(puzzle_grid)
    self.solution = copyGrid(solution)
    self.user = emptyGrid()
    self.notes = emptyNotes()
    self.wrong_marks = emptyMarkerGrid()
    self.selected = { row = 1, col = 1 }
    self.reveal_solution = false
    self.source_label = opts.label
    if opts.difficulty then
        self.difficulty = opts.difficulty
    end
    self.undo_stack = {}
    self:recalcConflicts()
    return true
end

function SudokuBoard:pushUndo(entry)
    if entry then
        self.undo_stack[#self.undo_stack + 1] = entry
    end
end

function SudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

function SudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then
        return given
    end
    return self.user[row][col]
end

function SudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

local function ensureGridValues(grid)
    for r = 1, 9 do
        grid[r] = grid[r] or {}
        for c = 1, 9 do
            grid[r][c] = grid[r][c] or 0
        end
    end
end

function SudokuBoard:recalcConflicts()
    ensureGridValues(self.conflicts)
    for r = 1, 9 do
        for c = 1, 9 do
            self.conflicts[r][c] = false
        end
    end
    local function markConflicts(cells)
        local map = {}
        for _, cell in ipairs(cells) do
            if cell.value ~= 0 then
                map[cell.value] = map[cell.value] or {}
                table.insert(map[cell.value], cell)
            end
        end
        for _, positions in pairs(map) do
            if #positions > 1 then
                for _, pos in ipairs(positions) do
                    self.conflicts[pos.row][pos.col] = true
                end
            end
        end
    end
    for r = 1, 9 do
        local cells = {}
        for c = 1, 9 do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end
    for c = 1, 9 do
        local cells = {}
        for r = 1, 9 do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end
    for box_row = 0, 2 do
        for box_col = 0, 2 do
            local cells = {}
            for r = 1, 3 do
                for c = 1, 3 do
                    local row = box_row * 3 + r
                    local col = box_col * 3 + c
                    cells[#cells + 1] = { row = row, col = col, value = self:getWorkingValue(row, col) }
                end
            end
            markConflicts(cells)
        end
    end
end

function SudokuBoard:setSelection(row, col)
    self.selected = { row = math.max(1, math.min(9, row)), col = math.max(1, math.min(9, col)) }
end

function SudokuBoard:getSelection()
    return self.selected.row, self.selected.col
end

function SudokuBoard:isShowingSolution()
    return self.reveal_solution
end

function SudokuBoard:toggleSolution()
    self.reveal_solution = not self.reveal_solution
end

function SudokuBoard:setValue(value)
    if self.reveal_solution then
        return false, _("Hide result to keep playing.")
    end
    local row, col = self:getSelection()
    if self:isGiven(row, col) then
        return false, _("This cell is fixed.")
    end
    local prev_value = self.user[row][col]
    local prev_notes = cloneNoteCell(self.notes[row][col])
    local new_value = value or 0

    if prev_value == new_value and not prev_notes then
        if not value then
            return false, _("Cell already empty.")
        end
        return true
    end

    self.user[row][col] = new_value
    self:clearNotes(row, col)
    self:clearWrongMark(row, col)
    self:recalcConflicts()
    if prev_value ~= new_value or prev_notes then
        self:pushUndo{
            type = "value",
            row = row,
            col = col,
            prev_value = prev_value,
            prev_notes = prev_notes,
        }
    end
    return true
end

function SudokuBoard:clearSelection()
    return self:setValue(nil)
end

function SudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], self:isGiven(row, col)
    end
    if self:isGiven(row, col) then
        return self.puzzle[row][col], true
    end
    local value = self.user[row][col]
    if value == 0 then
        return nil
    end
    return value, false
end

function SudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function SudokuBoard:clearNotes(row, col)
    if self.notes[row] and self.notes[row][col] then
        self.notes[row][col] = {}
    end
end

function SudokuBoard:getCellNotes(row, col)
    local cell = self.notes[row] and self.notes[row][col]
    if not cell then
        return nil
    end
    for digit = 1, 9 do
        if cell[digit] then
            return cell
        end
    end
    return nil
end

function SudokuBoard:clearWrongMarks()
    for r = 1, 9 do
        for c = 1, 9 do
            self.wrong_marks[r][c] = false
        end
    end
end

function SudokuBoard:clearWrongMark(row, col)
    if self.wrong_marks[row] then
        self.wrong_marks[row][col] = false
    end
end

function SudokuBoard:hasWrongMark(row, col)
    return self.wrong_marks[row] and self.wrong_marks[row][col] or false
end

function SudokuBoard:updateWrongMarks()
    self:clearWrongMarks()
    local has_wrong = false
    for r = 1, 9 do
        for c = 1, 9 do
            local value = self.user[r][c]
            if value ~= 0 and value ~= self.solution[r][c] then
                self.wrong_marks[r][c] = true
                has_wrong = true
            end
        end
    end
    return has_wrong
end

function SudokuBoard:toggleNoteDigit(value)
    if self.reveal_solution then
        return false, _("Hide result to keep playing.")
    end
    local row, col = self:getSelection()
    if self:isGiven(row, col) then
        return false, _("This cell is fixed.")
    end
    if self.user[row][col] ~= 0 then
        return false, _("Clear the cell before adding notes.")
    end
    self.notes[row][col] = self.notes[row][col] or {}
    local prev_cell = cloneNoteCell(self.notes[row][col])
    local was_set = self.notes[row][col][value] and true or false
    if was_set then
        self.notes[row][col][value] = nil
    else
        self.notes[row][col][value] = true
    end
    local now_set = self.notes[row][col][value] and true or false
    if was_set == now_set then
        return true
    end
    self:pushUndo{
        type = "notes",
        row = row,
        col = col,
        prev_notes = prev_cell,
    }
    return true
end

function SudokuBoard:getRemainingCells()
    local remaining = 0
    for r = 1, 9 do
        for c = 1, 9 do
            if self:getWorkingValue(r, c) == 0 then
                remaining = remaining + 1
            end
        end
    end
    return remaining
end

function SudokuBoard:canUndo()
    return self.undo_stack[1] ~= nil
end

function SudokuBoard:undo()
    local entry = table.remove(self.undo_stack)
    if not entry then
        return false, _("Nothing to undo.")
    end
    local row, col = entry.row, entry.col
    if entry.type == "value" then
        self.user[row][col] = entry.prev_value or 0
        self.notes[row][col] = cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
        self:recalcConflicts()
        self:clearWrongMark(row, col)
    elseif entry.type == "notes" then
        self.notes[row][col] = cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
    end
    return true
end

function SudokuBoard:isSolved()
    if self.reveal_solution then
        return false
    end
    for r = 1, 9 do
        for c = 1, 9 do
            if self:getWorkingValue(r, c) ~= self.solution[r][c] or self.conflicts[r][c] then
                return false
            end
        end
    end
    return true
end

local SudokuBoardWidget = InputContainer:extend{
    board = nil,
}

function SudokuBoardWidget:init()
    self.size = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * 0.82)
    self.dimen = Geom:new{ w = self.size, h = self.size }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = self.size, h = self.size }
    self.number_face = Font:getFace("cfont", math.max(28, math.floor(self.size / 14)))
    self.note_face = Font:getFace("smallinfofont", math.max(16, math.floor(self.size / 28)))
    self.number_face_size = self.number_face.size
    self.number_cell_padding = 0
    self.note_face_size = self.note_face.size
    self.note_mini_padding = 0
    do
        local cell = self.size / 9
        local mini = cell / 3
        local padding = math.max(1, math.floor(mini / 8))
        local safety = math.max(1, math.floor(mini / 18))
        local max_w = math.max(1, math.floor(mini - 2 * padding - safety))
        local max_h = math.max(1, math.floor(mini - 2 * padding - safety))
        local size = self.note_face_size
        while size > 8 do
            local face = Font:getFace("smallinfofont", size)
            local m = RenderText:sizeUtf8Text(0, max_w, face, "8", true, false)
            local h = m.y_bottom - m.y_top
            if m.x <= max_w and h <= max_h then
                local final_size = math.max(8, size - 2)
                self.note_face = Font:getFace("smallinfofont", final_size)
                self.note_face_size = final_size
                self.note_mini_padding = padding
                break
            end
            size = size - 1
        end
    end
    do
        local cell = self.size / 9
        local padding = math.max(2, math.floor(cell / 9))
        local safety = math.max(1, math.floor(cell / 20))
        local max_w = math.max(1, math.floor(cell - 2 * padding - safety))
        local max_h = math.max(1, math.floor(cell - 2 * padding - safety))
        local size = self.number_face_size
        while size > 10 do
            local face = Font:getFace("cfont", size)
            local m = RenderText:sizeUtf8Text(0, max_w, face, "8", true, false)
            local h = m.y_bottom - m.y_top
            if m.x <= max_w and h <= max_h then
                local final_size = math.max(10, size - 4)
                self.number_face = Font:getFace("cfont", final_size)
                self.number_face_size = final_size
                self.number_cell_padding = padding
                break
            end
            size = size - 1
        end
    end
    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.paint_rect end,
            }
        }
    }
end

function SudokuBoardWidget:getCellFromPoint(x, y)
    local rect = self.paint_rect
    local local_x = x - rect.x
    local local_y = y - rect.y
    if local_x < 0 or local_y < 0 or local_x > rect.w or local_y > rect.h then
        return nil
    end
    local cell_size = rect.w / 9
    local col = math.floor(local_x / cell_size) + 1
    local row = math.floor(local_y / cell_size) + 1
    if row < 1 or row > 9 or col < 1 or col > 9 then
        return nil
    end
    return row, col
end

function SudokuBoardWidget:onTap(_, ges)
    if not (self.board and ges and ges.pos) then
        return false
    end
    local row, col = self:getCellFromPoint(ges.pos.x, ges.pos.y)
    if not row then
        return false
    end
    self.board:setSelection(row, col)
    if self.onSelectionChanged then
        self.onSelectionChanged(row, col)
    end
    self:refresh()
    return true
end

function SudokuBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

local function drawLine(bb, x, y, w, h, color)
    bb:paintRect(x, y, w, h, color)
end

local function drawDiagonalLine(bb, x, y, length, dx, dy, color, thickness)
    color = color or Blitbuffer.COLOR_BLACK
    thickness = thickness or 1
    length = math.max(0, length)
    for step = 0, length do
        local px = math.floor(x + dx * step)
        local py = math.floor(y + dy * step)
        bb:paintRect(px, py, thickness, thickness, color)
    end
end

function SudokuBoardWidget:paintTo(bb, x, y)
    if not self.board then
        return
    end
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }
    local cell = self.dimen.w / 9
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local sel_row, sel_col = self.board:getSelection()
    local band_highlight = Blitbuffer.COLOR_GRAY_D
    local cell_highlight = Blitbuffer.COLOR_GRAY
    bb:paintRect(x + (sel_col - 1) * cell, y, cell, self.dimen.h, band_highlight)
    bb:paintRect(x, y + (sel_row - 1) * cell, self.dimen.w, cell, band_highlight)
    bb:paintRect(x + (sel_col - 1) * cell, y + (sel_row - 1) * cell, cell, cell, cell_highlight)
    for i = 0, 9 do
        local thickness = (i % 3 == 0) and Size.line.thick or Size.line.thin
        drawLine(bb, x + math.floor(i * cell), y, thickness, self.dimen.h, Blitbuffer.COLOR_BLACK)
        drawLine(bb, x, y + math.floor(i * cell), self.dimen.w, thickness, Blitbuffer.COLOR_BLACK)
    end
    for row = 1, 9 do
        for col = 1, 9 do
            local value, is_given = self.board:getDisplayValue(row, col)
            if value then
                local cell_x = x + (col - 1) * cell
                local cell_y = y + (row - 1) * cell
                local color
                if self.board:isShowingSolution() and not is_given then
                    color = Blitbuffer.COLOR_GRAY_4
                elseif is_given then
                    color = Blitbuffer.COLOR_BLACK
                else
                    color = Blitbuffer.COLOR_GRAY_2
                end
                if self.board:isConflict(row, col) then
                    color = Blitbuffer.COLOR_RED
                end
                local text = tostring(value)
                local cell_padding = self.number_cell_padding or 0
                local cell_inner = math.max(1, math.floor(cell - 2 * cell_padding))
                local metrics = RenderText:sizeUtf8Text(0, cell_inner, self.number_face, text, true, false)
                local text_w = metrics.x
                local baseline = cell_y + cell_padding + math.floor((cell_inner + metrics.y_top - metrics.y_bottom) / 2)
                local text_x = cell_x + cell_padding + math.floor((cell_inner - text_w) / 2)
                RenderText:renderUtf8Text(bb, text_x, baseline, self.number_face, text, true, false, color)
                if is_given and DISPLAY_PINS_ON_GIVEN then
                    local dot = math.max(1, math.floor(cell / 18))
                    local padding = math.max(1, math.floor(cell / 20))
                    local dot_color = Blitbuffer.COLOR_GRAY_4
                    bb:paintRect(cell_x + padding, cell_y + padding, dot, dot, dot_color)
                    bb:paintRect(cell_x + cell - padding - dot, cell_y + padding, dot, dot, dot_color)
                    bb:paintRect(cell_x + padding, cell_y + cell - padding - dot, dot, dot, dot_color)
                    bb:paintRect(cell_x + cell - padding - dot, cell_y + cell - padding - dot, dot, dot, dot_color)
                elseif self.board:hasWrongMark(row, col) then
                    local padding = math.max(1, math.floor(cell / 12))
                    local diag_len = math.max(0, math.floor(cell - padding * 2))
                    local cross_thickness = math.max(2, math.floor(cell / 18))
                    drawDiagonalLine(bb, cell_x + padding, cell_y + padding, diag_len, 1, 1, Blitbuffer.COLOR_BLACK, cross_thickness)
                    drawDiagonalLine(bb, cell_x + padding, cell_y + cell - padding, diag_len, 1, -1, Blitbuffer.COLOR_BLACK, cross_thickness)
                end
            else
                local notes = self.board:getCellNotes(row, col)
                if notes then
                    local mini = cell / 3
                    local mini_padding = self.note_mini_padding or 0
                    local mini_inner = math.max(1, math.floor(mini - 2 * mini_padding))
                    for digit = 1, 9 do
                        if notes[digit] then
                            local mini_col = (digit - 1) % 3
                            local mini_row = math.floor((digit - 1) / 3)
                            local mini_x = x + (col - 1) * cell + mini_col * mini
                            local mini_y = y + (row - 1) * cell + mini_row * mini
                            local note_text = tostring(digit)
                            local note_metrics = RenderText:sizeUtf8Text(0, mini_inner, self.note_face, note_text, true, false)
                            local note_baseline = mini_y + mini_padding + math.floor((mini_inner + note_metrics.y_top - note_metrics.y_bottom) / 2)
                            local note_x = mini_x + mini_padding + math.floor((mini_inner - note_metrics.x) / 2)
                            RenderText:renderUtf8Text(bb, note_x, note_baseline, self.note_face, note_text, true, false, Blitbuffer.COLOR_GRAY_4)
                        end
                    end
                end
            end
        end
    end
end

local SudokuScreen = InputContainer:extend{}

function SudokuScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.covers_fullscreen = true
    self.vertical_align = "center"
    self.note_mode = false
    self.undo_button = nil
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self.status_text = TextWidget:new{
        text = _("Tap a cell, then pick a number."),
        face = Font:getFace("smallinfofont"),
    }
    self.board_widget = SudokuBoardWidget:new{
        board = self.board,
        onSelectionChanged = function()
            self:updateStatus()
        end,
    }
    self:buildLayout()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function SudokuScreen:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local content_size = self.layout:getSize()
    local offset_x = x + math.floor((self.dimen.w - content_size.w) / 2)
    local offset_y = y
    if self.vertical_align == "center" then
        offset_y = offset_y + math.floor((self.dimen.h - content_size.h) / 2)
    end
    self.layout:paintTo(bb, offset_x, offset_y)
end

function SudokuScreen:buildLayout()
    local board_frame = FrameContainer:new{
        padding = Size.padding.large,
        margin = Size.margin.default,
        self.board_widget,
    }
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width = math.floor(Screen:getWidth() * 0.9),
        buttons = {
            {
                {
                    text = _("New game"),
                    callback = function()
                        self:onNewGamePressed()
                    end,
                },
                {
                    id = "show_result",
                    text = _("Show result"),
                    callback = function()
                        self:toggleSolution()
                    end,
                },
                {
                    text = _("Close"),
                    callback = function()
                        self:onClose()
                        UIManager:close(self)
                        UIManager:setDirty(nil, "full")
                    end,
                },
            },
        },
    }
    self.show_result_button = top_buttons:getButtonById("show_result")

    local keypad_rows = {}
    local value = 1
    for _ = 1, 3 do
        local row = {}
        for _ = 1, 3 do
            local digit = value
            row[#row + 1] = {
                text = tostring(digit),
                callback = function()
                    self:onDigit(digit)
                end,
            }
            value = value + 1
        end
        keypad_rows[#keypad_rows + 1] = row
    end
    keypad_rows[#keypad_rows + 1] = {
        {
            id = "note_button",
            text = self:getNoteButtonText(),
            callback = function()
                self:toggleNoteMode()
            end,
        },
        {
            text = _("Erase"),
            callback = function()
                self:onErase()
            end,
        },
        {
            text = _("Check"),
            callback = function()
                self:checkProgress()
            end,
        },
        {
            id = "undo_button",
            text = _("Undo"),
            callback = function()
                self:onUndo()
            end,
        },
    }
    local keypad = ButtonTable:new{
        width = math.floor(Screen:getWidth() * 0.75),
        shrink_unneeded_width = true,
        buttons = keypad_rows,
    }
    self.note_button = keypad:getButtonById("note_button")
    self.undo_button = keypad:getButtonById("undo_button")
    self.layout = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Size.span.vertical_large },
        top_buttons,
        VerticalSpan:new{ width = Size.span.vertical_large },
        board_frame,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        keypad,
        VerticalSpan:new{ width = Size.span.vertical_large },
    }
    self[1] = self.layout
    self:ensureShowButtonState()
    self:updateNoteButton()
    self:updateUndoButton()
    self:updateStatus()
end

function SudokuScreen:getNoteButtonText()
    return self.note_mode and _("Note: On") or _("Note: Off")
end

function SudokuScreen:updateNoteButton()
    if not self.note_button then
        return
    end
    local width = self.note_button.width
    self.note_button:setText(self:getNoteButtonText(), width)
end

function SudokuScreen:updateUndoButton()
    if not self.undo_button then
        return
    end
    self.undo_button:enableDisable(self.board:canUndo())
end

function SudokuScreen:toggleNoteMode()
    self.note_mode = not self.note_mode
    self:updateNoteButton()
    self:updateStatus(self.note_mode and _("Note mode enabled.") or _("Note mode disabled."))
end

-- "Create" sub-step: pick a difficulty, then generate a fresh puzzle at it.
function SudokuScreen:openCreateMenu()
    local dialog
    local diff_buttons = {}
    for _idx, level in ipairs(DIFFICULTY_ORDER) do
        local chosen = level
        diff_buttons[#diff_buttons + 1] = {
            text = DIFFICULTY_LABELS[chosen] or chosen,
            callback = function()
                UIManager:close(dialog)
                self:onNewGame(chosen)
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = _("Create: choose difficulty"),
        title_align = "center",
        buttons = {
            diff_buttons,
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function SudokuScreen:updateStatus(message)
    local status
    if message then
        status = message
    else
        local remaining = self.board:getRemainingCells()
        local row, col = self.board:getSelection()
        status = T(_("Selected: %1,%2  ·  Empty cells: %3"), row, col, remaining)
        if self.board:isShowingSolution() then
            status = status .. "\n" .. _("Result is being shown; editing is disabled.")
        elseif self.board:isSolved() then
            status = _("Congratulations! Puzzle solved.")
        elseif self.note_mode then
            status = status .. "\n" .. _("Note mode is ON.")
        end
    end
    self.status_text:setText(status)
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function SudokuScreen:onDigit(value)
    if self.note_mode then
        local ok, err = self.board:toggleNoteDigit(value)
        if not ok then
            self:updateStatus(err)
            return
        end
        self.board_widget:refresh()
        self:updateStatus()
        self.plugin:saveState()
        self:updateUndoButton()
        return
    end
    local ok, err = self.board:setValue(value)
    if not ok then
        self:updateStatus(err)
        return
    end
    self.board_widget:refresh()
    self:updateStatus()
    self.plugin:saveState()
    self:updateUndoButton()
    if self.board:isSolved() then
        UIManager:show(InfoMessage:new{ text = _("Puzzle complete!"), timeout = 4 })
    end
end

function SudokuScreen:onErase()
    local row, col = self.board:getSelection()
    self.board:clearNotes(row, col)
    local ok, err = self.board:clearSelection()
    if not ok then
        self:updateStatus(err)
        return
    end
    self.board_widget:refresh()
    self:updateStatus()
    self.plugin:saveState()
    self:updateUndoButton()
end

function SudokuScreen:onNewGame(difficulty)
    self.board:generate(difficulty or self.board.difficulty)
    self.plugin:saveState()
    self.board_widget:refresh()
    self:ensureShowButtonState()
    self:updateUndoButton()
    self.note_mode = false
    self:updateNoteButton()
    self:updateStatus(T(_("Started a %1 game."),
        DIFFICULTY_LABELS[self.board.difficulty] or self.board.difficulty))
end

-- "New game" first asks whether to generate a fresh puzzle or load one from a
-- bundled/dropped-in puzzle bank.
function SudokuScreen:onNewGamePressed()
    local dialog
    dialog = ButtonDialog:new{
        title = _("New game"),
        title_align = "center",
        buttons = {
            {
                {
                    text = _("Create"),
                    callback = function()
                        UIManager:close(dialog)
                        self:openCreateMenu()
                    end,
                },
            },
            {
                {
                    text = _("Load from bank"),
                    callback = function()
                        UIManager:close(dialog)
                        self:openLoadMenu()
                    end,
                },
            },
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function SudokuScreen:closeLoadMenus()
    if self._load_menus then
        for i = #self._load_menus, 1, -1 do
            UIManager:close(self._load_menus[i])
        end
        self._load_menus = nil
    end
end

function SudokuScreen:openLoadMenu()
    local Bank = require("sudoku_bank")
    Bank.ensurePuzzlesDir()
    local sources = Bank.listSources()
    if #sources == 0 then
        UIManager:show(InfoMessage:new{
            text = T(_("No puzzle banks found.\n\nDrop puzzle files into:\n%1"), Bank.PUZZLES_DIR),
        })
        return
    end
    local items = {}
    for _idx, source in ipairs(sources) do
        local entry_source = source
        items[#items + 1] = {
            text = T(_("%1  (%2 files)"), source.name, source.file_count),
            callback = function()
                self:openSourceFiles(entry_source)
            end,
        }
    end
    local menu = Menu:new{
        title = _("Choose a puzzle bank"),
        item_table = items,
        width = math.floor(Screen:getWidth() * 0.8),
        height = math.floor(Screen:getHeight() * 0.9),
        show_parent = self,
    }
    self._load_menus = { menu }
    UIManager:show(menu)
end

function SudokuScreen:openSourceFiles(source)
    local Bank = require("sudoku_bank")
    local files = Bank.listFiles(source)
    local items = {
        {
            text = _("Random puzzle (any file)"),
            callback = function()
                self:loadRandomFrom(source, nil)
            end,
        },
    }
    for _, file in ipairs(files) do
        local file_path = file.path
        items[#items + 1] = {
            text = file.name,
            callback = function()
                self:loadRandomFrom(source, file_path)
            end,
        }
    end
    local menu = Menu:new{
        title = source.name,
        item_table = items,
        width = math.floor(Screen:getWidth() * 0.8),
        height = math.floor(Screen:getHeight() * 0.9),
        show_parent = self,
    }
    self._load_menus = self._load_menus or {}
    self._load_menus[#self._load_menus + 1] = menu
    UIManager:show(menu)
end

function SudokuScreen:loadRandomFrom(source, file_path)
    local Bank = require("sudoku_bank")
    local entry, err
    if file_path then
        entry, err = Bank.loadRandomFromFile(source, file_path)
    else
        entry, err = Bank.loadRandomFromSource(source)
    end
    if not entry then
        UIManager:show(InfoMessage:new{ text = err or _("Could not load a puzzle.") })
        return
    end
    local ok, load_err = self.board:loadPuzzle(entry.grid, {
        solution = entry.solution,
        label = entry.label,
    })
    if not ok then
        UIManager:show(InfoMessage:new{ text = load_err or _("This puzzle could not be loaded.") })
        return
    end
    self:closeLoadMenus()
    self.plugin:saveState()
    self.board_widget:refresh()
    self:ensureShowButtonState()
    self:updateUndoButton()
    self.note_mode = false
    self:updateNoteButton()
    if entry.label then
        self:updateStatus(T(_("Loaded: %1"), entry.label))
    else
        self:updateStatus(_("Puzzle loaded."))
    end
end

function SudokuScreen:toggleSolution()
    self.board:toggleSolution()
    self.plugin:saveState()
    self.board_widget:refresh()
    self:ensureShowButtonState()
    self:updateStatus(self.board:isShowingSolution() and _("Showing the solution.") or nil)
end

function SudokuScreen:ensureShowButtonState()
    if not self.show_result_button then
        return
    end
    local text = self.board:isShowingSolution() and _("Hide result") or _("Show result")
    local width = self.show_result_button.width
    self.show_result_button:setText(text, width)
end

function SudokuScreen:checkProgress()
    self.board:updateWrongMarks()
    self.board_widget:refresh()
    self.plugin:saveState()
    if self.board:isSolved() then
        self:updateStatus(_("Everything looks good!"))
    elseif self.board:getRemainingCells() == 0 then
        self:updateStatus(_("There are mistakes highlighted in red."))
    else
        self:updateStatus(_("Keep going!"))
    end
end

function SudokuScreen:onClose()
    self.plugin:saveState()
    self.plugin:onScreenClosed()
end

function SudokuScreen:onUndo()
    local ok, err = self.board:undo()
    if not ok then
        self:updateStatus(err)
        return
    end
    self.board_widget:refresh()
    self:updateStatus(_("Last move undone."))
    self.plugin:saveState()
    self:updateUndoButton()
end

local Sudoku = WidgetContainer:extend{
    name = "sudoku",
    is_doc_only = false,
}

function Sudoku:ensureSettings()
    if not self.settings_file then
        self.settings_file = DataStorage:getSettingsDir() .. "/sudoku.lua"
    end
    if not self.settings then
        self.settings = LuaSettings:open(self.settings_file)
    end
end

function Sudoku:init()
    self:ensureSettings()
    self.ui.menu:registerToMainMenu(self)
end

function Sudoku:addToMainMenu(menu_items)
    menu_items.sudoku = {
        text = _("Sudoku"),
        sorting_hint = "tools",
        callback = function()
            self:showGame()
        end,
    }
end

function Sudoku:getBoard()
    if not self.board then
        self:ensureSettings()
        self.board = SudokuBoard:new()
        local state = self.settings:readSetting("state")
        if not self.board:load(state) then
            self.board:generate(DEFAULT_DIFFICULTY)
        end
    end
    return self.board
end

function Sudoku:saveState()
    if not self.board then
        return
    end
    self:ensureSettings()
    self.settings:saveSetting("state", self.board:serialize())
    self.settings:flush()
end

function Sudoku:showGame()
    if self.screen then
        return
    end
    self.screen = SudokuScreen:new{
        board = self:getBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Sudoku:onScreenClosed()
    self.screen = nil
end

return Sudoku

