# phajas dotfiles

## If you see a setting, they blew it

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

Questions? Comments? `emacs`? I'm [@peterhajas](http://twitter.com/peterhajas).
