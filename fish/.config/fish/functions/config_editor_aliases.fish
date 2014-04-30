function config_editor_aliases
    set editor "vim"
    if test -f ~/bin/mvim
        set editor "mvim"
    end
    
    # Muscle memory is strong

    alias mate $editor
    alias vim $editor
    alias subl $editor
end
