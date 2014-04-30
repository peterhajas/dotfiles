function config_editor_aliases
    set editor "vim"
    if test ~/bin/mvim
        set editor "mvim"
    end
    
    # Muscle memory is strong

    alias mate $editor
    alias vim $editor
    alias subl $editor
end
