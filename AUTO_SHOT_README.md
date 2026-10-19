# Matcha Auto Shot Meter

This is a video-calibrated timed-release helper for the Roblox basketball game shown in `20261019-0351-30.1474525.mp4`.

## What the clip showed

- The vertical shot meter appears shortly after the shooting animation begins.
- The sampled standing, moving, close, and longer shots reached the release phase in roughly one second.
- Version 1.0.0 therefore starts at a 0.98-second hold, with a fine trim control for live calibration.

## Default controls

- `F` (`0x46`) is the separate auto-shot trigger.
- The script presses and releases `E` (`0x45`) as the game's shoot key.
- If the game's keyboard shoot control is not `E`, enter its Windows virtual-key value in **Game shoot VK**.
- Mouse-button shot controls are available in the **Shot input** dropdown.

## Calibration

1. Enable **Auto shot**.
2. Stand at a repeatable spot and press `F` once.
3. If the game reports **Early**, increase **Fine trim** by 10-25 ms.
4. If the game reports **Late**, decrease **Fine trim** by 10-25 ms.
5. Repeat until the jumper consistently lands in the green window.

Matcha has no documented screen-pixel capture function, so this script times the input rather than visually reading the meter. A different jumper, special gather, layup, dunk, heavy latency spike, or server-side timing change may still require a different trim value.

## Local execution

Put `matcha_auto_shot.lua` in the Matcha workspace and run it directly, or use:

```lua
loadstring(readfile("matcha_auto_shot.lua"), "@MatchaAutoShot")()
```
