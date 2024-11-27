let metrics = import ./metrics.nix; in
{
    enable = true;
    settings = {
        font = {
            normal = {
                family = metrics.font;
            };
            size = 16;
        };
        colors = {
            primary = {
                foreground = metrics.colors.fg1;
                background = metrics.colors.bg1;
                dim_foreground = metrics.colors.shadow;
            };
            normal = {
                blue = metrics.colors.fg1;
                cyan = metrics.colors.fg1;
                green = metrics.colors.fg1;
                magenta = metrics.colors.fg1;
                red = metrics.colors.fg1;
                white = metrics.colors.fg1;
                yellow = metrics.colors.fg1;
            };
            bright = {
                blue = metrics.colors.fg1;
                cyan = metrics.colors.fg1;
                green = metrics.colors.fg1;
                magenta = metrics.colors.fg1;
                red = metrics.colors.fg1;
                white = metrics.colors.fg1;
                yellow = metrics.colors.fg1;
            };
            dim = {
                blue = metrics.colors.fg1;
                cyan = metrics.colors.fg1;
                green = metrics.colors.fg1;
                magenta = metrics.colors.fg1;
                red = metrics.colors.fg1;
                white = metrics.colors.fg1;
                yellow = metrics.colors.fg1;
            };
        };
    };
}
