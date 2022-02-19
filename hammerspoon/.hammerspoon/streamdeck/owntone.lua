require "owntone"
require "util"

-- A button for controlling an Owntone server
function owntoneButton(server, port)
    return {
        ['name'] = 'OwnTone ' .. server .. ' ' .. port,
        ['imageProvider'] = function(context)
            local playing = context['state']['playing']
            local playerState = context['state']['player']
            local artworkImage = context['state']['artworkImage']
            if artworkImage == nil then
                return streamdeck_imageFromText("􀒽")
            end

            local imageX = 0
            local imageY = 0
            local imageWidth = buttonWidth
            local imageHeight = buttonHeight

            if not playing then
                imageWidth = imageWidth * 0.8
                imageHeight = imageHeight * 0.8
                imageX = (buttonWidth - imageWidth) / 2
                imageY = (buttonHeight - imageHeight) / 2
            end

            local elements = { }
            table.insert(elements, {
                type = "image",
                frame = { x = imageX, y = imageY, w = imageWidth, h = imageHeight },
                image = artworkImage,
                imageScaling = 'shrinkToFit',
            })

            local progressFraction = context['state']['progressFraction']

            table.insert(elements, {
                type = "rectangle",
                frame = { x = 0, y = buttonHeight - 5, w = buttonWidth * progressFraction, h = 5 },
                action = "fill",
                fillColor = tintColor,
            })

            return streamdeck_imageWithCanvasContents(elements)
        end,
        ['onClick'] = function()
            owntonePut(server, port, "player/toggle")
        end,
        ['onLongPress'] = function(held)
            if held then
                owntonePut(server, port, "player/next")
            end
        end,
        ['updateInterval'] = 1,
        ['stateProvider'] = function()
            local player = owntoneGet(server, port, 'player')
            local queue = owntoneGet(server, port, 'queue')

            local playing = player['state'] == 'play'
            local progressMS = player['item_progress_ms']
            local lengthMS = player['item_length_ms']
            progressMS = math.max(1, progressMS)
            lengthMS = math.max(progressMS, lengthMS)
            local progressFraction = progressMS / lengthMS

            local itemID = player['item_id']
            for index,playerItem in pairs(queue['items']) do
                if playerItem['id'] == itemID then
                    artworkURL = playerItem['artwork_url']
                    break
                end
            end

            if artworkURL == nil then
                local artworkURL = player['artwork_url']
                if tableLength(queue['items']) > 0 then
                    local firstItem = queue['items'][1]
                    artworkURL = firstItem['artwork_url'] or artworkURL
                end
            end

            if artworkURL ~= nil then
                if not string.find(artworkURL, 'http') then
                    artworkURL = server .. ':' .. port .. '/' .. artworkURL
                    artworkURL = string.gsub(artworkURL, "/./", "/")
                end
                artworkImage = hs.image.imageFromURL(artworkURL)
            end

            return {
                ['playing'] = playing,
                ['progressFraction'] = progressFraction,
                ['queue'] = owntoneGet(server, port, 'queue'),
                ['player'] = owntoneGet(server, port, 'player'),
                ['artworkImage'] = artworkImage,
            }
        end
    }
end

