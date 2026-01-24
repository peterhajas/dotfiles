-- Navigate chapters if available, otherwise playlist
function chapter_or_playlist_next()
    local chapters = mp.get_property_number("chapters")
    local current_chapter = mp.get_property_number("chapter")

    if chapters and chapters > 0 and current_chapter < chapters - 1 then
        mp.command("add chapter 1")
    else
        mp.command("playlist-next")
    end
end

function chapter_or_playlist_prev()
    local chapters = mp.get_property_number("chapters")
    local current_chapter = mp.get_property_number("chapter")

    if chapters and chapters > 0 and current_chapter > 0 then
        mp.command("add chapter -1")
    else
        mp.command("playlist-prev")
    end
end

mp.add_key_binding("L", "chapter-or-playlist-next", chapter_or_playlist_next)
mp.add_key_binding("H", "chapter-or-playlist-prev", chapter_or_playlist_prev)
