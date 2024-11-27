let metrics = import ./metrics.nix; in
{
    enable = true;
    settings = {
        location = "center";
        prompt = "";
        insensitive = true;
        gtk_dark = true;
    };
    style = ''
        * {
            font-family: "${metrics.font}", monospace;
            font-size: 32px;
            color: ${metrics.colors.fg1};
        }

        window {
            border-width: ${metrics.sizes.border}px;
            border-color: ${metrics.colors.fg1};
            border-style: solid;
            background-color: ${metrics.colors.bg1};
        }

        #input {
            border-radius: 0px;
            border: 0px;
            color: ${metrics.colors.bg2};
            background-color: ${metrics.colors.fg1};
        }

        #selected *,
        #selected {
            color: ${metrics.colors.bg1};
            background-color: ${metrics.colors.fg1};
        }

        #inner-box {
            margin: 0px;
            border: none;
            background-color: transparent;
        }

        #outer-box {
            margin: 0px;
            border: none;
            background-color: transparent;
        }

        #entry,
        #entry focus,
        #entry selected {
            border: none;
            background-color: transparent;
        }

        #entry focus,
        #entry selected {
            color: ${metrics.colors.bg1};
        }
    '';
}
