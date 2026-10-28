# Future expansion boundaries

These notes describe extension points, not implemented mechanics.

- Battle location: NavigationState owns the authoritative player position, including the resolved interception point, before ExpeditionState prepares the existing battle. Future location checks can read that position at battle setup and pass modifiers through the established combat pipeline. World-space regions should remain separate from combat rules.
- Enemy movement: DefenseState owns the unit records and advances movement; target_for selects the current destination independently, currently always the homeworld. A future policy may use unit data and centralized tuning without putting decisions in the map renderer.
- System support: ExpeditionState owns expedition-wide resources and progression, while DefenseState and generated encounters are replaced on the next system generation during FTL. A future system-scoped effect belongs with system state and should supply any combat modifiers at the existing battle setup boundary. PoI rewards are resolved in gameplay, not presentation.

No hazards, alternate enemy policies, boosters, turrets or currencies are introduced here.
