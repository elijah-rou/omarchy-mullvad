# Connection

A logged-in user turns the tunnel on and off, or reconnects it, from IPC commands, panel keys, the power row, and the power switch. The widget refuses to connect while logged out, because the daemon would then block all traffic. When the daemon is stopped, the panel offers to start it.

## Sub-features

- `ipc-connect`: the `connect`, `disconnect`, and `toggleConnection` IPC calls.
- `key-c`: `c` in the panel toggles the connection.
- `key-r`: `r` in the panel reconnects.
- `power-row`: `Return` or `space` on the power row toggles the connection.
- `power-switch`: clicking the switch in the panel header toggles the connection.
- `refuse-logged-out`: connecting while logged out runs nothing and says why.
- `daemon-down`: the panel shows `Start mullvad-daemon`, and activating it runs `pkexec systemctl enable --now mullvad-daemon`.

## How to get to it (user POV)

- Run `omarchy-shell elijahrou.mullvad connect`, `disconnect`, or `toggleConnection`.
- Open the panel and press `c` to toggle or `r` to reconnect.
- Open the panel, move to the top row, and press `Return` or `space`.
- Open the panel and click the switch beside `Mullvad VPN`.
- With the daemon stopped, open the panel and activate `Start mullvad-daemon`.

## Driving it with verify-omarchy-mullvad

Preconditions:

- Drive target: `verify-omarchy-mullvad drive connection`.
- `verify-omarchy-mullvad doctor` passes for this run.
- The stub daemon is at the baseline: logged in and disconnected. The drive seeds it.

- **IPC.** `verify-omarchy-mullvad ipc connect` records `mullvad connect` and gives status `Connected`. `ipc disconnect` records `mullvad disconnect` and gives `Disconnected`. Two `ipc toggleConnection` calls do the same pair.
- **Keys.** After `ipc open`, `verify-omarchy-mullvad keys --text c` records `mullvad connect` and gives `Connected`. `keys --text r` records `mullvad reconnect`. `keys --text c` records `mullvad disconnect`.
- **Power row.** Move the cursor to the top with `keys j k k …`, then `keys Return` records `mullvad connect`, and `keys space` records `mullvad disconnect`.
- **Power switch.** The drive takes the pixels on the `Mullvad VPN` title row, right of the title, that change between the disconnected and connected panel screenshots. That is the switch. Clicking its centre records `mullvad connect`, and clicking again records `mullvad disconnect`.
- **Refused while logged out.** With the stub logged out (status `Not logged in`), `ipc open` then `ipc connect` shows `Log in to a Mullvad account first` in the panel (OCR). The stub records no `mullvad connect` within 1.5 seconds, and status stays `Not logged in`.
- **Daemon down.** With the stub daemon down (status `Daemon is not running`), the panel shows `Start mullvad-daemon`. `keys j` then `keys Return` records `pkexec systemctl enable --now mullvad-daemon`. The stub records pkexec and runs nothing.

## Gotchas

- The widget ignores a new action while the previous `mullvad` process runs, so the drive waits briefly after each recorded call before the next action.
- The logged-out message is a flash that clears after about 2.6 seconds. Read it right after the call.
- When the daemon comes back, the widget restarts `mullvad status --json listen` up to 5 seconds later. The drive's baseline calls `ipc refresh`, which restarts it at once.
