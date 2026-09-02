# claude-rig

The look-and-feel layer for Claude Code on this Mac: status line, themes, Ghostty shaders,
spinner verb packs, and the streaks/achievements board. Files are symlinked into place by
`install.sh`; edit them here.

## Install with an agent

Paste this to Claude Code (or any coding agent) along with the repo URL. It is written to be
followed verbatim; the human only needs to answer the two questions in step 2 and reload Ghostty.

```text
Install the claude-rig terminal setup from <REPO_URL>. Follow these steps exactly and tell me
before doing anything outside them.

1. Prerequisites. Check each and install what is missing: macOS with Ghostty (brew install --cask ghostty),
   bun (curl -fsSL https://bun.sh/install | bash), python3, and ccstatusline pinned to 2.2.27
   (bun add -g ccstatusline@2.2.27). Confirm `which ccstatusline` prints a path.
2. Ask me two things: (a) which Claude config dir I use — default is ~/.claude; the repo assumes
   ~/.claude-work — and (b) whether I already have a ~/.config/ghostty/config or
   ~/.claude*/settings.json you must preserve. Do not guess.
3. git clone <REPO_URL> ~/Projects/claude-rig and cd into it.
4. In ccstatusline/settings.json and claude/settings-snippets.json, replace every
   `.claude-work` with my config dir name from step 2a if it differs. Leave /Users/<name> paths
   alone; install.sh rewrites those.
5. Run: CLAUDE_CONFIG_DIR=<my config dir> ./install.sh
   It symlinks files into ~/.config/ghostty, ~/.config/ccstatusline and <config dir>/{bin,commands,spinner-packs},
   backing up any real file it displaces as *.bak-<date>. Show me the output.
6. Merge claude/settings-snippets.json into <config dir>/settings.json: statusLine, spinnerVerbs,
   and the hooks (PostToolUse, PostToolUseFailure, SessionStart, UserPromptSubmit). Append to hook
   arrays that already exist, never overwrite them. Fix the statusLine command to `which ccstatusline`.
7. Verify: `ghostty +validate-config` exits 0; `<config dir>/bin/usage-guard --check` prints a verdict;
   `<config dir>/bin/streaks.py show` prints a board; `echo '{}' | ccstatusline` prints three lines.
8. Tell me to reload Ghostty with cmd+shift+, and start a new Claude Code session. Then run
   /theme list and /spinner list so I can pick.

If ccstatusline shows stale usage numbers, read "Things that bite" in README.md before changing anything.
Do not edit files under ~/Projects/claude-rig except as described in step 4.
```

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
