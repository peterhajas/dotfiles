require "owntone"
require "util"

-- A button for controlling an Owntone server
function owntoneButton(server, port)
    return {
        ['name'] = 'OwnTone ' .. server .. ' ' .. port,
        ['imageProvider'] = function(context)
            local playerState = context['state']['player']
            local playing = context['state']['player']['state'] == 'play'
            local artworkURL = playerState['artwork_url']
            artworkURL = server .. ':' .. port .. '/' .. artworkURL
            artworkURL = string.gsub(artworkURL, "/./", "/")
            artworkImage = hs.image.imageFromURL(artworkURL)

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
            return {
                ['queue'] = owntoneGet(server, port, 'queue'),
                ['player'] = owntoneGet(server, port, 'player'),
            }
        end
    }
end

