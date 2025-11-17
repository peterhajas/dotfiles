-- mini.indentscope configuration
-- Animated indent scope visualization

require('mini.indentscope').setup({
    -- Draw options
    draw = {
        -- Delay (in ms) between event and start of drawing scope indicator
        delay = 0,

        -- Animation function - use built-in exponential for smooth animation
        -- duration per step scales with number of lines to cross
        animation = require('mini.indentscope').gen_animation.exponential({
            easing = 'in-out',
            duration = 0,   -- ms per step (will scale with scope size)
            unit = 'step',  -- proportional to number of lines
        }),
    },

    -- Module mappings - disabled
    mappings = {
        -- Textobjects
        object_scope = '',
        object_scope_with_border = '',

        -- Motions (jump to respective border line; if not present - body line)
        goto_top = '',
        goto_bottom = '',
    },

    -- Options which control scope computation
    options = {
        -- Type of scope's border: which line(s) with smaller indent to
        -- categorize as border. Can be one of: 'both', 'top', 'bottom', 'none'.
        border = 'both',

        -- Whether to use cursor column when computing reference indent.
        -- Useful to see incremental scopes with horizontal cursor movements.
        indent_at_cursor = true,

        -- Whether to first check input line to be a border of adjacent scope.
        -- Use it if you want to place cursor on function header to get scope of
        -- its body.
        try_as_border = false,
    },

    -- Which character to use for drawing scope indicator
    symbol = '│',
})

-- Note: Color is set to match Comment highlight in theme.lua
