# phajas dotfiles

## rocking since 2014

A "dotfile" is a configuration file for a computer program.

I have a bunch of these. They all live here.

## Install

1. Clone this repository into your home directory:

        cd
        git clone https://github.com/peterhajas/dotfiles.git

2. Go to the `dotfiles` directory:

        cd dotfiles

3. Run `update.sh`. You may need to give it proper permissions:

        cd dotfiles
        chmod a+x update.sh
        sh update.sh

## Colors

- Colors live at `colors/.config/colors/palette.toml` (defaults/hosts) and `colors/.config/colors/palettes/*.toml` (per-family palettes).
- Regenerate terminal/Neovim artifacts (Ghostty themes + `phajas_palette` colorscheme) with `python3 colors/.config/colors/build.py` (run automatically by `setup.yml` before stow).
- Per-machine stow overrides in `setup.yml` do not affect palette generation; the build step always runs so any hosts that stow Ghostty/Neovim get the fresh colors. Host-specific defaults are supported via `[hosts.<hostname>]` in `colors/.config/colors/palette.toml`, e.g.:

      [hosts.nyx]
      default_variant = "modus_vivendi"

- Light/dark: both variants are always generated. Ghostty points `theme = dark:phajas_dark,light:phajas_light` (stable names, independent of the variant keys), and Neovim chooses the variant by macOS appearance; host overrides only change the default when no flavor match is found.
- Extend to other apps by adding outputs inside `colors/.config/colors/build.py` alongside the Ghostty and Neovim writers.
- Neovim always loads the generated `phajas_palette` (see `nvim/.config/nvim/lua/phajas/plugins/theme.lua`); macOS appearance is polled to pick light/dark.
- Licensing: palette and generated artifacts are GPL v3 via Modus/Ef; the license text lives at `colors/.config/colors/LICENSE`.

That's it! If you had any configuration files, `stow` should leave them alone and not stomp on them. If you'd like to uninstall specific apps, you can do so by running `stow -D APPNAME` in the `dotfiles` directory. To install them again, run `stow APPNAME`.

## Third-Party Components

This repository includes the following GPL-licensed components:

- **Modus** by Miika Nissi (adapted from Protesilaos Stavrou)
  - Palette data: `colors/.config/colors/palettes/modus.toml` contains Modus-derived values; all generated artifacts from it (Ghostty themes, `phajas_palette` Neovim colorscheme, and any other outputs you add) inherit GPL v3 obligations.
  - Location: generated Ghostty themes (`ghostty/.config/ghostty/themes/phajas_light` and `ghostty/.config/ghostty/themes/phajas_dark`) plus the Neovim colorscheme (`nvim/.config/nvim/colors/phajas_palette.lua`)
  - License: GPL v3 (see `colors/.config/colors/LICENSE`; keep that file with any redistribution of the palette or generated artifacts)
  - Source: https://github.com/miikanissi/modus-themes.nvim
- **Ef Themes** by Protesilaos Stavrou
  - Palette data: `colors/.config/colors/palettes/ef_*.toml` contains Ef-derived values; all generated artifacts from it inherit GPL v3 obligations.
  - License: GPL v3 (see `colors/.config/colors/LICENSE`)
  - Source: https://github.com/protesilaos/ef-themes
- **Catppuccin** by Catppuccin Org
  - Palette data: `colors/.config/colors/palettes/catppuccin.toml` contains Catppuccin-derived values; generated artifacts that include those palettes follow MIT terms.
  - License: MIT (see `colors/.config/colors/LICENSE-catppuccin`)
  - Source: https://github.com/catppuccin/catppuccin

## License

Third-party components retain their original licenses as indicated in their respective directories.

---

Questions? Comments? `emacs`? I'm [@peterhajas](http://twitter.com/peterhajas).
