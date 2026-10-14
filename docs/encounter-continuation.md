# Encounter continuation

The result overlay previews a random active modifier for the next encounter and offers Continue after victory or FTL escape. The choice is rolled once per result (equal odds across Asteroid belt, Ion storm, Solar flare, Nebula and Temporal Rift). Edit this selection in board.gd if you want different weights or to exclude the test modifier.

Continue instantiates the current board scene with its setup settings. Only the remaining player hull carries over. Shields reset to the board scene's starting value (currently 10); both ships' resources and production reset to setup values, with usual first-player-turn income. Enemy hull/shields, hands, FTL and turn count reset. The next modifier selects the corresponding editable battlefield scene.

Play Again remains a fresh restart; Battle Setup returns to configuration. Defeat/draw cannot continue. No star system scene or expedition progression/deck persistence is introduced yet.

Hull amount no longer wins a battle, for either ship. Existing enemy destruction, resource victory and manual FTL escape remain. This permits a surviving player to retain 50+ hull without automatic wins in the following encounters.

## Result details and one-battle rewards

The expanded result panel reports the current full-round number, victory method, accumulated player hull damage, and initial→remaining hull. Hull damage counts real damage including self-damage and asteroids; repairs do not reduce the accumulated total. Shield loss is excluded and the label explicitly says Hull damage.

Normal victory is destroying the enemy or escaping by FTL; the existing resource victory is also reported if reached. Tactical victory requires ending with strictly more hull than the encounter started with, including carried hull as the baseline. It grants +5 Materials, Energy and Crew before next encounter income. Strategic victory compares summed Synthesizer+Reactor+Quarters against the enemy's total at victory, strictly higher, and grants +10 shields above the next encounter's reset shield value. Both bonuses stack and apply equally to escape/destruction wins. Draws/defeats earn neither. The bonus constants in board.gd are marked TUNE.

Rewards are passed separately from setup values, so they expire after the immediately following encounter and cannot permanently inflate starting resources/shields. New encounters snapshot hull anew and clear the damage tally. Play Again and Battle Setup grant no continuation rewards.

## Salvage and run score

Defeat/draw shows a large bold battles-won count. Every player victory (including FTL escape) increments this count once. Continue carries it; Play Again/Setup begins a fresh run.

Destroying the enemy in a surviving player victory grants 10 Salvage, once per result. FTL and resource victories do not grant salvage. Unspent salvage carries to the next encounter; a small counter appears below Turn in the battle's upper left.

The victory panel's −/+ controls select spending at 1 Hull per Salvage, defaulting to the smaller of available salvage and missing Hull. Spending cannot exceed either limit. Repair deducts only the selected amount; the rest remains. Repairs stop at configured Hull capacity (default 30) and never reduce excess Hull. This is available after any victory, so saved salvage can be used after FTL escape. TUNE board.gd constants DESTRUCTION_SALVAGE, HULL_PER_SALVAGE and the exported player_hull_capacity.

Combat result hull and earned tactical/strategic bonuses are frozen before repair. Post-battle repairs cannot earn an additional tactical bonus; repaired hull is carried into the next encounter as its new baseline.
