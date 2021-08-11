require "streamdeck.audio_devices"
require "streamdeck.itunes"
require "streamdeck.terminal"
require "streamdeck.peek"
require "streamdeck.url"
require "streamdeck.lock"
require "streamdeck.clock"
require "streamdeck.camera"
require "streamdeck.weather"
require "streamdeck.app_switcher"
require "streamdeck.window_switcher"
require "streamdeck.animation_demo"
require "streamdeck.home_assistant"
require "streamdeck.numpad"
require "streamdeck.window_clone"
require "streamdeck.function_keys"
require "streamdeck.shortcuts"
require "streamdeck.shelf"
require "streamdeck.soundboard"

initialButtonState = {
    ['name'] = 'Root',
    ['buttons'] = {
        weatherButton(),
        calendarPeekButton(),
        peekButtonFor('com.reederapp.5.macOS'),
        lockButton,
        audioDeviceButton(false),
        audioDeviceButton(true),
        itunesPreviousButton(),
        itunesNextButton(),
        appSwitcher(),
        windowSwitcher(),
        homeAssistant(),
        numberPad(),
        windowClone(),
        functionKeys(),
        homeAssistantEntity("scene.office_regular"),
        homeAssistantEntity("scene.office_mood"),
        homeAssistantEntity("scene.office_off"),
        shortcuts(),
        camera1Button,
        camera2Button,
        dashClose,
        shelfButtonForShelfWithID("a"),
        shelfButtonForShelfWithID("b"),
        shelfButtonForShelfWithID("c"),
        soundboardButton(),
        homeAssistantEntity("media_player.forked_daapd_server"),
    }
}
