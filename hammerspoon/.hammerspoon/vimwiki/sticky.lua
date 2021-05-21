require "util"

local rect = hs.geometry.rect(0, 0, 500, 500)

function pinVimwikiEntry(filePath)
    local handle = io.open(filePath, 'rb')

    -- Grab the contents of the path
    local contents = handle:read('*all')
    handle:close()

    -- HTML-ify it
    local html = hs.doc.markdown.convert(contents)

    -- Load and show it
    webview = hs.webview.new(rect)
        :html(html)
        :windowStyle(15)
        :deleteOnClose(true)
        :show()
end

function hideVimwikiEntry()
    
end
