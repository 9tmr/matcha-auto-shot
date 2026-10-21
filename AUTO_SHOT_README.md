# Matcha Auto Shot Meter 3.1

## Version 3.1 automatic takeover fix

Version 3.0 waited for the old `0.90`-second safety timeout when the meter was
not readable. More importantly, it disabled Roblox input before sending its
repeated key-up pulses. That could suppress the script's own release and leave
the real held button in control, making the player release manually.

Version 3.1 changes the shot lifecycle:

1. Physical E and Square/ButtonX are start signals; the script owns the charge
   so a quick tap and a long hold use the same automatic cycle.
2. A visible green contact or marker reversal still releases immediately.
3. An absolute video-calibrated `0.44`-second deadline releases every shot even
   when Matcha cannot inspect the meter.
4. E receives repeated key-up pulses. Square also receives the Windows
   `VK_GAMEPAD_X` (`0xC3`) release pulse while the cached held/charging GC state
   is cleared.
5. Release pulses are sent while input is enabled, then the gate is closed
   between pulses. The physical hold cannot silently suppress the scripted
   key-up or reclaim the charge.

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
- Automatic release deadline: `0.44` seconds
- Held-input block timeout: `5.00` seconds

The live green/contact and peak-reversal signals take priority over every timer.

## Status checks

After a shot, check **Last method** and **Last meter root**:

- `green-zone contact: ...` — the moving marker entered a green GUI cap.
- `meter peak reversal: ...` — the marker reached its highest point and started falling.
- `green meter: ...` — a tracked meter object changed to green.
- `full meter: ...` — a changing fill reached the configured threshold.
- `calibrated world-meter peak` — the world meter moved, but its internal marker was not individually exposed.
- `automatic calibrated release` — the meter was hidden, so the script released at the absolute automatic deadline.

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
