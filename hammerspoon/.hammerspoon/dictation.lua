-- Dictation Module
--
-- REQUIRES: macOS Dictation shortcut configured to Cmd-Shift-T.
--   System Settings > Keyboard > Dictation > Shortcut > Customize,
--   then press Cmd-Shift-T.
--
-- Controls macOS dictation by sending that global keyboard shortcut.
-- Going via the shortcut (rather than the Edit > Start/Stop Dictation
-- menu items) avoids a ~1s menu-state lag that made the menu-driven
-- approach fail intermittently right after a stop.

local dictation = {}

local log = hs.logger.new('dictation', 'debug')

local DICTATION_HOTKEY_MODS = { "cmd", "shift" }
local DICTATION_HOTKEY_KEY = "t"
local STOP_PATTERN = "Stop Dictation"
local STOP_DELAY_SECONDS = 0.15
local RIGHT_SHIFT_KEYCODE = hs.keycodes.map.rightshift or 60
local rightShiftPushToTalkTap = nil
local rightShiftDown = false
local rightShiftStartedDictation = false

local function frontApp()
    return hs.application.frontmostApplication()
end

local function sendDictationHotkey()
    log.f("sending dictation hotkey cmd-shift-t")
    hs.eventtap.keyStroke(DICTATION_HOTKEY_MODS, DICTATION_HOTKEY_KEY, 0)
end

-- Best-effort: queries the foreground app's Edit menu for "Stop Dictation".
-- macOS lags this update by ~1s after a state change, so treat as advisory
-- (fine for the streamdeck button image, not for control decisions).
function dictation.isDictating()
    local app = frontApp()
    if not app then return false end
    return app:findMenuItem(STOP_PATTERN, true) ~= nil
end

-- start/stop/toggle all just send the toggle hotkey. With a toggle-style
-- shortcut there's no way to address an absolute state, but exposing all
-- three names keeps callers ergonomic.
function dictation.toggle()
    sendDictationHotkey()
end

function dictation.start()
    sendDictationHotkey()
end

function dictation.stop()
    sendDictationHotkey()
end

function dictation.init()
    if rightShiftPushToTalkTap then
        rightShiftPushToTalkTap:stop()
    end

    rightShiftPushToTalkTap = hs.eventtap.new({
        hs.eventtap.event.types.flagsChanged,
    }, function(event)
        local flags = event:getFlags()
        local keycode = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
        if keycode ~= RIGHT_SHIFT_KEYCODE then
            return false
        end

        local isRightShiftDown = flags.shift == true

        if isRightShiftDown and not rightShiftDown then
            rightShiftDown = true
            rightShiftStartedDictation = not dictation.isDictating()

            if rightShiftStartedDictation then
                dictation.start()
            end

            return true
        elseif rightShiftDown and not isRightShiftDown then
            rightShiftDown = false

            if rightShiftStartedDictation then
                rightShiftStartedDictation = false
                hs.timer.doAfter(STOP_DELAY_SECONDS, function()
                    dictation.stop()
                end)
            end

            return true
        end

        return false
    end)

    rightShiftPushToTalkTap:start()
end

return dictation
