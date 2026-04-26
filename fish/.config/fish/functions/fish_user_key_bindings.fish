function fish_user_key_bindings
    if type -q sessionize
        bind \cf 'sessionize'
    end
    if type -q cdg
        bind \cg cdg
    end
end
