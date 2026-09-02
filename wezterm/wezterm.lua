-- claude-rig WezTerm config (Windows). Installed by install.ps1 as ~/.wezterm.lua.
-- Mirrors the Mac Ghostty config: herdr owns the layout, zero padding, no close
-- confirmation, mouse hidden while typing, and the theme follows /theme.
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()
local home = wezterm.home_dir

-- ---------------------------------------------------------------- shell
-- PowerShell 7 with the profile loaded. The Store build has no
-- C:/Program Files/PowerShell/7/pwsh.exe, so fall back to the PATH alias.
local function find_pwsh()
  local msi = 'C:/Program Files/PowerShell/7/pwsh.exe'
  if #wezterm.glob(msi) > 0 then
    return msi
  end
  return 'pwsh.exe'
end
local pwsh = find_pwsh()

local projects = 'E:/dev/projects'
if #wezterm.glob(projects) == 0 then
  projects = home
end

config.default_prog = { pwsh, '-NoLogo' }
config.default_cwd = projects

-- ---------------------------------------------------------------- theme
-- Nightshade: deep violet charcoal with moss-green and lilac accents
-- (same palette as ghostty/themes/Nightshade).
config.color_schemes = {
  Nightshade = {
    foreground = '#e8e6ef',
    background = '#24222c',
    cursor_bg = '#76ea6a',
    cursor_fg = '#24222c',
    cursor_border = '#76ea6a',
    selection_bg = '#443f54',
    selection_fg = '#f3f1f8',
    ansi = { '#312d3b', '#f0655f', '#5fcf55', '#e5c46a', '#6fa8f5', '#a17af2', '#5fd7d0', '#cfcbd8' },
    brights = { '#736d82', '#ff7b75', '#76ea6a', '#f2d57f', '#8bbcff', '#b995ff', '#7de8e1', '#f3f1f8' },
    tab_bar = {
      background = '#24222c',
      active_tab = { bg_color = '#3a3646', fg_color = '#e8e6ef' },
      inactive_tab = { bg_color = '#24222c', fg_color = '#736d82' },
      inactive_tab_hover = { bg_color = '#312d3b', fg_color = '#e8e6ef' },
      new_tab = { bg_color = '#24222c', fg_color = '#736d82' },
      new_tab_hover = { bg_color = '#312d3b', fg_color = '#e8e6ef' },
    },
  },
}

-- /theme (claude/bin/ccs-theme) writes the active theme name to this marker.
-- WezTerm watches it and reloads, so the terminal and status line switch together.
local THEMES = {
  ['nightshade'] = 'Nightshade',
  ['rose-pine'] = 'rose-pine',
  ['kanagawa-wave'] = 'Kanagawa (Gogh)',
  ['kanagawa-dragon'] = 'Kanagawa Dragon (Gogh)',
  ['catppuccin-mocha'] = 'Catppuccin Mocha',
}
local marker = home .. '/.config/ccstatusline/.theme'
wezterm.add_to_config_reload_watch_list(marker)
local function active_theme()
  local f = io.open(marker, 'r')
  if not f then
    return 'nightshade'
  end
  local name = (f:read('*l') or ''):gsub('%s+$', '')
  f:close()
  return name
end
config.color_scheme = THEMES[active_theme()] or 'Nightshade'

-- ---------------------------------------------------------------- look
config.font = wezterm.font 'JetBrains Mono' -- bundled with WezTerm, Nerd glyphs fall back automatically
config.font_size = 11.5
config.line_height = 1.08
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.window_background_opacity = 0.97
config.win32_system_backdrop = 'Acrylic'
config.initial_cols = 145
config.initial_rows = 40
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_button_style = 'Windows'
config.default_cursor_style = 'SteadyBar'
config.cursor_blink_rate = 0
config.hide_mouse_cursor_when_typing = true

-- herdr draws its own tabs and panes; keep WezTerm's chrome out of the way.
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 35

-- ---------------------------------------------------------------- behaviour
config.scrollback_lines = 100000
config.enable_scroll_bar = false
config.audible_bell = 'Disabled'
config.adjust_window_size_when_changing_font_size = false
config.automatically_reload_config = true
config.check_for_updates = false -- nightly build; update by hand
config.window_close_confirmation = 'NeverPrompt'
config.exit_behavior = 'CloseOnCleanExit'
config.enable_kitty_keyboard = true -- herdr and Claude Code use the kitty keyboard protocol

-- ---------------------------------------------------------------- herdr
local herdr = home .. '/AppData/Local/Programs/Herdr/bin/herdr.exe'

config.launch_menu = {
  { label = 'herdr', args = { herdr }, cwd = projects },
  { label = 'PowerShell 7', args = { pwsh, '-NoLogo' }, cwd = projects },
  { label = 'Claude Code', args = { pwsh, '-NoLogo', '-NoExit', '-Command', 'claude' }, cwd = projects },
  { label = 'Git Bash', args = { 'C:/Program Files/Git/bin/bash.exe', '--login', '-i' }, cwd = projects },
  { label = 'Command Prompt', args = { 'cmd.exe' } },
}

-- ---------------------------------------------------------------- keys
-- ctrl+alt chords are deliberately unbound: herdr uses them.
-- Ctrl+Space is a tmux-style leader for WezTerm's own panes (rarely needed with herdr).
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1500 }

config.keys = {
  -- herdr in a new tab
  { key = 'h', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewTab { args = { herdr }, cwd = projects } },

  -- clipboard
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },

  -- WezTerm tabs
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
  { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },

  -- WezTerm panes (leader, then key)
  { key = '\\', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'LeftArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Up', 3 } },
  { key = 'DownArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Down', 3 } },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },

  -- search, palette, launcher, reload
  { key = 'f', mods = 'CTRL|SHIFT', action = act.Search { CaseInSensitiveString = '' } },
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
  { key = 'l', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS|TABS|WORKSPACES|COMMANDS' } },
  { key = 'r', mods = 'CTRL|SHIFT', action = act.ReloadConfiguration },
}

-- Alt+1..8 select WezTerm tabs (herdr's workspace jump is ctrl+alt+1..9).
for i = 1, 8 do
  table.insert(config.keys, { key = tostring(i), mods = 'ALT', action = act.ActivateTab(i - 1) })
end

-- Ctrl-click opens links.
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL', action = act.OpenLinkAtMouseCursor },
}

return config
