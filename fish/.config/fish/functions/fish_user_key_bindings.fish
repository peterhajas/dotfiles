function fish_user_key_bindings
    bind \cg 'forward-char'
    if type -q sessionize
        bind \cf 'sessionize'
    end
end
