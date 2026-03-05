-- Chooser Module
-- Provides a UI chooser for selecting from a list of options using webview

local chooser = {}

require 'util'

-- Private state for CLI chooser
local chosen = nil
local exited = false

-- Private state for webview chooser
local currentWebview = nil
local currentPreviewWebview = nil
local currentCompletion = nil
local previousWindow = nil
local windowWatcher = nil
local eventHandlersInitialized = false
local currentOptions = {}

local function escapeHtml(str)
    if str == nil then
        return ""
    end
    return tostring(str)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
end

local function defaultPreviewHTML(message)
    return [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      margin: 0;
      padding: 20px;
      background: rgba(20, 20, 30, 0.95);
      color: #b9c0cc;
      font-family: Menlo, Monaco, monospace;
      font-size: 14px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div>]] .. escapeHtml(message or "Select a tiddler to preview") .. [[</div>
</body>
</html>
]]
end

local function closeChooserViews()
    if currentWebview then
        currentWebview:delete()
        currentWebview = nil
    end
    if currentPreviewWebview then
        currentPreviewWebview:delete()
        currentPreviewWebview = nil
    end
end

local function cancelCurrentChooser()
    if not currentCompletion then
        return
    end

    closeChooserViews()

    if windowWatcher then
        windowWatcher:stop()
        windowWatcher = nil
    end

    if previousWindow then
        previousWindow:focus()
        previousWindow = nil
    end

    currentCompletion(nil)
    currentCompletion = nil
end

-- Simple URL decode function
local function urlDecode(str)
    if not str then return nil end
    str = str:gsub("+", " ")
    str = str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return str
end

-- Generate HTML for the chooser
local function generateHTML(choices, options)
    options = options or {}
    local placeholder = options.placeholder or "Type to filter..."
    local escapedPlaceholder = placeholder:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    local allowFreeform = options.allowFreeform == true
    local allowDelete = options.allowDelete == true
    local enablePreview = options.enablePreview == true
    -- Use table for efficient string concatenation
    local choicesParts = {}
    for i, choice in ipairs(choices) do
        local escaped = choice:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
        table.insert(choicesParts, string.format('<div class="result-item" data-index="%d">%s</div>', i-1, escaped))
    end
    local choicesHTML = table.concat(choicesParts, "\n")

    return [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Menlo', monospace;
            background: rgba(20, 20, 30, 0.95);
            color: #e0e0e0;
            overflow: hidden;
        }

        #container {
            display: flex;
            flex-direction: column;
            height: 100vh;
            padding: 20px;
        }

        #search {
            width: 100%;
            font-size: 24px;
            padding: 15px 20px;
            border: 2px solid #4a4a5a;
            border-radius: 8px;
            background: #2a2a3a;
            color: #e0e0e0;
            outline: none;
            font-family: 'Menlo', monospace;
            margin-bottom: 15px;
        }

        #search:focus {
            border-color: #6a9fb5;
        }

        #results {
            flex: 1;
            overflow-y: auto;
            overflow-x: hidden;
        }

        .result-item {
            padding: 12px 20px;
            font-size: 18px;
            cursor: pointer;
            border-radius: 6px;
            margin-bottom: 5px;
            transition: background 0.1s;
            font-family: 'Menlo', monospace;
        }

        .result-item:hover {
            background: #3a3a4a;
        }

        .result-item.selected {
            background: #4a5a7a;
        }

        .result-item.hidden {
            display: none;
        }

        ::-webkit-scrollbar {
            width: 10px;
        }

        ::-webkit-scrollbar-track {
            background: #2a2a3a;
            border-radius: 5px;
        }

        ::-webkit-scrollbar-thumb {
            background: #4a4a5a;
            border-radius: 5px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: #5a5a6a;
        }
    </style>
</head>
<body>
    <div id="container">
        <input type="text" id="search" placeholder="]] .. escapedPlaceholder .. [[" autofocus>
        <div id="results">]] .. choicesHTML .. [[</div>
    </div>

    <script>
        const allItems = Array.from(document.querySelectorAll('.result-item'));
        let selectedIndex = 0;
        let visibleItems = [...allItems];
        let lastSelectedItem = null;
        const allowFreeform = ]] .. tostring(allowFreeform) .. [[;
        const allowDelete = ]] .. tostring(allowDelete) .. [[;
        const enablePreview = ]] .. tostring(enablePreview) .. [[;
        let previewTimer = null;
        let lastPreviewValue = null;

        const searchInput = document.getElementById('search');

        function updateSelection() {
            // Only update DOM for items that change state
            if (lastSelectedItem) {
                lastSelectedItem.classList.remove('selected');
            }

            if (visibleItems[selectedIndex]) {
                visibleItems[selectedIndex].classList.add('selected');
                lastSelectedItem = visibleItems[selectedIndex];
                visibleItems[selectedIndex].scrollIntoView({ block: 'nearest', behavior: 'instant' });
            }

            if (enablePreview) {
                schedulePreview();
            }
        }

        function selectedOrQueryText() {
            if (visibleItems[selectedIndex]) {
                return visibleItems[selectedIndex].textContent;
            }
            const query = searchInput.value.trim();
            return query;
        }

        function requestPreview() {
            const text = selectedOrQueryText();
            if (text && text !== '' && text !== lastPreviewValue) {
                lastPreviewValue = text;
                window.location.href = 'hammerspoon://preview?value=' + encodeURIComponent(text);
            }
        }

        function schedulePreview() {
            if (previewTimer) {
                clearTimeout(previewTimer);
            }
            previewTimer = setTimeout(requestPreview, 140);
        }

        function filterResults() {
            const query = searchInput.value.toLowerCase();

            if (query === '') {
                // Fast path for empty query
                visibleItems = allItems;
                allItems.forEach(item => item.classList.remove('hidden'));
            } else {
                visibleItems = [];
                // Batch DOM updates
                const fragment = document.createDocumentFragment();

                allItems.forEach(item => {
                    const isVisible = item.textContent.toLowerCase().includes(query);
                    if (isVisible) {
                        item.classList.remove('hidden');
                        visibleItems.push(item);
                    } else {
                        item.classList.add('hidden');
                    }
                });
            }

            selectedIndex = 0;
            updateSelection();
        }

        function selectItem() {
            if (visibleItems[selectedIndex]) {
                const text = visibleItems[selectedIndex].textContent;
                window.location.href = 'hammerspoon://select?value=' + encodeURIComponent(text);
            } else if (allowFreeform) {
                const query = searchInput.value.trim();
                if (query !== '') {
                    window.location.href = 'hammerspoon://select?value=' + encodeURIComponent(query);
                }
            }
        }

        function cancel() {
            window.location.href = 'hammerspoon://cancel';
        }

        function deleteItem() {
            if (!allowDelete) {
                return;
            }
            if (visibleItems[selectedIndex]) {
                const text = visibleItems[selectedIndex].textContent;
                window.location.href = 'hammerspoon://delete?value=' + encodeURIComponent(text);
            }
        }

        searchInput.addEventListener('input', filterResults);

        searchInput.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowDown') {
                e.preventDefault();
                selectedIndex = Math.min(selectedIndex + 1, visibleItems.length - 1);
                updateSelection();
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                selectedIndex = Math.max(selectedIndex - 1, 0);
                updateSelection();
            } else if (e.key === 'ArrowRight' || e.key === 'Enter') {
                e.preventDefault();
                selectItem();
            } else if (allowDelete && (e.key === 'd' || e.key === 'D') && e.ctrlKey) {
                e.preventDefault();
                deleteItem();
            } else if (e.key === 'ArrowLeft' || e.key === 'Escape') {
                e.preventDefault();
                cancel();
            }
        });

        allItems.forEach(item => {
            item.addEventListener('click', () => {
                const text = item.textContent;
                window.location.href = 'hammerspoon://select?value=' + encodeURIComponent(text);
            });
        });

        updateSelection();
        // Focus immediately
        searchInput.focus();
    </script>
</body>
</html>
    ]]
end

-- Initialize event handlers once
local function initializeEventHandlers()
    if eventHandlersInitialized then
        return
    end

    hs.urlevent.bind("select", function(eventName, params)
        if currentCompletion then
            local value = params.value
            if value then
                value = urlDecode(value)

                closeChooserViews()

                -- Stop watcher
                if windowWatcher then
                    windowWatcher:stop()
                    windowWatcher = nil
                end

                -- Restore previous window focus
                if previousWindow then
                    previousWindow:focus()
                    previousWindow = nil
                end

                -- Call completion
                currentCompletion(value)
                currentCompletion = nil
            end
        end
    end)

    hs.urlevent.bind("cancel", function(eventName, params)
        cancelCurrentChooser()
    end)

    hs.urlevent.bind("delete", function(eventName, params)
        if currentCompletion then
            local value = params.value
            if value then
                value = urlDecode(value)

                closeChooserViews()

                -- Stop watcher
                if windowWatcher then
                    windowWatcher:stop()
                    windowWatcher = nil
                end

                -- Restore previous window focus
                if previousWindow then
                    previousWindow:focus()
                    previousWindow = nil
                end

                -- Call onDelete callback if provided
                if currentOptions and currentOptions.onDelete then
                    currentOptions.onDelete(value)
                end

                -- End the chooser interaction
                currentCompletion(nil)
                currentCompletion = nil
            end
        end
    end)

    hs.urlevent.bind("preview", function(eventName, params)
        if not currentPreviewWebview then
            return
        end
        if not currentOptions then
            return
        end
        local value = urlDecode(params.value or "")
        if currentOptions.onPreviewEvent then
            local ok, handled = pcall(currentOptions.onPreviewEvent, currentPreviewWebview, value)
            if ok and handled then
                return
            end
        end
        if not currentOptions.onPreview then
            return
        end
        local ok, previewHTML = pcall(currentOptions.onPreview, value)
        if not ok then
            currentPreviewWebview:html(defaultPreviewHTML("Preview error"))
            return
        end
        if type(previewHTML) ~= "string" or previewHTML == "" then
            currentPreviewWebview:html(defaultPreviewHTML("No preview"))
            return
        end
        currentPreviewWebview:html(previewHTML)
    end)

    eventHandlersInitialized = true
end

-- Show a chooser with the given choices, calling completion with the chosen item
function chooser.show(choices, completion, options)
    -- Initialize event handlers on first use
    initializeEventHandlers()

    -- Store the currently focused window so we can restore it
    previousWindow = hs.window.focusedWindow()

    -- Close any existing webview
    closeChooserViews()

    currentCompletion = completion
    currentOptions = options or {}

    -- Get the main screen frame
    local mainScreen = hs.screen.mainScreen()
    local screenFrame = mainScreen:frame()

    local enablePreview = currentOptions.enablePreview == true

    -- Create webview at top of screen with fixed height
    local webviewHeight = 420
    local totalWidth = screenFrame.w * (enablePreview and 0.85 or 0.6)
    local originX = screenFrame.x + (screenFrame.w - totalWidth) / 2

    local chooserWidth = enablePreview and (totalWidth * 0.42) or totalWidth
    local verticalMargin = 12
    local overlayY = screenFrame.y + screenFrame.h - webviewHeight - verticalMargin

    local webviewFrame = {
        x = originX,
        y = overlayY,
        w = chooserWidth,
        h = webviewHeight
    }

    currentWebview = hs.webview.new(webviewFrame)
        :windowStyle({})
        :level(hs.drawing.windowLevels.floating)
        :allowTextEntry(true)
        :html(generateHTML(choices, currentOptions))
        :show()

    if enablePreview then
        local previewFrame = {
            x = originX + chooserWidth + 8,
            y = overlayY,
            w = totalWidth - chooserWidth - 8,
            h = webviewHeight
        }
        currentPreviewWebview = hs.webview.new(previewFrame)
            :windowStyle({})
            :level(hs.drawing.windowLevels.floating)
            :allowTextEntry(false)
            :html(defaultPreviewHTML(currentOptions.previewPlaceholder or "Select a tiddler to preview"))
            :show()

        if currentOptions.onPreviewInit then
            pcall(currentOptions.onPreviewInit, currentPreviewWebview)
        end
    end

    -- Focus the webview window immediately
    hs.timer.doAfter(0.01, function()
        if currentWebview then
            local webviewWindow = currentWebview:hswindow()
            if webviewWindow then
                webviewWindow:focus()

                -- Set up watcher to cancel if webview loses key window status
                if windowWatcher then
                    windowWatcher:stop()
                end

                if hs.window and hs.window.watcher and hs.window.watcher.new then
                    windowWatcher = hs.window.watcher.new(function(win, event, app)
                        -- Check if a different window got focused
                        if event == hs.window.watcher.windowFocused then
                            if win ~= webviewWindow and currentWebview and currentCompletion then
                                -- Another window got focused, trigger cancel
                                closeChooserViews()

                                -- Stop watcher
                                if windowWatcher then
                                    windowWatcher:stop()
                                    windowWatcher = nil
                                end

                                -- Restore previous window focus (which is now the focused window)
                                previousWindow = nil

                                -- Call completion with nil
                                currentCompletion(nil)
                                currentCompletion = nil
                            end
                        end
                    end)
                    windowWatcher:start()
                end
            end
        end
    end)
end

function chooser.showWithOptions(choices, completion, options)
    chooser.show(choices, completion, options)
end

function chooser.isVisible()
    return currentWebview ~= nil
end

function chooser.hide()
    cancelCurrentChooser()
end

-- Show chooser from CLI with pipe-separated arguments
function chooser.showCLI(args)
    chosen = nil
    exited = false

    local choices = {}
    local argsSplit = split(args, "|")
    for k,v in pairs(argsSplit) do
        table.insert(choices, v)
    end

    chooser.show(choices, function(picked)
        exited = true
        chosen = picked  -- Set chosen even if nil (for cancel case)
    end)
end

-- Get the chosen value from CLI chooser
function chooser.getCLIChosen()
    local out = nil
    if exited then
        if chosen then
            out = chosen
        else
            out = "NOTHING_PICKED_IN_CHOOSER"
        end
        -- Only reset after we've returned a non-nil value
        chosen = nil
        exited = false
    end

    return out
end

-- Export as globals for CLI compatibility
showChooserCLI = chooser.showCLI
getCLIChosen = chooser.getCLIChosen
showChooser = chooser.show

return chooser
