-- iTunes Album Artwork (an experiment) {{{
-- Currently unused

function currentiTunesArtwork()
    if hs.appfinder.appFromName('iTunes') then
        applescript_str = [[global f, a
        tell application "iTunes"
            
            tell artwork 1 of current track
                set d to raw data
                if format is «class PNG » then
                    set x to "png"
                else
                    set x to "jpg"
                end if
            end tell
            
            set a to album of current track
        end tell

        set f to (((path to temporary items) as text) & "cover." & x)
        set b to open for access file result with write permission
        set eof b to 0
        write d to b
        close access b

        return f]]

        ok, result = hs.applescript.applescript(applescript_str)

        if ok == true then
            path = string.gsub(result, ":", "/")

            -- Applescript paths include the name of the disk as the first
            -- component of the path. We should shave this off, so that calls
            -- to hs.image.imageFromPath() can find images

            local path_elem = hs.fnutils.split(path, "/")
            local disk_name = path_elem[1]

            -- Remove this leading disk_name from path

            path = string.gsub(path, disk_name, "")

            image = hs.image.imageFromPath(path)

            return image
        else
            return nil
        end
    else
        return nil
    end
end

local itunesArtwork

function updateiTunesArtwork()
    local image = currentiTunesArtwork()

    if image ~= nil then
        itunesArtwork:setImage(image)
        itunesArtwork:show()
        local activateiTunes = function() hs.application.launchOrFocus("iTunes") end
        itunesArtwork = itunesArtwork:setClickCallback(activateiTunes)

    else
        itunesArtwork = itunesArtwork:setClickCallback(nil)
        itunesArtwork:hide()
    end
end

function buildiTunesArtwork()
    if itunesArtwork ~= nil then itunesArtwork:delete() end
    local preferredScreenFrame = preferredScreen():fullFrame()
    local dimension = 100
    local frame = hs.geometry.rect(0,40,dimension,dimension)
    itunesArtwork = hs.drawing.image(frame, "ASCII:.")

    -- Not crazy about this - it still floats over windows :-/
    -- It won't get click events if it's sent to the back, though...
    itunesArtwork:orderBelow()

    updateiTunesArtwork()
end

buildiTunesArtwork()

-- }}}
