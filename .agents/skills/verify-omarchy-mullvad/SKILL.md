---
name: verify-omarchy-mullvad
description: Verify the Omarchy Mullvad bar widget (plugin elijahrou.mullvad) end to end. Starts a private Omarchy shell with the widget from a given checkout inside a nested Hyprland, replaces the mullvad CLI with a recording stub, and drives the bar icon and keyboard panel with IPC calls, keystrokes, and pointer clicks. Use it to prove a change to Panel.qml, Service.qml, Model.js, or MullvadIcon.qml on the real surface, to compare a pull request's head with main, or to record a verdict for a pull request in this repository.
---

# Verify the Omarchy Mullvad widget

The widget is a Quickshell (QML) bar widget that the Omarchy shell (`/usr/share/omarchy/shell/shell.qml`) loads from `~/.config/omarchy/plugins/elijahrou.mullvad`. A user sees a bar icon and a keyboard-driven panel; every effect goes through the `mullvad` CLI, plus a read of `/etc/mullvad-vpn/settings.json`.

Everything here runs through one control CLI, `.agents/skills/verify-omarchy-mullvad/scripts/verify-omarchy-mullvad` (called `verify-omarchy-mullvad` below; run it by its path). The feature map is `features/README.md`.

## Isolation

The control CLI never touches the user's session, and the drives depend on that:

- It never drives, restarts, or reconfigures the user's live Omarchy shell or Hyprland, and never edits `~/.config/omarchy` or `~/.config/omarchy/plugins/elijahrou.mullvad`. Each run starts its own shell from a scratch `HOME` under `/tmp/vom.*`. The run's plugin directory is a symlink to `--checkout`.
- It never runs the real `mullvad` binary. Inside the shell's sandbox (bwrap), `scripts/stub` is bound over `/usr/bin/mullvad`, `/usr/bin/pkexec`, and `omarchy-launch-browser`, and is also first on `PATH`. The daemon's socket `/var/run/mullvad-vpn` is masked, and a run-owned directory is bound at `/etc/mullvad-vpn`, holding the stub daemon's `settings.json`. Connecting or enabling lockdown on the real daemon would block the user's network.
- Keys (`wtype`) and pointer clicks (a `zwlr_virtual_pointer_v1` client in the CLI) go only to the run's own compositor socket, by an absolute `XDG_RUNTIME_DIR` under the run directory. Never point `wtype`, `ydotool`, or `hyprctl dispatch` at the user's compositor.
- Each sandbox sees render nodes only (no `/dev/input`, no KMS cards), has no network, and has `/run/user` and `/run/dbus` masked. The shell gets a private D-Bus session bus that can activate nothing.

## Launch

```sh
verify-omarchy-mullvad launch --checkout <plugin checkout> --allow-host-window
```

Launch does this:

1. It creates `/tmp/vom.XXXXXXXX/` with a scratch `HOME`. In it go a `shell.json` whose bar holds only `elijahrou.mullvad` (first-party services such as notifications, polkit, idle, and lock are disabled), the stub's state (logged in, disconnected, daemon up), and seed daemon settings from `scripts/fixtures/settings.json` (location Gothenburg, quantum-resistant on, LAN sharing on, ad blocking on).
2. It starts Hyprland in a sandbox. Aquamarine has no headless allocator, so Hyprland starts on its Wayland backend, which opens a window on the host. Launch then adds a headless output `VERIFY-1` (1280x800) and removes the host-window output, so the window exists for well under a second and host input never reaches the run. `--allow-host-window` accepts that flash, and launch refuses without it.
3. It starts the run's D-Bus bus, then `qs --path /usr/share/omarchy/shell` in the shell sandbox.

The readiness signal is the line `ready run=<id> status='Disconnected'`. It is printed only once the widget's IPC `status` answers with a settled state (not `Checking…`) and the bar's layer surface `omarchy-bar` is mapped. On failure launch prints `FAIL launch: <reason>` and the run's log directory.

## Doctor

```sh
verify-omarchy-mullvad doctor [--run <id>] [--strict-toolchain]
```

Doctor is read-only. It checks that the compositor, bus, and shell sandboxes are running by recorded PID, that the compositor's only output is `VERIFY-1` and its config has no errors, and that the shell's Quickshell instance belongs to this run and is not one of the user's instances. It also checks that the plugin directory resolves to `--checkout` and that the checkout's revision is unchanged since launch. Last, it checks that IPC answers, that the shell's `mullvad` calls reach the stub, and that every drive tool is installed. It writes `doctor-<time>.json` to the evidence directory and ends with `ok doctor` or `FAIL doctor`.

Doctor also runs the toolchain comparison that Dev loop defines.

## Drive

```sh
verify-omarchy-mullvad drive <feature> [--run <id>] [--repeat N]
```

Each feature in `features/` has one drive target. A drive seeds the stub daemon (the stub is the daemon, so this is seed data, not a widget setter), refreshes the widget through its `refresh` IPC call, and then acts the way a user does:

- IPC: `qs ipc` into this run's instance (`open`, `close`, `toggle`, `refresh`, `connect`, `disconnect`, `toggleConnection`, `status`).
- Keys: the README's panel keys (`j`/`k`, arrows, `Return`, `space`, `c`, `r`, `/`, `l`/`h`, `Escape`) and typed text.
- Pointer: left, right, and middle clicks on the bar icon, which the CLI finds from bar pixels without assuming the glyph, and on panel rows, found by their OCR text.

Every drive ends with one line: `PASS <feature>`, `FAIL <feature>: <check>`, or `SKIP <feature>: <missing prerequisite>`.

For diagnosis, the same levers are available one at a time:

```sh
verify-omarchy-mullvad ipc status
verify-omarchy-mullvad keys j j Return
verify-omarchy-mullvad keys --text /
verify-omarchy-mullvad click --icon --button right
verify-omarchy-mullvad click --text Albania
verify-omarchy-mullvad shot --ocr
verify-omarchy-mullvad calls --last 10
```

## Evidence

Each run gets one evidence directory, `~/.local/state/verify-omarchy-mullvad/evidence/<run id>/` (or `--evidence-root <dir>/<run id>/`). It sits outside the checkout and outside everything cleanup removes. It holds:

- `launch.json`, plus `doctor-*.json` with the toolchain report.
- `<feature>/<n>/` for each drive attempt, never overwritten. Each holds numbered screenshots, the OCR text beside each one, `steps.json` (every action and check), `calls.json` (the stub's recorded argv, the side-effect proof), and `result.json`. `bar-icon` adds `icon-stats.json`.
- `run-logs/` (compositor, bus, and shell logs) and `run-stub/` (the stub's state and full call log), both copied at cleanup.

Proof standards:

- Drive the user's path. That means IPC, keys, and clicks, never internal setters.
- Prove each action by its effect on the boundary, using the stub's argv and the stub daemon's `settings.json`, and by what the user sees: the IPC `status` hero text, OCR of the panel, and screenshots.
- The stub is a mock at the production boundary: the CLI is the widget's only path to the daemon. A pass proves the widget's behavior against the CLI's documented output shapes, not the real daemon's.
- Evidence never holds account identifiers, IPs, or locations of the user. Drives use the fake account `1111222233334444`, documentation IPs (192.0.2.0/24, 203.0.113.0/24), and invented places (`Testville, Testland`). The real daemon is never queried. Before committing or attaching any evidence, scan it (`grep -rE '[0-9]{16}' <dir>` finds only the fake account).

## Cleanup

```sh
verify-omarchy-mullvad cleanup [--run <id>]
```

Cleanup signals each sandbox's PID-namespace init and its bwrap parent by recorded PID, never by name. Killing the namespace init ends every process inside it. Cleanup then checks that no process mentions the run directory in its command line or environment. It copies logs and stub state into the evidence, deletes `/tmp/vom.*` and the run record, and keeps the evidence. It prints `cleaned run=<id>; evidence kept at <dir>`, or `FAIL cleanup` with the leftover PIDs.

## Control CLI

`verify-omarchy-mullvad --help`, and `--help` on each subcommand, show real examples. The subcommands:

- `launch`, `doctor`, `drive <feature>`, `cleanup`: the sections above.
- `all --checkout <path> --allow-host-window`: launch, doctor, every feature, and cleanup, which runs even after a failure. It ends with `all: P passed, F failed, S skipped` and exits 0 only when no feature failed and cleanup succeeded.
- `test --checkout <path>`: the repository's node tests (Dev loop).
- `map-check`: checks `features/` against `features/README.md` and the drive targets. `scripts/validate` runs it.
- `ipc`, `keys`, `click`, `shot`, `calls`: single levers for diagnosis.

Every input is a flag or argument, and nothing prompts.

## Dev loop

- `verify-omarchy-mullvad test --checkout <path>` runs `node tests/model.test.js` in the checkout with the host's node, the same toolchain the drives use. It reports how many test functions the file calls. The file calls its tests directly and has no filter, so `--filter` is refused with that explanation.
- `verify-omarchy-mullvad drive <feature> --repeat N` runs the drive N times, each in its own `<feature>/<n>/` directory. It prints `repeat: k of N passed`, plus the check where each failing run stopped. Fewer than N passes means state leaks between runs or the drive is flaky. Diagnose that; never add retries.
- Toolchain comparison: Doctor compares node versions pinned in `.nvmrc`, `.node-version`, or `node-version:` in `.github/workflows/*.yml` with the host's `node --version`, and reports each mismatch with its file. A mismatch is a warning (exit 0), because the fix is the host or the pin. It fails Doctor only under `--strict-toolchain`. `doctor --toolchain-only --checkout <path>` runs just this comparison against any checkout. The repository pins no node version today, and Doctor says so.

## Verdict rules

A change to this skill's verdict rules (this `SKILL.md`, or the proof and skip rules in `features/README.md`) sets this repository's verification policy and never passes on its own: its verdict is `verifier-blocked`, and it lands only by countersign (the `babysit-and-ship` skill's Countersign rule). Both files are policy paths `agentic verify --help` lists, so `agentic verify record` refuses any other passing verdict for them. A change only to feature files or drive scripts takes an ordinary verdict: trunk's copy of this skill decides it, and the reviewer treats a removed or loosened check as a finding.

For other pull requests:

- `live-ui-verified` requires `all --checkout <PR head worktree>` with no feature failing, plus a drive of every feature whose files the change touches. Run the same drives with `--checkout` on main as the regression lane. Cite the evidence directory.
- A feature that fails on main and on the PR head at the same check is a pre-existing failure. It does not block a pull request that does not touch that feature. The verdict's evidence names it.
- A `SKIP` never counts as a pass for its feature. A pull request that changes a skipped feature is `verifier-blocked` until the prerequisite exists.
- A change only to `Model.js` or `tests/` needs `test` to pass, plus a drive of every feature that renders the changed function. A change only to docs needs `scripts/validate`, and its verdict is `type-check-only`.
- Any failed check on the PR head that passes on main is `verifier-failed`.

## Gotchas

- `/etc/mullvad-vpn/settings.json` is a hardcoded path in `Service.qml`. The run binds its own directory there inside the shell's sandbox, without changing product code. That needs `/etc/mullvad-vpn` to exist on the host (it does wherever the daemon is installed), and launch fails with that message otherwise.
- The real daemon is never exercised. What the stub does not model (relay selection, real tunnel errors, account expiry on the server) stays unverified.
- Wayland socket paths must fit in 108 bytes, so run directories live at `/tmp/vom.*` rather than under `$TMPDIR`.
- Proof here runs on the developer's host, which is the real target, but in a nested compositor with a headless output rather than on a physical monitor. Fractional scaling and multi-monitor placement of the panel are not covered.
