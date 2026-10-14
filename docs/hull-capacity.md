# Hull capacity and ablative plating

Hull remains one integer per ship. Permanent Hull is min(Hull, capacity); Ablative Plating is max(Hull-capacity, 0). Starter capacity defaults to 35, starting Hull remains 30. Damage still passes through Shields before subtracting Hull, so excess plating is consumed automatically before permanent hull. Repairs can grow Hull without a cap during combat.

In Godot open scenes/board_3d.tscn, select Board3D, and edit Player Hull Capacity in the Inspector. Enemy Hull Capacity is independently editable. These exported properties live in scripts/board.gd and carry through Continue. Larger capacity does not change starting Hull; edit Player Hull separately if desired.

Continue transfers at most the player's configured capacity. Plating does not survive; the next battle's starting hull snapshot uses the capped value. Post-battle salvage repairs still respect their existing 35-hull ceiling and cannot exceed a smaller ship capacity. Victory bonuses are based on the finished combat state as before.

FTL disruption considers only actual permanent Hull lost. Asteroids compare permanent Hull before/after; cards use attack-local damage reports so healing in mixed-effect cards cannot obscure which Hull layer was damaged. Plating-only hits yield zero FTL risk. Existing probabilities and disable duration are unchanged.

scripts/hull_bar.gd draws the compact red/amber bars beside hull status. The red capacity marker separates permanent Hull from plating, and an amber label gives the exact excess amount. The combined bar fits available width by scaling its denominator to max(capacity,Hull); this imposes no gameplay cap. Inspector colors are adjustable. scenes/board.tscn contains both bars and the capacity label font size. Ship damage markings use permanent Hull in scripts/board_3d.gd.

Relevant checks: hull_capacity_test.gd, salvage_test.gd, victory_rewards_test.gd, encounter_continue_test.gd, tactical_cards_test.gd, ftl_test.gd.
