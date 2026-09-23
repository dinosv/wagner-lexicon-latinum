# Acknowledgements

## Wagner, Lexicon Latinum (Project Gutenberg #71280)

The dictionary content (`wagner-lat-fra.csv`, the prefaces and the signs
table) is converted from the Project Gutenberg transcription of
P. Franc. Wagner's *Lexicon Latinum seu Universae Phraseologiae Corpus
Congestum* (ed. Auguste Borgnet, Belgium, 1878): eBook
[#71280](https://www.gutenberg.org/ebooks/71280), released 26 July 2023,
credited to MWS, rmedinap and the Online Distributed Proofreading Team
at https://www.pgdp.net. The text is in the public domain; the Project
Gutenberg licence applies to the transcription itself. The ornamental
dropcaps and decorations of the printed original are not reproduced.

## Wiktionary

Sixty sample entries in `lexicon.csv` (the English blends `tablebase` through `Tealiban`) were pulled from [Wiktionary](https://en.wiktionary.org/) — specifically [Category:English blends](https://en.wiktionary.org/wiki/Category:English_blends) — including their definitions, parts of speech, and IPA transcriptions where available.

The pathological page-breaking test entry `set` was likewise built from [Wiktionary's *set* page](https://en.wiktionary.org/wiki/set): all 97 top-level English senses (verb, noun, adjective) and 426 derived terms with their first definitions, used as example lines.

The non-Latin script showcase entries were pulled the same way: 39 Greek nouns (`φα` onward, from [Category:Greek nouns](https://en.wiktionary.org/wiki/Category:Greek_nouns)) and 40 Bulgarian lemmas (`раб` onward, from [Category:Bulgarian lemmas](https://en.wiktionary.org/wiki/Category:Bulgarian_lemmas)), with their English-side definitions, parts of speech, and IPA where available.

Wiktionary content is available under the [Creative Commons Attribution-ShareAlike License (CC BY-SA)](https://creativecommons.org/licenses/by-sa/4.0/). These entries are used here **only as test data to validate the typesetting pipeline**; they are not part of any released dictionary content. If they were ever to be published, proper attribution and share-alike licensing of the affected entries would be required.

## Fonts

The main text face is [Lexicon No1](https://www.teff.nl/fonts/lexicon/) by Bram de Does (The Enschedé Font Foundry): Roman A for text, Roman D as the bold, Italic A and D for the italics. Lexicon is a commercial typeface used under the project owner's licence; it is not distributed with this repository. When it is not installed, and always for the published PDF, the build uses [XCharter](https://ctan.org/pkg/xcharter), Michael Sharpe's extension of Matthew Carter's Bitstream Charter, released under the SIL Open Font License, Version 1.1, and shipped with TeX Live.

The `fonts/` directory vendors:

- [Gentium](https://software.sil.org/gentium/) (version 7.000) — fallback face for the Greek and Cyrillic headword scripts and for symbols missing from Lexicon — SIL Open Font License (OFL), Version 1.1 (see `fonts/OFL-Gentium.txt`)
- [Charis SIL](https://software.sil.org/charis/) — used for IPA transcriptions only — SIL Open Font License (OFL), Version 1.1

Required as a system font:

- [DejaVu Serif](https://dejavu-fonts.github.io/) — last-resort glyph fallback (loaded via luaotfload in dictionary.tex) — DejaVu Fonts License (Bitstream Vera / Arev derived)
