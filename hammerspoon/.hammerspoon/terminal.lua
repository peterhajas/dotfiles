function runInNewTerminal(command, exitAfterwards)
    hs.application.open("com.apple.Terminal")
    hs.eventtap.keyStroke({"cmd"}, "n")
    hs.eventtap.keyStrokes(command)
    hs.eventtap.keyStroke({}, "return")
    if exitAfterwards then
        hs.eventtap.keyStrokes("exit")
        hs.eventtap.keyStroke({}, "return")
    end
end
