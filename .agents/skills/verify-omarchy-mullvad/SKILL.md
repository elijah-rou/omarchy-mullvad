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

Pass that `<id>` as `--run <id>` to every later command. Runs coexist, so a command without `--run` picks the run only while it is the only one; with several, it refuses and names them.

## Doctor

```sh
verify-omarchy-mullvad doctor --run <id> [--strict-toolchain]
```

Doctor is read-only. It checks that the compositor, bus, and shell sandboxes are running by recorded PID, that the compositor's only output is `VERIFY-1` and its config has no errors, and that the shell's Quickshell instance belongs to this run and is not one of the user's instances. It also checks that the plugin directory resolves to `--checkout` and that the checkout's revision is unchanged since launch. Last, it checks that IPC answers, that the shell's `mullvad` calls reach the stub, and that every drive tool is installed. It writes `doctor-<time>.json` to the evidence directory and ends with `ok doctor` or `FAIL doctor`.

Doctor also runs the toolchain comparison that Dev loop defines.

## Drive

```sh
verify-omarchy-mullvad drive <feature> --run <id> [--repeat N]
```

Each feature in `features/` has one drive target. A drive seeds the stub daemon (the stub is the daemon, so this is seed data, not a widget setter), refreshes the widget through its `refresh` IPC call, and then acts the way a user does:

- IPC: `qs ipc` into this run's instance (`open`, `close`, `toggle`, `refresh`, `connect`, `disconnect`, `toggleConnection`, `status`).
- Keys: the README's panel keys (`j`/`k`, arrows, `Return`, `space`, `c`, `r`, `/`, `l`/`h`, `Escape`), typed text, and held keys, which the run's compositor autorepeats after 600 ms at 25 per second.
- Pointer: left, right, and middle clicks on the bar icon, which the CLI finds from bar pixels without assuming the glyph, and on panel rows, found by their OCR text.

Every drive ends with one line: `PASS <feature>`, `FAIL <feature>: <check>`, or `SKIP <feature>: <missing prerequisite>`.

For diagnosis, the same levers are available one at a time:

```sh
verify-omarchy-mullvad ipc status --run <id>
verify-omarchy-mullvad keys j j Return --run <id>
verify-omarchy-mullvad keys --text / --run <id>
verify-omarchy-mullvad click --icon --button right --run <id>
verify-omarchy-mullvad click --text Albania --run <id>
verify-omarchy-mullvad shot --ocr --run <id>
verify-omarchy-mullvad calls --last 10 --run <id>
```

## Evidence

Each run gets one evidence directory, `~/.local/state/verify-omarchy-mullvad/evidence/<run id>/` (or `--evidence-root <dir>/<run id>/`). It sits outside the checkout and outside everything cleanup removes. It holds:

- `launch.json`, plus `doctor-*.json` with the toolchain report.
- `results.txt`: one line per drive attempt (`<feature>/<n> PASS|FAIL|SKIP ...`, with the checkout's revision), and `all`'s summary line. It lists every failed check of the run in one file.
- `<feature>/<n>/` for each drive attempt, never overwritten. Each holds numbered screenshots, the OCR text beside each one, `steps.json` (every action and check), `calls.json` (the stub's recorded argv, the side-effect proof), and `result.json`. `bar-icon` adds `icon-stats.json` (bar and panel hero).
- `run-logs/` (compositor, bus, and shell logs) and `run-stub/` (the stub's state and full call log), both copied at cleanup.

Proof standards:

- Drive the user's path. That means IPC, keys, and clicks, never internal setters.
- Prove each action by its effect on the boundary, using the stub's argv and the stub daemon's `settings.json`, and by what the user sees: the IPC `status` hero text, OCR of the panel, and screenshots.
- The stub is a mock at the production boundary: the CLI is the widget's only path to the daemon. A pass proves the widget's behavior against the CLI's documented output shapes, not the real daemon's.
- Evidence never holds account identifiers, IPs, or locations of the user. Drives use the fake account `1111222233334444`, documentation IPs (192.0.2.0/24, 203.0.113.0/24), and invented places (`Testville, Testland`). The real daemon is never queried. Before committing or attaching any evidence, scan it (`grep -rE '[0-9]{16}' <dir>` finds only the fake account).

## Cleanup

```sh
verify-omarchy-mullvad cleanup --run <id>
```

Cleanup signals each sandbox's PID-namespace init and its bwrap parent by recorded PID, never by name, and only after `/proc/<pid>/cmdline` or `environ` shows the PID still names the run directory. A record left by a crash or reboot can hold PIDs that now belong to other processes; cleanup leaves those alone and prints `skipped ...` for each. Killing the namespace init ends every process inside it. Cleanup then checks that no process mentions the run directory in its command line or environment. It copies logs and stub state into the evidence, deletes the run's `/tmp/vom.*` directory (if it still exists) and the run record, and keeps the evidence. It prints `cleaned run=<id>; evidence kept at <dir>`, or `FAIL cleanup` with the leftover PIDs.

## Control CLI

`verify-omarchy-mullvad --help`, and `--help` on each subcommand, show real examples. The subcommands:

- `launch`, `doctor`, `drive <feature>`, `cleanup`: the sections above.
- `all --checkout <path> --allow-host-window`: launch, doctor, every feature, and cleanup, which runs even after a failure. It drives and cleans up only the run it launched, whatever other runs exist. When launch or doctor fails it drives nothing: every feature gets `SKIP <feature>: not driven, launch failed` (or `doctor failed`). It ends with `all: P passed, F failed, S skipped` (plus `; not driven: <reason>` when nothing was driven) and exits 0 only when every feature passed and cleanup succeeded.
- `test --checkout <path>`: the repository's node tests (Dev loop).
- `map-check`: checks `features/` against `features/README.md` and the drive targets. `scripts/validate` runs it.
- `ipc`, `keys`, `click`, `shot`, `calls`: single levers for diagnosis.

Every input is a flag or argument, and nothing prompts.

## Dev loop

- `verify-omarchy-mullvad test --checkout <path>` runs `node tests/model.test.js` in the checkout with the host's node, the same toolchain the drives use. It reports how many test functions the file calls. The file calls its tests directly and has no filter, so `--filter` is refused with that explanation.
- `verify-omarchy-mullvad drive <feature> --repeat N` runs the drive N times, each in its own `<feature>/<n>/` directory. It prints `repeat: k of N passed`, plus the check where each failing run stopped. Fewer than N passes means state leaks between runs or the drive is flaky. Diagnose that; never add retries.
- Toolchain comparison: Doctor compares node versions pinned in `.nvmrc`, `.node-version`, or `node-version:` in `.github/workflows/*.yml` with the host's `node --version`, and reports each mismatch with its file. A mismatch is a warning (exit 0), because the fix is the host or the pin. It fails Doctor only under `--strict-toolchain`. `doctor --toolchain-only --checkout <path>` runs just this comparison against any checkout. The repository pins no node version today, and Doctor says so.

## Verdict rules

A change to this skill's verdict rules (this `SKILL.md`, the proof and skip rules in `features/README.md`, or the `.claude/skills/verify-omarchy-mullvad/SKILL.md` pointer, which could point at other rules) sets this repository's verification policy and never passes on its own: its verdict is `verifier-blocked`, and it lands only by countersign (the `babysit-and-ship` skill's Countersign rule). All three are policy paths `agentic verify --help` lists, so `agentic verify record` refuses any other passing verdict for them. A change only to feature files or drive scripts takes an ordinary verdict: trunk's copy of this skill decides it, and the reviewer treats a removed or loosened check as a finding.

Run this skill from trunk against the head (`all --checkout <PR head worktree>`); the head's skill may only add evidence for behavior trunk's skill does not cover, after the verifier reads its new steps as code. A pull request that deliberately changes a checked expectation in both the product and the skill (for example the bar icon's states, as #1 did) never passes on the head's skill alone, since trunk's skill still fails it; the verdict list below decides between `verifier-blocked` and `verifier-failed`. A pull request that adds behavior, or changes what a drive asserts, adds or changes the drive step that shows it in the same pull request.

Which features a change touches. A path matches the first row that names it. A change whose diff, read in full, alters only comments is docs-only whatever file it is in.

| Changed paths | Features touched | Needed |
| --- | --- | --- |
| `.agents/skills/verify-omarchy-mullvad/`, `.claude/skills/verify-omarchy-mullvad/` | every feature | trunk's skill's `all` on the head, plus the head's skill's `all` on the head |
| `Panel.qml`, `Service.qml`, `Model.js`, `manifest.json` | every feature: these files serve all of them | `all` on the head and on main; `test` too for `Model.js` |
| `MullvadIcon.qml` | `bar-icon` | `all` on the head and on main |
| `tests/` | none | `test` on the head |
| `README.md`, `AGENTS.md`, `LICENSE`, comment-only changes | none | a read of the diff, and `scripts/validate` on the head |
| anything else, including `scripts/validate` and `.gitignore` | not mapped | none exists: `verifier-blocked` |

Results:

- A drive stops at its first failed check, so a failed feature hides the checks after it.
- `all` that cannot launch, or whose doctor fails, drives nothing: every feature is `SKIP <feature>: not driven, ...`. Such a run is evidence for no feature, on main or on the head, and never a pre-existing failure. Fix the run and run `all` again.
- A feature that fails on main and on the head at the same check is a pre-existing failure.

Verdicts:

- `live-ui-verified`: `all` on the head with trunk's skill passes every feature the change touches, none of them SKIPs, and every other feature passes too or is a pre-existing failure the change does not touch; `all` on main is the regression lane. Any behavior the change adds or changes appears in a drive step's evidence. Cite both evidence directories and their `results.txt`, and name each pre-existing failure.
- `unit-test-verified`: a change only to `tests/` has `test` passing on the head and a read of its diff finding no removed or loosened assertion; or a docs-only change (`README.md`, `AGENTS.md`, `LICENSE`, comments) has a read of the diff confirming it matches the pull request's stated intent and changes no code, plus `scripts/validate` passing on the head. Name the read and the runs in the evidence.
- `verifier-blocked`: a feature the change touches SKIPs or was not driven and cannot be driven; the change touches a feature that has a pre-existing failure and does not fix it (that feature has no passing drive, since the failure hides its later checks), with the evidence naming the failure; the change touches a path the table does not map; the change touches a policy path; or trunk's skill fails only checks that the pull request deliberately changes in both the product and the skill, the head's skill passes them, and nothing else fails. The evidence then names each such check (from trunk's run's `results.txt`, which lists every drive's result line and, for `bar-icon`, every failed comparison) and the pull request's stated reason for changing it. The head's skill's run covers the checks after each one, and the verifier reads the skill's diff to confirm it changes only the named expectations. Policy changes and such deliberate changes land only by countersign: the user decides.
- `verifier-failed`: a needed drive, `test`, or `scripts/validate` fails on the head for any reason the `verifier-blocked` bullet does not name, including a check that passes on main and fails on the head, and a check trunk's skill fails that the pull request does not deliberately change in both the product and the skill.

## Gotchas

- `/etc/mullvad-vpn/settings.json` is a hardcoded path in `Service.qml`. The run binds its own directory there inside the shell's sandbox, without changing product code. That needs `/etc/mullvad-vpn` to exist on the host (it does wherever the daemon is installed), and launch fails with that message otherwise.
- The real daemon is never exercised. What the stub does not model (relay selection, real tunnel errors, account expiry on the server) stays unverified.
- Wayland socket paths must fit in 108 bytes, so run directories live at `/tmp/vom.*` rather than under `$TMPDIR`.
- Proof here runs on the developer's host, which is the real target, but in a nested compositor with a headless output rather than on a physical monitor. Fractional scaling and multi-monitor placement of the panel are not covered.
