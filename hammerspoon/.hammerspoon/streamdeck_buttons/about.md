Buttons are defined as tables, with some values:
- `image`: the image
- `imageProvider`: the function returning the image, taking some context
- `onClick`: the function to perform when being clicked
- `onLongPress`: the function to perform when being held down
    - passed a boolean for if we're being held or released
- `pressDown`: the function to perform on press down
- `pressUp`: the function to perform on press up
- `updateInterval`: the desired update interval (if any) in seconds
- `name`: the name of the button
- `children`: function returning child buttons, which will be pushed

Internal values:
- `_timer`: the timer that is updating this button
- `_holdTimer`: a timer for long-press events
- `_isHolding`: whether this button is being held down
