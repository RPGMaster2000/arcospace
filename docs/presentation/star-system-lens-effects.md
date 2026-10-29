# Experimental star-map lens effects

The map uses the existing `addons/lens_effects` compositor with 20 radial samples,
0.35 maximum multiplier and restrained anamorphic brightness. The procedural sun
remains the light-position source. Its projection uses the map camera and
SubViewport dimensions, not the main window. Only the map WorldEnvironment owns
this compositor. Compatibility/headless paths retain the procedural sun without
creating the effect. Hidden/inactive maps and off-screen/behind-camera suns disable
dispatch; an edge fade avoids a hard transition.

Use **Settings → Star-map lens effects (experimental)** for an on/off comparison.
The switch defaults on on supported backends and lasts for the current session;
it does not change save data. Compare the same camera framing on a physical
Android device. Twenty samples limits work, but this remains a full-resolution
compute pass plus one additive triangle; no physical-device frame-time or thermal claim is made.

The addon is reused in place. Its pipeline is retained across uniform updates and
tracked for cleanup. Shader accesses are bounded for non-multiple-of-16 viewport
sizes and edge depth taps. Shader initialization failure skips dispatch. The shader uses image dimensions
instead of an unavailable private engine include. A reusable RGBA16F light buffer
and additive raster pass support Mobile packed-HDR attachments without storage
image writes. The additive pass preserves scene alpha; depth jitter is stable
instead of animated. GPU dependents are released before their shaders.

`star_system_lens_effects_test.gd` joins the headless and both rendered suites.
The rendered CI jobs also exercise it from an exported resource pack. Existing
exported menu-to-battle startup checks remain in place. These software-rendered
checks do not replace Android device testing.
