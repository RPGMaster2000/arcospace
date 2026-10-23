# Replaceable sound effects

Arcospace's initial palette has **24 events / 38 files**, including three variants
for seven frequent events. Sources are **48 kHz, mono, signed 16-bit PCM WAV**,
1,483,912 bytes total (1.42 MiB). Import settings retain lossless PCM, disable
normalization and looping, and work with ordinary Godot audio imports on Windows,
Android and Web. No runtime synthesis, Python, external services or plugins.

## Replace or tune a sound in Godot

1. Import a WAV or OGG into the project (turn off looping for these one-shot cues).
2. In **FileSystem**, open **`res://resources/audio/sound_catalog.tres`**.
3. In **Inspector → Events**, expand the named event Resource, e.g. `shield_hit`.
4. Under **Streams**, replace the existing AudioStream reference(s). Use a single
   stream for one sound, or several for authored variations. Godot's AudioStream
   Inspector provides its normal playback preview. Save the catalog with Ctrl+S.

The event's **Enabled**, **Volume Db**, **Pitch Scale**, **Pitch Variation**,
**Replay Interval**, **Concurrency Limit**, **Priority**, and **Replay Group** are
all used by playback. Pitch Variation is a symmetric fraction: 0.025 = ±2.5%.
Leave it zero on recognizable alerts, EMP readiness/fire and result cues.
To disable a cue, uncheck Enabled; empty/null Streams are also safely silent.
Keep Event Id stable; presentation requests it rather than an asset filename.
Reassign references before deleting old files to avoid Godot's missing-resource
import diagnostics. A missing catalog/event or empty stream list does not crash
playback. No combat, AI, ship, expedition-state or navigation rule changes are
needed to replace the entire library, including with OGG or professional assets.

## Event map

All initial filenames are `<event>_01.wav` in `assets/sound/sfx/`. A **3** below
means `_01`, `_02`, `_03` are available; otherwise the event has one stream.

| Event | Presentation hook | Variants |
| --- | --- | ---: |
| `card_select` | Card emphasis changes to selected on press | 1 |
| `card_play` | CardMotion arrives at the resolution cue; immediate if motion disabled | 3 |
| `card_discard` | CardMotion scanner dissolve starts | 1 |
| `materials_gain` | BattleEffects committed Materials increase | 3 |
| `energy_gain` | BattleEffects committed Energy increase | 3 |
| `crew_gain` | BattleEffects committed Crew increase | 3 |
| `resource_drain` | BattleEffects hostile loss, excluding ordinary card payment | 1 |
| `production_gain` | Production increases; also Systems Failure recovery | 1 |
| `production_loss` | Production decreases/sabotage | 1 |
| `shield_hit` | Committed shield loss | 3 |
| `shield_break` | Shield falls from positive to zero | 1 |
| `hull_hit` | Committed Hull loss, including staged overflow at its impact | 3 |
| `hull_repair` | BattleEffects committed Hull increase | 1 |
| `ship_destroyed` | Hull crosses zero, replacing that ship's ordinary hit cue | 1 |
| `systems_failure_warning` | SystemsFailureDisplay enters active failure, once per activation | 1 |
| `systems_failure_defeat` | Result revealed with Systems Failure cause, either ship | 1 |
| `emp_charge` | Displayed EMP charge increases, while online; excludes initial HUD | 1 |
| `emp_ready` | EMP becomes available, including return online | 1 |
| `emp_fire` | Successful escape first appears in the HUD | 1 |
| `ship_departure` | Cinematic alignment completes and engine spool begins | 1 |
| `ui_select` | Shared styled buttons keyboard/controller focus; ship navigation, including keyboard | 3 |
| `ui_confirm` | Shared styled button press; ship selection, settings, expedition/result actions | 1 |
| `upgrade_acquired` | Accepted card reward, card upgrade or attribute choice | 1 |
| `result_reveal` | First visible ordinary victory result, under victory music | 1 |

BattleEffects reuses actual committed snapshots: shield fracture and deferred Hull
impacts retain their existing order. It owns these cues alongside its enabled
visual effects; turning off that developer presentation component also skips
its delta sounds. CardMotion still sounds when its animation is disabled.
Repeated HUD updates do not replay status/result cues. There are no countdown
beeps, per-frame sounds or cues based on predicted damage.

## Playback, volume and mixing

- Existing **Master** output now has independent **Music** and **SFX** buses.
  Settings → Audio contains the existing Music toggle plus **Music Volume** and
  **Sound Effects Volume (0 = mute)**. Values are stored alongside existing
  preferences in `user://music.cfg`, preserving other keys. The Music toggle
  retains its pause/resume semantics; Music Volume does not restart a track.
- Music keeps its original player, eight MP3s, randomized battle choice,
  track-specific gains, tier priority, one-shot victories and title fades.
  New volume gain is applied on its bus, leaving those player gains intact.
- The Sfx autoload owns exactly **12 reusable AudioStreamPlayers**. No player
  creation in `_process`, no runtime waveform generation and no unbounded voices.
  Its explicit static gateway supports @tool scripts and preloaded test scenes;
  there is no tree-wide signal scanner or generic event bus.
- Every request has a presentation-node scope. `tree_exiting` immediately stops
  that scope's voices, including owners freed on transition. Shared UI cues use
  the current screen scope so rebuilding a panel does not truncate its click. Finished voices
  release their streams. Playback duplicates the lightweight stream wrapper and
  forces WAV/OGG/MP3 one-shots without modifying catalog resources or copying PCM. Muting SFX stops current effects; unmuting cannot revive
  old impacts. Audio remains controllable while Settings pauses gameplay.
- Low/medium/high priority is editable per event. High-priority Hull impacts,
  destruction, EMP discharge and failure alerts can preempt lower-priority
  voices. Equal/higher-priority voices are retained; a full protected pool drops
  new requests. Normal event limits are 1–2 voices, with a global hard bound of 12.
- Minor resource gains/drains share `minor_resources` replay protection (160 ms),
  so a simultaneous multi-resource update gives one quiet cue. Other events keep
  their own cooldowns. The default traversal chooses Materials when all three
  arrive together; a standalone Energy/Crew gain retains its own identity.
- Source synthesis targets -22 dBFS RMS with a -7 dBFS peak ceiling and short
  endpoint fades. Minor resources get -5 dB catalog trims, charge/result -3 dB.
  UI navigation/confirmation use -11.0206 dB trims (half their initial amplitude).
  SFX bus headroom is -8 dB before the user gain. An SFX-only limiter provides a
  -1 dB ceiling for dense overlap, without changing soundtrack dynamics.
- Variant selection and mild pitch variation use a dedicated
  RandomNumberGenerator; they never consume global or combat RNG.

## Regeneration and checks

`python3 tools/generate_sfx.py` regenerates only the procedural source WAV files
and their manifest using NumPy and deterministic per-event seeds.
`python3 tools/generate_sfx.py --check` validates PCM metadata, duration, RMS,
peak bounds, endpoint samples and hashes. Godot WAV import normalization is off,
so the designed gain differences survive import. Remove this tool/manifest after
professional replacement if desired; runtime has no dependency on either.

`tests/sfx_test.gd` (253 checks) is discovered by the shared regression runner. It covers every
mapping/import, live stream replacement, missing/null/disabled definitions,
replay grouping, bounded overlap, priority, scene cleanup, independent buses,
unchanged gameplay RNG, card resolution cues, stat deltas, status edges, upgrade,
menu/departure and result presentation. A fresh-process companion
`tests/sfx_preferences_probe.gd` verifies persisted bus gains at startup.
For the same test in an exported PCK, pass `-- --probe-pack /absolute/path/to/game.pck`
after `--script res://tests/sfx_test.gd` so its child process uses the same pack.

Run `python3 tools/run_regressions.py --godot /path/to/Godot` and the existing
Python runner tests as described in [regression_testing.md](regression_testing.md).
Dummy audio validates the engine's playback/import path but cannot assess audible
mixing, speaker quality or device latency. Actual Android/Windows listening is a
separate manual alpha check; PCM WAV compatibility is not a device-playback claim.

## Deliberately shared or omitted cues

No bespoke sound for each battlefield modifier: committed asteroid/shield/Hull
changes already use the combat palette; ion-modified cards use normal card cues.
No passive menu refresh/automatic focus-loop sounds, repeated countdown alarm,
shield recharge cue, separate Systems Failure recovery asset, defeat stinger or
travel-map engine loop. Recovery shares production_gain; ordinary losses leave
room for the existing result presentation. Skipped departure cinematics use a
short confirmation rather than an invisible long engine sequence. Victory SFX
are deliberately quiet and do not control music priority.

Code ownership: three small audio scripts (event Resource, catalog Resource,
playback), one catalog and one bus layout. Existing presentation files contain
stable event requests; authoritative combat/expedition-state code is unchanged.

## Changed files

- `assets/sound/sfx/`: the WAV files listed above, their 38 `.wav.import` settings,
  and `manifest.json`.
- `scripts/audio/sound_event.gd`, `sound_catalog.gd`, `sfx.gd` (and script UIDs);
  `resources/audio/sound_catalog.tres`; `default_bus_layout.tres`; `project.godot`.
- Presentation hooks: `scripts/battle_effects.gd`, `card_motion.gd`, `card_view.gd`,
  `battle_setup.gd`, `expedition.gd`, `presentation/main_menu_3d.gd`,
  `ui/battle_hud.gd`, `ui/systems_failure_display.gd`, `ui/encounter_presentation.gd`.
- Preferences/UI: `scripts/music.gd`, `scripts/ui/settings_menu.gd`.
- Development: `tools/generate_sfx.py`, `tools/test_generate_sfx.py`,
  `tests/sfx_test.gd`, `tests/sfx_preferences_probe.gd` (and test UIDs), this document,
  and the cross-reference in `docs/DEVELOPER_GUIDE.md`.

No card, ship, enemy-AI, combat-rule, authoritative expedition-state or soundtrack
asset file changed. No new third-party dependency is needed for play or export.

## Implementation validation (2026-10-23)

Validated with the repository-pinned **Godot 4.7.2**, using Dummy audio:

- Clean import of a separate checkout with no `.godot` cache: no engine/script
  errors. All 38 WAV imports use lossless PCM.
- Source and Android-exported PCK: **253 SFX checks, zero failures** in each,
  including a fresh process restoring saved volumes. PCK export/import is verified;
  this is not an APK or Android device playback test.
- Offline integrity and shared runner: **10 Python tests passed**; the generator's
  `--check` also verifies every source WAV and manifest hash.
- **All 83 shared regression scripts passed**, counting the corrective/extended
  reruns below; the separate import run also passed. Early audio shutdown resource errors were
  corrected and all four affected tests rerun successfully. Three unchanged
  sampling tests exceeded the runner's 120-second default; they passed when given
  360 seconds: Card Progression (151.7 s), PoI Reward Overhaul (292.0 s), and Power
  Allocation (145.6 s). No gameplay/test-runner timeout policy was changed.
- Some tests retain Godot ObjectDB shutdown warnings, recorded separately by the
  shared runner. These are not hidden or treated as proof of clean engine teardown.
  Scope-exit tests verify zero playing SFX voices after the presentation owner exits.
- Whole-track FFmpeg volume checks: `battle1` source RMS/peak -24.3/-7.1 dBFS;
  `victory_normal` -18.0/-1.7 dBFS. Existing Music gain remains -12 dB. Default
  untrimmed SFX RMS is approximately -30 dBFS after bus headroom, while the result
  accent is approximately -33 dBFS. This checks levels against the real tracks;
  RMS is not perceptual LUFS or a substitute for listening.

Actual Windows/Android speaker/headphone playback, device latency and a new APK
were not tested. The standard runner excludes its existing render-only enemy-model
check; no additional rendered screenshot session was performed for this audio pass.


## UI feedback polish

Pointer hover is silent. Pointer focus does not add a navigation sound on top of
a click. Keyboard/controller focus keeps its navigation cue. Confirmation waits
until the button's callbacks finish; if a more specific action cue (e.g. an
upgrade) was played for that input frame, its generic click is omitted. Deferred
requests use weak references so closing a screen cannot retain its controls.

Tactical preview highlights are feathered additive halos owned by each target
Label: after its icon/badge graphics and behind its text. Gains use green/teal,
losses red/orange and uncertainty amber, with resource-family tints and resource
colors for payment. Existing +/−/?/$ symbols still distinguish meanings. All
halos are removed on dismissal, target changes and scene exit.

The title/selection Reference button is sized from its themed minimum width and
placed to the left of Settings with a 12-pixel gap. Compact layouts also reserve
header space. The halo shader is `shaders/tactical_target_glow.gdshader`,
owned by `scripts/ui/tactical_preview.gd`. `tests/ui_feedback_test.gd` checks
click/focus cues, half-volume
trims, target glow ownership, cleanup and both menu phases at four landscape sizes.
