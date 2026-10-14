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
