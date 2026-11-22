"""Cuts M PLUS 1 down to what the Japanese translation uses.

Run after changing the Japanese column of Resources/Translations/strings.csv
(new characters would otherwise show as empty boxes):

    pip install fonttools
    python Tools/subset_japanese_font.py

Reads the full font from Assets/Source/Fonts (not shipped) and writes
Resources/MPLUS1-Japanese.ttf, keeping:
  - every character in the translation's Japanese column,
  - all hiragana, katakana, Japanese punctuation and full-width forms,
  - ASCII, and every weight (it stays a variable font).
It also trims the font's line height to the em box (ascent 0.88, descent
0.12): M PLUS 1 ships with 1.45 em lines, and next to Copperplate's short
caps lines (0.59 em) every Japanese line came out much taller than English,
pushing dialogs off screen.
"""
import csv
import os
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Assets", "Source", "Fonts", "MPLUS1-VariableFont_wght.ttf")
CSV = os.path.join(ROOT, "Resources", "Translations", "strings.csv")
OUT = os.path.join(ROOT, "Resources", "MPLUS1-Japanese.ttf")
ALWAYS = "U+0020-007E,U+3000-303F,U+3040-309F,U+30A0-30FF,U+FF00-FFEF"

with open(CSV, encoding="utf-8", newline="") as f:
    rows = list(csv.DictReader(f))
text = "".join(row["ja"] for row in rows) + "日本語"

options = subset.Options()
options.layout_features = ["*"]
font = TTFont(SOURCE)
subsetter = subset.Subsetter(options)
subsetter.populate(text=text, unicodes=subset.parse_unicodes(ALWAYS))
subsetter.subset(font)

hhea, os2 = font["hhea"], font["OS/2"]
hhea.ascent, hhea.descent, hhea.lineGap = 880, -120, 0
os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = 880, -120, 0
os2.usWinAscent, os2.usWinDescent = 880, 120
os2.fsSelection |= 1 << 7   # USE_TYPO_METRICS
font.save(OUT)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB,", len(font.getGlyphOrder()), "glyphs")
