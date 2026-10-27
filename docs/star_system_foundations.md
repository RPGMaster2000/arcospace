# Star-system UI foundation contracts

This stabilization builds on `dacdaaf` and retains gameplay rules, encounter generation,
combat handoff, interruption positions and the existing v1 save format.

## Ownership

- Expedition owns routing, State commands, persistence and presentation cancellation.
- ExpeditionScreen owns contextual panels, Back, confirmation, view visibility and map geometry.
- StarSystemHUD owns mounting/restoring the existing resource, FTL and utility controls.
  Screen supplies these references once with `bind_controls`, then requests one explicit
  `Mode`: HIDDEN, OVERVIEW or FOCUS. It does not manipulate their parents or visibility.
  HUD retains no screen/controller reference or gameplay State.
- Zoom buttons belong to one map generation. HUD borrows them explicitly, restores them on
  handoff, and releases controls whose original parent was destroyed during map replacement.
  Original parents are weak references, and original minimum sizes/sibling order are restored.
- ResourceBar continues to own resource facts, descriptions and its existing modal callbacks.
  No duplicate widgets, inventory, resource values or gameplay signal connections are created.

For a new star-system view, select the existing HUD mode through Screen's map layout operation.
Do not add a second visibility switch or independently reparent shared HUD controls.

## Reusable tactical views

`TacticalBriefing.configure` updates read-only encounter facts in a stable control tree.
Content, modifier-rule callbacks and responsive styling have separate methods. Reconfiguration
and live viewport resizing retain button/modal identities and keyboard focus. Compact styling
is recomputed when the viewport changes, including crossing the 600px logical-height boundary.
Pursuit retains compact styling and its existing fixed camera.

Future panels should build controls once, update facts explicitly, and reapply typography/layout
on size changes. Resizing must not reroll gameplay RNG, rebuild callbacks or replace active modals.

## Requirements

`State.approach_requirement` is the single evaluator for normal PoI gate precedence:
production, Salvage price, then full Hull. Its detached `ApproachRequirement` contains the gate
kind, attribute, required amount and current amount. `locked_reason` preserves legacy wording.
`ExpeditionText.requirement_text` formats the same facts for compact UI; it never reevaluates
eligibility. Adding a gate requires an explicit contract/formatter/test update.

Locked options still expose only their name and failed requirement. Font size has a 14px floor;
long content wraps and reserves additional height rather than shrinking indefinitely or clipping
the actual gate. Unlocked rewards, probabilities and confirmation behavior are unchanged.

## Layout invalidation

Screen, HUD and encounter tiles queue/coalesce static geometry work in response to resizing or
minimum-size/content changes. Idle screens do not repeatedly copy HUD exclusion regions or
measure every option each frame. Application resume also invalidates safe-area layout.
Map orbit, travel, rotation, heartbeat and other actual animations keep their existing processing.

For new dynamic content, update the existing Control's text/minimum size so normal layout signals
invalidate the relevant view. Avoid a new per-frame fit loop. `layout_invalidation_test` checks both
idle settling and reactions to content/width changes.

## Verification

The headless suite is discovered by `tools/run_regressions.py`. The recurring rendered registry
lives in `tools/run_rendered_regressions.py` and is shared by local runs and CI. It uses the same
bounded process/error/log contract as headless checks, and retains partial summaries on failure.
Headless tests and rendered jobs have separate time budgets. Compatibility covers existing
presentation checks plus the newest HUD/focus suites. Mobile/Vulkan has a smaller smoke,
resize and ownership suite; the smoke verifies the requested renderer without silent GL fallback.

Run an imported checkout locally with a display:

```sh
python3 tools/run_regressions.py --godot godot
xvfb-run -a python3 tools/run_rendered_regressions.py --godot godot --renderer gl_compatibility
xvfb-run -a python3 tools/run_rendered_regressions.py --godot godot --renderer mobile
```

Rendered captures go to `.godot/testlogs`, never tracked historical documentation screenshots.
Documentation image import sidecars are ignored; required source/script UID metadata is tracked.
The superseded secondary enemy-preview component was removed after checking its runtime users.

Save migration and release-pack content selection remain separate future work. This pass does
not rename persistent content IDs, change the save schema, remove exported-startup fixtures,
or claim physical Android performance measurements.


## Verification record for this pass

See [the results](star_system_foundations_results.json) for the exact scope and retained failures.
All 122 headless scripts were exercised. One fresh-process persistence assertion failed during
that run, then passed five isolated reruns without a persistence change. Phase and seed logging
now preserves the preceding successful phases if it recurs; its root cause remains unconfirmed.
The seven relevant Compatibility suites, three Mobile/Vulkan suites, 13 Python checks and
72-check isolated PCK startup passed. Physical Android hardware was not available.
