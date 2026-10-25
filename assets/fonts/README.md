# Bundled emoji

ArcospaceEmoji.ttf is a 61,828-byte subset of Noto Color Emoji (CBDT/CBLC bitmap color font), renamed Arcospace Emoji. Only the UI icon glyphs are included; no system emoji font is required.

- Upstream: https://github.com/googlefonts/noto-emoji
- Pinned revision: `e20cbc2bbec1926686be9f9bee7d1d2cfa1fea0e`
- Source: `2D/fonts/NotoColorEmoji.ttf`
- Source SHA-256: `15671215ab769fdc7162a045d56fd7d7e477c51b04e6b3c761d914d8fdd6cc44`
- License: SIL Open Font License 1.1, included in `OFL.txt`; original font copyright metadata retained.
- Rebuild: install `fonttools==4.60.1`, download the pinned source, then run `python tools/subset_emoji_font.py path/to/NotoColorEmoji.ttf`.

`emoji_ui.tres` keeps Godot's default text font and adds the bundled emoji fallback. UI heading labels use it. Mappings are collected from `scripts/ui/encounter_presentation.gd` and `scripts/presentation/star_system/poi_marker.gd`. Rebuild the subset when adding new symbols. Star-map markers use the bundled color font directly, with the default text font for planet names. All 12 category emojis and the unknown-category glyph are bundled; the completion check is drawn geometrically. The optional Android text-only preference remains available but is disabled by default.
