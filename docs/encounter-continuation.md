# Encounter continuation

The result overlay previews a random active modifier for the next encounter and offers Continue after victory or FTL escape. The choice is rolled once per result (equal odds across Asteroid belt, Ion storm, Solar flare, Nebula and Temporal Rift). Edit this selection in board.gd if you want different weights or to exclude the test modifier.

Continue instantiates the current board scene with its setup settings. Only the remaining player hull carries over. Shields reset to the board scene's starting value (currently 10); both ships' resources and production reset to setup values, with usual first-player-turn income. Enemy hull/shields, hands, FTL and turn count reset. The next modifier selects the corresponding editable battlefield scene.

Play Again remains a fresh restart; Battle Setup returns to configuration. Defeat/draw cannot continue. No star system scene or expedition progression/deck persistence is introduced yet.

Hull amount no longer wins a battle, for either ship. Existing enemy destruction, resource victory and manual FTL escape remain. This permits a surviving player to retain 50+ hull without automatic wins in the following encounters.
