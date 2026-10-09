# Cards and player hand

28 cards ported from Starship Duel (`tower-duel`), source commit
`36a5d309aa1d8e0ed7a21c10820e0ade0f8764de`, `dist/game.mjs` and `dist/theme.mjs`.
Costs and effect order match that source. Fabricator/Hangar are named
Synthesizer/Quarters to match this Godot project.

## In the editor

- Select a `.tres` in `cards/` to edit its name, cost, description, effects and
  Play Again flag. Update description text yourself when changing effects.
- Duplicate a `.tres` and add its preload to `scripts/card_library.gd` to add a card.
- The six existing board buttons remain editable instances of `scenes/card.tscn`.
  Their Card Data property controls the editor preview; runtime hands override it.
  Shared appearance belongs in `card.tscn`, not in the data resources.
- Select `CardHand` in `board.tscn`. Empty Card Pool uses the full library.
  Drag card resources into Card Pool to use a custom draw pool. Empty Starting
  Hand draws randomly; set it to up to six resources for a repeatable test hand.
  Starting Hand may include cards outside the draw pool. Replacements use the pool.
- Max Copies defaults to 2. A custom pool needs at least three distinct card
  resources to fill six slots at that limit. An undersized pool warns and leaves
  unfillable slots empty. Duplicate entries do not change draw probabilities.
- Select the board root to edit player/enemy starting values or Card Slots.
  Current resource defaults remain 16. The number of linked slots sets hand size.

## Player loop

On startup, deal six cards. Click an affordable card: pay once, resolve its effects,
then draw a replacement into that same slot. Other slots stay unchanged.
Draws follow the browser game's uniform selection with replacement, with at most
two copies per hand. The played card is excluded from the copy count, so the same
card can legitimately be drawn again. There is no finite draw/discard pile.
Unaffordable cards are disabled and cannot consume resources or trigger a draw.

This is a player-only loop. No enemy AI, turn income, discard or full victory
system has been added. The existing zero-Hull stop remains. Energy Surge sets
`extra_action_requested` for a future turn controller; it grants no extra income.
Resources can run out: restart the scene or increase starting values in Inspector.

## Code responsibilities

- `card_data.gd`: Inspector-editable data and change notifications.
- `card_library.gd`: default card catalogue.
- `card_hand.gd`: starting hand, eligible draws and slot replacement.
- `card_effects.gd`: cost payment and effects on actor/enemy state.
- `card_view.gd`: labels, editor preview and affordability appearance.
- `board.gd`: connects button presses, effects, hand and displayed state.

## Verification

Run `godot --headless --path . --script res://tests/player_hand_test.gd`.
Checks cover actual button wiring, costs/effects, same-slot replacement, unchanged
other slots, unaffordable plays, 3,000 random replacements, play-again metadata,
resource-driven label updates and the existing zero-Hull stop.

The original 28 effects were checked against browser results in 336 state
combinations. Current automated checks use Godot 4.6 headless. This project declares
4.7; visual layout and that exact version have not been verified here.
