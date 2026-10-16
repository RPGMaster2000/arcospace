# Rebuild from the pinned upstream font documented in assets/fonts/README.md.
# Usage: python tools/subset_emoji_font.py path/to/NotoColorEmoji.ttf
import re
import sys
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
root = Path(__file__).resolve().parents[1]
text = (root / 'scripts/ui/encounter_presentation.gd').read_text(encoding='utf-8')
glyphs = ''.join(re.findall(r'\["([^"\n]+)", "[A-Z]+"\]', text))
font = TTFont(sys.argv[1])
options = subset.Options()
options.recalc_timestamp = False
worker = subset.Subsetter(options=options)
worker.populate(text=glyphs)
worker.subset(font)
# Mark this modified subset with a project-specific family name.
for record in font['name'].names:
    if record.nameID in (1, 3, 4, 6):
        record.string = 'Arcospace Emoji'.encode(record.getEncoding())
font.save(root / 'assets/fonts/ArcospaceEmoji.ttf')
print('Bundled emoji subset:', (root / 'assets/fonts/ArcospaceEmoji.ttf').stat().st_size, 'bytes')
