-- dictionary-abbreviations.lua
-- Three-column abbreviations table. The first CSV line is a header row
-- whose 2nd/3rd cells become the printed column titles; cell parsing is
-- delegated to the dictionary-tools CSV parser so quoted cells (commas
-- inside) and empty trailing cells work.
local M = {}

function M.process_abbreviations_csv(filename)
    local dt = require("dictionary-tools")
    local file = io.open(filename, "r")
    if not file then
        tex.print("\\textbf{Error: Could not open abbreviations file: " .. filename .. "}")
        return
    end

    tex.print("\\begin{longtable}{>{\\itshape}p{2cm} p{5.5cm} p{5.5cm}}")

    local is_header = true
    for line in file:lines() do
        line = line:gsub("[\r\n]", "")
        if line:match("%S") then
            local c = dt.parse_csv_line(line)
            local c1 = dt.escape_latex(c[1] or "")
            local c2 = dt.escape_latex(c[2] or "")
            local c3 = dt.escape_latex(c[3] or "")
            if is_header then
                is_header = false
                tex.print("& {\\scshape\\MakeLowercase{" .. c2 .. "}} & {\\scshape\\MakeLowercase{" .. c3 .. "}} \\\\")
                tex.print("\\endhead")
                tex.print("\\multicolumn{3}{r}{\\small\\textit{sequitur in pagina proxima}} \\\\")
                tex.print("\\endfoot")
                tex.print("\\endlastfoot")
            else
                -- braces guard the first cell: a bare "*" after the
                -- previous row's \\ would otherwise parse as \\*
                tex.print("{" .. c1 .. "} & " .. c2 .. " & " .. c3 .. " \\\\")
            end
        end
    end

    file:close()
    tex.print("\\end{longtable}")
end

return M
