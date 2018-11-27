function hammerspoon -d "Send a command to the Hammerspoon process"
    set command $argv[1]
    set urlstring 'hammerspoon://'
    echo $urlstring$command'?' | read urlstring

    set loopcount 0
    set is_param 1
    for i in $argv
        if test $loopcount -gt 0
            if test $is_param -gt 0
                echo -n $urlstring$i'=' | read urlstring
                set is_param 0
            else
                echo -n $urlstring$i'&' | read urlstring
                set is_param 1
            end
        end

        echo (math $loopcount+1) | read loopcount
    end

    open $urlstring
end
