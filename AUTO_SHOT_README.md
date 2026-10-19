# Matcha Auto Shot Meter 2.0

Version 2.0 replaces the fixed-delay-only release with a universal three-layer system:

1. It watches the game's existing `PlayerGui` for visible shot/meter/fill/power bars and releases when a changing bar reaches the configured full threshold or turns green.
2. It scans once for known client-side shot values and uses Matcha's cached `applygc` path while the shot charges. It does not repeatedly run the expensive `getgc` scan.
3. If neither signal is exposed by the game, it safely falls back to the video-calibrated timer.

Reloading the script automatically disables the previous copy, so an older timing loop cannot interfere with the updated release logic.

## Default controls

- **Auto shot** starts enabled in the **Auto Shot** tab.
- Press `F` (`0x46`) to perform one controlled shot.
- Pressing the game's `E` (`0x45`) shoot key also starts the controlled hold/release automatically.
- A PlayStation Square press is exposed to Roblox as `ButtonX`; a quick Square/ButtonX tap triggers the same controlled `E` release when Matcha exposes the `UserInputService` event.
- Select Mouse 1 or Mouse 2 if that is the game's actual shooting input.

The default strategy is **Perfect lock + live meter**. The fixed `0.98` second value is now a timeout rather than the primary release method.

## Status checks

After a shot, read **Last method**:

- `green meter: ...` means the meter changed to green and triggered the release.
- `full meter: ...` means a changing meter reached the full threshold.
- `timer fallback` means the game did not expose a recognizable meter object during that shot.

Use **Rescan perfect values** after entering a match or changing courts. **GC matches** reports how many known client-side shot fields Matcha found.

## Important limitation

This uses the game's existing GUI objects and client-side Lua values; it does not read screen pixels. If a game hides its meter in an unsupported renderer or validates the final timing only on its server, a client script cannot force every result green. In that case, copy the diagnostics after one failed shot so game-specific keys can be added.

Matcha's documented input API can inject keyboard and mouse input but not a controller button. For controller play, Square/ButtonX is therefore used as the trigger and the script performs the controlled `E` input underneath. Tap Square rather than holding it so the game's physical controller state does not outlast the script's release.

## GitHub execution

```lua
loadstring(httpget("https://raw.githubusercontent.com/9tmr/matcha-auto-shot/main/matcha_auto_shot.lua"), "@MatchaAutoShot")()
```

## Local execution

Place `matcha_auto_shot.lua` in the Matcha workspace and run:

```lua
loadstring(readfile("matcha_auto_shot.lua"), "@MatchaAutoShot")()
```
