Buttons are defined as tables, with some values:
- `image`: the image
- `imageProvider`: the function returning the image, taking some context
- `pressDown`: the function to perform on press down
- `pressUp`: the function to perform on press up
- `updateInterval`: the desired update interval (if any) in seconds
- `name`: the name of the button
- `children`: function returning child buttons, which will be pushed

Internal values:
- `_timer`: the timer that is updating this button
