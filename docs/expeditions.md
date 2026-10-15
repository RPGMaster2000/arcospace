# Star systems and expedition economy

## Playing the prototype

Choose a ship and **Begin Expedition** to open the system list. There is no mandatory opening battle: choose any encounter and charge the interstellar FTL Drive. After a battle victory (including Emergency Jump), the existing result screen offers repairs and **Star System**, returning to the list. Battles and PoIs can be visited in any order. Completed entries are disabled.

Each system has six encounters, targeting 3–4 ordinary PoIs, 0–2 hazardous PoIs and 1–2 enemies. The FTL Drive requires **PoI count + 1** charge. Completing a PoI grants +1; defeating **or escaping** an enemy grants its profile reward (standard 1, elite 2, boss 3). Wormhole outcomes may add extra charge. Rewards are single-use, and travel charge resets in each new system. Escape grants no combat Salvage.

Once charged, jump or continue exploring. Pending card/resource/production choices must be resolved first. Emergency Jump retains the original combat charging and disruption mechanics; it is distinct from interstellar FTL Drive progress. If a PoI has no affordable, unlocked approach guaranteed to preserve at least 1 Hull, a navigation survey can complete it for its normal charge, forfeiting loot and imposing −1 Reactor next battle. This covers broke outpost visits and dangerous debris fields at 1 Hull.

A PoI is a single visit: select one of its four approaches/services, resolve any choice, then Continue. You can back out before committing. Each approach shows requirements, cost, success/failure probabilities, and exact rewards/penalties.

Run state is held in memory for this prototype, not saved to disk. New Expedition, returning to ship selection and starting again, or closing the game resets it. Ship selection, permanent Hull, Salvage, acquired card weight and upgrades persist across encounters and charged system jumps. Battle resource stockpiles and combat-only production improvements reset.

## Godot Inspector tuning

| Open in FileSystem | Inspector fields |
|---|---|
| `encounters/expedition_rules.tres` | PoI library, encounters per system, category counts/weights, enemy registry, resource-victory Salvage, survey penalty, exhausted-upgrade fallback, debug seed |
| Any ordinary/hazardous `encounters/*.tres` | Title/description; expand **Approaches**, then any of the four approach resources |
| Approach resource | Title, required production, minimum production (default 3), Salvage cost, success chance, Success and Failure |
| Success / Failure resource | Blurb, Salvage, permanent Hull, Next Battle dictionary, card reward/minimum tier, upgrade reward, resource choice, production choice, extra interstellar FTL charge |
| `cards/*.tres` | Cost/effects/description/tier, Upgrade Cost Reduction (default 1), Max Upgrades (default 3) |
| `ships/wayfarer.tres`, `specter.tres`, `bastion.tres` | Starting stats and production; no ship names are used in approach eligibility |
| `scenes/expedition.tscn` root | Rules resource used by the run |

Production names in code and resource dictionary keys map to the existing game:
- `synthesizer` = Fabricator, `reactor` = Reactor, `quarters` = Hangar.
- Next Battle accepts `materials`, `energy`, `crew`, `shields`, those three production keys, `emergency_jump_charge`, and `emergency_jump_offline`.
- Use positive amounts for bonuses, negative for penalties. `emergency_jump_offline` is a positive number of initial player turns without charging/warp.
- Immediate `hull` is signed and capped between zero and ship capacity. Fatal PoI damage ends the expedition. Outpost repair never creates Ablative Plating.
- Each outcome should have a positive reward. Card/upgrade/resource-choice/production-choice are mutually exclusive choice types per outcome; immediate Salvage/Hull and temporary modifiers can accompany any one.
- Probabilities are 0–1. Both outcomes must be authored even for guaranteed approaches (the supplied resources do this).

The strongest bonus and strongest penalty are stored separately per attribute, and their net amount applies to the next battle. They do not add repeatedly: +3 then +5 Energy becomes +5, while a −3 Energy penalty remains separately and produces a net +2. Production/resource results clamp to zero before the normal first-turn income. Temporary modifiers survive PoIs and system jumps, then are consumed once at battle initialization. Permanent outpost production upgrades do accumulate. PoI requirements use ship starting production plus permanent upgrades, excluding next-battle boosts and combat-only upgrades.

Emergency Jump charge is capped at the selected ship's requirement. It is granted before the existing first-turn charge tick. An offline penalty suppresses that tick for exactly the specified initial turns.

## Salvage and card progression

Default combat Salvage: standard destruction **10**, elite **20**, boss **30**, resource victory **6**, Emergency Jump **0**. Enemy profiles edit destruction Salvage and FTL independently. Existing tactical (+5 starting Materials/Energy/Crew) and strategic (+10 Shields) bonuses remain, joining the same strongest-per-attribute pending modifiers. The victory-screen repair service remains one Salvage per Hull, with its existing adjustable spending control.

Outposts offer exactly the four requested services, one per encounter: 5 Salvage/5 Hull; 4 Salvage/+5 resource next battle; 8 Salvage/card; 12 Salvage/+1 expedition production. Full-Hull repair is locked; partial repairs still cost 5 and cap at capacity.

All card rewards offer **three distinct library cards** and allow one selection, including Engineering Recovery (the later temporary-selection requirement takes precedence over the earlier two-card table entry). Boarding teams offer Tier 2 or better only. Tiers display as Common/Uncommon/Rare; no new rarity mechanics were introduced.

The existing library is already the entire base draw pool. Acquisition therefore adds a weighted entry to the **shared player/enemy pool** for this expedition, rather than removing or replacing a card. The original six-card hand, maximum two identical cards, Tier 2 opening lock and one-per-tier hand restriction remain. Tier restrictions still apply to acquired cards.

An upgrade reduces one card's resource cost, with a floor of one and a default maximum of three upgrades. It affects all player draw entries of that card using a private resource copy; enemy cards and shared assets are unchanged. Upgraded and original copies share an identity for hand limits. If no card can be upgraded, research grants 4 Salvage instead (editable).

## Restoration balance

Effects and Ablative Plating behavior are unchanged. Hull restored above capacity still absorbs damage first and is discarded between battles.

| Card | Old cost | New cost | Effect |
|---|---:|---:|---|
| Shield Plating | 3 | 3 | +4 Shields |
| Shield Array | 6 | 4 | +8 Shields |
| Shield Recharge | 5 | 3 | +6 Shields |
| Hull Patch / Hull Nanobots | 5 | 7 | +5 Hull |
| Hull Overhaul | 10 | 10 | +8 Hull |
| Structural Reinforcement | 7 | 6 | +5 Shields, +2 Hull |
| Emergency Refit | 15 | 20 | +14 Hull, +8 Shields |
| Aegis Overcharge | 15 | 16 | +20 Shields, +6 Hull |
| Damage Control | 15 | 23 | +18 Hull, +6 Shields |
| Cataclysm Protocol | 20 | 26 | 18 damage, +15 Hull |

Basic shield restoration is substantially cheaper per point than persistent Hull restoration. Mixed high-tier effects retain a modest efficiency discount; the damaging/healing Cataclysm also pays more for its persistent repair benefit.

## Verification

Run with Godot 4.7.2:
```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/ftl_progression_test.gd
godot --headless --path . --script tests/expedition_test.gd
godot --headless --path . --script tests/expedition_ui_test.gd
```

The expedition test forces both branches of every approach and checks seeded generation, non-sequential visits, jumps, costs/rewards, Hull/plating, threshold requirements, modifier consumption/clamps, FTL caps/offline duration, card choices, shared weights, isolated upgrades, upgrade limits/fallback, and live battle/victory/list transitions. UI checks include actual button selection and 1280×720, 1560×720 and 960×540 windows under the existing canvas scaling.

Run the UI test with a rendering driver (for example `--rendering-method gl_compatibility`) to also write screen captures under `.godot/testlogs/`. It uses the game's existing Godot controls and touch-friendly scroll containers, with no platform-specific dependencies. Physical Android device verification remains necessary.

Existing combat, AI, FTL, ship, victory, card, repair, and presentation tests are retained. The combat-modifier test now uses the existing configured Nebula step instead of its stale literal, and follows the new setup→expedition→battle hierarchy. No Nebula gameplay or export workflow changes are included.

For debugging: set Rules **Debug Seed** to a nonzero integer. Systems, card offers, and PoI rolls repeat for the same sequence of choices; each approach logs seed, system, encounter, approach, roll and success. Combat retains its existing independent randomness.

## Quick balance references

- [Ships](balance/ships.md)
- [Cards](balance/cards.md)
- [Battle modifiers](balance/battle_modifiers.md)
- [PoIs and generation](balance/pois.md)

Regenerate from current Resources with `godot --headless --path . --script tools/generate_balance_docs.gd`. The progression test simulates 10,000 systems, including randomized completion orders, all-escape routes, low Hull, repeat results and remaining obtainable charge. It tests progression availability, not guaranteed combat survival.
