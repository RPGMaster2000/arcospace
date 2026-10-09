# Cards, hands and AI turns

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

## Match loop

On startup, deal six cards to each side and begin the player turn. Click an affordable card: pay once, resolve its effects,
then draw a replacement into that same slot. Other slots stay unchanged.
Draws follow the browser game's uniform selection with replacement, with at most
two copies per hand. The played card is excluded from the copy count, so the same
card can legitimately be drawn again. There is no finite draw/discard pile.
Unaffordable cards are disabled and cannot consume resources or trigger a draw.

During your turn, right-click a card to discard it, including an unaffordable card.
For touch or left-click, press the Discard +N footer on the chosen card.
The footer shows that card's refund and stays active when playing is unaffordable. Discarding grants floor(cost / 3) in the
card's cost resource without paying the cost or applying any effect. It replaces
that slot and never grants Play Again. The footer is an editable Button in card.tscn.

Normal plays and discards hand control to the opponent. At each new turn,
Materials/Energy/Crew increase by Synthesizer/Reactor/Quarters production.
The current Inspector defaults remain 16 resources and production 2: the player
therefore opens with 18; the enemy starts at 16 until its first turn begins.
Play Again retains the current turn without another income payment, for both sides.
Player play/discard controls are disabled during the enemy turn and after victory.

Win by reducing the opposing Hull to zero, reaching Hull 50, or holding at least
100 of all three resources. Hull Goal and Resource Goal are editable on the board
root. Wins are checked after effects/refunds and income, before another AI action.
The turn label announces the winner. Restart the scene to play a new match.

The enemy uses a separate six-card hand with the same draw and copy rules. It
prefers an immediate win, then attacks an opponent at 15 Hull or less, builds
when its own Hull is at least 40, upgrades production, then chooses a random
legal card. If none is affordable, it discards a random card for the same refund.
This follows Starship Duel's basic AI; it does not plan several turns ahead.

### AI controls in the editor

- `EnemyHand`: set an optional starting hand, card pool or copy limit.
- `EnemyAI`: edit attack/build thresholds.
- `EnemyThinkTimer`: edit Wait Time (default 0.9 seconds between AI actions).
- `TurnLabel` and `LastActionLabel`: edit the status layout and appearance.

## Code responsibilities

- `card_data.gd`: Inspector-editable data and change notifications.
- `card_library.gd`: default card catalogue.
- `card_hand.gd`: starting hand, eligible draws and slot replacement.
- `card_effects.gd`: cost payment and effects on actor/enemy state.
- `card_view.gd`: labels, editor preview and affordability appearance.
- `board.gd`: coordinates both hands, legal actions, turns, timers and display.
- `enemy_ai.gd`: selects a move without changing live state.
- `match_rules.gd`: production income and win conditions.

## Verification

Run `godot --headless --path . --script res://tests/player_hand_test.gd`.
Checks cover actual button wiring, costs/effects, same-slot replacement, unchanged
other slots, unaffordable plays, 3,000 random replacements, play-again metadata,
resource-driven label updates and the existing zero-Hull stop.

The original 28 effects were checked against browser results in 336 state
combinations. Current automated checks use Godot 4.6 headless. This project declares
4.7; visual layout and that exact version have not been verified here.

Discard checks: `godot --headless --path . --script res://tests/discard_test.gd`.
Includes all 28 refunds, real GUI right-click input on an unaffordable card,
per-card footer behavior, effect suppression, replacement and the zero-Hull stop.

## Reference layout

The board follows the supplied vintage sci-fi reference proportions at 1280×720:
large resource totals down the outside edges, small production badges, horizontal
Hull/Shields readouts under the ship placeholders, and six taller cards below.
Each card has a family shape and large cost, title, placeholder art, effect text,
and a separate discard footer. Unaffordable card bodies dim while discard stays
available during your turn. Ship-name headings retain your board edits; a centered
turn label and a last-action line show whose turn it is and which card was used.

All visuals are native scene nodes, polygons, lines, flat styles and a system font.
No generated images or paid assets are used. Move/resize nodes in board.tscn;
edit the shared card structure in card.tscn. Card family colors are in card_view.gd.
All script/test comments are in English.

Headless checks verified text fits for all 28 cards, the six card bounds, player
hand behavior, right-click discard, and actual GUI clicks on the discard footer.
A rendered screenshot was not available in this environment.

AI/turn checks: `godot --headless --path . --script res://tests/ai_turn_test.gd`.
Covers actual Timer-driven play, both sides' extra actions, income timing, blocked
player input, AI discard/refunds, choosing a winning piercing attack, all three
win conditions and stopping AI scheduling on victory.
