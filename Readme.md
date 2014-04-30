# dotfiles

These are the configuration files I use on my computer. I've collected them
here to make it easier to sync them between machines. Additionally, I think
they will be useful to others crafting their own setups.

## Install

1. Clone this repository into your home directory
2. `cd` into the `dotfiles` directory
3. Run `sh update.sh`. You may need to `chmod a+x update.sh`

That's it! If you had any configuration files, `stow` should leave them alone and not stomp on them. If you'd like to uninstall specific apps, you can do so by running `stow -D APPNAME` in the `dotfiles` directory. To install them again, run `stow APPNAME`.

Questions? Comments? I'm [@peterhajas](http://twitter.com/peterhajas).
