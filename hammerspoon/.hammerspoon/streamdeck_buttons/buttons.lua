require 'profile'

-- Updates `button`
function updateButton(button, context)
    -- nil-checking
    if button == nil then return end
    local buttonName = button['name'] or "button"
    profileStart('buttonUpdate_' .. buttonName)
    local isStatic = button['image'] ~= nil
    local currentState = {}
    if isStatic then
        button['_lastImage'] = button['image']
    else
        local isDirty = false
        local stateProvider = button['stateProvider']
        if stateProvider == nil then
            isDirty = true
        else
            currentState = stateProvider() or { }
            local lastState = button['_lastState'] or { }
            isDirty = not equals(currentState, lastState, false)
            button['_lastState']  = currentState
        end
        if isDirty then
            local context = context or { }
            context['state'] = currentState
            local image = button['imageProvider'](context)
            button['_lastImage'] = image
        end
    end
    profileStop('buttonUpdate_' .. buttonName)
end

-- Returns an update timer for button, if appropriate, and start it
function updateTimerForButton(button, updateFunction)
    local updateInterval = button['updateInterval']
    if updateInterval == nil then return nil end
    local timer = hs.timer.new(updateInterval, updateFunction)
    timer:start()
    return timer
end
