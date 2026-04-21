local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

local theme_path = os.getenv('HOME') .. '/.config/wezterm/theme.lua'
local theme_func = loadfile(theme_path)
if theme_func then
  local theme = theme_func()
  if theme then
    config.colors = theme
  end
end

config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.font_size = 10.0
config.use_ime = true
config.xim_im_name = 'fcitx'

config.enable_tab_bar = false
config.window_background_opacity = 0.9

return config