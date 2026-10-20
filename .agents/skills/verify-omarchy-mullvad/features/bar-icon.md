# Bar icon

The bar shows one Mullvad icon. It is bright while the tunnel is up, dimmed and struck through while it is off, and carries a red warning badge when logged out or when the daemon is down. The whole glyph turns the urgent colour when traffic is blocked. Clicking the icon opens the panel, connects or disconnects, or reconnects.

## Sub-features

- `icon-active`: a bright glyph with no strike or badge while connected.
- `icon-off`: a dimmed, struck-through glyph while disconnected.
- `icon-warning`: a warning badge while logged out.
- `icon-problem`: the urgent colour while lockdown blocks traffic or the tunnel errors.
- `icon-daemon-down`: a warning badge with no strike while the daemon is not running.
- `click-left`: opens and closes the panel.
- `click-right`: toggles the connection.
- `click-middle`: reconnects.
- `ipc-panel`: `open`, `close`, and `toggle` over IPC.

## How to get to it (user POV)

- Look at the right side of the bar.
- Left-click the icon to open the panel, and left-click again to close it.
- Right-click the icon to connect or disconnect.
- Middle-click the icon to reconnect.
- Run `omarchy-shell elijahrou.mullvad open`, `close`, or `toggle` (bound to keys by the user).

## Driving it with verify-omarchy-mullvad

Preconditions:

- Drive target: `verify-omarchy-mullvad drive bar-icon`.
- `verify-omarchy-mullvad doctor` passes for this run.
- The panel is closed and the pointer rests away from the bar. The drive does both.

- **Seed each state.** The drive seeds the stub daemon, then waits for IPC `status`: connected gives `Connected`, then disconnected gives `Disconnected`, logged out gives `Not logged in`, lockdown on gives `Lockdown is blocking traffic`, and daemon down gives `Daemon is not running`. It takes a screenshot of each (`icon-<state>.png`).
- **Find the icon.** The icon box is the bounding box of the pixels in the bar's right section that differ from the bar's background in the connected screenshot. The drive uses that box for every state.
- **Compare states.** These comparisons are written to `icon-stats.json`:
  - Off differs from active, and its mean foreground luma is at least 10 lower.
  - Warning's bottom-right quadrant is at least 15 redder than off's.
  - Problem's whole glyph is at least 15 redder than active's.
  - Daemon down's bottom-right quadrant is at least 15 redder than off's.
- **Left click.** `verify-omarchy-mullvad click --icon` makes the layer `omarchy-keyboard-panel` appear (`hyprctl layers`). A second left click removes it.
- **IPC panel calls.** `verify-omarchy-mullvad ipc open`, then `close`, `toggle`, and `toggle` again, open, close, open, and close the panel.
- **Right click.** `verify-omarchy-mullvad click --icon --button right` makes the stub record `mullvad connect`, and status becomes `Connected`. A middle click records `mullvad reconnect`. A second right click records `mullvad disconnect`, and status becomes `Disconnected`.

## Gotchas

- A pointer left over the icon draws a hover fill that changes its pixels. The drive parks the pointer at (60, 760) before each screenshot.
- The icon checks are relative between states, so a new glyph or theme keeps them valid. A change that makes two states look the same fails them, and that failure is intended.
- The redness thresholds rely on the shell's default theme urgent colour (`#a55555`), which the scratch `HOME` uses because it has no theme. Under a theme whose urgent colour is not red, these checks would need another channel.
