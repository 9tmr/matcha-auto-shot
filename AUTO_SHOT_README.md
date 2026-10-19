# Matcha Auto Shot Meter 2.3

Version 2.3 adds a tap-or-hold shot controller and a held-input release gate:

1. A single tap or a held E/Square press starts one complete controlled charge.
2. It watches the game's existing `PlayerGui` for a changing fill dimension, a meter turning green, or a moving needle entering a green zone.
3. It releases immediately at the detected green/full point. The default threshold is `97%`; the short `0.10`-second arming delay only rejects the meter's initial appearance.
4. At the release point, it seals matching visible meter descendants to full green so the displayed bar finishes at the top.
5. If E or Square is still physically held after the release, it temporarily gates Roblox input until that button is lifted, preventing the held button from overriding the automatic release.
6. A maximum `1.15`-second timer remains as the fallback when a game does not expose a recognizable meter.

The perfect-value layer still scans once for known client-side shot values and uses Matcha's cached `applygc` path while the shot charges. It does not repeatedly run the expensive `getgc` scan.

Unlike v2.2, v2.3 does **not** force the visual bar full before reading it. That old order could turn the script's own visual write into a false release signal.

Reloading the script automatically disables the previous copy, so an older timing loop cannot interfere with the updated release logic.

## Default controls

- **Auto shot** starts enabled in the **Auto Shot** tab.
- Press `F` (`0x46`) to perform one controlled shot.
- Pressing the game's `E` (`0x45`) shoot key also starts the controlled hold/release automatically.
- A PlayStation Square press is exposed to Roblox as `ButtonX`; a quick Square/ButtonX tap triggers the same controlled `E` release when Matcha exposes the `UserInputService` event.
- Select Mouse 1 or Mouse 2 if that is the game's actual shooting input.

The default strategy is **Perfect lock + live meter**, **Force meter to 100% green** starts enabled, and the live full threshold defaults to `0.97`. The maximum fallback timeout is `1.15` seconds.

## Tap, hold, and forced release

Whether the physical input is tapped or held, the injected shot input remains held until the live meter reaches green/full. The script then sends repeated release events. For direct E and Square/ButtonX shots, it also calls `setrobloxinput(false)` while the same physical input remains down, then restores input as soon as it is released (or after the configurable safety timeout).

This is what allows the automatic release to occur while the player's finger is still holding the button.

## Status checks

After a shot, read **Last method**:

- `green meter: ...` means the meter changed to green and triggered the release.
- `full meter: ...` means a changing meter reached the full threshold.
- `green-zone contact: ...` means a moving meter indicator entered a visible green GUI zone.
- `timer fallback` means the game did not expose a recognizable meter object during that shot.

Use **Rescan perfect values** after entering a match or changing courts. **GC matches** reports how many known client-side shot fields Matcha found.

## Important limitation

This uses the game's existing GUI objects and client-side Lua values; it does not read screen pixels. If a game hides its meter in an unsupported renderer or validates the final timing only on its server, a client script cannot force every result green. In that case, copy the diagnostics after one failed shot so game-specific keys can be added.

Matcha's documented input API can inject keyboard and mouse input but not a synthetic controller button. For controller play, Square/ButtonX is detected through both `InputBegan` and `IsGamepadButtonDown`; the script holds the configured keyboard shot input underneath and uses Matcha's Roblox-input gate to stop a still-held Square signal at release.

## GitHub execution

```lua
loadstring(httpget("https://raw.githubusercontent.com/9tmr/matcha-auto-shot/main/matcha_auto_shot.lua"), "@MatchaAutoShot")()
```

## Local execution

Place `matcha_auto_shot.lua` in the Matcha workspace and run:

```lua
loadstring(readfile("matcha_auto_shot.lua"), "@MatchaAutoShot")()
```
