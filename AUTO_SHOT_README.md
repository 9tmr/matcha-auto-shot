# Matcha Auto Shot Meter 2.2

Version 2.2 replaces the fixed-delay-only release with a universal four-layer system and a pump-fake-safe charge state:

1. It immediately forces matching visible shot-meter fill objects to `UDim2.new(1, 0, 1, 0)` and colors them green while the shot charges.
2. It watches the game's existing `PlayerGui` for visible shot/meter/fill/power bars and releases when a changing bar reaches `100%` or turns green.
3. It scans once for known client-side shot values and uses Matcha's cached `applygc` path while the shot charges. It does not repeatedly run the expensive `getgc` scan.
4. If none of those signals are exposed by the game, it safely falls back to the video-calibrated timer.

Reloading the script automatically disables the previous copy, so an older timing loop cannot interfere with the updated release logic.

## Default controls

- **Auto shot** starts enabled in the **Auto Shot** tab.
- Press `F` (`0x46`) to perform one controlled shot.
- Pressing the game's `E` (`0x45`) shoot key also starts the controlled hold/release automatically.
- A PlayStation Square press is exposed to Roblox as `ButtonX`; a quick Square/ButtonX tap triggers the same controlled `E` release when Matcha exposes the `UserInputService` event.
- Select Mouse 1 or Mouse 2 if that is the game's actual shooting input.

The default strategy is **Perfect lock + live meter**, **Force meter to 100% green** starts enabled, and the full threshold defaults to `1.00`. A shot now stays held for at least `0.90` seconds even if the visual meter is forced full immediately. The maximum fallback timeout is `1.15` seconds.

## Pump-fake fix

The supplied `20261019-0437-00.3195460.mp4` recording shows the meter appearing but the player returning to idle without releasing the ball. Version 2.1 allowed a forced-full meter to satisfy the release condition after about `0.20` seconds. Version 2.2 separates visual fill from release timing: it fills the correct non-text descendants beneath a named meter container, keeps the shot key held, and refuses to release before **Minimum charge time**.

## Status checks

After a shot, read **Last method**:

- `green meter: ...` means the meter changed to green and triggered the release.
- `full meter: ...` means a changing meter reached the full threshold.
- `timer fallback` means the game did not expose a recognizable meter object during that shot.

Use **Rescan perfect values** after entering a match or changing courts. **GC matches** reports how many known client-side shot fields Matcha found.

## Important limitation

This uses the game's existing GUI objects and client-side Lua values; it does not read screen pixels. If a game hides its meter in an unsupported renderer or validates the final timing only on its server, a client script cannot force every result green. In that case, copy the diagnostics after one failed shot so game-specific keys can be added.

Matcha's documented input API can inject keyboard and mouse input but not a controller button. For controller play, Square/ButtonX is detected through both `InputBegan` and `IsGamepadButtonDown`, then the script holds the controlled `E` input underneath until the safe release point.

## GitHub execution

```lua
loadstring(httpget("https://raw.githubusercontent.com/9tmr/matcha-auto-shot/main/matcha_auto_shot.lua"), "@MatchaAutoShot")()
```

## Local execution

Place `matcha_auto_shot.lua` in the Matcha workspace and run:

```lua
loadstring(readfile("matcha_auto_shot.lua"), "@MatchaAutoShot")()
```
