# Hull capacity and ablative plating

Hull remains one integer per ship. Permanent Hull is min(Hull, capacity); Ablative Plating is max(Hull-capacity, 0). Starter capacity defaults to 30, starting Hull remains 30. Damage still passes through Shields before subtracting Hull, so excess plating is consumed automatically before permanent hull. Repairs can grow Hull without a cap during combat.

In Godot open scenes/board_3d.tscn, select Board3D, and edit Player Hull Capacity in the Inspector. Enemy Hull Capacity is independently editable. These exported properties live in scripts/board.gd and carry through Continue. Larger capacity does not change starting Hull; edit Player Hull separately if desired.

Continue transfers at most the player's configured capacity. Plating does not survive; the next battle's starting hull snapshot uses the capped value. Post-battle salvage repairs use the configured Hull capacity as their ceiling and spend only the selected amount. Victory bonuses are based on the finished combat state as before.

FTL disruption considers only actual permanent Hull lost. Asteroids compare permanent Hull before/after; cards use attack-local damage reports so healing in mixed-effect cards cannot obscure which Hull layer was damaged. Plating-only hits yield zero FTL risk. Existing probabilities and disable duration are unchanged.

scripts/hull_bar.gd draws the compact red/amber bars beside hull status. The red capacity marker separates permanent Hull from plating, and the Hull status shows the total (e.g. Hull 43/30) in amber above capacity. The combined bar fits available width by scaling its denominator to max(capacity,Hull); this imposes no gameplay cap. Inspector colors are adjustable. scenes/board.tscn contains both bars and the capacity label font size. Ship damage markings use permanent Hull in scripts/board_3d.gd.

Relevant checks: hull_capacity_test.gd, salvage_test.gd, victory_rewards_test.gd, encounter_continue_test.gd, tactical_cards_test.gd, ftl_test.gd.

Hull text is light gray normally (amber for excess) and shield text is blue, both 20 px and aligned symmetrically about the board center. FTL is above the player ship, mirroring the Hull status center's distance below it; board_3d.gd recalculates this after viewport resizing.

The player engine light at Battlefield/PlayerShip/Body/OmniLight3D uses its scene-authored energy as the baseline. Board3D Inspector engine_offline_factor defaults to 0.3, engine_ready_factor to 1.4. Pulse depth/speed are also exported. Removing the optional light simply skips its animation.

ModifierDisplay Inspector ftl_offline_seconds (1.45) and ftl_online_seconds (0.65) control dedicated red/blue transition flashes. Online announces resumed charging unless already charged, when it reads FTL ONLINE. These do not change charging or disable timing.

## Field repairs and Outpost plating

On the **star-system screen**, tap the existing Hull status button. Its existing
information overlay now includes quantity controls (minus/slider/plus), affordable
maximum, resulting Hull and total cost. **Confirm** spends **2 Salvage/Hull** and
repairs permanent Hull only, never past the selected ship's normal capacity. Merely
changing a quantity does not spend. Full Hull and insufficient Salvage retain the
information with disabled controls and an explanation. Repairs are unavailable in
PoI/service/preview screens, pending choices or combat, and persist immediately in
`ExpeditionState`. The original grid and star-map presentations use the same entry point.

The Trading Outpost keeps its existing four service slots. Its Hull slot now changes
in place, using the same confirmation and quantity selector:

| Combined Hull | Hull service | Rate / limit |
|---|---|---|
| Below capacity | Repair Hull | 1 Salvage/Hull, up to capacity |
| At/above capacity but below capacity +10 | Install Ablative Plating | 2 Salvage/point, up to +10 |
| Capacity +10 or higher | Ablative Plating Full | Disabled; no further purchase |

`RepairRules` contains rates and shared quantity/cost calculations. State validates
amount, funds and confirmation revision before spending; successful transactions
consume that revision. Field UI clears its selected amount after confirmation, so
repeated signals cannot repeat the same purchase. Station availability, escalating
production prices and other services are unchanged. Post-battle repairs cost **2 Salvage/Hull**, matching field repairs; station repairs remain **1 Salvage/Hull**.

### Plating handoff and the agreed PoI rule

There is still **one Hull integer**, with no separate armor stat. `begin_battle()`
copies its full value to the board, including purchased plating. `sync_battle()` still
caps carried Hull, both when the result is recorded and on return after optional
repairs. Destruction victory, Systems Failure and successful EMP Pulse therefore
all discard leftover plating. Returning to ship selection starts no new expedition
until confirmation; it does not carry the old expedition's plating into a fresh run.
Combat damage, card repairs and FTL disruption calculations are unchanged.

Neutral noncombat outcomes no longer clamp combined Hull down to capacity; they retain
plating until battle. Positive PoI Hull repairs cannot add plating or erase existing
plating. **Clarified design choice:** negative PoI Hull outcomes reduce the combined
Hull value and can consume plating. For example, 35/30 −3 becomes 32/30 (30 permanent
Hull +2 plating). Preserving 27 permanent Hull alongside 5 plating cannot be encoded
by the existing `min/max` formula, and no extra layer/bookkeeping was introduced.

### Hull warning Inspector controls

On the root **Expedition** node in `scenes/expedition.tscn`, the **Hull warning** group
exposes:

- `hull_pulse_period`: **1.45 seconds** per soft double beat and rest.
- `hull_pulse_scale`: **1.03** maximum visual scale (no container resizing).
- `hull_pulse_intensity`: **0.22** maximum red tint blend.

Only a damaged, surviving ship's Hull button pulses on the system screen, even with
zero Salvage. Full Hull stops and resets the effect immediately; plating uses amber
without a pulse. Encounter/combat HUD behavior is unchanged. The lightweight update
uses one phase accumulator and no per-frame Tween allocation.

Focused checks: `field_repairs_test.gd` covers all six ships, rates, limits, duplicate
transactions, noncombat retention and the three surviving battle result paths.
`field_repairs_ui_test.gd` covers the existing popup, pointer/emulated touch, pulse
reset, immediate HUD refresh, same-slot station transitions and the original grid.
Its rendered mode captures 1280×720, 1680×720, 960×540 and 686×384. Emulated input and
desktop rendering do not establish physical Android behavior/performance.

### Repair previews

Field, post-battle and station selectors share `scripts/ui/repair_preview.gd`: current Hull → resulting Hull, a red current-Hull bar with a green repair segment (amber for plating), and Salvage before → after with total cost and unit rate. Selection is preview-only until Confirm. Minus/plus on the result screen select individual Hull points, capped by `floor(Salvage / 2)` and missing capacity. `RepairRules.RESULT_SALVAGE_PER_HULL` controls its 2:1 rate. Combat repair cards are unchanged.
