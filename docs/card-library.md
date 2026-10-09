# Card library

28 cards ported from Starship Duel (`tower-duel`), source commit
`36a5d309aa1d8e0ed7a21c10820e0ade0f8764de`, `dist/game.mjs` and `dist/theme.mjs`.
Costs and effect order match that source. Fabricator/Hangar are named
Synthesizer/Quarters to match this Godot project.

## Edit and test

- Select a `.tres` file in `cards/` to edit its name, cost, description,
  effects and Play Again flag in the Inspector.
- `scripts/card_library.gd` lists the cards in original order.
- `scripts/card_effects.gd` pays the cost and updates actor/enemy dictionaries.
  It can be used for either player; it does not manage turns.
- Run the board. Previous/Next cycles between the six original test cards
  and five library pages. Buttons can be played repeatedly while affordable.
- Restart the scene to reset the test state. Current starting resources remain 16.

The board is still a card-testing scene, not a complete match. No hand/draw,
discard, AI, turn income or full victory rules have been added. Energy Surge
sets `extra_action_requested`; a future turn controller must consume this flag
and allow another action without granting turn income. Descriptions are explicit
text: update them when changing effects.

Validation: Godot 4.6 headless import and board startup passed. All 28 card effects
matched browser results in 336 combinations of shield/resource values, including
piercing, shield break before damage, limited theft, resource drain and minimum
production. Unaffordable plays were rejected without changing actor state.
The project declares Godot 4.7; visual layout and that version were not tested here.
