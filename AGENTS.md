# omarchy-mullvad

Instructions for coding agents working in this repository.

Standalone MIT-licensed Omarchy shell bar widget for Mullvad VPN, installed as plugin `elijahrou.mullvad`.

## Architecture

- `Panel.qml`: bar icon, panel UI, keyboard cursor, and IPC target `elijahrou.mullvad`.
- `Service.qml`: every `mullvad` CLI call, the `status --json listen` stream, and the `/etc/mullvad-vpn/settings.json` watch.
- `Model.js`: pure parsers and view-model helpers with no Qt dependency, tested under node by `tests/model.test.js`.
- `MullvadIcon.qml`: bar and hero icon, the Mullvad mark drawn natively as a `Shape` in the theme color, as the stock Tailscale and Dropbox icons draw theirs.

## Validate

Run `scripts/validate` before every commit and push: it is the one command that runs this repository's checks.

## Conventions

- Keep this file the one source of agent instructions; other instruction files import it.
- Match the stock Omarchy panels in `/usr/share/omarchy/shell/plugins/panels/` (read-only) for components, spacing, and keyboard behavior.
- Never start a tunnel while logged out: the daemon then blocks all traffic. Anything that can block traffic must stay visible and undoable without an account number.
- The account number travels over stdin or the environment, never argv, and is never persisted.
- Build shell commands as argv arrays; quote any interpolated value with `Util.shellQuote`.
- Tests are hermetic: fixtures under `tests/fixtures/`, no reads of live daemon state.
