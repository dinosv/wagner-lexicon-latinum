-- dictionary-tools.lua
-- CSV-driven dictionary engine for LuaLaTeX. Loaded by dictionary-tools.sty
-- via require(); the only TeX-facing entry point is process_dictionary_csv.
--
-- CONTRACT: the engine emits the following macros via tex.print, all of
-- which must be defined by dictionary-tools.sty:
--   \printentry{word}{ipa}{pos}{definition}
--   \dictlabel{label} (small-caps element labels, inside entry bodies)
--   \dictfr{text} (italic French gloss segments, inside entry bodies)
--   \letterheader{letter}
--   \entrydone
--   \index{key@word} (imakeidx)
--
-- All functions live on the module table (rather than locals) so test
-- harnesses can exercise them individually:
--   local dt = require("dictionary-tools")
--   assert(dt.escape_latex("50%") == "50\\%")

local M = {}

-- Tunables, settable from TeX (see \dictsortorderfile in dictionary-tools.sty)
-- or directly from Lua before the build call.
M.config = {
    -- Optional custom collation alphabet. When the file is absent the
    -- entries flow through in CSV order, without letter headers.
    sort_order_file = "sortorder.txt",
    -- Optional sort folding: an array of {from, to} pairs applied to the
    -- headword (in order) before sort tokenisation and index keys, so
    -- decorated letters can collate as their base form (quantity marks,
    -- ligatures: {"Ā","A"}, {"Æ","AE"}, ...). Display text is untouched.
    -- nil disables folding entirely -- languages that collate decorated
    -- letters separately must NOT fold them.
    sort_fold = nil,
}

function M.parse_csv_line(line)
    local res = {}
    local pos = 1
    -- Ensure line ends cleanly with a separator to capture trailing empty cells
    line = line .. ','

    while pos <= #line do
        local next_char = string.sub(line, pos, pos)
        if next_char == '"' then
            -- Quoted field parsing
            local txt = ""
            pos = pos + 1
            while pos <= #line do
                local startp, endp = string.find(line, '^[^"]*', pos)
                txt = txt .. string.sub(line, pos, endp)
                pos = endp + 1
                if string.sub(line, pos, pos) == '"' then
                    if string.sub(line, pos + 1, pos + 1) == '"' then
                        txt = txt .. '"' -- Escaped quote sign inside cell
                        pos = pos + 2
                    else
                        pos = pos + 1 -- Outer closing quote sign reached
                        break
                    end
                end
            end
            table.insert(res, txt)
            pos = pos + 1 -- Skip the trailing comma delimiter
        else
            -- Plain unquoted field extraction
            local startp, endp = string.find(line, '^[^,]*', pos)
            if endp then
                table.insert(res, string.sub(line, pos, endp))
                pos = endp + 2
            else
                break
            end
        end
    end
    return res
end

-- Safely sanitize critical LaTeX control characters found inside strings
function M.escape_latex(text)
    if not text then return "" end
    text = text:gsub("\\", "\\textbackslash{}")
    text = text:gsub("([&%%%$#{}_])", "\\%1")
    text = text:gsub("~", "⁓") -- use a swung dash instead of tilde
    text = text:gsub("%^", "\\textasciicircum{}")
    return text
end

-- Apply the sort-fold pairs (see config.sort_fold) to a word. Identity
-- when no fold table is configured. Keys are plain strings, so gsub
-- needs its magic characters neutralised -- fold sources are letters in
-- practice, but escape defensively.
function M.fold(word)
    local pairs_ = M.config.sort_fold
    if not pairs_ then return word end
    for _, p in ipairs(pairs_) do
        word = word:gsub((p[1]:gsub("%p", "%%%1")), p[2])
    end
    return word
end

-- Inline markup: _text_ becomes an italic French-language segment
-- (\dictfr -- the marked spans are the French glosses). Apply AFTER
-- escape_latex, which has turned each raw "_" into "\_" -- so the
-- pattern matches the escaped form and unwraps it. Markers never nest
-- and never span paragraphs; an unpaired marker is left escaped, which
-- is the safe rendering of a stray underscore.
function M.format_markup(text)
    return (text:gsub("\\_(.-)\\_", "\\dictfr{%1}"))
end

-- Small-caps the element labels of the source dictionary wherever they
-- appear in running text (Wagner-style: Transl., Fig., Cf. show up
-- mid-flow inside Usus senses). Lowercased inside \dictlabel so true
-- small caps render the whole label at small-cap height.
M.inline_labels = {
    "Syn%.", "Epith%.", "Phras%.", "Adv%.", "Vulg%.", "Transl%.",
    "Prov%.", "Rad%.", "Differ%.", "Signif%.", "Fig%.", "Cf%.",
    -- stranded top-level labels kept inline by the converter (a Usus
    -- run opening the entry) style like their columned counterparts
    "Usus:", "Usus%.",
}
function M.format_inline_labels(text)
    for _, pat in ipairs(M.inline_labels) do
        text = text:gsub("(%f[%a])(" .. pat .. ")", function(_, lbl)
            return "\\dictlabel{" .. lbl:lower() .. "}"
        end)
    end
    return text
end

-- Bold inline sense numbers in multi-definition entries. Matches
-- "\s\d{1,2}.\s" (e.g. " 2. ", " 12. ") so ordinary sentence-ending
-- digits like "series #2." followed by a parenthesis are left untouched.
-- Also anchors the leading sense at the very start of the field ("1. ...").
-- Apply AFTER escape_latex (digits, dots and spaces are never escaped).
function M.format_senses(text)
    text = text:gsub("^(%d%d?%.)(%s)", "\\textbf{%1}%2")
    text = text:gsub("(%s)(%d%d?%.)(%s)", "%1\\textbf{%2}%3")
    return text
end

-- Italicize parenthesized usage labels in definitions: regionalisms
-- "(AmEn, UK)", attitude "(derog.)", or combinations "(UK, slang, derog.)".
-- A label is recognized in expansion-initial position only, i.e. either at
-- the very start of a sole unnumbered definition, or right after a full
-- stop. The latter covers both a sense number ("2. (UK) ...", since "2."
-- itself ends in a stop) and a new expansion within a sense ("...; sour.
-- (of wine) high in acidity."). Parentheticals elsewhere in the running
-- text are left untouched. The parentheses stay upright; only the content
-- is italic. Nested parentheses are not supported. The two patterns cannot
-- overlap (field start has no preceding stop), so no double-wrapping.
-- Apply AFTER escape_latex but BEFORE format_senses, so this sees the raw
-- "1. " form, not the inserted \textbf{}.
function M.format_labels(text)
    -- Sole unnumbered definition: label at the very start of the field
    text = text:gsub("^(%s*)%(([^()]+)%)", "%1(\\textit{%2})")
    -- Label right after a full stop: sense number or expansion boundary
    text = text:gsub("(%.%s+)%(([^()]+)%)", "%1(\\textit{%2})")
    return text
end

-- Parse the Examples column: a semicolon separated list of
-- "example expression: definition" pairs. Definitions may themselves
-- contain semicolons: an item WITHOUT a colon is not a new example but
-- the continuation of the previous definition, and is rejoined with ";".
-- Limitation: a continuation fragment containing a colon is
-- indistinguishable from a new example.
-- Returns an INLINE run for embedding at the end of the entry paragraph
-- (italic expression, colon, gloss, "; " separators, no marker, no
-- trailing punctuation), or "" when the cell is empty. The caller
-- (process_dictionary_csv) appends it to the entry body.
function M.parse_examples(text)
    if not text or text:gsub("%s+", "") == "" then return "" end
    local items = {}
    for item in text:gmatch("[^;]+") do
        if item:find(":") then
            table.insert(items, item)
        elseif #items > 0 then
            items[#items] = items[#items] .. ";" .. item
        end
    end
    local out = {}
    for _, item in ipairs(items) do
        -- Split on the first colon only; glosses may contain further colons
        local expr, def = item:match("^%s*(.-)%s*:%s*(.-)%s*$")
        if expr and expr ~= "" then
            table.insert(out, string.format("\\textit{%s}: %s",
                M.escape_latex(expr), M.escape_latex(def)))
        end
    end
    return table.concat(out, "; ")
end

-- Case folding that also covers non-ASCII when LuaTeX's unicode lib exists
local ulower = (unicode and unicode.utf8 and unicode.utf8.lower) or string.lower

-- Load the custom collation alphabet: every sortable "letter" (possibly a
-- multi-character digraph like "Ll" or a diacritic like "Č") separated by
-- commas and/or blanks -- both work, mixed freely. Returns nil if absent.
function M.load_sort_order(filename)
    local f = io.open(filename, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    local letters = {}
    for tok in content:gmatch("[^,%s]+") do
        table.insert(letters, tok)
    end
    if #letters == 0 then return nil end
    return letters
end

-- Build collator state: rank per lowercased letter, plus the letter list
-- ordered longest-first so digraphs ("ll") beat their prefix letter ("l")
function M.build_collator(letters)
    local rank, probe = {}, {}
    for i, l in ipairs(letters) do
        local ll = ulower(l)
        rank[ll] = i
        table.insert(probe, ll)
    end
    table.sort(probe, function(a, b) return #a > #b end)
    return rank, probe
end

-- Turn a word into its sequence of sort ranks via longest-match. Anything
-- not listed in the sort order sinks behind all real letters (1000 + byte),
-- so digits and stray symbols never claim a letter block of their own.
function M.sort_tokens(word, rank, probe)
    local w = ulower(word)
    local tokens = {}
    local pos = 1
    while pos <= #w do
        local matched = false
        for _, l in ipairs(probe) do
            if w:sub(pos, pos + #l - 1) == l then
                table.insert(tokens, rank[l])
                pos = pos + #l
                matched = true
                break
            end
        end
        if not matched then
            table.insert(tokens, 1000 + w:byte(pos))
            pos = pos + 1
        end
    end
    return tokens
end

-- Encode a token sequence as a fixed-width sort key for makeindex, used
-- via \index{key@word}. Each rank becomes three base-26 lowercase letters
-- ("aab", "aac", ...): makeindex would sort digit-leading keys numerically
-- (its "numbers" group), but pure-letter keys compare cleanly byte-wise,
-- making the index collation match ours exactly. Capacity 26^3 = 17576
-- comfortably covers alphabet ranks plus the 1000+byte unknown-char sink.
function M.index_key(tokens)
    local parts = {}
    for _, t in ipairs(tokens) do
        local n = t
        local c3 = n % 26; n = math.floor(n / 26)
        local c2 = n % 26; n = math.floor(n / 26)
        local c1 = n % 26
        table.insert(parts, string.char(97 + c1, 97 + c2, 97 + c3))
    end
    return table.concat(parts)
end

-- Main engine pipeline
function M.process_dictionary_csv(filename)
    local file = io.open(filename, "r")
    if not file then
        tex.print("\\textbf{Error: CSV file not found!}")
        return
    end

    -- Pass 1: collect all rows
    local entries = {}
    local is_header = true
    for line in file:lines() do
        if is_header then
            is_header = false
        else
            -- Strip trailing windows/unix carriage returns smoothly
            line = line:gsub("[\r\n]", "")
            if line:gsub("%s+", "") ~= "" then
                local data = M.parse_csv_line(line)
                if #data >= 4 then
                    table.insert(entries, data)
                end
            end
        end
    end
    file:close()

    -- Pass 2: optional custom collation. Without the sort-order file the
    -- entries flow through untouched, in CSV order, without headers.
    local letters = M.load_sort_order(M.config.sort_order_file)
    if letters then
        local rank, probe = M.build_collator(letters)
        for _, e in ipairs(entries) do
            e.tokens = M.sort_tokens(M.fold(e[1]), rank, probe)
        end
        table.sort(entries, function(a, b)
            local ta, tb = a.tokens, b.tokens
            for i = 1, math.min(#ta, #tb) do
                if ta[i] ~= tb[i] then return ta[i] < tb[i] end
            end
            if #ta ~= #tb then return #ta < #tb end
            return a[1] < b[1] -- deterministic tie-break
        end)
    end

    -- Pass 3: ship entries, opening a letter block whenever the leading
    -- letter changes. The header shows the letter as written in the
    -- sort-order file.
    local current = nil
    for _, e in ipairs(entries) do
        if letters then
            local first = e.tokens[1]
            if first and first <= #letters and first ~= current then
                current = first
                tex.print(string.format("\\letterheader{%s}", M.escape_latex(letters[first])))
            end
        end
        local word = M.escape_latex(e[1])
        local ipa  = e[2] -- Retain raw string safely for font structures
        local pos  = M.escape_latex(e[3])

        -- Log word and page number. With a custom sort order, prefix the
        -- makeindex "key@display" sort key so the index collates identically.
        if letters then
            tex.print(string.format("\\index{%s@%s}", M.index_key(e.tokens), word))
        else
            tex.print(string.format("\\index{%s}", word))
        end

        -- Ship one run-on paragraph per entry: formatted definition, the
        -- labelled element segments (extended columns 6-12, emitted in
        -- canonical order with small-caps labels), the inline examples,
        -- then \entrydone INSIDE the closing brace so the mark migrates
        -- out attached to the entry's last typeset line (a stand-alone
        -- vertical-mode token could be pushed to the next page while the
        -- entry stays, leaving it spuriously "open").
        local function rich(cell)
            return M.format_senses(M.format_inline_labels(
                M.format_labels(M.format_markup(M.escape_latex(cell)))))
        end
        local body = rich(e[4])
        local function seg(label, cell)
            if cell and cell:gsub("%s+", "") ~= "" then
                body = body .. " " .. label .. " " .. rich(cell)
            end
        end
        seg("\\dictlabel{syn.}",   e[6])
        seg(")(",                  e[7])
        seg("\\dictlabel{adv.}",   e[8])
        seg("\\dictlabel{epith.}", e[9])
        seg("\\dictlabel{phras.}", e[10])
        seg("\\dictlabel{usus}:",  e[11])
        -- Notes: pre-labelled segments joined with " | " by the producer;
        -- the separator flattens to a space and format_inline_labels
        -- small-caps each segment's own leading label.
        if e[12] and e[12]:gsub("%s+", "") ~= "" then
            body = body .. " " .. rich((e[12]:gsub("%s*|%s*", " ")))
        end
        local examples = M.parse_examples(e[5])
        if examples ~= "" then
            body = body .. " " .. examples
        end
        tex.print(string.format("\\printentry{%s}{%s}{%s}{%s\\entrydone}",
            word, ipa, pos, body))
    end
end

return M
