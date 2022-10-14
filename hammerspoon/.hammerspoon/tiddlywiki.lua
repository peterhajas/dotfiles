require "util"

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    local app = hs.application'TiddlyDesktop'
    local show = false

    if app == nil then
        show = true
    elseif app:isHidden() then
        show = true
    elseif not app:isFrontmost() then
        show = true
    end

    if show then
        hs.application.launchOrFocus('TiddlyDesktop')
    else
        app:hide()
    end
end)
