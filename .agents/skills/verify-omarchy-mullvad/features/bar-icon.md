# Bar icon

The bar shows the Mullvad mark. It is full strength while the tunnel is up and half transparent while it is off. Problem states take the urgent colour: a tunnel error with the tunnel up is full urgent, and lockdown blocking traffic while the tunnel is off is half-transparent urgent, so dimmer than the tunnel error. A red warning badge marks logged out, daemon down, and every problem state. The panel's hero shows the same mark, half transparent while the tunnel is off and urgent on a problem, but badges only problem states. Clicking the icon opens the panel, connects or disconnects, or reconnects.

## Sub-features

- `icon-active`: the full-strength mark with no badge while connected.
- `icon-off`: the half-transparent mark with no badge while disconnected.
- `icon-warning`: the half-transparent mark with a warning badge while logged out.
- `icon-tunnel-error`: the full urgent mark with a badge while the tunnel errors and stays up.
- `icon-lockdown`: the half-transparent urgent mark with a badge while lockdown blocks traffic with the tunnel off.
- `icon-daemon-down`: the half-transparent mark with a warning badge while the daemon is not running.
- `hero-icon`: the panel hero's mark dims while off, turns urgent on a problem, and carries no badge while logged out.
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

- **Seed each state.** The drive seeds the stub daemon, then waits for IPC `status`: connected gives `Connected`, disconnected gives `Disconnected`, logged out gives `Not logged in`, a tunnel error gives `Error · blocking all traffic`, lockdown on gives `Lockdown is blocking traffic`, and daemon down gives `Daemon is not running`. It takes a screenshot of the bar in each state (`icon-<state>.png`), and of the open panel in each state but daemon down (`hero-<state>.png`).
- **Find the icons.** The bar icon's box is the bounding box of the pixels in the bar's right section that differ from the bar's background in the connected screenshot. The hero icon's box is the bounding box of the pixels just left of the OCR'd `Mullvad VPN` title that differ from the panel's background. The drive uses each box for every state.
- **Compare states.** All comparisons run, and a failure names every one that failed. They are written to `icon-stats.json`:
  - Off differs from active, and its mean foreground luma is at least 10 lower.
  - Tunnel error's whole mark is at least 15 redder than active's.
  - Lockdown's whole mark is at least 15 redder than off's, and its mean luma is at least 10 lower than tunnel error's.
  - Warning's and daemon down's bottom-right quadrant is at least 15 redder than off's.
  - Hero: off is at least 10 dimmer than active, tunnel error at least 15 redder than active, lockdown at least 15 redder than off and at least 10 dimmer than tunnel error, and logged out's bottom-right quadrant is not 15 redder than off's (no badge).
- **Left click.** `verify-omarchy-mullvad click --icon` makes the layer `omarchy-keyboard-panel` appear (`hyprctl layers`). A second left click removes it.
- **IPC panel calls.** `verify-omarchy-mullvad ipc open`, then `close`, `toggle`, and `toggle` again, open, close, open, and close the panel.
- **Right click.** `verify-omarchy-mullvad click --icon --button right` makes the stub record `mullvad connect`, and status becomes `Connected`. A middle click records `mullvad reconnect`. A second right click records `mullvad disconnect`, and status becomes `Disconnected`.

## Gotchas

- A pointer left over the icon draws a hover fill that changes its pixels. The drive parks the pointer at (60, 760) before each screenshot.
- The icon checks are relative between states, so a new glyph or theme keeps them valid. A change that makes two states look the same fails them, and that failure is intended. On c993533, before the Mullvad mark, lockdown was as strong as a tunnel error, and the check that lockdown is dimmer fails there.
- A problem's badge sits on an urgent mark, so the badge quadrant cannot tell a hero badge from the mark's own colour. The hero check covers only the badge's absence while logged out.
- The redness thresholds rely on the shell's default theme urgent colour (`#a55555`), which the scratch `HOME` uses because it has no theme. Under a theme whose urgent colour is not red, these checks would need another channel.
