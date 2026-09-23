# Lexicon Latinum --- Corpus Phraseologiæ

A print dictionary built with LuaLaTeX: the complete Wagner 1878 Lexicon
Latinum (11,239 Latin--French phraseology articles, Project Gutenberg
eBook \#71280), typeset in a dense Oxford/Robert-style two-column
layout. Entries live in `wagner-lat-fra.csv` (generated from the source
by `scripts/wagner2csv.py`) and are parsed at compile time by a Lua CSV
engine. Abbreviations live in `abbreviations.csv` (generated from the
source's signs table). Run `lualatex` twice for a full build; each pass
takes a couple of minutes; the current edition runs to about 670
pages. The main face is Lexicon No1 when it is installed and XCharter
otherwise; `scripts/publish-public.sh` builds the XCharter edition and
publishes it as `dictionary.pdf` on the public repository.

This repository holds the LaTeX sources and data only. Fonts are not
included: Lexicon No1 is commercial and must be installed system-wide,
and Gentium 7.000 and Charis SIL must be downloaded from SIL and placed
in `fonts/` before building. Without Lexicon No1 the build falls back
to XCharter, which is what the distributed `dictionary.pdf` uses.

`lexicon.csv` remains in the repo as small sample data (English test
entries pulled from Wiktionary or invented); point
`\builddictionary{...}` at it for quick experiments.

All project-written *code* is released under
https://creativecommons.org/publicdomain/zero/1.0/ ; the impressum's
copyright claim is a placeholder only and has no legal meaning.

## Project layout

| File | Role |
|----|----|
| `dictionary.tex` | The document: page design (geometry, fonts, grid, running-head layout), front matter, `\builddictionary{wagner-lat-fra.csv}` call, sort-fold table. |
| `dictionary-tools.sty` | Typesetting machinery: entry/letter macros, running-head mark classes, engine loader, config setters. |
| `dictionary-tools.lua` | The engine: CSV parsing, definition/label/sense formatting, custom collation, index keys. Emits the macros defined in the `.sty` (the contract is documented in both file headers). |
| `wagner-lat-fra.csv` | The entries: full Wagner corpus (see *CSV format*). |
| `lexicon.csv` | Sample entries for experiments/tests. |
| `scripts/wagner2csv.py` | Converts the PG \#71280 HTML corpus to the CSV (stdlib Python; prints a validation report). |
| `scripts/wagner-prefaces.py` | Extracts the French/Latin prefaces as `foreword-fr.tex` / `foreword-la.tex`. |
| `scripts/wagner-indexes.py` | Extracts the three historic back-matter indexes as `index-*.tex` (replaces the generated makeindex section). |
| `sortorder.txt` | Optional collation alphabet (see *Sort order*). |
| `dictionary-abbreviations.sty` | Styling for the abbreviations table. |
| `dictionary-abbreivations.lua` | Parses 3-column CSV for abbreviations table. |
| `abbreviations.csv` | your csv of abbreviations! Three columns. Simple. |

## Building

The edition incorporates 543 verified Latin corrections and 21 further
editorial decisions that change the text or its quantity notation. Their
original readings, replacements, and sources are retained in
[`data/latin-corrections.json`](data/latin-corrections.json). All three
extractors apply this register automatically: dictionary corrections use
source article anchors and exact field checks; index and preface corrections
require an exact, unique original passage. Source drift stops generation
with an error. The Gutenberg HTML remains unchanged.

Regenerate the corrected text from the supplied transcription:

```sh
python3 scripts/wagner2csv.py source/html/pg71280-images.html wagner-lat-fra.csv
python3 scripts/wagner-indexes.py source/html/pg71280-images.html .
python3 scripts/wagner-prefaces.py source/html/pg71280-images.html .
```

Verified historical variants are retained. The editorial note distinguishes
feminine *etesiæ* and *planeta*, later *obsurdeo*, and Cicero's use of
*facere sumptus*. All 21 formerly unresolved findings now have an editorial
disposition; four additional decisions address queries outside that list.
The [resolution report](latin-resolutions-2026-09-09.md) and
[`data/latin-resolutions.json`](data/latin-resolutions.json) distinguish
corrections, adopted conjectures, normalization, omissions, and retained
readings. Disputed quantity marks are omitted; an unmarked vowel does not
assert a short or long quantity. The earlier [verification report](latin-verification-2026-09-09.md)
documents the **pre-correction** edition and remains historical evidence.

Check correction guards and reproducible generation with
`python3 tests/test-latin-corrections.py`; run the existing typesetting-engine
tests with `texlua tests/test-dictionary-tools.lua`.

Compile with LuaLaTeX (plain `pdflatex`/`xelatex` will not work --- the
parser relies on `\directlua`):

``` sh
lualatex dictionary.tex
```

## CSV format

``` csv
Word,IPA,POS,Definition,Examples,Synonyms,Antonyms,Adverbs,Epithets,Phrases,Usage,Notes
ABDĬTUS,,"part. v. abdo.","_Caché._",,"Latens, opacus.","Apertus.",,,,"1. Abditi foci.",
```

The first five columns are the original schema; the seven element
columns are optional (missing trailing cells read as empty, so
five-column CSVs like `lexicon.csv` still build unchanged). Each element
column prints after the definition, introduced by its small-caps label:
Synonyms (syn.), Antonyms (the historic `)(` sign), Adverbs (adv.),
Epithets (epith.), Phrases (phras.), Usage (usus:), then Notes ---
pre-labelled segments joined with `" | "` (e.g.
`Vulg. dicitur. | Prov. latet anguis.`). In any cell, `_text_` renders
in italic, and known element labels occurring mid-text (Transl., Fig.,
Cf., ...) are small-capsed automatically.

| Column | Required | Notes |
|----|----|----|
| `Word` | yes | Headword. Lowercase unless a proper noun --- for the Wagner corpus the converter enforces this: lemmas are lowercased and re-capitalised only when the entry's own text shows the word capitalised mid-sentence. |
| `IPA` | yes | Raw IPA transcription (not LaTeX-escaped). May be empty --- no brackets are printed then. |
| `POS` | yes | Part of speech, e.g. `n`, `adj`, `v`. |
| `Definition` | yes | Quote the field (`"..."`) if it contains commas; use `""` for literal quotes. See *Definition markup* below. |
| `Examples` | no | Semicolon-separated pairs: `expression: definition;expression 2: definition;`. Split on the *first* colon. Use `~` as a placeholder for the headword --- automatically mapped to a swung dash. An item **without** a colon is not a new example --- it continues the previous definition and is rejoined with `;`, so example definitions may safely contain semicolons (but not colons). |

### Definition markup

- **Multiple senses** are numbered inline:
  `1. first sense 2. second sense` (1--2 digits, e.g. `12.`). Sense
  numbers are automatically emboldened when preceded by whitespace or at
  field start.
- **Usage labels** in parentheses --- `(UK, slang, derog.)`,
  `(figuratively)` --- are automatically italicized, but *only* in
  expansion-initial position: at the very start of a sole unnumbered
  definition, or right after a full stop (which includes right after a
  sense number). Parentheticals in running text stay upright.

## Sort order (`sortorder.txt`)

Optional file listing every sortable "letter" separated by commas and/or
blanks (both work). Letters may be multi-character digraphs (`Ll`, `Ch`)
or diacritics (`Č`), so languages that collate these separately are
handled; matching is case-insensitive and headline letters print exactly
as written in the file. When present:

- entries are sorted by this custom collation (characters not listed
  sort last),
- each letter opens a **new page** with a large headline letter,
- the back index follows the same collation (via generated makeindex
  sort keys).

Without the file, entries flow in CSV order with no letter pages.

A different filename can be set in the preamble:
`\dictsortorderfile{my-alphabet.txt}`.

## Page breaking policy

Entries are set as single run-on paragraphs (senses inline with bold
numbers, examples inline at the end) and break freely at line level, as
in the Oxford and Robert print references. Two guards apply: a
headword's first line is never left alone at the bottom of a column, and
widows are discouraged but not banned (a hard ban would punch holes in
the `\flushbottom` baseline grid). When a page begins in the middle of a
still-open entry, the running head gains a continuation note --
`word — word2  (set, cont.)` -- driven by a kernel mark class
(`dictcont`, LaTeX 2022+ `\NewMarkClass`) set at entry start and cleared
at entry end; no manual tagging needed.

The stress-test case is the `set` entry in `lexicon.csv` (97 senses, 426
derived-term examples, pulled from Wiktionary).

## Sort folding

For collations where decorated letters must file under their base form
(Wagner interfiles Æ as AE, Œ as OE, and ignores vowel-quantity marks),
set an ordered fold table before the build (see the `\directlua` block
in `dictionary.tex`): pairs like `{"Ā","A"}` or `{"Æ","AE"}` are applied
to a copy of the headword for sorting and index keys only --- the
printed form keeps its marks. Languages that collate decorated letters
separately must not fold them.

## Encoding: UTF-8 only

The CSV **must be saved as UTF-8 (without BOM)**. The IPA column and the
example swung dash rely on multi-byte Unicode characters; any other
encoding (Latin-1, Windows-1252) will produce garbled phonetics or break
the Lua parser. Configure your editor/spreadsheet export accordingly.

## Requirements

LaTeX packages (all included in TeX Live / MiKTeX):

- `geometry`
- `fontspec`
- `xcolor`
- `microtype`
- `imakeidx`
- `fancyhdr`

Fonts:

- Lexicon No1 (Roman A/D, Italic A/D) --- main text font when
  installed; commercial (TEFF), not included in this repo
- XCharter (TeX Live package `xcharter`, SIL OFL) --- main text font
  otherwise, and always for the published PDF (define `\publicfonts`
  before `\input{dictionary}` to force it)
- Charis SIL --- main IPA text font (place in `fonts/`, not vendored)
- Gentium --- vendored fallback for Greek, Cyrillic, superscript letters
  and symbols missing from XCharter
- DejaVu Serif --- last-resort glyph fallback
- yfonts (TeX Live package) --- blackletter textura for the historic
  title pages
