function config_diff_merge_tool
    ## Default diff/merge tool is vimdiff

    set diffMergeTool "vimdiff"

    if test -d /Applications/Kaleidoscope.app
        ## But if we have ksdiff, let's use that
        set PATH $PATH /Applications/Kaleidoscope.app/Contents/Resources/bin;
        set diffMergeTool "Kaleidoscope"
    end

    git config --global diff.tool $diffMergeTool
    git config --global merge.tool $diffMergeTool
end
