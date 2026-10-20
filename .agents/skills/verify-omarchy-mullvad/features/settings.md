# Settings

A logged-in user switches the daemon's settings from the panel: auto-connect, lockdown mode, local network sharing, multihop, DAITA, quantum-resistant tunnel, and in-tunnel IPv6. The user also chooses DNS content blockers, which are disabled while a custom DNS server is set. Each switch reflects the daemon's `settings.json`, not a value the widget keeps.

## Sub-features

- `toggle-keyboard`: `Return` and `space` on each of the seven setting rows run the matching `mullvad` command in both directions.
- `toggle-click`: clicking a setting row toggles it.
- `lockdown-status`: lockdown on while disconnected shows `Lockdown is blocking traffic`.
- `multihop-detail`: multihop on labels the Location row `Exit location · multihop on`.
- `dns-blockers`: the DNS row expands six blockers, and each toggles through `mullvad dns set default` with the full flag set.
- `dns-custom`: under custom DNS the row says so, and its blockers run nothing.

## How to get to it (user POV)

- Open the panel, move to a row under `SETTINGS`, and press `Return` or `space`.
- Click a setting row.
- Activate `DNS content blockers` to expand it, then activate a blocker.

## Driving it with verify-omarchy-mullvad

Preconditions:

- Drive target: `verify-omarchy-mullvad drive settings`.
- `verify-omarchy-mullvad doctor` passes for this run.
- The stub daemon is logged in and disconnected with the seed settings, and the DNS list is collapsed. The drive seeds the settings and collapses the list.

- **Each setting, both ways.** For rows 3 to 9, the drive moves the cursor to the row. `keys Return` records the command that flips the row's current value, for example `mullvad auto-connect set on`, `mullvad lan set block`, or `mullvad tunnel set quantum-resistant off`. `settings.json` then shows the new value. `keys space` records the reverse command, and `settings.json` shows the original value.
- **Lockdown status.** While lockdown is on, status is `Lockdown is blocking traffic`.
- **DNS blockers.** On `DNS content blockers`, `keys Return` expands the list. Walking the cursor to the last blocker shows `Ads`, `Trackers`, `Malware`, `Gambling`, `Adult content`, and `Social media`. On `Trackers`, `keys Return` records `mullvad dns set default --block-ads --block-trackers`, and `settings.json` shows trackers blocked. `keys Return` again records `mullvad dns set default --block-ads`. Back on the DNS row, `keys Return` collapses the list, which then reads `1 on`.
- **Custom DNS.** With the stub's DNS state set to `custom`, the panel shows `Custom DNS is set`. Expanding the list and pressing `Return` on `Ads` records no `mullvad dns` call within 1.5 seconds.
- **Click.** `verify-omarchy-mullvad click --text Multihop` records `mullvad relay set multihop on`, and the panel shows `Exit location · multihop on`. A second click records `mullvad relay set multihop off`.

## Gotchas

- The panel keeps the DNS list expanded across close and open, and an expanded list shifts every row below it. The drive reads the panel and collapses the list before counting rows.
- `settings.json` is the run's own copy, bound at `/etc/mullvad-vpn` inside the shell's sandbox. The stub replaces it atomically, the way the daemon does, so the widget's file watch sees each change.
- Wait for `settings.json` to change before pressing the row again. Otherwise the second press sends the same command.
