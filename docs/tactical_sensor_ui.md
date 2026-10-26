# Right-side tactical sensor interface

This follow-up applies the supplied reference exclusively to the right-side briefing. The existing left cinematic camera, player/enemy poses, pursuit arrangement, lighting and movement remain unchanged. The former map-projected targeting brackets are removed.

`TacticalBriefing` owns the read-only right panel: hostile warning, name/level/class, danger badge, sensor frame, side-by-side systems and authored tactical profile, modifier description and entry effects. The existing controller still owns Enter Combat, confirmation and transactions. Its existing pinned combat button now uses a solid red accent.

`EnemySensorPreview` owns one small UI SubViewport with a detached instance of the existing enemy model. Only this instance rotates, at 0.3 radians/second. A fixed cyan/red reticle is drawn by its overlay Control inside the sensor frame; it is not attached to either cinematic ship. The preview fits a bounding sphere around the model for safe rotation. Existing model loading/material helpers are reused. The viewport updates only while its texture is visible, and is freed with its briefing. It has no connection to expedition state, gameplay RNG or the map camera.

This deliberately introduces a UI model viewport in response to the explicit request for a separate rotating model on the right. It does not replace or move the actual enemy in the left scene. Normal PoIs and card management are unchanged.

Verification: 93 tactical checks cover all requested resolutions, every enemy model and both elite hulls, modifiers, preview rotation, stationary cinematic model, reticle ownership and existing cleanup. Focused compact-PoI, expedition, status/modifier and transition tests were rerun. See `tactical_sensor_results.json` for exact results. Mobile/Vulkan and Compatibility/OpenGL were checked using software Mesa llvmpipe; no physical Android hardware was tested. The full shared suite from the preceding commit was not rerun for this UI follow-up.

Screenshots: `tactical_sensor_screenshots/` (excluded from exports). Long modifier descriptions remain scrollable; Enter Combat remains pinned outside the scrolling content.
