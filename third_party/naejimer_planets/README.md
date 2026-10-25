# Naejimer / Rémi — 3D Planet Generator subset

Source: https://github.com/remijean/godot-3d-planet-generator
Pinned upstream revision: `2d17d1699d7440b17f34e3ae1654084244bd2f7d` (main).
Downloaded directly with Git on 2026-10-25. The Godot Asset Library lists version
1.0 for Godot 4.5: https://godotengine.org/asset-library/asset/1615 . Upstream
project.godot declares 4.5 / Forward Plus. We test this subset on Arcospace's 4.7.2.

License: MIT, Copyright (c) 2023 Rémi. The complete upstream LICENSE is retained.
Upstream shader provenance comments are retained. No plugin.cfg, editor plugin,
demo scene, animation player, demo project or demo icon is required or imported.

Included: body, clouds and atmosphere shaders; six small sample noise resources;
body ShaderMaterials extracted from the terrestrial, ice, lava, sand, gaseous and
no-atmosphere sample scenes. Sample star is not imported: Arcospace retains its sun.

Adaptations:
- Explicit path-based references rather than upstream UIDs/demo scene dependencies.
- Noise textures reduced to 128×128 and shared by sample material, generated once
  by Godot rather than synthesized every frame.
- Undefined modulo by zero in animated body/cloud UVs replaced with fract() and
  repeating samplers. This is a concrete upstream animation-path correction.
- Explicit back-face culling and a per-material noise_offset for cosmetic variation.
- Arcospace supplies mesh sizes, rotation, detached material copies, subtle atmosphere
  parameters and optional cloud layers. Presets remain editable ShaderMaterials.
- No glow/bloom or screen/depth texture dependency. Mobile/Compatibility do not need
  Forward+ features; the atmosphere is a simple Fresnel shell, not volumetric scattering.

Fallback: StarSystemSettings → Background and quality → Imported Planets = Off.
This uses the unchanged res://shaders/planet_surface.gdshader and omits imported
cloud/atmosphere shells. Atmospheres and clouds can also be disabled separately.
