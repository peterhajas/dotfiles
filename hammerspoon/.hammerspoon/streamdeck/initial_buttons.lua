require "streamdeck.audio_devices"
require "streamdeck.itunes"
require "streamdeck.terminal"
require "streamdeck.peek"
require "streamdeck.url"
require "streamdeck.lock"
require "streamdeck.clock"
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
require "streamdeck.owntone"

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
        shortcuts(),
        shelfButtonForShelfWithID("a"),
        shelfButtonForShelfWithID("b"),
        shelfButtonForShelfWithID("c"),
        soundboardButton(),
        owntoneButton('http://192.168.1.2', '3689'),
        homeAssistantEntity('switch.office_shelly_channel_1'),
        homeAssistantEntity('media_player.office_announcements')
    }
}
