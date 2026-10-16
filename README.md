# Spam Macro

A small interactive auto-clicker / key spammer for Windows, written in PowerShell. It sends mouse clicks and key presses at a speed you choose, toggled by a hotkey.

## Usage

Double-click `spam.cmd`, or run it from a terminal:

```
spam.cmd
```

Menu options:

| Option | What it does |
| --- | --- |
| 1) Toggle key | Hotkey that turns spamming on and off (default `F6`) |
| 2) Mode | `Toggle` (press to start/stop) or `Hold` (active while held) |
| 3) Speed | Cycles per second, `0` = as fast as possible |
| 4) Mouse | Left, Right, or None |
| 5) Keys | Keys to spam each cycle, e.g. `G,F,E` |
| 6) Quit key | Stops the macro and returns to the menu (default `End`) |

Press `S` to start. Settings are saved to `config.json` next to the script.

## Requirements

Windows with PowerShell 5.1 or newer. No install needed.

## Notes

Input is sent with `SendInput`. Some games with anti-cheat may block or flag automated input, so use it at your own risk.
