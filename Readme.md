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

That's it! If you had any configuration files, `stow` should leave them alone and not stomp on them. If you'd like to uninstall specific apps, you can do so by running `stow -D APPNAME` in the `dotfiles` directory. To install them again, run `stow APPNAME`.

## Third-Party Components

This repository includes the following GPL-licensed components:

- **Modus** by Miika Nissi (adapted from Protesilaos Stavrou)
  - Location: `ghostty/.config/ghostty/themes/modus_operandi` and `ghostty/.config/ghostty/themes/modus_vivendi`
  - License: GPL v3 (see `ghostty/.config/ghostty/themes/LICENSE`)
  - Source: https://github.com/miikanissi/modus-themes.nvim
  - No modifications made

## License

Third-party components retain their original licenses as indicated in their respective directories.

---

Questions? Comments? `emacs`? I'm [@peterhajas](http://twitter.com/peterhajas).
