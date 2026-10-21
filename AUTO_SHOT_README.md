# Matcha Auto Shot Meter 3.0

Version 3.0 is a major meter and input-state overhaul based on the supplied `20261021-0043-43.9894260.mp4` recording.

## What the recording showed

The game's shot meter is a world-space/Billboard-style vertical bar beside the character. The white marker rises into the green cap in roughly 0.3–0.5 seconds. When Square stays held, the marker reverses and falls. Version 2.3 scanned only `PlayerGui`, so it missed this world-space meter and waited for the 1.15-second fallback—after the green window had already passed.

## Version 3.0 behavior

1. Scans both `PlayerGui` and the local character for world-space/Billboard meter descendants. A single targeted Workspace scan covers games that parent the meter to a temporary world object.
2. Tracks changing fill dimensions, color changes, and local GUI position rather than treating camera or character movement as meter movement.
3. Releases as soon as a moving marker touches a related green GUI zone.
4. Detects the marker's upward peak and releases on the first downward reversal if the green contact is not directly exposed.
5. Uses a video-calibrated `0.44`-second world-meter timeout as a final backup for meters drawn as one inaccessible image.
6. Forces recognized fill descendants to full green only at the actual release point, so the script's own visual write cannot cause an early pump fake.
7. Sends a six-pulse release burst and applies a cached GC release takeover for common held/charging flags.
8. If E or Square remains physically held, it gates Roblox input and continues pulsing release state until the button is lifted.

Reloading the script disables the older copy automatically.

## Default controls

- Auto shot starts enabled in the **Auto Shot** tab.
- Press `F` (`0x46`) for one controlled shot.
- Press or hold the game's `E` (`0x45`) shoot key.
- Press or hold PlayStation Square / Roblox `ButtonX` on controller.
- The default shot output is the configured keyboard shot key (`E`). Mouse 1 and Mouse 2 remain available.

## Default tuning

- Full meter threshold: `0.96`
- Meter arming delay: `0.06` seconds
- World-meter peak timeout: `0.44` seconds
- No-meter safety timeout: `0.90` seconds
- Held-input block timeout: `5.00` seconds

The live green/contact and peak-reversal signals take priority over every timer.

## Status checks

After a shot, check **Last method** and **Last meter root**:

- `green-zone contact: ...` — the moving marker entered a green GUI cap.
- `meter peak reversal: ...` — the marker reached its highest point and started falling.
- `green meter: ...` — a tracked meter object changed to green.
- `full meter: ...` — a changing fill reached the configured threshold.
- `calibrated world-meter peak` — the world meter moved, but its internal marker was not individually exposed.
- `no-meter safety timeout` — no usable meter activity was visible to Matcha.

`Last meter root` should normally report `Character/Billboard` for the game in the supplied recording. **Release takeover matches** reports how many common held/charging client values were found.

## Important limitation

No client-side executor can guarantee a server-validated result in every game. Version 3.0 aggressively controls the visible meter, injected release, and exposed client state, but a server may independently reject or recalculate a shot. If a shot still fails, use **Copy diagnostics** immediately afterward so the exact release method, meter root, timing, and matched state fields can be inspected.

Matcha has no documented API for injecting a controller-button release. Controller mode therefore detects Square/ButtonX, drives the configured keyboard shot input, clears exposed held/charging state, and gates the remaining physical hold at the release point.

## GitHub execution

```lua
loadstring(httpget("https://raw.githubusercontent.com/9tmr/matcha-auto-shot/main/matcha_auto_shot.lua"), "@MatchaAutoShot")()
```

## Local execution

```lua
loadstring(readfile("matcha_auto_shot.lua"), "@MatchaAutoShot")()
```
