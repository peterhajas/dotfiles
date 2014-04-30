function config_editor_aliases
    set editor "vim"
    if test -f ~/bin/mvim
        set editor "mvim"
    end
    
    # Muscle memory is strong

    alias mate $editor
    alias subl $editor
    alias mvim $editor
end
