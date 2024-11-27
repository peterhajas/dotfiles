let metrics = import ./metrics.nix; in
{
    enable = true;
    extraConfig = ''
# rotate display
monitor=,preferred,auto,2,transform,3
# rotate touchscreen
input {
    touchdevice {
        transform = 3
    }
}

exec = gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"   # for GTK3 apps
exec = gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"   # for GTK4 apps
env = QT_QPA_PLATFORMTHEME,qt6ct   # for Qt apps

exec-once = "magick convert -size 1920x1200 xc:'${metrics.colors.bg1}' ~/bg.png"
exec-once = waybar
exec-once = hyprpaper

env = XCURSOR_SIZE,${metrics.sizes.cursor}
env = HYPRCURSOR_SIZE,${metrics.sizes.cursor}

general { 
    gaps_in = 8
    gaps_out = 16
    border_size = ${metrics.sizes.border}

    col.active_border = rgb(0f380f)
    col.inactive_border = rgb(306230)

    resize_on_border = true 

    no_border_on_floating = true

    allow_tearing = true

    layout = dwindle
}

decoration {
    rounding = 0

    active_opacity = 1.0
    inactive_opacity = 0.64

    dim_strength = 0.16

    col.shadow = rgb(306230)
    drop_shadow = true
    shadow_range = 0
    shadow_render_power = 4
    shadow_offset = 8 8

    blur {
        enabled = false
    }
}

animations {
    enabled = ${metrics.animation.enabled}
    bezier = ${metrics.animation.linear}
    animation = global, 1, ${metrics.animation.duration}, linear
}

misc { 
    force_default_wallpaper = 0
    disable_hyprland_logo = true
}

input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1

    touchpad {
        natural_scroll = true
    }
}

gestures {
    workspace_swipe = true
}

$mainMod = SUPER

bind = $mainMod, Return, exec, alacritty
bind = $mainMod, x, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, f, togglefloating,
bind = $mainMod, d, exec, wofi --show drun
bind = $mainMod, Space, exec, wofi --show drun
bind = $mainMod, Escape, exec, hyprlock
bindl=,switch:Lid Switch, exec, hyprlock

bind = $mainMod, h, movefocus, l
bind = $mainMod, l, movefocus, r
bind = $mainMod, k, movefocus, u
bind = $mainMod, j, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

windowrulev2 = suppressevent maximize, class:.* # You'll probably like this.
    '';
}
