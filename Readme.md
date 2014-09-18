# phajas dotfiles

## If you see a setting, they blew it

A "dotfile" is a configuration file for a computer program.

I have a bunch of these. They all live here.

## Install

1. Clone this repository into your home directory
2. `cd` into the `dotfiles` directory
3. Run `sh update.sh`. You may need to `chmod a+x update.sh`

That's it! If you had any configuration files, `stow` should leave them alone and not stomp on them. If you'd like to uninstall specific apps, you can do so by running `stow -D APPNAME` in the `dotfiles` directory. To install them again, run `stow APPNAME`.

Questions? Comments? `emacs`? I'm [@peterhajas](http://twitter.com/peterhajas).
