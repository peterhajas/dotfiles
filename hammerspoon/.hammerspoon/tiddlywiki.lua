-- Rendering
function TiddlyWikiRender(name)
    local out, _, _, _ = hs.execute('~/bin/tiddlywiki_render ' .. name)
    return out
end

-- Metrics

local width = 180
local yOffset = 30

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    peekAtApp("TiddlyDesktop")
end)

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
WikiPath = wikiDirectory .. "phajas-wiki.html"
local cachedWikiContents = ""
local webView = nil
local glanceWebView = nil
local glanceTiddler = "HUDNONE"

local needsHUDUpdate = false
local needsGlanceUpdate = false

local function updateHUD()
    if needsHUDUpdate then
        local hudWikiContents = cachedWikiContents
        hudWikiContents = string.gsub(hudWikiContents, "HUDNONE", "Heads Up Display Desktop")
        hudWikiContents = string.gsub(hudWikiContents, "HUDOPTIONSNONE", "HUDOPTIONS_SIDEBARWIDGET")
        hudWikiContents = string.gsub(hudWikiContents, "#2d2d2d", "#21212199")
        webView:html(hudWikiContents)
    end
    needsHUDUpdate = false
end

local function updateGlance()
    if needsGlanceUpdate then
        local glanceWikiContents = cachedWikiContents
        glanceWikiContents = string.gsub(glanceWikiContents, "HUDNONE", glanceTiddler)
        glanceWebView:html(glanceWikiContents)
    end
    needsGlanceUpdate = false
end

local function update()
    local wikiFile = io.open(WikiPath, "r")
    if wikiFile ~= nil then
        local wikiContents = wikiFile:read("*a")
        if wikiContents ~= cachedWikiContents then
            cachedWikiContents = wikiContents
            needsHUDUpdate = true
            needsGlanceUpdate = true
        end
    end
    updateHUD()
    updateGlance()
end

local function layout()
    update()
    local screen = hs.screen.primaryScreen()
    local rect = hs.geometry.rect(screen:frame().w - width, yOffset, width, screen:frame().h - yOffset)
    webView:frame(rect)
end

local function caffeinateCallback(event)
    layout()
    if event == hs.caffeinate.watcher.screensDidLock or event == hs.caffeinate.watcher.screensaverDidStart or event == hs.caffeinate.watcher.systemWillSleep then
        SaveWiki()
        local tiddlyApp = hs.application.find("TiddlyDesktop")
        if tiddlyApp ~= nil then
            tiddlyApp:kill()
        end
    elseif event == hs.caffeinate.watcher.screensDidUnlock then
        local front = hs.application.frontmostApplication()
        hs.application.launchOrFocus("TiddlyDesktop")
        hs.timer.doAfter(1, function()
            ActivateTopWikiIfNeeded()
        end)
        if front ~= nil then
            hs.timer.doAfter(2, function()
                front:activate()
            end)
        end
    end
end

local function screenCallback()
    local showGlance = false
    local glanceFrame = hs.geometry.rect(0,0,0,0)
    if tableLength(hs.screen.allScreens()) > 1 then
        if hs.screen.allScreens()[2]:name() == "Sidecar Display (AirPlay)" then
            glanceFrame = hs.screen.allScreens()[2]:frame()
            showGlance = true
        end
    end

    if showGlance then
        glanceWebView:frame(glanceFrame)
        glanceWebView:sendToBack()
        glanceWebView:show()
        needsGlanceUpdate = true
    else
        glanceWebView:hide()
    end

    layout()
end

WikiCaffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
WikiScreenWatcher = hs.screen.watcher.new(screenCallback)
WikiPathWatcher = hs.pathwatcher.new(WikiPath, layout)

-- This is load-bearring and I don't know why
function UPDATEWIKI()
    layout()
end

local function setupWebView()
    local rect = hs.geometry.rect(0,0,0,0)
    webView = hs.webview.new(rect)
    webView:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    webView:transparent(true)
    webView:sendToBack()
    webView:show()

    glanceWebView = hs.webview.new(glanceFrame)
    glanceWebView:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)

    WikiScreenWatcher:start()
    WikiCaffeinateWatcher:start()
    WikiPathWatcher:start()

    screenCallback()
end

function SaveWiki()
    local app = hs.application.find("TiddlyDesktop")
    local down = hs.eventtap.event.newKeyEvent({"cmd"}, string.lower("s"), true)
    down:post(app)
    local up = hs.eventtap.event.newKeyEvent({"cmd"}, string.lower("s"), false)
    up:post(app)
end

wikiAppWatcher = hs.application.watcher.new(function(name, type, app)
    local leavingTiddlyDesktop = name == "TiddlyDesktop" and type == hs.application.watcher.deactivated 
    if leavingTiddlyDesktop then
        SaveWiki()
    end
end)
wikiAppWatcher:start()

function SendGlanceToTiddler(name)
    glanceTiddler = name
    needsGlanceUpdate = true
    update()
end

-- Activates the top Wiki in the "Main" window of TiddlyDesktop if needed
-- "Needed" means that the "Main" window is visible.
function ActivateTopWikiIfNeeded()
    local mainWindow = hs.application.find("TiddlyDesktop"):mainWindow()
    local mainWindowTitle = mainWindow:title()
    if mainWindowTitle ~= "TiddlyDesktop – Main - NW.js" then
        -- The main window is not the wiki list. Skip and early return
        dbg("EARLY RETURN")
        return
    end

    local windowAXElement = hs.axuielement.windowElement(mainWindow)
    local callback = function(msg, results, count)

        local found = results[1]
        if found == nil then
            dbg("EARLY RETURN 2")
            return
        end

        -- This part is a bit gross
        -- Grab the second child
        local secondChild = found:attributeValue("AXChildren")[2]
        -- and its first child
        local thirdChildOfSecondChild = secondChild:attributeValue("AXChildren")[3]
        -- and its third child
        local firstChildOfThirdChildOfSecondChild = thirdChildOfSecondChild:attributeValue("AXChildren")[1]
        -- This thing is the parent of the wiki list entries
        -- Get the first child, for the wiki entry
        local wikiEntry = firstChildOfThirdChildOfSecondChild:attributeValue("AXChildren")[1]
        local wikiEntryInternals = wikiEntry:attributeValue("AXChildren")[1]
        local openWikiButtonParent = wikiEntryInternals:attributeValue("AXChildren")[1]
        local openWikiButton = openWikiButtonParent:attributeValue("AXChildren")[1]
        openWikiButton:performAction("AXPress")

        mainWindow:close()

    end

    local criteria = function(elem)
        local role = elem:attributeValue("AXRole")
        return role == "AXWebArea"
    end


    windowAXElement:elementSearch(callback, criteria, {
        ["count"] = 1,
    })
end

setupWebView()
