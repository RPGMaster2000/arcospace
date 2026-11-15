# Beam depth, victory ordering and destruction HUD

## Beam/background rendering

The standard sky disabled depth writing (`depth_draw_never`) while the imported beam uses transparent materials at their normal priority. In a rendered reproduction, most of the beam disappeared with the sky visible and reappeared when it was hidden. Switching only the distant sky to `depth_draw_opaque` restores normal ordering.

The sphere writes its real, distant surface depth. Beam shaders, render priorities and depth tests are unchanged. The rendered regression samples the same beam against visible/hidden sky from normal, attacker and victim viewpoints in both standard arenas. It then inserts opaque foreground geometry and requires that geometry to occlude the beam. This guards against an always-on-top workaround.

## Presentation sequence

```mermaid
flowchart LR
    Commit[Existing authoritative outcome and rewards] --> Destruction[Destruction VFX finish with normal HUD]
    Destruction --> Orbit[Surviving player orbit]
    Orbit --> Boost[Engine boost and departure]
    Boost --> Black[Fade to black]
    Black --> Result[Existing Victory screen]
    Result --> Upgrades[Existing confirmation and upgrades]
    Upgrades --> Map[Original star-system return]
```

`board_3d.gd` owns three ephemeral presentation latches and a black instance of the existing transition curtain. It starts departure once, after combat effects and destruction complete. The result screen is prepared under completed black, then its existing reveal animation is exposed. Departed ships stay hidden behind the result screen. No second scene fade or departure occurs after rewards/upgrades.

`ExpeditionState` still commits the result at its original boundary. The controller still clears `active_battle` and removes the board when the existing result continuation fires. Required upgrades then complete normally. The old post-upgrade retained-board/return-camera machinery is removed; no new save fields or migrations are needed.

The Skip preference bypasses optional motion while retaining the single covered result handoff. Active Skip remains safe at orbit, boost and fade. Presentation locking prevents early/repeated Continue from skipping the result sequence. Defeat and ordinary FTL/EMP escape never start player departure.

## Destruction HUD

Destruction shots continue using the normal battlefield viewport (`fullscreen = false`). A display-only `destruction_presenting` fact keeps existing allocation/charged-EMP controls visible while terminal actions remain disabled. Hull, Shields, resources and cards stay in their established positions and opacity; authoritative damage still updates their values. Full-screen treatment begins only for the subsequent victory orbit, after destruction VFX finish.

## Validation

- `beam_depth_test.gd`: actual rendered beam visibility, unchanged foreground occlusion, both directions, three viewpoints and both standard arenas.
- `battle_cinematic_test.gd`: real lethal player/enemy card attacks; frame-by-frame visibility, opacity, card/control rectangles and viewport bounds during both destruction sequences.
- `battle_departure_test.gd`: actual expedition commits, destruction → departure → black → result ordering, all Skip stages, legal FTL escape, defeat, upgrade completion, no replay on map return and identical final save records against the original immediate flow.
- `battlefield_depth_test.gd`: automatic departure integrated into both standard-arena combat smoke cases.

The tests run headless where applicable and in the recurring GL Compatibility/Mobile Vulkan suites. Captures use production scenes and imported effects, with controlled battle inputs and shorter test shot durations. No generated artwork or baseline-fixture replacements are used. Physical Android/Windows performance and native-device input remain manual checks.

## Actual rendered captures

[Captured production sequence](battle_cinematic_fix_captures/sequence.webp) shows destruction, departure, Victory and map return. Frames are sampled and encoded at 8 fps for review, not a physical-device frame-rate claim. The capture helper stages a real Missile Barrage against a 3-Hull unshielded target for reproducibility.

| View | Capture |
| --- | --- |
| Beam in front of distant sky, normal viewport | [Beam](battle_cinematic_fix_captures/beam-normal.webp) |
| Beam at a close camera angle | [Close view](battle_cinematic_fix_captures/beam-close.webp) |
| Enemy destruction with intact HUD | [HUD](battle_cinematic_fix_captures/enemy-destruction-hud.webp) |
| Player destruction with intact HUD | [HUD](battle_cinematic_fix_captures/player-destruction-hud.webp) |
| Subsequent surviving-ship orbit | [Orbit](battle_cinematic_fix_captures/victory-orbit.webp) |
| Existing Victory screen after departure | [Victory](battle_cinematic_fix_captures/victory-result.webp) |
