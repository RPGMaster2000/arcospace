# Starfront Defense v1.1 checkpoint

This is an interim checkpoint, not a release or merge-ready claim. Branch `feature/starfront-defense-v1-1` started from `main` at `63baac0` (the v1.0 merge). Work is local; no v1.1 branch has been published.

Implemented so far:

- Player speed 7 and strategic conversion 1/7; movement and committed PoI, service and battle activity costs share `DefenseState.advance_time`.
- Activity contacts retain unspent strategic seconds in the versioned save until the intercepted battle resolves; the coordinator defers presenting the contact until the existing result/reward flow allows it.
- Four deterministically generated inactive reinforcement identities, first/next countdowns, active/lifetime caps, bounded placement, target cancellation, and version-2 defense-save migration to version 3.
- Analytic pursuit destinations from defense state; 2.5× mothership presentation scale; terminal hostile exhaust and trail cleanup; Back hidden on committed defense encounters.
- Mouse/touch marker holds open the existing encounter panels in a read-only mode, with outside dismissal and drag/pinch cancellation.

Verification completed on the checkpoint working tree: `starfront_quality_test` (28 checks), `starfront_defense_test` (3,538 checks), `starfront_persistence_test` (33 checks), `starfront_interception_test`, and `starfront_inspection_test` passed headless. A Mobile-renderer inspection test and the v1.0 scene flow passed earlier in this pass, before the latest small presentation and save-validation changes. Several scene tests still report existing ObjectDB shutdown warnings.

The broader headless regression run was intentionally interrupted for this checkpoint after 74 passing scripts; no failures were recorded, and `outpost_screen_test` was running. Its partial results are in sibling `starfront-v11-regressions/summary.json`. Full headless, final Compatibility/Mobile/Vulkan rendering, exported startup, Android APK/device checks, and CI remain incomplete. No physical device was tested. Do not call this pass fully verified or merge it based only on the checks above.

Next: review the complete diff, particularly deferred time/contact ordering, legacy version-2 saves (including completed and unresolved-battle states), reinforcement cap and placement over many seeds, and inspection action/input handling. Finish the headless registry, run the registered rendered suites and exported-startup checks, check exact-head CI after publishing if authorized, and fix any failures before making a release commit or preparing the merge. The local v1.1 branch has not been pushed.
