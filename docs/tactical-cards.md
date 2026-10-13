# Tactical card effects

Cards 36–44 implement the discussion's exact costs, families and effects. Cataclysm Protocol and Emergency Reserves are Tier 2; the other seven are Tier 1. Tier chances and the one-Tier-2-per-hand rule remain in `card_hand.gd`.

Edit each `.tres` in Godot's Inspector to tune Cost and Effects. Description is display text and must be updated when you change Effects.

| Effect key | Inspector value | Result |
|---|---|---|
| random_gain | 2 | Gain that many of one of the three resources, equal odds |
| random_gain_other | 20 | Gain that many of one resource excluding the card family, equal odds |
| random_gain_range_other | {min:12, max:15} | Pick another resource equally, then an inclusive uniform amount |
| production_other | {type:"reactor", production:1, resource:5} | Increase Reactor and Energy; works only if Energy differs from card family |
| shield_collapse_below | 10 | Remove all enemy shields when current strength is strictly below 10 |
| self_damage | 4 | Direct damage to acting ship's hull, bypassing its shields |

Valid production types: synthesizer→materials, reactor→energy, quarters→crew. All effects work for either ship. Play Again uses the existing card property and grants no extra income or FTL charge.

Self damage is applied even if a Nebula attack misses; it is an unavoidable cost. Other mixed-card effects retain the existing miss behavior. Shield Collapse counts as an enemy combat effect for Nebula, and its threshold remains 10 under Ion Storm. Ion scales numerical gains, self damage and random-range bounds; piercing fraction and conditional thresholds stay unchanged. Its preview shows adjusted amounts/ranges before play.

AI simulation uses copies and never samples real combat RNG. Random bonuses are omitted from conservative win prediction; the AI cannot assume a lucky resource roll. It also avoids fatal self-damage when selecting non-winning moves. Gameplay randomness uses an independent generator or the encounter's passed generator, and is testable with a seeded generator.
