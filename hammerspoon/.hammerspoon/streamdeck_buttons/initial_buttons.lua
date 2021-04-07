require "streamdeck_buttons.audio_devices"
require "streamdeck_buttons.itunes"
require "streamdeck_buttons.terminal"
require "streamdeck_buttons.peek"
require "streamdeck_buttons.url"
require "streamdeck_buttons.lock"
require "streamdeck_buttons.clock"
require "streamdeck_buttons.camera"
require "streamdeck_buttons.weather"
require "streamdeck_buttons.app_switcher"
require "streamdeck_buttons.window_switcher"
require "streamdeck_buttons.animation_demo"
require "streamdeck_buttons.home_assistant"
require "streamdeck_buttons.numpad"
require "streamdeck_buttons.window_clone"
require "streamdeck_buttons.function_keys"

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
    }
}
