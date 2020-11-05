-- Grab the current track's iTunes albumart
function currentiTunesArtwork()
    local app = hs.application'Music'
    if app == nil then
        return nil
    end
    if app:isRunning() == false then
        return nil
    end
    if hs.itunes.getCurrentTrack() == nil then
        return nil
    end
    applescript_str = [[global f, a
    tell application "Music"
        
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
end
