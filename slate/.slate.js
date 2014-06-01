// .slate.js
// Peter Hajas, originally authored May 31, 2014

// Global Configuration
// Set the "hyper" key, my own modifier space

var hyperKey = "ctrl,alt,shift";

// Order screens left to right

slate.config("orderScreensLeftToRight", true);

// Show window hints when pressing hyper-enter

var hint = slate.operation
(
    "hint",
        {
            "characters" : "asdfghjkl"
        }
);

slate.bind("return:" + hyperKey, hint);

// Show grid when pressing hyper-space

var grid = slate.operation
(
    "grid",
        {
            "padding" : 0
        }
);

slate.bind("space:" + hyperKey, grid);
