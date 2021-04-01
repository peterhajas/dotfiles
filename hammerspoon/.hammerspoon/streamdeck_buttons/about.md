Buttons are defined as tables, with some values:
- `image`: the image
- `stateProvider`: optional state-providing function. `imageProvider` will only
  be called when the state changes
- `imageProvider`: the function returning the image, taking context in a table:
    - `isPressed` - whether the button is being pressed down
    - `location` - table of `x` and `y` keys representing the button location 
        - zero-indexed
    - `size` - table of `w` and `h` keys representing the deck size 
    - `state` - the state to act on, as returned by `stateProvider`
- `onClick`: the function to perform when being clicked
- `onLongPress`: the function to perform when being held down
    - passed a boolean for if we're being held or released
- `updateInterval`: the desired update interval (if any) in seconds
- `name`: the name of the button
- `children`: function returning child buttons, which will be pushed

Internal values:
- `_lastState`: the last state we heard about for this button
- `_lastImage`: the last image we grabbed for this button
- `_holdTimer`: a timer for long-press events
- `_isHolding`: whether this button is being held down
