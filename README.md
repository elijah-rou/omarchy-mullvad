# Omarchy Mullvad

A Mullvad VPN widget for the [Omarchy](https://omarchy.org) bar. It shows the
tunnel state in the bar and opens a keyboard-driven panel. From the panel you
can log in, connect, pick a country or city, and change the daemon's main
settings. It works the same way as Omarchy's built-in Tailscale and Wi-Fi
panels.

The widget is a front end for the `mullvad` CLI. It never talks to Mullvad's
servers itself.

## Requirements

- Omarchy with its Quickshell-based shell
- The Mullvad daemon and CLI, with the daemon running. On Arch, `mullvad-vpn-daemon`
  in `extra` has just the daemon and CLI. `mullvad-vpn` also includes the desktop
  app.

```sh
omarchy pkg add mullvad-vpn-daemon
sudo systemctl enable --now mullvad-daemon
```

If the daemon is not running, the panel offers to start it through polkit.

## Install

```sh
omarchy plugin add https://github.com/elijah-rou/omarchy-mullvad.git --enable
```

The widget is added to the right side of the bar. Move it with
`omarchy bar move elijahrou.mullvad --section <left|center|right>`.

For development, link a checkout instead:

```sh
ln -s ~/Projects/omarchy-mullvad ~/.config/omarchy/plugins/elijahrou.mullvad
omarchy-shell shell rescanPlugins
```

## Use

| Input | Action |
| --- | --- |
| Left click | Open the panel |
| Right click | Connect or disconnect |
| Middle click | Reconnect |

In the panel:

- `j`/`k` or the arrow keys move the cursor
- `Enter` or `Space` activates the selected row
- `c` connects or disconnects, and `r` reconnects
- `/` opens the location search, where `l`/`h` expand and collapse a country
- `Tab` switches to the neighboring bar panel

The panel has four sections:

- **Status:** the connection state, the server, and the visible location and IP.
- **Location:** countries and cities from `mullvad relay list`. Picking one while
  you are disconnected also connects.
- **Settings:** auto-connect, lockdown mode, local network sharing, multihop,
  DAITA, quantum-resistant tunnel, in-tunnel IPv6, and DNS content blockers.
- **Account:** the masked account number (click to copy), the time left, a link
  to manage the account on mullvad.net, and logout.

The widget also exposes IPC commands, so you can bind them to keys:

```sh
omarchy-shell elijahrou.mullvad toggleConnection
omarchy-shell elijahrou.mullvad status
```

The other commands are `open`, `close`, `toggle`, `connect`, `disconnect`, and
`refresh`.

## Behavior worth knowing

- **Connecting while logged out.** If you connect without an account, the daemon
  blocks all traffic until you log in or disconnect. The widget refuses to
  connect while you are logged out.
- **Blocked traffic while logged out.** If traffic is blocked anyway, by lockdown
  mode or a tunnel error, the panel says so before anything else. Disconnect and
  the lockdown toggle stay available without logging in.
- **Your account number.** The number goes to `mullvad account login` over stdin,
  so it never appears in the process list. The widget doesn't save it anywhere,
  and it clears the login field when the panel closes.
- **Live updates.** Tunnel state streams from `mullvad status --json listen`.
  Settings come from the daemon's world-readable
  `/etc/mullvad-vpn/settings.json`, which the widget watches for changes.

## Provenance

The panel structure, keyboard handling, and bar integration follow Omarchy's
built-in Tailscale panel (MIT). The upstream copyright notice is kept in
`LICENSE`.

## Development

Run `./scripts/validate`. It validates the manifest, runs the model tests under
node, and runs `qmllint` on the QML. The tests read no machine state.
