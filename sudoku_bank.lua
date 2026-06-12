--[[
Puzzle bank: discovers puzzle sources shipped in (or dropped into) the plugin's
`puzzles/` folder and loads a random puzzle from them.

Layout:
    sudoku.koplugin/
        puzzles/
            sudoku-exchange-puzzle-bank/   <- drop grantm bank files here
            line81/                        <- one-puzzle-per-line .txt files
            kaggle-csv/                    <- puzzle[,solution] CSV files

Picking a random puzzle uses single-pass reservoir sampling, so even a multi-
megabyte bank file is read line by line without loading it all into memory.
]]--

local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")

local Formats = require("sudoku_formats")
local Grid = require("sudoku_grid")
local Sources = require("sudoku_sources")

-- Files bigger than this are sampled by seeking to a random byte offset instead
-- of scanning the whole file (the grantm banks are several MB / hundreds of
-- thousands of lines). Smaller files are scanned exactly, which is both fast and
-- perfectly uniform.
local SEEK_THRESHOLD = 262144 -- 256 KiB
local SEEK_ATTEMPTS = 40

local Bank = {}

local function getPluginPath()
    local info = debug.getinfo(1, "S").source
    if info:sub(1, 1) == "@" then
        local src = info:sub(2):gsub("\\", "/")
        local dir = src:match("^(.*)/[^/]+$")
        if dir then
            return dir
        end
    end
    return DataStorage:getDataDir() .. "/plugins/sudoku.koplugin"
end

Bank.PLUGIN_PATH = getPluginPath()
Bank.PUZZLES_DIR = ffiUtil.joinPath(Bank.PLUGIN_PATH, "puzzles")

local function attrMode(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode
end

local function ensureDir(path)
    if not lfs.attributes(path) then
        lfs.mkdir(path)
    end
end

-- Create the base puzzles/ directory and a folder per known source so users have
-- an obvious place to drop their own bank files.
function Bank.ensurePuzzlesDir()
    ensureDir(Bank.PUZZLES_DIR)
    for _, source in ipairs(Sources) do
        ensureDir(ffiUtil.joinPath(Bank.PUZZLES_DIR, source.dir))
    end
end

local function isListableFile(name)
    if name:sub(1, 1) == "." then
        return false
    end
    local lower = name:lower()
    if lower == "readme" or lower:match("^readme%.") then
        return false
    end
    if lower == "license" or lower:match("^license%.") then
        return false
    end
    return true
end

-- List the candidate puzzle files inside a source folder, sorted by name.
function Bank.listFiles(source)
    local dir = ffiUtil.joinPath(Bank.PUZZLES_DIR, source.dir)
    local files = {}
    if attrMode(dir) ~= "directory" then
        return files
    end
    for name in lfs.dir(dir) do
        if name ~= "." and name ~= ".." and isListableFile(name) then
            local full = ffiUtil.joinPath(dir, name)
            if attrMode(full) == "file" then
                files[#files + 1] = { name = name, path = full }
            end
        end
    end
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
    return files
end

-- Sources that actually have at least one file available to load from.
function Bank.listSources()
    local out = {}
    for _, source in ipairs(Sources) do
        local files = Bank.listFiles(source)
        if #files > 0 then
            out[#out + 1] = {
                id = source.id,
                name = source.name,
                dir = source.dir,
                format = source.format,
                file_count = #files,
            }
        end
    end
    return out
end

local function composeLabel(source, extra)
    local label = source.name
    if extra and extra ~= "" then
        label = label .. " · " .. extra
    end
    return label
end

-- Turn a matched "raw" record (strings) into a playable entry (grids). Only ever
-- called for the single chosen puzzle, so the per-line scan stays allocation-free.
local function buildEntry(raw)
    local grid = Grid.fromString(raw.puzzle)
    if not grid then
        return nil
    end
    local solution
    if raw.solution then
        local sgrid = Grid.fromString(raw.solution)
        if sgrid and Grid.isComplete(sgrid) then
            solution = sgrid
        end
    end
    return { grid = grid, solution = solution, id = raw.id, label_extra = raw.label }
end

-- Exact, uniform sampling over a full pass of the file (used for small files and
-- as a fallback). Returns the chosen raw record or nil.
local function sampleByScan(file, match)
    file:seek("set", 0)
    local chosen, count = nil, 0
    for line in file:lines() do
        local ok, raw = pcall(match, line)
        if ok and raw then
            count = count + 1
            if math.random(count) == 1 then
                chosen = raw
            end
        end
    end
    return chosen
end

-- Fastest path for formats whose every line is the same byte length (e.g. the
-- sudoku-exchange bank): measure one line's stride, then seek straight to a
-- random line index and read exactly that line. Perfectly uniform, one read per
-- pick, no scanning. Falls back to nil (and thus to sampleBySeek) if a line ever
-- fails to parse, which would mean the file is not actually fixed-width.
local function sampleByFixedWidth(file, size, match)
    file:seek("set", 0)
    local first = file:read("*l")
    if not first then
        return nil
    end
    local stride = file:seek() -- byte position after the first line (incl. EOL)
    if not stride or stride <= 0 then
        return nil
    end
    local line_count = math.floor(size / stride)
    if line_count < 1 then
        return nil
    end
    for _attempt = 1, SEEK_ATTEMPTS do
        local index = math.random(0, line_count - 1)
        file:seek("set", index * stride)
        local line = file:read("*l")
        if line then
            local ok, raw = pcall(match, line)
            if ok and raw then
                return raw
            end
        end
    end
    return nil
end

-- O(1) sampling for big files: jump to a random byte offset, skip the partial
-- line we landed in, then take the next full line. Retries a few times so
-- comment/blank lines don't matter. Returns the chosen raw record or nil.
local function sampleBySeek(file, size, match)
    for _attempt = 1, SEEK_ATTEMPTS do
        local offset = math.random(0, size - 1)
        file:seek("set", offset)
        if offset > 0 then
            file:read("*l") -- discard the partial line we jumped into
        end
        local line = file:read("*l")
        if not line then -- landed in the trailing line: wrap to the top
            file:seek("set", 0)
            line = file:read("*l")
        end
        if line then
            local ok, raw = pcall(match, line)
            if ok and raw then
                return raw
            end
        end
    end
    return nil
end

-- Load one random puzzle entry from a single file.
function Bank.loadRandomFromFile(source, path)
    local format = Formats[source.format]
    if not format or not format.match then
        return nil, _("Unknown puzzle format.")
    end
    local file = io.open(path, "r")
    if not file then
        return nil, _("Could not open the puzzle file.")
    end
    local size = file:seek("end") or 0
    size = math.floor(size)

    local raw
    if size > SEEK_THRESHOLD then
        if format.fixed_width then
            raw = sampleByFixedWidth(file, size, format.match)
        end
        if not raw then
            raw = sampleBySeek(file, size, format.match)
        end
    end
    if not raw then
        raw = sampleByScan(file, format.match)
    end
    file:close()

    if not raw then
        return nil, _("No valid puzzles were found in this file.")
    end
    local entry = buildEntry(raw)
    if not entry then
        return nil, _("No valid puzzles were found in this file.")
    end
    entry.file_name = path:match("[^/\\]+$")
    entry.source_name = source.name
    entry.label = composeLabel(source, entry.label_extra)
    return entry
end

-- Pick a random file from the source, then a random puzzle within it.
function Bank.loadRandomFromSource(source)
    local files = Bank.listFiles(source)
    if #files == 0 then
        return nil, _("This bank has no puzzle files.")
    end
    local file = files[math.random(#files)]
    return Bank.loadRandomFromFile(source, file.path)
end

return Bank
