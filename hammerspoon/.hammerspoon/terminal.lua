function runInNewTerminal(command, exitAfterwards)
    local effectiveCommand = command
    if exitAfterwards then
        effectiveCommand = command .. " && exit"
    end

    hs.application.open("com.mitchellh.ghostty")
    hs.eventtap.keyStroke({"cmd"}, "n")
    hs.eventtap.keyStrokes(effectiveCommand)
    hs.eventtap.keyStroke({}, "return")
end
