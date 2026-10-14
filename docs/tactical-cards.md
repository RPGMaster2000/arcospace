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

Balance revision: Energy Surge costs zero, grants 3 Energy and Play Again. EMP costs 8 and drains 7 of each resource. All eight Tier 2 costs multiplied by 1.25 and rounded upward. Phase Lance (10) and Antimatter Lance (20) retain 50% piercing: half direct, remainder regular, unblocked regular damage also reaches hull. With no shields, their full damage reaches hull.

Shield Collapse now uses shield_collapse:{threshold:10,chance:0.5,self_damage:10}. It always removes all target shields. At original target shields ≥10 there is a 50% regular self-damage backlash. Below10 it is risk free. The old shield_collapse_below key remains supported for custom cards. Ion scales damage amounts but not threshold or chance. AI assumes backlash for conservative survival checks without sampling RNG.

Desperate Conversion costs 9 Crew and uses self_damage_regular:8 (Shields→Plating→Hull) while still granting20 Materials or Energy. The original self_damage key continues to bypass shields for other cards.
