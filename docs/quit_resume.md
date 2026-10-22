# Single-slot Quit & Resume

Arcospace automatically maintains one active expedition at
`user://expedition_save.json`. Continue Expedition is the main menu's primary
action when this file contains a valid active run. New Expedition requires an
explicit abandonment confirmation, then initializes and durably writes the new
run before replacing the current scene. A failed write leaves the old run intact.

## Boundaries and format

`scripts/persistence/expedition_save.gd` owns the explicit codec, validation,
version handling, recovery and disk operations. ExpeditionState has no filesystem
dependency. Its `progress_committed` signal reports completed authoritative
transactions; the expedition controller coordinates saves. Existing typed
BattleSetup/BattleResult contracts remain the combat boundary.

Schema **1** is a small UTF-8 JSON envelope:

```json
{"schema": 1, "payload": "{...JSON checkpoint...}", "sha256": "..."}
```

The payload is a JSON string so its checksum can be verified over the exact bytes
without numeric reformatting during parsing. It contains a monotonically increasing
revision, an `ended` flag, and (for an active run) `expedition` and `battle` objects.
There is no object deserialization, resource-path loading from the file, scene
snapshot, history browser or manual load action. References are checked against
bundled card, ship and encounter registries. Unknown schema versions/references,
invalid shapes, truncated JSON and checksum failures cannot produce a partial run.

The expedition record includes:

- Stable player/enemy/PoI Resource paths, generated encounters, completion and
  charge-awarded flags, resolutions, mandatory bosses, modifiers and system identity.
- Seed, current system, Hull/plating, Salvage, wins, FTL charge/requirement,
  outpost scheduling, purchase count and transaction revision.
- Navigation origin, committed travel destination, chasedown destination/enemy,
  response and interception count. Committed travel resumes without rerolling its
  already-decided interception; a legitimate system jump may still cancel travel.
- Production upgrades, pending bonuses/penalties, removed identities, acquisitions
  and upgrade levels. The owned deck is reconstructed from these ledgers.
- Outstanding reward type, exact offered/pending cards, replacement choice,
  remaining upgrades, identities already upgraded in the event and outcome text.
- Seed **and** state of generation/outcome, station and chasedown RNG streams.
  These 64-bit values are decimal strings, avoiding JSON floating-point loss.

Live combat attributes, hands, animation frames, UI objects and process-specific
result IDs are not serialized. Repair availability and screen controls are rebuilt.

## Transactions and autosaves

Saves follow new-run initialization, system generation, committed travel/arrival,
chasedown responses, PoI/survey outcomes, station purchases, field/result repairs,
card acquisition/replacement/decline, attribute choices, upgrades, battle results
and related persistent updates. Notifications occur after complete transactions,
not inside reward/application helpers. In particular, battle result synchronization
suppresses its inner notification until completion, currency and rewards all agree.
There are no per-frame writes or routine save confirmations.

Save & Quit uses the same checkpoint function, checks success, then returns to the
main menu. Failure shows an error and preserves the live session. Quit Game also
uses this path during an expedition. Desktop close requests save before exit;
Android suspension requests another checkpoint, but ordinary progression autosaves
do not rely on receiving a final background notification. Android Back opens the
existing Resume / Save & Quit settings instead of bypassing this flow.

## Interrupted combat

Before bonuses are consumed or Board is created, the controller durably saves the
pre-entry expedition and a marker containing the encounter index and battle seed.
The normal BattleSetup is then built and carries that seed. Both hands, enemy AI,
EMP disruption and modifier RNGs are seeded before their first combat draw/use.
No generation or encounter-choice RNG is rerolled on Continue.

An unfinished battle restarts from that checkpoint, including the same opponent,
modifier, initial stats, upgraded deck, opening cards and randomization. Hull costs
or penalties legitimately committed before entry remain paid. The settings action
warns: **“Your current battle will restart when you continue.”**

Scene cleanup is explicitly prevented from committing a pending result when
leaving for this checkpoint. This matters for lethal damage waiting on a shield
shatter cue: freeing the scene must not award a phantom victory or death.
Normal battle damage timing is otherwise unchanged.

A definitive result replaces the entry checkpoint with completed progression.
A completed battle resumes at the map or its outstanding reward decision, rather
than replaying the battle or its result animation. Result-screen-only presentation
and optional repair selection are not reconstructed; already purchased repairs
are preserved. This is a safe-screen resume, not full combat/result-scene saving.

## Permadeath and recovery

Hull loss to zero and battle defeat/draw end the run. Systems Failure defeat is
terminal even with positive Hull. A durable `ended` tombstone prevents recovery of
a pre-death checkpoint while the active/recovery files are being removed.
Individual battle victories and escapes do not delete the expedition. The current
expedition is open-ended, so no new final-victory condition was invented.

Writes validate data, write/flush/close a same-directory `.tmp` file, read it back,
protect the previous published checkpoint in `.previous`, then check the rename
that replaces the active file. Successful publication removes the internal previous
file. Neither internal file is a selectable save slot.

Recovery prefers a valid published active file, then its valid previous file,
then a complete temporary file if neither published copy is valid. This prevents
an unpublished/failed new-run replacement from abandoning an intact old run.
A complete newer terminal marker takes precedence to prevent resurrection.
Recoverable data is promoted using checked operations; failure preserves the files
and explains the problem. Unsupported schemas are preserved instead of silently
falling back to an older run. Unrecoverable corruption offers a new expedition.

## Development inspection and reset

Find the actual directory with `OS.get_user_data_dir()` in Godot. Desktop defaults
are Godot's `app_userdata/Arcospace` directory; Android uses the application's
private `user://` storage. No external-storage permission is needed.

To inspect a local file with Python:

```python
import json
from pathlib import Path
save_path = Path("/actual/user-directory/expedition_save.json")
envelope = json.loads(save_path.read_text(encoding="utf-8"))
print(json.dumps(json.loads(envelope["payload"]), indent=2, ensure_ascii=False))
```

For a development reset, call `ExpeditionSave.clear_run()` using a preload of the
persistence script. Alternatively, with the game closed, remove
`expedition_save.json`, `expedition_save.json.tmp` and
`expedition_save.json.previous` together so an internal recovery copy cannot be
restored. Do not delete only the active file and assume the slot is empty.

## Validation and limits

New suites cover codec/validation/recovery, complete progression ledgers,
transaction replay protection, menu replacement, write failures, Android-style
pause/Back handling, deterministic interrupted combat and pending-impact cleanup.
A subprocess suite writes an actual run, restores pending choices in a second
process, forcibly kills that process during combat, then verifies the same battle,
rewards and permadeath across further application starts.

Regression processes have isolated `XDG_DATA_HOME` directories. Existing synthetic
UI fixtures disable persistence explicitly; dedicated integration tests exercise
the shipped default with real disk writes. Use the shared runner (or set a fresh
`XDG_DATA_HOME` yourself) to keep manually launched tests away from player data.

Godot 4.7.2 validation: 71 headless suites, 20 rendered workflow/integration
suites, and nine Python runner tests passed, including targeted retests after
fixes. The existing exact seeded combat trace regression passed. Fresh application
processes verified persistence and forced termination during combat. Rendered
startup and resume were also checked from an exported resource pack outside the
source checkout. Some existing rendered fixtures report ObjectDB shutdown leaks;
these remain visible in the shared runner's logs.

Android export was attempted but could not build: this environment lacks the
Android export templates and configured Android SDK/build tools. Pause/Back and
process-death behavior were tested on desktop; APK/device validation remains open.

This is local persistence, not tamper-proof storage: external file copying/editing,
uninstall/clear-app-data, full device/filesystem failure and future content/schema
migrations are outside its guarantees. After an I/O failure the session stays live;
force-killing it before a successful retry can lose unpersisted progress. Browser
storage and physical Android-device behavior still require platform testing.

Godot API references: [DirAccess rename/copy](https://docs.godotengine.org/en/stable/classes/class_diraccess.html),
[quit handling](https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html),
[SceneTree mobile Back handling](https://docs.godotengine.org/en/stable/classes/class_scenetree.html).
