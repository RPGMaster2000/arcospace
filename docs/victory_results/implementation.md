# Victory result input and animation

Base: main `2dd340c` (weekend polish / PR68).

## Reproduced input failure

A real expedition battle produced a committed pending upgrade event and an enabled
Upgrade Cards button. Simulated pointer movement identified the later-added
results VBoxContainer as the hovered control instead of the button. Wrapped labels
initially computed narrow-width minimum heights; the containers retained heights
around 550 pixels even after layout widened them. Their default PASS mouse filter
sent input to the result root, never to the button's earlier sibling Panel.

The initial regression reproduced two failures: no button press and no upgrade
modal. The input fix makes all decoration explicitly IGNORE pointer input and
refits when minimum sizes settle. The exact same real click then reached Continue,
emitted Board.expedition_continue, reached Expedition._battle_finished, and opened
the existing card-management upgrade modal without changing pending upgrades.
