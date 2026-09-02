# claude-rig

The look-and-feel layer for Claude Code on this Mac: status line, themes, Ghostty shaders,
spinner verb packs, and the streaks/achievements board. Files are symlinked into place by
`install.sh`; edit them here.

## Layout

| Path | What |
|---|---|
| `ghostty/config` | Ghostty config: theme line plus the four `custom-shader` lines at the bottom |
| `ghostty/themes/Nightshade` | Custom Nightshade theme: moss green `#76ea6a`, purple `#a17af2`, violet-tinted charcoal `#24222c` |
| `ghostty/shaders/` | `starfield`, `cursor-trail`, `bloom`, `crt` (aberration off). Knobs are the `const` lines at the top of each |
| `ccstatusline/settings.json` | ccstatusline layout (three lines, powerline). Read from `~/.config/ccstatusline/` with no `--config` flag |
| `ccstatusline/usage-bar.py` | Usage bars with pace marker and end-of-window projection; `session`, `weekly`, `fable` |
| `claude/bin/ccs-theme` | `/theme`: switches Ghostty theme, status line chips, bar palette, cursor-trail colour, starfield background together |
| `claude/bin/spinner-pack` | `/spinner`: verb packs. `rotate` is called by a SessionStart hook and cycles `spinner-packs/rotation.json` |
| `claude/bin/usage-guard` | UserPromptSubmit hook: when a usage window is on course to run out and its reset is >30m away, adds one line asking Claude to economise. `--check` shows the verdict |
| `claude/bin/streaks.py` | Streaks and achievements. `show` prints the board; hooks feed it; the widget renders the badge |
| `claude/commands/` | The `/theme` and `/spinner` slash commands |
| `claude/settings-snippets.json` | The parts of `~/.claude-work/settings.json` this rig needs (statusLine, spinnerVerbs, hooks). Merge by hand |

## Things that bite

- The invisible `extra-usage-used` widget at the end of status line 1 is what makes ccstatusline
  call the usage API. Fable's weekly number only refreshes because of it. Do not delete it.
- ccstatusline reads the macOS keychain item `Claude Code-credentials` first. If that item exists
  with an empty access token, ccstatusline serves a stale cache forever. Delete the item.
- Paths inside the configs are absolute. `install.sh` rewrites `/Users/<anyone>/...` to your `$HOME` before linking.
- Ghostty reloads config and shaders with cmd+shift+, . There is no shader validator on the box;
  a broken shader shows up in `log show --predicate 'process == "ghostty"' --last 5m`.
- State that is deliberately not in the repo: `~/.claude-work/streaks/state.json`,
  `~/.config/ccstatusline/palette.json`, `~/.config/ccstatusline/.theme`, `spinner-packs/.active`.
