# Escape the Backrooms — Godot 4 Recreation

A fan recreation of the Level 0 ("The Lobby") section of *Escape the
Backrooms* in Godot 4.3. Single-player, first-person, with the iconic
yellow-wallpaper maze, flickering fluorescent lights, damp carpet, and
that "you should not be here" hum.

> This is an independent fan project. It is **not affiliated with**
> Fancy Games or the original *Escape the Backrooms*. No copyrighted
> assets from the original game are used; all textures and audio are
> generated procedurally at runtime.

## Status

- [x] Level 0 — procedural Lobby maze
- [x] First-person controller (walk, sprint, crouch, jump, head-bob,
  stamina)
- [x] Yellow wallpaper, damp carpet, ceiling tiles (procedural textures)
- [x] Flickering fluorescent lights with SDFGI bounce lighting
- [x] Procedural ambient 60 Hz hum + damp-carpet footsteps
- [x] Post-processing: film grain, vignette, chromatic aberration,
  warm tint
- [x] HUD with stamina/sanity bars
- [x] No-clip exit trigger (Level 1 stub)
- [ ] Level 1, Level 2, … (future)
- [ ] Multiplayer co-op (future)

## Requirements

- [Godot 4.3](https://godotengine.org/download) (Forward+ renderer)

## Running

```bash
godot --path . --main-scene res://scenes/main.tscn
```

Or open `project.godot` in the Godot editor and press F5.

## Controls

| Action            | Key                |
| ----------------- | ------------------ |
| Move              | `W` `A` `S` `D`    |
| Sprint            | `Shift` (drains stamina) |
| Crouch            | `Ctrl`             |
| Jump              | `Space`            |
| Look              | Mouse              |
| Interact          | `E`                |
| Open settings / pause | `Esc`          |

## Project Layout

```
escape-the-backrooms-godot/
├── project.godot              # Godot project config + input map
├── scenes/
│   ├── main.tscn              # Root scene: env + post-process + level loader
│   ├── player/player.tscn     # First-person controller
│   ├── levels/level_0.tscn    # Lobby (procedural)
│   └── ui/hud.tscn            # Stamina/sanity HUD + fader
├── scripts/
│   ├── main.gd                # Composes world at startup
│   ├── game_state.gd          # Autoload singleton (sanity/stamina/signals)
│   ├── player.gd              # CharacterBody3D controller
│   ├── level_0.gd             # Procedural Lobby builder
│   ├── flicker_light.gd       # Fluorescent light flicker
│   ├── noclip_exit.gd         # Wall-clip exit trigger
│   ├── buzz_generator.gd      # Procedural 60Hz hum (AudioStreamGenerator)
│   ├── footstep_stream.gd     # Procedural carpet footstep bursts
│   └── hud.gd                 # HUD logic
├── shaders/
│   └── post_process.gdshader  # Grain + vignette + CA + warm tint
└── resources/
    └── default_env.tres       # WorldEnvironment with SDFGI + fog + glow
```

## Design Notes

### Look

The Backrooms aesthetic is built from four ingredients:

1. **Color** — saturated mid-century yellow `#d8b94a` for walls,
   warm light `#fff4c2` for fluorescents, dirty `#8c5a26` carpet.
2. **Lighting** — many low-energy point lights with SDFGI global
   illumination producing the flat, diffuse "everything is lit" look,
   plus heavy `fog_density` for depth fall-off.
3. **Materials** — embossed wallpaper made from a SimplexNoise
   `FastNoiseLite` pass plus thin sine stripes; carpet is two-octave
   noise with random damp patches; ceiling tiles are noise + grid lines.
4. **Post** — vignette + film grain + a tiny chromatic aberration scaled
   by distance from screen center; a warm sepia push to lock in the
   yellow.

### Audio

All audio is generated at runtime through `AudioStreamGenerator`:

- `buzz_generator.gd` mixes a 60 Hz fundamental with second and third
  harmonics plus a touch of white noise. The result is the
  fluorescent-fixture mains hum that defines the Backrooms.
- `footstep_stream.gd` synthesises a short noise burst with a damped
  120 Hz "thud" body, fed through a one-pole low-pass to capture the
  muffled feel of damp carpet. Called by the player every
  `0.38 / 0.55 / 0.85` seconds depending on sprint / walk / crouch.

This means the project ships with **no audio files** and avoids any
licensing questions about copying the original game's assets.

### Level Generation

Level 0 is a `24 × 24` grid of `4 × 4 m` tiles. Generation:

1. Carve 5–8 large rectangular rooms.
2. Drunkard's-walk corridors between random anchor points, widened to
   2 tiles for the "office hallway" feel.
3. Force the centre `4 × 4` block open as the player spawn.
4. Fill every remaining closed cell with a full-height wall block.
5. Place a fluorescent fixture every other open tile.
6. Pick one random open tile bordering a wall as the **no-clip exit**;
   when the player walks into it, `GameState.trigger_noclip()` fires
   and the HUD fades to black with a "Level 1: coming soon" message.

The seed is fixed (`13_071_996`) so every run produces the same map —
swap to `randomize()` in `level_0.gd` for a new layout each launch.

## License

MIT — see `LICENSE` (if present) or treat all original code in this
repo as MIT-licensed. *Backrooms* concept and original game are
property of their respective owners.
