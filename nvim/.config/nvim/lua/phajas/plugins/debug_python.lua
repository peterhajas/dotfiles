local dap_python = require('dap-python')
local dap = require('dap')

-- Set up dap-python with uv's python path
-- This function finds the python executable in your uv environment
local function get_uv_python_path()
    local result = ""
    local handle = io.popen('uv run which python')
    if handle ~= nil then
        result = handle:read("*a")
        handle:close()
    end
    return result:gsub("%s+", "") -- trim whitespace
end

-- Configure dap-python
dap_python.setup("uv") -- instead of get_uv_python_path

-- Clear the configurations
dap.configurations.python = {}

-- Startup Configurations
table.insert(dap.configurations.python, 1, {
    type = 'python',
    request = 'launch',
    name = 'Launch with uv',
    program = '${file}',
    python = get_uv_python_path(),
    console = 'integratedTerminal',
    cwd = '${workspaceFolder}',
    env = function()
        local env = {}

        -- Get environment variables from uv
        local handle = io.popen('uv run env')
        if handle ~= nil then
            local env_output = handle:read("*a")
            handle:close()
            for line in env_output:gmatch("[^\r\n]+") do
                local key, value = line:match("([^=]+)=(.+)")
                if key and value then
                    env[key] = value
                end
            end
        end

        return env
    end,
})

-- -- Configuration for running the main module with uv
-- table.insert(dap.configurations.python, {
--     type = 'python',
--     request = 'launch',
--     name = 'Launch module with uv',
--     module = '${input:module}',
--     python = get_uv_python_path(),
--     console = 'integratedTerminal',
--     cwd = '${workspaceFolder}',
--     env = function()
--         local env = {}

--         -- Get environment variables from uv
--         local handle = io.popen('uv run env')
--         if handle ~= nil then
--             local env_output = handle:read("*a")
--             handle:close()
--             for line in env_output:gmatch("[^\r\n]+") do
--                 local key, value = line:match("([^=]+)=(.+)")
--                 if key and value then
--                     env[key] = value
--                 end
--             end
--         end

--         return env
--     end,
-- })
