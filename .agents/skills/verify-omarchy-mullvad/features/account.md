# Account

A user logs in with a 16-digit account number, which reaches `mullvad` over stdin and never appears in argv. Once logged in, the user can copy the number, open the account page, and log out after confirming. A logged-out user can create an account after confirming. While logged out, the panel offers recovery rows when traffic is blocked: Disconnect for a tunnel the daemon holds up, and the Lockdown mode switch.

## Sub-features

- `login`: typing the number and pressing `Return` logs in over stdin.
- `copy`: activating the masked number copies it to the clipboard.
- `manage`: `Manage account` opens `https://mullvad.net/account` in the browser.
- `logout`: `Log out` needs a second press, then disconnects and logs out.
- `create`: `Create a new account` needs a second press, then creates one.
- `recovery-lockdown`: logged out with lockdown on, the Lockdown mode row turns it off.
- `recovery-blocked`: logged out with a blocking tunnel error, the Disconnect row stops the tunnel.

## How to get to it (user POV)

- Open the panel while logged out. The `Account number` field has focus. Type the number and press `Return`.
- Open the panel while logged in, move to the account rows under `ACCOUNT`, and press `Return`.
- While logged out, press `Down` from the field to reach `Log in` and `Create a new account`, or `Up` to reach the recovery rows.

## Driving it with verify-omarchy-mullvad

Preconditions:

- Drive target: `verify-omarchy-mullvad drive account`.
- `verify-omarchy-mullvad doctor` passes for this run.
- The stub daemon is logged out and disconnected. The drive seeds it.

- **Log in.** After `ipc open` (the panel shows `LOG IN` and `Create a new account`), `keys --text "1111 2222 3333 4444"` then `keys Return` records `mullvad account login`. The stub reports that stdin held the test number, and status becomes `Disconnected`. No recorded argv anywhere holds the number.
- **Masked number.** On the account rows, the panel shows `4444`, `ACCOUNT`, and `Verify Mole`, and not `1111`.
- **Copy.** `keys Return` on the number shows `Account number copied`, and `wl-paste` in the run's compositor returns the number.
- **Manage.** `keys Return` on `Manage account` records `omarchy-launch-browser https://mullvad.net/account`.
- **Log out.** `keys Return` on `Log out` shows `Press again to log out` and records no logout. A second `keys Return` records `mullvad disconnect`, then `mullvad account logout`, and status becomes `Not logged in`.
- **Create.** Logged out, `keys Down Down` then `keys Return` shows `Press again to create an account` and records nothing. A second `keys Return` records `mullvad account create`, and status becomes `Disconnected`.
- **Recovery with lockdown.** Logged out with lockdown on (status `Lockdown is blocking traffic`), the panel shows `Lockdown mode` above `LOG IN`. `keys Up` then `keys Return` records `mullvad lockdown-mode set off`, and status becomes `Not logged in`.
- **Recovery with a blocking error.** Logged out with the tunnel in a blocking error (status `Error · blocking all traffic`), the panel shows `Stop the tunnel so traffic flows again`. `keys Up` then `keys Return` records `mullvad disconnect`, and status becomes `Not logged in`.

## Gotchas

- The logged-out panel focuses the text field, which takes `j` and `k` as text. Move with `Up` and `Down` there.
- The test number `1111222233334444` is fake, and only the stub accepts it. Never type a real account number into a run.
- Confirmations reset after 3 seconds. Press the second time within that window.
