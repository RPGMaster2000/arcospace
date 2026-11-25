# Tier 2 and Tier 3 synergy balance

The [card reference](cards.md) lists the 27 new cards, their costs, rarity, Power Allocation categories and three complete effect sets. All requested card values, initial draw rates, unlock rounds and prices were retained.

## Ship affinities

| Ship | Natural build | Starting points | Rare options |
|---|---|---|---|
| Ganymede | Industrial conversion | Industrial Conversion, Automated Assembly Line, Kinetic Reclamation | Industrial Supremacy, Siege Assembly |
| Thunderbolt | Shield breaking and aggression | Execution Beam, Reactor Cascade, Ion Interdictor | Overload Sequence, Siege Assembly |
| Titania | Attrition and recovery | Reactive Foundry, Emergency Fabrication, Recovery Specialists | Bastion Foundry, Last Stand Command |
| Callisto | Shield economy | Shield Dividend, Capacitor Transfer | Aegis Protocol |
| Orion | Boarding and reserve denial | Precision Boarding, Deep Cover, Shield Boarding, Counterintelligence Cell | Total Infiltration |
| Endeavour | Adaptive economy | Supply Chain Relay, Reserve Equalizer, Logistics Officers | Tri-Vector Reactor, Fleet Quartermaster |

All ships can obtain these cards. The six starting pools and ship signatures stay the same.

## Deterministic combat study

Godot 4.7.2 ran 100 matches per ship for each of four configurations, plus a 100-match Titania control. Matched seeds 50000–50099 covered Siege Monitor, Marauder Vanguard, AXIOM Command Nexus and Choir Leviathan, cycling through the full modifier catalogue. Within each group, 48 battles included valid Warzone preparation packages on both sides. The diagnostics use the actual combat, draw, modifier and AI code and disable voluntary EMP escape to compare combat builds.

- **Before** uses the original catalogue, four Tier 2 acquisitions and one prototype Tier 3. It approximates the pre-expansion 10% Tier 3 player rate from round three. Its random roll intervals follow the current implementation.
- **Drafted** takes the first option in four normal seeded drafts and the reserved option in one rare draft. It uses the expanded enemy pools.
- **Affinity** takes five cards from the ship's affinity list and uses the same enemies and progression as Drafted.
- **Late** carries three Tier 3 and two Tier 2 identities, all upgraded twice. It uses System 8 enemies and one more permanent production point than the System 5 configurations.

Each configuration has 34 owned identities. The first three use a single permanent production increase and upgrade eligible acquisitions once. Opponent mix, limited player upgrades and AI policies make these stress comparisons rather than estimates of human campaign win rates. The model samples one rare acquisition per player loadout and does not estimate how often a campaign reaches a rare source. The new draw policy changes seeded card sequences.

| Ship | Before win rate / rounds | Drafted | Affinity | Late |
|---|---:|---:|---:|---:|
| Endeavour | 24% / 33.8 | 26% / 34.5 | 8% / 36.0 | 5% / 36.4 |
| Thunderbolt | 5% / 21.9 | 12% / 25.9 | 11% / 18.9 | 17% / 21.2 |
| Titania | 22% / 45.9 | 27% / 37.1 | 16% / 56.0 | 15% / 55.9 |
| Ganymede | 6% / 29.2 | 7% / 36.2 | 8% / 30.6 | 7% / 34.1 |
| Callisto | 7% / 39.9 | 15% / 41.6 | 4% / 47.8 | 4% / 46.4 |
| Orion | 11% / 22.1 | 14% / 28.7 | 16% / 24.4 | 12% / 25.6 |

### When Tier 3 cards appeared

Rates are per battle, including battles that ended before the listed round. “Affordable” is the share of turns holding a Tier 3 card on which it could legally be played.

| Configuration | Reached round 6 | Drawn by 8 | By 10 | By 15 | Played a Tier 3 | Drew but played no Tier 3 | Affordable while held |
|---|---:|---:|---:|---:|---:|---:|---:|
| Before | 96.7% | 48.3% | 54.7% | 63.5% | 45.0% | 30.0% | 35.1% |
| Drafted | 96.5% | 10.5% | 21.0% | 33.3% | 42.0% | 14.8% | 28.4% |
| Affinity | 96.3% | 11.0% | 20.5% | 32.2% | 43.7% | 11.0% | 31.6% |
| Late | 97.0% | 11.2% | 20.7% | 31.8% | 47.5% | 9.5% | 35.1% |

Drafted runs won 101 of 600 matches, compared with 75 before the expansion. Hull accounted for 92 of those 101 wins and Systems Failure for nine. Warzone-prepared drafted runs won 49 of 288 and the other drafted runs won 52 of 312. These are different seeded weather and matchup samples, so they do not isolate the effect of preparation.

All 27 new cards saw play. Reactor Cascade was least frequent in these loadouts and was played 39 times out of 43 draws. Capacitor Transfer had 64 plays on 159 draws, reflecting the extra Shield payment requirement. Total Infiltration was played 158 times and Industrial Supremacy 360 times across the expanded configurations and Titania control. Both consume the turn and need substantial reserves. Infiltration's actual transfer is limited by each opposing reserve. The current game awards combat victories through Hull destruction and Systems Failure. High reserves or over-repair cannot directly win a match. No global victory or repair changes were needed.

Titania's affinity build reached the 100-round diagnostic limit in 37 of 100 matches. The same loadout with Fortress Protocol and Siege Lance replacing the two new rare recovery cards reached the limit in 30 of 100. The average fell from 56.0 to 51.3 rounds and both won 16 matches. The sample suggests a possible pacing cost for stacked recovery, with no evidence of a dominant win strategy. The initial values remain unchanged. Long Titania fights and early access to expensive rare cards remain useful cases for manual playtesting.

Ion, Metal and Psionic Storms scale matching numeric effects inside branches and leave conditions and sacrifices fixed. Temporal Rift boosts Tier 2 only. Solar Flare checks the live disabled Shield state and blocks Shield sacrifice. Nebula retains the existing miss rules for combat effects. Warzone preparations modify battle-local stats before the cards read them. Saved pending rewards keep their committed identities and discovery draft sampling uses a separate deterministic seed.

### Reproduce

```sh
godot --headless --path . --script tests/card_synergy_balance.gd -- /tmp/synergy.ndjson
godot --headless --path . --script tests/card_synergy_balance.gd -- /tmp/titania.ndjson 2 recovery_control
```
