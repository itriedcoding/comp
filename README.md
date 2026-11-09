# BLACKSITE

An offline, single-player tactical first-person shooter for Windows 10/11 (64-bit), built with **Godot 4.7.2** and GDScript. Everything in the game — weapons, movement, AI, maps, UI, audio, materials — is implemented in this repository. There are no external asset packs, no network services and no placeholder menus.

The prebuilt Windows build is committed as [`dist/BlackSite-win64.zip`](dist/BlackSite-win64.zip). Unzip it and run `BlackSite.exe` — a single self-contained executable with the game data embedded. No installer, runtime or additional files are required.

The uncompressed `dist/BlackSite.exe` (105 MB, almost all of it the Godot runtime) is what the export step produces. It is not stored in git because GitHub rejects files over 100 MB, hence the zip.

---

## Requirements

| | |
|---|---|
| OS | Windows 10 or 11, 64-bit |
| GPU | Vulkan or Direct3D 12 capable (GTX 900 / RX 400 or newer class) |
| RAM | 6 GB |
| Disk | ~120 MB |
| Input | Keyboard + mouse |

## Controls

| Action | Bindings |
|---|---|
| Move | `W` `A` `S` `D` |
| Sprint | `Shift` (hold) |
| Crouch | `Ctrl` (hold) |
| Slide | `Shift` + `Ctrl` while sprinting |
| Jump | `Space` |
| Lean left / right | `Q` / `E` |
| Fire | Left mouse |
| Aim down sights | Right mouse |
| Reload | `R` |
| Weapons | `1` primary, `2` secondary, `3` sidearm, mouse wheel to cycle |
| Tactical light | `T` |
| Interact / hold objective | `F` |
| Pause | `Esc` |
| FPS counter | `F3` (or enable it in Settings) |

Sensitivity, ADS sensitivity, invert-Y, FOV, crosshair style/colour/gap/thickness/dot and HUD scale are all adjustable in **Settings**.

## Game modes

* **Campaign** — three linked operations across three maps, each with staged objectives (reach, eliminate, destroy, extract), a briefing, mid-mission checkpoints and a debrief that unlocks the next operation.
* **Shooting Range** — a timed drill with pop-up targets, scoring, accuracy tracking and a persistent best score.
* **Survival** — escalating waves on the industrial map with a supply crate between waves (health, armor, ammunition).
* **Tactical Mission** — a stealth-weighted extraction on the urban map. An alarm timer starts reinforcements; staying undetected pays a score bonus.
* **Offline Bot Match** — team deathmatch against seven AI operators on the forest outpost, with respawns, a score limit and a match timer.

## Implemented systems

**Weapons.** Five weapons (KX-15 rifle, M14 DMR, M590 shotgun, MP5 SMG, P226 pistol) with distinct ballistics, rate of fire, recoil patterns, spread, falloff and reload timings. Magazine + chamber ammunition model, tactical and empty reloads with separate timings and sounds, weapon swapping with draw time, and per-weapon procedurally built first-person models. Attachments (optic, suppressor, extended magazine, vertical grip) are functional: they change zoom, report/noise radius, magazine capacity, recoil and spread, and are reflected in the viewmodel. Hitscan ballistics trace through materials with per-surface penetration, damage falloff, headshot multipliers (separate hit shape) and impact decals/particles/tracers on every surface type.

**Movement.** Acceleration-based ground/air movement, sprint with stamina, crouch with capsule resize, slide, jump, lean, view bob, landing dip, camera shake, surface-aware footstep audio, and recoil that accumulates and recovers with the weapon's own recovery rate.

**Player.** Health and armor with armor absorbing a portion of incoming damage, delayed regeneration, directional damage indicators, death handling and respawn (bot match).

**AI.** Perception through view cone + line-of-sight raycast + hearing (gunfire noise radius, footsteps, suppressed shots are quieter), awareness buildup, and a patrol → investigate → combat → search → patrol state machine. Squads share contact reports through a director, take cover behind registered cover points, flank, use burst fire with reaction delays and accuracy scaled by difficulty, react to being hit, and die with ragdoll-free but animated collapse + loot-free cleanup. Four difficulty tiers tune reaction time, accuracy, damage, awareness and health.

**Maps.** Three hand-laid maps — Kessler Industrial Complex, Sokol Heights (urban) and the forest Outpost — each built from procedural geometry with generated PBR materials, cover registration, patrol routes, objective markers, weather (rain/dust), time-of-day lighting, volumetric fog, and a baked A* navigation grid used by every AI agent.

**Characters and world detail.** Hostiles are articulated operators built from ~35 parts: plate carrier with pouches and radio, helmet with NVG mount and goggles, articulated arms with gloved hands, legs with knee pads and boots, and a rifle with optic and magazine. They walk with a procedural gait that scales with speed, counter-rotate their torso, crouch behind cover, turn their head and torso toward the player, hold their rifle in a firing pose and collapse on death. The player's viewmodel now has gloved hands on the grip and handguard, a stock butt plate, charging handle, ejection port and optic-height ADS alignment. World materials carry ramped albedo, tangent-space normals, roughness and ambient-occlusion maps; the sky is a physical Rayleigh/Mie atmosphere with a sun disc, and lighting adds SSIL bounce plus contact-hardened SSAO and screen-space reflections. Impact decals are 96 px with radial cracks and a dust rim.

**Audio.** Every sound is synthesised at runtime into `AudioStreamWAV` buffers (no audio files): five weapon reports plus suppressed variants, magazine/bolt handling, footsteps per surface, impact sounds per material, hitmarkers, alarms, ambience beds (wind, industrial hum, rain), UI clicks. 3D playback with distance attenuation and raycast-based occlusion, buses for SFX/ambience/UI, and a reverb send.

**UI.** Main menu with operations, briefings, difficulty, loadout and settings; in-game HUD with health/armor/stamina bars, dynamic crosshair that reacts to spread, hitmarkers, compass, objective list, timer, ammo/fire-mode readout, kill feed, damage vignette and objective prompts; pause menu (resume, settings, restart, quit to menu); mission results screen with stats; loading/intro overlay.

**Persistence.** Settings, loadout and progression are written to `%APPDATA%\Godot\app_userdata\BLACKSITE\` (`settings.cfg`, `profile.cfg`). Campaign checkpoints (`checkpoint.json`) are written every 45 seconds and on objective completion, and can be resumed from the campaign menu.

**Graphics settings.** Resolution and window mode, render scale, MSAA, TAA, FSR 1 / FSR 2 upscaling, shadow quality, SSAO, SSR, volumetric fog, view distance, texture quality, VSync, FPS cap, FOV and HUD scale.

## Honest scope and limitations

* This is a **Godot 4** project, not Unreal Engine 5. It does not use Lumen, Nanite or photogrammetry assets, and the visuals are procedural rather than photoreal. Geometry, PBR maps, characters, sky and audio are all generated in code. UE5 could not be installed or run in the Linux build environment used to create this project.
* **DLSS is not implemented** and is not faked; Godot has no DLSS support. FSR 1 and FSR 2 are real and selectable. The settings screen says so in-game.
* All art and audio are generated in code at startup. This keeps the download small and dependency-free, but it is not equivalent to authored AAA art.
* Single-player offline only. There is no networking, matchmaking, or online service of any kind.
* The game was built and tested **headlessly on Linux** (logic, maps, AI, weapons, saves and all five modes are covered by an automated suite). It has **not** been run on Windows or on a GPU in this environment, so frame rate, driver compatibility and the final look have not been verified here. The Windows executable is produced by Godot's official Windows export template.
* No GitHub Release was published from this build environment because the GitHub CLI is unauthenticated here. The full source, documentation and a ready-to-run zipped build are in the repository; publishing the release only requires uploading `dist/BlackSite.exe` (or the zip) to a new release from an authenticated account.
* Bots are competent but not human-like; difficulty tiers change reaction, accuracy and awareness rather than adding new behaviours.

## Building from source

See [BUILD.md](BUILD.md). Short version:

```bash
godot --headless --import
godot --headless --export-release "Windows Desktop" dist/BlackSite.exe
```

## Tests

```bash
godot --headless --path . res://tests/test_runner.tscn
```

158 checks covering input bindings, weapon/mission/difficulty data, settings round-trips, synthesised audio streams, material generation, all three maps (navigation grid, cover, spawns, pathing, environment), player movement/damage/healing, weapon firing/reload/switching, AI perception/combat/death/squad bookkeeping, checkpoint save-load, booting all five game modes, and the rendering budgets below.

The exported pack was additionally booted headlessly with `--main-pack` to confirm the build contains every resource it needs and starts the menu without script or resource errors.

## Performance

Measured on this build machine, headless (no GPU). The suite prints these numbers on every run:

| Metric | Result |
|---|---|
| Map mesh nodes, all three maps combined | **2,055 → 56** (one merged batch per material) |
| Draw batches per map | **17–20** |
| Cold map build + merge (industrial) | **49 ms** (32 ms build, 17 ms merge) |
| Warm rebuilds (industrial / urban / outpost) | 42 ms / 25 ms / 301 ms |
| Process static memory during the full suite | **187 MB** |
| Generated texture budget at "High" (1024 albedo, 512 normal/roughness/AO) | roughly 0.2 GB VRAM |

Static world geometry is merged into one mesh per material at load, which removes roughly 2,000 individual mesh nodes and their draw calls per map. Only the directional sun casts dynamic shadows; lamp lights are unshadowed and grounded by SSAO/SSIL instead. `rendering` quality tiers control texture resolution, shadow atlas size, effects density and view distance, so the game can be pushed down if a machine is struggling; at the tested settings it stays far inside a 6 GB footprint.

```bash
godot --headless --path . res://tests/bench_cold.tscn   # cold map build + merge
```

## Layout

```
autoload/        Game (settings, profile, saves, routing) and Audio (synthesis, 3D playback)
scenes/          main.tscn — the only scene; everything else is built in code
scripts/         bootstrap, data, ballistics, fx, player, training target
scripts/ai/      enemy agent and squad director
scripts/modes/   GameMode base + campaign, training, survival, tactical, bot match
scripts/ui/      theme, HUD, menu, loadout, settings, pause, results
scripts/weapons/ weapon system and procedural viewmodels
scripts/world/   materials, map builder, the three maps
tests/           headless test suite (excluded from the exported build)
dist/            exported Windows build
```

## License

MIT — see [LICENSE](LICENSE).
