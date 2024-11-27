let metrics = import ./metrics.nix; in
{
    enable = true;
    settings.rightBar = {
        height = metrics.sizes.barWidth;
        position = "top";
        modules-left = [
            "wlr/taskbar"
        ];
        modules-center = [

        ];
        modules-right = [
            "clock"
            "battery"
        ];
        clock = {
            format = "{:%H:%M}";
            format-alt = "{:%F}";
        };
        battery = {
            format = "{capacity}%";
        };
        "wlr/taskbar" = {
            icon-size = 50;
            format = "{title:.10}";
            on-click = "activate";
            on-click-right = "close";
        };
    };
    style = ''
    * {
        font-family: "${metrics.font}", monospace;
        font-size: 16px;
        color: ${metrics.colors.fg1};
        border-radius: 0px;
    }

    #tray > *:hover {
        color: ${metrics.colors.bg1};
        background-color: ${metrics.colors.fg1};
    }

    window#waybar {
        background-color: ${metrics.colors.bg1};
        margin: 8px;
    }

    #taskbar button {
        opacity: 0.5;
    }

    #taskbar button.active {
        color: ${metrics.colors.bg1};
        background-color: ${metrics.colors.fg1};
    }

    #taskbar button:hover {
        color: ${metrics.colors.bg1};
        background-color: ${metrics.colors.fg1};
    }
    '';
}
