---
name: verify-omarchy-mullvad
description: Verify the Omarchy Mullvad bar widget (plugin elijahrou.mullvad) end to end. Starts a private Omarchy shell with the widget from a given checkout inside a nested Hyprland, replaces the mullvad CLI with a recording stub, and drives the bar icon and keyboard panel with IPC calls, keystrokes, and pointer clicks. Use it to prove a change to Panel.qml, Service.qml, Model.js, or MullvadIcon.qml on the real surface, to compare a pull request's head with main, or to record a verdict for a pull request in this repository.
---

# Verify the Omarchy Mullvad widget

The skill lives at `.agents/skills/verify-omarchy-mullvad/SKILL.md`. Read that file and follow it. Its control CLI, scripts, and feature map sit beside it.

This file is a copy of that skill's frontmatter for Claude Code discovery. It is not a symlink because `omarchy plugin validate` (which `omarchy plugin add` and `update` run) refuses any symlink in a plugin folder, and this repository is the plugin folder. `scripts/validate` fails when the two frontmatters differ.
