local mainMod = "SUPER"
local terminal = "uwsm app -- xfce4-terminal"

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 3,
    border_size = 1,
    layout = "dwindle",
    col = {
      active_border = "rgba(5294e2ff)",
      inactive_border = "rgba(383c4aff)",
    },
  },
  input = {
    kb_layout = "us",
    -- Match the important half of the existing .Xmodmap: Caps -> Ctrl.
    -- Right-Ctrl -> Caps remains X11-only for now.
    kb_options = "ctrl:nocaps",
    repeat_rate = 20,
    repeat_delay = 200,
  },
  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = { enabled = false },
    shadow = { enabled = false },
  },
  animations = {
    enabled = true,
  },
  dwindle = {
    preserve_split = true,
    smart_resizing = true,
    split_width_multiplier = 1.0,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    vfr = true,
  },
  binds = {
    workspace_back_and_forth = true,
  },
})

-- Connector-agnostic fallback. The startup helper below upgrades the
-- 3440x1440 display to the refresh closest to the old 144 Hz setup.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Preserve the old i3 workspace intent.
hl.window_rule({ match = { class = "(?i)^xfce4-terminal$" }, workspace = "1" })
hl.window_rule({ match = { class = "(?i)^firefox$" }, workspace = "2" })
hl.window_rule({ match = { class = "(?i)^steam$" }, workspace = "3" })
hl.window_rule({ match = { class = "(?i)^thunar$" }, workspace = "4" })
hl.window_rule({ match = { class = "(?i)^emacs$" }, workspace = "5" })

-- Float the same sort of utility/dialog applications that i3 floats.
for _, class in ipairs({
  "(?i)^yad$",
  "(?i)^galculator$",
  "(?i)^xsane$",
  "(?i)^pavucontrol$",
  "(?i)^qt5ct$",
  "(?i)^blueberry.*$",
  "(?i)^bluetooth-sendto$",
  "(?i)^pamac-manager$",
}) do
  hl.window_rule({ match = { class = class }, float = true })
end

-- Startup mirrors the useful parts of the i3 session, but uses native
-- Wayland tools. UWSM owns the session lifecycle and XDG autostart.
local function configure_desktop_monitor()
  hl.exec_cmd("hypr-display-setup")
end

hl.on("hyprland.start", function()
  configure_desktop_monitor()
  hl.exec_cmd("uwsm app -- waybar")
  hl.exec_cmd("uwsm app -- mako")
  hl.exec_cmd("uwsm app -- swaybg -c '#08052b'")
  hl.exec_cmd("uwsm app -- swayidle -w timeout 600 hyprlock before-sleep hyprlock")
  hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
  hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
  hl.exec_cmd("sleep 2 && uwsm app -- xfce4-terminal")
  hl.exec_cmd("sleep 7 && uwsm app -- firefox")
end)

-- Re-run connector-agnostic mode selection when a display appears.
hl.on("monitor.added", function(_)
  configure_desktop_monitor()
end)

-- Core i3-like keybindings.
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("uwsm stop"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.reload_config())
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.reload_config())

hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + B", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + O", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + DOWN", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + UP", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "r" }))

hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + LEFT", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + DOWN", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + UP", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + RIGHT", hl.dsp.window.move({ direction = "r" }))

hl.bind(mainMod .. " + H", hl.dsp.layout("preselect r"))
hl.bind(mainMod .. " + V", hl.dsp.layout("preselect d"))
hl.bind(mainMod .. " + E", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.focus({ last = true }))

-- Hyprland groups are the closest analogue to i3 tabbed/stacked
-- containers. Both old keys intentionally toggle the same group mode.
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + S", hl.dsp.group.toggle())

hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

for i = 1, 10 do
  local key = tostring(i % 10)
  local workspace = tostring(i)
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("uwsm app -- rofi -modi drun -show drun -config $HOME/.config/rofi/rofidmenu.rasi -run-command 'uwsm app -- {cmd}'"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("uwsm app -- rofi -show window -config $HOME/.config/rofi/rofidmenu.rasi"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hypr-clipboard"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("uwsm app -- firefox"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("uwsm app -- thunar"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("$HOME/.config/i3/scripts/power-profiles"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.focus({ workspace = "empty" }))

hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind(mainMod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
hl.bind(mainMod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
