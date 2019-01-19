-- Emoji Picker
-- Loosely based on https://aldur.github.io/articles/hammerspoon-emojis/

-- Build the list of emoji from the json file
local emojiPath = "emoji.json"
local openedFile = io.open(emojiPath)
local decoded = hs.json.decode(openedFile:read())

local choices = {}

for _, emoji in ipairs(decoded) do
    local hintText = table.concat(emoji["kwds"], ", ")
    hintText = emoji["name"] .. " " .. hintText
    table.insert(choices,
    {
        text = emoji["chars"],
        subText = hintText,
        characters = emoji["chars"]
    })
end

hs.hotkey.bind(hyper, "e", function()
    local chooser = hs.chooser.new(function(picked)
        if not picked then return end
        hs.pasteboard.setContents(picked["characters"])
    end)

    chooser:width(20)

    chooser:choices(choices)
    chooser:searchSubText(true)

    chooser:show()
end)
