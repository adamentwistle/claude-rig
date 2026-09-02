#!/usr/bin/env bash
# Symlink this repo's files into place. Safe to re-run; existing real files are backed up as *.bak-<date>.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude-work}"
stamp="$(date +%Y%m%d-%H%M%S)"

link() { # link <repo-relative> <target>
  local src="$R/$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then mv "$dst" "$dst.bak-$stamp"; echo "backed up $dst"; fi
  ln -sfn "$src" "$dst"; echo "linked $dst"
}

# Configs bake in absolute paths for the machine they were last installed on.
# Rewrite any /Users/<name>/... to this machine's actual home before linking.
fixpaths() { # fixpaths <repo-relative>
  local f="$R/$1"
  local home_esc="${HOME//\\/\\\\}"
  home_esc="${home_esc//&/\\&}"
  sed -i '' -E "s#/Users/[^/[:space:]\"]+#$home_esc#g" "$f"
}
for f in ccstatusline/settings.json claude/settings-snippets.json ghostty/config; do fixpaths "$f"; done

link ghostty/config            "$HOME/.config/ghostty/config"
link ghostty/themes            "$HOME/.config/ghostty/themes"
link ghostty/shaders           "$HOME/.config/ghostty/shaders"
link ccstatusline/settings.json "$HOME/.config/ccstatusline/settings.json"
link ccstatusline/usage-bar.py  "$HOME/.config/ccstatusline/usage-bar.py"
for f in ccs-theme spinner-pack streaks.py usage-guard; do link "claude/bin/$f" "$CFG/bin/$f"; done
for f in spinner.md theme.md;              do link "claude/commands/$f" "$CFG/commands/$f"; done
link claude/spinner-packs      "$CFG/spinner-packs"

echo
echo "Now merge claude/settings-snippets.json into $CFG/settings.json (statusLine, spinnerVerbs, hooks),"
echo "install ccstatusline (bun add -g ccstatusline@2.2.27), and reload Ghostty with cmd+shift+,."
echo "Absolute paths in the configs were rewritten to $HOME."
