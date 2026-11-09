# Building BLACKSITE

The project targets **Godot 4.7.2 stable**. No plugins, C# or native extensions are required.

## 1. Get Godot

Download Godot 4.7.2 (standard build) from <https://godotengine.org/download> and install the **Export Templates** for the same version (Editor → Manage Export Templates → Download and Install, or place them in `~/.local/share/godot/export_templates/4.7.2.stable/` on Linux / `%APPDATA%\Godot\export_templates\4.7.2.stable\` on Windows).

Verify the templates contain:

```
windows_debug_x86_64.exe
windows_release_x86_64.exe
windows_debug_x86_64_console.exe
windows_release_x86_64_console.exe
```

## 2. Import

From the repository root:

```bash
godot --headless --import
```

This generates `.godot/` (ignored by git) and imports `icon.svg`.

## 3. Run

```bash
godot --path .
```

## 4. Test

```bash
godot --headless --path . res://tests/test_runner.tscn
```

The process exits with code `0` when every check passes and `1` on failure. The suite prints `PASS`/`FAIL` per check and a final summary. It covers input bindings, data tables, settings persistence, generated audio and materials, all three maps (navigation, cover, spawns, pathing, environment), player movement/damage, weapon fire/reload/switch, AI perception/combat/death, checkpoints, and all five modes.

## 5. Export the Windows build

`export_presets.cfg` already defines a single **Windows Desktop** preset (x86_64, PCK embedded, `tests/*` excluded).

```bash
mkdir -p dist
godot --headless --export-release "Windows Desktop" dist/BlackSite.exe
```

The result is one self-contained executable. On Windows the same command works from `cmd`/PowerShell with `godot.exe` on `PATH`.

## Notes

* The exported build writes settings and progress to `%APPDATA%\Godot\app_userdata\BLACKSITE\`.
* `tests/` is excluded from the export via the preset's exclude filter.
* Rendering options (MSAA, TAA, FSR, SSAO, SSR, fog) are applied at runtime from the in-game settings screen; nothing needs to be configured at export time.
