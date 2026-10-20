# Omarchy Mullvad verification map

This directory is the maintained source for verifying what users of the Mullvad bar widget can do. Read this index before driving the widget, then use the matching feature file as the recipe.

## Baseline preconditions

- A run started by `verify-omarchy-mullvad launch --checkout <path> --allow-host-window` exists, and `verify-omarchy-mullvad doctor --run <id>` passes for it. Pass `--run <id>` from launch's `ready run=<id>` line to every command. Never drive an instance this run did not start.
- The widget comes from the checkout under test, through the run's scratch `HOME` (`/tmp/vom.*/home/.config/omarchy/plugins/elijahrou.mullvad`).
- The stub daemon starts logged in to the fake account `1111222233334444` (device `Verify Mole`), disconnected, and with the daemon up. Settings come from `scripts/fixtures/settings.json`: location Gothenburg, Sweden; LAN sharing on; quantum-resistant on; ad blocking on; everything else off. Its relay list (`scripts/fixtures/relay-list.txt`) has Albania (Tirana), Germany (Berlin, Dusseldorf, Frankfurt), and Sweden (Gothenburg, Malmö, Stockholm).
- Every drive seeds the state it needs and returns the stub daemon to that baseline when it ends.
- Evidence goes to `<evidence dir>/<feature>/<n>/`, which cleanup never touches.

## Driving conventions

- `verify-omarchy-mullvad drive <feature>` runs a feature's whole recipe and ends with `PASS`, `FAIL`, or `SKIP`. The labeled bullets in each feature file are the steps it takes, for diagnosis.
- Use IPC through `verify-omarchy-mullvad ipc <method>`, keys through `verify-omarchy-mullvad keys`, and clicks through `verify-omarchy-mullvad click`. All three reach only this run's compositor and shell.
- The panel's rows, top to bottom when logged in with the picker and DNS list closed: power, Location, Auto-connect, Lockdown mode, Local network sharing, Multihop, DAITA, Quantum-resistant tunnel, In-tunnel IPv6, DNS content blockers, the masked account number, Manage account, Log out. Drives reach a row by pressing `j` once (which only shows the cursor), `k` until the top, then `j` once per row.
- The panel's content scrolls. Text below the fold is visible only after the cursor has moved there, so drives move the cursor before reading text.

## Proof and skip reporting

- Capture the user action and the resulting state: the step log, a screenshot, OCR of the panel, and the IPC `status` text.
- An action on the daemon is proved by the stub's recorded argv (`calls.json`). A settings change is also proved by a second, read-only view: the stub daemon's `settings.json` and the panel's text.
- What must not happen is proved by its absence: no stub call of that kind within a stated window.
- Bar icon states are proved by comparing pixels between states (changed, dimmer, redder, badge quadrant), never by the glyph's exact pixels.
- `results.txt` in the run's evidence directory lists every drive attempt's result line, so every failed check of the run is in one file.
- Every artifact sits under the feature's attempt directory. Its `steps.json` names the entry point used for each action.
- `SKIP` is only for a missing tool the drives need (`missing_tools` in the control CLI), and names it, or, in `all`, for every feature when launch or doctor failed (`not driven, ...`), since nothing was driven. A `SKIP` never counts as a pass. A missing seed state is a `FAIL` naming the precondition.
- An entry point that cannot be reached is reported with the attempted command and the unmet precondition. It is never reported as verified through a different entry point.

## Feature file contract

Each feature file starts with an H1 title and one paragraph describing the behavior a user sees. It then has exactly four H2 sections, in this order:

1. `Sub-features`: short IDs, one line each.
2. `How to get to it (user POV)`: every entry point a user has.
3. `Driving it with verify-omarchy-mullvad`: starts with `Preconditions:`, whose first bullet names the feature's drive target, then labeled bullets pairing each user action with an exact command and its observable result.
4. `Gotchas`: traps that waste or invalidate a run.

`verify-omarchy-mullvad map-check` enforces this contract and the one-to-one match between feature files and drive targets.

## Features

- [Bar icon](./bar-icon.md): bar and panel hero icon states for connected, off, logged out, tunnel error, lockdown, and daemon down; left, right, and middle clicks; panel open, close, and toggle over IPC.
- [Connection](./connection.md): connect, disconnect, and reconnect from IPC, keys, the power row, and the power switch; refusal while logged out; starting a stopped daemon.
- [Location](./location.md): the country and city picker from the Location row and `/`, search, expand and collapse, picking by keyboard and by click, and a held `Return`.
- [Settings](./settings.md): the seven daemon settings, DNS content blockers, and blockers disabled under custom DNS.
- [Account](./account.md): logging in over stdin, copying the number, managing the account, logging out, creating an account, and the logged-out recovery rows.
