# Ten-battle progression prototype

A normal, non-EMP win against a standard enemy offers the existing card-upgrade allowance or one acquisition from up to three distinct, unowned advanced cards. The offers include both Tier 2 and Tier 3 when both are available. At the 34-card limit, victory acquisitions use the existing replacement flow. A legacy deck above the limit keeps its cards. Open the deck to remove excess identities explicitly. The outpost offers up to six cards and requires free capacity before a purchase. Choosing an offer only previews it. Confirming revalidates the offer and spends Salvage while granting the card.

Victory and outpost offers can contain the eight prototype cards. Ordinary PoI rewards and the default enemy draw pool retain the original card library. The prototype cards use their authored base values. Emergency Refit Mk II keeps the existing Emergency Refit’s identity and rules intact. Tier 3 draws during player expedition combat share the existing advanced-card round gate. Tier 3 has a 10% draw chance when eligible and owned. Hull repair follows the existing in-battle overflow and expedition Hull rules.

Resource Overdrive sits beside the battle controls. Each action specifies its effect and eligible payment resources. It is available once per player turn and uses normal Shield rules. A beam can charge once per eligible fight. It starts appearing from System 2 after four wins, in fights entered after an even number of wins, once the enemy reaches its second turn. Charging replaces that turn’s card play. The next enemy turn fires the beam unless actual Hull damage disrupted it, in which case the enemy skips the entire turn.

Victory offers and outpost offers use separate seeded RNG streams. Pending rewards keep the existing expedition checkpoint. After a prototype combat action, Save & Quit records the last settled player turn plus any committed Overdrive payment, charge or interruption. Resuming during an unsettled enemy action returns to that checkpoint. Battles without prototype actions retain the existing battle-entry resume behavior.

## Reproduce a playtest

In a development checkout, set **Debug Seed** to **717** on [the expedition rules resource](../encounters/expedition_rules.tres). Start a fresh Starfront Defense expedition with the first ship and play through ten card-battle wins using normal map controls. Restore the setting to 0 afterward. Prioritize threats approaching the homeworld and progress through the mothership encounters normally. Try both victory choices, visit a trading outpost when available, and enter a System 2 fight after four or six wins. Keep the enemy alive through its second turn to observe the charge, then try either defending against the beam or hitting its Hull.

Use the focused regression runner with --script ten_battle_progression_test for the deterministic mechanic checks.

During the first playtest, record how often you give up upgrades for a card, when a Tier 3 card first gets played, whether 30-resource Overdrive competes with high-cost cards, and how often you can pierce Shields in time to attempt a beam interrupt. Note whether the 34-card cap prompts interesting replacements and whether outpost cards justify their Salvage cost.
