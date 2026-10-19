extends Resource

# RESPONSIBILITY: Store the shared draw multiplier; CardHand applies it only to player draws.
# Static battle configuration; the player hand snapshots this value at battle start.
## TUNE: Matching cards' relative weight inside the already eligible rarity bucket.
@export_range(1.0, 10.0, 0.1) var matching_draw_weight: float = 2.0
